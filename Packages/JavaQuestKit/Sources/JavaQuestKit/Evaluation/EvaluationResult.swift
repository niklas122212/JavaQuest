import Foundation

/// Antwort der lernenden Person in einer der vier Eingabeformen.
public enum TaskAnswer: Sendable, Hashable {
    case choice(Int)
    case blanks([String])
    case text(String)
}

/// Einzelne Rückmeldung der Auswertung (erfüllt, verfehlt oder Hinweis).
public struct Finding: Sendable, Hashable {
    public enum Kind: Sendable, Hashable { case passed, failed, hint }

    public let kind: Kind
    public let message: String
    public let line: Int?

    public static func passed(_ message: String, line: Int? = nil) -> Finding { Finding(kind: .passed, message: message, line: line) }
    public static func failed(_ message: String, line: Int? = nil) -> Finding { Finding(kind: .failed, message: message, line: line) }
    public static func hint(_ message: String, line: Int? = nil) -> Finding { Finding(kind: .hint, message: message, line: line) }
}

public struct EvaluationResult: Sendable, Hashable {
    public let isCorrect: Bool
    /// Teilpunktzahl 0…1 – auch bei falschen Antworten aussagekräftig (z. B. 3 von 4 Regeln erfüllt).
    public let score: Double
    public let findings: [Finding]

    public init(isCorrect: Bool, score: Double, findings: [Finding]) {
        self.isCorrect = isCorrect
        self.score = min(max(score, 0), 1)
        self.findings = findings
    }

    public var percent: Int { Int((score * 100).rounded()) }
}
