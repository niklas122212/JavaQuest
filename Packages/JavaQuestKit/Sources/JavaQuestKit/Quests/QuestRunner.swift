import Foundation

/// Ergebnis eines einzelnen Tests.
public struct QuestTestResult: Sendable, Identifiable {
    public let test: QuestTest
    public let passed: Bool
    /// Was der Code geliefert hat – für „erwartet … · bekommen …“.
    public let actual: String?
    /// Warum der Test scheitert, in Alltagssprache.
    public let message: String?
    /// Zeile im Code des Spielers, an der es hakt (bei Fehlern und Abstürzen).
    public let line: Int?
    public var id: String { test.name }
}

/// Der eine Hinweis, den der Mentor nach einem Lauf gibt – der hilfreichste zuerst.
public struct MentorHint: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case compile, unsupported, missingClass, missingMember, endless, crash, wrongValue, requirement, quality, success
    }
    public let kind: Kind
    public let title: String
    public let text: String
    public let line: Int?
}

/// Ergebnis eines Laufs: Übersetzung, Tests, Pflicht-Bausteine, Code-Qualität, Sterne und Mentor.
public struct QuestResult: Sendable {
    /// Lässt sich der Code nicht lesen, laufen keine Tests.
    public let compileProblem: JavaProblem?
    public let tests: [QuestTestResult]
    public let missingRequirements: [String]
    public let naming: [QualityFinding]
    public let indentation: [QualityFinding]
    public let mentor: MentorHint

    public var passedCount: Int { tests.filter(\.passed).count }
    public var solved: Bool { compileProblem == nil && !tests.isEmpty && tests.allSatisfy(\.passed) && missingRequirements.isEmpty }
    /// ★ alle Tests · ★ saubere Namen · ★ sauber eingerückt – die Qualitäts-Sterne nur, wenn alles läuft.
    public var stars: Int { solved ? 1 + (naming.isEmpty ? 1 : 0) + (indentation.isEmpty ? 1 : 0) : 0 }
}

/// Prüft den Code einer Quest gegen ihre versteckten Tests.
public enum QuestRunner {
    public static let stepLimit = 40_000

    public static func run(_ code: String, quest: CodeQuest) -> QuestResult {
        let source = JavaSource.normalizingTypography(code)

        // 1. Lässt sich der Code übersetzen?
        let program: JavaProgram
        do {
            program = try JavaParser.parse(source)
        } catch {
            return QuestResult(compileProblem: error, tests: [], missingRequirements: [], naming: [], indentation: [],
                               mentor: Mentor.compile(error))
        }
        // 2. Gibt es die verlangte Klasse?
        guard program.classes[quest.className] != nil || program.mainClass == quest.className else {
            let others = (program.classOrder + [program.mainClass].compactMap { $0 })
            let similar = others.first { $0.lowercased() == quest.className.lowercased() }
            let hint = MentorHint(kind: .missingClass, title: "Die Klasse \(quest.className) fehlt",
                text: similar.map { "Deine Klasse heißt \($0) – Java unterscheidet Groß- und Kleinschreibung. Sie muss genau \(quest.className) heißen, wie die Datei \(quest.className).java." }
                    ?? "Die Datei heißt \(quest.className).java – deshalb muss darin die Klasse public class \(quest.className) { … } stehen.",
                line: nil)
            return QuestResult(compileProblem: nil, tests: quest.tests.map { QuestTestResult(test: $0, passed: false, actual: nil, message: hint.text, line: nil) },
                               missingRequirements: [], naming: [], indentation: [], mentor: hint)
        }

        // 3. Die Tests
        let results = quest.tests.map { run($0, source: source) }

        // 4. Pflicht-Bausteine
        let masked = JavaSource.maskingLiterals(source)
        let missing = quest.requirements.filter { rule in
            let target = rule.scope == .raw ? JavaSource.strippingComments(source) : masked
            let hit = rule.allPatterns.contains { AnswerEvaluator.matches($0, in: target) }
            return rule.rule == .forbid ? hit : !hit
        }.map(\.message)

        // 5. Code-Qualität
        let naming = CodeQuality.naming(source)
        let indentation = CodeQuality.indentation(source)

        let mentor = Mentor.after(results, missing: missing, naming: naming, indentation: indentation, quest: quest)
        return QuestResult(compileProblem: nil, tests: results, missingRequirements: missing, naming: naming,
                           indentation: indentation, mentor: mentor)
    }

