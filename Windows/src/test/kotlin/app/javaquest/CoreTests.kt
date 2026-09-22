package app.javaquest

import app.javaquest.core.AnswerEvaluator
import app.javaquest.core.Blank
import app.javaquest.core.CodeRule
import app.javaquest.core.CodeSnippet
import app.javaquest.core.CourseLoader
import app.javaquest.core.Difficulty
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.FindingKind
import app.javaquest.core.JavaContext
import app.javaquest.core.JavaHighlighter
import app.javaquest.core.JavaSource
import app.javaquest.core.KnowledgeAnalyzer
import app.javaquest.core.LearningPath
import app.javaquest.core.LearningTask
import app.javaquest.core.LessonResult
import app.javaquest.core.LessonSession
import app.javaquest.core.LessonState
import app.javaquest.core.LessonSummary
import app.javaquest.core.TaskOutcome
import app.javaquest.core.MasterRank
import app.javaquest.core.MasterScore
import app.javaquest.core.PlacementTest
import app.javaquest.core.PracticeBuilder
import app.javaquest.core.RuleKind
import app.javaquest.core.RuleScope
import app.javaquest.core.Stars
import app.javaquest.core.StructureCheck
import app.javaquest.core.TaskHistory
import app.javaquest.core.TaskAnswer
import app.javaquest.core.TaskKind
import app.javaquest.core.TopicStats
import app.javaquest.core.TopicStatus
import app.javaquest.core.TrainingBuilder
import app.javaquest.core.UmlLayout
import app.javaquest.core.UmlRelationKind
import app.javaquest.core.VariantSelector
import java.time.Instant
import kotlin.math.abs
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private val course by lazy { CourseLoader.loadBundled() }

class JavaSourceTest {
    @Test fun `Kommentare werden entfernt, Strings bleiben erhalten`() {
        val source = "int a = 1; // Kommentar\n/* Block\n   über zwei Zeilen */ int b = 2;\nString s = \"// kein Kommentar\";"
        val stripped = JavaSource.strippingComments(source)
        assertFalse("Kommentar\n" in stripped)
        assertFalse("Block" in stripped)
        assertTrue("\"// kein Kommentar\"" in stripped)
        assertEquals(4, stripped.split("\n").size, "Zeilennummern müssen erhalten bleiben")
    }

    @Test fun `Literale werden maskiert, Escapes beruecksichtigt`() {
        assertEquals("""String s = ""; char c = '';""", JavaSource.maskingLiterals("""String s = "for (;;) \" {"; char c = '{';"""))
    }

    @Test fun `Klammerfehler werden mit Zeile gemeldet`() {
        assertTrue(JavaSource.delimiterIssues("if (a) { b(); }").isEmpty())
        assertEquals(1, JavaSource.delimiterIssues("if (a) {\n  b();\n").first().line)
        assertEquals(1, JavaSource.delimiterIssues("foo(]").first().line)
        assertTrue("nie geöffnet" in JavaSource.delimiterIssues("}\n").first().message)
    }

    @Test fun `Fehlende Semikolons werden erkannt`() {
        assertEquals(listOf(1, 2, 3), JavaSource.linesMissingSemicolon("int x = 5\nx++\nSystem.out.println(x)\nreturn x;"))
    }

    @Test fun `Korrekter Code erzeugt keine Semikolon-Fehlalarme`() {
        val code = """
            @Override
            public static void main(String[] args)
            {
                for (int i = 0; i < 3; i++)
                    System.out.println(i);
                List<Integer> r = list.stream()
                        .filter(n -> n > 2)
                        .toList();
                String t = switch (n) {
                    case 1 -> "eins";
                    default -> {
                        yield "viele";
                    }
                };
                if (a &&
                    b) {
                } else if (c) {
                }
                class Box<T>
                {
                }
                label:
                do {
                } while (x);
            }
        """.trimIndent()
        assertTrue(JavaSource.linesMissingSemicolon(JavaSource.maskingLiterals(code)).isEmpty())
    }

