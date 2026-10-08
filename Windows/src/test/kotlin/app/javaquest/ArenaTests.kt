package app.javaquest

import app.javaquest.core.ArenaAction
import app.javaquest.core.ArenaCatalog
import app.javaquest.core.ArenaEngine
import app.javaquest.core.ArenaGoal
import app.javaquest.core.ArenaMission
import app.javaquest.core.ArenaPlayback
import app.javaquest.core.ArenaSimulation
import app.javaquest.core.CodeInsertion
import app.javaquest.core.GridPoint
import app.javaquest.core.StarCriterion
import app.javaquest.core.CourseLoader
import app.javaquest.core.JavaSource
import app.javaquest.core.MissionKind
import app.javaquest.core.RobotCommand
import app.javaquest.core.interpreter.JavaProblem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.test.fail

/** Dieselben Prüfungen wie ArenaTests.swift – gleiche Missionsdatei, gleiche Regeln. */
class ArenaTest {
    private val catalog = ArenaCatalog.loadBundled()
    private val course = CourseLoader.loadBundled()
    private val lessonOrder = course.allLessons.map { it.id }

    private fun lessonIndex(mission: ArenaMission) = lessonOrder.indexOf(mission.lessonId).let { if (it < 0) Int.MAX_VALUE else it }

    private fun mission(map: List<String>, coins: Boolean = false, output: String? = null): ArenaMission {
        val worldMap = map.joinToString(",") { "\"$it\"" }
        val expected = output?.let { ",\"expectedOutput\":\"$it\"" } ?: ""
        val json = """
            {"missions":[{"id":"test","kind":"training","title":"T","story":"","lessonId":"l01-hello","topicId":"syntax","difficulty":1,
             "worlds":[{"map":[$worldMap]$expected}],"newCommands":["move","turnLeft","turnRight","pickCoin","frontIsClear","leftIsClear","rightIsClear","onCoin","atGoal","coins"],
             "solution":"","hint":"","collectAllCoins":$coins,"bonus":[{"type":"allCoins"},{"type":"maxLines","value":3}]}],
             "playground":{"map":["#R#"]}}
        """.trimIndent()
        return ArenaCatalog.parse(json).missions.single()
    }

    @Test fun `Missionen sind vollstaendig und passen zum Kurs`() {
        assertTrue(catalog.missions.size >= 13)
        assertEquals(catalog.missions.size, catalog.missions.map { it.id }.toSet().size, "IDs doppelt")
        val lessonIds = course.allLessons.map { it.id }.toSet()
        val topicIds = course.topics.map { it.id }.toSet()
        for (mission in catalog.missions) {
            assertTrue(mission.lessonId in lessonIds, "${mission.id}: Lektion ${mission.lessonId}")
            assertTrue(mission.topicId in topicIds, "${mission.id}: Thema ${mission.topicId}")
            assertEquals(2, mission.bonus.size, "${mission.id}: genau zwei Zusatzziele")
            assertTrue(mission.worlds.isNotEmpty())
            if (mission.kind == MissionKind.BOSS) assertTrue(course.modules.any { it.id == mission.moduleId }, "${mission.id}: Modul")
            mission.worlds.forEachIndexed { index, world ->
                assertNotNull(world.start, "${mission.id} Welt ${index + 1}: kein Startfeld R")
                if (mission.reachGoal) assertNotNull(world.goal, "${mission.id} Welt ${index + 1}: kein Ziel G")
                assertEquals(1, world.map.map { it.length }.toSet().size, "${mission.id} Welt ${index + 1}: Zeilen ungleich lang")
            }
        }
        for (lessonId in listOf("l01-hello", "l02-variables", "l03-operators", "l04-conditionals", "l05-loops", "l06-methods", "l07-arrays-strings")) {
            assertNotNull(catalog.lessonMission(lessonId), "Keine Mission für $lessonId")
        }
        for (moduleId in listOf("m1-first-steps", "m2-control-flow", "m3-objects")) {
            assertNotNull(catalog.bossMission(moduleId), "Kein Boss für $moduleId")
        }
        assertNotNull(catalog.playground.start)
    }

