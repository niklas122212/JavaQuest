package app.javaquest.core

import app.javaquest.core.interpreter.JavaParser
import app.javaquest.core.interpreter.JavaProblem
import app.javaquest.core.interpreter.JavaRunner
import app.javaquest.core.interpreter.JavaTestOutcome
import app.javaquest.core.interpreter.JavaTestValue
import app.javaquest.core.interpreter.test
import kotlin.math.abs

/** Ergebnis eines einzelnen Tests. */
data class QuestTestResult(
    val test: QuestTest,
    val passed: Boolean,
    /** Was der Code geliefert hat – für „erwartet … · bekommen …“. */
    val actual: String?,
    /** Warum der Test scheitert, in Alltagssprache. */
    val message: String?,
    /** Zeile im Code des Spielers, an der es hakt (bei Fehlern und Abstürzen). */
    val line: Int?,
)

/** Der eine Hinweis, den der Mentor nach einem Lauf gibt – der hilfreichste zuerst. */
data class MentorHint(val kind: Kind, val title: String, val text: String, val line: Int?) {
    enum class Kind { COMPILE, UNSUPPORTED, MISSING_CLASS, MISSING_MEMBER, ENDLESS, CRASH, WRONG_VALUE, REQUIREMENT, QUALITY, SUCCESS }
}

/** Ergebnis eines Laufs: Übersetzung, Tests, Pflicht-Bausteine, Code-Qualität, Sterne und Mentor. */
data class QuestResult(
    /** Lässt sich der Code nicht lesen, laufen keine Tests. */
    val compileProblem: JavaProblem?,
    val tests: List<QuestTestResult>,
    val missingRequirements: List<String>,
    val naming: List<QualityFinding>,
    val indentation: List<QualityFinding>,
    val mentor: MentorHint,
) {
    val passedCount: Int get() = tests.count { it.passed }
    val solved: Boolean get() = compileProblem == null && tests.isNotEmpty() && tests.all { it.passed } && missingRequirements.isEmpty()
    /** ★ alle Tests · ★ saubere Namen · ★ sauber eingerückt – die Qualitäts-Sterne nur, wenn alles läuft. */
    val stars: Int get() = if (solved) 1 + (if (naming.isEmpty()) 1 else 0) + (if (indentation.isEmpty()) 1 else 0) else 0
}

/** Prüft den Code einer Quest gegen ihre versteckten Tests – wie in der Apple-App. */
object QuestRunner {
    const val STEP_LIMIT = 40_000

    fun run(code: String, quest: CodeQuest): QuestResult {
        val source = JavaSource.normalizingTypography(code)

        // 1. Lässt sich der Code übersetzen?
        val program = try {
            JavaParser.parse(source)
        } catch (e: JavaProblem) {
            return QuestResult(e, emptyList(), emptyList(), emptyList(), emptyList(), Mentor.compile(e))
        }
        // 2. Gibt es die verlangte Klasse?
        if (!program.classes.containsKey(quest.className) && program.mainClass != quest.className) {
            val others = program.classOrder + listOfNotNull(program.mainClass)
            val similar = others.firstOrNull { it.lowercase() == quest.className.lowercase() }
            val hint = MentorHint(
                MentorHint.Kind.MISSING_CLASS, "Die Klasse ${quest.className} fehlt",
                similar?.let { "Deine Klasse heißt $it – Java unterscheidet Groß- und Kleinschreibung. Sie muss genau ${quest.className} heißen, wie die Datei ${quest.className}.java." }
                    ?: "Die Datei heißt ${quest.className}.java – deshalb muss darin die Klasse public class ${quest.className} { … } stehen.",
                null,
            )
            return QuestResult(null, quest.tests.map { QuestTestResult(it, false, null, hint.text, null) }, emptyList(), emptyList(), emptyList(), hint)
        }

        // 3. Die Tests
        val results = quest.tests.map { run(it, source) }

        // 4. Pflicht-Bausteine
        val masked = JavaSource.maskingLiterals(source)
        val missing = quest.requirements.filter { rule ->
            val target = if (rule.scope == RuleScope.RAW) JavaSource.strippingComments(source) else masked
            val hit = rule.allPatterns.any { AnswerEvaluator.matches(it, target) }
            if (rule.rule == RuleKind.FORBID) hit else !hit
        }.map { it.message }

        // 5. Code-Qualität
        val naming = CodeQuality.naming(source)
        val indentation = CodeQuality.indentation(source)

        return QuestResult(null, results, missing, naming, indentation, Mentor.after(results, missing, naming, indentation, quest))
    }

