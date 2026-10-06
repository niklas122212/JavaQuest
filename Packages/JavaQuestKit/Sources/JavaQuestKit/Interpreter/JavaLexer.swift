import Foundation

struct JavaToken: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case identifier
        case keyword
        case intLiteral
        case longLiteral
        case doubleLiteral
        case stringLiteral
        case charLiteral
        case symbol
        case end
    }

    let kind: Kind
    /// Bei Literalen der bereits entschlüsselte Wert (ohne Anführungszeichen, Escapes aufgelöst).
    let text: String
    let line: Int

    func `is`(_ symbol: String) -> Bool { (kind == .symbol || kind == .keyword) && text == symbol }
}

/// Zerlegt Java-Quelltext in Tokens. Kommentare und Leerraum fallen weg.
enum JavaLexer {
    static let keywords: Set<String> = [
        "abstract", "boolean", "break", "byte", "case", "catch", "char", "class", "continue", "default",
        "do", "double", "else", "enum", "extends", "final", "finally", "float", "for", "if", "implements",
        "import", "instanceof", "int", "interface", "long", "new", "null", "package", "private", "protected",
        "public", "return", "short", "static", "super", "switch", "this", "throw", "throws", "true", "false",
        "try", "void", "while", "var", "yield", "record",
    ]

    /// Mehrzeichen-Operatoren zuerst, damit `>>>=` nicht als `>` `>` … zerfällt.
    private static let symbols: [String] = [
        ">>>=", "<<=", ">>=", ">>>", "...", "->", "::", "++", "--", "&&", "||", "==", "!=", "<=", ">=",
        "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<", ">>",
        "(", ")", "{", "}", "[", "]", ";", ",", ".", "=", "<", ">", "!", "~", "?", ":",
        "+", "-", "*", "/", "%", "&", "|", "^", "@",
    ]

