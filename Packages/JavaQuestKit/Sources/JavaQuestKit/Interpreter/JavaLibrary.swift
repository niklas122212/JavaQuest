import Foundation

/// Die Teile der Java-Standardbibliothek, die Anfänger-Programme typischerweise brauchen.
enum JavaLibrary {
    // MARK: Statische Methoden

    static func callStatic(_ className: String, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch className {
        case "Math": return try math(name, args, line: line, interpreter: interpreter)
        case "Integer", "Long", "Double", "Boolean": return try wrapper(className, name, args, line: line)
        case "String": return try stringStatic(name, args, line: line)
        case "Character": return try character(name, args, line: line)
        case "Arrays": return try arrays(name, args, line: line, interpreter: interpreter)
        case "System":
            throw .unsupported("System.\(name) kennt der eingebaute Interpreter nicht.", line: line)
        default:
            if className.first?.isUppercase == true {
                throw .unsupported("Die Klasse \(className) kennt der eingebaute Interpreter nicht.", line: line)
            }
            throw .syntax("„\(className)“ kennt Java hier nicht. Ist die Variable deklariert und richtig geschrieben?", line: line)
        }
    }

    private static func arity(_ args: [JavaValue], _ count: Int, _ name: String, line: Int) throws(JavaProblem) {
        guard args.count == count else {
            throw .syntax("\(name) erwartet \(count) Wert(e) in den Klammern, bekommt aber \(args.count).", line: line)
        }
    }

    private static func number(_ value: JavaValue, _ name: String, line: Int) throws(JavaProblem) -> Numeric {
        guard let number = Numeric(value) else {
            throw .syntax("\(name) rechnet nur mit Zahlen, nicht mit \(value.typeName).", line: line)
        }
        return number
    }

    private static func doubleArg(_ value: JavaValue, _ name: String, line: Int) throws(JavaProblem) -> Double {
        try number(value, name, line: line).toDouble
    }

    private static func intArg(_ value: JavaValue, _ name: String, line: Int) throws(JavaProblem) -> Int32 {
        guard let number = Numeric(value), case .int(let v) = number else {
            throw .syntax("\(name) erwartet hier eine ganze Zahl (int), bekommt aber \(value.typeName).", line: line)
        }
        return v
    }

    private static func stringArg(_ value: JavaValue, _ name: String, line: Int) throws(JavaProblem) -> String {
        switch value {
        case .string(let text): return text.text
        case .null: throw .runtime("NullPointerException: \(name) bekommt null statt eines Textes.", line: line)
        default: throw .syntax("\(name) erwartet einen Text (String), bekommt aber \(value.typeName).", line: line)
        }
    }

    private static func math(_ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        let label = "Math.\(name)"
        switch name {
        case "random":
            try arity(args, 0, label, line: line)
            return .double(interpreter.nextRandom())
        case "abs":
            try arity(args, 1, label, line: line)
            switch try number(args[0], label, line: line) {
            case .int(let v): return .int(v == Int32.min ? v : abs(v))
            case .long(let v): return .long(v == Int64.min ? v : abs(v))
            case .double(let v): return .double(abs(v))
            }
        case "max", "min":
            try arity(args, 2, label, line: line)
            let (a, b) = Numeric.promote(try number(args[0], label, line: line), try number(args[1], label, line: line))
            if a.isNaN || b.isNaN { return .double(.nan) }
            let order = Numeric.compare(a, b)
            let pickFirst = name == "max" ? order != .orderedAscending : order != .orderedDescending
            return (pickFirst ? a : b).value
        case "pow":
            try arity(args, 2, label, line: line)
            return .double(Foundation.pow(try doubleArg(args[0], label, line: line), try doubleArg(args[1], label, line: line)))
        case "round":
            try arity(args, 1, label, line: line)
            let v = try doubleArg(args[0], label, line: line)
            // Java rundet .5 immer nach oben (auch bei negativen Zahlen: -2.5 → -2).
            return .long(Numeric.double((v + 0.5).rounded(.down)).toInt64)
        case "floorDiv", "floorMod":
            try arity(args, 2, label, line: line)
            let (a, b) = Numeric.promote(try number(args[0], label, line: line), try number(args[1], label, line: line))
            guard !a.isDouble else { throw .syntax("\(label) rechnet nur mit ganzen Zahlen.", line: line) }
            if b.isZeroIntegral { throw .runtime("ArithmeticException: / by zero", line: line) }
            let x = a.toInt64, y = b.toInt64
            var quotient = x / y
            if (x % y != 0) && ((x < 0) != (y < 0)) { quotient -= 1 }
            let result = name == "floorDiv" ? quotient : x - quotient * y
            if case .int = a { return .int(Int32(truncatingIfNeeded: result)) }
            return .long(result)
        case "hypot":
            try arity(args, 2, label, line: line)
            return .double(Foundation.hypot(try doubleArg(args[0], label, line: line), try doubleArg(args[1], label, line: line)))
        case "signum":
            try arity(args, 1, label, line: line)
            let v = try doubleArg(args[0], label, line: line)
            return .double(v > 0 ? 1 : (v < 0 ? -1 : v))
        default:
            let unary: [String: (Double) -> Double] = [
                "sqrt": Foundation.sqrt, "cbrt": Foundation.cbrt, "floor": Foundation.floor, "ceil": Foundation.ceil,
                "log": Foundation.log, "log10": Foundation.log10, "exp": Foundation.exp,
                "sin": Foundation.sin, "cos": Foundation.cos, "tan": Foundation.tan,
                "toRadians": { $0 * .pi / 180 }, "toDegrees": { $0 * 180 / .pi },
            ]
            guard let function = unary[name] else {
                throw .unsupported("\(label) kennt der eingebaute Interpreter nicht.", line: line)
            }
            try arity(args, 1, label, line: line)
            return .double(function(try doubleArg(args[0], label, line: line)))
        }
    }

