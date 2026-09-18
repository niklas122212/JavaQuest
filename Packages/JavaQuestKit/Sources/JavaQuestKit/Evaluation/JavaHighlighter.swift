import Foundation

/// Minimaler Tokenizer für Syntaxhervorhebung. Die Farben vergibt die App.
public enum JavaHighlighter {
    public enum TokenKind: Sendable, Hashable {
        case plain, keyword, type, string, number, comment, annotation
    }

    public struct Token: Sendable, Hashable {
        public let text: String
        public let kind: TokenKind
    }

    static let keywords: Set<String> = [
        "abstract", "boolean", "break", "byte", "case", "catch", "char", "class", "continue", "default", "do",
        "double", "else", "enum", "extends", "final", "finally", "float", "for", "if", "implements", "import",
        "instanceof", "int", "interface", "long", "new", "null", "package", "private", "protected", "public",
        "record", "return", "short", "static", "super", "switch", "this", "throw", "throws", "true", "false",
        "try", "var", "void", "while", "yield",
    ]

    public static func tokenize(_ code: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(code)
        var i = 0

        func append(_ start: Int, _ end: Int, _ kind: TokenKind) {
            let text = String(chars[start..<end])
            if kind == .plain, let last = tokens.last, last.kind == .plain {
                tokens[tokens.count - 1] = Token(text: last.text + text, kind: .plain)
            } else {
                tokens.append(Token(text: text, kind: kind))
            }
        }

        while i < chars.count {
            let c = chars[i]
            let start = i
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                while i < chars.count, chars[i] != "\n" { i += 1 }
                append(start, i, .comment)
            } else if c == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                i += 2
                while i < chars.count, !(chars[i] == "*" && i + 1 < chars.count && chars[i + 1] == "/") { i += 1 }
                i = min(i + 2, chars.count)
                append(start, i, .comment)
            } else if c == "\"" || c == "'" {
                i += 1
                while i < chars.count, chars[i] != c, chars[i] != "\n" {
                    i += chars[i] == "\\" ? 2 : 1
                }
                i = min(i + 1, chars.count)
                append(start, i, .string)
            } else if c == "@", i + 1 < chars.count, chars[i + 1].isLetter {
                i += 1
                while i < chars.count, chars[i].isLetter || chars[i].isNumber { i += 1 }
                append(start, i, .annotation)
            } else if c.isNumber {
                while i < chars.count, chars[i].isNumber || chars[i] == "." || chars[i] == "_" || chars[i].isLetter { i += 1 }
                append(start, i, .number)
            } else if c.isLetter || c == "_" {
                while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" { i += 1 }
                let word = String(chars[start..<i])
                let kind: TokenKind = keywords.contains(word) ? .keyword : (word.first?.isUppercase == true ? .type : .plain)
                append(start, i, kind)
            } else {
                i += 1
                append(start, i, .plain)
            }
        }
        return tokens
    }
}
