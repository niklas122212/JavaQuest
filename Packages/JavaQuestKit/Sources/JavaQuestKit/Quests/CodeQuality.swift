import Foundation

/// Ein Hinweis zur Code-Qualität – mit Zeile, damit der Editor sie markieren kann.
public struct QualityFinding: Sendable, Hashable {
    public let line: Int?
    public let message: String
}

/// Sauberer Code, der Sterne bringt: Java-Namenskonventionen und saubere Einrückung.
/// Beides bewertet nur Programme, die sich lesen lassen – bei Syntaxfehlern gibt es kein Urteil.
public enum CodeQuality {
    // MARK: Namen

    /// Klassen beginnen groß (`Golem`), Methoden und Variablen klein in camelCase (`getEnergie`),
    /// Konstanten (`static final`) und Enum-Werte in GROSSBUCHSTABEN (`MAX_ENERGIE`).
    public static func naming(_ source: String) -> [QualityFinding] {
        guard let program = try? JavaParser.parse(JavaSource.normalizingTypography(source)) else { return [] }
        var findings: [QualityFinding] = []
        var seen: Set<String> = []
        func report(_ line: Int?, _ message: String) {
            // Dieselbe Variable mit falschem Namen nur einmal nennen.
            guard seen.insert(message).inserted else { return }
            findings.append(QualityFinding(line: line, message: message))
        }

        if let main = program.mainClass, !isTypeName(main) {
            report(line(ofClass: main, in: source), "Klassennamen beginnen mit einem Großbuchstaben: \(suggestedType(main)) statt \(main).")
        }
        for name in program.classOrder {
            guard let decl = program.classes[name] else { continue }
            if !isTypeName(decl.name) {
                report(decl.line, "Klassennamen beginnen mit einem Großbuchstaben: \(suggestedType(decl.name)) statt \(decl.name).")
            }
            for field in decl.fields {
                checkField(field, report: report)
            }
            for constant in decl.enumConstants where !isConstantName(constant.name) {
                report(constant.line, "Enum-Werte schreibt man in Großbuchstaben: \(constant.name.uppercased()) statt \(constant.name).")
            }
            for component in decl.recordComponents where !isVariableName(component.name) {
                report(decl.line, "Variablen und Felder beginnen klein: \(suggestedVariable(component.name)) statt \(component.name).")
            }
            for constructor in decl.constructors {
                for parameter in constructor.parameters { checkVariable(parameter.name, line: constructor.line, report: report) }
                walk(constructor.body, report: report)
            }
            for method in decl.methods.values.flatMap({ $0 }) {
                checkMethod(method, report: report)
            }
        }
        for method in program.methods.values.flatMap({ $0 }) {
            checkMethod(method, report: report)
        }
        for statement in program.staticFields {
            if case .varDecl(_, let declarators, let isFinal, _) = statement {
                for declarator in declarators where !(isFinal ? isConstantName(declarator.name) || isVariableName(declarator.name) : isVariableName(declarator.name)) {
                    report(declarator.line, isFinal
                        ? "Konstanten schreibt man in Großbuchstaben mit _: \(suggestedConstant(declarator.name)) statt \(declarator.name)."
                        : "Variablen und Felder beginnen klein: \(suggestedVariable(declarator.name)) statt \(declarator.name).")
                }
            }
        }
        walk(program.statements, report: report)
        return findings.sorted { ($0.line ?? 0) < ($1.line ?? 0) }
    }

    private static func checkField(_ field: JavaField, report: (Int?, String) -> Void) {
        if field.isStatic && field.isFinal {
            if !isConstantName(field.name) && !isVariableName(field.name) {
                report(field.line, "Konstanten schreibt man in Großbuchstaben mit _: \(suggestedConstant(field.name)) statt \(field.name).")
            }
        } else if !isVariableName(field.name) {
            report(field.line, "Variablen und Felder beginnen klein: \(suggestedVariable(field.name)) statt \(field.name).")
        }
    }

    private static func checkMethod(_ method: JavaMethod, report: (Int?, String) -> Void) {
        if !isVariableName(method.name) {
            report(method.line, "Methodennamen beginnen klein, weitere Wörter groß: \(suggestedVariable(method.name)) statt \(method.name).")
        }
        for parameter in method.parameters {
            checkVariable(parameter.name, line: method.line, report: report)
        }
        walk(method.body, report: report)
    }

    private static func checkVariable(_ name: String, line: Int, report: (Int?, String) -> Void) {
        if !isVariableName(name) {
            report(line, "Variablen und Parameter beginnen klein, weitere Wörter groß: \(suggestedVariable(name)) statt \(name).")
        }
    }

    /// Lokale Variablen in allen Anweisungen – auch in Schleifen, if, switch und try.
    private static func walk(_ statements: [JavaStmt], report: (Int?, String) -> Void) {
        for statement in statements { walk(statement, report: report) }
    }

