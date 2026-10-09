package app.javaquest

import androidx.compose.ui.graphics.toAwtImage
import androidx.compose.ui.test.DesktopComposeUiTest
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.runDesktopComposeUiTest
import app.javaquest.core.CourseLoader
import app.javaquest.core.LessonSession
import app.javaquest.core.TaskKind
import app.javaquest.data.ProgressFile
import app.javaquest.data.ProgressStore
import app.javaquest.ui.AppShell
import app.javaquest.ui.AppState
import app.javaquest.ui.JavaQuestTheme
import java.io.File
import java.nio.file.Files
import javax.imageio.ImageIO
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Klickt die echte Oberfläche durch (ohne Fenster) – wie eine lernende Person.
 * Nebenbei entstehen Screenshots in build/screenshots.
 */
@OptIn(ExperimentalTestApi::class)
class UiFlowTest {
    private val course = CourseLoader.loadBundled()
    private val shots = File("build/screenshots").apply { mkdirs() }

    private fun newState() = AppState(ProgressStore(course, ProgressFile(Files.createTempDirectory("jq-ui").resolve("progress.json"))))

    private val catalog = app.javaquest.core.ArenaCatalog.loadBundled()

    /** Wie [newState], aber mit Arena: Lektion 1–7 enden dann mit einer Mission. */
    private fun newArenaState() = AppState(
        ProgressStore(course, ProgressFile(Files.createTempDirectory("jq-arena").resolve("progress.json")), catalog = catalog),
    )

    private fun DesktopComposeUiTest.show(state: AppState, dark: Boolean = false) =
        setContent { JavaQuestTheme(dark = dark) { AppShell(state) } }

    private fun DesktopComposeUiTest.shot(name: String) {
        waitForIdle()
        ImageIO.write(onRoot().captureToImage().toAwtImage(), "png", File(shots, "$name.png"))
    }

    private fun DesktopComposeUiTest.click(tag: String) {
        val node = onNodeWithTag(tag, useUnmergedTree = true)
        // Knöpfe in der festen Aktionsleiste liegen in keinem scrollbaren Bereich.
        runCatching { node.performScrollTo() }
        node.performClick()
        waitForIdle()
    }

    /** Beantwortet die aktuelle Aufgabe über die Oberfläche; `correct = false` tippt Unsinn ein. */
    private fun DesktopComposeUiTest.answerCurrentTask(state: AppState, correct: Boolean = true) {
        val task = state.flow!!.currentTask!!
        when (val kind = task.kind) {
            is TaskKind.SingleChoice -> click("choice-${if (correct) kind.correctIndex else (kind.correctIndex + 1) % kind.choices.size}")
            is TaskKind.FillBlank -> kind.blanks.forEachIndexed { i, blank ->
                onNodeWithTag("blank-$i").performScrollTo().performTextInput(if (correct) blank.accepted.first() else "falsch")
            }
            is TaskKind.PredictOutput -> onNodeWithTag("output-editor").performScrollTo().performTextInput(if (correct) kind.expectedOutput else "keine Ahnung")
            is TaskKind.Code -> onNodeWithTag("code-editor").performScrollTo().performTextReplacement(if (correct) kind.solution.source else "int x")
            // Puzzle: Bausteine der Reihe nach anklicken – falsch heißt: mit dem letzten beginnen.
            is TaskKind.Ordering -> (if (correct) kind.pieces.indices.toList() else kind.pieces.indices.reversed()).forEach { click("puzzle-piece-$it") }
            is TaskKind.FindBug -> click("bug-line-${if (correct) kind.bugLine else (1..task.code!!.lines.size).first { it != kind.bugLine && task.code!!.lines[it - 1].code.isNotBlank() }}")
        }
        waitForIdle()
        click("submit")
    }

