package app.javaquest

import app.javaquest.core.AttemptRecord
import app.javaquest.core.CourseLoader
import app.javaquest.core.Kalender
import app.javaquest.core.ReviewReminder
import app.javaquest.core.SpacedRepetition
import app.javaquest.data.Backup
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/** Dieselben Fälle wie ReviewReminderTests.swift und die Web-Prüfung. */
class ErinnerungTest {
    private val utc: ZoneId = ZoneOffset.UTC
    private fun t(iso: String) = Instant.parse(iso)
    private fun plan(faellig: List<String>, jetzt: String) = ReviewReminder.plan(faellig.map(::t), t(jetzt), utc)

    @Test
    fun `nichts faellig - kein Termin`() {
        assertTrue(plan(emptyList(), "2026-09-24T12:00:00Z").isEmpty())
    }

    @Test
    fun `schon faellig vor 18 Uhr - heute, dann hoechstens noch zwei Tage`() {
        val termine = plan(listOf("2026-09-20T09:00:00Z"), "2026-09-24T12:00:00Z")
        assertEquals(listOf("2026-09-24T18:00:00Z", "2026-09-25T18:00:00Z", "2026-09-26T18:00:00Z").map(::t), termine.map { it.date })
        assertTrue(termine.all { it.count == 1 })
    }

    @Test
    fun `nach 18 Uhr erst morgen, abends faellig erst am Tag darauf`() {
        assertEquals(t("2026-09-25T18:00:00Z"), plan(listOf("2026-09-20T09:00:00Z"), "2026-09-24T19:30:00Z").first().date)
        assertEquals(t("2026-09-26T18:00:00Z"), plan(listOf("2026-09-25T20:00:00Z"), "2026-09-24T12:00:00Z").first().date)
    }

    @Test
    fun `die Zahl waechst mit dem, was dazukommt`() {
        val termine = plan(listOf("2026-09-24T08:00:00Z", "2026-09-25T08:00:00Z", "2026-09-30T08:00:00Z"), "2026-09-24T12:00:00Z")
        assertEquals(listOf(1, 2, 2), termine.map { it.count })
    }

    @Test
    fun `auf der gemeinsamen Beispiel-Sicherung gerechnet - wie in Swift`() {
        val course = CourseLoader.loadBundled()
        val stand = assertNotNull(Backup.lesen(File("../Tests/Sicherungen/aus-der-app.json").readText()))
        val ziele = SpacedRepetition.goals(
            stand.attempts.filter { it.context != "placement" }.map { AttemptRecord(it.taskId, it.credit, Instant.parse(it.date)) },
            course,
        )
        val termine = ReviewReminder.plan(ziele.values.map { it.dueDate }, t("2026-09-24T12:00:00Z"), utc)
        assertEquals(listOf(4, 4, 5), termine.map { it.count })
    }

    @Test
    fun `Kalendereintrag - Ortszeit, Alarm, Umbruch nach 75 Byte, Maskierung`() {
        val ics = Kalender.eintrag(ReviewReminder.Slot(t("2026-09-26T16:00:00Z"), 4), t("2026-09-24T12:00:00Z"), ZoneId.of("Europe/Berlin"))
        val zeilen = ics.split("\r\n")
        assertTrue(ics.endsWith("\r\n") && !Regex("[^\r]\n").containsMatchIn(ics), "Zeilenende muss CRLF sein")
        assertTrue(zeilen.all { it.toByteArray(Charsets.UTF_8).size <= 75 }, zeilen.filter { it.toByteArray().size > 75 }.toString())
        val entfaltet = ics.replace("\r\n ", "")
        assertTrue("DTSTART:20260926T180000\r\n" in entfaltet, "18 Uhr in Berlin, ohne Zeitzone")
        assertTrue("SUMMARY:JavaQuest: 4 Lernziele wiederholen" in entfaltet)
        assertTrue("BEGIN:VALARM" in entfaltet && "TRIGGER:PT0M" in entfaltet)
        val beschreibung = Regex("\r\nDESCRIPTION:(.*?)\r\n").find(entfaltet)!!.groupValues[1]
        assertTrue("\\," in beschreibung && !Regex("[^\\\\],").containsMatchIn(beschreibung), beschreibung)
    }
}
