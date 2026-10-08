package app.javaquest.core

import app.javaquest.core.interpreter.CallContext
import app.javaquest.core.interpreter.JValue
import app.javaquest.core.interpreter.JavaHost
import app.javaquest.core.interpreter.JavaProblem
import app.javaquest.core.interpreter.JavaRunResult
import app.javaquest.core.interpreter.JavaRunner
import app.javaquest.core.interpreter.JavaVariable
import app.javaquest.core.interpreter.JavaWarning
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

// Arena: Der Roboter „Byte“ wird mit echtem Java gesteuert – gleiche Missionsdatei und Regeln wie in der iOS-App.

enum class Heading(val raw: String, val degrees: Float, val dx: Int, val dy: Int) {
    NORTH("north", 270f, 0, -1), EAST("east", 0f, 1, 0), SOUTH("south", 90f, 0, 1), WEST("west", 180f, -1, 0);

    val left: Heading get() = when (this) { NORTH -> WEST; WEST -> SOUTH; SOUTH -> EAST; EAST -> NORTH }
    val right: Heading get() = when (this) { NORTH -> EAST; EAST -> SOUTH; SOUTH -> WEST; WEST -> NORTH }

    /** Blickrichtung in Worten, wie man sie auf dem Spielfeld sieht. */
    val direction: String get() = when (this) { NORTH -> "nach oben"; EAST -> "nach rechts"; SOUTH -> "nach unten"; WEST -> "nach links" }

    companion object {
        fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } ?: EAST
    }
}

data class GridPoint(val x: Int, val y: Int) {
    fun moved(heading: Heading) = GridPoint(x + heading.dx, y + heading.dy)
}

/** Spielwelt als Textkarte: `#` Wand · `.` Boden · `o` Münze · `G` Ziel · `R` Start des Roboters. */
data class ArenaWorld(val map: List<String>, val facing: Heading = Heading.EAST, val expectedOutput: String? = null) {
    val width: Int get() = map.maxOfOrNull { it.length } ?: 0
    val height: Int get() = map.size

    private fun cell(p: GridPoint): Char = map.getOrNull(p.y)?.getOrNull(p.x) ?: '#'
    private fun points(c: Char) = map.flatMapIndexed { y, row -> row.mapIndexedNotNull { x, ch -> if (ch == c) GridPoint(x, y) else null } }

    fun isWall(p: GridPoint) = cell(p) == '#'
    val coins: Set<GridPoint> get() = points('o').toSet()
    val goal: GridPoint? get() = points('G').firstOrNull()
    val start: GridPoint? get() = points('R').firstOrNull()
}

/** Zusatzziel für Stern 2 und 3. */
sealed interface StarCriterion {
    val title: String

    data object AllCoins : StarCriterion { override val title = "Alle Münzen eingesammelt" }
    data class MaxLines(val limit: Int) : StarCriterion { override val title get() = "Höchstens $limit Zeilen Code" }
    data class MaxActions(val limit: Int) : StarCriterion { override val title get() = "Höchstens $limit Roboter-Aktionen" }
    data class Uses(val pattern: String, val label: String) : StarCriterion { override val title get() = label }
}

enum class MissionKind { LESSON, BOSS, TRAINING }