    @Test fun `Typografische Anfuehrungszeichen werden zu ASCII`() {
        assertEquals("System.out.println(\"Hi\");", JavaSource.normalizingTypography("System.out.println(„Hi“);"))
        assertEquals("i--;", JavaSource.normalizingTypography("i—;"))
    }

    @Test fun `Syntaxhervorhebung erkennt Schluesselwoerter, Strings und Kommentare`() {
        val tokens = JavaHighlighter.tokenize("int x = 5; // Zahl\nString s = \"hi\";")
        assertTrue(tokens.any { it.kind == JavaHighlighter.Kind.KEYWORD && it.text == "int" })
        assertTrue(tokens.any { it.kind == JavaHighlighter.Kind.COMMENT && it.text == "// Zahl" })
        assertTrue(tokens.any { it.kind == JavaHighlighter.Kind.STRING && it.text == "\"hi\"" })
        assertTrue(tokens.any { it.kind == JavaHighlighter.Kind.TYPE && it.text == "String" })
        assertEquals("int x = 5; // Zahl\nString s = \"hi\";", tokens.joinToString("") { it.text })
    }
}

class EvaluatorTest {
    private fun task(kind: TaskKind) = LearningTask("t", "x", Difficulty.MEDIUM, "", null, null, "", JavaContext.STATEMENTS, kind)
    private fun code(vararg rules: CodeRule) =
        task(TaskKind.Code(CodeSnippet.of(""), CodeSnippet.of(""), null, rules.toList(), StructureCheck.entries))

    @Test fun `Lueckentext ignoriert Leerzeichen und ein ueberzaehliges Semikolon`() {
        val t = task(TaskKind.FillBlank(CodeSnippet.of("x{{0}}"), listOf(Blank(listOf("+= 1")))))
        assertTrue(AnswerEvaluator.evaluate(TaskAnswer.Blanks(listOf("+=1")), t).isCorrect)
        assertTrue(AnswerEvaluator.evaluate(TaskAnswer.Blanks(listOf(" += 1; ")), t).isCorrect)
        assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Blanks(listOf("-= 1")), t).isCorrect)
    }

    @Test fun `Gross- und Kleinschreibung zaehlt standardmaessig`() {
        val strict = task(TaskKind.FillBlank(CodeSnippet.of("{{0}}"), listOf(Blank(listOf("println")))))
        assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Blanks(listOf("PrintLn")), strict).isCorrect)
        val loose = task(TaskKind.FillBlank(CodeSnippet.of("{{0}}"), listOf(Blank(listOf("println"), caseSensitive = false))))
        assertTrue(AnswerEvaluator.evaluate(TaskAnswer.Blanks(listOf("PrintLn")), loose).isCorrect)
    }

    @Test fun `Teilpunkte beim Lueckentext`() {
        val t = task(TaskKind.FillBlank(CodeSnippet.of("{{0}} {{1}}"), listOf(Blank(listOf("a")), Blank(listOf("b")))))
        val result = AnswerEvaluator.evaluate(TaskAnswer.Blanks(listOf("a", "c")), t)
        assertFalse(result.isCorrect)
        assertEquals(0.5, result.score)
    }

    @Test fun `Ausgabe - Leerzeichen am Zeilenende und Leerzeilen am Rand sind egal`() {
        val t = task(TaskKind.PredictOutput("1 2 3\nfertig"))
        assertTrue(AnswerEvaluator.evaluate(TaskAnswer.Text("\n1 2 3   \r\nfertig\n\n"), t).isCorrect)
        val wrong = AnswerEvaluator.evaluate(TaskAnswer.Text("1 2 3\nFertig"), t)
        assertFalse(wrong.isCorrect)
        assertEquals(0.5, wrong.score)
        assertTrue(wrong.findings.any { it.kind == FindingKind.HINT && "Groß" in it.message })
    }

    @Test fun `Code - Regeln, Kommentare und Strings zaehlen nicht`() {
        val t = code(
            CodeRule(RuleKind.REQUIRE, """\bfor\s*\(""", "Schleife"),
            CodeRule(RuleKind.FORBID, "5050", "nicht hart codieren"),
        )
        assertTrue(AnswerEvaluator.evaluate(TaskAnswer.Text("for (int i = 0; i < 3; i++) { s += i; }"), t).isCorrect)
        assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Text("// for (\nint s = 1;"), t).isCorrect)
        assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Text("String s = \"for (\";"), t).isCorrect)
        val cheated = AnswerEvaluator.evaluate(TaskAnswer.Text("for (;;) { break; }\nSystem.out.println(5050);"), t)
        assertFalse(cheated.isCorrect)
        assertEquals(0.5, cheated.score)
    }

    @Test fun `Code - Strukturfehler verhindern eine richtige Wertung`() {
        val t = code(CodeRule(RuleKind.REQUIRE, "println", "Ausgabe"))
        val result = AnswerEvaluator.evaluate(TaskAnswer.Text("System.out.println(\"x\")"), t)
        assertFalse(result.isCorrect)
        assertEquals(1, result.findings.first().line)
        assertTrue(AnswerEvaluator.evaluate(TaskAnswer.Text("System.out.println(\"x\");"), t).isCorrect)
    }

    @Test fun `Code mit Smart Quotes wird akzeptiert`() {
        val t = code(CodeRule(RuleKind.REQUIRE, "\"Hallo\"", "Text", RuleScope.RAW))
        assertTrue(AnswerEvaluator.evaluate(TaskAnswer.Text("System.out.println(“Hallo”);"), t).isCorrect)
    }

    @Test fun `Falsche Antwortform wird sauber abgelehnt`() {
        assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Text("a"), task(TaskKind.SingleChoice(listOf("a", "b"), 0))).isCorrect)
    }
}

