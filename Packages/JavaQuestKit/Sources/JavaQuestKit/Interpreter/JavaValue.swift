import Foundation

/// Ein Laufzeitwert des Interpreters. Ganzzahlen haben Javas feste Breite
/// (int = 32 Bit, long = 64 Bit) und laufen wie in Java über.
public enum JavaValue: @unchecked Sendable {
    case int(Int32)
    case long(Int64)
    case double(Double)
    case boolean(Bool)
    /// Java-chars sind UTF-16-Codeeinheiten.
    case char(UInt16)
    /// Strings sind wie in Java Referenzen: == vergleicht, ob es dasselbe Objekt ist.
    case string(JavaString)
    case array(JavaArray)
    case null
    case void

    var type: JavaType {
        switch self {
        case .int: .int
        case .long: .long
        case .double: .double
        case .boolean: .boolean
        case .char: .char
        case .string: .string
        case .array(let array): .array(array.elementType)
        case .null: .unknown("null")
        case .void: .void
        }
    }

    var typeName: String {
        if case .null = self { return "null" }
        return type.description
    }

    /// Text, wie ihn `System.out.println` bzw. String-Verkettung erzeugt.
    public var javaString: String {
        switch self {
        case .int(let value): String(value)
        case .long(let value): String(value)
        case .double(let value): JavaFormat.double(value)
        case .boolean(let value): value ? "true" : "false"
        case .char(let value): String(utf16CodeUnits: [value], count: 1)
        case .string(let value): value.text
        case .array(let array): array.identityString
        case .null: "null"
        case .void: ""
        }
    }

    /// Darstellung für die Variablen-Anzeige: Strings in Anführungszeichen, Arrays mit Inhalt.
    public var debugDisplay: String {
        switch self {
        case .string(let value): "\"\(value.text)\""
        case .char: "'\(javaString)'"
        case .array(let array): "{" + array.elements.prefix(12).map(\.debugDisplay).joined(separator: ", ") + (array.elements.count > 12 ? ", …" : "") + "}"
        default: javaString
        }
    }

    static func defaultValue(for type: JavaType) -> JavaValue {
        switch type {
        case .int: .int(0)
        case .long: .long(0)
        case .double: .double(0)
        case .boolean: .boolean(false)
        case .char: .char(0)
        default: .null
        }
    }
}

/// Ein String-Objekt. Gleiche Literale teilen sich ein Objekt (String-Pool), berechnete Texte sind neue Objekte.
public final class JavaString: @unchecked Sendable {
    let text: String

    init(_ text: String) {
        self.text = text
    }
}

extension JavaValue {
    /// Ein neu berechneter String – ein eigenes Objekt.
    static func str(_ text: String) -> JavaValue { .string(JavaString(text)) }

    var stringValue: String? {
        if case .string(let value) = self { return value.text }
        return nil
    }
}

/// Arrays sind in Java Referenzen: Zwei Variablen können auf denselben „Eierkarton“ zeigen.
public final class JavaArray: @unchecked Sendable {
    let elementType: JavaType
    var elements: [JavaValue]
    let serial: Int

    private static let counterLock = NSLock()
    nonisolated(unsafe) private static var counter = 0x1b6d3586

    init(elementType: JavaType, elements: [JavaValue]) {
        self.elementType = elementType
        self.elements = elements
        // Eindeutige „Adresse“, wie Java sie bei println(array) zeigt – geschützt, weil mehrere Programme parallel laufen können.
        self.serial = Self.counterLock.withLock {
            Self.counter = (Self.counter &* 31 &+ 7) & 0x7fffffff
            return Self.counter
        }
    }

    var identityString: String {
        let code: String = switch elementType {
        case .int: "[I"
        case .long: "[J"
        case .double: "[D"
        case .boolean: "[Z"
        case .char: "[C"
        case .string: "[Ljava.lang.String;"
        default: "[Ljava.lang.Object;"
        }
        return code + "@" + String(serial, radix: 16)
    }
}

enum JavaFormat {
    /// `Double.toString` aus Java: kürzeste eindeutige Ziffernfolge, zwischen 10⁻³ und 10⁷
    /// als Dezimalzahl mit mindestens einer Nachkommastelle, sonst wissenschaftlich (`1.0E10`).
    static func double(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
        if value == 0 { return value.sign == .minus ? "-0.0" : "0.0" }

        let sign = value < 0 ? "-" : ""
        let (digits, exponent) = decimalDigits(abs(value))
        let magnitude = abs(value)
        if magnitude >= 1e-3 && magnitude < 1e7 {
            if exponent <= 0 {
                return sign + "0." + String(repeating: "0", count: -exponent) + digits
            }
            if exponent >= digits.count {
                return sign + digits + String(repeating: "0", count: exponent - digits.count) + ".0"
            }
            let split = digits.index(digits.startIndex, offsetBy: exponent)
            return sign + digits[..<split] + "." + digits[split...]
        }
        let first = digits.prefix(1)
        let rest = digits.count > 1 ? String(digits.dropFirst()) : "0"
        return sign + first + "." + rest + "E" + String(exponent - 1)
    }

    /// Zerlegt eine positive Zahl in Ziffern D und Exponent E mit Wert = 0.D × 10^E.
    /// Swift liefert wie Java die kürzeste Darstellung, die die Zahl eindeutig bestimmt.
    static func decimalDigits(_ value: Double) -> (String, Int) {
        let text = value.description
        let parts = text.lowercased().split(separator: "e", maxSplits: 1)
        let mantissa = String(parts[0])
        let power = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let pieces = mantissa.split(separator: ".", omittingEmptySubsequences: false)
        let integerPart = String(pieces[0])
        let fractionPart = pieces.count > 1 ? String(pieces[1]) : ""
        var all = Array(integerPart + fractionPart)
        var pointPosition = integerPart.count
        while all.first == "0", all.count > 1 {
            all.removeFirst()
            pointPosition -= 1
        }
        while all.last == "0", all.count > 1 { all.removeLast() }
        return (String(all), pointPosition + power)
    }

