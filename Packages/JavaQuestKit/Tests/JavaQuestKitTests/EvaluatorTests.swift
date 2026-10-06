import Testing
@testable import JavaQuestKit

@Suite("Java-Quelltextanalyse")
struct JavaSourceTests {
    @Test("Kommentare werden entfernt, Strings bleiben erhalten")
    func stripComments() {
        let source = """
        int a = 1; // Kommentar
        /* Block
           über zwei Zeilen */ int b = 2;
        String s = "// kein Kommentar";
        """
        let stripped = JavaSource.strippingComments(source)
        #expect(!stripped.contains("Kommentar\n"))
        #expect(!stripped.contains("Block"))
        #expect(stripped.contains("\"// kein Kommentar\""))
        #expect(stripped.components(separatedBy: "\n").count == 4, "Zeilennummern müssen erhalten bleiben")
    }

    @Test("Literale werden maskiert, Escapes berücksichtigt")
    func maskLiterals() {
        let masked = JavaSource.maskingLiterals(#"String s = "for (;;) \" {"; char c = '{';"#)
        #expect(masked == #"String s = ""; char c = '';"#)
    }

    @Test("Klammerfehler werden mit Zeile gemeldet")
    func delimiterIssues() {
        #expect(JavaSource.delimiterIssues(in: "if (a) { b(); }").isEmpty)
        #expect(JavaSource.delimiterIssues(in: "if (a) {\n  b();\n").first?.line == 1)
        #expect(JavaSource.delimiterIssues(in: "foo(]").first?.line == 1)
        #expect(JavaSource.delimiterIssues(in: "}\n").first?.message.contains("nie geöffnet") == true)
    }

    @Test("Fehlende Semikolons werden erkannt")
    func missingSemicolons() {
        let code = """
        int x = 5
        x++
        System.out.println(x)
        return x;
        """
        #expect(JavaSource.linesMissingSemicolon(in: code) == [1, 2, 3])
    }

    @Test("Korrekter Code erzeugt keine Semikolon-Fehlalarme")
    func noFalsePositives() {
        let code = """
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
        """
        #expect(JavaSource.linesMissingSemicolon(in: JavaSource.maskingLiterals(code)).isEmpty)
    }

    @Test("Typografische Anführungszeichen werden zu ASCII")
    func typography() {
        #expect(JavaSource.normalizingTypography("System.out.println(\u{201E}Hi\u{201C});") == "System.out.println(\"Hi\");")
        #expect(JavaSource.normalizingTypography("i\u{2014};") == "i--;")
    }
}

@Suite("Evaluator")
struct EvaluatorTests {
    let evaluator = AnswerEvaluator()

    @Test("Eine falsche Ausgabe wird begründet, nicht nur abgelehnt")
    func outputMistakesAreNamed() {
        typealias E = AnswerEvaluator
        // Zeile für Zeile
        #expect(E.warumZeileFalsch("hallo", erwartet: "Hallo").contains("Groß- und Kleinschreibung"))
        #expect(E.warumZeileFalsch("a b", erwartet: "ab").contains("Leerzeichen"))
        #expect(E.warumZeileFalsch("10", erwartet: "10.0").contains("Nachkommastelle"))
        #expect(E.warumZeileFalsch("1, 2", erwartet: "[1, 2]").contains("eckigen Klammern"))
        // Über die ganze Ausgabe – der print/println-Fehler darf nicht als Schreibweise
        // durchgehen: Dort ist der Text identisch, nur die Umbrüche fehlen.
        #expect(E.warumAusgabeFalsch(["ABC"], erwartet: ["A", "B", "C"])?.contains("einer Zeile") == true)
        #expect(E.warumAusgabeFalsch(["A", "B", "C"], erwartet: ["ABC"])?.contains("mehrere Zeilen") == true)
        #expect(E.warumAusgabeFalsch(["abc"], erwartet: ["ABC"])?.contains("Groß- und Kleinschreibung") == true)
        #expect(E.warumAusgabeFalsch(["a", "b", "c"], erwartet: ["a", "b"])?.contains("zu viel") == true)
        #expect(E.warumAusgabeFalsch(["a"], erwartet: ["a", "b"])?.contains("fehlen") == true)
    }