    private static func walk(_ statement: JavaStmt, report: (Int?, String) -> Void) {
        switch statement {
        case .varDecl(_, let declarators, let isFinal, _):
            for declarator in declarators where !(isVariableName(declarator.name) || (isFinal && isConstantName(declarator.name))) {
                report(declarator.line, "Variablen beginnen klein, weitere Wörter groß: \(suggestedVariable(declarator.name)) statt \(declarator.name).")
            }
        case .block(let body, _):
            walk(body, report: report)
        case .ifStmt(_, let then, let otherwise, _):
            walk(then, report: report)
            if let otherwise { walk(otherwise, report: report) }
        case .whileStmt(_, let body, _), .doWhile(let body, _, _):
            walk(body, report: report)
        case .forStmt(let initializers, _, _, let body, _):
            walk(initializers, report: report)
            walk(body, report: report)
        case .forEach(_, let name, _, let body, let line):
            checkVariable(name, line: line, report: report)
            walk(body, report: report)
        case .switchStmt(_, let cases, _):
            for switchCase in cases { walk(switchCase.body, report: report) }
        case .tryStmt(let body, let catches, let finally, _):
            walk(body, report: report)
            for handler in catches {
                checkVariable(handler.name, line: handler.line, report: report)
                walk(handler.body, report: report)
            }
            if let finally { walk(finally, report: report) }
        default:
            break
        }
    }

    static func isTypeName(_ name: String) -> Bool { name.range(of: #"^[A-Z][A-Za-z0-9]*$"#, options: .regularExpression) != nil }
    static func isVariableName(_ name: String) -> Bool { name.range(of: #"^[a-z][A-Za-z0-9]*$"#, options: .regularExpression) != nil }
    static func isConstantName(_ name: String) -> Bool { name.range(of: #"^[A-Z][A-Z0-9_]*$"#, options: .regularExpression) != nil }

    private static func words(_ name: String) -> [String] {
        name.replacingOccurrences(of: #"([a-z0-9])([A-Z])"#, with: "$1_$2", options: .regularExpression)
            .split(separator: "_").map { $0.lowercased() }.filter { !$0.isEmpty }
    }
    static func suggestedVariable(_ name: String) -> String {
        let parts = words(name)
        guard let first = parts.first else { return name }
        return first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
    static func suggestedType(_ name: String) -> String {
        words(name).map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
    static func suggestedConstant(_ name: String) -> String { words(name).map { $0.uppercased() }.joined(separator: "_") }

    private static func line(ofClass name: String, in source: String) -> Int? {
        let lines = source.components(separatedBy: "\n")
        return lines.firstIndex { $0.range(of: #"\bclass\s+\#(name)\b"#, options: .regularExpression) != nil }.map { $0 + 1 }
    }

    // MARK: Einrückung

    /// Jede Klammerebene 4 Leerzeichen tiefer, die schließende Klammer zurück auf die Ebene ihrer Zeile.
    /// Erlaubt: eine Stufe mehr nach `case …:` und Fortsetzungszeilen, die tiefer stehen als ihre Ebene.
    public static func indentation(_ source: String) -> [QualityFinding] {
        guard JavaRunner.check(source)?.kind != .syntax else { return [] }
        let masked = JavaSource.maskingLiterals(JavaSource.normalizingTypography(source)).components(separatedBy: "\n")
        let original = source.components(separatedBy: "\n")
        var findings: [QualityFinding] = []
        var depth = 0
        var afterCase = false
        var previousCode = ""
        for (index, maskedLine) in masked.enumerated() {
            let code = maskedLine.trimmingCharacters(in: .whitespaces)
            let opens = maskedLine.filter { $0 == "{" }.count
            let closes = maskedLine.filter { $0 == "}" }.count
            defer {
                depth = max(depth + opens - closes, 0)
                if !code.isEmpty { previousCode = code }
            }
            guard !code.isEmpty, index < original.count else { continue }
            let raw = original[index]
            let indent = raw.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            let level = code.hasPrefix("}") ? max(depth - 1, 0) : depth
            let expected = level * 4
            let isCaseLabel = code.hasPrefix("case ") || code.hasPrefix("default")
            // Eine Anweisung, die über mehrere Zeilen geht, darf tiefer stehen.
            let isContinuation = !previousCode.isEmpty && !(previousCode.hasSuffix(";") || previousCode.hasSuffix("{")
                || previousCode.hasSuffix("}") || previousCode.hasSuffix(":") || previousCode.hasPrefix("@") || previousCode.hasSuffix("->"))
            let allowed: Bool = if isContinuation {
                indent >= expected
            } else if afterCase && !isCaseLabel && !code.hasPrefix("}") {
                indent == expected || indent == expected + 4
            } else {
                indent == expected
            }
            if isCaseLabel { afterCase = true } else if code.hasPrefix("}") { afterCase = false }
            if !allowed {
                findings.append(QualityFinding(line: index + 1,
                    message: "Zeile \(index + 1) ist mit \(indent) statt \(expected) Leerzeichen eingerückt – je Klammerebene 4 Leerzeichen."))
            }
        }
        return findings
    }
}