class CourseContentTest {
    @Test fun `Kurs laedt - 13 Module, 32 Lektionen, 160 Aufgaben plus Uebungspool`() {
        assertEquals(13, course.modules.size)
        assertEquals(32, course.allLessons.size)
        assertEquals(160, course.allLessons.sumOf { it.tasks.size })
        // Der Übungspool speist Übung, Training und freies Lernen.
        assertTrue(course.taskPool.size >= 50, "nur ${course.taskPool.size} Übungsaufgaben")
        assertEquals(course.allLessons.sumOf { it.tasks.size } + course.taskPool.size, course.practiceableTasks.size)
        assertEquals(1, course.placement.pool(ExperienceLevel.INTERMEDIATE).size)
        assertEquals("m1-first-steps", course.entryModule(ExperienceLevel.BEGINNER)?.id)
        assertEquals("m3-objects", course.entryModule(ExperienceLevel.INTERMEDIATE)?.id)
    }

    @Test fun `Jede Codezeile im Kurs hat eine Erklaerung`() {
        val snippets = course.allSnippets
        assertEquals(465, snippets.size)
        var lines = 0
        for ((location, snippet) in snippets) {
            assertTrue(snippet.linesMissingExplanation.isEmpty(), "$location: Zeilen ${snippet.linesMissingExplanation}")
            lines += snippet.explained(course.glossary).size
        }
        assertTrue(lines >= 2840, "nur $lines erklärte Zeilen")
    }

    @Test fun `Jeder Befehl einer Zeile steht im Lexikon`() {
        assertTrue(course.glossary.size >= 100)
        for ((location, snippet) in course.allSnippets) {
            for (line in snippet.lines) {
                for (term in line.terms) assertNotNull(course.glossary[term], "$location: „$term“ fehlt im Lexikon")
            }
        }
        val first = course.lesson("l02-variables")!!.theory[0].example!!.explained(course.glossary)[0]
        assertEquals("int alter = 25;", first.code)
        assertTrue(first.explanation.startsWith("Hier erstellen wir eine Box namens „alter“ und legen die Zahl 25 hinein."), first.explanation)
        assertEquals(listOf("int", "="), first.terms.map { it.term })
    }