    @Test
    fun `Anfaenger - Onboarding, Theorie mit Zeilen-Erklaerung, Aufgaben, bestanden`() = runDesktopComposeUiTest(1280, 860) {
        val state = newState()
        show(state)
        onNodeWithText("Lerne Java.\nLevel für Level.").assertExists()
        shot("01-welcome")
        click("welcome-start")
        onNodeWithText("Ich habe 0 Erfahrung").assertExists()
        onNodeWithText("Ich habe schon Vorkenntnisse").assertExists()
        click("level-beginner")
        shot("02-experience")
        click("experience-continue")

        // Direkt in Lektion 1: Theorie mit Code-Exegese.
        assertEquals("l01-hello", state.flow?.lessonId)
        onNodeWithText("Dein erstes Programm").assertExists()
        click("code-line-3")
        onNodeWithText("Schreibt den Text „Hallo, Java!“", substring = true).assertExists()
        onNodeWithText("BEFEHLE IN DIESER ZEILE").assertExists()
        shot("03-theory-exegese")

        repeat(state.flow!!.theory.size) { click("theory-next") }
        var index = 0
        while (state.flow?.phase is LessonSession.Phase.Task) {
            if (index == 2) shot("04-task-before")
            answerCurrentTask(state)
            onNodeWithTag("feedback").assertExists()
            if (index == 2) shot("05-task-solved")
            click("task-next")
            index++
        }
        // 5 Aufgaben aus dem Kurs plus das Code-Puzzle von Lektion 1.
        assertEquals(6, index)
        onNodeWithText("Lektion gemeistert!").assertExists()
        shot("06-summary-passed")
        assertEquals(1, state.store.completedLessonCount)
        assertTrue(state.store.masterScore > 0)

        click("close-lesson")
        onNodeWithTag("master-score").assertExists()
        shot("07-dashboard")
        click("nav-analysis")
        onNodeWithText("Wissensanalyse").assertExists()
        shot("08-analysis")
        click("nav-path")
        shot("09-path")
    }

    @Test
    fun `Unter 69 Prozent - Loesung gezeigt, Lektion nicht bestanden`() = runDesktopComposeUiTest(1280, 860) {
        val state = newState()
        show(state)
        click("welcome-start"); click("level-beginner"); click("experience-continue")
        repeat(state.flow!!.theory.size) { click("theory-next") }
        // Lösung bei der schwersten Aufgabe aufdecken (Niveau 3 von 9 Punkten) → 6/9 = 67 %.
        val lastIndex = state.flow!!.tasks.lastIndex
        var position = 0
        while (state.flow?.phase is LessonSession.Phase.Task) {
            if (position == lastIndex) {
                answerCurrentTask(state, correct = false)
                onNodeWithText("Noch nicht ganz").assertExists()
                click("reveal")
                onNodeWithText("Lösung aufgedeckt").assertExists()
            } else {
                answerCurrentTask(state)
            }
            position++
            click("task-next")
        }
        onNodeWithText("Fast geschafft!").assertExists()
        onNodeWithText("Punkte gibt es, sobald du die Lektion mit mindestens 69 % bestehst.").assertExists()
        shot("10-summary-not-passed")
        assertEquals(0, state.store.completedLessonCount)
        assertEquals(0, state.store.masterScore)
    }

