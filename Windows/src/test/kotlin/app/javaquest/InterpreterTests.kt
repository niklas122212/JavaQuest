package app.javaquest

import app.javaquest.core.AnswerEvaluator
import app.javaquest.core.CourseLoader
import app.javaquest.core.TaskKind
import app.javaquest.core.interpreter.JavaProblem
import app.javaquest.core.interpreter.JavaRunner
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class InterpreterTest {
    private fun problem(source: String) = JavaRunner.run(source).problem

    @Test fun `Gleiche Ausgabe wie ein echtes JDK`() {
        val text = javaClass.getResourceAsStream("/java_differential.json")!!.bufferedReader().readText()
        val cases = Json.parseToJsonElement(text).jsonArray
        assertTrue(cases.size >= 5)
        for (case in cases) {
            val obj = case.jsonObject
            val name = obj.getValue("name").jsonPrimitive.content
            val result = JavaRunner.run(obj.getValue("source").jsonPrimitive.content)
            assertNull(result.problem, "$name: ${result.problem?.description}")
            assertEquals(obj.getValue("expected").jsonPrimitive.content, result.output, name)
        }
    }

    @Test fun `printf mit Zeilenumbruch gibt auf jedem System dasselbe aus`() {
        // %n wäre unter Windows „\r\n“ – die App vergleicht aber mit „\n“ wie auf Mac und iPhone.
        assertEquals("a\nb\n", JavaRunner.run("System.out.printf(\"a%nb%n\");").output)
        assertEquals("1.50\n", JavaRunner.run("System.out.print(String.format(\"%.2f%n\", 1.5));").output)
    }

    @Test fun `Fehler mit Zeile und verstaendlicher Meldung`() {
        val semicolon = assertNotNull(problem("int x = 5\nSystem.out.println(x);"))
        assertEquals(JavaProblem.Kind.SYNTAX, semicolon.kind)
        assertEquals(1, semicolon.line)
        assertTrue("Semikolon" in semicolon.message)

        val unknown = assertNotNull(problem("int zahl = 3;\nSystem.out.println(Zahl);"))
        assertEquals(2, unknown.line)
        assertTrue("Meintest du „zahl“" in unknown.message)

        assertTrue("(int)" in assertNotNull(problem("int x = 2.5;")).message)

        val index = assertNotNull(problem("int[] a = new int[3];\na[3] = 1;"))
        assertEquals(JavaProblem.Kind.RUNTIME, index.kind)
        assertEquals(2, index.line)

        assertEquals(3, problem("int a = 5;\nint b = 0;\nSystem.out.println(a / b);")?.line)
        assertTrue("==" in assertNotNull(problem("int x = 1;\nif (x = 2) { }")).message)
        assertTrue("final" in assertNotNull(problem("final int MAX = 3;\nMAX = 4;")).message)
    }

    @Test fun `Endlosschleifen und endlose Rekursion werden gestoppt`() {
        assertEquals(JavaProblem.Kind.STEP_LIMIT, JavaRunner.run("while (true) { }", stepLimit = 5_000).problem?.kind)
        assertTrue("StackOverflowError" in assertNotNull(problem("static int f(int n) { return f(n + 1); }\nSystem.out.println(f(0));")).message)
    }

    @Test fun `Unbekannte Bausteine sind nicht unterstuetzt statt falsch`() {
        listOf(
            "List<String> l = new ArrayList<>();",
            "class Hund { String name; Hund(String n) { name = n; } }",
            "try { int x = 1; } catch (Exception e) { }",
            "Runnable r = () -> System.out.println(1);",
        ).forEach { assertEquals(JavaProblem.Kind.UNSUPPORTED, problem(it)?.kind, it) }
    }

    @Test fun `Strings mit == vergleichen wie in Java`() {
        val result = JavaRunner.run("String a = \"Java\";\nString b = new String(\"Java\");\nSystem.out.println(a == b);\nSystem.out.println(a.equals(b));")
        assertEquals("false\ntrue\n", result.output)
        assertTrue(result.warnings.any { "equals" in it.message && it.line == 3 })
    }

    @Test fun `Wo der Interpreter den Kurscode versteht, rechnet er wie Java`() {
        val course = CourseLoader.loadBundled()
        var supported = 0
        for (task in course.allTasks) {
            val (source, expected) = when (val kind = task.kind) {
                is TaskKind.PredictOutput -> (task.code?.source ?: continue) to kind.expectedOutput
                is TaskKind.Code -> kind.solution.source to (kind.expectedOutput ?: continue)
                else -> continue
            }
            val result = JavaRunner.run(source)
            if (result.problem?.kind == JavaProblem.Kind.UNSUPPORTED) continue
            supported++
            assertNull(result.problem, "${task.id}: ${result.problem?.description}")
            assertEquals(AnswerEvaluator.outputLines(expected), AnswerEvaluator.outputLines(result.output), task.id)
        }
        assertTrue(supported >= 17, "nur $supported Aufgaben")
    }
}
