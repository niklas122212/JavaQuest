package app.javaquest.android

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.CalendarContract
import android.provider.OpenableColumns
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import app.javaquest.core.ReviewReminder
import app.javaquest.ui.Plattform
import java.io.File
import java.io.FileNotFoundException

/**
 * Android-Seite der gemeinsamen Oberfläche: Speicherort, Dateiauswahl über das System
 * (Storage Access Framework – dafür braucht die App keine Speicher-Berechtigung) und
 * Kalender über den Eintragen-Dialog der Kalender-App.
 *
 * Die Launcher müssen registriert sein, bevor die Activity startet – also im Konstruktor,
 * der in onCreate läuft.
 */
class AndroidPlattform(private val activity: ComponentActivity, lernstand: File) : Plattform {
    override val lernstandOrt: String = "App-Speicher: ${lernstand.absolutePath}"
    override val geraet = "diesem Gerät"

    private var ausstehenderText: String? = null
    private var nachSpeichern: ((String) -> Unit)? = null
    private var nachWaehlen: ((Result<String>?) -> Unit)? = null

    private val speichern = activity.registerForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri -> speicherungAbschliessen(uri) }

    private val waehlen = activity.registerForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri -> auswahlAbschliessen(uri) }

    override fun sicherungSpeichern(dateiname: String, text: String, fertig: (String) -> Unit) {
        ausstehenderText = text
        nachSpeichern = fertig
        try {
            speichern.launch(dateiname)
        } catch (e: ActivityNotFoundException) {
            ausstehenderText = null
            nachSpeichern = null
            fertig("Auf diesem Gerät gibt es keine Dateiauswahl.")
        }
    }

    override fun sicherungWaehlen(fertig: (Result<String>?) -> Unit) {
        nachWaehlen = fertig
        try {
            // Manche Dateimanager melden JSON als Text oder als unbekannten Binärtyp.
            waehlen.launch(arrayOf("application/json", "text/plain", "application/octet-stream"))
        } catch (e: ActivityNotFoundException) {
            nachWaehlen = null
            fertig(Result.failure(IllegalStateException("Auf diesem Gerät gibt es keine Dateiauswahl.")))
        }
    }

    private fun speicherungAbschliessen(uri: Uri?) {
        val text = ausstehenderText
        val fertig = nachSpeichern ?: return
        ausstehenderText = null
        nachSpeichern = null
        if (uri == null || text == null) return fertig("Abgebrochen.")
        fertig(
            try {
                val resolver = activity.contentResolver
                // "wt" kürzt eine vorhandene Datei; nicht jeder Anbieter kennt den Modus.
                val mitKuerzen = try {
                    resolver.openOutputStream(uri, "wt")
                } catch (e: FileNotFoundException) {
                    null
                } catch (e: IllegalArgumentException) {
                    null
                }
                val strom = mitKuerzen ?: resolver.openOutputStream(uri)
                    ?: throw FileNotFoundException("Die Datei ließ sich nicht öffnen.")
                strom.use { it.write(text.toByteArray(Charsets.UTF_8)) }
                "Gesichert: ${anzeigeName(uri)}"
            } catch (e: Exception) {
                Log.w("JavaQuest", "Sicherung fehlgeschlagen", e)
                "Speichern fehlgeschlagen: ${e.message}"
            },
        )
    }

    private fun auswahlAbschliessen(uri: Uri?) {
        val fertig = nachWaehlen ?: return
        nachWaehlen = null
        if (uri == null) return fertig(null)
        fertig(
            runCatching {
                activity.contentResolver.openInputStream(uri)?.use { String(it.readBytes(), Charsets.UTF_8) }
                    ?: throw FileNotFoundException("Die Datei ließ sich nicht öffnen.")
            },
        )
    }

    private fun anzeigeName(uri: Uri): String = runCatching {
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { zeiger ->
            if (zeiger.moveToFirst()) zeiger.getString(0) else null
        }
    }.getOrNull() ?: uri.lastPathSegment ?: "Datei"

    /**
     * Öffnet den Eintragen-Dialog der Kalender-App mit Titel, Zeit und Beschreibung – dieselben
     * Texte wie im .ics-Eintrag der Windows- und Web-Fassung. Die Kalender-App erinnert dann
     * auch, wenn JavaQuest geschlossen ist.
     */
    override fun erinnerungInKalender(termin: ReviewReminder.Slot, fertig: (String) -> Unit) {
        val ziele = if (termin.count == 1) "1 Lernziel" else "${termin.count} Lernziele"
        val warten = if (termin.count == 1) "wartet" else "warten"
        val beginn = termin.date.toEpochMilli()
        val intent = Intent(Intent.ACTION_INSERT)
            .setData(CalendarContract.Events.CONTENT_URI)
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginn)
            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, beginn + 15 * 60 * 1000)
            .putExtra(CalendarContract.Events.TITLE, "JavaQuest: $ziele wiederholen")
            .putExtra(CalendarContract.Events.DESCRIPTION, "$ziele $warten auf die Wiederholung – kurz reinschauen, bevor es verblasst.")
            .putExtra(CalendarContract.Events.HAS_ALARM, true)
        fertig(
            try {
                activity.startActivity(intent)
                "Kalender geöffnet – speichere den Eintrag dort."
            } catch (e: ActivityNotFoundException) {
                "Keine Kalender-App gefunden."
            },
        )
    }
}
