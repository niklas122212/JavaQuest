package app.javaquest.core

import java.time.Instant
import kotlin.math.abs
import kotlin.math.roundToInt

// ---------------------------------------------------------------- Lern-Loop

data class TaskOutcome(
    val taskId: String,
    val topicId: String,
    val difficulty: Difficulty,
    val attempts: Int,
    val solved: Boolean,
    val credit: Double,
) {
    constructor(task: LearningTask, attempts: Int, solved: Boolean, credit: Double) :
        this(task.id, task.topicId, task.difficulty, attempts, solved, credit)

    val solvedOnFirstTry: Boolean get() = solved && attempts == 1
}

object Stars {
    /** Bestanden (ab 90 %) = 1 Stern, ab 95 % = 2 Sterne, fehlerfrei = 3 Sterne. */
    fun forAccuracy(accuracy: Double): Int = when {
        accuracy >= 0.999 -> 3
        accuracy >= 0.95 -> 2
        accuracy >= LessonSession.PASS_THRESHOLD -> 1
        else -> 0
    }
}

data class LessonSummary(val outcomes: List<TaskOutcome>, val taskCount: Int) {
    /** Nach Niveau gewichtete Trefferquote 0…1. */
    val accuracy: Double
        get() {
            val total = outcomes.sumOf { it.difficulty.weight }
            return if (total > 0) outcomes.sumOf { it.difficulty.weight * it.credit } / total else 0.0
        }
    val passed: Boolean get() = accuracy >= LessonSession.PASS_THRESHOLD && outcomes.size == taskCount
    val solvedCount: Int get() = outcomes.count { it.solved }
    val firstTryCount: Int get() = outcomes.count { it.solvedOnFirstTry }
    val stars: Int get() = Stars.forAccuracy(accuracy)
}

/**
 * Zustandsautomat für eine Lektion: Theorie-Happen → Aufgaben (Niveau aufsteigend) → Auswertung.
 * Wertung: erster Versuch 100 %, später 50 %, Lösung angezeigt 0 %.
 */
class LessonSession(val mode: Mode, val title: String, val theory: List<TheoryCard>, tasks: List<LearningTask>) {
    sealed interface Mode {
        data class Lesson(val lessonId: String) : Mode
        data class Practice(val topicId: String) : Mode
    }

    sealed interface Phase {
        data class Theory(val page: Int) : Phase
        data class Task(val index: Int) : Phase
        data object Summary : Phase
    }

    companion object {
        const val MAX_ATTEMPTS = 3
        /** Eine Lektion gilt ab 90 % (gewichtete Trefferquote) als bestanden. */
        const val PASS_THRESHOLD = 0.9

        fun of(lesson: app.javaquest.core.Lesson) = LessonSession(Mode.Lesson(lesson.id), lesson.title, lesson.theory, lesson.tasks)
    }

    val tasks: List<LearningTask> = tasks.sortedBy { it.difficulty.level }
    var phase: Phase = when {
        theory.isNotEmpty() -> Phase.Theory(0)
        this.tasks.isNotEmpty() -> Phase.Task(0)
        else -> Phase.Summary
    }
        private set
    val outcomes = mutableListOf<TaskOutcome>()
    var attempts = 0
        private set
    var lastResult: EvaluationResult? = null
        private set
    var isRevealed = false
        private set

    val lessonId: String? get() = (mode as? Mode.Lesson)?.lessonId
    val currentTask: LearningTask? get() = (phase as? Phase.Task)?.let { tasks[it.index] }

    /** Aufgabe erledigt (gelöst oder Lösung gezeigt) – dann geht es nur noch weiter. */
    val isCurrentTaskFinished: Boolean get() = lastResult?.isCorrect == true || isRevealed
    val canRetry: Boolean get() = !isCurrentTaskFinished && lastResult != null && attempts < MAX_ATTEMPTS

    /** Gesamtfortschritt 0…1 über Theorie und Aufgaben. */
    val progress: Double
        get() {
            val steps = (theory.size + tasks.size).toDouble()
            if (steps == 0.0) return 1.0
            return when (val p = phase) {
                is Phase.Theory -> p.page / steps
                is Phase.Task -> (theory.size + p.index + if (isCurrentTaskFinished) 1 else 0) / steps
                Phase.Summary -> 1.0
            }
        }

