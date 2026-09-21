package app.javaquest.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Schwierigkeitsgrad einer Aufgabe auf der Skala 1 bis 5. */
enum class Difficulty(val level: Int, val label: String) {
    VERY_EASY(1, "Sehr leicht"),
    EASY(2, "Leicht"),
    MEDIUM(3, "Mittel"),
    DEMANDING(4, "Anspruchsvoll"),
    HARD(5, "Schwer");

    /** Anzeige wie „Niveau: Leicht - 2/5“. */
    val badgeText: String get() = "Niveau: $label - $level/$SCALE_MAXIMUM"

    /** Gewicht in allen Scores: schwere Aufgaben zählen mehr als leichte. */
    val weight: Double get() = level.toDouble()

    companion object {
        const val SCALE_MAXIMUM = 5
        fun clamped(value: Int): Difficulty = entries[value.coerceIn(1, SCALE_MAXIMUM) - 1]
    }
}

/** Selbsteinschätzung beim App-Start. Jede Stufe hat ein Einstiegsmodul im Kurs. */
enum class ExperienceLevel(val raw: String, val title: String) {
    BEGINNER("beginner", "Anfänger"),
    INTERMEDIATE("intermediate", "Leicht fortgeschritten"),
    ADVANCED("advanced", "Erfahren");

    val onboardingTitle: String
        get() = if (this == BEGINNER) "Ich habe 0 Erfahrung" else "Ich habe schon Vorkenntnisse"

    val onboardingSummary: String
        get() = if (this == BEGINNER) {
            "Kein Problem! Du startest mit dem Grundkurs: kurze Theorie, jede Codezeile erklärt, sehr einfache Aufgaben."
        } else {
            "Beantworte eine Einstufungsfrage. Ab 65 % überspringst du den Grundkurs und startest bei den Objekten."
        }

    /** Nur mit Vorkenntnissen gibt es die Einstufungsfrage. */
    val requiresPlacement: Boolean get() = this == INTERMEDIATE

    /** Stufe, auf die bei nicht bestandener Einstufung zurückgefallen wird. */
    val fallback: ExperienceLevel get() = if (this == ADVANCED) INTERMEDIATE else BEGINNER

    companion object {
        /** Die beiden Wahlmöglichkeiten beim App-Start. */
        val onboardingChoices = listOf(BEGINNER, INTERMEDIATE)
        fun fromRaw(raw: String?): ExperienceLevel? = entries.firstOrNull { it.raw == raw }
    }
}

/** Ein Begriff aus dem Befehlslexikon. */
data class GlossaryEntry(val term: String, val meaning: String)

/** Eine Codezeile mit ihrer Erklärung in Alltagssprache und den Befehlen darin. */
data class SnippetLine(val code: String, val explain: String?, val terms: List<String>)

/** Eine erklärte Zeile, bereit für die Anzeige (Nummer ab 1). */
data class ExplainedLine(val number: Int, val code: String, val explanation: String, val terms: List<GlossaryEntry>)

/** Java-Code zusammen mit seiner Zeile-für-Zeile-Erklärung. */
data class CodeSnippet(val lines: List<SnippetLine>) {
    val source: String get() = lines.joinToString("\n") { it.code }

    /** Zeilen mit Inhalt, denen keine Erklärung mitgegeben wurde (1-basiert). */
    val linesMissingExplanation: List<Int>
        get() = lines.mapIndexedNotNull { index, line ->
            if (line.code.isBlank() || !line.explain.isNullOrBlank()) null else index + 1
        }

    /** Alle Zeilen mit Inhalt, erklärt. Leerzeilen fallen weg (die Nummern bleiben). */
    fun explained(glossary: Map<String, String>): List<ExplainedLine> =
        lines.mapIndexedNotNull { index, line ->
            if (line.code.isBlank()) return@mapIndexedNotNull null
            ExplainedLine(
                number = index + 1,
                code = line.code,
                explanation = line.explain ?: "",
                terms = line.terms.mapNotNull { term -> glossary[term]?.let { GlossaryEntry(term, it) } },
            )
        }

    companion object {
        fun of(source: String) = CodeSnippet(source.split("\n").map { SnippetLine(it, null, emptyList()) })
    }
}

