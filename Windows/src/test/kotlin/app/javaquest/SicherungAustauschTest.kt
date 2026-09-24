package app.javaquest

import app.javaquest.core.AttemptRecord
import app.javaquest.core.CourseLoader
import app.javaquest.core.SpacedRepetition
import app.javaquest.data.AttemptContext
import app.javaquest.data.Backup
import app.javaquest.data.ProgressData
import java.io.File
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

/**
 * Eine Sicherung muss in jeder Fassung lesbar sein – sonst hat, wer am Mac und unter Windows
 * lernt, zwei getrennte Lernstände. Lange hat das kein Test geprüft.
 *
 * Dieselben zwei Dateien liest auch die Apple-Testreihe (SicherungAustauschTests.swift) und
 * die Web-Prüfung (Web/tests/pruefungen.mjs) – mit denselben erwarteten Zahlen. Wer eine
 * davon ändert, muss sie überall ändern.
 */
class SicherungAustauschTest {
    private val course = CourseLoader.loadBundled()
    /** Zu diesem Zeitpunkt sind die Dateien „erstellt“; die fälligen Lernziele beziehen sich darauf. */
    private val stichtag = Instant.parse("2026-09-24T12:00:00Z")

    /** Die Tests laufen im Ordner Windows/, die Beispieldateien liegen im Repo daneben. */
    private fun datei(name: String) = File("../Tests/Sicherungen/$name").readText()

    /** Fällige Lernziele wie im ProgressStore: ohne die Einstufung. */
    private fun faellig(stand: ProgressData): Int = SpacedRepetition.goals(
        stand.attempts.filter { it.context != AttemptContext.PLACEMENT.raw }
            .map { AttemptRecord(it.taskId, it.credit, Instant.parse(it.date)) },
        course,
    ).values.count { it.isDue(stichtag) }

    @Test
    fun `eine Sicherung aus der Mac- oder iPhone-App wird gelesen`() {
        // Swift lässt leere Felder beim Schreiben weg – hier fehlt „lessonId“ bei jeder
        // Trainings- und Übungsantwort. Das darf das Einlesen nicht scheitern lassen.
        val stand = assertNotNull(Backup.lesen(datei("aus-der-app.json")), "Mac-Sicherung wurde abgelehnt")

        assertEquals(10, stand.attempts.size)
        assertEquals(2, stand.lessonRecords.values.count { it.isCompleted })
        assertEquals(3, faellig(stand))
        assertEquals(32, Backup.vereine(stand, stand, course).masterScore)
    }

    @Test
    fun `eine Sicherung aus der Web-App wird gelesen – mit derselben Wiedervorlage`() {
        val stand = assertNotNull(Backup.lesen(datei("aus-dem-web.json")), "Web-Sicherung wurde abgelehnt")

        assertEquals(7, stand.attempts.size)
        assertEquals(1, stand.lessonRecords.values.count { it.isCompleted })
        // 4 fällige Lernziele – genau so viele zählt die Web-App in ihrem eigenen Stand.
        assertEquals(4, faellig(stand))
        assertEquals(12, Backup.vereine(stand, stand, course).masterScore)
    }

    @Test
    fun `zweimal eingelesen ergibt keine doppelten Eintraege`() {
        for (name in listOf("aus-der-app.json", "aus-dem-web.json")) {
            val stand = assertNotNull(Backup.lesen(datei(name)))
            assertEquals(stand.attempts.size, Backup.vereine(stand, stand, course).attempts.size, name)
        }
    }
}