    @Test("Eine falsch gefüllte Lücke wird begründet")
    func blankMistakesAreNamed() {
        let println = FillBlankSpec.Blank(accepted: ["println"], caseSensitive: false)
        let elseBlank = FillBlankSpec.Blank(accepted: ["else"], caseSensitive: false)
        typealias E = AnswerEvaluator
        #expect(E.warumBlankFalsch("PRINTLN", blank: println, alle: [println], index: 0).contains("Groß- und Klein"))
        #expect(E.warumBlankFalsch("else", blank: println, alle: [println, elseBlank], index: 0).contains("Lücke 2"))
        #expect(E.warumBlankFalsch("print", blank: println, alle: [println], index: 0).contains("Anfang stimmt"))
    }

    func task(_ kind: TaskKind, difficulty: Difficulty = .medium) -> LearningTask {
        LearningTask(id: "t", topicId: "x", difficulty: difficulty, prompt: "", explanation: "", kind: kind)
    }

    @Test("Lückentext ignoriert Leerzeichen und ein überzähliges Semikolon")
    func blanksAreLenient() {
        let t = task(.fillBlank(FillBlankSpec(template: "x{{0}}", blanks: [.init(accepted: ["+= 1"])])))
        #expect(evaluator.evaluate(.blanks(["+=1"]), for: t).isCorrect)
        #expect(evaluator.evaluate(.blanks([" += 1; "]), for: t).isCorrect)
        #expect(!evaluator.evaluate(.blanks(["-= 1"]), for: t).isCorrect)
    }

    @Test("Groß-/Kleinschreibung zählt standardmäßig")
    func blanksAreCaseSensitiveByDefault() {
        let strict = task(.fillBlank(FillBlankSpec(template: "{{0}}", blanks: [.init(accepted: ["println"])])))
        #expect(!evaluator.evaluate(.blanks(["PrintLn"]), for: strict).isCorrect)
        let loose = task(.fillBlank(FillBlankSpec(template: "{{0}}", blanks: [.init(accepted: ["println"], caseSensitive: false)])))
        #expect(evaluator.evaluate(.blanks(["PrintLn"]), for: loose).isCorrect)
    }

    @Test("Teilpunkte beim Lückentext")
    func partialBlanks() {
        let t = task(.fillBlank(FillBlankSpec(template: "{{0}} {{1}}", blanks: [.init(accepted: ["a"]), .init(accepted: ["b"])])))
        let result = evaluator.evaluate(.blanks(["a", "c"]), for: t)
        #expect(!result.isCorrect)
        #expect(result.score == 0.5)
    }

    @Test("Ausgabe: Leerzeichen am Zeilenende und Leerzeilen am Rand sind egal")
    func outputNormalization() {
        let t = task(.predictOutput(PredictOutputSpec(expectedOutput: "1 2 3\nfertig")))
        #expect(evaluator.evaluate(.text("\n1 2 3   \r\nfertig\n\n"), for: t).isCorrect)
        let wrong = evaluator.evaluate(.text("1 2 3\nFertig"), for: t)
        #expect(!wrong.isCorrect)
        #expect(wrong.score == 0.5)
        #expect(wrong.findings.contains { $0.kind == .hint && $0.message.contains("Groß") })
    }