    @Test
    fun `Vorkenntnisse - fuenf adaptive Fragen, alles richtig stuft nach vorn ein`() = runDesktopComposeUiTest(1280, 860) {
        val state = newState()
        show(state)
        click("welcome-start"); click("level-intermediate"); click("experience-continue")
        onNodeWithText("Kurze Einstufung").assertExists()
        click("placement-start")
        // Während der Fragen gibt es keine Erklärungen.
        assertTrue(onAllNodesWithText("Code Zeile für Zeile erklären").fetchSemanticsNodes().isEmpty())

        val gestellt = mutableListOf<String>()
        repeat(course.placement.questionsPerTest) { index ->
            val task = state.placementTest!!.currentTask!!
            gestellt += task.id
            when (val kind = task.kind) {
                is TaskKind.SingleChoice -> click("choice-${kind.correctIndex}")
                is TaskKind.FillBlank -> kind.blanks.forEachIndexed { i, blank ->
                    onNodeWithTag("blank-$i").performScrollTo().performTextInput(blank.accepted.first())
                }
                is TaskKind.PredictOutput -> onNodeWithTag("output-editor").performScrollTo().performTextInput(kind.expectedOutput)
                is TaskKind.Code -> onNodeWithTag("code-editor").performScrollTo().performTextReplacement(kind.solution.source)
                is TaskKind.Ordering, is TaskKind.FindBug -> error("Bonus-Aufgaben kommen in der Einstufung nicht vor")
            }
            waitForIdle()
            if (index == 0) shot("11-placement-question")
            click("placement-submit")
        }
        // Keine Frage kam doppelt, und der Test ist nach fünf Antworten zu Ende.
        assertEquals(gestellt.size, gestellt.toSet().size)
        onNodeWithTag("placement-score").assertTextEquals("100 %")
        onNodeWithText("Das saß – großer Sprung!").assertExists()
        // Jede der fünf Fragen wird einzeln nachbesprochen.
        repeat(course.placement.questionsPerTest) { onNodeWithText("Frage ${it + 1}").performScrollTo().assertExists() }
        shot("12-placement-result")
        click("placement-go")
        // Alles richtig → Sprung in den fortgeschrittenen Teil, alles davor angerechnet.
        val entry = course.entryModule(app.javaquest.core.ExperienceLevel.ADVANCED)!!
        assertEquals(entry.lessons.first().id, state.flow?.lessonId)
        val davor = course.modules.takeWhile { it.id != entry.id }.sumOf { it.lessons.size }
        assertEquals(davor, state.store.completedLessonCount)
    }

    @Test
    fun `Lueckentext - Zeile mit Luecke bleibt bis zum Loesen gesperrt`() = runDesktopComposeUiTest(1280, 860) {
        val state = newState()
        show(state)
        click("welcome-start"); click("level-beginner"); click("experience-continue")
        repeat(state.flow!!.theory.size) { click("theory-next") }
        while (state.flow!!.currentTask!!.kind !is TaskKind.FillBlank) {
            answerCurrentTask(state); click("task-next")
        }
        onNodeWithText("Code Zeile für Zeile erklären").performScrollTo().performClick()
        waitForIdle()
        onNodeWithText("Hier steckt eine Lücke", substring = true).assertExists()
        onNodeWithText("[Lücke 1]", substring = true).assertExists()
        shot("13-fill-blank-locked")
        answerCurrentTask(state)
        assertTrue(onAllNodesWithText("Hier steckt eine Lücke", substring = true).fetchSemanticsNodes().isEmpty())
        shot("14-fill-blank-unlocked")
    }

    @Test
    fun `Dunkles Erscheinungsbild und Neustart mit gespeichertem Stand`() = runDesktopComposeUiTest(1280, 860) {
        val dir = Files.createTempDirectory("jq-restart")
        val file = ProgressFile(dir.resolve("progress.json"))
        val first = AppState(ProgressStore(course, file))
        first.store.completeOnboarding(app.javaquest.core.ExperienceLevel.BEGINNER, null)
        assertNull(first.flow)
        val reopened = AppState(ProgressStore(course, file))
        assertNotNull(reopened.store.data)
        show(reopened, dark = true)
        onNodeWithTag("master-score").assertExists()
        shot("15-dashboard-dark")
        click("start-next-lesson")
        shot("16-theory-dark")
    }

