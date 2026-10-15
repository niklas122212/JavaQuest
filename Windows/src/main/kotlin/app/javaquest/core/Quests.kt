package app.javaquest.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull

/**
 * „Code-Quests“: Ein Abenteuer, das durch Code vorankommt. Jede Quest führt ein Java-Konzept ein, erzählt eine
 * Szene („Die Tür ist verschlossen …“) und prüft den Code des Spielers mit versteckten Tests – wie JUnit.
 * Die Daten stehen in `code_quests.json`, derselben Datei wie in der Apple-App.
 */
class QuestBook(val title: String, val intro: String, val chapters: List<QuestChapter>, val quests: List<CodeQuest>) {
    fun quest(id: String): CodeQuest? = quests.firstOrNull { it.id == id }
    fun quests(chapter: QuestChapter): List<CodeQuest> = quests.filter { it.chapterId == chapter.id }
    fun chapter(id: String): QuestChapter? = chapters.firstOrNull { it.id == id }

    /** Die Quest davor in der Geschichte – sie muss geschafft sein, damit es weitergeht. */
    fun previous(quest: CodeQuest): CodeQuest? {
        val index = quests.indexOfFirst { it.id == quest.id }
        return if (index > 0) quests[index - 1] else null
    }

    companion object {
        const val FILE = "code_quests.json"
        /** Quest-IDs beginnen damit – so lassen sie sich im Protokoll von Arena-Missionen unterscheiden. */
        const val ID_PREFIX = "quest-"
        val EMPTY = QuestBook("", "", emptyList(), emptyList())

        fun loadBundled(): QuestBook {
            val stream = QuestBook::class.java.getResourceAsStream("/$FILE") ?: error("Die Datei $FILE fehlt.")
            return parse(stream.bufferedReader(Charsets.UTF_8).use { it.readText() })
        }

        fun parse(text: String): QuestBook {
            val root = Json.parseToJsonElement(text).jsonObject
            return QuestBook(
                title = root.str("title"),
                intro = root.str("intro"),
                chapters = root.getValue("chapters").jsonArray.map { c ->
                    val o = c.jsonObject
                    QuestChapter(o.str("id"), o.str("title"), o.str("story"), o.str("symbol"))
                },
                quests = root.getValue("quests").jsonArray.map { parseQuest(it.jsonObject) },
            )
        }

        private fun JsonObject.str(key: String) = getValue(key).jsonPrimitive.content
        private fun JsonObject.optStr(key: String) = (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content

        private fun parseQuest(q: JsonObject): CodeQuest {
            val concept = q.getValue("concept").jsonObject
            val reward = q.getValue("reward").jsonObject
            val blueprint = q["blueprint"] as? JsonObject
            return CodeQuest(
                id = q.str("id"),
                chapterId = q.str("chapterId"),
                title = q.str("title"),
                lessonId = q.str("lessonId"),
                topicId = q.str("topicId"),
                difficulty = q.getValue("difficulty").jsonPrimitive.content.toInt(),
                story = q.str("story"),
                task = q.str("task"),
                concept = QuestConcept(concept.str("title"), concept.str("text"), concept.str("code")),
                className = q.str("className"),
                starterCode = q.str("starterCode"),
                solution = q.str("solution"),
                tests = q.getValue("tests").jsonArray.map { parseTest(it.jsonObject) },
                requirements = (q["requirements"] as? JsonArray)?.map { CourseLoader.parseRule(it.jsonObject) } ?: emptyList(),
                success = q.str("success"),
                reward = QuestReward(reward.str("item"), reward.str("symbol"), reward.str("text")),
                blueprint = blueprint?.let { QuestBlueprint(it.str("title"), it.str("text"), it.str("code")) },
            )
        }

        private fun parseTest(t: JsonObject): QuestTest {
            val expect = t.getValue("expect").jsonObject
            val expectation = when {
                "value" in expect -> QuestExpectation.Value(parseValue(expect.getValue("value")))
                "text" in expect -> QuestExpectation.Text(expect.str("text"))
                "output" in expect -> QuestExpectation.Output(expect.str("output"))
                "exception" in expect -> QuestExpectation.Exception(expect.str("exception"))
                else -> error("Ein Test braucht value, text, output oder exception.")
            }
            return QuestTest(
                name = t.str("name"),
                setup = t.optStr("setup") ?: "",
                expression = t.optStr("expression"),
                expect = expectation,
                isVisible = (t["visible"] as? JsonPrimitive)?.booleanOrNull ?: false,
                hint = t.str("hint"),
            )
        }

        private fun parseValue(element: kotlinx.serialization.json.JsonElement): QuestValue {
            if (element is JsonNull) return QuestValue.NullV
            val p = element.jsonPrimitive
            return when {
                p.isString -> QuestValue.StringV(p.content)
                p.booleanOrNull != null -> QuestValue.BooleanV(p.booleanOrNull!!)
                p.longOrNull != null -> QuestValue.IntegerV(p.longOrNull!!)
                else -> QuestValue.DoubleV(p.doubleOrNull ?: error("Unbekannter Wert $p"))
            }
        }
    }
}

data class QuestChapter(val id: String, val title: String, val story: String, val symbol: String)

/** Eine Quest: Szene, Auftrag, neues Konzept, Startcode, Musterlösung und versteckte Tests. */
data class CodeQuest(
    val id: String,
    val chapterId: String,
    val title: String,
    /** Die Quest wird frei, sobald diese Lektion erreicht ist. */
    val lessonId: String,
    val topicId: String,
    val difficulty: Int,
    val story: String,
    val task: String,
    val concept: QuestConcept,
    /** Die Klasse, um die es geht (und damit der Dateiname `Tuer.java`). */
    val className: String,
    val starterCode: String,
    val solution: String,
    val tests: List<QuestTest>,
    /** Bausteine, die verlangt oder verboten sind (z. B. „Nutze eine Schleife“). */
    val requirements: List<CodeRule>,
    val success: String,
    val reward: QuestReward,
    /** Ein Bauplan für die Werkstatt, den man mit dieser Quest freischaltet. */
    val blueprint: QuestBlueprint?,
) {
    /** Die sichtbaren Beispiel-Tests – die übrigen bleiben bis zum Lösen geheim. */
    val visibleTests: List<QuestTest> get() = tests.filter { it.isVisible }
}

data class QuestConcept(val title: String, val text: String, val code: String)

data class QuestReward(val item: String, val symbol: String, val text: String)

/** Vorlage für die Werkstatt („Bauplan“) – ein Stück Code, das man dort einfügen kann. */
data class QuestBlueprint(val title: String, val text: String, val code: String)

/** Ein versteckter Test – wie eine JUnit-Assertion: Vorbereitung, Ausdruck und erwarteter Wert. */
data class QuestTest(
    val name: String,
    val setup: String,
    val expression: String?,
    val expect: QuestExpectation,
    val isVisible: Boolean,
    val hint: String,
) {
    /** Der Test als Java-Code, wie er in einer JUnit-Testklasse stünde. */
    val assertion: String
        get() {
            val prefix = if (setup.isEmpty()) "" else setup + "\n"
            return prefix + when (expect) {
                is QuestExpectation.Value -> "assertEquals(${expect.value.javaLiteral}, ${expression ?: ""});"
                is QuestExpectation.Text -> "assertEquals(\"${expect.text}\", String.valueOf(${expression ?: ""}));"
                is QuestExpectation.Output -> "// Ausgabe: " + expect.output.replace("\n", " ⏎ ")
                is QuestExpectation.Exception -> "assertThrows(${expect.className}.class, () -> ${expression ?: ""});"
            }
        }
}

/** Was ein Test erwartet. */
sealed interface QuestExpectation {
    /** Ein Wert – verglichen mit Typ: `true`, `42`, `2.5`, `"Hallo"`. */
    data class Value(val value: QuestValue) : QuestExpectation
    /** Der Text, den `println` zeigen würde – für Objekte, Listen und Maps. */
    data class Text(val text: String) : QuestExpectation
    /** Die Ausgabe auf der Konsole. */
    data class Output(val output: String) : QuestExpectation
    /** Eine Exception dieser Klasse, z. B. `IllegalArgumentException`. */
    data class Exception(val className: String) : QuestExpectation
}

/** Ein erwarteter Wert aus dem JSON: Wahrheitswert, ganze Zahl, Kommazahl, Text oder null. */
sealed interface QuestValue {
    data class BooleanV(val value: Boolean) : QuestValue
    data class IntegerV(val value: Long) : QuestValue
    data class DoubleV(val value: Double) : QuestValue
    data class StringV(val value: String) : QuestValue
    data object NullV : QuestValue

    /** Der Wert, wie er in Java-Code stünde. */
    val javaLiteral: String
        get() = when (this) {
            is BooleanV -> value.toString()
            is IntegerV -> value.toString()
            is DoubleV -> value.toString()
            is StringV -> "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
            NullV -> "null"
        }
}