    private static func wrapper(_ className: String, _ name: String, _ args: [JavaValue], line: Int) throws(JavaProblem) -> JavaValue {
        let label = "\(className).\(name)"
        switch (className, name) {
        case ("Integer", "parseInt"), ("Integer", "valueOf"):
            try arity(args, 1, label, line: line)
            guard let text = args[0].stringValue else {
                guard name == "valueOf" else { _ = try stringArg(args[0], label, line: line); return .void }
                return .int(try intArg(args[0], label, line: line))
            }
            guard let value = Int32(text.hasPrefix("+") ? String(text.dropFirst()) : text) else {
                throw .runtime("NumberFormatException: For input string: \"\(text)\" – das ist keine ganze Zahl.", line: line)
            }
            return .int(value)
        case ("Long", "parseLong"), ("Long", "valueOf"):
            try arity(args, 1, label, line: line)
            let text = try stringArg(args[0], label, line: line)
            guard let value = Int64(text) else {
                throw .runtime("NumberFormatException: For input string: \"\(text)\"", line: line)
            }
            return .long(value)
        case ("Double", "parseDouble"), ("Double", "valueOf"):
            try arity(args, 1, label, line: line)
            if let number = Numeric(args[0]) { return .double(number.toDouble) }
            let text = try stringArg(args[0], label, line: line).trimmingCharacters(in: .whitespaces)
            guard let value = Double(text) else {
                throw .runtime("NumberFormatException: For input string: \"\(text)\" – das ist keine Zahl (Kommazahlen mit Punkt schreiben).", line: line)
            }
            return .double(value)
        case ("Boolean", "parseBoolean"):
            try arity(args, 1, label, line: line)
            if case .null = args[0] { return .boolean(false) }
            return .boolean(try stringArg(args[0], label, line: line).lowercased() == "true")
        case (_, "toString"):
            try arity(args, 1, label, line: line)
            return .str(args[0].javaString)
        case ("Integer", "toBinaryString"):
            try arity(args, 1, label, line: line)
            return .str(String(UInt32(bitPattern: try intArg(args[0], label, line: line)), radix: 2))
        case ("Integer", "compare"), ("Double", "compare"), ("Long", "compare"):
            try arity(args, 2, label, line: line)
            let order = Numeric.compare(try number(args[0], label, line: line), try number(args[1], label, line: line))
            return .int(order == .orderedAscending ? -1 : (order == .orderedDescending ? 1 : 0))
        case ("Integer", "sum"):
            try arity(args, 2, label, line: line)
            return .int(try intArg(args[0], label, line: line) &+ (try intArg(args[1], label, line: line)))
        case ("Integer", "max"), ("Integer", "min"):
            try arity(args, 2, label, line: line)
            let a = try intArg(args[0], label, line: line), b = try intArg(args[1], label, line: line)
            return .int(name == "max" ? max(a, b) : min(a, b))
        default:
            throw .unsupported("\(label) kennt der eingebaute Interpreter nicht.", line: line)
        }
    }