    fun advanceTheory() {
        val p = phase as? Phase.Theory ?: return
        phase = when {
            p.page + 1 < theory.size -> Phase.Theory(p.page + 1)
            tasks.isEmpty() -> Phase.Summary
            else -> Phase.Task(0)
        }
    }

    fun goBackInTheory() {
        val p = phase as? Phase.Theory ?: return
        if (p.page > 0) phase = Phase.Theory(p.page - 1)
    }

    fun submit(answer: TaskAnswer): EvaluationResult? {
        val task = currentTask ?: return null
        if (isCurrentTaskFinished || attempts >= MAX_ATTEMPTS) return null
        val result = AnswerEvaluator.evaluate(answer, task)
        attempts += 1
        lastResult = result
        if (result.isCorrect) outcomes += TaskOutcome(task, attempts, true, if (attempts == 1) 1.0 else 0.5)
        return result
    }

    /** Setzt nur die angezeigte Rückmeldung zurück, damit erneut geantwortet werden kann. */
    fun prepareRetry() {
        if (canRetry) lastResult = null
    }

    fun revealSolution() {
        val task = currentTask ?: return
        if (isCurrentTaskFinished) return
        isRevealed = true
        outcomes += TaskOutcome(task, maxOf(attempts, 1), false, 0.0)
    }

    /** Das zuletzt abgeschlossene Aufgabenergebnis (für die Speicherung). */
    val finishedOutcome: TaskOutcome?
        get() {
            val task = currentTask ?: return null
            return if (isCurrentTaskFinished) outcomes.lastOrNull { it.taskId == task.id } else null
        }

    fun advanceToNextTask() {
        val p = phase as? Phase.Task ?: return
        if (!isCurrentTaskFinished) return
        attempts = 0
        lastResult = null
        isRevealed = false
        phase = if (p.index + 1 < tasks.size) Phase.Task(p.index + 1) else Phase.Summary
    }

    val summary: LessonSummary get() = LessonSummary(outcomes.toList(), tasks.size)
}

// ---------------------------------------------------------------- Einstufung

data class PlacementAnswer(val task: LearningTask, val result: EvaluationResult)

data class PlacementOutcome(
    val chosenLevel: ExperienceLevel,
    val scorePercent: Int,
    val passed: Boolean,
    val placedLevel: ExperienceLevel,
    val entryModuleId: String,
    val creditedLessonIds: List<String>,
    val creditedAccuracy: Double,
)

/**
 * Adaptiver Einstufungstest (hier: eine Frage mit sechs Lücken). Score = Σ(Niveau × Teilpunkte) / Σ(Niveau).
 * Ab `passThreshold` (65 %) Einstieg im Modul der Stufe, sonst eine Stufe darunter.
 */
class PlacementTest private constructor(course: Course, val level: ExperienceLevel) {
    val questionCount: Int = minOf(course.placement.questionsPerTest, course.placement.pool(level).size)
    val passThreshold: Int = course.placement.passThreshold
    val answers = mutableListOf<PlacementAnswer>()
    var targetDifficulty: Int = Difficulty.clamped(course.placement.startDifficulty).level
        private set
    private val remaining = course.placement.pool(level).toMutableList()
    var currentTask: LearningTask? = null
        private set

    init {
        currentTask = pickNext()
    }

    companion object {
        fun create(course: Course, level: ExperienceLevel): PlacementTest? =
            if (level.requiresPlacement && course.placement.pool(level).isNotEmpty()) PlacementTest(course, level) else null
    }

    val isFinished: Boolean get() = currentTask == null
    val progress: Double get() = answers.size.toDouble() / maxOf(questionCount, 1)

    val scorePercent: Int
        get() {
            val asked = answers.sumOf { it.task.difficulty.weight }
            if (asked <= 0) return 0
            val earned = answers.sumOf { it.task.difficulty.weight * it.result.score }
            return (earned / asked * 100).roundToInt()
        }

    val passed: Boolean get() = scorePercent >= passThreshold

    fun submit(result: EvaluationResult) {
        val task = currentTask ?: return
        answers += PlacementAnswer(task, result)
        targetDifficulty = Difficulty.clamped(task.difficulty.level + if (result.isCorrect) 1 else -1).level
        currentTask = if (answers.size < questionCount) pickNext() else null
    }

