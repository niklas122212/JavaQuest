package app.javaquest.core

import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * Wann an fällige Wiederholungen erinnert wird – dieselbe Rechnung wie ReviewReminder.plan
 * in der Apple-App und erinnerungsTermine in der Web-App.
 *
 * Nur an Tagen, an denen zur gewählten Uhrzeit wirklich etwas fällig ist, und höchstens
 * [MAX_COUNT] Tage hintereinander, falls niemand übt.
 */
object ReviewReminder {
    const val MAX_COUNT = 3
    const val DEFAULT_MINUTES = 18 * 60

    data class Slot(val date: Instant, val count: Int)

    fun plan(dueDates: List<Instant>, now: Instant, zone: ZoneId, minutes: Int = DEFAULT_MINUTES, maxCount: Int = MAX_COUNT): List<Slot> {
        val earliest = dueDates.minOrNull() ?: return emptyList()
        var day = maxOf(now, earliest).atZone(zone).toLocalDate()
        val slots = mutableListOf<Slot>()
        // Spätestens einen Tag nach dem frühesten Termin ist etwas fällig; die Schranke
        // verhindert trotzdem jede Endlosschleife.
        repeat(maxCount + 2) {
            if (slots.size < maxCount) {
                val time = day.atTime(minutes / 60, minutes % 60).atZone(zone).toInstant()
                if (time.isAfter(now)) {
                    val count = dueDates.count { !it.isAfter(time) }
                    if (count > 0) slots += Slot(time, count)
                }
            }
            day = day.plusDays(1)
        }
        return slots
    }
}

/**
 * Ein Kalendereintrag (.ics) mit Alarm – denselben Aufbau schreibt die Web-App.
 *
 * Die Windows-App kann sich nicht selbst melden, wenn sie geschlossen ist. Der Kalender
 * kann das: Outlook, der Windows-Kalender oder jede andere Kalender-App übernimmt den
 * Eintrag per Doppelklick.
 */
object Kalender {
    fun eintrag(slot: ReviewReminder.Slot, jetzt: Instant, zone: ZoneId): String {
        val beginn = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmm'00'").format(slot.date.atZone(zone))
        val stempel = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'").withZone(ZoneOffset.UTC).format(jetzt)
        val ziele = if (slot.count == 1) "1 Lernziel" else "${slot.count} Lernziele"
        val warten = if (slot.count == 1) "wartet" else "warten"
        return listOf(
            "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//JavaQuest//Wiederholung//DE", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
            "BEGIN:VEVENT",
            "UID:javaquest-wiederholung-$beginn@javaquest",
            "DTSTAMP:$stempel",
            // Ohne Zeitzone („floating“): 18 Uhr bleibt 18 Uhr, wie ein Wecker.
            "DTSTART:$beginn",
            "DURATION:PT15M",
            "SUMMARY:${text("JavaQuest: $ziele wiederholen")}",
            "DESCRIPTION:${text("$ziele $warten auf die Wiederholung – kurz reinschauen, bevor es verblasst.")}",
            "BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:${text("JavaQuest: $ziele wiederholen")}", "TRIGGER:PT0M", "END:VALARM",
            "END:VEVENT", "END:VCALENDAR",
        ).joinToString("\r\n") { zeile(it) } + "\r\n"
    }

    /** Backslash, Semikolon, Komma und Zeilenumbruch maskiert (RFC 5545). */
    fun text(t: String): String = t.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")

    /** Zeilen über 75 Byte werden umbrochen; die Fortsetzung beginnt mit einem Leerzeichen. */
    fun zeile(z: String): String {
        val teile = mutableListOf<String>()
        val aktuell = StringBuilder()
        var bytes = 0
        var i = 0
        while (i < z.length) {
            val cp = z.codePointAt(i)
            val zeichen = String(Character.toChars(cp))
            val laenge = zeichen.toByteArray(Charsets.UTF_8).size
            if (bytes + laenge > (if (teile.isEmpty()) 75 else 74)) {
                teile += aktuell.toString(); aktuell.clear(); bytes = 0
            }
            aktuell.append(zeichen); bytes += laenge
            i += Character.charCount(cp)
        }
        teile += aktuell.toString()
        return teile.joinToString("\r\n ")
    }
}
