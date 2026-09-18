import Foundation

/// Bewertet Antworten vollständig lokal – ohne Netz, ohne Sprachmodell, ohne Java-Compiler.
///
/// - Multiple Choice: Index-Vergleich.
/// - Lückentext: Vergleich ohne Leerzeichen, optional ohne Groß-/Kleinschreibung.
/// - Ausgabe vorhersagen: zeilenweiser Vergleich, Leerzeichen am Zeilenende egal.
/// - Code: Struktur-Checks (Klammern, Semikolons) plus RegEx-Regeln aus dem JSON.
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
            evaluateCode(JavaSource.normalizingTypography(text), spec: spec)
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
        }
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
                findings.append(.failed("Lücke \(index + 1) stimmt noch nicht."))
            }
        }
        let total = max(spec.blanks.count, 1)
        return EvaluationResult(isCorrect: correct == spec.blanks.count, score: Double(correct) / Double(total), findings: findings)
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
            } else {
                findings.append(.failed("Zeile \(index + 1) weicht ab.", line: index + 1))
            }
        }
        if matching > 0 {
            findings.insert(.passed("\(matching) von \(expected.count) Zeilen stimmen."), at: 0)
        }
        if given.joined().lowercased() == expected.joined().lowercased() {
            findings.append(.hint("Fast! Achte auf Groß- und Kleinschreibung."))
        } else if given.joined().filter({ !$0.isWhitespace }) == expected.joined().filter({ !$0.isWhitespace }) {
            findings.append(.hint("Fast! Achte auf Leerzeichen und Zeilenumbrüche – println beginnt eine neue Zeile, print nicht."))
        }
        let score = Double(matching) / Double(max(expected.count, given.count))
        return EvaluationResult(isCorrect: false, score: score, findings: findings)
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

    private func evaluateCode(_ source: String, spec: CodeTaskSpec) -> EvaluationResult {
        let withoutComments = JavaSource.strippingComments(source)
        let masked = JavaSource.maskingLiterals(source)

        guard !masked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return EvaluationResult(isCorrect: false, score: 0, findings: [.failed("Hier steht noch kein Code.")])
        }

        var structureFindings: [Finding] = []
        if spec.structure.contains(.balancedDelimiters) {
            structureFindings += JavaSource.delimiterIssues(in: masked)
        }
        if spec.structure.contains(.semicolons) {
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
            let matches = Self.matches(rule.pattern, in: target)
            switch rule.rule {
            case .require:
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

        var score = earned / total
        if violations > 0 { score *= 0.5 }
        let isCorrect = structureFindings.isEmpty && allRequiredMet && violations == 0
        return EvaluationResult(isCorrect: isCorrect, score: score, findings: structureFindings + ruleFindings)
    }

    static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
