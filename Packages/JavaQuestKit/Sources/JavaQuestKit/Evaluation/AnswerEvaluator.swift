import Foundation

/// Bewertet Antworten vollständig lokal – ohne Netz, ohne Sprachmodell, ohne Java-Compiler.
///
/// - Multiple Choice: Index-Vergleich.
/// - Lückentext: Vergleich ohne Leerzeichen, optional ohne Groß-/Kleinschreibung.
/// - Ausgabe vorhersagen: zeilenweiser Vergleich, Leerzeichen am Zeilenende egal.
/// - Code: Struktur-Checks (Klammern, Semikolons) plus RegEx-Regeln aus dem JSON. Versteht der
///   eingebaute Interpreter den Code, wird er zusätzlich wirklich ausgeführt und die Ausgabe verglichen.
public struct AnswerEvaluator: Sendable {
    public init() {}

    public func evaluate(_ answer: TaskAnswer, for task: LearningTask) -> EvaluationResult {
        switch (task.kind, answer) {
        case let (.singleChoice(spec), .choice(index)):
            evaluateChoice(index, spec: spec)
        case let (.fillBlank(spec), .blanks(values)):
            evaluateBlanks(values.map(JavaSource.normalizingTypography), spec: spec)
        case let (.predictOutput(spec), .text(text)):
            evaluateOutput(JavaSource.normalizingTypography(text), spec: spec)
        case let (.code(spec), .text(text)):
            evaluateCode(JavaSource.normalizingTypography(text), spec: spec, context: task.javaContext)
        case let (.ordering(spec), .order(order)):
            evaluateOrder(order, spec: spec)
        case let (.findBug(spec), .line(line)):
            evaluateBugLine(line, spec: spec)
        default:
            EvaluationResult(isCorrect: false, score: 0, findings: [.failed("Diese Antwortform passt nicht zur Aufgabe.")])
        }
    }

    /// Musterlösung als Antwort – für „Lösung zeigen“ und für die Inhaltstests.
    public func referenceAnswer(for task: LearningTask) -> TaskAnswer {
        switch task.kind {
        case .singleChoice(let spec): .choice(spec.correctIndex)
        case .fillBlank(let spec): .blanks(spec.blanks.map { $0.accepted.first ?? "" })
        case .predictOutput(let spec): .text(spec.expectedOutput)
        case .code(let spec): .text(spec.sampleSolution)
        case .ordering(let spec): .order(Array(spec.pieces.indices))
        case .findBug(let spec): .line(spec.bugLine)
        }
    }

    // MARK: Code-Puzzle

    private func evaluateOrder(_ order: [Int], spec: OrderingSpec) -> EvaluationResult {
        let pieces = spec.pieces
        let chosen = order.filter { pieces.indices.contains($0) }.map { pieces[$0] }
        guard !chosen.isEmpty else {
            return EvaluationResult(isCorrect: false, score: 0, findings: [.failed("Lege die Zeilen in die richtige Reihenfolge.")])
        }
        // Verglichen wird der Text: Gleiche Zeilen (z. B. zwei „}“) sind austauschbar.
        let correct = zip(chosen, pieces).filter { $0 == $1 }.count
        if chosen == pieces {
            return EvaluationResult(isCorrect: true, score: 1, findings: [.passed("Alle \(pieces.count) Zeilen stehen an der richtigen Stelle.")])
        }
        var findings: [Finding] = []
        if chosen.count < pieces.count {
            let missing = pieces.count - chosen.count
            findings.append(.failed(missing == 1 ? "Eine Zeile fehlt noch." : "Es fehlen noch \(missing) Zeilen."))
        }
        if let firstWrong = zip(chosen, pieces).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset {
            findings.append(.failed(
                firstWrong == 0
                    ? "Schon die erste Zeile passt noch nicht – womit beginnt ein Programm?"
                    : "Bis Zeile \(firstWrong) stimmt alles – ab Zeile \(firstWrong + 1) passt die Reihenfolge noch nicht.",
                line: firstWrong + 1
            ))
        }
        if correct > 0 { findings.insert(.passed("\(correct) von \(pieces.count) Zeilen stehen schon richtig."), at: 0) }
        return EvaluationResult(isCorrect: false, score: Double(correct) / Double(pieces.count), findings: findings)
    }