data class ArenaMission(
    val id: String,
    val kind: MissionKind,
    val title: String,
    val story: String,
    val lessonId: String,
    val moduleId: String?,
    val topicId: String,
    val difficulty: Difficulty,
    val worlds: List<ArenaWorld>,
    val starter: CodeSnippet,
    val solution: CodeSnippet,
    val hint: String,
    val reachGoal: Boolean = true,
    val collectAllCoins: Boolean = false,
    val requirements: List<CodeRule> = emptyList(),
    val bonus: List<StarCriterion> = emptyList(),
    val newCommands: List<String> = emptyList(),
    /** Der Weg zur Lösung in Worten: was zu tun ist – nicht der fertige Code. */
    val steps: List<String> = emptyList(),
    /** Java-Bausteine, die die Mission braucht (IDs aus `ArenaCatalog.concepts`). */
    val conceptIds: List<String> = emptyList(),
    /**
     * Roboter-Befehle, die Byte hier kann: alle, die bis zu dieser Mission eingeführt wurden.
     * Der Katalog setzt sie beim Laden (die Missionen stehen in Kursreihenfolge).
     */
    val commandNames: List<String> = RobotCommand.all.map { it.name },
) {
    val starterCode: String get() = starter.source

    /** Was zum Lösen nötig ist – als Liste für den Auftrag, abgeleitet aus Welten und Pflicht-Bausteinen. */
    val goals: List<ArenaGoal>
        get() {
            val goals = mutableListOf<ArenaGoal>()
            if (reachGoal) goals += ArenaGoal(ArenaGoal.Kind.REACH_GOAL, "Fahr Byte auf die Zielflagge.")
            if (collectAllCoins) goals += ArenaGoal(ArenaGoal.Kind.COLLECT_COINS, "Sammle alle Münzen ein.")
            val outputs = worlds.mapIndexedNotNull { index, world -> world.expectedOutput?.let { ArenaGoal.ExpectedOutput(index + 1, it) } }
            if (outputs.isNotEmpty()) {
                goals += if (outputs.map { it.text }.toSet().size == 1 && outputs.size == worlds.size) {
                    ArenaGoal(ArenaGoal.Kind.OUTPUT, "Gib am Ende genau das aus:", listOf(ArenaGoal.ExpectedOutput(null, outputs[0].text)))
                } else {
                    ArenaGoal(ArenaGoal.Kind.OUTPUT, "Gib am Ende genau das aus – in jeder Welt etwas anderes:", outputs)
                }
            }
            goals += requirements.map { ArenaGoal(ArenaGoal.Kind.RULE, it.message) }
            if (worlds.size == 2) {
                goals += ArenaGoal(ArenaGoal.Kind.ALL_WORLDS, "Derselbe Code muss in beiden Welten klappen. Nach dem Ausführen schaltest du über „Welt 1“ und „Welt 2“ um.")
            } else if (worlds.size > 2) {
                goals += ArenaGoal(ArenaGoal.Kind.ALL_WORLDS, "Derselbe Code muss in allen ${worlds.size} Welten klappen. Nach dem Ausführen schaltest du über „Welt 1“ bis „Welt ${worlds.size}“ um.")
            }
            return goals
        }

    companion object {
        /** Der Spielplatz: freie Welt ohne Ziel und ohne Sterne. */
        fun playground(world: ArenaWorld) = ArenaMission(
            id = "playground", kind = MissionKind.TRAINING, title = "Spielplatz",
            story = "Hier gibt es kein Ziel und keine Bewertung – probier einfach aus, was Byte alles kann.",
            lessonId = "", moduleId = null, topicId = "syntax", difficulty = Difficulty.clamped(1), worlds = listOf(world),
            starter = CodeSnippet.of("// Probier dich aus!\nrobot.move();\nrobot.turnLeft();"), solution = CodeSnippet.of(""),
            hint = "Klicke unten auf einen Befehl, um ihn einzufügen.", reachGoal = false,
        )
    }
}

/** Ein Punkt im Auftrag einer Mission („Fahr Byte auf die Zielflagge.“). */
data class ArenaGoal(val kind: Kind, val text: String, val outputs: List<ExpectedOutput> = emptyList()) {
    enum class Kind { REACH_GOAL, COLLECT_COINS, OUTPUT, RULE, ALL_WORLDS }

    /** Erwartete Ausgabe – `world` ist nur gesetzt, wenn sie je Welt verschieden ist. */
    data class ExpectedOutput(val world: Int?, val text: String)
}

/** Ein Java-Baustein, den eine Mission braucht – mit Mini-Beispiel für den Auftrag. */
data class ArenaConcept(
    val id: String,
    val title: String,
    val code: String,
    val text: String,
    /** Lektion, in der der Kurs den Baustein beibringt. `null`: Die Arena erklärt ihn selbst. */
    val lessonId: String?,
)

/** Ein Baustein im Auftrag einer bestimmten Mission. */
data class ArenaConceptUse(
    val concept: ArenaConcept,
    /** Weder der Kurs noch eine frühere Mission hat ihn erklärt – er wird hier zum ersten Mal gebraucht. */
    val isNew: Boolean,
)

