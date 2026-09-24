package app.javaquest.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.javaquest.core.AttemptRecord
import app.javaquest.core.Course
import app.javaquest.core.GoalHistory
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.KnowledgeAnalyzer
import app.javaquest.core.KnowledgeReport
import app.javaquest.core.LearningPath
import app.javaquest.core.LearningTask
import app.javaquest.core.LevelAnalyzer
import app.javaquest.core.LevelPerformance
import app.javaquest.core.Lesson
import app.javaquest.core.LessonResult
import app.javaquest.core.LessonState
import app.javaquest.core.LessonSummary
import app.javaquest.core.MasterRank
import app.javaquest.core.MasterScore
import app.javaquest.core.ModuleProgress
import app.javaquest.core.PlacementTest
import app.javaquest.core.PracticeBuilder
import app.javaquest.core.ReviewReminder
import app.javaquest.core.SpacedRepetition
import app.javaquest.core.TaskHistory
import app.javaquest.core.TaskOutcome
import app.javaquest.core.TopicStats
import app.javaquest.core.TrainingBuilder
import app.javaquest.core.VariantSelector
import app.javaquest.core.Difficulty
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
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
    // Mit Vorgabewert: Swift lässt ein leeres Feld beim Schreiben ganz weg, und ohne Vorgabe
    // verlangt kotlinx.serialization den Schlüssel. Dann scheiterte jede Mac- oder
    // iPhone-Sicherung mit einer Trainings- oder Übungsantwort (dort gibt es keine Lektion).
    val lessonId: String? = null,
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

    /** Hier bleiben Kopien liegen, bevor der Lernstand zurückgesetzt wird – neben progress.json. */
    val kopienOrdner: Path get() = path.resolveSibling("vor-dem-zuruecksetzen")

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
/** Eine Kopie vom Zurücksetzen: wo sie liegt, wann sie entstand und was drinsteht. */
data class KopieVorZuruecksetzen(val pfad: Path, val erstellt: String?, val stand: ProgressData)

