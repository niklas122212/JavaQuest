package app.javaquest.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Route
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.vector.ImageVector
import app.javaquest.core.AnswerEvaluator
import app.javaquest.core.Difficulty
import app.javaquest.core.EvaluationResult
import app.javaquest.core.LearningTask
import app.javaquest.core.Lesson
import app.javaquest.core.LessonSession
import app.javaquest.core.TaskAnswer
import app.javaquest.core.TaskKind
import app.javaquest.core.TheoryCard
import app.javaquest.data.AttemptContext
import app.javaquest.data.ProgressStore
import app.javaquest.data.ScoreChange

enum class Section(val title: String, val icon: ImageVector) {
    DASHBOARD("Übersicht", Icons.Rounded.Dashboard),
    PATH("Lernpfad", Icons.Rounded.Route),
    TOPICS("Alle Themen", Icons.Rounded.GridView),
    ANALYSIS("Analyse", Icons.Rounded.Psychology),
    PROFILE("Profil", Icons.Rounded.Person),
}

/** Navigation: Bereich in der Seitenleiste und die laufende Lektion, Übung oder Trainingsrunde. */
class AppState(val store: ProgressStore) {
    var section by mutableStateOf(Section.DASHBOARD)
    var flow by mutableStateOf<LessonFlowModel?>(null)
        private set

    /** Der laufende Einstufungstest – gehört zum Onboarding, nicht zu einer Lektion. */
    var placementTest by mutableStateOf<app.javaquest.core.PlacementTest?>(null)

    fun startLesson(lessonId: String) {
        val lesson = store.course.lesson(lessonId) ?: return
        // Varianten je Lernziel: beim Wiederholen kommen andere Aufgaben.
        val session = LessonSession(
            LessonSession.Mode.Lesson(lesson.id), lesson.title, lesson.theory, store.lessonTasks(lesson),
        )
        flow = LessonFlowModel(store, session, isPractice = false)
    }

    fun startPractice(topicId: String) {
        val tasks = store.practiceTasks(topicId)
        if (tasks.isEmpty()) return
        val title = "Übung: ${store.course.topic(topicId)?.title ?: topicId}"
        flow = LessonFlowModel(store, LessonSession(LessonSession.Mode.Practice(topicId), title, emptyList(), tasks), isPractice = true)
    }

    /** Startet eine neue Runde Endlos-Training (auch direkt aus der Auswertung heraus). */
    fun startTraining() {
        val tasks = store.trainingTasks()
        if (tasks.isEmpty()) return
        flow = LessonFlowModel(store, LessonSession(LessonSession.Mode.Training, "Endlos-Training", emptyList(), tasks), isPractice = true)
    }

    /** Wiederholung: die Lernziele, deren Pause abgelaufen ist. */
    fun startReview(count: Int = app.javaquest.core.TrainingBuilder.ROUND_SIZE) {
        val tasks = store.reviewTasks(count)
        if (tasks.isEmpty()) return
        flow = LessonFlowModel(store, LessonSession(LessonSession.Mode.Training, "Wiederholung", emptyList(), tasks), isPractice = true)
    }

    /** Freies Training: selbst gewählte Themen, Niveaus und Anzahl – ohne Lernpfad-Sperre. */
    fun startFreeTraining(topicIds: Set<String>, difficulties: Set<Difficulty>, count: Int) {
        val tasks = store.freeTrainingTasks(topicIds, difficulties, count)
        if (tasks.isEmpty()) return
        val names = topicIds.mapNotNull { store.course.topic(it)?.title }
        val title = if (names.isEmpty()) "Freies Training" else "Freies Training: ${names.joinToString(", ")}"
        flow = LessonFlowModel(store, LessonSession(LessonSession.Mode.Training, title, emptyList(), tasks), isPractice = true)
    }

    fun closeFlow() {
        flow = null
    }
}

/** Eingaben der lernenden Person für die aktuelle Aufgabe. */
data class AnswerDraft(val choice: Int? = null, val blanks: List<String> = emptyList(), val text: String = "") {
    fun answer(task: LearningTask): TaskAnswer? = when (task.kind) {
        is TaskKind.SingleChoice -> choice?.let(TaskAnswer::Choice)
        is TaskKind.FillBlank -> if (blanks.any { it.isNotBlank() }) TaskAnswer.Blanks(blanks) else null
        is TaskKind.PredictOutput, is TaskKind.Code -> if (text.isBlank()) null else TaskAnswer.Text(text)
    }

    fun applying(answer: TaskAnswer) = when (answer) {
        is TaskAnswer.Choice -> copy(choice = answer.index)
        is TaskAnswer.Blanks -> copy(blanks = answer.values)
        is TaskAnswer.Text -> copy(text = answer.text)
    }

    companion object {
        fun forTask(task: LearningTask?) = when (val kind = task?.kind) {
            is TaskKind.FillBlank -> AnswerDraft(blanks = List(kind.blanks.size) { "" })
            is TaskKind.Code -> AnswerDraft(text = kind.starter.source)
            else -> AnswerDraft()
        }
    }
}