    internal fun run(test: QuestTest, source: String): QuestTestResult {
        // Nur eine Ausgabe, kein Ausdruck: das ganze Programm mit main.
        val expect = test.expect
        if (test.setup.isEmpty() && test.expression == null && expect is QuestExpectation.Output) {
            val result = JavaRunner.run(source, STEP_LIMIT)
            result.problem?.let { return QuestTestResult(test, false, null, Mentor.describe(it), it.line) }
            val passed = AnswerEvaluator.outputLines(result.output) == AnswerEvaluator.outputLines(expect.output)
            return QuestTestResult(test, passed, shown(result.output),
                if (passed) null else "Erwartet wird die Ausgabe „${shown(expect.output)}“, dein Programm gibt ${said(result.output)} aus.", null)
        }

        val outcome = JavaRunner.test(source, test.setup, test.expression, STEP_LIMIT)
        val problem = outcome.problem
        val call = outcome.failingTestCode
        if (problem != null && call != null && (problem.kind == JavaProblem.Kind.SYNTAX || problem.kind == JavaProblem.Kind.UNSUPPORTED)) {
            // Der Test kann nicht aufrufen, was er erwartet: Methode fehlt, heißt anders oder hat andere Parameter.
            return QuestTestResult(test, false, null, Mentor.MISSING_MEMBER_PREFIX + "$call“ auf – aber: ${problem.message}", null)
        }
        if (expect is QuestExpectation.Exception) {
            if (problem == null) {
                return QuestTestResult(test, false, outcome.text,
                    "Hier sollte eine ${expect.className} geworfen werden – dein Code läuft aber ohne Fehler durch${outcome.text?.let { " und liefert $it" } ?: ""}.", null)
            }
            val thrown = problem.exceptionClass
            val passed = problem.kind == JavaProblem.Kind.RUNTIME &&
                (thrown == expect.className || (expect.className in setOf("Exception", "RuntimeException") && thrown != null))
            return QuestTestResult(test, passed, thrown,
                if (passed) null else thrown?.let { "Erwartet wird eine ${expect.className}, geworfen wird aber eine $it." } ?: Mentor.describe(problem),
                problem.line)
        }
        if (problem != null) return QuestTestResult(test, false, problem.exceptionClass, Mentor.describe(problem), problem.line)
        return when (expect) {
            is QuestExpectation.Value -> {
                val (passed, message) = compare(expect.value, outcome)
                QuestTestResult(test, passed, display(outcome), if (passed) null else message, null)
            }
            is QuestExpectation.Text -> {
                val passed = outcome.text == expect.text
                QuestTestResult(test, passed, outcome.text, if (passed) null else "Erwartet: „${expect.text}“ – dein Code liefert „${outcome.text ?: ""}“.", null)
            }
            is QuestExpectation.Output -> {
                val passed = AnswerEvaluator.outputLines(outcome.output) == AnswerEvaluator.outputLines(expect.output)
                QuestTestResult(test, passed, shown(outcome.output),
                    if (passed) null else "Erwartet wird die Ausgabe „${shown(expect.output)}“, dein Code gibt ${said(outcome.output)} aus.", null)
            }
            is QuestExpectation.Exception -> QuestTestResult(test, false, null, null, null)
        }
    }

    /** Vergleich wie `assertEquals`: Wert und Art müssen passen (eine Zahl ist kein Text). */
    internal fun compare(expected: QuestValue, outcome: JavaTestOutcome): Pair<Boolean, String> {
        val actual = display(outcome)
        val mismatch = "Erwartet: ${expected.javaLiteral} – dein Code liefert $actual."
        val value = outcome.value ?: return false to mismatch
        return when {
            expected is QuestValue.BooleanV && value is JavaTestValue.BooleanV -> (expected.value == value.value) to mismatch
            expected is QuestValue.IntegerV && value is JavaTestValue.IntegerV -> (expected.value == value.value) to mismatch
            expected is QuestValue.DoubleV && value is JavaTestValue.DoubleV -> (abs(expected.value - value.value) < 1e-9) to mismatch
            expected is QuestValue.DoubleV && value is JavaTestValue.IntegerV -> (value.value.toDouble() == expected.value) to mismatch
            expected is QuestValue.StringV && value is JavaTestValue.StringV -> (expected.value == value.value) to mismatch
            expected is QuestValue.NullV && value is JavaTestValue.NullV -> true to mismatch
            value is JavaTestValue.VoidV ->
                false to "Die Methode gibt nichts zurück (void) – erwartet wird aber ${expected.javaLiteral}. Fehlt ein return?"
            else -> false to "Erwartet wird ${kind(expected)} (${expected.javaLiteral}), dein Code liefert aber ${kind(value)} ($actual)."
        }
    }

