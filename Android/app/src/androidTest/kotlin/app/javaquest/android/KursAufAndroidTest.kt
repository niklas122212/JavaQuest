package app.javaquest.android

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.javaquest.core.AnswerEvaluator
import app.javaquest.core.Course
import app.javaquest.core.CourseLoader
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.TaskAnswer
import app.javaquest.core.TaskKind
import app.javaquest.data.ProgressFile
import app.javaquest.data.ProgressStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.regex.Pattern

/**
 * Die Kernlogik auf echtem Android statt auf der JVM des Desktops.
 *
 * Der Unterschied ist nicht nur theoretisch: Android übersetzt Regex mit ICU statt mit
 * java.util.regex, hat eigene java.time- und java.nio-Implementierungen und kennt viele
 * Java-9+-APIs nicht. Die Windows-Testreihe kann das nicht sehen – deshalb prüft diese
 * Reihe auf dem Emulator dieselben Zusagen: jede Musterlösung zählt, gleichwertige Wege
 * zählen, Unfug nicht, und der Lernstand übersteht Speichern und Neuladen.
 */
@RunWith(AndroidJUnit4::class)
class KursAufAndroidTest {
    private val kontext = InstrumentationRegistry.getInstrumentation().targetContext
    private val kurs: Course get() = geladenerKurs

    companion object {
        // Einmal für alle Tests: JUnit legt je Test ein neues Objekt an, der Kurs hat 3 MB.
        private val geladenerKurs: Course by lazy {
            val kontext = InstrumentationRegistry.getInstrumentation().targetContext
            CourseLoader.parse(kontext.assets.open("java_course.json").bufferedReader(Charsets.UTF_8).use { it.readText() })
        }
    }

    @Test
    fun kursLaedtAusDenAssets() {
        assertEquals(14, kurs.modules.size)
        assertEquals(35, kurs.allLessons.size)
        assertTrue("Aufgabenpool zu klein: ${kurs.allTasks.size}", kurs.allTasks.size >= 775)
    }

    /** Jedes Bewertungsmuster muss sich mit der ICU-Regex von Android übersetzen lassen. */
    @Test
    fun jedesBewertungsmusterLaesstSichAufAndroidUebersetzen() {
        val kaputt = mutableListOf<String>()
        for (task in kurs.allTasks) {
            val kind = task.kind as? TaskKind.Code ?: continue
            for (regel in kind.rules) for (muster in regel.allPatterns) {
                runCatching { Pattern.compile(muster) }.onFailure { kaputt += "${task.id}: $muster – ${it.message}" }
            }
        }
        assertTrue(kaputt.joinToString("\n"), kaputt.isEmpty())
    }

    @Test
    fun musterloesungJederAufgabeWirdAkzeptiert() {
        val abgelehnt = kurs.allTasks.mapNotNull { task ->
            val ergebnis = AnswerEvaluator.evaluate(AnswerEvaluator.referenceAnswer(task), task)
            if (ergebnis.isCorrect && ergebnis.score == 1.0) null
            else "${task.id}: ${ergebnis.findings.map { it.message }}"
        }
        assertTrue("${abgelehnt.size} Musterlösungen abgelehnt:\n${abgelehnt.take(20).joinToString("\n")}", abgelehnt.isEmpty())
    }

    @Test
    fun gleichwertigeLoesungenWerdenAkzeptiert() {
        val codeAufgaben = kurs.allTasks.filter { it.kind is TaskKind.Code }.associateBy { it.id }
        val abgelehnt = mutableListOf<String>()
        for ((id, loesungen) in kurs.equivalentSolutions) {
            val task = codeAufgaben[id] ?: continue
            for (loesung in loesungen) {
                if (!AnswerEvaluator.evaluate(TaskAnswer.Text(loesung), task).isCorrect) abgelehnt += id
            }
        }
        assertTrue("Gleichwertige Lösungen abgelehnt: $abgelehnt", abgelehnt.isEmpty())
    }

    @Test
    fun startercodeUndUnfugWerdenAbgelehnt() {
        for (task in kurs.practiceableTasks) {
            val kind = task.kind as? TaskKind.Code ?: continue
            assertFalse("${task.id}: Startercode gilt als Lösung", AnswerEvaluator.evaluate(TaskAnswer.Text(kind.starter.source), task).isCorrect)
            assertFalse("${task.id}: leere Antwort gilt als Lösung", AnswerEvaluator.evaluate(TaskAnswer.Text(""), task).isCorrect)
        }
    }

    @Test
    fun jedeCodezeileHatEineErklaerung() {
        // Wie in der Windows-Testreihe; explained() läuft dabei durch die Regex des Befehlslexikons.
        var zeilen = 0
        for ((ort, schnipsel) in kurs.allSnippets) {
            assertTrue("$ort: Zeilen ${schnipsel.linesMissingExplanation}", schnipsel.linesMissingExplanation.isEmpty())
            zeilen += schnipsel.explained(kurs.glossary).size
        }
        assertTrue("nur $zeilen erklärte Zeilen", zeilen >= 4400)
    }

    /** Speichern und Laden über java.nio, Serialisierung und Kopie vor dem Zurücksetzen. */
    @Test
    fun lernstandUeberstehtSpeichernUndNeuladen() {
        val ordner = File(kontext.cacheDir, "lernstand-test-${System.nanoTime()}").apply { mkdirs() }
        val datei = ProgressFile(File(ordner, "progress.json").toPath())
        val erster = ProgressStore(kurs, datei)
        erster.completeOnboarding(ExperienceLevel.BEGINNER, null)
        assertTrue(File(ordner, "progress.json").exists())
        val sicherung = erster.sicherungText()

        val zweiter = ProgressStore(kurs, datei)
        assertNotNull(zweiter.data)
        assertFalse(zweiter.needsOnboarding)
        assertEquals(0, zweiter.sicherungEinlesen(sicherung))
        ordner.deleteRecursively()
    }
}