    private static func stringStatic(_ name: String, _ args: [JavaValue], line: Int) throws(JavaProblem) -> JavaValue {
        switch name {
        case "valueOf":
            try arity(args, 1, "String.valueOf", line: line)
            if case .array(let array) = args[0], array.elementType == .char {
                return .str(array.elements.map(\.javaString).joined())
            }
            return .str(args[0].javaString)
        case "format":
            guard let pattern = args.first?.stringValue else {
                throw .syntax("String.format braucht als Erstes einen Format-Text.", line: line)
            }
            return .str(try JavaFormat.format(pattern, Array(args.dropFirst()), line: line))
        case "join":
            guard args.count >= 2 else { throw .syntax("String.join braucht ein Trennzeichen und Texte.", line: line) }
            let separator = try stringArg(args[0], "String.join", line: line)
            var parts: [String] = []
            if args.count == 2, case .array(let array) = args[1] {
                parts = array.elements.map(\.javaString)
            } else {
                parts = try args.dropFirst().map { (value) throws(JavaProblem) in try stringArg(value, "String.join", line: line) }
            }
            return .str(parts.joined(separator: separator))
        default:
            throw .unsupported("String.\(name) kennt der eingebaute Interpreter nicht.", line: line)
        }
    }

    private static func character(_ name: String, _ args: [JavaValue], line: Int) throws(JavaProblem) -> JavaValue {
        let label = "Character.\(name)"
        try arity(args, 1, label, line: line)
        guard case .char(let code) = args[0] else {
            throw .syntax("\(label) erwartet ein Zeichen (char), bekommt aber \(args[0].typeName).", line: line)
        }
        let character = Character(Unicode.Scalar(code).map { $0 } ?? " ")
        switch name {
        case "isDigit": return .boolean(character.isASCII && character.isNumber)
        case "isLetter": return .boolean(character.isLetter)
        case "isLetterOrDigit": return .boolean(character.isLetter || character.isNumber)
        case "isUpperCase": return .boolean(character.isUppercase)
        case "isLowerCase": return .boolean(character.isLowercase)
        case "isWhitespace": return .boolean(character.isWhitespace)
        case "toUpperCase": return .char(String(character).uppercased().utf16.first ?? code)
        case "toLowerCase": return .char(String(character).lowercased().utf16.first ?? code)
        case "getNumericValue": return .int(Int32(character.wholeNumberValue ?? -1))
        case "toString", "valueOf": return .str(String(character))
        default: throw .unsupported("\(label) kennt der eingebaute Interpreter nicht.", line: line)
        }
    }

    private static func arrays(_ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        let label = "Arrays.\(name)"
        guard case .array(let array)? = args.first else {
            if case .null? = args.first { throw .runtime("NullPointerException: \(label) bekommt null statt eines Arrays.", line: line) }
            throw .syntax("\(label) erwartet ein Array.", line: line)
        }
        switch name {
        case "toString":
            try arity(args, 1, label, line: line)
            return .str("[" + array.elements.map(\.javaString).joined(separator: ", ") + "]")
        case "sort":
            try arity(args, 1, label, line: line)
            switch array.elementType {
            case .string:
                array.elements.sort { compareStrings($0.javaString, $1.javaString) < 0 }
            case .boolean:
                throw .syntax("Ein boolean-Array kann man nicht sortieren.", line: line)
            default:
                array.elements.sort { a, b in
                    guard let x = Numeric(a), let y = Numeric(b) else { return false }
                    return Numeric.compare(x, y) == .orderedAscending
                }
            }
            return .void
        case "fill":
            try arity(args, 2, label, line: line)
            let value = try interpreter.coerce(args[1], to: array.elementType, line: line, what: label)
            array.elements = Array(repeating: value, count: array.elements.count)
            return .void
        case "copyOf":
            try arity(args, 2, label, line: line)
            let length = Int(try intArg(args[1], label, line: line))
            if length < 0 { throw .runtime("NegativeArraySizeException: \(length)", line: line) }
            var copy = Array(array.elements.prefix(length))
            copy += Array(repeating: .defaultValue(for: array.elementType), count: max(0, length - copy.count))
            return .array(JavaArray(elementType: array.elementType, elements: copy))
        case "equals":
            try arity(args, 2, label, line: line)
            guard case .array(let other) = args[1] else { return .boolean(false) }
            return .boolean(array.elements.map(\.javaString) == other.elements.map(\.javaString))
        default:
            throw .unsupported("\(label) kennt der eingebaute Interpreter nicht.", line: line)
        }
    }

