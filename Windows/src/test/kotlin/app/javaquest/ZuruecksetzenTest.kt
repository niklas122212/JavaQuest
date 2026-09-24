package app.javaquest

import app.javaquest.core.AnswerEvaluator
import app.javaquest.core.CourseLoader
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.LessonSession
import app.javaquest.data.AttemptContext
import app.javaquest.data.ProgressFile
import app.javaquest.data.ProgressStore
import java.nio.file.Files
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * „Alle Fortschritte löschen“ löschte sofort und endgültig. Jetzt bleibt eine Kopie liegen,
 * die sich wiederherstellen lässt – dieselben Regeln wie im Web und auf Apple-Geräten.
 */
class ZuruecksetzenTest {
    private val course = CourseLoader.loadBundled()
    private val dir = Files.createTempDirectory("javaquest-zuruecksetzen")
    private val file = ProgressFile(dir.resolve("progress.json"))
    private fun uhr(minute: Int) = Clock.fixed(Instant.parse("2026-09-24T10:%02d:00Z".format(minute)), ZoneOffset.UTC)

    /** Erste Lektion komplett richtig beantworten und abschließen – wie in StoreTests. */
    private fun ersteLektion(store: ProgressStore) {
        val lesson = course.allLessons.first()
        val session = LessonSession.of(lesson)
        repeat(lesson.theory.size) { session.advanceTheory() }
        while (true) {
            val task = session.currentTask ?: break
            session.submit(AnswerEvaluator.referenceAnswer(task))
            store.record(session.finishedOutcome!!, lesson.id, AttemptContext.LESSON)
            session.advanceToNextTask()
        }
        store.completeLesson(lesson.id, session.summary)
    }

    @Test
    fun `Zuruecksetzen hebt eine Kopie auf, Wiederherstellen fuehrt zusammen`() {
        val vorher = ProgressStore(course, file, uhr(10))
        vorher.completeOnboarding(ExperienceLevel.BEGINNER, null)
        ersteLektion(vorher)
        val antworten = vorher.data!!.attempts.size
        assertTrue(antworten > 0)

        vorher.resetAllProgress()
        assertNull(vorher.data)
        val kopie = assertNotNull(vorher.kopieVorZuruecksetzen(), "keine Kopie nach dem Zurücksetzen")
        assertEquals(antworten, kopie.stand.attempts.size)
        assertEquals(1, kopie.stand.lessonRecords.values.count { it.isCompleted })

        // Zweites Zurücksetzen ohne Fortschritt: keine neue Kopie, die alte bleibt.
        val danach = ProgressStore(course, file, uhr(12))
        danach.resetAllProgress()
        assertEquals(1, danach.kopien().size)

        // Seitdem neu begonnen, dann wiederhergestellt: beides bleibt.
        danach.completeOnboarding(ExperienceLevel.BEGINNER, null)
        assertTrue(danach.vorZuruecksetzenWiederherstellen())
        assertEquals(1, danach.data!!.lessonRecords.values.count { it.isCompleted })
        assertEquals(antworten, danach.data!!.attempts.size)
        assertNull(danach.kopieVorZuruecksetzen(), "die Kopie wird danach nicht mehr angeboten")
        assertTrue(Files.list(file.kopienOrdner).use { it.anyMatch { p -> p.fileName.toString().endsWith(".wiederhergestellt.json") } },
            "die Kopie wird beiseitegelegt, nicht gelöscht")
    }

    @Test
    fun `die Kopie hat das Format einer Sicherung und ist ueberall lesbar`() {
        val store = ProgressStore(course, file, uhr(10))
        store.completeOnboarding(ExperienceLevel.BEGINNER, null)
        ersteLektion(store)
        store.resetAllProgress()
        val text = Files.readString(store.kopien().first())
        assertTrue(text.contains("\"app\" : \"JavaQuest\"") || text.contains("\"app\": \"JavaQuest\""), text.take(200))
        assertEquals("2026-09-24T10:10:00Z", app.javaquest.data.Backup.erstellt(text))
    }
}
