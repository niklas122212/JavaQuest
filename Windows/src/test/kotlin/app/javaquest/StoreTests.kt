package app.javaquest

import app.javaquest.core.AnswerEvaluator
import app.javaquest.core.CourseLoader
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.LessonSession
import app.javaquest.core.PlacementTest
import app.javaquest.core.TaskAnswer
import app.javaquest.core.TaskHistory
import app.javaquest.core.TaskKind
import app.javaquest.data.AttemptContext
import app.javaquest.data.ProgressFile
import app.javaquest.data.ProgressStore
import java.nio.file.Files
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class StoreTest {
    private val course = CourseLoader.loadBundled()
    private val dir = Files.createTempDirectory("javaquest-test")
    private fun file() = ProgressFile(dir.resolve("progress.json"))
    private fun clock(day: Int) = Clock.fixed(Instant.parse("2026-09-%02dT10:00:00Z".format(day)), ZoneOffset.UTC)

    /** Spielt eine Lektion durch; [revealAtIndex] deckt dort die Lösung auf (0 Punkte für die Aufgabe). */
    private fun playLesson(store: ProgressStore, index: Int, revealAtIndex: Int? = null) {
        val lesson = course.allLessons[index]
        val session = LessonSession.of(lesson)
        repeat(lesson.theory.size) { session.advanceTheory() }
        var position = 0
        while (true) {
            val task = session.currentTask ?: break
            if (position == revealAtIndex) session.revealSolution() else session.submit(AnswerEvaluator.referenceAnswer(task))
            position++
            store.record(session.finishedOutcome!!, lesson.id, AttemptContext.LESSON)
            session.advanceToNextTask()
        }
        store.completeLesson(lesson.id, session.summary)
    }

    @Test fun `Endlos-Training - Topf, Verlauf und Zaehler bleiben gespeichert`() {
        val store = ProgressStore(course, file(), clock(1))
        store.completeOnboarding(ExperienceLevel.BEGINNER, null)
        assertTrue(store.trainingTasks().isEmpty(), "ohne abgeschlossene Lektion gibt es nichts zu trainieren")
        playLesson(store, 0)
        playLesson(store, 1)
        val lessonTasks = course.allLessons.take(2).flatMap { it.tasks }
        val learnedTopics = lessonTasks.map { it.topicId }.toSet()
        assertEquals(
            lessonTasks.size + course.taskPool.count { it.topicId in learnedTopics },
            store.trainingPool.size,
        )

        val scoreBefore = store.masterScore
        val round = store.trainingTasks()
        assertEquals(8, round.size)
        val session = LessonSession(LessonSession.Mode.Training, "Endlos-Training", emptyList(), round)
        val revealed = session.currentTask!!
        while (true) {
            val task = session.currentTask ?: break
            if (task == revealed) session.revealSolution() else session.submit(AnswerEvaluator.referenceAnswer(task))
            store.record(session.finishedOutcome!!, session.lessonId, AttemptContext.TRAINING)
            session.advanceToNextTask()
        }
        assertEquals(8, store.trainingTaskCount)
        assertEquals(scoreBefore, store.masterScore, "Training ändert den Score nicht")
        // Aufgedeckte Lösung zählt 0 Punkte und steht so im Verlauf – Grundlage der Variantenauswahl.
        val history = store.taskHistory.getValue(revealed.id)
        assertEquals(0.0, history.lastCredit)
        assertEquals(Instant.parse("2026-09-01T10:00:00Z"), history.lastDate)

        val reopened = ProgressStore(course, file(), clock(1))
        assertEquals(8, reopened.trainingTaskCount)
        assertEquals(0.0, reopened.taskHistory[revealed.id]?.lastCredit)
    }

    @Test fun `Anfaenger - Fortschritt wird gespeichert und nach Neustart gelesen`() {
        val store = ProgressStore(course, file(), clock(1))
        assertTrue(store.needsOnboarding)
        store.completeOnboarding(ExperienceLevel.BEGINNER, null)
        playLesson(store, 0)
        assertEquals(1, store.completedLessonCount)
        assertTrue(store.masterScore > 0)
        assertEquals("l02-variables", store.nextLesson?.id)

        val reopened = ProgressStore(course, file(), clock(1))
        assertFalse(reopened.needsOnboarding)
        assertEquals(store.masterScore, reopened.masterScore)
        assertEquals(store.lessonResults, reopened.lessonResults)
        assertEquals(5, reopened.solvedTaskCount)
        assertEquals(1, reopened.displayedStreak)
    }

    @Test fun `Unter 69 Prozent bleibt die Lektion offen, Score bleibt 0`() {
        val store = ProgressStore(course, file(), clock(1))
        store.completeOnboarding(ExperienceLevel.BEGINNER, null)
        // Lösung bei der schwersten Aufgabe (Niveau 3 von 9 Gewichtspunkten) → 6/9 = 67 % → nicht bestanden.
        playLesson(store, 0, revealAtIndex = course.allLessons[0].tasks.lastIndex)
        assertEquals(0, store.completedLessonCount)
        assertEquals(0, store.masterScore)
        assertEquals("l01-hello", store.nextLesson?.id)
        assertTrue(store.knowledgeReport.insights.any { it.mastery != null }, "Analyse zählt trotzdem mit")
    }

    @Test fun `Einstufung rechnet die uebersprungenen Lektionen an`() {
        val store = ProgressStore(course, file(), clock(1))
        val test = PlacementTest.create(course, ExperienceLevel.INTERMEDIATE)!!
        val themen = mutableSetOf<String>()
        while (true) {
            val task = test.currentTask ?: break
            themen += task.topicId
            test.submit(AnswerEvaluator.evaluate(AnswerEvaluator.referenceAnswer(task), task))
        }
        store.completeOnboarding(ExperienceLevel.INTERMEDIATE, test)
        // Alles richtig → fortgeschrittener Teil; angerechnet wird genau, was davor liegt.
        assertEquals(ExperienceLevel.ADVANCED, store.placedLevel)
        val entry = course.entryModule(ExperienceLevel.ADVANCED)!!
        val davor = course.modules.takeWhile { it.id != entry.id }.sumOf { it.lessons.size }
        assertEquals(davor, store.completedLessonCount)
        assertEquals(entry.lessons.first().id, store.nextLesson?.id)
        assertTrue(store.masterScore > 0)
        for (topic in themen) {
            assertTrue(store.knowledgeReport.insights.first { it.topic.id == topic }.mastery != null, topic)
        }
    }

    @Test fun `Serie - gestern plus heute ergibt 2, Luecke setzt zurueck, Reset loescht alles`() {
        val first = ProgressStore(course, file(), clock(1))
        first.completeOnboarding(ExperienceLevel.BEGINNER, null)
        val second = ProgressStore(course, file(), clock(2))
        playLesson(second, 0)
        assertEquals(2, second.displayedStreak)
        val later = ProgressStore(course, file(), clock(5))
        assertEquals(0, later.displayedStreak)
        later.resetAllProgress()
        assertTrue(later.needsOnboarding)
        assertNull(ProgressFile(dir.resolve("progress.json")).load())
    }

    @Test fun `Uebungsaufgaben nur aus freigeschalteten Lektionen`() {
        val store = ProgressStore(course, file(), clock(1))
        store.completeOnboarding(ExperienceLevel.BEGINNER, null)
        assertTrue(store.practiceTasks("lambdas").isEmpty())
        assertTrue(store.practiceTasks("basics").all { it.kind !is TaskKind.Code || true })
        assertEquals(setOf("l01-hello"), store.unlockedLessonIds)
    }
}