/** Code-Vorlage für die Befehlsleiste – nur angeboten, wenn ihre Bausteine und Befehle schon bekannt sind. */
data class ArenaTemplate(val name: String, val code: String, val conceptIds: List<String>, val commandNames: List<String>) {
    companion object {
        val all = listOf(
            ArenaTemplate("if", "if (robot.onCoin()) {\n    robot.pickCoin();\n}", listOf("if"), listOf("onCoin", "pickCoin")),
            ArenaTemplate("while", "while (!robot.atGoal()) {\n    robot.move();\n}", listOf("while", "nicht"), listOf("atGoal", "move")),
            ArenaTemplate("for", "for (int i = 0; i < 3; i++) {\n    robot.move();\n}", listOf("for"), listOf("move")),
            ArenaTemplate("Methode", "static void schritt() {\n    robot.move();\n}", listOf("methode"), listOf("move")),
        )
    }
}

/** Alle Missionen der Arena (siehe `arena_missions.json`), in Kursreihenfolge. */
class ArenaCatalog(missions: List<ArenaMission>, val playground: ArenaWorld, val concepts: List<ArenaConcept> = emptyList()) {
    /** In Kursreihenfolge – davon hängt ab, welche Befehle und Bausteine eine Mission voraussetzen darf. */
    val missions: List<ArenaMission> = assigningCommands(missions)

    fun concept(id: String) = concepts.firstOrNull { it.id == id }

    /** Die Bausteine einer Mission für ihren Auftrag. */
    fun conceptUses(mission: ArenaMission): List<ArenaConceptUse> {
        val earlier = missionsBefore(mission)
        return mission.conceptIds.mapNotNull { id ->
            val concept = concept(id) ?: return@mapNotNull null
            val introducedBefore = earlier.any { id in it.conceptIds }
            ArenaConceptUse(concept, isNew = concept.lessonId == null && !introducedBefore)
        }
    }

    /**
     * Ist ein Baustein in dieser Mission bekannt? Ja, wenn der Kurs ihn bis zu ihrer Lektion
     * beigebracht hat, die Mission ihn selbst erklärt oder eine frühere Mission ihn eingeführt hat.
     */
    fun knows(conceptId: String, mission: ArenaMission, lessonOrder: List<String>): Boolean {
        if (conceptId in mission.conceptIds) return true
        if (missionsBefore(mission).any { conceptId in it.conceptIds }) return true
        val taughtIn = concept(conceptId)?.lessonId ?: return false
        val taught = lessonOrder.indexOf(taughtIn)
        val current = lessonOrder.indexOf(mission.lessonId)
        return taught >= 0 && current >= 0 && taught <= current
    }

    /** Vorlagen für die Befehlsleiste, die in dieser Mission schon verständlich sind. */
    fun templates(mission: ArenaMission, lessonOrder: List<String>): List<ArenaTemplate> = ArenaTemplate.all.filter { template ->
        template.conceptIds.all { knows(it, mission, lessonOrder) } && template.commandNames.all { it in mission.commandNames }
    }

    private fun missionsBefore(mission: ArenaMission): List<ArenaMission> {
        val index = missions.indexOfFirst { it.id == mission.id }
        return if (index < 0) emptyList() else missions.subList(0, index)
    }

    fun mission(id: String) = missions.firstOrNull { it.id == id }
    fun lessonMission(lessonId: String) = missions.firstOrNull { it.kind == MissionKind.LESSON && it.lessonId == lessonId }
    fun bossMission(moduleId: String) = missions.firstOrNull { it.kind == MissionKind.BOSS && it.moduleId == moduleId }