    @Test fun `Musterloesung jeder Aufgabe wird akzeptiert`() {
        for (task in course.allTasks) {
            val result = AnswerEvaluator.evaluate(AnswerEvaluator.referenceAnswer(task), task)
            assertTrue(result.isCorrect, "${task.id}: ${result.findings.map { it.message }}")
            assertEquals(1.0, result.score, "${task.id}")
        }
    }

    @Test fun `Falsche Antworten werden abgelehnt`() {
        for (task in course.allTasks) {
            when (val kind = task.kind) {
                is TaskKind.SingleChoice -> kind.choices.indices.filter { it != kind.correctIndex }.forEach {
                    assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Choice(it), task).isCorrect, "${task.id} Option $it")
                }
                is TaskKind.FillBlank -> {
                    assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Blanks(kind.blanks.map { "" }), task).isCorrect)
                    assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Blanks(kind.blanks.map { "xyz" }), task).isCorrect)
                }
                is TaskKind.PredictOutput -> {
                    assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Text(""), task).isCorrect)
                    assertFalse(AnswerEvaluator.evaluate(TaskAnswer.Text(kind.expectedOutput + "\nx"), task).isCorrect)
                }
                is TaskKind.Code -> assertFalse(
                    AnswerEvaluator.evaluate(TaskAnswer.Text(kind.starter.source), task).isCorrect,
                    "${task.id}: Startercode gilt schon als Lösung",
                )
            }
        }
    }

    @Test fun `Lueckenzeilen und geloeste Vorlage`() {
        val kind = course.placement.pool(ExperienceLevel.INTERMEDIATE).first().kind as TaskKind.FillBlank
        assertEquals(6, kind.blanks.size)
        assertTrue(kind.blankLineNumbers.isNotEmpty())
        assertFalse("{{" in kind.solvedSnippet.source)
        // Nach dem Lösen erklärt das Lexikon auch die eingesetzten Befehle.
        val solvedTerms = kind.solvedSnippet.explained(course.glossary).flatMap { it.terms.map { t -> t.term } }.toSet()
        assertTrue(solvedTerms.containsAll(listOf("int", "for", "++", "if", "println()")), "$solvedTerms")
        // Befehle einer Lückenzeile verraten die Lösung nicht.
        // Ein Begriff darf nur auftauchen, wenn er ohnehin sichtbar in der Zeile steht (z. B. „int x“).
        for (number in kind.blankLineNumbers) {
            val line = kind.template.lines[number - 1]
            val visible = line.code.replace(Regex("""\{\{\d+}}"""), " ")
            for (blank in kind.blanks) {
                val answer = blank.accepted.first()
                if (answer in line.terms) assertTrue(Regex("""\b${Regex.escape(answer)}\b""").containsMatchIn(visible), "Zeile $number verrät $answer")
            }
        }
    }
}

class ProgressTest {
    private fun runPlacement(correctBlanks: Int): PlacementTest {
        val test = PlacementTest.create(course, ExperienceLevel.INTERMEDIATE)!!
        val task = test.currentTask!!
        val kind = task.kind as TaskKind.FillBlank
        val answers = kind.blanks.mapIndexed { i, blank -> if (i < correctBlanks) blank.accepted.first() else "falsch" }
        test.submit(AnswerEvaluator.evaluate(TaskAnswer.Blanks(answers), task))
        return test
    }

    @Test fun `Nur Vorkenntnisse fuehren zur Einstufungsfrage`() {
        assertEquals(listOf(ExperienceLevel.BEGINNER, ExperienceLevel.INTERMEDIATE), ExperienceLevel.onboardingChoices)
        assertNull(PlacementTest.create(course, ExperienceLevel.BEGINNER))
        val test = PlacementTest.create(course, ExperienceLevel.INTERMEDIATE)!!
        assertEquals(1, test.questionCount)
        assertEquals(65, test.passThreshold)
    }