    static func tokenize(_ source: String) throws(JavaProblem) -> [JavaToken] {
        let chars = Array(JavaSource.normalizingTypography(source))
        var tokens: [JavaToken] = []
        var i = 0
        var line = 1

        func peek(_ offset: Int = 0) -> Character? { i + offset < chars.count ? chars[i + offset] : nil }

        while i < chars.count {
            let c = chars[i]
            if c == "\n" { line += 1; i += 1; continue }
            if c.isWhitespace { i += 1; continue }

            // Kommentare
            if c == "/", peek(1) == "/" {
                while i < chars.count, chars[i] != "\n" { i += 1 }
                continue
            }
            if c == "/", peek(1) == "*" {
                let startLine = line
                i += 2
                while i < chars.count, !(chars[i] == "*" && peek(1) == "/") {
                    if chars[i] == "\n" { line += 1 }
                    i += 1
                }
                guard i < chars.count else { throw .syntax("Der Kommentar /* … wird nie mit */ geschlossen.", line: startLine) }
                i += 2
                continue
            }

            // Zahlen
            if c.isNumber || (c == "." && (peek(1)?.isNumber ?? false)) {
                var text = ""
                var isDouble = false
                if c == "0", let x = peek(1), x == "x" || x == "X" {
                    i += 2
                    var hex = ""
                    while let d = peek(), d.isHexDigit || d == "_" { if d != "_" { hex.append(d) }; i += 1 }
                    let isLong = peek() == "L" || peek() == "l"
                    if isLong { i += 1 }
                    guard let value = UInt64(hex, radix: 16) else { throw .syntax("„0x\(hex)“ ist keine gültige Hexadezimalzahl.", line: line) }
                    tokens.append(JavaToken(kind: isLong ? .longLiteral : .intLiteral, text: String(Int64(bitPattern: value)), line: line))
                    continue
                }
                while let d = peek(), d.isNumber || d == "_" || d == "." || d == "e" || d == "E"
                        || ((d == "+" || d == "-") && (text.last == "e" || text.last == "E")) {
                    if d == "." {
                        // `1..` gibt es nicht; ein Punkt gefolgt von einem Buchstaben ist ein Methodenaufruf.
                        guard let next = peek(1), next.isNumber || !next.isLetter else { break }
                        if isDouble { break }
                        isDouble = true
                    }
                    if d == "e" || d == "E" { isDouble = true }
                    if d != "_" { text.append(d) }
                    i += 1
                }
                if let suffix = peek(), "lLdDfF".contains(suffix) {
                    i += 1
                    switch suffix {
                    case "l", "L":
                        tokens.append(JavaToken(kind: .longLiteral, text: text, line: line))
                    case "f", "F":
                        throw .unsupported("float-Zahlen (mit f am Ende) kennt der eingebaute Interpreter nicht – nimm double.", line: line)
                    default:
                        tokens.append(JavaToken(kind: .doubleLiteral, text: text, line: line))
                    }
                    continue
                }
                tokens.append(JavaToken(kind: isDouble ? .doubleLiteral : .intLiteral, text: text, line: line))
                continue
            }

            // Namen und Schlüsselwörter
            if c.isLetter || c == "_" || c == "$" {
                var text = ""
                while let d = peek(), d.isLetter || d.isNumber || d == "_" || d == "$" { text.append(d); i += 1 }
                tokens.append(JavaToken(kind: keywords.contains(text) ? .keyword : .identifier, text: text, line: line))
                continue
            }

            // Text-Blöcke """…""" werden nicht unterstützt, normale Strings schon.
            if c == "\"" {
                if peek(1) == "\"", peek(2) == "\"" {
                    throw .unsupported("Text-Blöcke (\"\"\") kennt der eingebaute Interpreter nicht.", line: line)
                }
                i += 1
                var value = ""
                while true {
                    guard let d = peek(), d != "\n" else {
                        throw .syntax("Der Text wird nicht mit \" geschlossen.", line: line)
                    }
                    if d == "\"" { i += 1; break }
                    if d == "\\" {
                        value.append(try escape(chars, &i, line: line))
                        continue
                    }
                    value.append(d)
                    i += 1
                }
                tokens.append(JavaToken(kind: .stringLiteral, text: value, line: line))
                continue
            }
            if c == "'" {
                i += 1
                var value = ""
                if peek() == "\\" {
                    value.append(try escape(chars, &i, line: line))
                } else if let d = peek(), d != "'", d != "\n" {
                    value.append(d)
                    i += 1
                }
                guard peek() == "'", value.count == 1 else {
                    throw .syntax("Ein char steht in einfachen Anführungszeichen und enthält genau ein Zeichen, z. B. 'a'.", line: line)
                }
                i += 1
                tokens.append(JavaToken(kind: .charLiteral, text: value, line: line))
                continue
            }

            if let symbol = symbols.first(where: { matches($0, chars, at: i) }) {
                tokens.append(JavaToken(kind: .symbol, text: symbol, line: line))
                i += symbol.count
                continue
            }
            throw .syntax("Das Zeichen „\(c)“ gehört nicht in Java-Code.", line: line)
        }
        tokens.append(JavaToken(kind: .end, text: "", line: line))
        return tokens
    }

    private static func matches(_ symbol: String, _ chars: [Character], at index: Int) -> Bool {
        var j = index
        for s in symbol {
            guard j < chars.count, chars[j] == s else { return false }
            j += 1
        }
        return true
    }

    private static func escape(_ chars: [Character], _ i: inout Int, line: Int) throws(JavaProblem) -> Character {
        guard i + 1 < chars.count else { throw .syntax("Nach \\ fehlt ein Zeichen.", line: line) }
        let e = chars[i + 1]
        i += 2
        switch e {
        case "n": return "\n"
        case "t": return "\t"
        case "r": return "\r"
        case "b": return "\u{8}"
        case "f": return "\u{C}"
        case "0": return "\0"
        case "\\": return "\\"
        case "'": return "'"
        case "\"": return "\""
        case "u":
            var hex = ""
            while hex.count < 4, i < chars.count, chars[i].isHexDigit { hex.append(chars[i]); i += 1 }
            guard hex.count == 4, let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) else {
                throw .syntax("\\u braucht genau vier Hex-Ziffern, z. B. \\u00e4.", line: line)
            }
            return Character(scalar)
        default:
            throw .syntax("„\\\(e)“ ist keine gültige Escape-Sequenz.", line: line)
        }
    }
}
