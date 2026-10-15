package app.javaquest

import app.javaquest.core.Achievement
import app.javaquest.core.ActivityRecord
import app.javaquest.core.ArenaCatalog
import app.javaquest.core.CodeEditing
import app.javaquest.core.CodeQuality
import app.javaquest.core.CourseLoader
import app.javaquest.core.Experience
import app.javaquest.core.LearnerFacts
import app.javaquest.core.MentorHint
import app.javaquest.core.QuestBook
import app.javaquest.core.QuestProgress
import app.javaquest.core.QuestRunner
import app.javaquest.core.interpreter.JavaProblem
import app.javaquest.core.interpreter.JavaRunner
import app.javaquest.core.interpreter.JavaTestValue
import app.javaquest.core.interpreter.test
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Dieselben Prüfungen wie `QuestTests.swift` – Windows und Android bewerten Quests genau wie die Apple-App. */
class QuestTest {
    private val book = QuestBook.loadBundled()
    private val course = CourseLoader.loadBundled()
    private fun quest(id: String) = assertNotNull(book.quest(id), id)

    @Test fun `Quests sind vollstaendig und folgen dem Kurs`() {
        assertTrue(book.quests.size >= 16)
        assertEquals(book.quests.size, book.quests.map { it.id }.toSet().size, "IDs doppelt")
        assertTrue(book.quests.all { it.id.startsWith(QuestBook.ID_PREFIX) })
        val lessons = course.allLessons.map { it.id }
        var last = 0
        for (quest in book.quests) {
            val index = lessons.indexOf(quest.lessonId)
            assertTrue(index >= 0, "${quest.id}: Lektion ${quest.lessonId}")
            assertTrue(index >= last, "${quest.id} kommt vor einer früheren Lektion")
            last = index
            assertTrue(quest.visibleTests.isNotEmpty(), quest.id)
            assertNotNull(book.chapter(quest.chapterId), quest.id)
        }
        assertEquals(Achievement.QUEST_COUNT, book.quests.size, "Ziel des Abzeichens an das Questbuch anpassen")
    }

    @Test fun `Jede Musterloesung besteht alle Tests mit 3 Sternen`() {
        for (quest in book.quests) {
            val result = QuestRunner.run(quest.solution, quest)
            val failures = result.tests.filter { !it.passed }.map { "${it.test.name}: ${it.message}" }
            assertTrue(result.solved, "${quest.id}: ${result.compileProblem?.description} $failures ${result.missingRequirements}")
            assertEquals(3, result.stars, "${quest.id}: ${result.naming.map { it.message }} ${result.indentation.map { it.message }}")
            assertEquals(MentorHint.Kind.SUCCESS, result.mentor.kind, quest.id)
        }
    }

    @Test fun `Der Startcode uebersetzt, loest die Quest aber nicht`() {
        for (quest in book.quests) {
            assertNull(JavaRunner.check(quest.starterCode), quest.id)
            val result = QuestRunner.run(quest.starterCode, quest)
            assertFalse(result.solved, quest.id)
            assertNull(result.compileProblem, quest.id)
        }
    }

    @Test fun `Die Tuer aus dem Beispiel`() {
        val tuer = quest("quest-tuer")
        val halb = "public class Tuer {\n    public static boolean unlock(int key) {\n        return key > 100;\n    }\n}"
        val result = QuestRunner.run(halb, tuer)
        assertFalse(result.solved)
        assertEquals(3, result.passedCount)
        assertEquals(MentorHint.Kind.WRONG_VALUE, result.mentor.kind)
        assertTrue("110" in result.mentor.text)
        val failed = result.tests.first { !it.passed }
        assertEquals("true", failed.actual)
        assertTrue(failed.message!!.contains("Erwartet: false"))
        assertEquals("assertEquals(true, Tuer.unlock(105));", tuer.visibleTests.first().assertion)
    }

