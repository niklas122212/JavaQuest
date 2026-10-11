package app.javaquest.core.interpreter

import app.javaquest.core.JavaSource
import java.util.concurrent.atomic.AtomicReference

/** Ergebnis eines versteckten Tests: der Wert des Ausdrucks, die Ausgabe dabei – oder der Fehler. */
class JavaTestOutcome(
    /** Der Wert in vergleichbarer Form; null, wenn der Test mit einem Fehler endete. */
    val value: JavaTestValue?,
    /** So würde `System.out.println` den Wert zeigen (bei Objekten über `toString()`). */
    val text: String?,
    /** Typ des Werts, wie Java ihn nennt (`int`, `boolean`, `String`, `Golem` …). */
    val typeName: String?,
    /** Was das Programm während des Tests ausgegeben hat. */
    val output: String,
    val problem: JavaProblem?,
    /**
     * Scheitert schon der Testcode selbst (fehlende Methode, falscher Konstruktor), steht hier die Zeile des Tests,
     * die nicht klappt – z. B. `Tuer.unlock(105)`. Die Zeilennummer im Fehler gehört dann nicht zum Code des Spielers.
     */
    val failingTestCode: String? = null,
)

/** Ein Testwert ohne Interpreter-Innenleben – damit Quests ihn mit dem erwarteten Wert vergleichen können. */
sealed interface JavaTestValue {
    data class IntegerV(val value: Long) : JavaTestValue
    data class DoubleV(val value: Double) : JavaTestValue
    data class BooleanV(val value: Boolean) : JavaTestValue
    data class CharV(val value: String) : JavaTestValue
    data class StringV(val value: String) : JavaTestValue
    data object NullV : JavaTestValue
    data object VoidV : JavaTestValue
    /** Objekte, Arrays und Sammlungen – verglichen wird über ihren Text. */
    data class Other(val text: String) : JavaTestValue

    companion object {
        fun of(value: JValue, text: String): JavaTestValue = when (value) {
            is JValue.IntV -> IntegerV(value.value.toLong())
            is JValue.LongV -> IntegerV(value.value)
            is JValue.DoubleV -> DoubleV(value.value)
            is JValue.BoolV -> BooleanV(value.value)
            is JValue.CharV -> CharV(value.value.toString())
            is JValue.StrV -> StringV(value.ref.text)
            JValue.Null -> NullV
            JValue.Void -> VoidV
            is JValue.ArrV, is JValue.Obj -> Other(text)
        }
    }
}

/** Name der Hilfsklasse, in der Vorbereitung und Ausdruck eines Tests stehen. */
private const val TEST_CLASS = "QuestTest__"

/**
 * Testet ein Programm wie ein JUnit-Test: Klassen und statische Felder werden geladen, `main` läuft nicht.
 * Dann kommen die Anweisungen aus [setup] und zuletzt der Ausdruck [expression] (z. B. `Tuer.unlock(105)`),
 * dessen Wert zurückkommt. Ohne Ausdruck zählt nur die Ausgabe. Wie in der Apple-App.
 */
fun JavaRunner.test(source: String, setup: String = "", expression: String?, stepLimit: Int = 40_000): JavaTestOutcome {
    val result = AtomicReference<JavaTestOutcome>()
    val thread = Thread(null, { result.set(testDirectly(source, setup, expression, stepLimit)) }, "java-test", 64L shl 20)
    thread.start()
    thread.join()
    return result.get() ?: JavaTestOutcome(null, null, null, "", JavaProblem.runtime("Der Test konnte nicht gestartet werden.", null))
}

