package app.javaquest.core

import kotlin.math.roundToInt

/** Antwort der lernenden Person in einer der vier Eingabeformen. */
sealed interface TaskAnswer {
    data class Choice(val index: Int) : TaskAnswer
    data class Blanks(val values: List<String>) : TaskAnswer
    data class Text(val text: String) : TaskAnswer
}

enum class FindingKind { PASSED, FAILED, HINT }

/** Einzelne Rückmeldung der Auswertung (erfüllt, verfehlt oder Hinweis). */
data class Finding(val kind: FindingKind, val message: String, val line: Int? = null) {
    companion object {
        fun passed(message: String, line: Int? = null) = Finding(FindingKind.PASSED, message, line)
        fun failed(message: String, line: Int? = null) = Finding(FindingKind.FAILED, message, line)
        fun hint(message: String, line: Int? = null) = Finding(FindingKind.HINT, message, line)
    }
}

class EvaluationResult(val isCorrect: Boolean, score: Double, val findings: List<Finding>) {
    /** Teilpunktzahl 0…1 – auch bei falschen Antworten aussagekräftig. */
    val score: Double = score.coerceIn(0.0, 1.0)
    val percent: Int get() = (score * 100).roundToInt()

    override fun equals(other: Any?) =
        other is EvaluationResult && other.isCorrect == isCorrect && other.score == score && other.findings == findings

    override fun hashCode() = listOf(isCorrect, score, findings).hashCode()
}

/** Leichtgewichtige Java-Quelltextanalyse ohne Compiler. */
object JavaSource {
    /** Ersetzt typografische Zeichen („smarte“ Anführungszeichen, Gedankenstriche) durch ASCII. */
    fun normalizingTypography(text: String): String = buildString(text.length) {
        for (c in text) {
            when (c) {
                '“', '”', '„', '‟', '«', '»' -> append('"')
                '‘', '’', '‚', '‛' -> append('\'')
                '—' -> append("--")
                '–' -> append('-')
                '…' -> append("...")
                ' ' -> append(' ')
                else -> append(c)
            }
        }
    }

    /** Entfernt Kommentare; String- und Char-Literale bleiben unverändert. */
    fun strippingComments(source: String): String = scan(source).first

    /** Entfernt Kommentare und leert Literale ("abc" → ""). */
    fun maskingLiterals(source: String): String = scan(source).second

    private enum class State { CODE, LINE_COMMENT, BLOCK_COMMENT, STRING, CHARACTER, TEXT_BLOCK }

    private fun scan(source: String): Pair<String, String> {
        val chars = source.toCharArray()
        val plain = StringBuilder()
        val masked = StringBuilder()
        var state = State.CODE
        var i = 0
        fun peek(offset: Int): Char? = chars.getOrNull(i + offset)

        while (i < chars.size) {
            val c = chars[i]
            when (state) {
                State.CODE -> {
                    if (c == '/' && peek(1) == '/') { state = State.LINE_COMMENT; i += 2; continue }
                    if (c == '/' && peek(1) == '*') {
                        state = State.BLOCK_COMMENT; plain.append(' '); masked.append(' '); i += 2; continue
                    }
                    if (c == '"' && peek(1) == '"' && peek(2) == '"') {
                        state = State.TEXT_BLOCK; plain.append("\"\"\""); masked.append("\"\"\""); i += 3; continue
                    }
                    if (c == '"') state = State.STRING
                    if (c == '\'') state = State.CHARACTER
                    plain.append(c); masked.append(c)
                }
                State.LINE_COMMENT -> if (c == '\n') { state = State.CODE; plain.append(c); masked.append(c) }
                State.BLOCK_COMMENT -> {
                    if (c == '*' && peek(1) == '/') { state = State.CODE; i += 2; continue }
                    if (c == '\n') { plain.append(c); masked.append(c) }
                }
                State.STRING, State.CHARACTER -> {
                    val delimiter = if (state == State.STRING) '"' else '\''
                    val next = peek(1)
                    if (c == '\\' && next != null) { plain.append(c).append(next); i += 2; continue }
                    if (c == delimiter || c == '\n') {
                        // Zeilenende schließt ein nicht beendetes Literal, damit der Rest analysierbar bleibt.
                        state = State.CODE
                        plain.append(c)
                        masked.append(if (c == '\n') '\n' else delimiter)
                    } else {
                        plain.append(c)
                    }
                }
                State.TEXT_BLOCK -> {
                    if (c == '"' && peek(1) == '"' && peek(2) == '"') {
                        state = State.CODE; plain.append("\"\"\""); masked.append("\"\"\""); i += 3; continue
                    }
                    plain.append(c)
                    if (c == '\n') masked.append(c)
                }
            }
            i += 1
        }
        return plain.toString() to masked.toString()
    }