    // MARK: Bug-Jagd

    private func evaluateBugLine(_ line: Int, spec: FindBugSpec) -> EvaluationResult {
        if line == spec.bugLine {
            return EvaluationResult(isCorrect: true, score: 1, findings: [.passed("Erwischt! In Zeile \(line) steckt der Fehler.", line: line)])
        }
        return EvaluationResult(isCorrect: false, score: 0, findings: [.failed("Zeile \(line) ist in Ordnung – der Fehler steckt woanders.", line: line)])
    }

    // MARK: Multiple Choice

    private func evaluateChoice(_ index: Int, spec: SingleChoiceSpec) -> EvaluationResult {
        index == spec.correctIndex
            ? EvaluationResult(isCorrect: true, score: 1, findings: [.passed("Richtig gewählt.")])
            : EvaluationResult(isCorrect: false, score: 0, findings: [.failed("Diese Antwort stimmt leider nicht.")])
    }

    // MARK: Lückentext

    private func evaluateBlanks(_ values: [String], spec: FillBlankSpec) -> EvaluationResult {
        var findings: [Finding] = []
        var correct = 0
        for (index, blank) in spec.blanks.enumerated() {
            let value = index < values.count ? values[index] : ""
            if Self.blank(blank, accepts: value) {
                correct += 1
                findings.append(.passed("Lücke \(index + 1) ist richtig."))
            } else if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(.failed("Lücke \(index + 1) ist noch leer."))
            } else {
                findings.append(.failed("Lücke \(index + 1): " + Self.warumBlankFalsch(value, blank: blank, alle: spec.blanks, index: index)))
            }
        }
        let total = max(spec.blanks.count, 1)
        return EvaluationResult(isCorrect: correct == spec.blanks.count, score: Double(correct) / Double(total), findings: findings)
    }

    /// Warum diese Eingabe die Lücke nicht füllt – konkret statt „stimmt noch nicht“.
    ///
    /// Ein bloßes „falsch“ lässt den Lernenden im Dunkeln. Die häufigen Fälle lassen sich
    /// benennen: nur die Groß-/Kleinschreibung daneben, in der falschen Lücke gelandet,
    /// ein Klammerpaar zu viel oder zu wenig.
    static func warumBlankFalsch(_ value: String, blank: FillBlankSpec.Blank,
                                 alle: [FillBlankSpec.Blank], index: Int) -> String {
        let eingabe = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let richtig = blank.accepted.first ?? ""

        // Nur die Groß-/Kleinschreibung daneben – bei caseSensitive ein echter Fehler.
        if blank.accepted.contains(where: { $0.lowercased() == eingabe.lowercased() }) {
            return "fast – achte auf Groß- und Kleinschreibung."
        }
        // In der falschen Lücke gelandet.
        for (anderer, b) in alle.enumerated() where anderer != index {
            if b.accepted.contains(where: { $0.lowercased() == eingabe.lowercased() }) {
                return "das gehört in Lücke \(anderer + 1)."
            }
        }
        // Klammern mitgetippt oder vergessen.
        let ohneKlammern = eingabe.replacingOccurrences(of: "()", with: "")
        if blank.accepted.contains(where: { $0.lowercased() == ohneKlammern.lowercased() }) {
            return "die runden Klammern stehen hier schon im Text."
        }
        if blank.accepted.contains(where: { $0.lowercased() == (eingabe + "()").lowercased() }) {
            return "fast – es fehlen die runden Klammern."
        }
        // Richtiger Anfang, aber zu kurz oder zu lang.
        if !richtig.isEmpty, richtig.lowercased().hasPrefix(eingabe.lowercased()) {
            return "der Anfang stimmt, es fehlt noch etwas."
        }
        if !eingabe.isEmpty, eingabe.lowercased().hasPrefix(richtig.lowercased()), !richtig.isEmpty {
            return "da steht etwas zu viel."
        }
        return "stimmt noch nicht."
    }

    static func blank(_ blank: FillBlankSpec.Blank, accepts value: String) -> Bool {
        func normalize(_ text: String) -> String {
            let compact = text.filter { !$0.isWhitespace }
            return blank.caseSensitive ? compact : compact.lowercased()
        }
        var candidates = [normalize(value)]
        // Ein versehentlich mitgetipptes Semikolon am Ende wird toleriert.
        if let first = candidates.first, first.hasSuffix(";") { candidates.append(String(first.dropLast())) }
        let accepted = Set(blank.accepted.map(normalize))
        return candidates.contains { accepted.contains($0) }
    }

    // MARK: Ausgabe vorhersagen

    private func evaluateOutput(_ text: String, spec: PredictOutputSpec) -> EvaluationResult {
        let given = Self.outputLines(text)
        let expectations = ([spec.expectedOutput] + spec.alsoAccepted).map(Self.outputLines)
        if expectations.contains(given) {
            return EvaluationResult(isCorrect: true, score: 1, findings: [.passed("Die Ausgabe stimmt exakt.")])
        }

        let expected = expectations[0]
        guard !given.isEmpty else {
            return EvaluationResult(isCorrect: false, score: 0, findings: [.failed("Noch keine Ausgabe eingegeben.")])
        }

        var findings: [Finding] = []
        var matching = 0
        for index in 0..<max(expected.count, given.count) {
            let expectedLine = index < expected.count ? expected[index] : nil
            let givenLine = index < given.count ? given[index] : nil
            if let expectedLine, expectedLine == givenLine {
                matching += 1
            } else if expectedLine == nil {
                findings.append(.failed("Zeile \(index + 1) ist zu viel.", line: index + 1))
            } else if givenLine == nil {
                findings.append(.failed("Zeile \(index + 1) fehlt noch.", line: index + 1))
            } else if let expectedLine, let givenLine {
                findings.append(.failed("Zeile \(index + 1): " + Self.warumZeileFalsch(givenLine, erwartet: expectedLine),
                                        line: index + 1))
            }
        }
        if matching > 0 {
            findings.insert(.passed("\(matching) von \(expected.count) Zeilen stimmen."), at: 0)
        }
        if let gesamt = Self.warumAusgabeFalsch(given, erwartet: expected) {
            findings.append(.hint(gesamt))
        }
        let score = Double(matching) / Double(max(expected.count, given.count))
        return EvaluationResult(isCorrect: false, score: score, findings: findings)
    }

    /// Was an dieser einen Zeile abweicht – benannt, nicht nur festgestellt.
    static func warumZeileFalsch(_ gegeben: String, erwartet: String) -> String {
        if gegeben.lowercased() == erwartet.lowercased() {
            return "richtig bis auf die Groß- und Kleinschreibung."
        }
        if gegeben.filter({ !$0.isWhitespace }) == erwartet.filter({ !$0.isWhitespace }) {
            return "richtig bis auf die Leerzeichen."
        }
        // Ganze Zahl statt Kommazahl: der Klassiker bei double.
        if erwartet.hasSuffix(".0"), String(erwartet.dropLast(2)) == gegeben {
            return "die Nachkommastelle fehlt – sobald eine Kommazahl beteiligt ist, hat auch das Ergebnis eine."
        }
        if gegeben.hasSuffix(".0"), String(gegeben.dropLast(2)) == erwartet {
            return "hier wird mit ganzen Zahlen gerechnet, da kommt keine Nachkommastelle heraus."
        }
        // Liste ohne die eckigen Klammern.
        if erwartet.hasPrefix("["), erwartet.hasSuffix("]"),
           String(erwartet.dropFirst().dropLast()) == gegeben {
            return "eine Liste gibt sich mit eckigen Klammern aus."
        }
        if erwartet.count == gegeben.count {
            return "gleich lang, aber ein anderer Inhalt."
        }
        return gegeben.count < erwartet.count ? "da fehlt noch etwas." : "da steht etwas zu viel."
    }

    /// Ein Befund über die ganze Ausgabe – für Fehler, die man nur im Zusammenhang sieht.
    static func warumAusgabeFalsch(_ gegeben: [String], erwartet: [String]) -> String? {
        // Groß-/Kleinschreibung nur melden, wenn sich der Text wirklich darin unterscheidet –
        // sonst verdeckt dieser Fall den print/println-Fehler, bei dem der Text identisch ist.
        if gegeben.joined().lowercased() == erwartet.joined().lowercased(),
           gegeben.joined() != erwartet.joined() {
            return "Fast! Achte auf Groß- und Kleinschreibung."
        }
        // Alles in einer Zeile: der Unterschied zwischen print und println.
        if gegeben.count == 1, erwartet.count > 1, gegeben[0] == erwartet.joined() {
            return "Der Inhalt stimmt, aber alles steht in einer Zeile. println beginnt danach eine neue, print nicht."
        }
        if erwartet.count == 1, gegeben.count > 1, erwartet[0] == gegeben.joined() {
            return "Der Inhalt stimmt, aber er ist auf mehrere Zeilen verteilt. Nur println bricht um."
        }
        if gegeben.joined().filter({ !$0.isWhitespace }) == erwartet.joined().filter({ !$0.isWhitespace }) {
            return "Fast! Achte auf Leerzeichen und Zeilenumbrüche – println beginnt eine neue Zeile, print nicht."
        }
        if gegeben.count > erwartet.count {
            return "Es erscheinen \(gegeben.count - erwartet.count) Zeile(n) zu viel. Zähl nach, wie oft die Ausgabe wirklich erreicht wird."
        }
        if gegeben.count < erwartet.count {
            return "Es fehlen \(erwartet.count - gegeben.count) Zeile(n). Zähl nach, wie oft die Ausgabe erreicht wird."
        }
        return nil
    }

    /// Normalisiert Konsolenausgabe: Zeilenenden vereinheitlicht, Leerzeichen am
    /// Zeilenende und Leerzeilen am Anfang und Ende entfernt.
    static func outputLines(_ text: String) -> [String] {
        var lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { line in String(line.reversed().drop { $0 == " " || $0 == "\t" }.reversed()) }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines
    }

    // MARK: Code

    private func evaluateCode(_ source: String, spec: CodeTaskSpec, context: LearningTask.JavaContext) -> EvaluationResult {
        let withoutComments = JavaSource.strippingComments(source)
        let masked = JavaSource.maskingLiterals(source)

        guard !masked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return EvaluationResult(isCorrect: false, score: 0, findings: [.failed("Hier steht noch kein Code.")])
        }

        let run = execute(source, spec: spec, context: context)

        var structureFindings: [Finding] = []
        if let run, run.problemKind == .syntax {
            // Der Interpreter kennt die genaue Fehlerstelle – die Heuristiken unten wären nur ungenauer.
            structureFindings.append(.failed(run.problemDescription ?? "", line: run.report.problemLine))
        } else if spec.structure.contains(.balancedDelimiters) {
            structureFindings += JavaSource.delimiterIssues(in: masked)
        }
        if run?.problemKind != .syntax, spec.structure.contains(.semicolons) {
            structureFindings += JavaSource.linesMissingSemicolon(in: masked).prefix(3).map { line in
                .failed("Zeile \(line): Am Ende fehlt vermutlich ein Semikolon (;).", line: line)
            }
        }

        var ruleFindings: [Finding] = []
        var earned = structureFindings.isEmpty ? 1.0 : 0.0
        var total = 1.0
        var allRequiredMet = true
        var violations = 0

        for rule in spec.rules {
            let target = rule.scope == .raw ? withoutComments : masked
            // Bei anyOf genügt einer der gleichwertigen Wege, sonst muss das Muster passen.
            let matches = rule.allPatterns.contains { Self.matches($0, in: target) }
            switch rule.rule {
            case .require, .anyOf:
                total += rule.weight
                if matches {
                    earned += rule.weight
                    ruleFindings.append(.passed(rule.message))
                } else {
                    allRequiredMet = false
                    ruleFindings.append(.failed(rule.message))
                }
            case .forbid:
                if matches {
                    violations += 1
                    ruleFindings.append(.failed(rule.message))
                }
            }
        }

        var runFindings: [Finding] = []
        var runSucceeded = true
        if let run {
            total += 1
            switch run.problemKind {
            case .syntax?:
                runSucceeded = false
            case .runtime?, .stepLimit?:
                runSucceeded = false
                runFindings.append(.failed("Beim Ausführen: \(run.problemDescription ?? "")", line: run.report.problemLine))
            case .unsupported?, nil:
                break
            }
            if run.problemKind == nil, let matches = run.report.outputMatches {
                if matches {
                    earned += 1
                    runFindings.append(.passed("Ausgeführt – die Ausgabe stimmt."))
                } else {
                    runSucceeded = false
                    runFindings.append(.failed(Self.outputDifference(run.report.output, expected: spec.expectedOutput ?? "")))
                }
            }
            runFindings += run.warnings.map { .hint($0.message, line: $0.line) }
        }

        var score = earned / total
        if violations > 0 { score *= 0.5 }
        let isCorrect = structureFindings.isEmpty && allRequiredMet && violations == 0 && runSucceeded
        return EvaluationResult(isCorrect: isCorrect, score: score, findings: structureFindings + runFindings + ruleFindings, execution: run?.report)
    }

    private struct CodeRun {
        let report: ExecutionReport
        let problemKind: JavaProblem.Kind?
        let problemDescription: String?
        let warnings: [JavaWarning]
    }

    /// Führt den Code aus, sofern die Aufgabe dafür geeignet ist: Es gibt eine erwartete Ausgabe,
    /// und die Musterlösung selbst läuft im Interpreter. Sonst bleibt es bei der Regelprüfung.
    private func execute(_ source: String, spec: CodeTaskSpec, context: LearningTask.JavaContext) -> CodeRun? {
        guard let expected = spec.expectedOutput, context != .members, Self.isRunnable(spec) else { return nil }
        // Kursprogramme brauchen nur ein paar hundert Schritte; ein kleines Limit hält die Oberfläche
        // auch bei einer Endlosschleife flüssig (die Prüfung läuft auf dem Haupt-Thread).
        let result = JavaRunner.run(source, stepLimit: Self.evaluationStepLimit)
        if result.problem?.kind == .unsupported {
            // Gültiges Java, das der Interpreter nicht kennt: kein Urteil über die Ausführung.
            return nil
        }
        let matches = result.problem == nil ? Self.outputLines(result.output) == Self.outputLines(expected) : nil
        let report = ExecutionReport(
            output: result.output,
            problem: result.problem?.message,
            problemLine: result.problem?.line,
            outputMatches: matches
        )
        return CodeRun(report: report, problemKind: result.problem?.kind, problemDescription: result.problem?.description, warnings: result.warnings)
    }

    /// Läuft die Musterlösung im Interpreter und erzeugt genau die erwartete Ausgabe?
    static func isRunnable(_ spec: CodeTaskSpec) -> Bool {
        guard let expected = spec.expectedOutput else { return false }
        let key = spec.sampleSolution
        if let cached = RunnableCache.shared.value(for: key) { return cached }
        let result = JavaRunner.run(spec.sampleSolution)
        let runnable = result.problem == nil && outputLines(result.output) == outputLines(expected)
        RunnableCache.shared.store(runnable, for: key)
        return runnable
    }

    public static let evaluationStepLimit = 40_000

    /// Testlauf ohne Bewertung: führt den Code einer Aufgabe aus, wie er gerade im Editor steht.
    public static func testRun(_ source: String) -> JavaRunResult {
        JavaRunner.run(JavaSource.normalizingTypography(source), stepLimit: evaluationStepLimit)
    }

    static func outputDifference(_ output: String, expected: String) -> String {
        let given = outputLines(output)
        if given.isEmpty { return "Ausgeführt – aber dein Programm gibt nichts aus. Fehlt ein System.out.println(…)?" }
        let shown = given.prefix(3).joined(separator: " ⏎ ") + (given.count > 3 ? " …" : "")
        return "Ausgeführt – dein Programm gibt „\(shown)“ aus, erwartet wird „\(outputLines(expected).joined(separator: " ⏎ "))“."
    }

    static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}

/// Merkt sich, welche Musterlösungen der Interpreter ausführen kann (ändert sich zur Laufzeit nie).
final class RunnableCache: @unchecked Sendable {
    static let shared = RunnableCache()
    private let lock = NSLock()
    private var values: [String: Bool] = [:]

    func value(for key: String) -> Bool? {
        lock.withLock { values[key] }
    }

    func store(_ value: Bool, for key: String) {
        lock.withLock { values[key] = value }
    }
}