private fun testDirectly(source: String, setup: String, expression: String?, stepLimit: Int): JavaTestOutcome {
    fun failed(problem: JavaProblem) = JavaTestOutcome(null, null, null, "", problem)
    val normalized = JavaSource.normalizingTypography(source)
    // Erst den Code des Spielers allein – damit Fehler darin ihre echte Zeilennummer behalten.
    try {
        JavaParser.parse(normalized)
    } catch (e: JavaProblem) {
        return failed(e)
    }
    // Dann zusammen mit dem Testcode: So kennt die Vorbereitung alle Klassen des Spielers
    // (`Golem g = new Golem("Rolf");`). Der Ausdruck steht in einem println und wird dort herausgelöst.
    // Zeile für Zeile zusammengesetzt (nicht trimMargin – Code darf mit „||“ beginnen).
    val harness = listOf(
        normalized,
        "",
        "class $TEST_CLASS {",
        "    static void vorbereiten() {",
        setup,
        "    }",
        "    static void ausdruck() {",
        "        System.out.println(${expression ?: "0"});",
        "    }",
        "}",
    ).joinToString("\n")
    val program: Program
    val setupStatements: List<Stmt>
    val expr: Expr?
    try {
        program = JavaParser.parse(harness)
        val testClass = program.classes[TEST_CLASS]
        val prepare = testClass?.methods?.get("vorbereiten")?.firstOrNull()
        val evaluate = testClass?.methods?.get("ausdruck")?.firstOrNull()
        val call = ((evaluate?.body?.firstOrNull() as? Stmt.ExprStmt)?.expr as? Expr.Call)
        if (prepare == null || call == null || call.name != "println" || call.args.size != 1) {
            return failed(JavaProblem.unsupported("Testcode: Der Test lässt sich nicht aufbauen.", null))
        }
        setupStatements = prepare.body
        expr = if (expression == null) null else call.args[0]
    } catch (e: JavaProblem) {
        return failed(JavaProblem.unsupported("Testcode: ${e.description}", null))
    }
    program.classes.remove(TEST_CLASS)
    program.classOrder.remove(TEST_CLASS)

    val interpreter = JavaInterpreter(program, stepLimit, null)
    val (value, problem) = interpreter.runTest(setupStatements, expr)
    if (value == null || problem != null) {
        val playerLines = normalized.split("\n").size
        val line = problem?.line
        if (problem != null && line != null && line > playerLines) {
            // Der Fehler steckt im Testcode – meist ruft der Test etwas auf, das es (so) noch nicht gibt.
            val harnessLines = harness.split("\n")
            var code = harnessLines.getOrNull(line - 1)?.trim() ?: ""
            if (code.startsWith("System.out.println(") && code.endsWith(");")) code = code.removePrefix("System.out.println(").dropLast(2)
            val moved = JavaProblem(problem.kind, problem.message, null).also {
                it.exceptionClass = problem.exceptionClass
                it.javaMessage = problem.javaMessage
                it.thrown = problem.thrown
            }
            return JavaTestOutcome(null, null, null, interpreter.output.toString(), moved, code.ifEmpty { null })
        }
        return JavaTestOutcome(null, null, null, interpreter.output.toString(), problem)
    }
    val text = runCatching { interpreter.printable(value, 0) }.getOrElse { value.javaString }
    return JavaTestOutcome(JavaTestValue.of(value, text), text, value.typeName, interpreter.output.toString(), null)
}

/** Lädt Klassen und statische Felder, führt die Testanweisungen aus und wertet den Ausdruck aus – ohne `main`. */
internal fun JavaInterpreter.runTest(setup: List<Stmt>, expression: Expr?): Pair<JValue?, JavaProblem?> = try {
    validateClasses()
    initializeClasses()
    for (field in program.staticFields) execute(field, global = true)
    for (statement in setup) execute(statement)
    (if (expression == null) JValue.Void else evaluate(expression)) to null
} catch (e: JavaProblem) {
    null to e
} catch (e: StackOverflowError) {
    null to JavaProblem.runtime("StackOverflowError: Eine Methode ruft sich immer wieder selbst auf. Jede Rekursion braucht einen Abbruchfall.", null)
}