    @Test fun `Einstufung - alles richtig, alles falsch, Teilpunkte`() {
        val all = runPlacement(6)
        assertTrue(all.isFinished)
        assertEquals(100, all.scorePercent)
        val outcome = all.outcome(course)
        assertEquals("m3-objects", outcome.entryModuleId)
        assertEquals(6, outcome.creditedLessonIds.size)
        assertEquals(1.0, outcome.creditedAccuracy)

        val none = runPlacement(0).outcome(course)
        assertEquals(0, none.scorePercent)
        assertEquals(ExperienceLevel.BEGINNER, none.placedLevel)
        assertTrue(none.creditedLessonIds.isEmpty())

        assertEquals(67, runPlacement(4).scorePercent)
        assertTrue(runPlacement(4).passed)
        assertEquals(50, runPlacement(3).scorePercent)
        assertFalse(runPlacement(3).passed)
    }

    @Test fun `Lern-Loop - Theorie, Aufgaben, Auswertung`() {
        val lesson = course.allLessons[0]
        val session = LessonSession.of(lesson)
        assertEquals(LessonSession.Phase.Theory(0), session.phase)
        repeat(lesson.theory.size) { session.advanceTheory() }
        assertEquals(LessonSession.Phase.Task(0), session.phase)
        while (true) {
            val task = session.currentTask ?: break
            session.submit(AnswerEvaluator.referenceAnswer(task))
            assertEquals(1.0, session.finishedOutcome?.credit)
            session.advanceToNextTask()
        }
        assertEquals(LessonSession.Phase.Summary, session.phase)
        assertEquals(1.0, session.summary.accuracy)
        assertEquals(3, session.summary.stars)
        assertTrue(session.summary.passed)
    }

    @Test fun `Bestehensgrenze 69 Prozent - 68 faellt durch, 69 und 70 bestehen`() {
        assertEquals(0.69, LessonSession.PASS_THRESHOLD)
        assertEquals(69, LessonSession.passPercent)

        // Die geforderten Grenzfälle, direkt an der Auswertung einer Lektion.
        val task = course.allLessons[0].tasks[0]
        fun summaryWith(accuracy: Double) =
            LessonSummary(listOf(TaskOutcome(task, 1, true, accuracy)), 1)
        assertFalse(summaryWith(0.68).passed, "68 % ist nicht bestanden")
        assertTrue(summaryWith(0.69).passed, "69 % ist bestanden")
        assertTrue(summaryWith(0.70).passed, "70 % ist bestanden")

        // Sterne: ab der Grenze einer, auf halbem Weg zur Fehlerfreiheit zwei, fehlerfrei drei.
        assertEquals(0, Stars.forAccuracy(0.68))
        assertEquals(1, Stars.forAccuracy(0.69))
        assertEquals(1, Stars.forAccuracy(0.84))
        assertEquals(0.845, Stars.twoStarThreshold)
        assertEquals(2, Stars.forAccuracy(0.845))
        assertEquals(3, Stars.forAccuracy(1.0))

        // Lektion 1 (Niveaus 1,1,2,2,3): die schwerste Aufgabe erst im 2. Versuch → 7,5/9 = 83 %.
        val lesson = course.allLessons[0]
        val session = LessonSession(LessonSession.Mode.Lesson(lesson.id), "", emptyList(), lesson.tasks)
        var index = 0
        while (true) {
            val task = session.currentTask ?: break
            if (index == lesson.tasks.lastIndex) {
                session.submit(TaskAnswer.Choice(99))
                session.prepareRetry()
            }
            session.submit(AnswerEvaluator.referenceAnswer(task))
            session.advanceToNextTask()
            index++
        }
        assertTrue(abs(session.summary.accuracy - 7.5 / 9) < 1e-9)
        assertTrue(session.summary.passed, "83 % liegen über der Grenze von 69 %")
    }