    // MARK: Methoden auf Werten

    static func callInstance(_ receiver: JavaValue, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch receiver {
        case .string(let text):
            return try stringMethod(text.text, name, args, line: line)
        case .array(let array):
            switch name {
            case "clone":
                try arity(args, 0, "clone", line: line)
                return .array(JavaArray(elementType: array.elementType, elements: array.elements))
            case "length":
                throw .syntax("Bei Arrays ist length ein Feld ohne Klammern: \(name == "length" ? "zahlen.length" : name).", line: line)
            default:
                throw .syntax("Arrays haben keine Methode \(name)(). Für Hilfsfunktionen gibt es Arrays.\(name)(…).", line: line)
            }
        case .null:
            throw .runtime("NullPointerException: Der Wert ist null – auf null kann man keine Methode \(name)() aufrufen.", line: line)
        case .void:
            throw .syntax("Die Methode davor gibt nichts zurück (void) – darauf kann man nicht .\(name)() aufrufen.", line: line)
        default:
            throw .syntax("\(receiver.typeName) ist ein einfacher Wert und hat keine Methoden wie \(name)().", line: line)
        }
    }

    private static func utf16(_ text: String) -> [UInt16] { Array(text.utf16) }
    private static func string(_ units: some Collection<UInt16>) -> String { String(decoding: Array(units), as: UTF16.self) }

    /// `String.compareTo`: Differenz der ersten verschiedenen Zeichen, sonst der Längen.
    static func compareStrings(_ a: String, _ b: String) -> Int {
        let x = utf16(a), y = utf16(b)
        for (p, q) in zip(x, y) where p != q { return Int(p) - Int(q) }
        return x.count - y.count
    }

