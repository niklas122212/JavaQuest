package app.javaquest

import androidx.compose.ui.graphics.toAwtImage
import androidx.compose.ui.test.DesktopComposeUiTest
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.captureToImage
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
        assertEquals(5, index)
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
    fun `Vorkenntnisse - Einstufungsfrage mit 4 von 6 Luecken ergibt 67 Prozent`() = runDesktopComposeUiTest(1280, 860) {
        val state = newState()
        show(state)
        click("welcome-start"); click("level-intermediate"); click("experience-continue")
        onNodeWithText("Eine Einstufungsfrage").assertExists()
        click("placement-start")
        // Während der Frage gibt es keine Erklärungen.
        assertTrue(onAllNodesWithText("Code Zeile für Zeile erklären").fetchSemanticsNodes().isEmpty())
        val kind = course.placement.pool(app.javaquest.core.ExperienceLevel.INTERMEDIATE).first().kind as TaskKind.FillBlank
        kind.blanks.forEachIndexed { i, blank -> onNodeWithTag("blank-$i").performScrollTo().performTextInput(if (i < 4) blank.accepted.first() else "falsch") }
        shot("11-placement-question")
        click("placement-submit")
        onNodeWithTag("placement-score").assertTextEquals("67 %")
        onNodeWithText("Stark eingestuft!").assertExists()
        onNodeWithText("Die Lösung Zeile für Zeile").assertExists()
        shot("12-placement-result")
        click("placement-go")
        assertEquals(course.entryModule(app.javaquest.core.ExperienceLevel.INTERMEDIATE)!!.lessons.first().id, state.flow?.lessonId)
        assertEquals(6, state.store.completedLessonCount)
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
}
