package app.javaquest.core

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.roundToInt

/**
 * Ein gespeicherter Versuch mit allen Angaben, die XP und Abzeichen brauchen – Aufgaben und Arena-Missionen.
 * (Die Wiedervorlage nutzt die schlankere Form [AttemptRecord].)
 *
 * Missionen stehen im selben Protokoll wie Aufgaben: `taskId` ist dann die Missions-ID und
 * `credit` die Sterne geteilt durch 3 – wie in der Apple-App. So bleibt das Speicherformat gleich.
 */
data class ActivityRecord(
    val taskId: String,
    val topicId: String,
    val context: String,
    val difficulty: Int,
    val credit: Double,
    val solved: Boolean,
    val tries: Int,
    val date: Instant,
) {
    val isTask: Boolean get() = isTaskContext(context)
    val solvedOnFirstTry: Boolean get() = solved && tries == 1

    /** Sterne einer Mission (0–3). */
    val stars: Int get() = (credit * 3).roundToInt()

    companion object {
        const val PLACEMENT = "placement"
        /** Endlos-, Freies und Wiederholungs-Training. */
        const val TRAINING = "training"
        /** Arena-Mission (aus der Lektion oder der Arena-Übersicht). */
        const val MISSION = "mission"
        /** Die tägliche Mission – zählt zusätzlich als Tageserfolg. */
        const val DAILY = "daily"

        /** Aufgabe oder Mission? Unbekannte Kontexte gelten wie in Swift als Aufgabe. */
        fun isTaskContext(context: String) = context != MISSION && context != DAILY

        /** Hilfswert zum Speichern einer Mission: Sterne → credit. */
        fun credit(stars: Int) = stars.coerceIn(0, 3) / 3.0
    }
}

/** Alles, was Abzeichen, XP und Tagesziele brauchen – abgeleitet aus dem Fortschritt. */
class LearnerFacts(
    val course: Course,
    val catalog: ArenaCatalog,
    attempts: List<ActivityRecord>,
    val lessonResults: Map<String, LessonResult>,
    val longestStreak: Int,
    val zone: ZoneId = ZoneId.systemDefault(),
) {
    /** Chronologisch sortiert. */
    val attempts: List<ActivityRecord> = attempts.sortedBy { it.date }
    val taskAttempts: List<ActivityRecord> by lazy { this.attempts.filter { it.isTask } }

    /** Beste Sterne je Mission (Lektion, Arena oder tägliche Mission zählen gleich). */
    val missionStars: Map<String, Int> by lazy { missionStars(before = Instant.MAX) }

    /** Sterne-Stand zu einem Zeitpunkt – damit die Tagesmission den ganzen Tag dieselbe bleibt. */
    fun missionStars(before: Instant): Map<String, Int> {
        val best = mutableMapOf<String, Int>()
        for (a in attempts) {
            if (!a.isTask && a.solved && a.date.isBefore(before)) best[a.taskId] = maxOf(best[a.taskId] ?: 0, a.stars)
        }
        return best
    }

    val completedLessonIds: Set<String> get() = lessonResults.filterValues { it.isCompleted }.keys

    /** Lektionen, die man selbst bestanden hat (nicht nur per Einstufung angerechnet). */
    val earnedLessonIds: Set<String> get() = lessonResults.filterValues { it.isCompleted && !it.viaPlacement }.keys

    /** Längste Folge von Aufgaben, die beim ersten Versuch saßen (über Lektionen hinweg). */
    val bestCombo: Int by lazy {
        var best = 0
        var current = 0
        for (a in taskAttempts) {
            if (a.context == ActivityRecord.PLACEMENT) continue
            current = if (a.solvedOnFirstTry) current + 1 else 0
            best = maxOf(best, current)
        }
        best
    }

    private val taskTypes by lazy { course.allTasks.associate { it.id to it.type } }

    fun solvedCount(type: TaskType): Int =
        taskAttempts.filter { it.solved && taskTypes[it.taskId] == type }.map { it.taskId }.toSet().size

    // Nicht LocalDate.ofInstant: Das gibt es auf Android erst ab Version 14.
    private fun day(instant: Instant): LocalDate = instant.atZone(zone).toLocalDate()

    val dailyCompletions: Int
        get() = attempts.filter { it.context == ActivityRecord.DAILY && it.solved }.map { day(it.date) }.toSet().size

    fun isDailyDone(day: LocalDate) = dailyMissionId(doneOn = day) != null

    /** Die Tagesmission, die an diesem Tag geschafft wurde. */
    fun dailyMissionId(doneOn: LocalDate): String? =
        attempts.lastOrNull { it.context == ActivityRecord.DAILY && it.solved && day(it.date) == doneOn }?.taskId

    /** Die Mission des Tages – stabil vom Morgen bis zum Abend, auch wenn zwischendurch Sterne dazukommen. */
    fun dailyMission(day: LocalDate, available: List<ArenaMission>): ArenaMission? {
        dailyMissionId(doneOn = day)?.let { done -> catalog.mission(done)?.let { return it } }
        return DailyMission.mission(day, available, missionStars(before = day.atStartOfDay(zone).toInstant()), zone)
    }

    val experience: Int by lazy { Experience.points(this) }
}