    @Test fun `Zweiter Versuch halb, Loesung zeigen null, maximal drei Versuche`() {
        val lesson = course.allLessons[1]
        val session = LessonSession(LessonSession.Mode.Lesson(lesson.id), "", emptyList(), lesson.tasks.take(2))
        val first = session.currentTask!!
        session.submit(TaskAnswer.Choice(99))
        assertTrue(session.canRetry)
        session.prepareRetry()
        session.submit(AnswerEvaluator.referenceAnswer(first))
        assertEquals(0.5, session.finishedOutcome?.credit)
        session.advanceToNextTask()
        session.submit(TaskAnswer.Blanks(listOf("falsch")))
        session.revealSolution()
        assertEquals(0.0, session.finishedOutcome?.credit)

        val limited = LessonSession(LessonSession.Mode.Practice("x"), "", emptyList(), listOf(course.allLessons[0].tasks[0]))
        repeat(LessonSession.MAX_ATTEMPTS) { limited.submit(TaskAnswer.Choice(99)); limited.prepareRetry() }
        assertFalse(limited.canRetry)
        assertNull(limited.submit(TaskAnswer.Choice(0)))
    }

    @Test fun `Master Score, Raenge und Lernpfad`() {
        assertEquals(0, MasterScore.compute(course, emptyMap()))
        assertEquals(1000, MasterScore.compute(course, course.allLessons.associate { it.id to LessonResult(1.0, true) }))
        val results = mutableMapOf<String, LessonResult>()
        var previous = 0
        for (lesson in course.allLessons) {
            results[lesson.id] = LessonResult(0.95, true)
            val score = MasterScore.compute(course, results)
            assertTrue(score > previous, lesson.id)
            previous = score
        }
        assertEquals("Neuling", MasterRank.rank(0).title)
        assertEquals("Java Master", MasterRank.rank(1000).title)
        assertEquals(0.5, MasterRank.progressToNext(75))

        val lessons = course.allLessons
        val placed = lessons.take(6).associate { it.id to LessonResult(0.95, true, viaPlacement = true) }
        val states = LearningPath.states(course, placed)
        assertEquals(LessonState.Completed(2, true), states[lessons[5].id])
        assertEquals(LessonState.Current, states[lessons[6].id])
        assertEquals(LessonState.Locked, states[lessons[7].id])
    }

    @Test fun `Wissensanalyse und Uebungen`() {
        val now = Instant.now()
        val gap = TopicStats().recording(Difficulty.MEDIUM, 0.0, now).recording(Difficulty.HARD, 0.5, now)
        var strength = TopicStats()
        listOf(Difficulty.EASY, Difficulty.MEDIUM, Difficulty.DEMANDING, Difficulty.HARD).forEach { strength = strength.recording(it, 1.0, now) }
        assertEquals(TopicStatus.UNKNOWN, KnowledgeAnalyzer.classify(TopicStats()))
        assertEquals(TopicStatus.GAP, KnowledgeAnalyzer.classify(gap))
        assertEquals(TopicStatus.STRENGTH, KnowledgeAnalyzer.classify(strength))
        assertEquals(TopicStatus.DEVELOPING, KnowledgeAnalyzer.classify(TopicStats().recording(Difficulty.HARD, 0.0, now)))
        val report = KnowledgeAnalyzer.report(course, mapOf("loops" to gap, "variables" to strength))
        assertEquals("loops", report.focusTopic?.topic?.id)
        assertEquals("l05-loops", report.gaps.first().lessonId)

        val unlocked = course.allLessons.take(7).map { it.id }.toSet()
        val tasks = PracticeBuilder.tasks("loops", course, unlocked)
        assertTrue(tasks.isNotEmpty() && tasks.size <= 5 && tasks.all { it.topicId == "loops" })
        assertTrue(PracticeBuilder.tasks("lambdas", course, unlocked).isEmpty())
    }