enum class JavaContext(val instruction: String) {
    STATEMENTS("Schreibe nur die Anweisungen – der main-Block ist schon da."),
    MEMBERS("Schreibe die Methoden bzw. Felder innerhalb der Klasse."),
    FILE("Schreibe den vollständigen Code inklusive Klassen."),
}

enum class TaskType(val title: String) {
    SINGLE_CHOICE("Multiple Choice"),
    FILL_BLANK("Lückentext"),
    PREDICT_OUTPUT("Ausgabe vorhersagen"),
    CODE("Code schreiben"),
}

data class Blank(val accepted: List<String>, val caseSensitive: Boolean = true) {
    /** Gleiche Regeln wie der Evaluator – für die farbige Markierung einzelner Lücken. */
    fun accepts(value: String): Boolean = AnswerEvaluator.blankAccepts(this, JavaSource.normalizingTypography(value))
}

enum class RuleKind { REQUIRE, FORBID }
enum class RuleScope { CODE, RAW }
enum class StructureCheck { BALANCED_DELIMITERS, SEMICOLONS }

data class CodeRule(
    val rule: RuleKind,
    val pattern: String,
    val message: String,
    val scope: RuleScope = RuleScope.CODE,
    val weight: Double = 1.0,
)

sealed interface TaskKind {
    val type: TaskType

    data class SingleChoice(val choices: List<String>, val correctIndex: Int) : TaskKind {
        override val type get() = TaskType.SINGLE_CHOICE
    }

    /** Lückentext: die Vorlage enthält Platzhalter {{0}}, {{1}} … */
    data class FillBlank(val template: CodeSnippet, val blanks: List<Blank>) : TaskKind {
        override val type get() = TaskType.FILL_BLANK

        /** Die Vorlage mit der ersten richtigen Antwort in jeder Lücke – samt Erklärungen. */
        val solvedSnippet: CodeSnippet
            get() = CodeSnippet(template.lines.map { line ->
                var code = line.code
                val terms = line.terms.toMutableList()
                blanks.forEachIndexed { index, blank ->
                    if (placeholder(index) !in code) return@forEachIndexed
                    val answer = blank.accepted.firstOrNull() ?: ""
                    code = code.replace(placeholder(index), answer)
                    // Der eingesetzte Befehl wird jetzt ebenfalls erklärt (Methoden stehen im Lexikon mit „()“).
                    for (candidate in listOf(answer, "$answer()")) if (candidate !in terms) terms += candidate
                }
                line.copy(code = code, terms = terms)
            })

        /** Zeilen (ab 1) mit einer Lücke – ihre Erklärung bleibt bis zum Lösen verborgen. */
        val blankLineNumbers: Set<Int>
            get() = template.lines.mapIndexedNotNull { index, line -> if ("{{" in line.code) index + 1 else null }.toSet()

        companion object {
            fun placeholder(index: Int) = "{{$index}}"
        }
    }

    data class PredictOutput(val expectedOutput: String, val alsoAccepted: List<String> = emptyList()) : TaskKind {
        override val type get() = TaskType.PREDICT_OUTPUT
    }

    /** Freie Code-Eingabe, geprüft durch Plausibilitätsregeln statt durch einen Compiler. */
    data class Code(
        val starter: CodeSnippet,
        val solution: CodeSnippet,
        val expectedOutput: String?,
        val rules: List<CodeRule>,
        val structure: List<StructureCheck>,
    ) : TaskKind {
        override val type get() = TaskType.CODE
    }
}

data class LearningTask(
    val id: String,
    val topicId: String,
    val difficulty: Difficulty,
    val prompt: String,
    val code: CodeSnippet?,
    val hint: String?,
    val explanation: String,
    val javaContext: JavaContext,
    val kind: TaskKind,
    /** Aufgaben derselben Gruppe fragen dasselbe Lernziel ab; pro Sitzung kommt eine davon dran. */
    val variantGroup: String? = null,
    /** UML-Klassendiagramm zur Aufgabe. */
    val diagram: UmlDiagram? = null,
) {
    val type: TaskType get() = kind.type

    /** Gruppenschlüssel für die Variantenauswahl (eigene ID, falls keine Gruppe gesetzt ist). */
    val groupKey: String get() = variantGroup ?: id
}

