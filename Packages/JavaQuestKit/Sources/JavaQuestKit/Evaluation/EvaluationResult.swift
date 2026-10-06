import Foundation

/// Antwort der lernenden Person in einer der vier Eingabeformen.
public enum TaskAnswer: Sendable, Hashable {
    case choice(Int)
    case blanks([String])
    case text(String)
    /// Code-Puzzle: Indizes der Puzzleteile in der gewählten Reihenfolge.
    case order([Int])
    /// Bug-Jagd: die angetippte Zeile (ab 1).
    case line(Int)
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

/// Was beim echten Ausführen des Codes passiert ist (nur bei Code-Aufgaben, die der Interpreter versteht).
public struct ExecutionReport: Sendable, Hashable {
    /// Konsolenausgabe des Programms (bis zum Ende oder bis zum Fehler).
    public let output: String
    /// Laufzeit- oder Syntaxfehler mit Zeile, falls das Programm nicht durchlief.
    public let problem: String?
    public let problemLine: Int?
    /// Stimmt die Ausgabe mit der erwarteten überein? `nil`, wenn es nichts zu vergleichen gab.
    public let outputMatches: Bool?

    public init(output: String, problem: String? = nil, problemLine: Int? = nil, outputMatches: Bool?) {
        self.output = output
        self.problem = problem
        self.problemLine = problemLine
        self.outputMatches = outputMatches
    }
}

public struct EvaluationResult: Sendable, Hashable {
    public let isCorrect: Bool
    /// Teilpunktzahl 0…1 – auch bei falschen Antworten aussagekräftig (z. B. 3 von 4 Regeln erfüllt).
    public let score: Double
    public let findings: [Finding]
    public let execution: ExecutionReport?

    public init(isCorrect: Bool, score: Double, findings: [Finding], execution: ExecutionReport? = nil) {
        self.isCorrect = isCorrect
        self.score = min(max(score, 0), 1)
        self.findings = findings
        self.execution = execution
    }

    public var percent: Int { Int((score * 100).rounded()) }
}
