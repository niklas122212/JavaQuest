import Foundation

/// Ein Fehler beim Ausführen von Java-Code – mit Zeile und einer Erklärung in Alltagssprache.
public struct JavaProblem: Error, Sendable, Hashable, CustomStringConvertible {
    public enum Kind: Sendable, Hashable {
        /// Der Code ist kein gültiges Java (würde auch `javac` ablehnen).
        case syntax
        /// Gültiges Java, das der eingebaute Interpreter aber nicht kennt (z. B. Klassen, Lambdas).
        case unsupported
        /// Fehler zur Laufzeit, z. B. Division durch 0 oder Array-Index zu groß.
        case runtime
        /// Das Programm hört nicht auf (Schrittlimit erreicht).
        case stepLimit
    }

    public let kind: Kind
    public let message: String
    public let line: Int?
    /// Bei Laufzeitfehlern: die Java-Exception, z. B. `ArithmeticException` – damit try/catch sie auffangen kann.
    public var exceptionClass: String?
    /// Javas eigene Meldung (`getMessage()`), z. B. „/ by zero“.
    public var javaMessage: String?
    /// Das geworfene Exception-Objekt (bei `throw` oder eigenen Exceptions).
    var thrown: ThrownObject?

    public init(_ kind: Kind, _ message: String, line: Int?) {
        self.kind = kind
        self.message = message
        self.line = line
        if kind == .runtime, let colon = message.firstIndex(of: ":") {
            // „ArithmeticException: / by zero – …“: Die Klasse steht vorne.
            let name = String(message[..<colon])
            if name.hasSuffix("Exception") || name.hasSuffix("Error"), !name.contains(" ") { exceptionClass = name }
        }
    }

    /// Laufzeitfehler mit Exception-Klasse und Javas Originalmeldung; `explanation` ist der Text für Lernende.
    static func exception(_ className: String, javaMessage: String?, explanation: String, line: Int?) -> JavaProblem {
        var problem = JavaProblem(.runtime, "\(className): \(explanation)", line: line)
        problem.exceptionClass = className
        problem.javaMessage = javaMessage
        return problem
    }

    /// Meldung mit vorangestellter Zeilennummer.
    public var description: String {
        guard let line else { return message }
        return "Zeile \(line): \(message)"
    }

    static func syntax(_ message: String, line: Int?) -> JavaProblem { JavaProblem(.syntax, message, line: line) }
    static func unsupported(_ message: String, line: Int?) -> JavaProblem { JavaProblem(.unsupported, message, line: line) }
    static func runtime(_ message: String, line: Int?) -> JavaProblem { JavaProblem(.runtime, message, line: line) }
}

/// Hülle für ein geworfenes Exception-Objekt – vergleichbar über die Identität.
final class ThrownObject: @unchecked Sendable, Hashable {
    let value: JavaValue

    init(_ value: JavaValue) {
        self.value = value
    }

    static func == (lhs: ThrownObject, rhs: ThrownObject) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
