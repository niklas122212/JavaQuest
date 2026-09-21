package app.javaquest.core

import java.time.Duration
import java.time.Instant
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.random.Random

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
    /**
     * Zweiter Stern auf halbem Weg zwischen Bestehensgrenze und fehlerfrei –
     * so bleiben die Stufen sinnvoll, egal wie die Grenze eingestellt ist.
     */
    val twoStarThreshold: Double get() = LessonSession.PASS_THRESHOLD + (1 - LessonSession.PASS_THRESHOLD) / 2

    /** Bestanden = 1 Stern, deutlich darüber = 2 Sterne, fehlerfrei = 3 Sterne. */
    fun forAccuracy(accuracy: Double): Int = when {
        accuracy >= 0.999 -> 3
        accuracy >= twoStarThreshold -> 2
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
        /** Endlos-Training: gemischte Runde über alle abgeschlossenen Lektionen. */
        data object Training : Mode
    }

    sealed interface Phase {
        data class Theory(val page: Int) : Phase
        data class Task(val index: Int) : Phase
        data object Summary : Phase
    }

    companion object {
        const val MAX_ATTEMPTS = 3
        /**
         * Eine Lektion gilt ab 69 % (gewichtete Trefferquote) als bestanden.
         * Einzige Quelle für die Bestehensgrenze – Sterne und Anzeigetexte leiten sich davon ab.
         */
        const val PASS_THRESHOLD = 0.69

        /** Bestehensgrenze als ganze Prozentzahl für Anzeigetexte („69 %“). */
        val passPercent: Int get() = kotlin.math.round(PASS_THRESHOLD * 100).toInt()

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

/**
 * Wählt aus Aufgaben-Varianten aus: Aufgaben mit derselben `variantGroup` fragen dasselbe
 * Lernziel auf verschiedene Weise ab. Pro Sitzung kommt eine davon dran – erst ungesehene,
 * nach einem Fehler bewusst eine andere, sonst die am längsten nicht gezeigte.
 */
object VariantSelector {
    fun groups(tasks: List<LearningTask>): List<Pair<String, List<LearningTask>>> =
        tasks.groupBy { it.groupKey }.toList()

    fun pick(variants: List<LearningTask>, history: Map<String, TaskHistory>): LearningTask? {
        val first = variants.firstOrNull() ?: return null
        if (variants.size == 1) return first

        val unseen = variants.filter { history[it.id] == null }
        if (unseen.isNotEmpty()) return unseen.minByOrNull { it.difficulty.level }

        val newest = variants.maxByOrNull { history[it.id]?.lastDate ?: Instant.EPOCH } ?: first
        val others = variants.filter { it.id != newest.id }.sortedBy { history[it.id]?.lastDate ?: Instant.EPOCH }
        return others.firstOrNull() ?: newest
    }

    /** Eine Aufgabe je Lernziel. */
    fun collapse(tasks: List<LearningTask>, history: Map<String, TaskHistory>): List<LearningTask> =
        groups(tasks).mapNotNull { (_, variants) -> pick(variants, history) }

    /** Die Aufgaben einer Lektion, mit passender Variante je Lernziel. */
    fun lessonTasks(lesson: Lesson, course: Course, history: Map<String, TaskHistory>): List<LearningTask> {
        val groupKeys = lesson.tasks.map { it.groupKey }.toSet()
        val extras = course.taskPool.filter { it.groupKey in groupKeys }
        return collapse(lesson.tasks + extras, history).sortedBy { it.difficulty.level }
    }
}

/** Stellt gezielte Übungssitzungen für ein Thema zusammen. */
object PracticeBuilder {
    fun tasks(
        topicId: String,
        course: Course,
        unlockedLessonIds: Set<String>,
        limit: Int = 5,
        history: Map<String, TaskHistory> = emptyMap(),
    ): List<LearningTask> {
        val unlocked = course.allLessons.filter { it.id in unlockedLessonIds }
        val unlockedTopics = unlocked.flatMap { it.topicIds }.toSet()
        val fromLessons = unlocked.flatMap { it.tasks }.filter { it.topicId == topicId }
        // Aus dem Pool nur Themen, die im Lernpfad schon dran waren – das freie Training
        // (siehe TrainingBuilder.freePool) umgeht diese Sperre bewusst.
        val fromPool = if (topicId in unlockedTopics) course.taskPool.filter { it.topicId == topicId } else emptyList()
        val candidates = VariantSelector.collapse(fromLessons + fromPool, history)
            .sortedBy { it.difficulty.level }
        if (limit <= 1 || candidates.size <= limit) return candidates.take(maxOf(limit, 0))
        val step = (candidates.size - 1).toDouble() / (limit - 1)
        return (0 until limit).map { candidates[(it * step).roundToInt()] }
    }
}

// ---------------------------------------------------------------- Endlos-Training

/** Wie eine Aufgabe zuletzt lief – für die Auswahl im Endlos-Training. */
data class TaskHistory(val attempts: Int, val lastCredit: Double, val lastDate: Instant)

/**
 * Endlos-Training: gemischte Runden über alle abgeschlossenen Lektionen.
 *
 * Jede Aufgabe bekommt ein Gewicht – je höher, desto eher kommt sie dran:
 * schwaches Thema bis zu +3, noch nie geübt +2, zuletzt nicht (voll) gelöst bis zu +3,
 * lange nicht gesehen bis zu +2 (eine Woche = +1); heute schon fehlerfrei gelöst: nur ein Drittel.
 * Gezogen wird ohne Zurücklegen; die Runde steigt im Niveau an.
 */
object TrainingBuilder {
    const val ROUND_SIZE = 8

    /**
     * Trainiert wird nur, was schon gelernt ist: Aufgaben abgeschlossener Lektionen –
     * dazu die Übungsaufgaben aus dem Pool zu den Themen dieser Lektionen.
     */
    fun pool(course: Course, completedLessonIds: Set<String>): List<LearningTask> {
        val lessons = course.allLessons.filter { it.id in completedLessonIds }
        val learnedTopics = lessons.flatMap { it.tasks }.map { it.topicId }.toSet()
        return lessons.flatMap { it.tasks } + course.taskPool.filter { it.topicId in learnedTopics }
    }

    /**
     * Aufgabentopf für das freie Training: nur die gewählten Themen, optional auf Niveaus begrenzt.
     * Bewusst ohne Rücksicht auf den Lernpfad – jedes Thema ist jederzeit übbar.
     */
    fun freePool(course: Course, topicIds: Set<String>, difficulties: Set<Difficulty> = emptySet()): List<LearningTask> =
        course.practiceableTasks.filter { task ->
            (topicIds.isEmpty() || task.topicId in topicIds) &&
                (difficulties.isEmpty() || task.difficulty in difficulties)
        }

    /** Eine Runde freies Training: eigene Themen, Niveaus und Anzahl. */
    fun freeRound(
        course: Course,
        topicIds: Set<String>,
        difficulties: Set<Difficulty> = emptySet(),
        count: Int = ROUND_SIZE,
        topicStats: Map<String, TopicStats> = emptyMap(),
        history: Map<String, TaskHistory> = emptyMap(),
        now: Instant = Instant.now(),
        random: Random = Random.Default,
    ): List<LearningTask> = round(
        freePool(course, topicIds, difficulties), topicStats, history, now, count, random,
    )

    fun weight(task: LearningTask, topicStats: Map<String, TopicStats>, history: Map<String, TaskHistory>, now: Instant): Double {
        var weight = 1.0
        val mastery = topicStats[task.topicId]?.takeIf { it.attempts > 0 }?.mastery ?: 0.5
        weight += (1 - mastery) * 3
        val past = history[task.id] ?: return weight + 2
        weight += (1 - past.lastCredit.coerceIn(0.0, 1.0)) * 3
        val days = maxOf(Duration.between(past.lastDate, now).toMillis() / 86_400_000.0, 0.0)
        weight += minOf(days, 14.0) / 7
        if (days < 1 && past.lastCredit >= 1) weight /= 3
        return weight
    }

    /** Eine Runde mit bis zu [size] verschiedenen Aufgaben. Gleicher Zufall → gleiche Runde (für Tests). */
    fun round(
        pool: List<LearningTask>,
        topicStats: Map<String, TopicStats>,
        history: Map<String, TaskHistory>,
        now: Instant = Instant.now(),
        size: Int = ROUND_SIZE,
        random: Random = Random.Default,
    ): List<LearningTask> {
        // Je Lernziel tritt nur eine Variante an – so kommt dieselbe Frage nicht zweimal
        // in einer Runde, und nach einem Fehler kommt beim nächsten Mal eine andere.
        val candidates = VariantSelector.collapse(pool, history)
            .map { it to weight(it, topicStats, history, now) }.toMutableList()
        val chosen = mutableListOf<LearningTask>()
        while (chosen.size < size && candidates.isNotEmpty()) {
            var ticket = random.nextDouble() * candidates.sumOf { it.second }
            var index = candidates.lastIndex
            for ((i, candidate) in candidates.withIndex()) {
                ticket -= candidate.second
                if (ticket <= 0) { index = i; break }
            }
            chosen += candidates.removeAt(index).first
        }
        return chosen.sortedBy { it.difficulty.level }
    }
}