    private fun pickNext(): LearningTask? {
        val askedTopics = answers.map { it.task.topicId }.toSet()
        val best = remaining.withIndex().minWithOrNull(compareBy<IndexedValue<LearningTask>>(
            { abs(it.value.difficulty.level - targetDifficulty) },
            { if (it.value.topicId in askedTopics) 1 else 0 },
            { it.index },
        )) ?: return null
        remaining.removeAt(best.index)
        return best.value
    }

    fun outcome(course: Course): PlacementOutcome {
        val score = scorePercent
        val placedLevel = if (score >= passThreshold) level else level.fallback
        val entryModule = course.entryModule(placedLevel) ?: course.modules.first()
        val entryIndex = course.modules.indexOfFirst { it.id == entryModule.id }.coerceAtLeast(0)
        val skipped = course.modules.take(entryIndex).flatMap { it.lessons }.map { it.id }
        return PlacementOutcome(
            chosenLevel = level,
            scorePercent = score,
            passed = score >= passThreshold,
            placedLevel = placedLevel,
            entryModuleId = entryModule.id,
            creditedLessonIds = skipped,
            // Übersprungene Lektionen zählen mit dem Testergebnis, mindestens mit der Schwelle.
            creditedAccuracy = maxOf(score, passThreshold) / 100.0,
        )
    }
}

// ---------------------------------------------------------------- Score & Lernpfad

data class LessonResult(val bestAccuracy: Double, val isCompleted: Boolean, val viaPlacement: Boolean = false) {
    val stars: Int get() = if (isCompleted) Stars.forAccuracy(bestAccuracy) else 0
}

/** Java Master Score 0–1000: jede bestandene Lektion zählt mit Gewicht × Bestwert. */
object MasterScore {
    const val MAXIMUM = 1000

    fun tierFactor(tier: ExperienceLevel) = when (tier) {
        ExperienceLevel.BEGINNER -> 1.0
        ExperienceLevel.INTERMEDIATE -> 1.25
        ExperienceLevel.ADVANCED -> 1.5
    }

    fun compute(course: Course, results: Map<String, LessonResult>): Int {
        var total = 0.0
        var earned = 0.0
        for (module in course.modules) {
            val factor = tierFactor(module.tier)
            for (lesson in module.lessons) {
                val weight = lesson.difficultyWeight * factor
                total += weight
                val result = results[lesson.id]
                if (result != null && result.isCompleted) earned += weight * result.bestAccuracy.coerceIn(0.0, 1.0)
            }
        }
        return if (total > 0) (earned / total * MAXIMUM).roundToInt() else 0
    }
}

data class MasterRank(val title: String, val minimumScore: Int) {
    companion object {
        val all = listOf(
            MasterRank("Neuling", 0),
            MasterRank("Code-Talent", 150),
            MasterRank("Java-Profi", 350),
            MasterRank("Architektur-Ass", 600),
            MasterRank("Java Master", 850),
        )

        fun rank(score: Int) = all.lastOrNull { score >= it.minimumScore } ?: all.first()
        fun next(score: Int) = all.firstOrNull { it.minimumScore > score }

        /** Fortschritt 0…1 innerhalb des aktuellen Rangs. */
        fun progressToNext(score: Int): Double {
            val current = rank(score)
            val next = next(score) ?: return 1.0
            return (score - current.minimumScore).toDouble() / (next.minimumScore - current.minimumScore)
        }
    }
}

sealed interface LessonState {
    data object Locked : LessonState
    data object Current : LessonState
    data class Completed(val stars: Int, val viaPlacement: Boolean) : LessonState

    val isPlayable: Boolean get() = this != Locked
}

data class ModuleProgress(val module: CourseModule, val completedLessons: Int, val isUnlocked: Boolean) {
    val totalLessons: Int get() = module.lessons.size
    val fraction: Double get() = if (totalLessons > 0) completedLessons.toDouble() / totalLessons else 0.0
    val isCompleted: Boolean get() = completedLessons == totalLessons
}

/** Linearer Lernpfad: eine Lektion wird frei, sobald die vorherige abgeschlossen ist. */
object LearningPath {
    fun states(course: Course, results: Map<String, LessonResult>): Map<String, LessonState> {
        val states = LinkedHashMap<String, LessonState>()
        var foundCurrent = false
        for (lesson in course.allLessons) {
            val result = results[lesson.id]
            states[lesson.id] = when {
                result != null && result.isCompleted -> LessonState.Completed(result.stars, result.viaPlacement)
                !foundCurrent -> { foundCurrent = true; LessonState.Current }
                else -> LessonState.Locked
            }
        }
        return states
    }