/**
 * Lern-Loop einer Lektion, Übung oder Trainingsrunde. Die Sitzung selbst ist reine Logik aus `core`;
 * `revision` sorgt dafür, dass Compose nach jeder Änderung neu zeichnet.
 */
class LessonFlowModel(val store: ProgressStore, private val session: LessonSession, val isPractice: Boolean) {
    private var revision by mutableIntStateOf(0)
    var draft by mutableStateOf(AnswerDraft.forTask(session.currentTask))
    var scoreChange by mutableStateOf<ScoreChange?>(null)
        private set
    var successCount by mutableIntStateOf(0)
        private set

    private fun <T> read(value: () -> T): T {
        revision
        return value()
    }

    val title: String get() = session.title
    val theory: List<TheoryCard> get() = session.theory
    val tasks: List<LearningTask> get() = session.tasks
    val phase: LessonSession.Phase get() = read { session.phase }
    val currentTask: LearningTask? get() = read { session.currentTask }
    val lastResult: EvaluationResult? get() = read { session.lastResult }
    val isRevealed: Boolean get() = read { session.isRevealed }

    /** Die gewählte falsche Antwort samt Begründung – für die Rückmeldung nach einem Fehler. */
    val wrongChoice: Pair<String, String?>? get() {
        val kind = currentTask?.kind as? TaskKind.SingleChoice ?: return null
        if (lastResult?.isCorrect != false) return null
        val index = draft.choice ?: return null
        if (index == kind.correctIndex) return null
        return kind.choices[index] to kind.whyWrong(index)
    }

    /** Was richtig gewesen wäre – erst, wenn die Aufgabe abgeschlossen ist. */
    val correctAnswer: String? get() {
        if (!isCurrentTaskFinished) return null
        return when (val kind = currentTask?.kind) {
            is TaskKind.SingleChoice -> kind.choices.getOrNull(kind.correctIndex)
            else -> null
        }
    }
    val attempts: Int get() = read { session.attempts }
    val isCurrentTaskFinished: Boolean get() = read { session.isCurrentTaskFinished }
    val canRetry: Boolean get() = read { session.canRetry }
    val progress: Double get() = read { session.progress }
    val summary get() = read { session.summary }
    val lessonId: String? get() = session.lessonId
    val isTraining: Boolean get() = session.mode == LessonSession.Mode.Training
    val remainingAttempts: Int get() = read { maxOf(LessonSession.MAX_ATTEMPTS - session.attempts, 0) }

    /** Position „Aufgabe 2 von 5“. */
    val taskPosition: Pair<Int, Int>?
        get() = (phase as? LessonSession.Phase.Task)?.let { it.index + 1 to tasks.size }

    val canSubmit: Boolean
        get() {
            val task = currentTask ?: return false
            if (isCurrentTaskFinished) return false
            if (lastResult != null && !canRetry) return false
            val kind = task.kind
            if (kind is TaskKind.Code && draft.text.trim() == kind.starter.source.trim()) return false
            return draft.answer(task) != null
        }

    fun advanceTheory() { session.advanceTheory(); revision++ }
    fun goBackInTheory() { session.goBackInTheory(); revision++ }

    fun submit() {
        if (!canSubmit) return
        val task = currentTask ?: return
        val answer = draft.answer(task) ?: return
        if (session.lastResult != null) session.prepareRetry()
        val result = session.submit(answer) ?: return
        revision++
        if (result.isCorrect) {
            successCount++
            persistFinishedOutcome()
        }
    }

    fun revealSolution() {
        val task = currentTask ?: return
        session.revealSolution()
        draft = draft.applying(AnswerEvaluator.referenceAnswer(task))
        revision++
        persistFinishedOutcome()
    }

    fun next() {
        session.advanceToNextTask()
        draft = AnswerDraft.forTask(session.currentTask)
        revision++
        val id = session.lessonId
        if (session.phase == LessonSession.Phase.Summary && id != null) {
            scoreChange = store.completeLesson(id, session.summary)
        }
    }

    /** Ergebnis je Lücke nach dem Prüfen – für die farbige Markierung. */
    fun blankStates(task: LearningTask): List<Boolean>? {
        val kind = task.kind as? TaskKind.FillBlank ?: return null
        if (lastResult == null && !isRevealed) return null
        return kind.blanks.mapIndexed { index, blank -> blank.accepts(draft.blanks.getOrElse(index) { "" }) }
    }

    val nextLessonAfterCurrent: Lesson?
        get() {
            val id = session.lessonId ?: return null
            val lessons = store.course.allLessons
            val index = lessons.indexOfFirst { it.id == id }
            return lessons.getOrNull(index + 1)
        }

    private fun persistFinishedOutcome() {
        val outcome = session.finishedOutcome ?: return
        store.record(outcome, session.lessonId, when {
            isTraining -> AttemptContext.TRAINING
            isPractice -> AttemptContext.PRACTICE
            else -> AttemptContext.LESSON
        })
    }
}