    /** Handy hochkant (400 dp): Bereiche als Leiste unten, die während einer Lektion verschwindet. */
    @Test
    fun `Handy - Leiste unten, Lektion im Vollbild, Zurueck-Taste`() = runDesktopComposeUiTest(400, 860) {
        val state = newState()
        show(state)
        click("welcome-start")
        click("level-beginner")
        click("experience-continue")
        assertEquals("l01-hello", state.flow?.lessonId)
        // In der Lektion keine Leiste – der Platz gehört der Aufgabe.
        onNodeWithTag("nav-profile").assertDoesNotExist()
        shot("handy-01-theorie")

        // Zurück-Taste (Android): erst die Lektion schließen, dann zur Übersicht, dann nichts mehr.
        assertTrue(state.kannZurueck)
        state.zurueck()
        waitForIdle()
        assertNull(state.flow)
        onNodeWithTag("master-score").assertExists()
        onNodeWithTag("nav-profile").assertExists()
        shot("handy-02-uebersicht")

        click("nav-analysis")
        onNodeWithText("Wissensanalyse").assertExists()
        click("nav-profile")
        onNodeWithText("Fortschritt sichern").assertExists()
        // Ohne Plattform (Test) meldet der Knopf das, statt abzustürzen.
        onNodeWithText("Sicherung speichern").performScrollTo().performClick()
        waitForIdle()
        onNodeWithText("Auf diesem System nicht verfügbar.").assertExists()
        shot("handy-03-profil")

        assertTrue(state.kannZurueck)
        state.zurueck()
        waitForIdle()
        assertEquals(app.javaquest.ui.Section.DASHBOARD, state.section)
        assertTrue(!state.kannZurueck)
    }

    @Test
    fun `Lektion 1 mit Testlauf und Abschluss-Mission - Byte faehrt, Sterne und XP in der Auswertung`() = runDesktopComposeUiTest(1280, 860) {
        val state = newArenaState()
        state.store.completeOnboarding(app.javaquest.core.ExperienceLevel.BEGINNER, null)
        show(state)
        state.startLesson("l01-hello")
        waitForIdle()
        repeat(state.flow!!.theory.size) { click("theory-next") }
        var testRunSeen = false
        while (state.flow?.phase is LessonSession.Phase.Task) {
            val task = state.flow!!.currentTask!!
            val kind = task.kind
            // Testlauf: einmal mit der Musterlösung ausprobieren – zählt nicht als Versuch.
            if (!testRunSeen && kind is TaskKind.Code && state.flow!!.let { it.draft = it.draft.copy(text = kind.solution.source); it.canTestRun }) {
                waitForIdle()
                click("test-run")
                onNodeWithTag("test-run-output").assertExists()
                assertEquals(0, state.flow!!.attempts, "Testlauf darf keinen Versuch kosten")
                testRunSeen = true
            }
            answerCurrentTask(state)
            click("task-next")
        }
        assertTrue(testRunSeen, "Lektion 1 hat eine Code-Aufgabe mit Testlauf")
        // Nach der letzten Aufgabe: die Abschluss-Mission „Erste Schritte“.
        assertTrue(state.flow?.phase is LessonSession.Phase.Mission)
        onNodeWithText("Erste Schritte").assertExists()
        onNodeWithText("Dein Auftrag").assertExists()
        shot("20-lesson-mission")
        val mission = state.flow!!.missionModel!!
        mission.updateCode(mission.mission.solution.source, null)
        waitForIdle()
        click("arena-run")
        waitUntil(timeoutMillis = 10_000) { mission.result != null }
        assertTrue(mission.result!!.solved)
        assertEquals(3, mission.result!!.stars)
        mission.skipToEnd()
        waitForIdle()
        shot("21-lesson-mission-solved")
        click("arena-finish")
        assertEquals(LessonSession.Phase.Summary, state.flow?.phase)
        onNodeWithText("Lektion gemeistert!").assertExists()
        assertTrue(onAllNodesWithText("XP", substring = true).fetchSemanticsNodes().isNotEmpty(), "XP in der Auswertung")
        assertEquals(3, state.store.missionStars["a01-erste-schritte"])
        shot("22-lesson-summary-rewards")
    }