    @Test fun `Mentor erklaert Fehler`() {
        val tuer = quest("quest-tuer")
        val semikolon = QuestRunner.run("public class Tuer {\n    public static boolean unlock(int key) {\n        return key > 100\n    }\n}", tuer)
        assertEquals(MentorHint.Kind.COMPILE, semikolon.mentor.kind)
        assertTrue("Semikolon" in semikolon.mentor.text)
        assertEquals(3, semikolon.mentor.line)

        val ohneMethode = QuestRunner.run(tuer.starterCode, tuer)
        assertEquals(MentorHint.Kind.MISSING_MEMBER, ohneMethode.mentor.kind)
        assertTrue("Tuer.unlock(105)" in ohneMethode.mentor.text)
        assertNull(ohneMethode.mentor.line)
        val golem = quest("quest-golem")
        assertEquals(MentorHint.Kind.MISSING_MEMBER, QuestRunner.run(golem.starterCode, golem).mentor.kind)

        val klasse = QuestRunner.run("public class tuer {\n    public static boolean unlock(int key) {\n        return true;\n    }\n}", tuer)
        assertEquals(MentorHint.Kind.MISSING_CLASS, klasse.mentor.kind)
        assertTrue("Groß- und Kleinschreibung" in klasse.mentor.text)

        val treppe = quest("quest-wendeltreppe")
        val endlos = "public class Treppe {\n    static int stufen(int stockwerke) {\n        int summe = 0;\n        int i = 1;\n" +
            "        while (i <= stockwerke) {\n            summe = summe + i;\n        }\n        return summe;\n    }\n}"
        assertEquals(MentorHint.Kind.ENDLESS, QuestRunner.run(endlos, treppe).mentor.kind)

        val ohneReturn = "public class Golem {\n    private String name;\n    private int energie = 100;\n\n    public Golem(String name) {\n" +
            "        this.name = name;\n    }\n\n    public String getName() {\n        return name;\n    }\n\n    public void getEnergie() {\n    }\n\n" +
            "    public void arbeiten() {\n        energie = energie - 30;\n    }\n}"
        assertTrue(QuestRunner.run(ohneReturn, golem).tests.first().message!!.contains("Fehlt ein return?"))
    }

    @Test fun `Exceptions und Pflicht-Bausteine`() {
        val kammer = quest("quest-schatzkammer")
        val ohnePruefung = QuestRunner.run(kammer.solution.replace("menge < 1 || ", ""), kammer)
        val negativ = ohnePruefung.tests.first { "Negatives" in it.test.name }
        assertFalse(negativ.passed)
        assertTrue("ohne Fehler" in negativ.message!!)
        val falsch = QuestRunner.run(kammer.solution.replace("IllegalArgumentException", "IllegalStateException"), kammer)
        assertTrue(falsch.tests.any { it.message?.contains("IllegalStateException") == true })

        val rune = quest("quest-rechenrune")
        val geschummelt = QuestRunner.run("public class Rune {\n    public static void main(String[] args) {\n        System.out.println(\"Runencode: 100\");\n    }\n}", rune)
        assertTrue(geschummelt.tests.all { it.passed })
        assertFalse(geschummelt.solved)
        assertEquals(MentorHint.Kind.REQUIREMENT, geschummelt.mentor.kind)
    }

    @Test fun `Sauberer Code bringt Sterne`() {
        val tuer = quest("quest-tuer")
        val parameter = "public class Tuer {\n    public static boolean unlock(int Key) {\n        int Rest = Key % 7;\n        return Key > 100 && Rest == 0;\n    }\n}"
        val result = QuestRunner.run(parameter, tuer)
        assertTrue(result.solved)
        assertEquals(2, result.stars)
        assertTrue(result.naming.any { "key statt Key" in it.message })
        assertTrue(result.naming.any { "rest statt Rest" in it.message })
        assertEquals(MentorHint.Kind.QUALITY, result.mentor.kind)

        val schief = "public class Tuer {\npublic static boolean unlock(int key) {\n      return key > 100 && key % 7 == 0;\n  }\n}"
        val schiefResult = QuestRunner.run(schief, tuer)
        assertEquals(2, schiefResult.stars)
        assertEquals(listOf(2, 3, 4), schiefResult.indentation.map { it.line })

        val ok = "public class A {\n    static String f(int x) {\n        switch (x) {\n            case 1:\n                return \"eins\";\n" +
            "            default:\n                return \"viel\";\n        }\n    }\n\n    static int g(int a,\n                 int b) {\n" +
            "    \treturn a\n                + b;\n    }\n}"
        assertEquals(emptyList(), CodeQuality.indentation(ok).map { it.message })
        assertEquals("maxWert", CodeQuality.suggestedVariable("Max_Wert"))
        assertEquals("MeinHeld", CodeQuality.suggestedType("mein_held"))
        assertEquals("MAX_ENERGIE", CodeQuality.suggestedConstant("maxEnergie"))
    }

    @Test fun `Tests sehen Objekte, Ausgaben und Fehler`() {
        val code = "public class Golem {\n    private int energie = 100;\n\n    public void arbeiten() {\n        System.out.println(\"Bumm\");\n" +
            "        energie -= 30;\n    }\n\n    public int getEnergie() {\n        return energie;\n    }\n}"
        val outcome = JavaRunner.test(code, "Golem g = new Golem();\ng.arbeiten();", "g.getEnergie()")
        assertEquals(JavaTestValue.IntegerV(70), outcome.value)
        assertEquals("int", outcome.typeName)
        assertEquals("Bumm\n", outcome.output)
        val syntax = JavaRunner.test("public class A {\n    int x = ;\n}", expression = "1")
        assertEquals(JavaProblem.Kind.SYNTAX, syntax.problem?.kind)
        assertEquals(2, syntax.problem?.line)
        val thrown = JavaRunner.test("public class A {\n    static int f() {\n        throw new IllegalStateException(\"kaputt\");\n    }\n}", expression = "A.f()")
        assertEquals("IllegalStateException", thrown.problem?.exceptionClass)
        assertEquals(3, thrown.problem?.line)
    }