// ---------------------------------------------------------------- XP & Level

/**
 * Erfahrungspunkte: Jede gelöste Aufgabe, jede Mission und jeder Tageserfolg bringt XP.
 * Anders als der Master Score (Bestwerte, max. 1000) wächst XP mit jeder Übung weiter.
 */
object Experience {
    const val PER_MISSION_STAR = 25
    const val PER_BOSS_STAR = 50
    const val PER_DAILY = 50
    const val PER_LESSON = 50

    fun points(attempt: ActivityRecord): Int = when {
        !attempt.solved -> 2
        attempt.solvedOnFirstTry -> 10 * attempt.difficulty
        else -> 5 * attempt.difficulty
    }

    fun points(facts: LearnerFacts): Int {
        val tasks = facts.taskAttempts.sumOf { points(it) }
        val missions = facts.missionStars.entries.sumOf { (id, stars) ->
            stars * if (facts.catalog.mission(id)?.kind == MissionKind.BOSS) PER_BOSS_STAR else PER_MISSION_STAR
        }
        return tasks + missions + facts.dailyCompletions * PER_DAILY + facts.earnedLessonIds.size * PER_LESSON
    }

    /** XP, die man insgesamt braucht, um Level `level` zu erreichen (Level 1 ab 0 XP, dann 100, 300, 600 …). */
    fun threshold(level: Int): Int {
        val n = maxOf(level - 1, 0)
        return 50 * n * (n + 1)
    }

    fun level(xp: Int): LevelProgress {
        var level = 1
        while (threshold(level + 1) <= xp) level++
        return LevelProgress(level, xp, threshold(level), threshold(level + 1))
    }
}

data class LevelProgress(val level: Int, val xp: Int, val levelStart: Int, val nextLevelAt: Int) {
    val fraction: Double get() = (xp - levelStart).toDouble() / maxOf(nextLevelAt - levelStart, 1)
    val remaining: Int get() = nextLevelAt - xp
}

// ---------------------------------------------------------------- Abzeichen

/** Symbole der Abzeichen – die Oberfläche wählt dazu ein passendes Bild. */
enum class AchievementIcon { WAVE, FLAG, STAR, BOLT, FLAME, CODE, BUG, PUZZLE, GAME, SPARKLES, SHIELD, CROWN, SUN, REPEAT, ONE, UP, TROPHY }