    @Test
    fun `Arena und Abzeichen in der Seitenleiste, Spielplatz oeffnet und schliesst`() = runDesktopComposeUiTest(1280, 860) {
        val state = newArenaState()
        state.store.completeOnboarding(app.javaquest.core.ExperienceLevel.BEGINNER, null)
        show(state)
        click("nav-arena")
        onNodeWithText("Die Arena").assertExists()
        click("open-playground")
        assertNotNull(state.arena)
        click("close-arena")
        assertNull(state.arena)
        click("nav-achievements")
        onNodeWithText("freigeschaltet", substring = true).assertExists()
        shot("23-achievements")
    }

    @Test
    fun `Handy - Arena, Mission und Abzeichen passen auf einen schmalen Bildschirm`() = runDesktopComposeUiTest(400, 860) {
        val state = newArenaState()
        state.store.completeOnboarding(app.javaquest.core.ExperienceLevel.BEGINNER, null)
        show(state)
        shot("30-handy-uebersicht")
        // Arena und Abzeichen stehen nicht in der Leiste unten – erreichbar über die Übersicht.
        assertTrue(onAllNodesWithText("Arena").fetchSemanticsNodes().isEmpty() || state.section == app.javaquest.ui.Section.DASHBOARD)
        state.section = app.javaquest.ui.Section.ARENA
        waitForIdle()
        onNodeWithText("Die Arena").assertExists()
        shot("31-handy-arena")
        state.startMission("a01-erste-schritte")
        waitForIdle()
        onNodeWithTag("arena-file").assertExists()
        shot("32-handy-mission")
        val mission = state.arena!!
        mission.updateCode(mission.mission.solution.source, null)
        waitForIdle()
        click("arena-run")
        waitUntil(timeoutMillis = 10_000) { mission.result != null }
        mission.skipToEnd()
        waitForIdle()
        shot("33-handy-mission-geloest")
        state.closeArena()
        state.section = app.javaquest.ui.Section.ACHIEVEMENTS
        waitForIdle()
        shot("34-handy-abzeichen")
        // Bug-Jagd aus Lektion 2 auf dem Handy
        state.startLesson("l02-variables")
        val flow = state.flow!!
        repeat(flow.theory.size) { flow.advanceTheory() }
        while (flow.currentTask?.kind !is TaskKind.FindBug) {
            flow.draft = flow.draft.applying(app.javaquest.core.AnswerEvaluator.referenceAnswer(flow.currentTask!!))
            flow.submit(); flow.next()
        }
        waitForIdle()
        shot("35-handy-bugjagd")
    }

    @Test
    fun `Ausfuehren und zusehen - Theorie-Beispiel laeuft Schritt fuer Schritt`() = runDesktopComposeUiTest(1280, 860) {
        val state = newState()
        state.store.completeOnboarding(app.javaquest.core.ExperienceLevel.BEGINNER, null)
        show(state)
        state.startLesson("l05-loops")
        waitForIdle()
        // Erstes Theorie-Beispiel: for (int i = 1; i <= 3; i++) { System.out.println("Runde " + i); }
        waitUntil(timeoutMillis = 5_000) { onAllNodesWithTag("run-open", useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty() }
        click("run-open")
        repeat(3) { click("run-next") }
        onNodeWithTag("run-position", useUnmergedTree = true).assertTextEquals("Schritt 4 von 8")
        onNodeWithTag("run-console", useUnmergedTree = true).assertTextEquals("Runde 1")
        onNodeWithText("Als Nächstes Zeile 2", substring = true).assertExists()
        shot("40-zusehen")
        click("run-end")
        onNodeWithText("Das Programm ist fertig.").assertExists()
        onNodeWithTag("run-console", useUnmergedTree = true).assertTextEquals("Runde 1\nRunde 2\nRunde 3")
    }
}
