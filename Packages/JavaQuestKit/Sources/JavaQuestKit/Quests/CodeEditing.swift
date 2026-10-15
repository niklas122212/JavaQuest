import Foundation

/// Was der Code-Editor beim Tippen selbst erledigt – wie in einer echten IDE:
/// Einrückung nach `{`, schließende `}` zurück auf die Ebene ihrer `{`, Tab als vier Leerzeichen,
/// Tab/⇧Tab auf markierten Zeilen ein- und ausrücken, ⌘/ zum Auskommentieren,
/// Klammern und Anführungszeichen paarweise. Rein und ohne UI, damit iOS, macOS und Tests
/// dasselbe Verhalten haben. Positionen sind UTF-16-Offsets (wie bei `NSRange`).
public enum CodeEditing {
    public struct Edit: Sendable, Hashable {
        /// Dieser Bereich des Texts wird ersetzt …
        public let range: NSRange
        /// … durch diesen Text,
        public let replacement: String
        /// und danach steht der Cursor hier (Offset im neuen Text) …
        public let cursor: Int
        /// … mit so vielen markierten Zeichen dahinter (0 = nur der Cursor).
        public let selectionLength: Int

        public init(range: NSRange, replacement: String, cursor: Int, selectionLength: Int = 0) {
            self.range = range
            self.replacement = replacement
            self.cursor = cursor
            self.selectionLength = selectionLength
        }
    }

    public static let indentUnit = "    "

    /// Antwort auf eine Eingabe: `input` ersetzt `selection` in `text`. Nil heißt: normal eintippen.
    public static func edit(for input: String, in text: String, selection: NSRange) -> Edit? {
        let ns = text as NSString
        guard selection.location != NSNotFound, NSMaxRange(selection) <= ns.length else { return nil }
        switch input {
        case "\n", "\r", "\r\n":
            return newline(in: ns, selection: selection)
        case "\t":
            // Mit Auswahl rückt Tab die Zeilen ein, statt sie durch Leerzeichen zu ersetzen.
            if selection.length > 0 { return shiftLines(in: text, selection: selection, outdent: false) }
            let column = selection.location - lineStart(in: ns, at: selection.location)
            let spaces = String(repeating: " ", count: 4 - column % 4)
            return Edit(range: selection, replacement: spaces, cursor: selection.location + spaces.utf16.count)
        case "}":
            return closingBrace(in: ns, selection: selection)
        case "(", "[":
            // Nur vor Leerraum, Zeilenende oder schließenden Zeichen – mitten in einem Wort störte es.
            guard selection.length == 0, isBoundary(after: selection.location, in: ns), !isInsideLiteral(ns, at: selection.location) else { return nil }
            let pair = input == "(" ? "()" : "[]"
            return Edit(range: selection, replacement: pair, cursor: selection.location + 1)
        case ")", "]":
            // Über die schon vorhandene schließende Klammer hinwegtippen.
            if selection.length == 0, selection.location < ns.length, ns.substring(with: NSRange(location: selection.location, length: 1)) == input {
                return Edit(range: NSRange(location: selection.location, length: 0), replacement: "", cursor: selection.location + 1)
            }
            return nil
        case "\"":
            guard selection.length == 0 else { return nil }
            if selection.location < ns.length, ns.character(at: selection.location) == 0x22, isInsideLiteral(ns, at: selection.location) {
                return Edit(range: selection, replacement: "", cursor: selection.location + 1)
            }
            guard isBoundary(after: selection.location, in: ns), !isInsideLiteral(ns, at: selection.location) else { return nil }
            return Edit(range: selection, replacement: "\"\"", cursor: selection.location + 1)
        default:
            return nil
        }
    }