    /** Prüft, ob (), [] und {} ausgeglichen sind. Erwartet maskierten Code. */
    fun delimiterIssues(masked: String): List<Finding> {
        val closing = mapOf(')' to '(', ']' to '[', '}' to '{')
        val closingFor = mapOf('(' to ')', '[' to ']', '{' to '}')
        val stack = ArrayDeque<Pair<Char, Int>>()
        var line = 1
        for (c in masked) {
            when {
                c == '\n' -> line += 1
                c in closingFor -> stack.addLast(c to line)
                c in closing -> {
                    val last = stack.lastOrNull()
                        ?: return listOf(Finding.failed("Zeile $line: „$c“ wird geschlossen, aber nie geöffnet.", line))
                    if (last.first != closing[c]) {
                        return listOf(Finding.failed(
                            "Zeile $line: „$c“ passt nicht – erwartet wurde „${closingFor[last.first]}“ zu „${last.first}“ aus Zeile ${last.second}.",
                            line,
                        ))
                    }
                    stack.removeLast()
                }
            }
        }
        val open = stack.lastOrNull() ?: return emptyList()
        return listOf(Finding.failed("„${open.first}“ aus Zeile ${open.second} wird nicht mit „${closingFor[open.first]}“ geschlossen.", open.second))
    }

    private val controlKeywords = setOf("if", "else", "for", "while", "do", "switch", "try", "catch", "finally", "case", "default", "synchronized")
    private val declarationPattern = Regex("""\b(class|interface|enum|record)\b""")

    /** Zeilen (1-basiert), in denen vermutlich ein Semikolon fehlt – bewusst vorsichtig. */
    fun linesMissingSemicolon(masked: String): List<Int> {
        val lines = masked.split("\n").map { it.trim(' ', '\t') }
        val result = mutableListOf<Int>()
        for ((index, line) in lines.withIndex()) {
            val last = line.lastOrNull() ?: continue
            if (last in ";{},:(") continue
            if (line.startsWith("@") || line.endsWith("\"\"\"")) continue
            if (line.endsWith("->") || line.endsWith("&&") || line.endsWith("||")) continue
            val endsWithIncrement = line.endsWith("++") || line.endsWith("--")
            if (last in "+-*/%=&|?<>!.^~" && !endsWithIncrement) continue

            val head = line.dropWhile { it == '}' || it == ' ' }
            val firstWord = head.takeWhile { it.isLetter() }
            if (firstWord in controlKeywords) continue
            if (declarationPattern.containsMatchIn(line)) continue

            val next = lines.drop(index + 1).firstOrNull { it.isNotEmpty() }
            if (next != null && next.first() in "{.)+-*/&|?:") continue

            if (last.isLetter() || last.isDigit() || last in ")]\"'_" || endsWithIncrement) result.add(index + 1)
        }
        return result
    }
}

/**
 * Bewertet Antworten vollständig lokal – ohne Netz, ohne Sprachmodell, ohne Java-Compiler.
 * Gleiche Regeln wie die iOS-App.
 */
object AnswerEvaluator {
    fun evaluate(answer: TaskAnswer, task: LearningTask): EvaluationResult {
        val kind = task.kind
        return when {
            kind is TaskKind.SingleChoice && answer is TaskAnswer.Choice ->
                if (answer.index == kind.correctIndex) EvaluationResult(true, 1.0, listOf(Finding.passed("Richtig gewählt.")))
                else EvaluationResult(false, 0.0, listOf(Finding.failed("Diese Antwort stimmt leider nicht.")))
            kind is TaskKind.FillBlank && answer is TaskAnswer.Blanks ->
                evaluateBlanks(answer.values.map(JavaSource::normalizingTypography), kind)
            kind is TaskKind.PredictOutput && answer is TaskAnswer.Text ->
                evaluateOutput(JavaSource.normalizingTypography(answer.text), kind)
            kind is TaskKind.Code && answer is TaskAnswer.Text ->
                evaluateCode(JavaSource.normalizingTypography(answer.text), kind)
            else -> EvaluationResult(false, 0.0, listOf(Finding.failed("Diese Antwortform passt nicht zur Aufgabe.")))
        }
    }