class Achievement(
    val id: String,
    val title: String,
    val detail: String,
    val icon: AchievementIcon,
    val target: Int,
    private val measure: (LearnerFacts) -> Int,
) {
    fun current(facts: LearnerFacts) = minOf(measure(facts), target)
    fun isUnlocked(facts: LearnerFacts) = measure(facts) >= target

    override fun equals(other: Any?) = other is Achievement && other.id == id
    override fun hashCode() = id.hashCode()

    companion object {
        /** So viele Lektionen hat der Kurs – „Java Master“ verlangt alle (ein Test prüft die Zahl). */
        const val COURSE_LESSONS = 35

        private fun bosses(f: LearnerFacts) = f.missionStars.keys.count { f.catalog.mission(it)?.kind == MissionKind.BOSS }

        val all: List<Achievement> = listOf(
            Achievement("first-task", "Hallo, Welt!", "Löse deine erste Aufgabe.", AchievementIcon.WAVE, 1) { f ->
                f.taskAttempts.filter { it.solved && it.context != ActivityRecord.PLACEMENT }.map { it.taskId }.toSet().size
            },
            Achievement("first-lesson", "Durchstarter", "Schließe deine erste Lektion ab.", AchievementIcon.FLAG, 1) { it.earnedLessonIds.size },
            Achievement("perfect", "Fehlerfrei", "Hol in einer Lektion alle 3 Sterne.", AchievementIcon.STAR, 1) { f ->
                f.lessonResults.values.count { it.isCompleted && !it.viaPlacement && it.stars == 3 }
            },
            Achievement("combo-5", "Combo ×5", "Löse 5 Aufgaben in Folge beim ersten Versuch.", AchievementIcon.BOLT, 5) { it.bestCombo },
            Achievement("combo-10", "Unaufhaltsam", "Löse 10 Aufgaben in Folge beim ersten Versuch.", AchievementIcon.BOLT, 10) { it.bestCombo },
            Achievement("streak-3", "Dranbleiber", "Lerne 3 Tage in Folge.", AchievementIcon.FLAME, 3) { it.longestStreak },
            Achievement("streak-7", "Wochenkrieger", "Lerne 7 Tage in Folge.", AchievementIcon.FLAME, 7) { it.longestStreak },
            Achievement("coder", "Selbst geschrieben", "Löse 5 Aufgaben, in denen du eigenen Code schreibst.", AchievementIcon.CODE, 5) {
                it.solvedCount(TaskType.CODE)
            },
            Achievement("bug-hunter", "Bug-Jäger", "Finde den Fehler in 5 Bug-Jagden.", AchievementIcon.BUG, 5) { it.solvedCount(TaskType.FIND_BUG) },
            Achievement("puzzler", "Puzzle-Profi", "Löse 5 Code-Puzzles.", AchievementIcon.PUZZLE, 5) { it.solvedCount(TaskType.ORDERING) },
            Achievement("first-mission", "Roboter-Pilot", "Schaffe deine erste Arena-Mission.", AchievementIcon.GAME, 1) { it.missionStars.size },
            Achievement("star-collector", "Sternensammler", "Sammle 15 Sterne in der Arena.", AchievementIcon.SPARKLES, 15) { it.missionStars.values.sum() },
            Achievement("boss", "Bossbezwinger", "Besiege ein Boss-Level.", AchievementIcon.SHIELD, 1) { bosses(it) },
            Achievement("all-bosses", "Endgegner", "Besiege alle Boss-Level.", AchievementIcon.CROWN, 3) { bosses(it) },
            Achievement("daily-3", "Tagesheld", "Schaffe 3 tägliche Missionen.", AchievementIcon.SUN, 3) { it.dailyCompletions },
            Achievement("training-10", "Wiederholungstäter", "Löse 10 Aufgaben im Training oder in der Wiederholung.", AchievementIcon.REPEAT, 10) { f ->
                f.taskAttempts.count { it.context == ActivityRecord.TRAINING && it.solved }
            },
            Achievement("module-1", "Grundlagen sitzen", "Schließe Modul 1 ab.", AchievementIcon.ONE, 1) { f ->
                val lessons = f.course.modules.firstOrNull()?.lessons?.map { it.id } ?: emptyList()
                if (lessons.isNotEmpty() && lessons.all { it in f.completedLessonIds }) 1 else 0
            },
            Achievement("level-5", "Aufsteiger", "Erreiche Level 5.", AchievementIcon.UP, 5) { Experience.level(it.experience).level },
            Achievement("course", "Java Master", "Schließe alle Lektionen ab.", AchievementIcon.TROPHY, COURSE_LESSONS) { f ->
                // Nur Lektionen, die im Kurs stehen – alte Einträge aus früheren Kursfassungen zählen nicht.
                f.course.allLessons.count { it.id in f.completedLessonIds }
            },
        )

        fun unlocked(facts: LearnerFacts): Set<String> = all.filter { it.isUnlocked(facts) }.map { it.id }.toSet()
    }
}

// ---------------------------------------------------------------- Tägliche Mission

object DailyMission {
    /** Missionen, die man spielen darf: Lektion erreicht (Lektion/Training) bzw. Modul geschafft (Boss). */
    fun available(catalog: ArenaCatalog, course: Course, results: Map<String, LessonResult>): List<ArenaMission> {
        val states = LearningPath.states(course, results)
        return catalog.missions.filter { isUnlocked(it, course, results, states) }
    }

    fun isUnlocked(
        mission: ArenaMission,
        course: Course,
        results: Map<String, LessonResult>,
        states: Map<String, LessonState> = LearningPath.states(course, results),
    ): Boolean = when (mission.kind) {
        MissionKind.LESSON -> states[mission.lessonId]?.isPlayable == true
        MissionKind.TRAINING -> results[mission.lessonId]?.isCompleted == true
        MissionKind.BOSS -> course.modules.firstOrNull { it.id == mission.moduleId }?.lessons?.all { results[it.id]?.isCompleted == true } == true
    }

    /** Sekunden zwischen 1970 und dem Bezugstag der Apple-Uhr (1. 1. 2001) – für dieselbe Tageszahl wie dort. */
    private const val APPLE_REFERENCE_EPOCH = 978_307_200L

    /**
     * Die Mission des Tages: deterministisch je Kalendertag, bevorzugt Trainingsmissionen und Missionen,
     * die noch nicht alle Sterne haben. Die Tageszahl rechnet wie die Apple-App, damit Mac, iPhone und
     * Windows am selben Tag dieselbe Mission zeigen.
     */
    fun mission(day: LocalDate, available: List<ArenaMission>, stars: Map<String, Int>, zone: ZoneId = ZoneId.systemDefault()): ArenaMission? {
        if (available.isEmpty()) return null
        val unfinished = available.filter { (stars[it.id] ?: 0) < 3 }
        val pool = unfinished.ifEmpty { available }
            .sortedWith(compareBy<ArenaMission>({ if (it.kind == MissionKind.TRAINING) 0 else 1 }, { it.id }))
        // Swift: Int(startOfDay.timeIntervalSinceReferenceDate / 86_400) – Int() schneidet Richtung null ab.
        val seconds = day.atStartOfDay(zone).toEpochSecond() - APPLE_REFERENCE_EPOCH
        val dayNumber = (seconds.toDouble() / 86_400).toLong()
        return pool[Math.floorMod(dayNumber, pool.size.toLong()).toInt()]
    }
}