    @Test fun `Varianten - eine je Lernziel, nach einem Fehler eine andere`() {
        val group = course.practiceableTasks.filter { it.groupKey == "t03-1" }
        assertTrue(group.size >= 2, "Lernziel t03-1 hat Varianten: ${group.map { it.id }}")

        val collapsed = VariantSelector.collapse(group, emptyMap())
        assertEquals(1, collapsed.size)

        val wrong = collapsed.first()
        val history = mapOf(wrong.id to TaskHistory(1, 0.0, Instant.now()))
        assertTrue(VariantSelector.pick(group, history)?.id != wrong.id, "Nach einem Fehler nicht dieselbe Frage")

        // Auch wenn alle dran waren: nicht die zuletzt gezeigte.
        val seen = group.mapIndexed { index, task ->
            task.id to TaskHistory(1, 1.0, Instant.now().plusSeconds(index * 60L))
        }.toMap()
        assertTrue(VariantSelector.pick(group, seen)?.id != group.last().id)
    }

    @Test fun `Jedes Lernziel hat mindestens zwei Varianten`() {
        val ohneVariante = VariantSelector.groups(course.practiceableTasks)
            .filter { it.second.size < 2 }
            .map { it.first }
        assertTrue(ohneVariante.isEmpty(), "Lernziele mit nur einer Aufgabe: ${ohneVariante.sorted()}")
    }

    @Test fun `Eine Runde zeigt kein Lernziel doppelt`() {
        val completed = course.allLessons.take(6).map { it.id }.toSet()
        val round = TrainingBuilder.round(TrainingBuilder.pool(course, completed), emptyMap(), emptyMap(), random = Random(7))
        val goals = round.map { it.groupKey }
        assertEquals(goals.size, goals.toSet().size, "jedes Lernziel höchstens einmal je Runde")
    }

    @Test fun `Freies Training - eigene Themen und Niveaus, ohne Lernpfad-Sperre`() {
        val tasks = TrainingBuilder.freeRound(course, setOf("lambdas"), count = 5, random = Random(3))
        assertTrue(tasks.isNotEmpty())
        assertTrue(tasks.all { it.topicId == "lambdas" })
        assertTrue(tasks.size <= 5)

        val mixed = TrainingBuilder.freeRound(
            course, setOf("loops", "conditionals"), setOf(Difficulty.EASY), 10, random = Random(4),
        )
        assertTrue(mixed.isNotEmpty())
        assertTrue(mixed.all { it.difficulty == Difficulty.EASY })

        assertEquals(course.practiceableTasks.size, TrainingBuilder.freePool(course, emptySet()).size)
    }

    @Test fun `Jedes Thema ist frei waehlbar`() {
        for (topic in course.practiceableTopics) {
            val tasks = TrainingBuilder.freeRound(course, setOf(topic.id), count = 3, random = Random(11))
            assertTrue(tasks.isNotEmpty(), "Thema „${topic.title}“ hat keine übbare Aufgabe")
        }
    }

    @Test fun `UML-Diagramme werden geladen und angeordnet`() {
        val umlTasks = course.practiceableTasks.filter { it.diagram != null }
        assertTrue(umlTasks.size >= 10, "nur ${umlTasks.size} Aufgaben mit Diagramm")

        val diagram = course.lesson("l31-uml-relations")!!.theory.first { it.diagram != null }.diagram!!
        assertTrue(diagram.classes.isNotEmpty() && diagram.relations.isNotEmpty())

        // Vererbung: Die Eltern-Klasse steht oben, das Kind darunter.
        val inheritance = course.practiceableTasks.first { task ->
            task.diagram?.relations?.any { it.kind == UmlRelationKind.EXTENDS } == true
        }.diagram!!
        val relation = inheritance.relations.first { it.kind == UmlRelationKind.EXTENDS }
        val layout = UmlLayout.compute(inheritance)
        val child = layout.placed(relation.from)!!
        val parent = layout.placed(relation.to)!!
        assertTrue(parent.y < child.y, "Eltern-Klasse gehört über die Kind-Klasse")
        assertTrue(layout.width > 0 && layout.height > 0)
    }

