package app.javaquest.android

import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.javaquest.core.ArenaCatalog
import app.javaquest.core.CourseLoader
import app.javaquest.data.ProgressFile
import app.javaquest.data.ProgressStore
import app.javaquest.ui.AppState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Hält Kurs und Lernstand, solange der Prozess lebt.
 *
 * Die Kursdatei hat knapp 3 MB; sie wird einmal im Hintergrund gelesen und nicht bei jedem
 * neuen Activity-Objekt (etwa nach dem Zurückkehren aus der Dateiauswahl) erneut.
 */
object Sitzung {
    private const val TAG = "JavaQuest"

    var zustand by mutableStateOf<AppState?>(null)
        private set
    var fehler by mutableStateOf<String?>(null)
        private set

    private var laeuft = false

    /** Wo der Lernstand liegt: im privaten App-Speicher, den nur JavaQuest lesen kann. */
    fun lernstandDatei(context: Context): File = File(context.filesDir, "progress.json")

    /** Lädt Kurs und Lernstand, falls das nicht schon geschehen ist. Aufruf vom Main-Thread. */
    suspend fun laden(context: Context) {
        if (zustand != null || laeuft) return
        laeuft = true
        fehler = null
        try {
            val appContext = context.applicationContext
            zustand = withContext(Dispatchers.IO) {
                val start = System.nanoTime()
                fun lies(name: String) = appContext.assets.open(name).bufferedReader(Charsets.UTF_8).use { it.readText() }
                val text = lies("java_course.json")
                // Bonus-Aufgaben (Code-Puzzle, Bug-Jagd) und Arena-Missionen liegen neben dem Kurs.
                // Fehlt eine der Dateien, läuft die App ohne sie weiter.
                val kurs = CourseLoader.parse(text, extraTasks = runCatching { lies(CourseLoader.EXTRA_TASKS_FILE) }.getOrNull())
                val missionen = runCatching { ArenaCatalog.parse(lies("arena_missions.json")) }.getOrDefault(ArenaCatalog.EMPTY)
                val store = ProgressStore(kurs, ProgressFile(lernstandDatei(appContext).toPath()), catalog = missionen)
                Log.i(TAG, "Kurs geladen: ${kurs.modules.size} Module, ${kurs.allLessons.size} Lektionen " +
                    "in ${(System.nanoTime() - start) / 1_000_000} ms")
                AppState(store)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Kurs oder Lernstand ließ sich nicht laden", e)
            fehler = e.message ?: e.javaClass.simpleName
        } finally {
            laeuft = false
        }
    }
}
