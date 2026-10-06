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

    public init(_ kind: Kind, _ message: String, line: Int?) {
        self.kind = kind
        self.message = message
        self.line = line
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