    companion object {
        /** Kein Katalog geladen – dann gibt es keine Arena (z. B. in Tests, die sie nicht brauchen). */
        val EMPTY = ArenaCatalog(emptyList(), ArenaWorld(listOf("R")))

        /** Jede Mission kann die Befehle, die sie selbst oder eine Mission vor ihr eingeführt hat. */
        private fun assigningCommands(missions: List<ArenaMission>): List<ArenaMission> {
            val known = mutableSetOf<String>()
            return missions.map { mission ->
                known += mission.newCommands
                mission.copy(commandNames = RobotCommand.all.map { it.name }.filter { it in known })
            }
        }

        fun loadBundled(): ArenaCatalog {
            val stream = ArenaCatalog::class.java.getResourceAsStream("/arena_missions.json") ?: error("Die Datei arena_missions.json fehlt.")
            return parse(stream.bufferedReader(Charsets.UTF_8).use { it.readText() })
        }

        fun parse(text: String): ArenaCatalog {
            val root = Json.parseToJsonElement(text).jsonObject
            val concepts = (root["concepts"] as? JsonArray)?.map { c ->
                val o = c.jsonObject
                ArenaConcept(o.str("id"), o.str("title"), o.str("code"), o.str("text"), o.optStr("lessonId"))
            } ?: emptyList()
            return ArenaCatalog(
                root.getValue("missions").jsonArray.map { parseMission(it.jsonObject) },
                parseWorld(root.getValue("playground").jsonObject),
                concepts,
            )
        }

        private fun JsonObject.str(key: String) = getValue(key).jsonPrimitive.content
        private fun JsonObject.optStr(key: String) = (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
        private fun JsonObject.bool(key: String, default: Boolean) = (this[key] as? JsonPrimitive)?.booleanOrNull ?: default

        private fun parseWorld(w: JsonObject) = ArenaWorld(w.getValue("map").jsonArray.map { it.jsonPrimitive.content }, Heading.fromRaw(w.optStr("facing")), w.optStr("expectedOutput"))

        private fun snippet(element: JsonElement?): CodeSnippet = if (element == null) CodeSnippet.of("") else CourseLoader.parseSnippet(element)

        private fun parseMission(m: JsonObject) = ArenaMission(
            id = m.str("id"),
            kind = MissionKind.valueOf(m.str("kind").uppercase()),
            title = m.str("title"),
            story = m.str("story"),
            lessonId = m.str("lessonId"),
            moduleId = m.optStr("moduleId"),
            topicId = m.str("topicId"),
            difficulty = Difficulty.clamped(m.getValue("difficulty").jsonPrimitive.intOrNull ?: 1),
            worlds = m.getValue("worlds").jsonArray.map { parseWorld(it.jsonObject) },
            starter = snippet(m["starterCode"]),
            solution = snippet(m["solution"]),
            hint = m.str("hint"),
            reachGoal = m.bool("reachGoal", true),
            collectAllCoins = m.bool("collectAllCoins", false),
            requirements = (m["requirements"] as? JsonArray)?.map { r ->
                val rule = r.jsonObject
                CodeRule(
                    rule = RuleKind.valueOf(rule.str("rule").uppercase()),
                    pattern = rule.str("pattern"),
                    message = rule.str("message"),
                    scope = rule.optStr("scope")?.let { RuleScope.valueOf(it.uppercase()) } ?: RuleScope.CODE,
                )
            } ?: emptyList(),
            bonus = m.getValue("bonus").jsonArray.map { b ->
                val o = b.jsonObject
                when (o.str("type")) {
                    "allCoins" -> StarCriterion.AllCoins
                    "maxLines" -> StarCriterion.MaxLines(o.getValue("value").jsonPrimitive.intOrNull ?: 0)
                    "maxActions" -> StarCriterion.MaxActions(o.getValue("value").jsonPrimitive.intOrNull ?: 0)
                    "uses" -> StarCriterion.Uses(o.str("pattern"), o.str("label"))
                    else -> error("Unbekanntes Sternziel ${o.str("type")}")
                }
            },
            newCommands = m.strings("newCommands"),
            steps = m.strings("steps"),
            conceptIds = m.strings("concepts"),
        )

        private fun JsonObject.strings(key: String) = (this[key] as? JsonArray)?.map { it.jsonPrimitive.content } ?: emptyList()
    }
}

// ---------------------------------------------------------------- Simulation

sealed interface ArenaAction {
    val isCrash: Boolean get() = this is Crash

