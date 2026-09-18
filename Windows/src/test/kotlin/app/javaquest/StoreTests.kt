package app.javaquest

import app.javaquest.core.AnswerEvaluator
import app.javaquest.core.CourseLoader
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.LessonSession
import app.javaquest.core.PlacementTest
import app.javaquest.core.TaskAnswer
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

    private fun playLesson(store: ProgressStore, index: Int, revealFirst: Boolean = false) {
        val lesson = course.allLessons[index]
        val session = LessonSession.of(lesson)
        repeat(lesson.theory.size) { session.advanceTheory() }
        var first = true
        while (true) {
            val task = session.currentTask ?: break
            if (revealFirst && first) session.revealSolution() else session.submit(AnswerEvaluator.referenceAnswer(task))
            first = false
            store.record(session.finishedOutcome!!, lesson.id, AttemptContext.LESSON)
            session.advanceToNextTask()
        }
        store.completeLesson(lesson.id, session.summary)
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

    @Test fun `Unter 90 Prozent bleibt die Lektion offen, Score bleibt 0`() {
        val store = ProgressStore(course, file(), clock(1))
        store.completeOnboarding(ExperienceLevel.BEGINNER, null)
        playLesson(store, 0, revealFirst = true)  // 8/9 = 89 %
        assertEquals(0, store.completedLessonCount)
        assertEquals(0, store.masterScore)
        assertEquals("l01-hello", store.nextLesson?.id)
        assertTrue(store.knowledgeReport.insights.any { it.mastery != null }, "Analyse zählt trotzdem mit")
    }

    @Test fun `Einstufung rechnet den Grundkurs an`() {
        val store = ProgressStore(course, file(), clock(1))
        val test = PlacementTest.create(course, ExperienceLevel.INTERMEDIATE)!!
        val task = test.currentTask!!
        test.submit(AnswerEvaluator.evaluate(AnswerEvaluator.referenceAnswer(task), task))
        store.completeOnboarding(ExperienceLevel.INTERMEDIATE, test)
        assertEquals(6, store.completedLessonCount)
        assertEquals(course.entryModule(ExperienceLevel.INTERMEDIATE)!!.lessons.first().id, store.nextLesson?.id)
        assertEquals(ExperienceLevel.INTERMEDIATE, store.placedLevel)
        assertTrue(store.masterScore > 0)
        assertTrue(store.knowledgeReport.insights.first { it.topic.id == task.topicId }.mastery != null)
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