    @Test("Code: alle Regeln erfüllt → korrekt, Kommentare zählen nicht")
    func codeRules() {
        let spec = CodeTaskSpec(sampleSolution: "", rules: [
            CodeRule(rule: .require, pattern: #"\bfor\s*\("#, message: "Schleife"),
            CodeRule(rule: .forbid, pattern: "5050", message: "nicht hart codieren"),
        ])
        let t = task(.code(spec))
        #expect(evaluator.evaluate(.text("for (int i = 0; i < 3; i++) { s += i; }"), for: t).isCorrect)
        #expect(!evaluator.evaluate(.text("// for (\nint s = 1;"), for: t).isCorrect, "Kommentar darf Regel nicht erfüllen")
        #expect(!evaluator.evaluate(.text("String s = \"for (\";"), for: t).isCorrect, "String-Inhalt darf Regel nicht erfüllen")
        let cheated = evaluator.evaluate(.text("for (;;) { break; }\nSystem.out.println(5050);"), for: t)
        #expect(!cheated.isCorrect)
        #expect(cheated.score == 0.5)
    }

    @Test("Code: Strukturfehler verhindern eine richtige Wertung")
    func codeStructure() {
        let spec = CodeTaskSpec(sampleSolution: "", rules: [CodeRule(rule: .require, pattern: "println", message: "Ausgabe")])
        let t = task(.code(spec))
        let result = evaluator.evaluate(.text("System.out.println(\"x\")"), for: t)
        #expect(!result.isCorrect)
        #expect(result.findings.first?.line == 1)
        #expect(evaluator.evaluate(.text("System.out.println(\"x\");"), for: t).isCorrect)
    }

    @Test("Code mit Smart Quotes vom iPhone wird akzeptiert")
    func smartQuotes() {
        let spec = CodeTaskSpec(sampleSolution: "", rules: [
            CodeRule(rule: .require, pattern: #""Hallo""#, message: "Text", scope: .raw),
        ])
        #expect(evaluator.evaluate(.text("System.out.println(\u{201C}Hallo\u{201D});"), for: task(.code(spec))).isCorrect)
    }

    @Test("Falsche Antwortform wird sauber abgelehnt")
    func mismatchedAnswer() {
        let t = task(.singleChoice(SingleChoiceSpec(choices: ["a", "b"], correctIndex: 0)))
        #expect(!evaluator.evaluate(.text("a"), for: t).isCorrect)
    }
}

@Suite("Code-Aufgaben werden wirklich ausgeführt")
struct ExecutionEvaluationTests {
    let evaluator = AnswerEvaluator()
    let sumTask = LearningTask(
        id: "sum", topicId: "loops", difficulty: .medium,
        prompt: "Summe 1 bis 100", explanation: "",
        kind: .code(CodeTaskSpec(
            sampleSolution: "int summe = 0;\nfor (int i = 1; i <= 100; i++) {\n    summe += i;\n}\nSystem.out.println(summe);",
            expectedOutput: "5050",
            rules: [CodeRule(rule: .require, pattern: #"\bfor\b|\bwhile\b"#, message: "Nutze eine Schleife.")]
        ))
    )

    @Test("Richtige Ausgabe: gelöst, mit Konsolenausgabe im Ergebnis")
    func correctOutput() {
        let result = evaluator.evaluate(.text("int s = 0;\nint i = 1;\nwhile (i <= 100) { s += i; i++; }\nSystem.out.println(s);"), for: sumTask)
        #expect(result.isCorrect)
        #expect(result.execution?.output == "5050\n")
        #expect(result.execution?.outputMatches == true)
    }

    @Test("Falsche Ausgabe wird erkannt, obwohl alle Regeln erfüllt sind")
    func wrongOutput() {
        // Klassischer Off-by-one: < statt <=
        let result = evaluator.evaluate(.text("int summe = 0;\nfor (int i = 1; i < 100; i++) {\n    summe += i;\n}\nSystem.out.println(summe);"), for: sumTask)
        #expect(!result.isCorrect)
        #expect(result.execution?.outputMatches == false)
        #expect(result.findings.contains { $0.kind == .failed && $0.message.contains("4950") })
    }

    @Test("Syntaxfehler kommen mit exakter Zeile vom Interpreter")
    func syntaxError() {
        let result = evaluator.evaluate(.text("int summe = 0;\nfor (int i = 1; i <= 100; i++) {\n    summe += i\n}\nSystem.out.println(summe);"), for: sumTask)
        #expect(!result.isCorrect)
        #expect(result.findings.first?.line == 3)
        #expect(result.findings.first?.message.contains("Semikolon") == true)
    }

    @Test("Laufzeitfehler und Endlosschleifen machen die Lösung falsch")
    func runtimeProblems() {
        let endless = evaluator.evaluate(.text("int summe = 0;\nfor (int i = 1; i <= 100; i--) {\n    summe += i;\n}\nSystem.out.println(summe);"), for: sumTask)
        #expect(!endless.isCorrect)
        #expect(endless.findings.contains { $0.message.contains("Endlosschleife") })
    }

    @Test("Unbekannte Java-Bausteine führen nicht zu einem falschen Urteil")
    func unsupportedFallsBackToRules() {
        let result = evaluator.evaluate(.text("int summe = java.util.stream.IntStream.rangeClosed(1, 100).sum();\nfor (;;) { break; }\nSystem.out.println(summe);"), for: sumTask)
        #expect(result.execution == nil)
        #expect(result.isCorrect)
    }
}

@Suite("Code-Puzzle und Bug-Jagd")
struct PuzzleAndBugTests {
    let evaluator = AnswerEvaluator()
    let puzzle = LearningTask(
        id: "p", topicId: "loops", difficulty: .medium, prompt: "", explanation: "",
        kind: .ordering(OrderingSpec(puzzle: CodeSnippet(source: "int s = 0;\nfor (int i = 0; i < 3; i++) {\ns += i;\n}\nSystem.out.println(s);")))
    )

    @Test("Puzzle: richtig, teilweise richtig, unvollständig")
    func ordering() {
        #expect(evaluator.evaluate(.order([0, 1, 2, 3, 4]), for: puzzle).isCorrect)
        let swapped = evaluator.evaluate(.order([0, 1, 2, 4, 3]), for: puzzle)
        #expect(!swapped.isCorrect)
        #expect(swapped.score == 0.6)
        #expect(swapped.findings.contains { $0.line == 4 })
        let partial = evaluator.evaluate(.order([0, 1]), for: puzzle)
        #expect(partial.findings.contains { $0.message.contains("3 Zeilen") })
    }

    @Test("Puzzle: gleiche Zeilen sind austauschbar, gemischt wird stabil")
    func duplicatesAndShuffle() throws {
        let twoBraces = LearningTask(id: "q", topicId: "syntax", difficulty: .easy, prompt: "", explanation: "",
                                     kind: .ordering(OrderingSpec(puzzle: CodeSnippet(source: "class A {\nvoid m() {\n}\n}"))))
        #expect(evaluator.evaluate(.order([0, 1, 3, 2]), for: twoBraces).isCorrect)
        guard case .ordering(let spec) = puzzle.kind else { return }
        #expect(spec.shuffledOrder(seed: "p") == spec.shuffledOrder(seed: "p"))
        #expect(spec.shuffledOrder(seed: "p").sorted() == [0, 1, 2, 3, 4])
        #expect(OrderingSpec.assemble(["for (;;) {", "x();", "}"]) == "for (;;) {\n    x();\n}")
    }

    @Test("Bug-Jagd: nur die fehlerhafte Zeile zählt, die Korrektur ersetzt sie eingerückt")
    func findBug() {
        let code = "int[] a = {1, 2};\nfor (int i = 0; i <= a.length; i++) {\n    System.out.println(a[i]);\n}"
        let spec = FindBugSpec(bugLine: 2, fix: CodeSnippet.Line(code: "for (int i = 0; i < a.length; i++) {", explain: "x"))
        let task = LearningTask(id: "b", topicId: "arrays", difficulty: .medium, prompt: "", code: code, explanation: "", kind: .findBug(spec))
        #expect(evaluator.evaluate(.line(2), for: task).isCorrect)
        #expect(!evaluator.evaluate(.line(3), for: task).isCorrect)
        #expect(spec.fixed(CodeSnippet(source: code)).lines[1].code == "for (int i = 0; i < a.length; i++) {")
        // Die korrigierte Fassung läuft wirklich, die fehlerhafte stürzt ab.
        #expect(JavaRunner.run(code).problem?.kind == .runtime)
        #expect(JavaRunner.run(spec.fixed(CodeSnippet(source: code)).source).output == "1\n2\n")
    }
}
