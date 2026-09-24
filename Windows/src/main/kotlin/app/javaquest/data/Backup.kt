package app.javaquest.data

import app.javaquest.core.Course
import app.javaquest.core.LessonResult
import app.javaquest.core.MasterScore
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Sicherung des Lernstands als Datei zum Mitnehmen.
 *
 * Der Stand liegt sonst ausschließlich in einer Datei im Benutzerverzeichnis. Ein neuer
 * Rechner, ein zurückgesetztes Windows, ein versehentlich gelöschter Ordner – und er ist
 * weg. Eine Sicherung ist die einzige Absicherung, die ohne Konto und ohne Server auskommt.
 */
@Serializable
data class BackupFile(
    val app: String = KENNUNG,
    val version: Int = 1,
    val erstellt: String,
    val stand: ProgressData,
) {
    companion object {
        const val KENNUNG = "JavaQuest"
    }
}

object Backup {
    private val json = Json { ignoreUnknownKeys = true; prettyPrint = true; encodeDefaults = true }

    fun schreiben(data: ProgressData, jetzt: String): String =
        json.encodeToString(BackupFile.serializer(), BackupFile(erstellt = jetzt, stand = data))

    /** Liest eine Sicherung; null, wenn die Datei keine ist oder nicht lesbar ist. */
    /** Der Zeitpunkt, zu dem die Sicherung geschrieben wurde – oder null. */
    fun erstellt(text: String): String? = runCatching {
        json.decodeFromString(BackupFile.serializer(), text).erstellt
    }.getOrNull()

    fun lesen(text: String): ProgressData? = runCatching {
        val datei = json.decodeFromString(BackupFile.serializer(), text)
        if (datei.app == BackupFile.KENNUNG) datei.stand else null
    }.getOrNull()

    /**
     * Führt zwei Stände zusammen, statt einen zu überschreiben.
     *
     * Beim Einlesen darf nichts verlorengehen – weder das Gesicherte noch das, was seit
     * der Sicherung dazugekommen ist. Deshalb gewinnt bei jeder Lektion das bessere
     * Ergebnis, das Aufgaben-Protokoll wird vereinigt statt ersetzt, und der Score wird
     * aus dem Ergebnis neu berechnet statt übernommen.
     */
    fun vereine(eigen: ProgressData, fremd: ProgressData, course: Course): ProgressData {
        // Lektionen: das bessere Ergebnis gewinnt, abgeschlossen bleibt abgeschlossen.
        val lektionen = (eigen.lessonRecords.keys + fremd.lessonRecords.keys).associateWith { id ->
            val a = eigen.lessonRecords[id]
            val b = fremd.lessonRecords[id]
            when {
                a == null -> b!!
                b == null -> a
                else -> LessonRecord(
                    bestAccuracy = maxOf(a.bestAccuracy, b.bestAccuracy),
                    lastAccuracy = if (spaeter(a.lastPlayedAt, b.lastPlayedAt)) a.lastAccuracy else b.lastAccuracy,
                    playCount = maxOf(a.playCount, b.playCount),
                    isCompleted = a.isCompleted || b.isCompleted,
                    completedViaPlacement = a.completedViaPlacement && b.completedViaPlacement,
                    firstCompletedAt = frueher(a.firstCompletedAt, b.firstCompletedAt),
                    lastPlayedAt = spaeteres(a.lastPlayedAt, b.lastPlayedAt),
                )
            }
        }

        // Themen: der Stand mit mehr Aufgaben weiß mehr.
        val themen = (eigen.topicMasteries.keys + fremd.topicMasteries.keys).associateWith { id ->
            val a = eigen.topicMasteries[id]
            val b = fremd.topicMasteries[id]
            when {
                a == null -> b!!
                b == null -> a
                a.attempts >= b.attempts -> a
                else -> b
            }
        }

        // Aufgaben-Protokoll: vereinigen, doppelte Einträge fallen weg. Es ist die
        // Grundlage für Varianten und Wiedervorlage – hier darf nichts verschwinden.
        val protokoll = (eigen.attempts + fremd.attempts)
            .distinctBy { listOf(it.taskId, it.date, it.context) }
            .sortedBy { it.date }

        val verlauf = (eigen.scoreHistory + fremd.scoreHistory)
            .distinctBy { listOf(it.date, it.score, it.reason) }
            .sortedBy { it.date }

        val vereint = eigen.copy(
            createdAt = frueher(eigen.createdAt, fremd.createdAt) ?: eigen.createdAt,
            experienceLevel = eigen.experienceLevel,
            placedLevel = eigen.placedLevel ?: fremd.placedLevel,
            placementScore = eigen.placementScore ?: fremd.placementScore,
            onboardingCompleted = eigen.onboardingCompleted || fremd.onboardingCompleted,
            currentStreak = if (spaeter(eigen.lastActiveDay, fremd.lastActiveDay)) eigen.currentStreak else fremd.currentStreak,
            longestStreak = maxOf(eigen.longestStreak, fremd.longestStreak),
            lastActiveDay = spaeteres(eigen.lastActiveDay, fremd.lastActiveDay),
            lessonRecords = lektionen,
            topicMasteries = themen,
            attempts = protokoll,
            scoreHistory = verlauf,
        )
        // Der Score ergibt sich aus den Lektionen – nach dem Zusammenführen neu rechnen,
        // statt eine der beiden gespeicherten Zahlen zu übernehmen.
        val ergebnisse = lektionen.mapValues { (_, r) -> LessonResult(r.bestAccuracy, r.isCompleted, r.completedViaPlacement) }
        return vereint.copy(masterScore = MasterScore.compute(course, ergebnisse))
    }

    private fun spaeter(a: String?, b: String?): Boolean = (a ?: "") >= (b ?: "")
    private fun spaeteres(a: String?, b: String?): String? = listOfNotNull(a, b).maxOrNull()
    private fun frueher(a: String?, b: String?): String? = listOfNotNull(a, b).minOrNull()
}