data class Topic(val id: String, val title: String, val symbol: String, val summary: String)

enum class CalloutKind { TIP, WARNING, INFO }
data class Callout(val kind: CalloutKind, val text: String)

/** Ein „Theorie-Happen“: kurze Karte mit Text, optional erklärtem Codebeispiel und Hinweis. */
data class TheoryCard(
    val title: String,
    val body: String,
    val example: CodeSnippet?,
    val callout: Callout?,
    /** UML-Klassendiagramm zur Karte – wird unter dem Text gezeichnet. */
    val diagram: UmlDiagram? = null,
)

data class Lesson(
    val id: String,
    val title: String,
    val summary: String,
    val topicIds: List<String>,
    val estimatedMinutes: Int,
    val theory: List<TheoryCard>,
    val tasks: List<LearningTask>,
) {
    /** Punktgewicht im Java Master Score (Summe der Aufgabenniveaus). */
    val difficultyWeight: Double get() = tasks.sumOf { it.difficulty.weight }
}

data class CourseModule(
    val id: String,
    val title: String,
    val subtitle: String,
    val tier: ExperienceLevel,
    val symbol: String,
    val lessons: List<Lesson>,
)

data class PlacementConfig(
    val passThreshold: Int,
    val questionsPerTest: Int,
    val startDifficulty: Int,
    val pools: Map<String, List<LearningTask>>,
) {
    fun pool(level: ExperienceLevel): List<LearningTask> = pools[level.raw] ?: emptyList()
}

/** Der komplette, lokal mitgelieferte Kurs – dieselbe Datei wie in der iOS-App. */
data class Course(
    val id: String,
    val title: String,
    val topics: List<Topic>,
    val modules: List<CourseModule>,
    val placement: PlacementConfig,
    val glossary: Map<String, String>,
    /** Übungsaufgaben außerhalb der Lektionen: Varianten und Aufgaben je Thema. */
    val taskPool: List<LearningTask> = emptyList(),
) {
    val allLessons: List<Lesson> get() = modules.flatMap { it.lessons }
    val allTasks: List<LearningTask>
        get() = allLessons.flatMap { it.tasks } + taskPool + ExperienceLevel.entries.flatMap { placement.pool(it) }

    /** Alle übbaren Aufgaben (Lektionen + Pool) – ohne die Einstufungsfragen. */
    val practiceableTasks: List<LearningTask> get() = allLessons.flatMap { it.tasks } + taskPool

    /** Alle übbaren Aufgaben eines Themas, unabhängig vom Lernpfad. */
    fun tasksForTopic(topicId: String) = practiceableTasks.filter { it.topicId == topicId }

    /** Themen, zu denen es überhaupt Aufgaben gibt – Grundlage der freien Themenauswahl. */
    val practiceableTopics: List<Topic>
        get() {
            val withTasks = practiceableTasks.map { it.topicId }.toSet()
            return topics.filter { it.id in withTasks }
        }

    fun topic(id: String) = topics.firstOrNull { it.id == id }
    fun lesson(id: String) = allLessons.firstOrNull { it.id == id }
    fun moduleContaining(lessonId: String) = modules.firstOrNull { module -> module.lessons.any { it.id == lessonId } }

    /** Erstes Modul der Stufe – dort landet man nach der Einstufung. */
    fun entryModule(level: ExperienceLevel) = modules.firstOrNull { it.tier == level }

    /** Erste Lektion, in der ein Thema behandelt wird. */
    fun firstLesson(teaching: String) = allLessons.firstOrNull { teaching in it.topicIds }

    /** Alle Code-Schnipsel mit Fundstelle – für Tests. */
    val allSnippets: List<Pair<String, CodeSnippet>>
        get() = buildList {
            for (lesson in allLessons) {
                lesson.theory.forEachIndexed { index, card -> card.example?.let { add("${lesson.id} Theorie ${index + 1}" to it) } }
            }
            for (task in allTasks) {
                task.code?.let { add("${task.id} code" to it) }
                when (val kind = task.kind) {
                    is TaskKind.FillBlank -> add("${task.id} template" to kind.template)
                    is TaskKind.Code -> {
                        add("${task.id} starterCode" to kind.starter)
                        add("${task.id} sampleSolution" to kind.solution)
                    }
                    else -> Unit
                }
            }
        }
}