    data object Start : ArenaAction
    data object Move : ArenaAction
    data object TurnLeft : ArenaAction
    data object TurnRight : ArenaAction
    data object PickCoin : ArenaAction
    data class Look(val question: String, val answer: Boolean) : ArenaAction
    /**
     * Gegen eine Wand gefahren ([wall] ist das Wandfeld) oder ins Leere gegriffen ([wall] ist null) –
     * das Programm bricht ab.
     */
    data class Crash(val wall: GridPoint?) : ArenaAction
}

/** Standbild der Welt nach jeder Roboter-Aktion – für die Wiedergabe. */
data class ArenaFrame(
    val robot: GridPoint,
    val heading: Heading,
    val coins: Set<GridPoint>,
    val collected: Int,
    val action: ArenaAction,
    val line: Int?,
    val output: String,
    val variables: List<JavaVariable>,
)

data class RobotCommand(
    val name: String,
    val returnType: String,
    val summary: String,
    /** Was der Befehl genau tut – für die Befehlsliste im Auftrag. */
    val detail: String,
) {
    val call: String get() = "robot.$name()"

    companion object {
        val all = listOf(
            RobotCommand("move", "void", "Ein Feld vorwärts fahren",
                "Fährt ein Feld in Blickrichtung. Steht dort eine Wand, gibt es einen Unfall."),
            RobotCommand("turnLeft", "void", "Um 90° nach links drehen",
                "Dreht Byte auf der Stelle um 90° nach links – er fährt dabei nicht."),
            RobotCommand("turnRight", "void", "Um 90° nach rechts drehen",
                "Dreht Byte auf der Stelle um 90° nach rechts – er fährt dabei nicht."),
            RobotCommand("pickCoin", "void", "Münze auf dem Feld aufheben",
                "Hebt die Münze auf, auf der Byte gerade steht. Liegt dort keine, gibt es einen Fehler."),
            RobotCommand("frontIsClear", "boolean", "Ist vorne frei?",
                "Antwortet true, wenn das Feld vor Byte frei ist – sonst false."),
            RobotCommand("leftIsClear", "boolean", "Ist links frei?",
                "Antwortet true, wenn das Feld links neben Byte frei ist – sonst false."),
            RobotCommand("rightIsClear", "boolean", "Ist rechts frei?",
                "Antwortet true, wenn das Feld rechts neben Byte frei ist – sonst false."),
            RobotCommand("onCoin", "boolean", "Liegt hier eine Münze?",
                "Antwortet true, wenn auf dem Feld von Byte eine Münze liegt – sonst false."),
            RobotCommand("atGoal", "boolean", "Steht er auf dem Ziel?",
                "Antwortet true, wenn Byte auf der Zielflagge steht – sonst false."),
            RobotCommand("coins", "int", "Wie viele Münzen hat er?",
                "Antwortet mit der Zahl der Münzen, die Byte schon aufgehoben hat (eine ganze Zahl)."),
        )
    }
}

/** Simuliert eine Welt und stellt dem Interpreter das Objekt `robot` bereit. */
class ArenaSimulation(
    val world: ArenaWorld,
    /** Befehle, die Byte in dieser Mission kann – für die Liste bei einem unbekannten Befehl. */
    private val commandNames: List<String> = RobotCommand.all.map { it.name },
) : JavaHost {
    companion object {
        const val MAX_ACTIONS = 400
        const val MAX_FRAMES = 1_500
        /** So oft darf Byte hintereinander gefragt werden, ohne sich zu bewegen. */
        const val MAX_QUESTIONS_IN_A_ROW = 250
        /**
         * So viele Fragen hintereinander zeigt die Wiedergabe als Sprechblase. Mehr braucht keine Mission
         * zwischen zwei Aktionen – eine Schleife ohne robot.move(); hätte sonst 250 gleiche Bilder.
         */
        const val SHOWN_QUESTIONS_IN_A_ROW = 6
    }

    override val objectNames = setOf("robot")
    var robot = world.start ?: GridPoint(0, 0); private set
    var heading = world.facing; private set
    val coins = world.coins.toMutableSet()
    var collected = 0; private set
    var actions = 0; private set
    val frames = mutableListOf<ArenaFrame>()
    private var questionsInARow = 0

    override val wantsSnapshot: Boolean get() = frames.size < MAX_FRAMES

    init {
        record(ArenaAction.Start, null)
    }

    private fun record(action: ArenaAction, context: CallContext?) {
        if (frames.size >= MAX_FRAMES) return
        frames += ArenaFrame(robot, heading, coins.toSet(), collected, action, context?.line, context?.output ?: "", context?.variables ?: emptyList())
    }

    override fun call(objectName: String, method: String, args: List<JValue>, context: CallContext): JValue {
        val command = RobotCommand.all.firstOrNull { it.name == method }
        if (command == null) {
            val similar = RobotCommand.all.firstOrNull { it.name.lowercase() == method.lowercase() }
            val tip = similar?.let { " Meintest du robot.${it.name}()? Achte auf Groß- und Kleinschreibung." }
                ?: (" Er kann hier: " + commandNames.joinToString(", ") { "$it()" } + ".")
            throw JavaProblem.syntax("Der Roboter kennt den Befehl $method() nicht.$tip", context.line)
        }
        if (args.isNotEmpty()) throw JavaProblem.syntax("robot.$method() braucht nichts in den Klammern.", context.line)
        if (command.returnType == "void") {
            questionsInARow = 0
            actions++
            if (actions > MAX_ACTIONS) {
                throw JavaProblem(JavaProblem.Kind.STEP_LIMIT, "Der Roboter hat schon $MAX_ACTIONS Aktionen gemacht und ist immer noch unterwegs – läuft er im Kreis?", context.line)
            }
        }
        when (method) {
            "move" -> {
                val next = robot.moved(heading)
                if (world.isWall(next)) {
                    record(ArenaAction.Crash(wall = next), context)
                    throw JavaProblem.runtime("Bumm! Der Roboter ist gegen eine Wand gefahren. Prüfe vorher mit robot.frontIsClear(), ob der Weg frei ist.", context.line)
                }
                robot = next
                record(ArenaAction.Move, context)
            }
            "turnLeft" -> { heading = heading.left; record(ArenaAction.TurnLeft, context) }
            "turnRight" -> { heading = heading.right; record(ArenaAction.TurnRight, context) }
            "pickCoin" -> {
                if (robot !in coins) {
                    record(ArenaAction.Crash(wall = null), context)
                    throw JavaProblem.runtime("Hier liegt keine Münze – der Roboter greift ins Leere. Prüfe vorher mit robot.onCoin().", context.line)
                }
                coins -= robot
                collected++
                record(ArenaAction.PickCoin, context)
            }
            "coins" -> return JValue.IntV(collected)
            else -> {
                questionsInARow++
                if (questionsInARow > MAX_QUESTIONS_IN_A_ROW) {
                    throw JavaProblem(JavaProblem.Kind.STEP_LIMIT, "Byte wird immer wieder gefragt, bewegt sich aber nicht – vermutlich eine Schleife ohne robot.move(); im Körper.", context.line)
                }
                val answer = when (method) {
                    "frontIsClear" -> !world.isWall(robot.moved(heading))
                    "leftIsClear" -> !world.isWall(robot.moved(heading.left))
                    "rightIsClear" -> !world.isWall(robot.moved(heading.right))
                    "onCoin" -> robot in coins
                    else -> robot == world.goal
                }
                if (questionsInARow <= SHOWN_QUESTIONS_IN_A_ROW) record(ArenaAction.Look(method, answer), context)
                return JValue.BoolV(answer)
            }
        }
        return JValue.Void
    }
}

data class ArenaWorldRun(
    val world: ArenaWorld,
    val frames: List<ArenaFrame>,
    val output: String,
    val problem: JavaProblem?,
    val reachedGoal: Boolean,
    val coinsLeft: Int,
    val actions: Int,
    /** Stimmt die Ausgabe? `null`, wenn die Welt keine bestimmte Ausgabe verlangt. */
    val outputMatches: Boolean?,
    /** Warum die Welt nicht geschafft ist – leer bei Erfolg. */
    val failures: List<String>,
) {
    val succeeded: Boolean get() = failures.isEmpty()
}

data class StarCriterionResult(
    val criterion: StarCriterion,
    val met: Boolean,
    /** Was der Code tatsächlich geschafft hat („du: 9“) – damit klar ist, was zum Stern fehlt. Nur bei gelöster Mission. */
    val progress: String? = null,
)

data class ArenaResult(
    val runs: List<ArenaWorldRun>,
    val missingRequirements: List<String>,
    val solved: Boolean,
    val criteria: List<StarCriterionResult>,
    val codeLines: Int,
    val warnings: List<JavaWarning>,
) {
    /** 1 Stern fürs Lösen, je ein weiterer pro erfülltem Zusatzziel. */
    val stars: Int get() = if (solved) 1 + criteria.count { it.met } else 0
    val firstFailingWorld: Int? get() = runs.indexOfFirst { !it.succeeded }.takeIf { it >= 0 }
}

/** Führt Code in allen Welten einer Mission aus und bewertet das Ergebnis. */
object ArenaEngine {
    const val STEP_LIMIT = 60_000

