package app.javaquest.ui

import androidx.compose.runtime.staticCompositionLocalOf
import app.javaquest.core.ReviewReminder

/**
 * Was sich zwischen Windows/Mac (Compose Desktop) und Android unterscheidet.
 *
 * Die Oberfläche in `ui/` ist für beide Fassungen dieselbe Datei; nur diese Handvoll
 * Dinge braucht das Betriebssystem: Dateiauswahl, Kalender und wo der Lernstand liegt.
 * Alle Aufrufe melden ihr Ergebnis über `fertig`, weil Android die Dateiauswahl in einer
 * eigenen Activity öffnet und erst später zurückkommt.
 */
interface Plattform {
    /** Wo der Lernstand liegt – nur zur Anzeige im Profil. */
    val lernstandOrt: String

    /** „diesem Rechner“ / „diesem Gerät“ – für den Hinweis „Dein Lernstand liegt nur auf …“. */
    val geraet: String

    /** Bedienung per Finger: Hinweise sagen „tippen“ statt „klicken“. */
    val touch: Boolean get() = false

    /** Lässt einen Speicherort wählen und schreibt [text] hinein. */
    fun sicherungSpeichern(dateiname: String, text: String, fertig: (String) -> Unit)

    /**
     * Lässt eine Datei wählen und reicht ihren Inhalt weiter: `null` bei Abbruch,
     * ein Fehlschlag, wenn sie sich nicht lesen ließ.
     */
    fun sicherungWaehlen(fertig: (Result<String>?) -> Unit)

    /** Trägt die nächste Wiederholung in den Kalender des Systems ein. */
    fun erinnerungInKalender(termin: ReviewReminder.Slot, fertig: (String) -> Unit)
}

/** Für Tests und Vorschauen: zeigt alles an, kann aber keine Dateien oder Kalender öffnen. */
object OhnePlattform : Plattform {
    override val lernstandOrt = "–"
    override val geraet = "diesem Gerät"
    override fun sicherungSpeichern(dateiname: String, text: String, fertig: (String) -> Unit) =
        fertig("Auf diesem System nicht verfügbar.")
    override fun sicherungWaehlen(fertig: (Result<String>?) -> Unit) =
        fertig(Result.failure(UnsupportedOperationException("Auf diesem System nicht verfügbar.")))
    override fun erinnerungInKalender(termin: ReviewReminder.Slot, fertig: (String) -> Unit) =
        fertig("Auf diesem System nicht verfügbar.")
}

val LocalPlattform = staticCompositionLocalOf<Plattform> { OhnePlattform }