    @Test fun `Jede Musterloesung schafft alle Welten mit 3 Sternen`() {
        for (mission in catalog.missions) {
            val result = ArenaEngine.run(mission.solution.source, mission)
            assertTrue(result.solved, "${mission.id}: ${result.runs.flatMap { it.failures } + result.missingRequirements}")
            assertEquals(3, result.stars, "${mission.id}: ${result.criteria.filter { !it.met }.map { it.criterion.title }}")
        }
    }

    @Test fun `Der Startcode allein loest keine Mission`() {
        for (mission in catalog.missions) assertFalse(ArenaEngine.run(mission.starterCode, mission).solved, mission.id)
    }

    @Test fun `Gegen die Wand fahren bricht mit Zeilennummer ab und wird animiert`() {
        val corridor = mission(listOf("#####", "#R.G#", "#####"))
        val result = ArenaEngine.run("robot.move();\nrobot.move();\nrobot.move();", corridor)
        assertFalse(result.solved)
        val run = result.runs.first()
        assertEquals(3, run.problem?.line)
        assertTrue(run.problem?.message?.contains("Wand") == true)
        assertEquals(ArenaAction.Crash(GridPoint(4, 1)), run.frames.last().action, "Das Wandfeld, gegen das Byte fährt")
        assertEquals(ArenaAction.Start, run.frames.first().action)
        assertEquals(listOf(1, 2, 3, 3), run.frames.map { it.robot.x })

        val grab = ArenaEngine.run("robot.pickCoin();", corridor)
        assertEquals(ArenaAction.Crash(null), grab.runs[0].frames.last().action, "Ins Leere gegriffen: keine Wand")
    }

    @Test fun `Ziel, Muenzen und Ausgabe werden geprueft`() {
        val level = mission(listOf("######", "#Ro.G#", "######"), coins = true, output = "fertig")
        val lazy = ArenaEngine.run("robot.move();\nrobot.move();\nrobot.move();\nSystem.out.println(\"fertig\");", level)
        assertFalse(lazy.solved)
        assertTrue(lazy.runs[0].failures.any { "Münze" in it })

        assertFalse(ArenaEngine.run("robot.move();\nrobot.pickCoin();\nrobot.move();\nrobot.move();", level).solved)

        val good = ArenaEngine.run("robot.move();\nrobot.pickCoin();\nrobot.move();\nrobot.move();\nSystem.out.println(\"fertig\");", level)
        assertTrue(good.solved)
        assertEquals(2, good.stars, "Alle Münzen ja, aber mehr als 3 Zeilen")
        assertEquals("", good.runs[0].frames.last().output)
    }

    @Test fun `Hilfreiche Meldungen bei Tippfehlern im Roboter-Befehl`() {
        val level = mission(listOf("####", "#RG#", "####"))
        assertTrue(ArenaEngine.run("robot.Move();", level).runs[0].problem?.message?.contains("robot.move()") == true)
        assertTrue(ArenaEngine.run("move();", level).runs[0].problem?.message?.contains("robot.move()") == true)
    }

    @Test fun `Ein Roboter, der im Kreis faehrt, wird gestoppt`() {
        val result = ArenaEngine.run("while (true) {\n  robot.turnLeft();\n}", mission(listOf("#####", "#R..#", "#..G#", "#####")))
        assertEquals(JavaProblem.Kind.STEP_LIMIT, result.runs[0].problem?.kind)
    }

    @Test fun `Eine Schleife ohne robot-move zeigt nur wenige Fragen`() {
        val run = ArenaEngine.run("while (!robot.atGoal()) {\n}", mission(listOf("######", "#R..G#", "######"))).runs[0]
        assertEquals(JavaProblem.Kind.STEP_LIMIT, run.problem?.kind)
        assertEquals(1 + ArenaSimulation.SHOWN_QUESTIONS_IN_A_ROW, run.frames.size)
    }