private val KOPIE = Regex("""stand-\d{8}-\d{6}\.json""")

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

    /**
     * Wie jedes Lernziel über die Zeit lief – Grundlage der Wiedervorlage.
     * Die Einstufung bleibt außen vor: Sie sagt nichts darüber, ob ein Lernziel sitzt.
     */
    val goalHistory: Map<String, GoalHistory>
        get() = SpacedRepetition.goals(
            data?.attempts.orEmpty()
                .filter { it.context != AttemptContext.PLACEMENT.raw }
                .map { AttemptRecord(it.taskId, it.credit, Instant.parse(it.date)) },
            course,
        )

    /** Wie viele Lernziele heute zur Wiederholung anstehen. */
    val dueGoalCount: Int get() = SpacedRepetition.due(goalHistory, clock.instant()).size

    /** Die nächsten Erinnerungstermine um 18 Uhr Ortszeit – wie in der Apple- und der Web-App. */
    fun erinnerungsTermine(): List<ReviewReminder.Slot> =
        ReviewReminder.plan(goalHistory.values.map { it.dueDate }, clock.instant(), clock.zone ?: ZoneId.systemDefault())

    /** Wie ein Thema auf den einzelnen Schwierigkeitsstufen läuft. */
    fun levels(topicId: String): List<LevelPerformance> = LevelAnalyzer.levels(course, taskHistory, topicId)

    /** Die Stufen eines Themas, auf denen es hakt – Vorauswahl für „genau das üben“. */
    fun weakDifficulties(topicId: String): Set<Difficulty> = LevelAnalyzer.weakDifficulties(course, taskHistory, topicId)

    /** Wie viele Aufgaben schon im Endlos-Training gelöst oder aufgelöst wurden. */
    val trainingTaskCount: Int get() = data?.attempts?.count { it.context == AttemptContext.TRAINING.raw } ?: 0

    fun trainingTasks(): List<LearningTask> =
        TrainingBuilder.round(trainingPool, topicStats, taskHistory, clock.instant(), goals = goalHistory)

    /** Eine Runde nur über die Lernziele, deren Wiederholung heute ansteht. */
    fun reviewTasks(count: Int = TrainingBuilder.ROUND_SIZE): List<LearningTask> =
        TrainingBuilder.reviewRound(course, taskHistory, goalHistory, topicStats, count, clock.instant())

    /** Selbst zusammengestellte Runde: gewählte Themen und Niveaus, unabhängig vom Lernpfad. */
    fun freeTrainingTasks(topicIds: Set<String>, difficulties: Set<Difficulty>, count: Int): List<LearningTask> =
        TrainingBuilder.freeRound(
            course, topicIds, difficulties, count, topicStats, taskHistory, clock.instant(), goals = goalHistory,
        )

    /** Aufgaben einer Lektion mit passender Variante je Lernziel. */
    fun lessonTasks(lesson: Lesson): List<LearningTask> = VariantSelector.lessonTasks(lesson, course, taskHistory)

    /** Gesehene, richtige und falsche Aufgaben eines Themas – aus dem Aufgaben-Protokoll. */
    fun topicPractice(topicId: String): TopicPractice {
        val attempts = data?.attempts.orEmpty().filter { it.topicId == topicId }
        return TopicPractice(
            seen = attempts.size,
            correct = attempts.count { it.solved },
            firstTry = attempts.count { it.solved && it.tries == 1 },
            lastPracticed = attempts.maxOfOrNull { it.date },
            mastery = topicStats[topicId]?.takeIf { it.attempts > 0 }?.mastery,
        )
    }

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

    // MARK: Sicherung

    /** Der komplette Lernstand als Text zum Wegschreiben. */
    fun sicherungText(): String = Backup.schreiben(data ?: ProgressData(createdAt = now()), now())

    /**
     * Liest eine Sicherung ein und führt sie mit dem vorhandenen Stand zusammen.
     *
     * Es wird nichts überschrieben: Bei jeder Lektion gewinnt das bessere Ergebnis, das
     * Aufgaben-Protokoll wird vereinigt. Rückgabe ist die Zahl der dazugekommenen
     * Aufgaben-Einträge, oder null, wenn die Datei keine JavaQuest-Sicherung ist.
     */
    fun sicherungEinlesen(text: String): Int? {
        val fremd = Backup.lesen(text) ?: return null
        val eigen = data ?: ProgressData(createdAt = now())
        val vorher = eigen.attempts.size
        val vereint = Backup.vereine(eigen, fremd, course)
        commit(vereint)
        return vereint.attempts.size - vorher
    }

    // MARK: Zurücksetzen mit Netz
    //
    // „Alle Fortschritte löschen“ löschte sofort und endgültig. Jetzt bleibt vorher eine Kopie
    // liegen – im Aufbau der Sicherungsdatei, also auch in den anderen Fassungen lesbar. Nur,
    // wenn es etwas zu verlieren gibt; die fünf jüngsten bleiben. Dieselben Regeln wie im Web
    // und auf Apple-Geräten.

    /** Löscht alle Fortschritte; danach startet das Onboarding neu. Vorher wird eine Kopie abgelegt. */
    fun resetAllProgress() {
        val bisher = data
        val ablage = file
        if (ablage != null && bisher != null && (bisher.attempts.isNotEmpty() || bisher.lessonRecords.isNotEmpty())) {
            runCatching {
                Files.createDirectories(ablage.kopienOrdner)
                val stempel = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneOffset.UTC).format(clock.instant())
                Files.writeString(ablage.kopienOrdner.resolve("stand-$stempel.json"), Backup.schreiben(bisher, now()))
                kopien().drop(5).forEach { Files.deleteIfExists(it) }
            }
        }
        runCatching { file?.delete() }
        data = null
    }

    /** Die Kopien vom Zurücksetzen, die jüngste zuerst. */
    fun kopien(): List<Path> {
        val ordner = file?.kopienOrdner ?: return emptyList()
        if (!Files.isDirectory(ordner)) return emptyList()
        return Files.list(ordner).use { dateien ->
            dateien.filter { KOPIE.matches(it.fileName.toString()) }.toList()
        }.sortedByDescending { it.fileName.toString() }
    }

    /** Die jüngste lesbare Kopie samt Zeitpunkt – oder null. */
    fun kopieVorZuruecksetzen(): KopieVorZuruecksetzen? = kopien().firstNotNullOfOrNull { pfad ->
        runCatching { Files.readString(pfad) }.getOrNull()?.let { text ->
            Backup.lesen(text)?.let { KopieVorZuruecksetzen(pfad, Backup.erstellt(text), it) }
        }
    }

    /**
     * Führt die jüngste Kopie mit dem jetzigen Stand zusammen – was seitdem dazukam, bleibt.
     * Danach wird sie beiseitegelegt (umbenannt, nicht gelöscht) und nicht mehr angeboten.
     */
    fun vorZuruecksetzenWiederherstellen(): Boolean {
        val kopie = kopieVorZuruecksetzen() ?: return false
        commit(Backup.vereine(data ?: ProgressData(createdAt = now()), kopie.stand, course))
        runCatching {
            Files.move(kopie.pfad, kopie.pfad.resolveSibling(kopie.pfad.fileName.toString().removeSuffix(".json") + ".wiederhergestellt.json"),
                StandardCopyOption.REPLACE_EXISTING)
        }
        return true
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

/** Übungsstand eines Themas für die Themenübersicht. */
data class TopicPractice(
    val seen: Int,
    val correct: Int,
    val firstTry: Int,
    val lastPracticed: String?,
    val mastery: Double?,
) {
    val wrong: Int get() = maxOf(seen - correct, 0)
    val successRate: Double get() = if (seen > 0) correct.toDouble() / seen else 0.0
}
