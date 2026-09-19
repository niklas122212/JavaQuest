package app.javaquest.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.javaquest.core.Course
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.KnowledgeAnalyzer
import app.javaquest.core.KnowledgeReport
import app.javaquest.core.LearningPath
import app.javaquest.core.LearningTask
import app.javaquest.core.Lesson
import app.javaquest.core.LessonResult
import app.javaquest.core.LessonState
import app.javaquest.core.LessonSummary
import app.javaquest.core.MasterRank
import app.javaquest.core.MasterScore
import app.javaquest.core.ModuleProgress
import app.javaquest.core.PlacementTest
import app.javaquest.core.PracticeBuilder
import app.javaquest.core.TaskHistory
import app.javaquest.core.TaskOutcome
import app.javaquest.core.TopicStats
import app.javaquest.core.TrainingBuilder
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

// ---------------------------------------------------------------- Gespeicherte Daten

@Serializable
data class LessonRecord(
    val bestAccuracy: Double = 0.0,
    val lastAccuracy: Double = 0.0,
    val playCount: Int = 0,
    val isCompleted: Boolean = false,
    val completedViaPlacement: Boolean = false,
    val firstCompletedAt: String? = null,
    val lastPlayedAt: String? = null,
)

@Serializable
data class TopicMastery(
    val attempts: Int = 0,
    val firstTryCorrect: Int = 0,
    val weightedCorrect: Double = 0.0,
    val weightedTotal: Double = 0.0,
    val lastPracticedAt: String? = null,
)

@Serializable
data class TaskAttempt(
    val taskId: String,
    val topicId: String,
    val lessonId: String?,
    val context: String,
    val difficulty: Int,
    val credit: Double,
    val solved: Boolean,
    val tries: Int,
    val date: String,
)

@Serializable
data class ScoreSnapshot(val date: String, val score: Int, val reason: String)

/** Der komplette Lernstand – eine JSON-Datei, nur auf diesem Rechner. */
@Serializable
data class ProgressData(
    val schemaVersion: Int = 1,
    val createdAt: String,
    val experienceLevel: String = ExperienceLevel.BEGINNER.raw,
    val placedLevel: String? = null,
    val placementScore: Int? = null,
    val onboardingCompleted: Boolean = false,
    val masterScore: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val lastActiveDay: String? = null,
    val lessonRecords: Map<String, LessonRecord> = emptyMap(),
    val topicMasteries: Map<String, TopicMastery> = emptyMap(),
    val attempts: List<TaskAttempt> = emptyList(),
    val scoreHistory: List<ScoreSnapshot> = emptyList(),
)

enum class AttemptContext(val raw: String) { LESSON("lesson"), PRACTICE("practice"), TRAINING("training"), PLACEMENT("placement") }

/** Ergebnis einer Score-Neuberechnung („+36 Punkte“, Rangaufstieg). */
data class ScoreChange(val before: Int, val after: Int, val newRank: MasterRank?) {
    val delta: Int get() = after - before
}

/** Liest und schreibt die Fortschrittsdatei. Schreiben erfolgt atomar (Temp-Datei + Umbenennen). */
class ProgressFile(val path: Path) {
    private val json = Json { ignoreUnknownKeys = true; prettyPrint = true; encodeDefaults = true }

    fun load(): ProgressData? = runCatching {
        if (Files.exists(path)) json.decodeFromString(ProgressData.serializer(), Files.readString(path)) else null
    }.getOrNull()