    /// Fügt ein Stück Code (Bauplan, Symbolleiste) an der Cursorstelle ein. Mehrzeiliges rückt auf die
    /// Ebene der aktuellen Zeile ein und beginnt in einer neuen Zeile, wenn davor schon Code steht.
    public static func insertion(_ snippet: String, in text: String, selection: NSRange) -> Edit {
        let ns = text as NSString
        let location = min(selection.location, ns.length)
        let range = NSRange(location: location, length: min(selection.length, ns.length - location))
        guard snippet.contains("\n") else {
            return Edit(range: range, replacement: snippet, cursor: location + snippet.utf16.count)
        }
        let start = lineStart(in: ns, at: location)
        let before = ns.substring(with: NSRange(location: start, length: location - start))
        let indent = indentation(of: before)
        let lines = snippet.components(separatedBy: "\n")
        var body = lines.enumerated().map { index, line in index == 0 || line.isEmpty ? line : indent + line }.joined(separator: "\n")
        if !before.trimmingCharacters(in: .whitespaces).isEmpty { body = "\n" + indent + body }
        return Edit(range: range, replacement: body, cursor: location + body.utf16.count)
    }

    /// Rückt die Zeilen ein bzw. aus, die die Auswahl berührt (Tab/⇧Tab, ⌘]/⌘[) – um vier Leerzeichen.
    /// Leere Zeilen bleiben leer. Mit Auswahl sind danach die ganzen Zeilen markiert, sodass man weiter
    /// schieben kann; ohne bleibt der Cursor an seiner Stelle im Code. Nil: Es gibt nichts zu tun.
    public static func shiftLines(in text: String, selection: NSRange, outdent: Bool) -> Edit? {
        let ns = text as NSString
        guard selection.location != NSNotFound, NSMaxRange(selection) <= ns.length else { return nil }
        let block = touchedLines(in: ns, selection: selection)
        let lines = ns.substring(with: block).components(separatedBy: "\n")
        let shifted = lines.map { line -> String in
            if outdent {
                let remove = line.hasPrefix("\t") ? 1 : min(line.prefix { $0 == " " }.count, indentUnit.count)
                return String(line.dropFirst(remove))
            }
            return line.allSatisfy { $0 == " " || $0 == "\t" } ? line : indentUnit + line
        }
        return lineEdit(in: ns, block: block, selection: selection, lines: lines, changed: shifted, at: { _ in 0 })
    }

    /// ⌘/: Stehen vor allen markierten Codezeilen schon `//`, fallen sie weg – sonst kommt `// ` davor,
    /// und zwar auf die Spalte der am wenigsten eingerückten Zeile (die Einrückung bleibt sauber).
    public static func toggleComment(in text: String, selection: NSRange) -> Edit? {
        let ns = text as NSString
        guard selection.location != NSNotFound, NSMaxRange(selection) <= ns.length else { return nil }
        let block = touchedLines(in: ns, selection: selection)
        let lines = ns.substring(with: block).components(separatedBy: "\n")
        let code = lines.filter { !$0.allSatisfy { $0 == " " || $0 == "\t" } }
        guard !code.isEmpty else { return nil }
        let uncomment = code.allSatisfy { $0.drop { $0 == " " || $0 == "\t" }.hasPrefix("//") }
        let column = code.map { indentation(of: $0).count }.min() ?? 0
        let changed = lines.map { line -> String in
            guard !line.allSatisfy({ $0 == " " || $0 == "\t" }) else { return line }
            let indent = indentation(of: line)
            if uncomment {
                var rest = line.dropFirst(indent.count + 2)
                if rest.hasPrefix(" ") { rest = rest.dropFirst() }
                return indent + rest
            }
            return String(line.prefix(column)) + "// " + String(line.dropFirst(column))
        }
        return lineEdit(in: ns, block: block, selection: selection, lines: lines, changed: changed) { line in
            uncomment ? indentation(of: line).utf16.count : column
        }
    }

