import Foundation

/// Java-Code zusammen mit seiner Zeile-für-Zeile-Erklärung.
///
/// JSON-Form:
/// ```json
/// "code": { "lines": [
///   { "code": "int alter = 25;", "explain": "Hier erstellen wir eine Box namens „alter“ und legen die Zahl 25 hinein." },
///   { "code": "" }
/// ] }
/// ```
/// Ein einfacher String wird ebenfalls akzeptiert – dann erzeugt `CodeExplainer`
/// die Erklärungen zur Laufzeit.
public struct CodeSnippet: Codable, Sendable, Hashable {
    public struct Line: Codable, Sendable, Hashable {
        public let code: String
        /// Erklärung in Alltagssprache; fehlt nur bei Leerzeilen.
        public let explain: String?

        public init(code: String, explain: String? = nil) {
            self.code = code
            self.explain = explain
        }
    }

    public let lines: [Line]

    public init(lines: [Line]) {
        self.lines = lines
    }

    public init(source: String) {
        self.lines = source.components(separatedBy: "\n").map { Line(code: $0) }
    }

    enum CodingKeys: String, CodingKey { case lines }

    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let source = try? single.decode(String.self) {
            self.init(source: source)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(lines: try container.decode([Line].self, forKey: .lines))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lines, forKey: .lines)
    }

    /// Der reine Quelltext (Zeilen mit Zeilenumbruch verbunden).
    public var source: String { lines.map(\.code).joined(separator: "\n") }

    /// Zeilen mit Inhalt, denen im JSON noch keine Erklärung mitgegeben wurde.
    public var linesMissingExplanation: [Int] {
        lines.enumerated().compactMap { index, line in
            line.code.trimmingCharacters(in: .whitespaces).isEmpty || !(line.explain ?? "").isEmpty ? nil : index + 1
        }
    }

    /// Erklärte Zeilen: gespeicherte Erklärungen haben Vorrang, Lücken füllt der
    /// `CodeExplainer`. Befehle (Lexikon) werden immer automatisch ergänzt.
    public func explained() -> [ExplainedLine] {
        CodeExplainer.explain(source).map { auto in
            let index = auto.number - 1
            guard index < lines.count, let stored = lines[index].explain, !stored.isEmpty else { return auto }
            return ExplainedLine(number: auto.number, code: auto.code, explanation: stored, terms: auto.terms, isFallback: false)
        }
    }
}