    static func run(_ test: QuestTest, source: String) -> QuestTestResult {
        // Nur eine Ausgabe, kein Ausdruck: das ganze Programm mit main.
        if test.setup.isEmpty, test.expression == nil, case .output(let expected) = test.expect {
            let result = JavaRunner.run(source, stepLimit: stepLimit)
            if let problem = result.problem {
                return QuestTestResult(test: test, passed: false, actual: nil, message: Mentor.describe(problem), line: problem.line)
            }
            let passed = AnswerEvaluator.outputLines(result.output) == AnswerEvaluator.outputLines(expected)
            return QuestTestResult(test: test, passed: passed, actual: shown(result.output),
                                   message: passed ? nil : "Erwartet wird die Ausgabe „\(shown(expected))“, dein Programm gibt „\(shown(result.output))“ aus.", line: nil)
        }

        let outcome = JavaRunner.test(source, setup: test.setup, expression: test.expression, stepLimit: stepLimit)
        if let problem = outcome.problem, let call = outcome.failingTestCode, problem.kind == .syntax || problem.kind == .unsupported {
            // Der Test kann nicht aufrufen, was er erwartet: Methode fehlt, heißt anders oder hat andere Parameter.
            return QuestTestResult(test: test, passed: false, actual: nil,
                                   message: Mentor.missingMemberPrefix + "\(call)“ auf – aber: \(problem.message)", line: nil)
        }
        if case .exception(let expected) = test.expect {
            guard let problem = outcome.problem else {
                return QuestTestResult(test: test, passed: false, actual: outcome.text,
                    message: "Hier sollte eine \(expected) geworfen werden – dein Code läuft aber ohne Fehler durch\(outcome.text.map { " und liefert \($0)" } ?? "").", line: nil)
            }
            let thrown = problem.exceptionClass
            let passed = problem.kind == .runtime && (thrown == expected || ["Exception", "RuntimeException"].contains(expected) && thrown != nil)
            return QuestTestResult(test: test, passed: passed, actual: thrown,
                message: passed ? nil : (thrown.map { "Erwartet wird eine \(expected), geworfen wird aber eine \($0)." } ?? Mentor.describe(problem)),
                line: problem.line)
        }
        if let problem = outcome.problem {
            return QuestTestResult(test: test, passed: false, actual: problem.exceptionClass, message: Mentor.describe(problem), line: problem.line)
        }
        switch test.expect {
        case .value(let expected):
            let (passed, message) = compare(expected, outcome)
            return QuestTestResult(test: test, passed: passed, actual: display(outcome), message: passed ? nil : message, line: nil)
        case .text(let expected):
            let passed = outcome.text == expected
            return QuestTestResult(test: test, passed: passed, actual: outcome.text,
                                   message: passed ? nil : "Erwartet: „\(expected)“ – dein Code liefert „\(outcome.text ?? "")“.", line: nil)
        case .output(let expected):
            let passed = AnswerEvaluator.outputLines(outcome.output) == AnswerEvaluator.outputLines(expected)
            return QuestTestResult(test: test, passed: passed, actual: shown(outcome.output),
                                   message: passed ? nil : "Erwartet wird die Ausgabe „\(shown(expected))“, dein Code gibt „\(shown(outcome.output))“ aus.", line: nil)
        case .exception:
            return QuestTestResult(test: test, passed: false, actual: nil, message: nil, line: nil)
        }
    }

    /// Vergleich wie `assertEquals`: Wert und Art müssen passen (eine Zahl ist kein Text).
    static func compare(_ expected: QuestValue, _ outcome: JavaTestOutcome) -> (Bool, String) {
        let actual = display(outcome)
        let mismatch = "Erwartet: \(expected.javaLiteral) – dein Code liefert \(actual)."
        guard let value = outcome.value else { return (false, mismatch) }
        switch (expected, value) {
        case (.boolean(let e), .boolean(let a)): return (e == a, mismatch)
        case (.integer(let e), .integer(let a)): return (e == a, mismatch)
        case (.double(let e), .double(let a)): return (abs(e - a) < 1e-9, mismatch)
        case (.double(let e), .integer(let a)): return (Double(a) == e, mismatch)
        case (.string(let e), .string(let a)): return (e == a, mismatch)
        case (.null, .null): return (true, mismatch)
        case (_, .void):
            return (false, "Die Methode gibt nichts zurück (void) – erwartet wird aber \(expected.javaLiteral). Fehlt ein return?")
        default:
            return (false, "Erwartet wird \(kind(of: expected)) (\(expected.javaLiteral)), dein Code liefert aber \(kind(of: value)) (\(actual)).")
        }
    }

    static func kind(of value: QuestValue) -> String {
        switch value {
        case .boolean: "ein Wahrheitswert"
        case .integer: "eine ganze Zahl"
        case .double: "eine Kommazahl"
        case .string: "ein Text"
        case .null: "null"
        }
    }