    @Test fun `Endlos-Training - nur Abgeschlossenes, 8 verschiedene Aufgaben, aufsteigend`() {
        assertTrue(TrainingBuilder.pool(course, emptySet()).isEmpty())
        val completed = course.allLessons.take(4).map { it.id }.toSet()
        val pool = TrainingBuilder.pool(course, completed)
        val lessonTasks = course.allLessons.take(4).flatMap { it.tasks }
        val learnedTopics = lessonTasks.map { it.topicId }.toSet()
        // Abgeschlossene Lektionen plus Übungsaufgaben zu genau deren Themen.
        val allowed = lessonTasks.map { it.id }.toSet() +
            course.taskPool.filter { it.topicId in learnedTopics }.map { it.id }.toSet()
        assertEquals(allowed, pool.map { it.id }.toSet())
        assertTrue(pool.size > lessonTasks.size, "Der Pool erweitert das Training")

        val round = TrainingBuilder.round(pool, emptyMap(), emptyMap(), random = Random(42))
        assertEquals(TrainingBuilder.ROUND_SIZE, round.size)
        assertEquals(round.size, round.map { it.id }.toSet().size, "keine Aufgabe doppelt")
        assertTrue(round.all { it.id in allowed })
        assertEquals(round.map { it.difficulty.level }.sorted(), round.map { it.difficulty.level })
        assertEquals(round.map { it.id }, TrainingBuilder.round(pool, emptyMap(), emptyMap(), random = Random(42)).map { it.id })
        val small = pool.take(3)
        assertEquals(small.map { it.id }.toSet(), TrainingBuilder.round(small, emptyMap(), emptyMap(), random = Random(1)).map { it.id }.toSet())
    }

    @Test fun `Endlos-Training - Fehler, Luecken und Vergessenes kommen oefter dran`() {
        val now = Instant.now()
        val task = course.allLessons[0].tasks[0]
        fun weight(history: TaskHistory?, stats: TopicStats? = null) = TrainingBuilder.weight(
            task,
            stats?.let { mapOf(task.topicId to it) } ?: emptyMap(),
            history?.let { mapOf(task.id to it) } ?: emptyMap(),
            now,
        )
        val solvedToday = TaskHistory(1, 1.0, now)
        val solvedLongAgo = TaskHistory(1, 1.0, now.minusSeconds(20 * 86_400))
        val failed = TaskHistory(1, 0.0, now.minusSeconds(2 * 86_400))
        val weak = TopicStats().recording(Difficulty.MEDIUM, 0.0, now).recording(Difficulty.MEDIUM, 0.0, now)
        var strong = TopicStats()
        repeat(4) { strong = strong.recording(Difficulty.MEDIUM, 1.0, now) }
        assertTrue(weight(null) > weight(solvedToday), "Neues vor gerade Gelöstem")
        assertTrue(weight(failed) > weight(solvedLongAgo), "Fehler vor Gelöstem")
        assertTrue(weight(solvedLongAgo) > weight(solvedToday), "lange nicht gesehen kommt wieder")
        assertTrue(weight(solvedLongAgo, weak) > weight(solvedLongAgo, strong), "schwaches Thema vor starkem")

        // Gemessen über viele Runden: Falsches kommt deutlich öfter als heute fehlerfrei Gelöstes.
        val pool = TrainingBuilder.pool(course, course.allLessons.take(6).map { it.id }.toSet())
        // Eine Aufgabe je Lernziel: Sonst würde die Variantenauswahl die gemessene Aufgabe
        // durch eine ungesehene Schwester ersetzen und die Messung verfälschen.
        val einzelne = VariantSelector.collapse(pool, emptyMap())
        val wrong = einzelne[0]
        val done = einzelne[1]
        val history = mapOf(
            wrong.id to TaskHistory(2, 0.0, now.minusSeconds(86_400)),
            done.id to TaskHistory(2, 1.0, now),
        )
        var wrongCount = 0
        var doneCount = 0
        for (seed in 1..400) {
            val ids = TrainingBuilder.round(einzelne, emptyMap(), history, now, random = Random(seed)).map { it.id }.toSet()
            if (wrong.id in ids) wrongCount++
            if (done.id in ids) doneCount++
        }
        assertTrue(wrongCount > doneCount * 3, "falsch: ${wrongCount}×, heute gelöst: ${doneCount}×")
    }
}