    fun save(data: ProgressData) {
        Files.createDirectories(path.parent)
        val temp = path.resolveSibling(path.fileName.toString() + ".tmp")
        Files.writeString(temp, json.encodeToString(ProgressData.serializer(), data))
        Files.move(temp, path, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
    }

    fun delete() {
        Files.deleteIfExists(path)
    }

    companion object {
        /** Windows: %APPDATA%\JavaQuest · macOS: ~/Library/Application Support/JavaQuest · sonst ~/.local/share. */
        fun defaultLocation(): ProgressFile {
            System.getProperty("javaquest.dataDir")?.let { return ProgressFile(Path.of(it, "progress.json")) }
            val os = System.getProperty("os.name").lowercase()
            val home = System.getProperty("user.home")
            val dir = when {
                "win" in os -> Path.of(System.getenv("APPDATA") ?: "$home\\AppData\\Roaming", "JavaQuest")
                "mac" in os -> Path.of(home, "Library", "Application Support", "JavaQuest")
                else -> Path.of(System.getenv("XDG_DATA_HOME") ?: "$home/.local/share", "JavaQuest")
            }
            return ProgressFile(dir.resolve("progress.json"))
        }
    }
}

// ---------------------------------------------------------------- Store

/**
 * Zentrale Schnittstelle zwischen Oberfläche und gespeichertem Lernstand.
 * Abgeleitete Werte (Score, Lernpfad, Analyse) kommen aus der reinen Logik in `core`.
 */
class ProgressStore(
    val course: Course,
    private val file: ProgressFile?,
    private val clock: Clock = Clock.systemDefaultZone(),
) {
    var data: ProgressData? by mutableStateOf(file?.load())
        private set
    var lastSaveError: String? by mutableStateOf(null)
        private set

    val needsOnboarding: Boolean get() = data?.onboardingCompleted != true

    // MARK: Abgeleitete Werte

    val lessonResults: Map<String, LessonResult>
        get() = data?.lessonRecords?.mapValues { (_, r) -> LessonResult(r.bestAccuracy, r.isCompleted, r.completedViaPlacement) } ?: emptyMap()

    val topicStats: Map<String, TopicStats>
        get() = data?.topicMasteries?.mapValues { (_, m) ->
            TopicStats(m.attempts, m.weightedCorrect, m.weightedTotal, m.lastPracticedAt?.let(Instant::parse))
        } ?: emptyMap()

    val lessonStates: Map<String, LessonState> get() = LearningPath.states(course, lessonResults)
    val moduleProgress: List<ModuleProgress> get() = LearningPath.moduleProgress(course, lessonResults)
    val nextLesson: Lesson? get() = LearningPath.nextLesson(course, lessonResults)
    val knowledgeReport: KnowledgeReport get() = KnowledgeAnalyzer.report(course, topicStats)

    val masterScore: Int get() = data?.masterScore ?: 0
    val rank: MasterRank get() = MasterRank.rank(masterScore)
    val nextRank: MasterRank? get() = MasterRank.next(masterScore)
    val progressToNextRank: Double get() = MasterRank.progressToNext(masterScore)
    val scoreHistory: List<Int> get() = data?.scoreHistory?.map { it.score } ?: emptyList()

    val experienceLevel: ExperienceLevel get() = ExperienceLevel.fromRaw(data?.experienceLevel) ?: ExperienceLevel.BEGINNER
    val placedLevel: ExperienceLevel? get() = ExperienceLevel.fromRaw(data?.placedLevel)

    /** Serie zählt nur, wenn heute oder gestern gelernt wurde. */
    val displayedStreak: Int
        get() {
            val d = data ?: return 0
            val last = d.lastActiveDay?.let(LocalDate::parse) ?: return 0
            return if (ChronoUnit.DAYS.between(last, today()) <= 1) d.currentStreak else 0
        }

    val completedLessonCount: Int get() = lessonResults.values.count { it.isCompleted }
    val solvedTaskCount: Int get() = data?.attempts?.count { it.solved } ?: 0

    /** Anteil der beim ersten Versuch gelösten Aufgaben (ohne Einstufung). */
    val firstTryRate: Double?
        get() {
            val relevant = data?.attempts?.filter { it.context != AttemptContext.PLACEMENT.raw } ?: return null
            if (relevant.isEmpty()) return null
            return relevant.count { it.solved && it.tries == 1 }.toDouble() / relevant.size
        }

    val unlockedLessonIds: Set<String> get() = lessonStates.filterValues { it.isPlayable }.keys

    fun practiceTasks(topicId: String): List<LearningTask> = PracticeBuilder.tasks(topicId, course, unlockedLessonIds)

    // MARK: Endlos-Training

    val completedLessonIds: Set<String> get() = lessonResults.filterValues { it.isCompleted }.keys

    /** Alle Aufgaben, die im Endlos-Training vorkommen können. */
    val trainingPool: List<LearningTask> get() = TrainingBuilder.pool(course, completedLessonIds)

    /** Wie jede Aufgabe zuletzt lief (aus dem Aufgaben-Protokoll). */
    val taskHistory: Map<String, TaskHistory>
        get() {
            val history = mutableMapOf<String, TaskHistory>()
            for (attempt in data?.attempts.orEmpty().sortedBy { it.date }) {
                val count = (history[attempt.taskId]?.attempts ?: 0) + 1
                history[attempt.taskId] = TaskHistory(count, attempt.credit, Instant.parse(attempt.date))
            }
            return history
        }

    /** Wie viele Aufgaben schon im Endlos-Training gelöst oder aufgelöst wurden. */
    val trainingTaskCount: Int get() = data?.attempts?.count { it.context == AttemptContext.TRAINING.raw } ?: 0

    fun trainingTasks(): List<LearningTask> = TrainingBuilder.round(trainingPool, topicStats, taskHistory, clock.instant())

    // MARK: Onboarding & Einstufung

    /** Schließt das Onboarding ab; eine Einstufung fließt in die Analyse ein und rechnet Lektionen an. */
    fun completeOnboarding(level: ExperienceLevel, placement: PlacementTest?) {
        var d = (data ?: ProgressData(createdAt = now())).copy(experienceLevel = level.raw)
        if (placement != null) {
            for (answer in placement.answers) {
                d = store(d, TaskOutcome(answer.task, 1, answer.result.isCorrect, answer.result.score), null, AttemptContext.PLACEMENT)
            }
            val outcome = placement.outcome(course)
            val records = d.lessonRecords.toMutableMap()
            for (lessonId in outcome.creditedLessonIds) {
                val record = records[lessonId] ?: LessonRecord()
                records[lessonId] = record.copy(
                    isCompleted = true,
                    completedViaPlacement = true,
                    bestAccuracy = maxOf(record.bestAccuracy, outcome.creditedAccuracy),
                    firstCompletedAt = record.firstCompletedAt ?: now(),
                )
            }
            d = d.copy(placementScore = outcome.scorePercent, placedLevel = outcome.placedLevel.raw, lessonRecords = records)
        } else {
            d = d.copy(placedLevel = ExperienceLevel.BEGINNER.raw)
        }
        d = touchStreak(d.copy(onboardingCompleted = true))
        commit(recomputeScore(d, if (placement == null) "start" else "placement").first)
    }

    // MARK: Lernen

    /** Speichert eine abgeschlossene Aufgabe (gelöst oder Lösung angezeigt). */
    fun record(outcome: TaskOutcome, lessonId: String?, context: AttemptContext) {
        val d = data ?: return
        commit(touchStreak(store(d, outcome, lessonId, context)))
    }

    /** Schließt eine Lektion ab. Nur bestandene Lektionen zählen, und es zählt der Bestwert. */
    fun completeLesson(lessonId: String, summary: LessonSummary): ScoreChange? {
        val d = data ?: return null
        var record = (d.lessonRecords[lessonId] ?: LessonRecord()).let {
            it.copy(playCount = it.playCount + 1, lastAccuracy = summary.accuracy, lastPlayedAt = now())
        }
        if (summary.passed) {
            record = record.copy(
                bestAccuracy = maxOf(record.bestAccuracy, summary.accuracy),
                isCompleted = true,
                completedViaPlacement = false,
                firstCompletedAt = record.firstCompletedAt ?: now(),
            )
        }
        val (updated, change) = recomputeScore(d.copy(lessonRecords = d.lessonRecords + (lessonId to record)), lessonId)
        commit(updated)
        return change
    }

    /** Löscht alle Fortschritte; danach startet das Onboarding neu. */
    fun resetAllProgress() {
        runCatching { file?.delete() }
        data = null
    }

    // MARK: Intern

    private fun store(d: ProgressData, outcome: TaskOutcome, lessonId: String?, context: AttemptContext): ProgressData {
        val attempt = TaskAttempt(
            taskId = outcome.taskId,
            topicId = outcome.topicId,
            lessonId = lessonId,
            context = context.raw,
            difficulty = outcome.difficulty.level,
            credit = outcome.credit,
            solved = outcome.solved,
            tries = outcome.attempts,
            date = now(),
        )
        val mastery = d.topicMasteries[outcome.topicId] ?: TopicMastery()
        val stats = TopicStats(mastery.attempts, mastery.weightedCorrect, mastery.weightedTotal)
            .recording(outcome.difficulty, outcome.credit, clock.instant())
        val updated = mastery.copy(
            attempts = stats.attempts,
            weightedCorrect = stats.weightedCorrect,
            weightedTotal = stats.weightedTotal,
            lastPracticedAt = now(),
            firstTryCorrect = mastery.firstTryCorrect + if (outcome.solvedOnFirstTry) 1 else 0,
        )
        return d.copy(attempts = d.attempts + attempt, topicMasteries = d.topicMasteries + (outcome.topicId to updated))
    }

    private fun recomputeScore(d: ProgressData, reason: String): Pair<ProgressData, ScoreChange> {
        val before = d.masterScore
        val results = d.lessonRecords.mapValues { (_, r) -> LessonResult(r.bestAccuracy, r.isCompleted, r.completedViaPlacement) }
        val after = MasterScore.compute(course, results)
        val history = if (after != before || d.scoreHistory.isEmpty()) d.scoreHistory + ScoreSnapshot(now(), after, reason) else d.scoreHistory
        val newRank = MasterRank.rank(after).takeIf { it != MasterRank.rank(before) }
        return d.copy(masterScore = after, scoreHistory = history) to ScoreChange(before, after, newRank)
    }

    private fun touchStreak(d: ProgressData): ProgressData {
        val today = today()
        val last = d.lastActiveDay?.let(LocalDate::parse)
        val streak = when {
            last == null -> 1
            ChronoUnit.DAYS.between(last, today) <= 0 -> return d
            ChronoUnit.DAYS.between(last, today) == 1L -> d.currentStreak + 1
            else -> 1
        }
        return d.copy(currentStreak = streak, longestStreak = maxOf(d.longestStreak, streak), lastActiveDay = today.toString())
    }

    private fun commit(updated: ProgressData) {
        data = updated
        lastSaveError = try {
            file?.save(updated)
            null
        } catch (e: Exception) {
            e.message ?: "Speichern fehlgeschlagen"
        }
    }

    private fun now(): String = clock.instant().toString()
    private fun today(): LocalDate = LocalDate.ofInstant(clock.instant(), clock.zone ?: ZoneId.systemDefault())
}