    @Test fun `Sterne nennen, was der Code geschafft hat`() {
        val level = mission(listOf("######", "#Ro.G#", "######"))
        val unsolved = ArenaEngine.run("robot.move();\nrobot.move();\nrobot.move();\nrobot.move();", level)
        assertFalse(unsolved.solved)
        assertTrue(unsolved.criteria.all { it.progress == null }, "Ohne Lösung keine Messwerte")

        val solved = ArenaEngine.run("robot.move();\nrobot.move();\nrobot.move();", level)
        val coins = solved.criteria.first { it.criterion == StarCriterion.AllCoins }
        val lines = solved.criteria.first { it.criterion == StarCriterion.MaxLines(3) }
        assertTrue(!coins.met && coins.progress == "1 Münze liegt noch")
        assertTrue(lines.met && lines.progress == "du: 3 Zeilen")
    }

    @Test fun `Wiedergabe - Fragen sind kuerzer, lange Fahrten werden gestaucht`() {
        val short = assertNotNull(catalog.mission("a01-erste-schritte"))
        val quick = ArenaEngine.run(short.solution.source, short).runs[0].frames
        assertEquals(listOf(0.0) + List(quick.size - 1) { 0.4 }, ArenaPlayback.delays(quick, 0.4))
        for (mission in catalog.missions) {
            for (run in ArenaEngine.run(mission.solution.source, mission).runs) {
                val delays = ArenaPlayback.delays(run.frames, 0.38)
                assertTrue(delays.sum() <= 0.38 * ArenaPlayback.MAX_STEPS + 0.001, "${mission.id}: zu lang")
                run.frames.zip(delays).drop(1).forEach { (frame, delay) ->
                    if (frame.action is ArenaAction.Look) assertTrue(delay < 0.38)
                }
            }
        }
    }

    @Test fun `Befehle landen an der Stelle, an der man schreibt`() {
        val loop = "while (!robot.atGoal()) {\n    // Was soll in jeder Runde passieren?\n}"
        val first = CodeInsertion.insert("robot.move();", loop, null)
        assertEquals("while (!robot.atGoal()) {\n    // Was soll in jeder Runde passieren?\n    robot.move();\n}", first.first)
        val second = CodeInsertion.insert("robot.pickCoin();", first.first, first.second)
        assertTrue(second.first.endsWith("    robot.move();\n    robot.pickCoin();\n}"))
        val template = CodeInsertion.insert("if (robot.onCoin()) {\n    robot.pickCoin();\n}", loop, null)
        assertTrue("\n    if (robot.onCoin()) {\n        robot.pickCoin();\n    }\n}" in template.first)
        assertEquals("while (true) {\n    robot.move();\n}", CodeInsertion.insert("robot.move();", "while (true) {\n}", 14).first)
        assertEquals("robot.turnLeft();\nrobot.move();\nrobot.pickCoin();", CodeInsertion.insert("robot.move();", "robot.turnLeft();\nrobot.pickCoin();", 18).first)
        assertEquals("int a = 0;\nrobot.move();\nrobot.turnLeft();", CodeInsertion.insert("robot.move();", "int a = 0;\n\nrobot.turnLeft();", 11).first)
        assertEquals("// Start\nrobot.move();\nrobot.move();\n", CodeInsertion.insert("robot.move();", "// Start\nrobot.move();\n", null).first)
        assertEquals("robot.move();", CodeInsertion.insert("robot.move();", "", null).first)
    }

    @Test fun `Codezeilen zaehlen nur echte Anweisungen`() {
        assertEquals(2, ArenaEngine.codeLineCount("// Kommentar\nrobot.move();\n\n}\n  }\nrobot.move(); // weiter"))
    }

    // Nur Bekanntes – und ein klarer Auftrag

    @Test fun `Missionen stehen in Kursreihenfolge`() {
        val indices = catalog.missions.map(::lessonIndex)
        assertEquals(indices.sorted(), indices, catalog.missions.map { it.lessonId }.toString())
    }