    fun nextLesson(course: Course, results: Map<String, LessonResult>): Lesson? =
        course.allLessons.firstOrNull { results[it.id]?.isCompleted != true }

    fun moduleProgress(course: Course, results: Map<String, LessonResult>): List<ModuleProgress> {
        val states = states(course, results)
        return course.modules.map { module ->
            ModuleProgress(
                module = module,
                completedLessons = module.lessons.count { results[it.id]?.isCompleted == true },
                isUnlocked = module.lessons.any { states[it.id]?.isPlayable == true },
            )
        }
    }
}

// ---------------------------------------------------------------- Wissensanalyse

data class TopicStats(
    val attempts: Int = 0,
    val weightedCorrect: Double = 0.0,
    val weightedTotal: Double = 0.0,
    val lastPracticed: Instant? = null,
) {
    /** Beherrschung 0…1 mit Laplace-Glättung: wenige Antworten führen nicht sofort zu 0 % oder 100 %. */
    val mastery: Double get() = (weightedCorrect + 1) / (weightedTotal + 2)

    fun recording(difficulty: Difficulty, credit: Double, at: Instant) = TopicStats(
        attempts = attempts + 1,
        weightedCorrect = weightedCorrect + difficulty.weight * credit.coerceIn(0.0, 1.0),
        weightedTotal = weightedTotal + difficulty.weight,
        lastPracticed = at,
    )
}

enum class TopicStatus(val title: String) {
    STRENGTH("Stärken"),
    DEVELOPING("Im Aufbau"),
    GAP("Wissenslücken"),
    UNKNOWN("Noch unbekannt"),
}

data class TopicInsight(val topic: Topic, val status: TopicStatus, val stats: TopicStats, val lessonId: String?) {
    val mastery: Double? get() = if (stats.attempts > 0) stats.mastery else null
}

data class KnowledgeReport(val insights: List<TopicInsight>) {
    fun topics(status: TopicStatus) = insights.filter { it.status == status }
    val strengths get() = topics(TopicStatus.STRENGTH)
    val gaps get() = topics(TopicStatus.GAP).sortedBy { it.mastery ?: 0.0 }
    val developing get() = topics(TopicStatus.DEVELOPING)
    val unknown get() = topics(TopicStatus.UNKNOWN)

    val overallMastery: Double?
        get() = insights.mapNotNull { it.mastery }.takeIf { it.isNotEmpty() }?.average()

    /** Das Thema, das sich als Nächstes am meisten lohnt. */
    val focusTopic: TopicInsight? get() = gaps.firstOrNull() ?: developing.minByOrNull { it.mastery ?: 1.0 }
}

/** Automatische Auswertung: Stärken, Wissenslücken und noch unbekannte Themen. */
object KnowledgeAnalyzer {
    const val STRENGTH_THRESHOLD = 0.75
    const val GAP_THRESHOLD = 0.55

    fun classify(stats: TopicStats): TopicStatus = when {
        stats.attempts == 0 -> TopicStatus.UNKNOWN
        stats.attempts >= 3 && stats.mastery >= STRENGTH_THRESHOLD -> TopicStatus.STRENGTH
        stats.attempts >= 2 && stats.mastery < GAP_THRESHOLD -> TopicStatus.GAP
        else -> TopicStatus.DEVELOPING
    }

    fun report(course: Course, stats: Map<String, TopicStats>) = KnowledgeReport(course.topics.map { topic ->
        val topicStats = stats[topic.id] ?: TopicStats()
        TopicInsight(topic, classify(topicStats), topicStats, course.firstLesson(topic.id)?.id)
    })
}

/** Stellt gezielte Übungssitzungen für ein Thema zusammen. */
object PracticeBuilder {
    fun tasks(topicId: String, course: Course, unlockedLessonIds: Set<String>, limit: Int = 5): List<LearningTask> {
        val candidates = course.allLessons
            .filter { it.id in unlockedLessonIds }
            .flatMap { it.tasks }
            .filter { it.topicId == topicId }
            .sortedBy { it.difficulty.level }
        if (limit <= 1 || candidates.size <= limit) return candidates.take(maxOf(limit, 0))
        val step = (candidates.size - 1).toDouble() / (limit - 1)
        return (0 until limit).map { candidates[(it * step).roundToInt()] }
    }
}
