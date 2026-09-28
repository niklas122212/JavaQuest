package app.javaquest.ui

import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.platform.SystemFont
import app.javaquest.core.Kalender
import app.javaquest.core.ReviewReminder
import app.javaquest.data.ProgressFile
import java.awt.Desktop
import java.awt.FileDialog
import java.nio.file.Files
import java.nio.file.Path
import java.time.Instant
import java.time.ZoneId

/** Windows, macOS und Linux über Compose Desktop: AWT-Dateidialog und .ics-Datei für den Kalender. */
object DesktopPlattform : Plattform {
    override val lernstandOrt: String get() = ProgressFile.defaultLocation().path.toString()
    override val geraet = "diesem Rechner"

    /** Monospace-Schrift: Consolas unter Windows, Menlo auf dem Mac. */
    @OptIn(ExperimentalTextApi::class)
    fun codeSchrift(): FontFamily {
        val os = System.getProperty("os.name").lowercase()
        return when {
            "win" in os -> FontFamily(SystemFont("Consolas"))
            "mac" in os -> FontFamily(SystemFont("Menlo"))
            else -> FontFamily.Monospace
        }
    }

    /* Datei-Dialoge über java.awt.FileDialog: Den gibt es auf Windows, macOS und Linux,
       und er sieht überall wie der Dialog des jeweiligen Systems aus. Compose Desktop
       bringt keinen eigenen mit. Er blockiert, bis gewählt ist – `fertig` kommt also sofort. */
    override fun sicherungSpeichern(dateiname: String, text: String, fertig: (String) -> Unit) {
        val dialog = FileDialog(null as java.awt.Frame?, "Sicherung speichern", FileDialog.SAVE)
        dialog.file = dateiname
        dialog.isVisible = true
        val ordner = dialog.directory ?: return fertig("Abgebrochen.")
        val name = dialog.file ?: return fertig("Abgebrochen.")
        fertig(
            try {
                Files.writeString(Path.of(ordner, name), text)
                "Gesichert: $ordner$name"
            } catch (e: Exception) {
                "Speichern fehlgeschlagen: ${e.message}"
            },
        )
    }

    override fun sicherungWaehlen(fertig: (Result<String>?) -> Unit) {
        val dialog = FileDialog(null as java.awt.Frame?, "Sicherung einlesen", FileDialog.LOAD)
        dialog.isVisible = true
        val ordner = dialog.directory ?: return fertig(null)
        val name = dialog.file ?: return fertig(null)
        fertig(runCatching { Files.readString(Path.of(ordner, name)) })
    }

    /**
     * Legt den Kalendereintrag als Datei an und öffnet ihn mit dem Standard-Kalender – dort
     * genügt dann ein Klick auf „Übernehmen“. Ohne Standard-Programm bleibt die Datei liegen.
     */
    override fun erinnerungInKalender(termin: ReviewReminder.Slot, fertig: (String) -> Unit) {
        fertig(
            try {
                val datei = Files.createTempFile("javaquest-wiederholung-", ".ics")
                Files.writeString(datei, Kalender.eintrag(termin, Instant.now(), ZoneId.systemDefault()))
                if (Desktop.isDesktopSupported() && Desktop.getDesktop().isSupported(Desktop.Action.OPEN)) {
                    Desktop.getDesktop().open(datei.toFile())
                    "Kalendereintrag geöffnet – übernimm ihn in deinen Kalender."
                } else {
                    "Kalendereintrag gespeichert: $datei – doppelklicke die Datei, um ihn zu übernehmen."
                }
            } catch (e: Exception) {
                "Kalendereintrag fehlgeschlagen: ${e.message}"
            }
        )
    }
}