    @Test fun `Quests oeffnen sich der Reihe nach`() {
        val fresh = QuestProgress(book, course, emptyMap(), setOf("l01-hello"))
        assertEquals(QuestProgress.State.Open, fresh.state(book.quests[0]))
        assertEquals(QuestProgress.State.Locked("Erst „${book.quests[0].title}“ lösen"), fresh.state(book.quests[1]))
        assertFalse(fresh.isWorkshopUnlocked)
        val afterFirst = QuestProgress(book, course, mapOf(book.quests[0].id to 2), setOf("l01-hello"))
        assertTrue((afterFirst.state(book.quests[1]) as QuestProgress.State.Locked).reason.startsWith("Ab Lektion 2"))
        assertTrue(afterFirst.blueprints.isEmpty())
        val chapterOne = book.quests(book.chapters[0])
        val workshop = QuestProgress(book, course, chapterOne.associate { it.id to 3 } + ("a01-erste-schritte" to 3), course.allLessons.map { it.id }.toSet())
        assertTrue(workshop.isWorkshopUnlocked)
        assertEquals(chapterOne.size, workshop.blueprints.size)
        assertEquals(chapterOne.size, workshop.solvedCount)
        assertEquals(book.quests[chapterOne.size].id, workshop.nextQuest?.id)
    }

    @Test fun `Quest-Sterne bringen XP und eigene Abzeichen`() {
        val records = book.quests.take(5).map {
            ActivityRecord(it.id, it.topicId, ActivityRecord.MISSION, it.difficulty, ActivityRecord.credit(3), true, 1, Instant.ofEpochSecond(1_800_000_000))
        }
        val facts = LearnerFacts(course, ArenaCatalog.loadBundled(), records, emptyMap(), 0)
        val unlocked = Achievement.unlocked(facts)
        assertTrue("first-quest" in unlocked)
        assertTrue("clean-code" in unlocked)
        assertFalse("javahall" in unlocked)
        assertFalse("first-mission" in unlocked, "Quests sind keine Arena-Missionen")
        assertEquals(5, facts.questStars.size)
        assertEquals(5 * 3 * Experience.PER_MISSION_STAR, facts.experience)
    }

    private fun type(input: String, text: String, cursor: Int): Pair<String, Int>? =
        CodeEditing.edit(input, text, cursor)?.let { it.applyTo(text) to it.cursor }

    @Test fun `Editor wie in der Apple-App`() {
        val open = "public class A {"
        assertEquals("public class A {\n    \n}" to open.length + 5, type("\n", open, open.length))
        assertEquals("class A {\n    void f() {\n        \n    }\n}", type("\n", "class A {\n    void f() {\n}", "class A {\n    void f() {".length)?.first)
        assertEquals("class A {\n    void f() {\n        \n    }\n}", type("\n", "class A {\n    void f() {\n    }\n}", "class A {\n    void f() {".length)?.first)
        assertEquals("if (x) {\n    \n}" to 13, type("\n", "if (x) {}", 8))
        assertEquals("    int x = 1;\n    ", type("\n", "    int x = 1;", 14)?.first)

        val code = "class A {\n    void f() {\n        int x = 1;\n        "
        assertTrue(type("}", code, code.length)!!.first.endsWith("int x = 1;\n    }"))
        assertEquals("ab  " to 4, type("\t", "ab", 2))
        assertEquals("f()" to 2, type("(", "f", 1))
        assertEquals("f()" to 3, type(")", "f()", 2))
        assertNull(type("(", "fx", 1))
        assertEquals("s = \"\";" to 5, type("\"", "s = ;", 4))
        assertEquals("s = \"ab\";" to 8, type("\"", "s = \"ab\";", 7))
        assertNull(type("(", "s = \" \";", 6))
        val tricky = "class A {\n    String s = \"{\";\n    "
        assertTrue(type("}", tricky, tricky.length)!!.first.endsWith("\n}"))

        // Eine schon gesetzte } wird übersprungen statt verdoppelt.
        val skip = "if (x) {\n    return x;\n    \n}"
        val (skipped, at) = type("}", skip, "if (x) {\n    return x;\n    ".length)!!
        assertEquals("if (x) {\n    return x;\n}", skipped)
        assertEquals(skipped.length, at)

        val insert = CodeEditing.insertion("int x = 1;\nint y = 2;", "class A {\n    ", 14)
        assertEquals("int x = 1;\n    int y = 2;", insert.replacement)
        assertEquals("\n    a();\n    b();", CodeEditing.insertion("a();\nb();", "    f();", 8).replacement)
    }
}