    /** Musterlösung als Antwort – für „Lösung zeigen“ und die Inhaltstests. */
    fun referenceAnswer(task: LearningTask): TaskAnswer = when (val kind = task.kind) {
        is TaskKind.SingleChoice -> TaskAnswer.Choice(kind.correctIndex)
        is TaskKind.FillBlank -> TaskAnswer.Blanks(kind.blanks.map { it.accepted.firstOrNull() ?: "" })
        is TaskKind.PredictOutput -> TaskAnswer.Text(kind.expectedOutput)
        is TaskKind.Code -> TaskAnswer.Text(kind.solution.source)
    }

    private fun evaluateBlanks(values: List<String>, spec: TaskKind.FillBlank): EvaluationResult {
        val findings = mutableListOf<Finding>()
        var correct = 0
        spec.blanks.forEachIndexed { index, blank ->
            val value = values.getOrElse(index) { "" }
            when {
                blankAccepts(blank, value) -> { correct += 1; findings += Finding.passed("Lücke ${index + 1} ist richtig.") }
                value.isBlank() -> findings += Finding.failed("Lücke ${index + 1} ist noch leer.")
                else -> findings += Finding.failed(
                    "Lücke ${index + 1}: " + warumBlankFalsch(value, blank, spec.blanks, index),
                )
            }
        }
        val total = maxOf(spec.blanks.size, 1)
        return EvaluationResult(correct == spec.blanks.size, correct.toDouble() / total, findings)
    }

    /** Warum diese Eingabe die Lücke nicht füllt – konkret statt „stimmt noch nicht“. */
    fun warumBlankFalsch(value: String, blank: Blank, alle: List<Blank>, index: Int): String {
        val eingabe = value.trim()
        val richtig = blank.accepted.firstOrNull() ?: ""
        if (blank.accepted.any { it.lowercase() == eingabe.lowercase() }) {
            return "fast – achte auf Groß- und Kleinschreibung."
        }
        alle.forEachIndexed { anderer, b ->
            if (anderer != index && b.accepted.any { it.lowercase() == eingabe.lowercase() }) {
                return "das gehört in Lücke ${anderer + 1}."
            }
        }
        val ohneKlammern = eingabe.replace("()", "")
        if (blank.accepted.any { it.lowercase() == ohneKlammern.lowercase() }) {
            return "die runden Klammern stehen hier schon im Text."
        }
        if (blank.accepted.any { it.lowercase() == (eingabe + "()").lowercase() }) {
            return "fast – es fehlen die runden Klammern."
        }
        if (richtig.isNotEmpty() && richtig.lowercase().startsWith(eingabe.lowercase())) {
            return "der Anfang stimmt, es fehlt noch etwas."
        }
        if (eingabe.isNotEmpty() && richtig.isNotEmpty() && eingabe.lowercase().startsWith(richtig.lowercase())) {
            return "da steht etwas zu viel."
        }
        return "stimmt noch nicht."
    }

    /** Was an dieser einen Zeile abweicht – benannt, nicht nur festgestellt. */
    fun warumZeileFalsch(gegeben: String, erwartet: String): String {
        if (gegeben.lowercase() == erwartet.lowercase()) return "richtig bis auf die Groß- und Kleinschreibung."
        if (gegeben.filterNot { it.isWhitespace() } == erwartet.filterNot { it.isWhitespace() }) {
            return "richtig bis auf die Leerzeichen."
        }
        if (erwartet.endsWith(".0") && erwartet.dropLast(2) == gegeben) {
            return "die Nachkommastelle fehlt – sobald eine Kommazahl beteiligt ist, hat auch das Ergebnis eine."
        }
        if (gegeben.endsWith(".0") && gegeben.dropLast(2) == erwartet) {
            return "hier wird mit ganzen Zahlen gerechnet, da kommt keine Nachkommastelle heraus."
        }
        if (erwartet.startsWith("[") && erwartet.endsWith("]") && erwartet.drop(1).dropLast(1) == gegeben) {
            return "eine Liste gibt sich mit eckigen Klammern aus."
        }
        if (erwartet.length == gegeben.length) return "gleich lang, aber ein anderer Inhalt."
        return if (gegeben.length < erwartet.length) "da fehlt noch etwas." else "da steht etwas zu viel."
    }

