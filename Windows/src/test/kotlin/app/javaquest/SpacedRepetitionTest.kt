package app.javaquest

import app.javaquest.core.AttemptRecord
import app.javaquest.core.CourseLoader
import app.javaquest.core.Difficulty
import app.javaquest.core.GoalHistory
import app.javaquest.core.LevelAnalyzer
import app.javaquest.core.LevelPerformance
import app.javaquest.core.SpacedRepetition
import app.javaquest.core.TaskHistory
import app.javaquest.core.TrainingBuilder
import app.javaquest.core.VariantSelector
import java.time.Instant
import kotlin.math.abs
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Verteiltes Wiederholen – dieselben Werte und dieselbe Formel wie in der iPhone- und Mac-Fassung.
 * Weicht eine Seite ab, lernt dieselbe Person auf zwei Geräten unterschiedlich.
 */
class SpacedRepetitionTest {
    private val course by lazy { CourseLoader.loadBundled() }

    private fun day(offset: Double): Instant =
        Instant.ofEpochMilli(1_800_000_000_000 + (offset * 86_400_000).toLong())

    /** Zwei Aufgaben desselben Lernziels – für die Prüfung, dass über Varianten hinweg gezählt wird. */
    private val goalWithTwoVariants by lazy {
        course.practiceableTasks.groupBy { it.groupKey }.entries.first { it.value.size >= 2 }
    }

    @Test fun `Die Serie zaehlt ueber Varianten hinweg und ein Fehler setzt sie zurueck`() {
        val (key, tasks) = goalWithTwoVariants
        val records = listOf(
            AttemptRecord(tasks[0].id, 1.0, day(0.0)),
            AttemptRecord(tasks[1].id, 1.0, day(1.0)),
            AttemptRecord(tasks[0].id, 1.0, day(2.0)),
        )
        val goals = SpacedRepetition.goals(records, course)
        assertEquals(3, goals[key]?.streak)
        assertEquals(3, goals[key]?.attempts)

        val danach = SpacedRepetition.goals(records + AttemptRecord(tasks[1].id, 0.0, day(3.0)), course)
        assertEquals(0, danach[key]?.streak)
        assertEquals(0, danach[key]?.box)
        assertEquals(4, danach[key]?.attempts)
    }

    @Test fun `Halbe Wertung zaehlt nicht als Treffer`() {
        val (key, tasks) = goalWithTwoVariants
        val goals = SpacedRepetition.goals(
            listOf(
                AttemptRecord(tasks[0].id, 1.0, day(0.0)),
                AttemptRecord(tasks[1].id, 0.5, day(1.0)),
            ),
            course,
        )
        assertEquals(0, goals[key]?.streak)
    }

    @Test fun `Die Pausen wachsen - 1, 3, 7, 16, 35 Tage`() {
        assertEquals(listOf(0.0, 1.0, 3.0, 7.0, 16.0, 35.0), SpacedRepetition.INTERVAL_DAYS)
        for (streak in 0..8) {
            val goal = GoalHistory(streak, streak, 1.0, day(0.0))
            assertEquals(minOf(streak, 5), goal.box)
            assertEquals(SpacedRepetition.INTERVAL_DAYS[minOf(streak, 5)], goal.intervalDays)
        }
    }

    @Test fun `Vor dem Termin gedaempft, danach angehoben`() {
        val goal = GoalHistory(3, 3, 1.0, day(0.0))
        assertEquals(7.0, goal.intervalDays)
        assertEquals(SpacedRepetition.MINIMUM_FACTOR, SpacedRepetition.factor(goal, day(0.0)))
        val mitte = SpacedRepetition.factor(goal, day(3.5))
        assertTrue(mitte > SpacedRepetition.MINIMUM_FACTOR && mitte < 1.0, "$mitte")
        assertTrue(abs(SpacedRepetition.factor(goal, day(7.0)) - 1.0) < 0.001)
        assertEquals(2.0, SpacedRepetition.factor(goal, day(14.0)))
        assertEquals(2.0, SpacedRepetition.factor(goal, day(400.0)))
    }