/** Liest `java_course.json`. Aufgaben stehen im JSON flach; `type` wählt die Variante. */
object CourseLoader {
    private val json = Json { ignoreUnknownKeys = true }

    fun loadBundled(): Course {
        val stream = CourseLoader::class.java.getResourceAsStream("/java_course.json")
            ?: error("Die Kursdatei java_course.json fehlt.")
        return parse(stream.bufferedReader(Charsets.UTF_8).use { it.readText() })
    }

    fun parse(text: String): Course {
        val root = json.parseToJsonElement(text).jsonObject
        val placement = root.obj("placement")
        return Course(
            id = root.str("id"),
            title = root.str("title"),
            topics = root.arr("topics").map { it.jsonObject.let { t -> Topic(t.str("id"), t.str("title"), t.str("symbol"), t.str("summary")) } },
            modules = root.arr("modules").map { parseModule(it.jsonObject) },
            placement = PlacementConfig(
                passThreshold = placement.int("passThreshold"),
                questionsPerTest = placement.int("questionsPerTest"),
                startDifficulty = placement.int("startDifficulty"),
                pools = placement.obj("pools").mapValues { (_, pool) -> pool.jsonArray.map { parseTask(it.jsonObject) } },
            ),
            glossary = (root["glossary"] as? JsonArray)?.associate { entry ->
                entry.jsonObject.str("term") to entry.jsonObject.str("meaning")
            } ?: emptyMap(),
            taskPool = (root["taskPool"] as? JsonArray)?.map { parseTask(it.jsonObject) } ?: emptyList(),
        )
    }

    private fun parseDiagram(d: JsonObject) = UmlDiagram(
        classes = d.arr("classes").map { entry ->
            val box = entry.jsonObject
            UmlBox(
                name = box.str("name"),
                kind = UmlBoxKind.fromRaw(box.optStr("kind")),
                fields = (box["fields"] as? JsonArray)?.map { parseMember(it.jsonObject) } ?: emptyList(),
                methods = (box["methods"] as? JsonArray)?.map { parseMember(it.jsonObject) } ?: emptyList(),
            )
        },
        relations = (d["relations"] as? JsonArray)?.map { entry ->
            val relation = entry.jsonObject
            UmlRelation(
                from = relation.str("from"),
                to = relation.str("to"),
                kind = UmlRelationKind.fromRaw(relation.str("kind")),
                label = relation.optStr("label"),
                multiplicity = relation.optStr("multiplicity"),
            )
        } ?: emptyList(),
    )

    private fun parseMember(m: JsonObject) = UmlMember(
        visibility = UmlVisibility.fromSymbol(m.str("visibility")),
        name = m.str("name"),
        type = m.optStr("type"),
    )

    private fun parseModule(m: JsonObject) = CourseModule(
        id = m.str("id"),
        title = m.str("title"),
        subtitle = m.str("subtitle"),
        tier = ExperienceLevel.fromRaw(m.str("tier")) ?: ExperienceLevel.BEGINNER,
        symbol = m.str("symbol"),
        lessons = m.arr("lessons").map { parseLesson(it.jsonObject) },
    )

    private fun parseLesson(l: JsonObject) = Lesson(
        id = l.str("id"),
        title = l.str("title"),
        summary = l.str("summary"),
        topicIds = l.arr("topicIds").map { it.jsonPrimitive.content },
        estimatedMinutes = l.int("estimatedMinutes"),
        theory = l.arr("theory").map { card ->
            val c = card.jsonObject
            TheoryCard(
                title = c.str("title"),
                body = c.str("body"),
                example = c["code"]?.let(::parseSnippet),
                callout = (c["callout"] as? JsonObject)?.let { callout ->
                    Callout(CalloutKind.valueOf(callout.str("kind").uppercase()), callout.str("text"))
                },
                diagram = (c["diagram"] as? JsonObject)?.let(::parseDiagram),
            )
        },
        tasks = l.arr("tasks").map { parseTask(it.jsonObject) },
    )