    private static func stringMethod(_ text: String, _ name: String, _ args: [JavaValue], line: Int) throws(JavaProblem) -> JavaValue {
        let units = utf16(text)
        let label = "\(name)"

        func index(_ value: JavaValue) throws(JavaProblem) -> Int { Int(try intArg(value, label, line: line)) }

        func needle(_ value: JavaValue) throws(JavaProblem) -> String {
            if case .char = value { return value.javaString }
            return try stringArg(value, label, line: line)
        }

        switch name {
        case "length":
            try arity(args, 0, "length()", line: line)
            return .int(Int32(units.count))
        case "charAt":
            try arity(args, 1, "charAt", line: line)
            let i = try index(args[0])
            guard i >= 0, i < units.count else {
                throw .runtime("StringIndexOutOfBoundsException: Index \(i) gibt es nicht – \"\(text)\" hat nur die Positionen 0 bis \(units.count - 1).", line: line)
            }
            return .char(units[i])
        case "substring":
            guard (1...2).contains(args.count) else { throw .syntax("substring erwartet 1 oder 2 Zahlen.", line: line) }
            let begin = try index(args[0])
            let end = args.count == 2 ? try index(args[1]) : units.count
            guard begin >= 0, end <= units.count, begin <= end else {
                throw .runtime("StringIndexOutOfBoundsException: begin \(begin), end \(end), length \(units.count) – der Bereich passt nicht in den Text.", line: line)
            }
            return .str(string(units[begin..<end]))
        case "indexOf", "lastIndexOf":
            guard (1...2).contains(args.count) else { throw .syntax("\(name) erwartet 1 oder 2 Werte.", line: line) }
            let search = utf16(try needle(args[0]))
            let from = args.count == 2 ? try index(args[1]) : (name == "indexOf" ? 0 : units.count)
            if search.isEmpty { return .int(Int32(max(0, min(from, units.count)))) }
            let positions = units.count >= search.count ? Array(0...(units.count - search.count)) : []
            let hits = positions.filter { Array(units[$0..<$0 + search.count]) == search }
            let found = name == "indexOf" ? hits.first { $0 >= from } : hits.last { $0 <= from }
            return .int(Int32(found ?? -1))
        case "contains":
            try arity(args, 1, "contains", line: line)
            let search = try needle(args[0])
            return .boolean(search.isEmpty || text.contains(search))
        case "equals":
            try arity(args, 1, "equals", line: line)
            if let other = args[0].stringValue { return .boolean(other == text) }
            return .boolean(false)
        case "equalsIgnoreCase":
            try arity(args, 1, "equalsIgnoreCase", line: line)
            if let other = args[0].stringValue { return .boolean(other.lowercased() == text.lowercased()) }
            return .boolean(false)
        case "compareTo", "compareToIgnoreCase":
            try arity(args, 1, name, line: line)
            let other = try stringArg(args[0], name, line: line)
            return name == "compareTo"
                ? .int(Int32(compareStrings(text, other)))
                : .int(Int32(compareStrings(text.lowercased(), other.lowercased())))
        case "toUpperCase":
            try arity(args, 0, name, line: line)
            return .str(text.uppercased())
        case "toLowerCase":
            try arity(args, 0, name, line: line)
            return .str(text.lowercased())
        case "trim", "strip":
            try arity(args, 0, name, line: line)
            return .str(text.trimmingCharacters(in: .whitespacesAndNewlines))
        case "isEmpty":
            try arity(args, 0, name, line: line)
            return .boolean(units.isEmpty)
        case "isBlank":
            try arity(args, 0, name, line: line)
            return .boolean(text.allSatisfy(\.isWhitespace))
        case "startsWith", "endsWith":
            try arity(args, 1, name, line: line)
            let part = try stringArg(args[0], name, line: line)
            return .boolean(name == "startsWith" ? text.hasPrefix(part) : text.hasSuffix(part))
        case "replace":
            try arity(args, 2, "replace", line: line)
            let old = try needle(args[0]), new = try needle(args[1])
            if old.isEmpty { throw .unsupported("replace mit leerem Suchtext kennt der eingebaute Interpreter nicht.", line: line) }
            return .str(text.replacingOccurrences(of: old, with: new))
        case "replaceAll", "matches", "split":
            let pattern = try stringArg(args.first ?? .null, name, line: line)
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                throw .runtime("PatternSyntaxException: „\(pattern)“ ist kein gültiger regulärer Ausdruck.", line: line)
            }
            let range = NSRange(text.startIndex..., in: text)
            if name == "matches" {
                try arity(args, 1, name, line: line)
                let match = regex.firstMatch(in: text, options: [.anchored], range: range)
                return .boolean(match?.range == range)
            }
            if name == "replaceAll" {
                try arity(args, 2, name, line: line)
                let replacement = try stringArg(args[1], name, line: line)
                return .str(regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement))
            }
            try arity(args, 1, name, line: line)
            if text.isEmpty { return .array(JavaArray(elementType: .string, elements: [.str("")])) }
            var parts: [String] = []
            var last = text.startIndex
            for match in regex.matches(in: text, range: range) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                // Ein Treffer der Länge 0 ganz am Anfang erzeugt in Java kein leeres erstes Element.
                if matchRange.isEmpty && matchRange.lowerBound == text.startIndex { continue }
                if matchRange.isEmpty && matchRange.lowerBound == text.endIndex { continue }
                parts.append(String(text[last..<matchRange.lowerBound]))
                last = matchRange.upperBound
            }
            parts.append(String(text[last...]))
            while parts.count > 1, parts.last?.isEmpty == true { parts.removeLast() }
            return .array(JavaArray(elementType: .string, elements: parts.map(JavaValue.str)))
        case "repeat":
            try arity(args, 1, "repeat", line: line)
            let count = try index(args[0])
            if count < 0 { throw .runtime("IllegalArgumentException: count is negative: \(count)", line: line) }
            return .str(String(repeating: text, count: count))
        case "concat":
            try arity(args, 1, "concat", line: line)
            return .str(text + (try stringArg(args[0], "concat", line: line)))
        case "toCharArray":
            try arity(args, 0, "toCharArray", line: line)
            return .array(JavaArray(elementType: .char, elements: units.map(JavaValue.char)))
        case "hashCode":
            try arity(args, 0, "hashCode", line: line)
            return .int(units.reduce(Int32(0)) { $0 &* 31 &+ Int32($1) })
        case "length()":
            return .int(Int32(units.count))
        default:
            throw .unsupported("Die String-Methode \(name)() kennt der eingebaute Interpreter nicht.", line: line)
        }
    }
}
