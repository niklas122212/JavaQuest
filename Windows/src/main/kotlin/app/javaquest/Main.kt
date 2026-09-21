package app.javaquest

import androidx.compose.runtime.remember
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.toComposeImageBitmap
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import app.javaquest.core.CourseLoader
import app.javaquest.data.ProgressFile
import app.javaquest.data.ProgressStore
import app.javaquest.ui.AppShell
import app.javaquest.ui.AppState
import app.javaquest.ui.JavaQuestTheme
import java.awt.Dimension
import java.io.File
import javax.imageio.ImageIO

fun main() {
    // Selbsttest für fertige Pakete: Kurs laden, Startbildschirm unsichtbar zeichnen, als PNG speichern.
    System.getProperty("javaquest.selfcheck")?.let { selfCheck(File(it)); return }

    application {
        val state = remember { AppState(ProgressStore(CourseLoader.loadBundled(), ProgressFile.defaultLocation())) }
        val icon = remember { BitmapPainter(ImageIO.read(AppState::class.java.getResourceAsStream("/icon.png")).toComposeImageBitmap()) }
        Window(
            onCloseRequest = ::exitApplication,
            title = "JavaQuest – Java lernen",
            icon = icon,
            state = rememberWindowState(size = DpSize(1280.dp, 860.dp)),
        ) {
            window.minimumSize = Dimension(980, 680)
            JavaQuestTheme { AppShell(state) }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
private fun selfCheck(outputDir: File) {
    outputDir.mkdirs()
    val course = CourseLoader.loadBundled()
    val lines = course.allSnippets.sumOf { it.second.explained(course.glossary).size }
    println("Kurs: ${course.modules.size} Module, ${course.allLessons.size} Lektionen, $lines erklärte Codezeilen")
    val state = AppState(ProgressStore(course, file = null))
    val scene = ImageComposeScene(1280, 860, Density(1f)) { JavaQuestTheme(dark = false) { AppShell(state) } }
    var count = 0
    fun render(name: String) {
        val image = scene.render()
        File(outputDir, "%02d-%s.png".format(++count, name)).writeBytes(image.encodeToData()!!.bytes)
    }

    // Jeden Bildschirm einmal zeichnen – so fällt eine fehlende Klasse im Paket sofort auf.
    render("onboarding")
    state.store.completeOnboarding(app.javaquest.core.ExperienceLevel.BEGINNER, null)
    for (section in app.javaquest.ui.Section.entries) { state.section = section; render(section.name.lowercase()) }
    for (lesson in course.allLessons) {
        state.startLesson(lesson.id)
        val flow = state.flow!!
        render("${lesson.id}-theorie")
        repeat(flow.theory.size) { flow.advanceTheory() }
        while (flow.currentTask != null) {
            val task = flow.currentTask!!
            flow.draft = flow.draft.applying(app.javaquest.core.AnswerEvaluator.referenceAnswer(task))
            render("${task.id}-frage")
            flow.submit()
            render("${task.id}-geloest")
            flow.next()
        }
        render("${lesson.id}-auswertung")
        state.closeFlow()
    }
    // Eine Runde Endlos-Training über alle abgeschlossenen Lektionen.
    state.startTraining()
    state.flow?.let { flow ->
        while (flow.currentTask != null) {
            val task = flow.currentTask!!
            flow.draft = flow.draft.applying(app.javaquest.core.AnswerEvaluator.referenceAnswer(task))
            flow.submit()
            render("training-${task.id}")
            flow.next()
        }
        render("training-auswertung")
    }
    state.closeFlow()
    // Freies Training über selbst gewählte Themen – hier die beiden UML-Themen.
    state.startFreeTraining(setOf("umlbasics", "umlrelations"), emptySet(), 4)
    state.flow?.let { flow ->
        while (flow.currentTask != null) {
            val task = flow.currentTask!!
            render("frei-${task.id}")
            flow.draft = flow.draft.applying(app.javaquest.core.AnswerEvaluator.referenceAnswer(task))
            flow.submit()
            flow.next()
        }
        render("frei-auswertung")
    }
    state.closeFlow()

    for (section in app.javaquest.ui.Section.entries) { state.section = section; render("${section.name.lowercase()}-am-ende") }
    scene.close()
    println("$count Bildschirme gezeichnet → ${outputDir.absolutePath}")
    println("Score ${state.store.masterScore}, Lektionen ${state.store.completedLessonCount}/${course.allLessons.size}")
    println("Java ${System.getProperty("java.version")} · ${System.getProperty("os.name")} ${System.getProperty("os.arch")}")
}