    fun parseTask(t: JsonObject): LearningTask {
        val kind: TaskKind = when (val type = t.str("type")) {
            "singleChoice" -> TaskKind.SingleChoice(t.arr("choices").map { it.jsonPrimitive.content }, t.int("correctIndex"))
            "fillBlank" -> TaskKind.FillBlank(
                template = parseSnippet(t.getValue("template")),
                blanks = t.arr("blanks").map { b ->
                    val blank = b.jsonObject
                    Blank(
                        accepted = blank.arr("accepted").map { it.jsonPrimitive.content },
                        caseSensitive = blank.optBool("caseSensitive") ?: true,
                    )
                },
            )
            "predictOutput" -> TaskKind.PredictOutput(
                expectedOutput = t.str("expectedOutput"),
                alsoAccepted = (t["alsoAccepted"] as? JsonArray)?.map { it.jsonPrimitive.content } ?: emptyList(),
            )
            "code" -> TaskKind.Code(
                starter = t["starterCode"]?.let(::parseSnippet) ?: CodeSnippet.of(""),
                solution = parseSnippet(t.getValue("sampleSolution")),
                expectedOutput = t.optStr("expectedOutput"),
                rules = t.arr("rules").map { r ->
                    val rule = r.jsonObject
                    CodeRule(
                        rule = RuleKind.valueOf(rule.str("rule").uppercase()),
                        pattern = rule.str("pattern"),
                        message = rule.str("message"),
                        scope = rule.optStr("scope")?.let { RuleScope.valueOf(it.uppercase()) } ?: RuleScope.CODE,
                        weight = (rule["weight"] as? JsonPrimitive)?.doubleOrNull ?: 1.0,
                    )
                },
                structure = (t["structure"] as? JsonArray)?.map { s ->
                    when (s.jsonPrimitive.content) {
                        "balancedDelimiters" -> StructureCheck.BALANCED_DELIMITERS
                        "semicolons" -> StructureCheck.SEMICOLONS
                        else -> error("Unbekannter Struktur-Check ${s.jsonPrimitive.content}")
                    }
                } ?: StructureCheck.entries,
            )
            else -> error("Unbekannter Aufgabentyp $type")
        }
        return LearningTask(
            id = t.str("id"),
            topicId = t.str("topicId"),
            difficulty = Difficulty.clamped(t.int("difficulty")),
            prompt = t.str("prompt"),
            code = t["code"]?.let(::parseSnippet),
            hint = t.optStr("hint"),
            explanation = t.str("explanation"),
            javaContext = when (t.optStr("javaContext")) {
                "members" -> JavaContext.MEMBERS
                "file" -> JavaContext.FILE
                else -> JavaContext.STATEMENTS
            },
            kind = kind,
            variantGroup = t.optStr("variantGroup"),
            diagram = (t["diagram"] as? JsonObject)?.let(::parseDiagram),
        )
    }

    /** Code-Felder sind entweder Text oder {"lines": [{"code", "explain", "terms"}]}. */
    fun parseSnippet(element: JsonElement): CodeSnippet = when (element) {
        is JsonPrimitive -> CodeSnippet.of(element.content)
        is JsonObject -> CodeSnippet(element.arr("lines").map { l ->
            val line = l.jsonObject
            SnippetLine(
                code = line.str("code"),
                explain = line.optStr("explain"),
                terms = (line["terms"] as? JsonArray)?.map { it.jsonPrimitive.content } ?: emptyList(),
            )
        })
        else -> error("Ungültiger Code-Schnipsel")
    }

    private fun JsonObject.str(key: String) = getValue(key).jsonPrimitive.content
    private fun JsonObject.optStr(key: String) = (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
    private fun JsonObject.int(key: String) = getValue(key).jsonPrimitive.intOrNull ?: error("$key ist keine Zahl")
    private fun JsonObject.optBool(key: String) = (this[key] as? JsonPrimitive)?.booleanOrNull
    private fun JsonObject.arr(key: String) = getValue(key).jsonArray
    private fun JsonObject.obj(key: String) = getValue(key).jsonObject
}