    /** Ein Befund über die ganze Ausgabe – für Fehler, die man nur im Zusammenhang sieht. */
    fun warumAusgabeFalsch(gegeben: List<String>, erwartet: List<String>): String? {
        val gJoin = gegeben.joinToString("")
        val eJoin = erwartet.joinToString("")
        // Nur melden, wenn sich der Text wirklich in der Schreibweise unterscheidet – sonst
        // verdeckt dieser Fall den print/println-Fehler, bei dem der Text identisch ist.
        if (gJoin.lowercase() == eJoin.lowercase() && gJoin != eJoin) {
            return "Fast! Achte auf Groß- und Kleinschreibung."
        }
        if (gegeben.size == 1 && erwartet.size > 1 && gegeben[0] == eJoin) {
            return "Der Inhalt stimmt, aber alles steht in einer Zeile. println beginnt danach eine neue, print nicht."
        }
        if (erwartet.size == 1 && gegeben.size > 1 && erwartet[0] == gJoin) {
            return "Der Inhalt stimmt, aber er ist auf mehrere Zeilen verteilt. Nur println bricht um."
        }
        if (gJoin.filterNot { it.isWhitespace() } == eJoin.filterNot { it.isWhitespace() }) {
            return "Fast! Achte auf Leerzeichen und Zeilenumbrüche – println beginnt eine neue Zeile, print nicht."
        }
        if (gegeben.size > erwartet.size) {
            return "Es erscheinen ${gegeben.size - erwartet.size} Zeile(n) zu viel. Zähl nach, wie oft die Ausgabe wirklich erreicht wird."
        }
        if (gegeben.size < erwartet.size) {
            return "Es fehlen ${erwartet.size - gegeben.size} Zeile(n). Zähl nach, wie oft die Ausgabe erreicht wird."
        }
        return null
    }

    fun blankAccepts(blank: Blank, value: String): Boolean {
        fun normalize(text: String): String {
            val compact = text.filterNot { it.isWhitespace() }
            return if (blank.caseSensitive) compact else compact.lowercase()
        }
        val first = normalize(value)
        // Ein versehentlich mitgetipptes Semikolon am Ende wird toleriert.
        val candidates = if (first.endsWith(";")) listOf(first, first.dropLast(1)) else listOf(first)
        val accepted = blank.accepted.map(::normalize).toSet()
        return candidates.any { it in accepted }
    }

    private fun evaluateOutput(text: String, spec: TaskKind.PredictOutput): EvaluationResult {
        val given = outputLines(text)
        val expectations = (listOf(spec.expectedOutput) + spec.alsoAccepted).map(::outputLines)
        if (given in expectations) return EvaluationResult(true, 1.0, listOf(Finding.passed("Die Ausgabe stimmt exakt.")))

        val expected = expectations.first()
        if (given.isEmpty()) return EvaluationResult(false, 0.0, listOf(Finding.failed("Noch keine Ausgabe eingegeben.")))

        val findings = mutableListOf<Finding>()
        var matching = 0
        for (index in 0 until maxOf(expected.size, given.size)) {
            val expectedLine = expected.getOrNull(index)
            val givenLine = given.getOrNull(index)
            when {
                expectedLine != null && expectedLine == givenLine -> matching += 1
                expectedLine == null -> findings += Finding.failed("Zeile ${index + 1} ist zu viel.", index + 1)
                givenLine == null -> findings += Finding.failed("Zeile ${index + 1} fehlt noch.", index + 1)
                else -> findings += Finding.failed(
                    "Zeile ${index + 1}: " + warumZeileFalsch(givenLine!!, expectedLine!!), index + 1,
                )
            }
        }
        if (matching > 0) findings.add(0, Finding.passed("$matching von ${expected.size} Zeilen stimmen."))
        warumAusgabeFalsch(given, expected)?.let { findings += Finding.hint(it) }
        return EvaluationResult(false, matching.toDouble() / maxOf(expected.size, given.size), findings)
    }

    /** Normalisiert Konsolenausgabe: Leerzeichen am Zeilenende und Leerzeilen am Rand fallen weg. */
    fun outputLines(text: String): List<String> {
        val lines = text.replace("\r\n", "\n").split("\n").map { it.trimEnd(' ', '\t') }.toMutableList()
        while (lines.firstOrNull()?.isEmpty() == true) lines.removeAt(0)
        while (lines.lastOrNull()?.isEmpty() == true) lines.removeAt(lines.lastIndex)
        return lines
    }

