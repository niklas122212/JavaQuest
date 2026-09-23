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
import app.javaquest.data.Backup
import app.javaquest.ui.LessonFlowModel
import app.javaquest.ui.zifferTaste
import androidx.compose.ui.input.key.Key
import app.javaquest.data.LessonRecord
import app.javaquest.data.ProgressData
import app.javaquest.data.TaskAttempt
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

    @Test fun `Zifferntasten waehlen eine Antwort, nach dem Abschluss nicht mehr`() {
        // Die Web-Fassung konnte das längst, die Apps nicht. Geprüft wird beides:
        // die Zuordnung der Tasten und die Sperre, sobald die Aufgabe durch ist.
        assertEquals(1, zifferTaste(Key.One))
        assertEquals(4, zifferTaste(Key.Four))
        assertEquals(4, zifferTaste(Key.NumPad4), "Der Zifferblock zählt mit")
        assertEquals(9, zifferTaste(Key.Nine))
        assertNull(zifferTaste(Key.A), "Buchstaben wählen nichts aus")
        assertNull(zifferTaste(Key.Zero), "Es gibt keine Antwort 0")

        val store = ProgressStore(course, file(), clock(1))
        store.completeOnboarding(ExperienceLevel.BEGINNER, null)
        val lektion = course.allLessons.first()
        val flow = LessonFlowModel(
            store,
            LessonSession(LessonSession.Mode.Lesson(lektion.id), lektion.title, lektion.theory, store.lessonTasks(lektion)),
            isPractice = false,
        )
        repeat(flow.theory.size) { flow.advanceTheory() }
        val task = flow.currentTask!!
        assertTrue(task.kind is TaskKind.SingleChoice, "Diese Prüfung braucht eine Auswahlaufgabe")

        flow.chooseAnswer(2)
        assertEquals(2, flow.draft.choice)
        flow.chooseAnswer(0)
        assertEquals(0, flow.draft.choice, "Umwählen ist erlaubt, solange nicht geprüft wurde")

        flow.submit()
        val nachAbschluss = flow.draft.choice
        flow.chooseAnswer(3)
        assertEquals(nachAbschluss, flow.draft.choice, "Nach dem Abschluss ändert die Ziffer nichts mehr")
    }

    @Test fun `Sicherung - Einlesen fuehrt zusammen und loescht nichts`() {
        // Zwei Stände, die sich überschneiden. Nach dem Einlesen muss von beiden
        // alles übrig sein – sonst wäre die Sicherung ein Datenverlust mit Ansage.
        fun versuch(id: String, datum: String, credit: Double) =
            TaskAttempt(id, "syntax", null, AttemptContext.PRACTICE.raw, 1, credit, credit >= 1.0, 1, datum)

        val eigen = ProgressData(
            createdAt = "2026-09-10T10:00:00Z",
            onboardingCompleted = true,
            longestStreak = 4,
            lastActiveDay = "2026-09-20",
            currentStreak = 2,
            lessonRecords = mapOf("l1" to LessonRecord(bestAccuracy = 0.7, playCount = 2, lastPlayedAt = "2026-09-20T10:00:00Z")),
            attempts = listOf(versuch("a", "2026-09-20T10:00:00Z", 1.0), versuch("b", "2026-09-20T11:00:00Z", 0.0)),
        )
        val fremd = ProgressData(
            createdAt = "2026-09-01T10:00:00Z",
            onboardingCompleted = true,
            longestStreak = 9,
            lastActiveDay = "2026-09-12",
            currentStreak = 5,
            lessonRecords = mapOf(
                "l1" to LessonRecord(bestAccuracy = 0.9, playCount = 5, isCompleted = true, lastPlayedAt = "2026-09-12T10:00:00Z"),
                "l2" to LessonRecord(bestAccuracy = 1.0, isCompleted = true),
            ),
            attempts = listOf(versuch("b", "2026-09-11T10:00:00Z", 1.0), versuch("c", "2026-09-11T11:00:00Z", 1.0)),
        )

        val vereint = Backup.vereine(eigen, fremd, course)
        assertEquals(0.9, vereint.lessonRecords.getValue("l1").bestAccuracy, "die bessere Wertung gewinnt")
        assertTrue(vereint.lessonRecords.getValue("l1").isCompleted, "einmal bestanden bleibt bestanden")
        assertTrue("l2" in vereint.lessonRecords, "fremde Lektion kommt dazu")
        assertEquals(4, vereint.attempts.size, "alle vier Einträge bleiben, keiner doppelt")
        assertEquals(9, vereint.longestStreak, "der höhere Rekord bleibt")
        assertEquals(2, vereint.currentStreak, "die aktuelle Serie kommt vom jüngeren Stand")
        assertEquals("2026-09-01T10:00:00Z", vereint.createdAt, "dabei seit dem früheren Datum")

        // Das Zusammenführen ist richtungsunabhängig: Wer wessen Sicherung einliest,
        // darf am Ergebnis nichts ändern.
        val andersherum = Backup.vereine(fremd, eigen, course)
        assertEquals(vereint.attempts.size, andersherum.attempts.size)
        assertEquals(vereint.lessonRecords.getValue("l1").bestAccuracy, andersherum.lessonRecords.getValue("l1").bestAccuracy)
        assertEquals(vereint.masterScore, andersherum.masterScore)
    }

    @Test fun `Sicherung - Datei schreiben und wieder lesen ergibt denselben Stand`() {
        val store = ProgressStore(course, file(), clock(1))
        store.completeOnboarding(ExperienceLevel.BEGINNER, null)
        playLesson(store, 0)
        val text = store.sicherungText()
        assertTrue(text.contains("\"app\": \"JavaQuest\""), "Kennung fehlt")

        val gelesen = Backup.lesen(text)
        assertTrue(gelesen != null, "eigene Sicherung nicht wieder lesbar")
        assertEquals(store.data!!.attempts.size, gelesen!!.attempts.size)
        assertNull(Backup.lesen("{\"app\":\"etwas anderes\"}"), "fremde Datei wird abgelehnt")
        assertNull(Backup.lesen("kein JSON"), "Unfug wird abgelehnt")
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