    @Test fun `Was zuletzt gehakt hat, wird nicht gedaempft`() {
        val goal = GoalHistory(4, 0, 0.0, day(0.0))
        assertEquals(1.0, SpacedRepetition.factor(goal, day(0.0)))
        assertTrue(goal.isDue(day(0.0)))
        assertEquals(1.0, SpacedRepetition.factor(null, day(0.0)))
    }

    @Test fun `Die Wiederholung nimmt nur, was faellig ist`() {
        val (key, tasks) = goalWithTwoVariants
        val anderes = course.practiceableTasks.first { it.groupKey != key }
        val goals = mapOf(
            key to GoalHistory(3, 3, 1.0, day(1.0)),      // noch sechs Tage Pause
            anderes.groupKey to GoalHistory(2, 2, 1.0, day(-30.0)), // längst überfällig
        )
        val pool = TrainingBuilder.reviewPool(course, goals, day(2.0))
        val keys = pool.map { it.groupKey }.toSet()
        assertFalse(key in keys)
        assertTrue(anderes.groupKey in keys)
        assertTrue(pool.none { it.id in tasks.map { t -> t.id } })
    }

    @Test fun `Gemessen - frisch Gesessenes kommt im Training deutlich seltener dran`() {
        val pool = VariantSelector.collapse(course.practiceableTasks.take(400), emptyMap())
        val frischesZiel = pool[0].groupKey
        val faelligesZiel = pool[1].groupKey
        val jetzt = day(10.0)
        val goals = mapOf(
            frischesZiel to GoalHistory(3, 3, 1.0, jetzt),
            faelligesZiel to GoalHistory(3, 3, 1.0, day(-10.0)),
        )
        val history = mapOf(
            pool[0].id to TaskHistory(3, 1.0, jetzt),
            pool[1].id to TaskHistory(3, 1.0, day(-10.0)),
        )
        var frisch = 0
        var faellig = 0
        val random = Random(42)
        repeat(400) {
            for (task in TrainingBuilder.round(pool, emptyMap(), history, jetzt, 8, random, goals)) {
                if (task.groupKey == frischesZiel) frisch++
                if (task.groupKey == faelligesZiel) faellig++
            }
        }
        assertTrue(faellig > frisch * 3, "faellig $faellig, frisch $frisch")
    }
}

/** Schwächen je Schwierigkeitsstufe – „Vererbung wackelt“ allein hilft niemandem weiter. */
class LevelPerformanceTest {
    private val course by lazy { CourseLoader.loadBundled() }
    private val topicId = "inheritance"

    @Test fun `Leichte Stufen sitzen, schwere nicht - genau das wird sichtbar`() {
        val history = course.tasksForTopic(topicId).associate { task ->
            task.id to TaskHistory(1, if (task.difficulty.level <= 3) 1.0 else 0.0, Instant.now())
        }
        val levels = LevelAnalyzer.levels(course, history, topicId)
        assertEquals(5, levels.size)
        assertEquals(listOf(1, 2, 3, 4, 5), levels.map { it.difficulty.level })
        for (level in levels) {
            assertEquals(level.difficulty.level >= 4, level.isWeak, level.summary)
        }
        assertEquals(
            setOf(Difficulty.DEMANDING, Difficulty.HARD),
            LevelAnalyzer.weakDifficulties(course, history, topicId),
        )
    }

    @Test fun `Ein einzelner Fehlversuch macht noch keine Schwaeche`() {
        assertFalse(LevelPerformance(Difficulty.MEDIUM, 1, 0).isWeak)
        assertTrue(LevelPerformance(Difficulty.MEDIUM, 3, 0).isWeak)
    }

    @Test fun `Genau an der Bestehensgrenze gilt eine Stufe noch als sicher`() {
        assertFalse(LevelPerformance(Difficulty.DEMANDING, 100, 69).isWeak)
        assertTrue(LevelPerformance(Difficulty.DEMANDING, 100, 68).isWeak)
    }

    @Test fun `Stufen ohne Vorgeschichte tauchen nicht auf`() {
        assertTrue(LevelAnalyzer.levels(course, emptyMap(), topicId).isEmpty())
    }
}