    private fun kind(value: QuestValue) = when (value) {
        is QuestValue.BooleanV -> "ein Wahrheitswert"
        is QuestValue.IntegerV -> "eine ganze Zahl"
        is QuestValue.DoubleV -> "eine Kommazahl"
        is QuestValue.StringV -> "ein Text"
        QuestValue.NullV -> "null"
    }

    private fun kind(value: JavaTestValue) = when (value) {
        is JavaTestValue.BooleanV -> "ein Wahrheitswert"
        is JavaTestValue.IntegerV -> "eine ganze Zahl"
        is JavaTestValue.DoubleV -> "eine Kommazahl"
        is JavaTestValue.CharV -> "ein Zeichen"
        is JavaTestValue.StringV -> "ein Text"
        JavaTestValue.NullV -> "null"
        JavaTestValue.VoidV -> "nichts"
        is JavaTestValue.Other -> "ein Objekt"
    }

    private fun display(outcome: JavaTestOutcome): String {
        val value = outcome.value
        if (value is JavaTestValue.StringV) return "\"${value.value}\""
        return outcome.text ?: "nichts"
    }

    private fun shown(output: String) = AnswerEvaluator.outputLines(output).joinToString(" ⏎ ")

    /** Für den Satz „dein Programm gibt … aus“ – ohne Ausgabe „nichts“ statt leerer Anführungszeichen. */
    private fun said(output: String) = if (AnswerEvaluator.outputLines(output).isEmpty()) "nichts" else "„${shown(output)}“"
}

/** Formuliert Fehler und gescheiterte Tests so, dass man weiß, was zu tun ist. */
object Mentor {
    const val MISSING_MEMBER_PREFIX = "Der Test ruft „"

    fun compile(problem: JavaProblem): MentorHint {
        if (problem.kind == JavaProblem.Kind.UNSUPPORTED) {
            return MentorHint(MentorHint.Kind.UNSUPPORTED, "Diesen Baustein kennt der Übungs-Compiler noch nicht",
                problem.message + " Bleib bei dem, was die Quest zeigt – damit klappt es.", problem.line)
        }
        val line = problem.line?.let { "Zeile $it: " } ?: ""
        val text = when {
            "Semikolon" in problem.message -> "${line}Du hast ein Semikolon vergessen. Jede Anweisung endet mit ; – wie ein Punkt am Satzende."
            "nie mit }" in problem.message || "nicht mit }" in problem.message ->
                "${line}Eine geschweifte Klammer { wird nie geschlossen. Zu jeder { gehört eine } – zähl sie einmal durch."
            else -> line + problem.message
        }
        return MentorHint(MentorHint.Kind.COMPILE, "Der Code lässt sich noch nicht übersetzen", text, problem.line)
    }

    /** Ein Fehler während eines Tests in Alltagssprache. */
    fun describe(problem: JavaProblem): String = when (problem.kind) {
        JavaProblem.Kind.STEP_LIMIT -> "Dein Code hört nicht mehr auf – vermutlich eine Endlosschleife. Prüfe, ob sich die Bedingung der Schleife irgendwann ändert."
        JavaProblem.Kind.RUNTIME -> "Dein Programm stürzt ab: ${problem.description}"
        JavaProblem.Kind.SYNTAX, JavaProblem.Kind.UNSUPPORTED -> problem.description
    }