    private fun evaluateCode(source: String, spec: TaskKind.Code): EvaluationResult {
        val withoutComments = JavaSource.strippingComments(source)
        val masked = JavaSource.maskingLiterals(source)
        if (masked.isBlank()) return EvaluationResult(false, 0.0, listOf(Finding.failed("Hier steht noch kein Code.")))

        val structureFindings = mutableListOf<Finding>()
        if (StructureCheck.BALANCED_DELIMITERS in spec.structure) structureFindings += JavaSource.delimiterIssues(masked)
        if (StructureCheck.SEMICOLONS in spec.structure) {
            structureFindings += JavaSource.linesMissingSemicolon(masked).take(3).map { line ->
                Finding.failed("Zeile $line: Am Ende fehlt vermutlich ein Semikolon (;).", line)
            }
        }

        val ruleFindings = mutableListOf<Finding>()
        var earned = if (structureFindings.isEmpty()) 1.0 else 0.0
        var total = 1.0
        var allRequiredMet = true
        var violations = 0
        for (rule in spec.rules) {
            val target = if (rule.scope == RuleScope.RAW) withoutComments else masked
            // Bei ANY_OF genügt einer der gleichwertigen Wege.
            val matches = rule.allPatterns.any { matches(it, target) }
            when (rule.rule) {
                RuleKind.REQUIRE, RuleKind.ANY_OF -> {
                    total += rule.weight
                    if (matches) { earned += rule.weight; ruleFindings += Finding.passed(rule.message) }
                    else { allRequiredMet = false; ruleFindings += Finding.failed(rule.message) }
                }
                RuleKind.FORBID -> if (matches) { violations += 1; ruleFindings += Finding.failed(rule.message) }
            }
        }
        var score = earned / total
        if (violations > 0) score *= 0.5
        val isCorrect = structureFindings.isEmpty() && allRequiredMet && violations == 0
        return EvaluationResult(isCorrect, score, structureFindings + ruleFindings)
    }

    fun matches(pattern: String, text: String): Boolean =
        runCatching { Regex(pattern).containsMatchIn(text) }.getOrDefault(false)
}

/** Minimaler Tokenizer für die Syntaxhervorhebung. */
object JavaHighlighter {
    enum class Kind { PLAIN, KEYWORD, TYPE, STRING, NUMBER, COMMENT, ANNOTATION }
    data class Token(val text: String, val kind: Kind)

    val keywords = setOf(
        "abstract", "boolean", "break", "byte", "case", "catch", "char", "class", "continue", "default", "do",
        "double", "else", "enum", "extends", "final", "finally", "float", "for", "if", "implements", "import",
        "instanceof", "int", "interface", "long", "new", "null", "package", "private", "protected", "public",
        "record", "return", "short", "static", "super", "switch", "this", "throw", "throws", "true", "false",
        "try", "var", "void", "while", "yield",
    )

    fun tokenize(code: String): List<Token> {
        val tokens = mutableListOf<Token>()
        var i = 0
        fun append(start: Int, end: Int, kind: Kind) {
            val text = code.substring(start, end)
            val last = tokens.lastOrNull()
            if (kind == Kind.PLAIN && last?.kind == Kind.PLAIN) tokens[tokens.lastIndex] = Token(last.text + text, Kind.PLAIN)
            else tokens += Token(text, kind)
        }
        while (i < code.length) {
            val c = code[i]
            val start = i
            when {
                c == '/' && code.getOrNull(i + 1) == '/' -> {
                    while (i < code.length && code[i] != '\n') i++
                    append(start, i, Kind.COMMENT)
                }
                c == '/' && code.getOrNull(i + 1) == '*' -> {
                    i += 2
                    while (i < code.length && !(code[i] == '*' && code.getOrNull(i + 1) == '/')) i++
                    i = minOf(i + 2, code.length)
                    append(start, i, Kind.COMMENT)
                }
                c == '"' || c == '\'' -> {
                    i++
                    while (i < code.length && code[i] != c && code[i] != '\n') i += if (code[i] == '\\') 2 else 1
                    i = minOf(i + 1, code.length)
                    append(start, i, Kind.STRING)
                }
                c == '@' && code.getOrNull(i + 1)?.isLetter() == true -> {
                    i++
                    while (i < code.length && code[i].isLetterOrDigit()) i++
                    append(start, i, Kind.ANNOTATION)
                }
                c.isDigit() -> {
                    while (i < code.length && (code[i].isLetterOrDigit() || code[i] == '.' || code[i] == '_')) i++
                    append(start, i, Kind.NUMBER)
                }
                c.isLetter() || c == '_' -> {
                    while (i < code.length && (code[i].isLetterOrDigit() || code[i] == '_')) i++
                    val word = code.substring(start, i)
                    append(start, i, when {
                        word in keywords -> Kind.KEYWORD
                        word.first().isUpperCase() -> Kind.TYPE
                        else -> Kind.PLAIN
                    })
                }
                else -> { i++; append(start, i, Kind.PLAIN) }
            }
        }
        return tokens
    }
}