    /// Die Einrückung einer Zeile – Leerzeichen (und Tabs) am Zeilenanfang.
    public static func indentation(of line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    // MARK: Eingaben

    private static func newline(in ns: NSString, selection: NSRange) -> Edit {
        let start = lineStart(in: ns, at: selection.location)
        let line = ns.substring(with: NSRange(location: start, length: selection.location - start))
        let indent = indentation(of: line)
        let before = line.trimmingCharacters(in: .whitespaces)
        let afterRange = NSRange(location: NSMaxRange(selection), length: lineEnd(in: ns, at: NSMaxRange(selection)) - NSMaxRange(selection))
        let after = ns.substring(with: afterRange).trimmingCharacters(in: .whitespaces)
        let opens = before.hasSuffix("{")

        guard opens else {
            // Nach `case …:` eine Stufe tiefer, sonst wie die Zeile davor.
            let extra = before.hasSuffix(":") && (before.hasPrefix("case ") || before.hasPrefix("default")) ? indentUnit : ""
            let inserted = "\n" + indent + extra
            return Edit(range: selection, replacement: inserted, cursor: selection.location + inserted.utf16.count)
        }
        let inner = indent + indentUnit
        if after.hasPrefix("}") {
            // `{|}` → Klammer auf eigene Zeile, Cursor dazwischen.
            let trailing = NSRange(location: NSMaxRange(selection), length: leadingWhitespace(in: ns, from: NSMaxRange(selection)))
            let range = NSUnionRange(selection, trailing)
            let inserted = "\n" + inner + "\n" + indent
            return Edit(range: range, replacement: inserted, cursor: selection.location + 1 + inner.utf16.count)
        }
        if after.isEmpty, needsClosingBrace(ns, opening: selection.location) {
            let inserted = "\n" + inner + "\n" + indent + "}"
            return Edit(range: selection, replacement: inserted, cursor: selection.location + 1 + inner.utf16.count)
        }
        let inserted = "\n" + inner
        return Edit(range: selection, replacement: inserted, cursor: selection.location + inserted.utf16.count)
    }

    private static func closingBrace(in ns: NSString, selection: NSRange) -> Edit? {
        let start = lineStart(in: ns, at: selection.location)
        let line = ns.substring(with: NSRange(location: start, length: selection.location - start))
        // Nur, wenn vor der Klammer in dieser Zeile nichts steht.
        guard line.allSatisfy({ $0 == " " || $0 == "\t" }) else { return nil }
        // Steht die passende } schon da (der Editor hat sie nach Enter gesetzt), springt der Cursor
        // hinter sie – statt eine zweite Klammer zu schreiben, die zu viel wäre.
        let code = codeUnits(ns)
        if selection.length == 0, code.filter({ $0 == 0x7D }).count >= code.filter({ $0 == 0x7B }).count {
            var next = NSMaxRange(selection)
            while next < ns.length, [0x20, 0x09, 0x0A, 0x0D].contains(ns.character(at: next)) { next += 1 }
            if next < ns.length, code[next] == 0x7D {
                let braceLine = lineStart(in: ns, at: next)
                let removed = NSRange(location: start, length: braceLine - start)
                return Edit(range: removed, replacement: "", cursor: next + 1 - removed.length)
            }
        }
        let target = matchingIndent(in: ns, before: start)
        guard target != line else { return nil }
        let range = NSRange(location: start, length: NSMaxRange(selection) - start)
        let inserted = target + "}"
        return Edit(range: range, replacement: inserted, cursor: start + inserted.utf16.count)
    }

    // MARK: Hilfen

    /// Die ganzen Zeilen, die die Auswahl berührt – ohne den letzten Zeilenumbruch. Endet die Auswahl
    /// direkt am Anfang einer Zeile, gehört diese Zeile nicht mehr dazu (wie in jeder IDE).
    private static func touchedLines(in ns: NSString, selection: NSRange) -> NSRange {
        let start = lineStart(in: ns, at: selection.location)
        var last = NSMaxRange(selection)
        if selection.length > 0, ns.character(at: last - 1) == 0x0A { last -= 1 }
        return NSRange(location: start, length: max(lineEnd(in: ns, at: last), start) - start)
    }

    /// Ersetzt die Zeilen `block` durch `changed`. Ohne Auswahl wandert der Cursor mit seinem Code mit;
    /// `at` nennt die Spalte, an der sich die erste Zeile ändert.
    private static func lineEdit(in ns: NSString, block: NSRange, selection: NSRange, lines: [String], changed: [String],
                                 at: (String) -> Int) -> Edit? {
        let replacement = changed.joined(separator: "\n")
        guard replacement != lines.joined(separator: "\n") else { return nil }
        guard selection.length == 0 else {
            return Edit(range: block, replacement: replacement, cursor: block.location, selectionLength: replacement.utf16.count)
        }
        let column = selection.location - block.location
        let start = at(lines[0])
        let delta = changed[0].utf16.count - lines[0].utf16.count
        // Vor der Änderungsstelle bleibt der Cursor stehen; genau auf ihr wandert er mit Eingefügtem mit.
        let moved = column < start || (column == start && delta < 0) ? column : max(start, column + delta)
        return Edit(range: block, replacement: replacement, cursor: block.location + min(moved, changed[0].utf16.count))
    }

    static func lineStart(in ns: NSString, at location: Int) -> Int {
        ns.lineRange(for: NSRange(location: location, length: 0)).location
    }

    static func lineEnd(in ns: NSString, at location: Int) -> Int {
        var end = 0
        var contentsEnd = 0
        ns.getLineStart(nil, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
        return contentsEnd
    }

    private static func leadingWhitespace(in ns: NSString, from location: Int) -> Int {
        var i = location
        while i < ns.length, ns.character(at: i) == 0x20 || ns.character(at: i) == 0x09 { i += 1 }
        return i - location
    }

    private static func isBoundary(after location: Int, in ns: NSString) -> Bool {
        guard location < ns.length else { return true }
        let next = Character(UnicodeScalar(ns.character(at: location)) ?? " ")
        return next.isWhitespace || ")];,".contains(next)
    }

    /// Steht die Stelle in einem String- oder Char-Literal? (Nur die aktuelle Zeile zählt – Literale enden am Zeilenende.)
    private static func isInsideLiteral(_ ns: NSString, at location: Int) -> Bool {
        let start = lineStart(in: ns, at: location)
        let line = Array(ns.substring(with: NSRange(location: start, length: location - start)))
        var quote: Character?
        var i = 0
        while i < line.count {
            let c = line[i]
            if let q = quote {
                if c == "\\" { i += 1 } else if c == q { quote = nil }
            } else if c == "\"" || c == "'" {
                quote = c
            } else if c == "/", i + 1 < line.count, line[i + 1] == "/" {
                return false
            }
            i += 1
        }
        return quote != nil
    }

    /// Fehlt zur `{` vor `opening` noch eine `}`? Gezählt wird ohne Kommentare und Literale.
    private static func needsClosingBrace(_ ns: NSString, opening: Int) -> Bool {
        let code = codeUnits(ns)
        return code.filter { $0 == 0x7B }.count > code.filter { $0 == 0x7D }.count
    }

    /// Der Text als UTF-16, Kommentare und Literale durch Leerzeichen ersetzt – gleich lang wie das Original.
    static func codeUnits(_ ns: NSString) -> [UInt16] {
        var units = (0..<ns.length).map { ns.character(at: $0) }
        enum State { case code, line, block, literal(UInt16) }
        var state = State.code
        var i = 0
        while i < units.count {
            let c = units[i]
            let next: UInt16? = i + 1 < units.count ? units[i + 1] : nil
            switch state {
            case .code:
                if c == 0x2F, next == 0x2F { state = .line; units[i] = 0x20 }
                else if c == 0x2F, next == 0x2A { state = .block; units[i] = 0x20; units[i + 1] = 0x20; i += 1 }
                else if c == 0x22 || c == 0x27 { state = .literal(c) }
            case .line:
                if c == 0x0A { state = .code } else { units[i] = 0x20 }
            case .block:
                if c == 0x2A, next == 0x2F { units[i] = 0x20; units[i + 1] = 0x20; i += 1; state = .code }
                else if c != 0x0A { units[i] = 0x20 }
            case .literal(let quote):
                if c == 0x5C, next != nil, next != 0x0A { units[i] = 0x20; units[i + 1] = 0x20; i += 1 }
                else if c == quote || c == 0x0A { state = .code }
                else { units[i] = 0x20 }
            }
            i += 1
        }
        return units
    }

    /// Die Einrückung der Zeile mit der passenden `{` – dort hin gehört die `}`.
    private static func matchingIndent(in ns: NSString, before location: Int) -> String {
        let code = codeUnits(ns.substring(to: location) as NSString)
        var depth = 0
        var i = code.count - 1
        while i >= 0 {
            let c = code[i]
            if c == 0x7D { depth += 1 }
            if c == 0x7B {
                if depth == 0 {
                    let start = lineStart(in: ns, at: i)
                    return indentation(of: ns.substring(with: NSRange(location: start, length: i - start)))
                }
                depth -= 1
            }
            i -= 1
        }
        return ""
    }
}