    fun after(results: List<QuestTestResult>, missing: List<String>, naming: List<QualityFinding>, indentation: List<QualityFinding>, quest: CodeQuest): MentorHint {
        results.firstOrNull { !it.passed }?.let { failed ->
            val message = failed.message ?: ""
            if (message.startsWith(MISSING_MEMBER_PREFIX)) {
                val tip = when {
                    "Konstruktor" in message -> "Schreib den Konstruktor so, wie der Auftrag ihn verlangt – mit denselben Parametern."
                    "statische" in message -> "Prüfe Name, Groß- und Kleinschreibung, static und die Parameter – genau wie im Auftrag."
                    else -> "Prüfe Name, Groß- und Kleinschreibung und die Parameter – genau wie im Auftrag."
                }
                return MentorHint(MentorHint.Kind.MISSING_MEMBER, "Der Test findet nicht, was er aufruft", "$message $tip", null)
            }
            if ("Endlosschleife" in message) {
                return MentorHint(MentorHint.Kind.ENDLESS, "Deine Schleife läuft endlos",
                    "Beim Test „${failed.test.name}“ hört dein Code nicht auf. Prüfe, ob sich die Bedingung der Schleife irgendwann ändert – zählst du hoch oder runter?",
                    failed.line)
            }
            if (message.startsWith("Dein Programm stürzt ab")) {
                return MentorHint(MentorHint.Kind.CRASH, "Absturz beim Test „${failed.test.name}“", "$message ${failed.test.hint}", failed.line)
            }
            val passed = results.count { it.passed }
            return MentorHint(MentorHint.Kind.WRONG_VALUE, "$passed von ${results.size} Tests bestanden",
                "„${failed.test.name}“: $message ${failed.test.hint}", failed.line)
        }
        missing.firstOrNull()?.let { return MentorHint(MentorHint.Kind.REQUIREMENT, "Alle Tests grün – eine Bedingung fehlt noch", it, null) }
        (naming.firstOrNull() ?: indentation.firstOrNull())?.let {
            return MentorHint(MentorHint.Kind.QUALITY, "Alle Tests grün! Für den nächsten Stern:", it.message, it.line)
        }
        return MentorHint(MentorHint.Kind.SUCCESS, "Perfekt – alle Tests grün und sauberer Code!", quest.success, null)
    }
}

// ---------------------------------------------------------------- Fortschritt

/**
 * Wie weit man im Abenteuer ist: welche Quest offen ist, was im Inventar liegt, welche Baupläne freigeschaltet sind
 * und ob die Werkstatt (freies Bauen) schon offen steht. Quest-Ergebnisse liegen im selben Protokoll wie
 * Arena-Missionen (Kontext „mission“, ID `quest-…`, credit = Sterne / 3) – wie in der Apple-App.
 */
class QuestProgress(val book: QuestBook, course: Course, stars: Map<String, Int>, private val unlockedLessonIds: Set<String>) {
    sealed interface State {
        /** Noch gesperrt – mit dem Grund („Erst „Die Tür“ lösen“). */
        data class Locked(val reason: String) : State
        data object Open : State
        data class Solved(val stars: Int) : State

        val isPlayable: Boolean get() = this !is Locked
    }

    /** Beste Sterne je Quest-ID. */
    val stars: Map<String, Int> = stars.filter { (id, value) -> book.quest(id) != null && value > 0 }
    private val lessonTitles: Map<String, Pair<Int, String>> =
        course.allLessons.withIndex().associate { (index, lesson) -> lesson.id to ((index + 1) to lesson.title) }

    fun state(quest: CodeQuest): State {
        stars[quest.id]?.let { return State.Solved(it) }
        book.previous(quest)?.let { previous -> if (stars[previous.id] == null) return State.Locked("Erst „${previous.title}“ lösen") }
        if (quest.lessonId !in unlockedLessonIds) {
            return State.Locked(lessonTitles[quest.lessonId]?.let { (number, title) -> "Ab Lektion $number: $title" } ?: "Lektion noch nicht erreicht")
        }
        return State.Open
    }

    val solvedCount: Int get() = stars.size
    val totalStars: Int get() = stars.values.sum()
    val maxStars: Int get() = book.quests.size * 3

    /** Die nächste Quest, die man spielen kann – oder null, wenn alles gelöst oder noch gesperrt ist. */
    val nextQuest: CodeQuest? get() = book.quests.firstOrNull { state(it) == State.Open }

    fun solvedCount(chapter: QuestChapter): Int = book.quests(chapter).count { stars[it.id] != null }

    /** Gegenstände aus gelösten Quests, in der Reihenfolge der Geschichte. */
    val inventory: List<QuestReward> get() = book.quests.filter { stars[it.id] != null }.map { it.reward }

    /** Baupläne gibt es für sauberen Code: Erst mit allen 3 Sternen landet der Bauplan der Quest in der Werkstatt. */
    fun isBlueprintUnlocked(quest: CodeQuest): Boolean = quest.blueprint != null && stars[quest.id] == 3

    val blueprints: List<Pair<CodeQuest, QuestBlueprint>>
        get() = book.quests.mapNotNull { quest -> quest.blueprint?.takeIf { isBlueprintUnlocked(quest) }?.let { quest to it } }

    /** Die Werkstatt öffnet, sobald das erste Kapitel geschafft ist. */
    val isWorkshopUnlocked: Boolean
        get() {
            val first = book.chapters.firstOrNull() ?: return false
            return book.quests(first).all { stars[it.id] != null }
        }
}
