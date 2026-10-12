package app.javaquest.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.javaquest.core.CodeQuest
import app.javaquest.core.JavaSource
import app.javaquest.core.QuestResult
import app.javaquest.core.QuestRunner
import app.javaquest.core.interpreter.JavaProblem
import app.javaquest.core.interpreter.JavaRunResult
import app.javaquest.core.interpreter.JavaRunner
import app.javaquest.data.ProgressStore
import app.javaquest.data.RewardGain
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** Eine laufende Quest: Code (als Entwurf gemerkt), Testlauf, Mentor und Belohnung – wie in der Apple-App. */
class QuestSessionModel(val quest: CodeQuest, private val store: ProgressStore) {
    private val draftKey = "quest:${quest.id}"

    var code by mutableStateOf(store.entwurf(draftKey) ?: quest.starterCode)
        private set
    var result by mutableStateOf<QuestResult?>(null)
        private set
    var isRunning by mutableStateOf(false)
        private set
    /** Läufe ohne Erfolg – nach dreien bietet der Mentor die Musterlösung zum Ansehen an. */
    var failedRuns by mutableIntStateOf(0)
        private set
    var rewardGain by mutableStateOf<RewardGain?>(null)
        private set
    /** Sterne vor diesem Besuch – „Neuer Bestwert“ und frisch freigeschaltete Baupläne. */
    val previousStars: Int = store.questProgress.stars[quest.id] ?: 0
    /** Der Code, der zuletzt geprüft wurde – ändert man danach etwas, gilt das Ergebnis als veraltet. */
    private var checkedCode by mutableStateOf<String?>(null)

    val isSolved: Boolean get() = result?.solved == true
    val isStale: Boolean get() = checkedCode != null && checkedCode != code

    /** Die Zeile, an der der letzte Lauf hängen blieb – der Editor markiert sie rot. */
    val errorLine: Int? get() = if (isStale) null else result?.let { it.compileProblem?.line ?: it.mentor.line }

    val nextQuest: CodeQuest?
        get() {
            val quests = store.questBook.quests
            val next = quests.getOrNull(quests.indexOfFirst { it.id == quest.id } + 1) ?: return null
            return next.takeIf { store.questProgress.state(it).isPlayable }
        }

    fun updateCode(text: String) {
        code = text
        store.entwurfMerken(draftKey, text)
    }

    suspend fun run() {
        if (isRunning) return
        isRunning = true
        val source = code
        val before = store.rewardSnapshot()
        val outcome = withContext(Dispatchers.Default) { QuestRunner.run(source, quest) }
        result = outcome
        checkedCode = source
        isRunning = false
        if (outcome.solved) {
            store.recordQuest(quest, outcome.stars)
            rewardGain = store.rewardSnapshot().gains(before).takeIf { !it.isEmpty }
        } else {
            failedRuns++
        }
    }

    fun reset() {
        updateCode(quest.starterCode)
        result = null
        checkedCode = null
    }
}

/** Ein eigenes Programm in der Werkstatt. */
@Serializable
data class WorkshopProject(val id: Long, val name: String, val code: String)

/** Die Werkstatt: freies Bauen mit eigenen Programmen – gemerkt in den Entwürfen dieses Geräts. */
class WorkshopModel(private val store: ProgressStore) {
    private val json = Json { ignoreUnknownKeys = true }
    val projects = mutableStateListOf<WorkshopProject>()
    var selectedId by mutableStateOf(0L)
        private set
    var output by mutableStateOf("")
        private set
    var problem by mutableStateOf<JavaProblem?>(null)
        private set
    var warnings by mutableStateOf<List<String>>(emptyList())
        private set
    var isRunning by mutableStateOf(false)
        private set
    /** Der Code des letzten Laufs – nur dafür gibt es „Zusehen“. */
    var ranCode by mutableStateOf<String?>(null)
        private set
    /** Bitte an den Editor, einen Bauplan einzufügen. */
    var insertion by mutableStateOf<EditorInsertion?>(null)
        private set

    init {
        val stored = store.entwurf(KEY)?.let { runCatching { json.decodeFromString(ListSerializer(WorkshopProject.serializer()), it) }.getOrNull() }
        projects += stored?.takeIf { it.isNotEmpty() } ?: listOf(template(1, "Mein Programm"))
        selectedId = projects.first().id
    }

    val selected: WorkshopProject? get() = projects.firstOrNull { it.id == selectedId }
    val code: String get() = selected?.code ?: ""

    fun updateCode(text: String) {
        val index = projects.indexOfFirst { it.id == selectedId }
        if (index < 0 || projects[index].code == text) return
        projects[index] = projects[index].copy(code = text)
        save()
    }

    fun select(id: Long) {
        selectedId = id
        output = ""
        problem = null
        warnings = emptyList()
        ranCode = null
    }

    fun newProject() {
        val id = (projects.maxOfOrNull { it.id } ?: 0) + 1
        projects += template(id, "Programm ${projects.size + 1}")
        select(id)
        save()
    }

    fun rename(name: String) {
        val index = projects.indexOfFirst { it.id == selectedId }
        if (index < 0 || name.isBlank()) return
        projects[index] = projects[index].copy(name = name.trim())
        save()
    }

    fun deleteSelected() {
        projects.removeAll { it.id == selectedId }
        if (projects.isEmpty()) projects += template(1, "Mein Programm")
        select(projects.first().id)
        save()
    }

    fun insert(snippet: String) {
        insertion = EditorInsertion((insertion?.id ?: 0) + 1, snippet)
    }

    suspend fun run() {
        if (isRunning) return
        isRunning = true
        val source = JavaSource.normalizingTypography(code)
        val result: JavaRunResult = withContext(Dispatchers.Default) { JavaRunner.run(source) }
        output = result.output
        problem = result.problem
        warnings = result.warnings.map { "Hinweis, Zeile ${it.line}: ${it.message}" }
        ranCode = source
        isRunning = false
    }

    private fun save() = store.entwurfMerken(KEY, json.encodeToString(ListSerializer(WorkshopProject.serializer()), projects.toList()))

    companion object {
        private const val KEY = "werkstatt"

        fun template(id: Long, name: String): WorkshopProject {
            val letters = name.filter { it.isLetterOrDigit() }
            val className = letters.replaceFirstChar { it.uppercaseChar() }.takeIf { it.firstOrNull()?.isLetter() == true } ?: "MeinProgramm"
            return WorkshopProject(
                id, name,
                "public class $className {\n    public static void main(String[] args) {\n        System.out.println(\"Hallo aus der Werkstatt!\");\n    }\n}",
            )
        }
    }
}