    fun run(code: String, mission: ArenaMission): ArenaResult {
        val source = JavaSource.normalizingTypography(code)
        val runs = mutableListOf<ArenaWorldRun>()
        val warnings = mutableListOf<JavaWarning>()
        for (world in mission.worlds) {
            val simulation = ArenaSimulation(world, mission.commandNames)
            val result = JavaRunner.run(source, STEP_LIMIT, simulation)
            result.warnings.forEach { if (it !in warnings) warnings += it }
            runs += evaluate(world, simulation, result, mission)
            // Ein Syntaxfehler ist in jeder Welt derselbe – ein Lauf reicht.
            if (result.problem?.kind == JavaProblem.Kind.SYNTAX || result.problem?.kind == JavaProblem.Kind.UNSUPPORTED) break
        }
        val masked = JavaSource.maskingLiterals(source)
        val missing = mission.requirements.filter { rule ->
            val target = if (rule.scope == RuleScope.RAW) JavaSource.strippingComments(source) else masked
            val matches = rule.allPatterns.any { AnswerEvaluator.matches(it, target) }
            if (rule.rule == RuleKind.FORBID) matches else !matches
        }.map { it.message }
        val solved = runs.size == mission.worlds.size && runs.all { it.succeeded } && missing.isEmpty()
        val lines = codeLineCount(source)
        val criteria = mission.bonus.map { criterion ->
            val met = when (criterion) {
                StarCriterion.AllCoins -> runs.size == mission.worlds.size && runs.all { it.coinsLeft == 0 }
                is StarCriterion.MaxLines -> lines <= criterion.limit
                is StarCriterion.MaxActions -> runs.all { it.actions <= criterion.limit }
                is StarCriterion.Uses -> AnswerEvaluator.matches(criterion.pattern, masked)
            }
            StarCriterionResult(criterion, solved && met, if (solved) progress(criterion, met, runs, lines) else null)
        }
        return ArenaResult(runs, missing, solved, criteria, lines, warnings)
    }