    /// `String.format`/`printf` für die gängigen Platzhalter: %d %s %f %.2f %c %b %x %n %% samt Breite und Flags.
    static func format(_ pattern: String, _ args: [JavaValue], line: Int) throws(JavaProblem) -> String {
        var result = ""
        var chars = Array(pattern)[...]
        var argIndex = 0
        while let c = chars.first {
            chars = chars.dropFirst()
            guard c == "%" else { result.append(c); continue }
            var flags = ""
            while let f = chars.first, "-0+,# ".contains(f) { flags.append(f); chars = chars.dropFirst() }
            var widthText = ""
            while let d = chars.first, d.isNumber { widthText.append(d); chars = chars.dropFirst() }
            var precision: Int?
            if chars.first == "." {
                chars = chars.dropFirst()
                var p = ""
                while let d = chars.first, d.isNumber { p.append(d); chars = chars.dropFirst() }
                precision = Int(p) ?? 0
            }
            guard let conversion = chars.first else {
                throw .runtime("UnknownFormatConversionException: Das Format endet mit einem einzelnen %.", line: line)
            }
            chars = chars.dropFirst()
            if conversion == "n" { result.append("\n"); continue }
            if conversion == "%" { result.append("%"); continue }
            guard argIndex < args.count else {
                throw .runtime("MissingFormatArgumentException: Für „%\(conversion)“ fehlt ein Wert.", line: line)
            }
            let arg = args[argIndex]
            argIndex += 1
            var text: String
            switch conversion {
            case "d":
                let number: Int64
                switch arg {
                case .int(let v): number = Int64(v)
                case .long(let v): number = v
                case .char, .double, .boolean, .string, .array, .null, .void:
                    throw .runtime("IllegalFormatConversionException: %d erwartet eine Ganzzahl, bekam \(arg.typeName).", line: line)
                }
                text = flags.contains(",") ? grouped(String(abs(number))) : String(abs(number))
                if number < 0 { text = "-" + text } else if flags.contains("+") { text = "+" + text }
            case "f", "e":
                let number: Double
                switch arg {
                case .double(let v): number = v
                default:
                    throw .runtime("IllegalFormatConversionException: %\(conversion) erwartet eine Kommazahl (double), bekam \(arg.typeName).", line: line)
                }
                if conversion == "e" {
                    text = String(format: "%.\(precision ?? 6)e", number)
                } else {
                    text = fixed(number, precision: precision ?? 6)
                    if flags.contains(",") {
                        let negative = text.hasPrefix("-")
                        let body = negative ? String(text.dropFirst()) : text
                        let parts = body.split(separator: ".", maxSplits: 1)
                        text = (negative ? "-" : "") + grouped(String(parts[0])) + (parts.count > 1 ? "." + parts[1] : "")
                    }
                }
                if number >= 0, flags.contains("+") { text = "+" + text }
            case "s", "S":
                text = arg.javaString
                if let precision { text = String(text.prefix(precision)) }
                if conversion == "S" { text = text.uppercased() }
            case "c":
                text = arg.javaString
            case "b", "B":
                if case .boolean(let v) = arg { text = v ? "true" : "false" } else if case .null = arg { text = "false" } else { text = "true" }
            case "x", "X":
                switch arg {
                case .int(let v): text = String(UInt32(bitPattern: v), radix: 16)
                case .long(let v): text = String(UInt64(bitPattern: v), radix: 16)
                default: throw .runtime("IllegalFormatConversionException: %x erwartet eine Ganzzahl.", line: line)
                }
                if conversion == "X" { text = text.uppercased() }
            default:
                throw .runtime("UnknownFormatConversionException: „%\(conversion)“ kennt String.format nicht.", line: line)
            }
            if let width = Int(widthText), text.count < width {
                let padding = width - text.count
                if flags.contains("-") {
                    text += String(repeating: " ", count: padding)
                } else if flags.contains("0"), "dfx".contains(conversion) {
                    let negative = text.hasPrefix("-")
                    let body = negative ? String(text.dropFirst()) : text
                    text = (negative ? "-" : "") + String(repeating: "0", count: padding) + body
                } else {
                    text = String(repeating: " ", count: padding) + text
                }
            }
            result += text
        }
        return result
    }

    /// Kaufmännisches Runden (HALF_UP) wie Javas Formatter – nicht Bankers Rounding.
    static func fixed(_ value: Double, precision: Int) -> String {
        let decimal = Decimal(string: double(value).replacingOccurrences(of: "E", with: "e")) ?? Decimal(value)
        var input = decimal
        var rounded = Decimal()
        // .plain rundet Hälften von der Null weg – genau wie Javas HALF_UP.
        NSDecimalRound(&rounded, &input, precision, .plain)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        formatter.minimumIntegerDigits = 1
        return formatter.string(from: rounded as NSDecimalNumber) ?? String(format: "%.\(precision)f", value)
    }

    private static func grouped(_ digits: String) -> String {
        var result = ""
        for (index, c) in digits.reversed().enumerated() {
            if index > 0, index % 3 == 0 { result.append(",") }
            result.append(c)
        }
        return String(result.reversed())
    }
}