    static func kind(of value: JavaTestValue) -> String {
        switch value {
        case .boolean: "ein Wahrheitswert"
        case .integer: "eine ganze Zahl"
        case .double: "eine Kommazahl"
        case .char: "ein Zeichen"
        case .string: "ein Text"
        case .null: "null"
        case .void: "nichts"
        case .other: "ein Objekt"
        }
    }

    static func display(_ outcome: JavaTestOutcome) -> String {
        if case .string(let s)? = outcome.value { return "\"\(s)\"" }
        return outcome.text ?? "nichts"
    }

    static func shown(_ output: String) -> String {
        AnswerEvaluator.outputLines(output).joined(separator: " ⏎ ")
    }
}

/// Formuliert Fehler und gescheiterte Tests so, dass man weiß, was zu tun ist.
public enum Mentor {
    static let missingMemberPrefix = "Der Test ruft „"

    static func compile(_ problem: JavaProblem) -> MentorHint {
        if problem.kind == .unsupported {
            return MentorHint(kind: .unsupported, title: "Diesen Baustein kennt der Übungs-Compiler noch nicht",
                              text: problem.message + " Bleib bei dem, was die Quest zeigt – damit klappt es.", line: problem.line)
        }
        let line = problem.line.map { "Zeile \($0): " } ?? ""
        let text: String
        if problem.message.contains("Semikolon") {
            text = "\(line)Du hast ein Semikolon vergessen. Jede Anweisung endet mit ; – wie ein Punkt am Satzende."
        } else if problem.message.contains("nie mit }") || problem.message.contains("nicht mit }") {
            text = "\(line)Eine geschweifte Klammer { wird nie geschlossen. Zu jeder { gehört eine } – zähl sie einmal durch."
        } else {
            text = line + problem.message
        }
        return MentorHint(kind: .compile, title: "Der Code lässt sich noch nicht übersetzen", text: text, line: problem.line)
    }

    /// Ein Fehler während eines Tests in Alltagssprache.
    static func describe(_ problem: JavaProblem) -> String {
        switch problem.kind {
        case .stepLimit:
            return "Dein Code hört nicht mehr auf – vermutlich eine Endlosschleife. Prüfe, ob sich die Bedingung der Schleife irgendwann ändert."
        case .runtime:
            return "Dein Programm stürzt ab: \(problem.description)"
        case .syntax, .unsupported:
            return problem.description
        }
    }

    static func after(_ results: [QuestTestResult], missing: [String], naming: [QualityFinding], indentation: [QualityFinding], quest: CodeQuest) -> MentorHint {
        if let failed = results.first(where: { !$0.passed }) {
            let message = failed.message ?? ""
            if message.hasPrefix(missingMemberPrefix) {
                let tip = if message.contains("Konstruktor") {
                    "Schreib den Konstruktor so, wie der Auftrag ihn verlangt – mit denselben Parametern."
                } else if message.contains("statische") {
                    "Prüfe Name, Groß- und Kleinschreibung, static und die Parameter – genau wie im Auftrag."
                } else {
                    "Prüfe Name, Groß- und Kleinschreibung und die Parameter – genau wie im Auftrag."
                }
                return MentorHint(kind: .missingMember, title: "Der Test findet nicht, was er aufruft", text: message + " " + tip, line: nil)
            }
            if message.contains("Endlosschleife") {
                return MentorHint(kind: .endless, title: "Deine Schleife läuft endlos",
                                  text: "Beim Test „\(failed.test.name)“ hört dein Code nicht auf. Prüfe, ob sich die Bedingung der Schleife irgendwann ändert – zählst du hoch oder runter?",
                                  line: failed.line)
            }
            if message.hasPrefix("Dein Programm stürzt ab") {
                return MentorHint(kind: .crash, title: "Absturz beim Test „\(failed.test.name)“",
                                  text: message + " " + failed.test.hint, line: failed.line)
            }
            let passed = results.filter(\.passed).count
            return MentorHint(kind: .wrongValue, title: "\(passed) von \(results.count) Tests bestanden",
                              text: "„\(failed.test.name)“: \(message) \(failed.test.hint)", line: failed.line)
        }
        if let first = missing.first {
            return MentorHint(kind: .requirement, title: "Alle Tests grün – eine Bedingung fehlt noch", text: first, line: nil)
        }
        if let finding = naming.first ?? indentation.first {
            return MentorHint(kind: .quality, title: "Alle Tests grün! Für den nächsten Stern:", text: finding.message, line: finding.line)
        }
        return MentorHint(kind: .success, title: "Perfekt – alle Tests grün und sauberer Code!", text: quest.success, line: nil)
    }
}
