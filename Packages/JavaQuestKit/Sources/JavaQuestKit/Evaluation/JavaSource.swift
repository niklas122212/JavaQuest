import Foundation

/// Leichtgewichtige Java-Quelltextanalyse ohne Compiler: Kommentare entfernen,
/// Literale maskieren, Klammern und Semikolons prüfen.
public enum JavaSource {
    /// Ersetzt typografische Zeichen, die Tastaturen automatisch einsetzen
    /// („smarte“ Anführungszeichen, Gedankenstriche), durch ASCII.
    public static func normalizingTypography(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "\u{201C}", "\u{201D}", "\u{201E}", "\u{201F}", "\u{00AB}", "\u{00BB}": result.append("\"")
            case "\u{2018}", "\u{2019}", "\u{201A}", "\u{201B}": result.append("'")
            case "\u{2014}": result.append("--")
            case "\u{2013}": result.append("-")
            case "\u{2026}": result.append("...")
            case "\u{00A0}": result.append(" ")
            default: result.append(character)
            }
        }
        return result
    }

    /// Entfernt Kommentare; String- und Char-Literale bleiben unverändert.
    public static func strippingComments(_ source: String) -> String { scan(source).withoutComments }

    /// Entfernt Kommentare und leert Literale (`"abc"` → `""`), damit Regeln
    /// nicht versehentlich auf Text in Strings anspringen.
    public static func maskingLiterals(_ source: String) -> String { scan(source).masked }

    private enum State { case code, lineComment, blockComment, string, character, textBlock }

    private static func scan(_ source: String) -> (withoutComments: String, masked: String) {
        let chars = Array(source)
        var plain = ""
        var masked = ""
        var state = State.code
        var i = 0

        func peek(_ offset: Int) -> Character? {
            i + offset < chars.count ? chars[i + offset] : nil
        }

        while i < chars.count {
            let c = chars[i]
            switch state {
            case .code:
                if c == "/", peek(1) == "/" {
                    state = .lineComment
                    i += 2
                    continue
                }
                if c == "/", peek(1) == "*" {
                    state = .blockComment
                    plain.append(" ")
                    masked.append(" ")
                    i += 2
                    continue
                }
                if c == "\"", peek(1) == "\"", peek(2) == "\"" {
                    state = .textBlock
                    plain += "\"\"\""
                    masked += "\"\"\""
                    i += 3
                    continue
                }
                if c == "\"" { state = .string }
                if c == "'" { state = .character }
                plain.append(c)
                masked.append(c)

            case .lineComment:
                if c == "\n" {
                    state = .code
                    plain.append(c)
                    masked.append(c)
                }

            case .blockComment:
                if c == "*", peek(1) == "/" {
                    state = .code
                    i += 2
                    continue
                }
                if c == "\n" {
                    plain.append(c)
                    masked.append(c)
                }

            case .string, .character:
                let delimiter: Character = state == .string ? "\"" : "'"
                if c == "\\", let next = peek(1) {
                    plain.append(c)
                    plain.append(next)
                    i += 2
                    continue
                }
                if c == delimiter || c == "\n" {
                    // Zeilenende schließt ein nicht beendetes Literal, damit der Rest analysierbar bleibt.
                    state = .code
                    plain.append(c)
                    masked.append(c == "\n" ? "\n" : delimiter)
                } else {
                    plain.append(c)
                }

            case .textBlock:
                if c == "\"", peek(1) == "\"", peek(2) == "\"" {
                    state = .code
                    plain += "\"\"\""
                    masked += "\"\"\""
                    i += 3
                    continue
                }
                plain.append(c)
                if c == "\n" { masked.append(c) }
            }
            i += 1
        }
        return (plain, masked)
    }

    /// Prüft, ob (), [] und {} ausgeglichen sind. Erwartet maskierten Code.
    public static func delimiterIssues(in masked: String) -> [Finding] {
        let closing: [Character: Character] = [")": "(", "]": "[", "}": "{"]
        let closingFor: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
        var stack: [(symbol: Character, line: Int)] = []
        var line = 1
        for c in masked {
            if c == "\n" {
                line += 1
            } else if closingFor[c] != nil {
                stack.append((c, line))
            } else if let opening = closing[c] {
                guard let last = stack.last else {
                    return [.failed("Zeile \(line): „\(c)“ wird geschlossen, aber nie geöffnet.", line: line)]
                }
                guard last.symbol == opening else {
                    let expected = closingFor[last.symbol].map(String.init) ?? "?"
                    return [.failed(
                        "Zeile \(line): „\(c)“ passt nicht – erwartet wurde „\(expected)“ zu „\(last.symbol)“ aus Zeile \(last.line).",
                        line: line
                    )]
                }
                stack.removeLast()
            }
        }
        if let open = stack.last, let expected = closingFor[open.symbol] {
            return [.failed("„\(open.symbol)“ aus Zeile \(open.line) wird nicht mit „\(expected)“ geschlossen.", line: open.line)]
        }
        return []
    }

    private static let controlKeywords: Set<String> = [
        "if", "else", "for", "while", "do", "switch", "try", "catch", "finally", "case", "default", "synchronized",
    ]

    private static let declarationPattern = try? NSRegularExpression(pattern: #"\b(class|interface|enum|record)\b"#)

    /// Zeilennummern (1-basiert), in denen vermutlich ein Semikolon fehlt.
    /// Bewusst vorsichtig: lieber einen Fehler übersehen als korrekten Code ablehnen.
    public static func linesMissingSemicolon(in masked: String) -> [Int] {
        let lines = masked.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var result: [Int] = []

        for (index, line) in lines.enumerated() {
            guard let last = line.last else { continue }
            if ";{},:(".contains(last) { continue }
            if line.hasPrefix("@") || line.hasSuffix("\"\"\"") { continue }
            if line.hasSuffix("->") || line.hasSuffix("&&") || line.hasSuffix("||") { continue }
            let endsWithIncrement = line.hasSuffix("++") || line.hasSuffix("--")
            if "+-*/%=&|?<>!.^~".contains(last), !endsWithIncrement { continue }

            let head = line.drop { $0 == "}" || $0 == " " }
            let firstWord = String(head.prefix { $0.isLetter })
            if controlKeywords.contains(firstWord) { continue }

            let range = NSRange(line.startIndex..., in: line)
            if declarationPattern?.firstMatch(in: line, range: range) != nil { continue }

            if let next = lines[(index + 1)...].first(where: { !$0.isEmpty }) {
                if let first = next.first, "{.)+-*/&|?:".contains(first) { continue }
            }

            if last.isLetter || last.isNumber || ")]\"'_".contains(last) || endsWithIncrement {
                result.append(index + 1)
            }
        }
        return result
    }
}