    @Test fun `Jede Mission sagt in Schritten, was zu tun ist, und nennt ihre Bausteine`() {
        for (mission in catalog.missions) {
            assertTrue(mission.steps.size >= 2, "${mission.id}: Schritte fehlen")
            assertTrue(mission.goals.isNotEmpty(), "${mission.id}: kein Auftrag")
            assertTrue(mission.conceptIds.isNotEmpty(), "${mission.id}: keine Bausteine")
            for (id in mission.conceptIds) {
                val concept = catalog.concept(id) ?: fail("${mission.id}: Baustein $id fehlt im Katalog")
                val taughtIn = concept.lessonId ?: continue
                val taught = lessonOrder.indexOf(taughtIn)
                assertTrue(taught >= 0, "$id: Lektion $taughtIn gibt es nicht")
                assertTrue(taught <= lessonIndex(mission), "${mission.id} braucht $id aus $taughtIn")
            }
        }
        assertEquals(catalog.concepts.size, catalog.concepts.map { it.id }.toSet().size, "Baustein-IDs doppelt")
    }

    @Test fun `Loesung und Startcode brauchen nur Befehle, die Byte schon kann`() {
        val names = RobotCommand.all.map { it.name }.toSet()
        for (mission in catalog.missions) {
            assertTrue(names.containsAll(mission.newCommands), "${mission.id}: unbekannter neuer Befehl")
            assertTrue(mission.commandNames.containsAll(mission.newCommands), mission.id)
            for (snippet in listOf(mission.starterCode, mission.solution.source)) {
                for (match in Regex("""robot\.(\w+)\s*\(""").findAll(JavaSource.maskingLiterals(snippet))) {
                    val name = match.groupValues[1]
                    assertTrue(name in mission.commandNames, "${mission.id} nutzt robot.$name(), das erst später eingeführt wird")
                }
            }
        }
        assertEquals(listOf("move", "pickCoin"), catalog.mission("a01-erste-schritte")?.commandNames)
    }

    @Test fun `Die Befehlsleiste bietet nur an, was schon erklaert ist`() {
        fun templates(id: String) = catalog.templates(assertNotNull(catalog.mission(id)), lessonOrder).map { it.name }
        assertEquals(emptyList(), templates("a01-erste-schritte"))
        assertEquals(emptyList(), templates("b1-tunnelschatz"))
        assertEquals(listOf("if"), templates("a04-die-weiche"))
        assertEquals(listOf("if", "while", "for"), templates("a05-langer-gang"))
        assertFalse("Methode" in templates("t2-zickzack"), "Methoden kommen erst in Lektion 6")
        assertTrue("Methode" in templates("a06-die-treppe"))
    }

    @Test fun `Neues ist markiert - Bekanntes nicht`() {
        val gang = assertNotNull(catalog.mission("a05-langer-gang"))
        assertEquals(true, catalog.conceptUses(gang).firstOrNull { it.concept.id == "nicht" }?.isNew)
        assertEquals(false, catalog.conceptUses(gang).firstOrNull { it.concept.id == "while" }?.isNew, "while kommt aus Lektion 5")
        val huerden = assertNotNull(catalog.mission("t3-huerdenlauf"))
        assertEquals(false, catalog.conceptUses(huerden).firstOrNull { it.concept.id == "nicht" }?.isNew, "schon im endlosen Gang erklärt")
    }

    @Test fun `Der Auftrag nennt Ziel, Ausgabe, Pflicht und Welten`() {
        val first = assertNotNull(catalog.mission("a01-erste-schritte"))
        assertEquals(listOf(ArenaGoal.Kind.REACH_GOAL, ArenaGoal.Kind.OUTPUT), first.goals.map { it.kind })
        assertEquals(listOf(ArenaGoal.ExpectedOutput(null, "Angekommen!")), first.goals[1].outputs)

        val knacker = assertNotNull(catalog.mission("b3-codeknacker"))
        assertEquals(listOf(1, 2), knacker.goals.first { it.kind == ArenaGoal.Kind.OUTPUT }.outputs.map { it.world })

        val weiche = assertNotNull(catalog.mission("a04-die-weiche"))
        assertEquals(
            listOf(ArenaGoal.Kind.REACH_GOAL, ArenaGoal.Kind.COLLECT_COINS, ArenaGoal.Kind.RULE, ArenaGoal.Kind.ALL_WORLDS),
            weiche.goals.map { it.kind },
        )
    }
}
