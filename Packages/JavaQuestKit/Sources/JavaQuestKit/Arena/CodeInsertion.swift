import Foundation

/// Fügt einen Befehl oder eine Vorlage aus der Befehlsleiste in den Code ein – als eigene Zeile,
/// richtig eingerückt und an der Stelle, an der man gerade schreibt.
///
/// Vorher landete alles am Ende des Codes. Bei einem Startcode wie
/// `while (!robot.atGoal()) { // … }` stand `robot.move();` dann hinter der Schleife statt darin.
public enum CodeInsertion {
    /// - Parameters:
    ///   - cursor: Position im Code (UTF-16), an der man gerade schreibt – oder nil, wenn sie unbekannt ist.
    ///     Steht sie am Anfang einer Zeile, kommt der Befehl davor, sonst dahinter.
    ///     Ohne Position kommt er in den ersten leeren Block mit Platzhalter-Kommentar
    ///     (`// Was soll in jeder Runde passieren?` direkt vor `}`), sonst ans Ende.
    /// - Returns: der neue Code und die Position direkt hinter dem Eingefügten (UTF-16) –
    ///   dort geht es beim nächsten Antippen weiter.
    public static func insert(_ snippet: String, into code: String, cursor: Int?) -> (code: String, cursor: Int) {
        var lines = code.components(separatedBy: "\n")
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (snippet, snippet.utf16.count)
        }

        var index: Int
        var before = false
        if let cursor {
            (index, before) = position(of: cursor, in: lines)
        } else {
            index = placeholderLine(in: lines) ?? lastCodeLine(in: lines)
        }

        let line = lines[index]
        let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
        var indent = String(line.prefix { $0 == " " || $0 == "\t" })
        if !before, !isBlank, opensBlock(line) { indent += "    " }
        let block = snippet.components(separatedBy: "\n").map { $0.isEmpty ? $0 : indent + $0 }

        let insertAt: Int
        if isBlank {
            // Eine leere Zeile wird zur Befehlszeile.
            lines.replaceSubrange(index...index, with: block)
            insertAt = index
        } else {
            insertAt = before ? index : index + 1
            lines.insert(contentsOf: block, at: insertAt)
        }
        let lastInserted = insertAt + block.count - 1
        let newCursor = lines[...lastInserted].map { $0.utf16.count }.reduce(0, +) + lastInserted
        return (lines.joined(separator: "\n"), newCursor)
    }

    /// Zeile, in der der Cursor steht – und ob er vor ihrem ersten Zeichen steht.
    private static func position(of cursor: Int, in lines: [String]) -> (line: Int, before: Bool) {
        var offset = 0
        for (index, line) in lines.enumerated() {
            let length = line.utf16.count
            if cursor <= offset + length {
                let column = cursor - offset
                let leading = line.utf16.prefix { $0 == 32 || $0 == 9 }.count
                let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
                return (index, !isBlank && column <= leading)
            }
            offset += length + 1
        }
        return (lines.count - 1, false)
    }

    /// Ein Kommentar direkt vor einer schließenden Klammer: der Platzhalter eines leeren Blocks.
    private static func placeholderLine(in lines: [String]) -> Int? {
        lines.indices.dropLast().first { index in
            lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("//")
                && lines[index + 1].trimmingCharacters(in: .whitespaces).hasPrefix("}")
        }
    }

    /// Die letzte Zeile mit Inhalt – Leerzeilen am Ende bleiben dahinter.
    private static func lastCodeLine(in lines: [String]) -> Int {
        lines.lastIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? lines.count - 1
    }

    private static func opensBlock(_ line: String) -> Bool {
        let code = line.components(separatedBy: "//").first ?? line
        return code.trimmingCharacters(in: .whitespaces).hasSuffix("{")
    }
}