    private fun progress(criterion: StarCriterion, met: Boolean, runs: List<ArenaWorldRun>, lines: Int): String? = when (criterion) {
        StarCriterion.AllCoins -> {
            val left = runs.sumOf { it.coinsLeft }
            if (met) null else if (left == 1) "1 Münze liegt noch" else "$left Münzen liegen noch"
        }
        is StarCriterion.MaxLines -> if (lines == 1) "du: 1 Zeile" else "du: $lines Zeilen"
        // Bei mehreren Welten zählt die Welt mit den meisten Aktionen.
        is StarCriterion.MaxActions -> "du: ${runs.maxOfOrNull { it.actions } ?: 0}"
        is StarCriterion.Uses -> null
    }

    private fun evaluate(world: ArenaWorld, simulation: ArenaSimulation, result: JavaRunResult, mission: ArenaMission): ArenaWorldRun {
        val failures = mutableListOf<String>()
        result.problem?.let { failures += it.description }
        val reachedGoal = world.goal == null || simulation.robot == world.goal
        if (result.problem == null) {
            if (mission.reachGoal && !reachedGoal) failures += "Der Roboter steht am Ende nicht auf dem Zielfeld."
            if (mission.collectAllCoins && simulation.coins.isNotEmpty()) {
                val count = simulation.coins.size
                failures += if (count == 1) "Es liegt noch 1 Münze herum." else "Es liegen noch $count Münzen herum."
            }
        }
        val expected = world.expectedOutput
        val outputMatches = expected?.let { AnswerEvaluator.outputLines(result.output) == AnswerEvaluator.outputLines(it) }
        if (expected != null && result.problem == null && outputMatches == false) {
            failures += AnswerEvaluator.outputDifference(result.output, expected).replace("Ausgeführt – ", "")
        }
        return ArenaWorldRun(
            world, simulation.frames.toList(), result.output, result.problem, reachedGoal,
            simulation.coins.size, simulation.actions, outputMatches, failures,
        )
    }

    /** Zählt „echte“ Codezeilen: ohne Leerzeilen, Kommentare und Zeilen, die nur Klammern enthalten. */
    fun codeLineCount(code: String): Int = JavaSource.strippingComments(code).split("\n").map { it.trim() }
        .count { line -> line.isNotEmpty() && !line.all { it in "{}();" } }
}
