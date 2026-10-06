import Foundation

/// Rekursiver Abstiegsparser für die Java-Teilmenge des Interpreters.
///
/// Akzeptiert drei Formen:
/// - lose Anweisungen (wie im main-Block) und statische Methoden dazwischen,
/// - eine Klasse mit `main` und statischen Methoden/Feldern,
/// - beides gemischt (Methoden über oder unter den Anweisungen).
///
/// Alles, was Objekte eigener Klassen, Lambdas, Generics oder try/catch braucht,
/// meldet `JavaProblem.Kind.unsupported` – dann greift in der App die regelbasierte Prüfung.
struct JavaParser {
    private var tokens: [JavaToken]
    private var position = 0
    private var classCount = 0
    /// String-Pool: Gleiche Literale sind in Java dasselbe Objekt ("a" == "a" ist true).
    private var pool: [String: JavaString] = [:]

    init(tokens: [JavaToken]) {
        self.tokens = tokens
    }

    static func parse(_ source: String) throws(JavaProblem) -> JavaProgram {
        var parser = JavaParser(tokens: try JavaLexer.tokenize(source))
        return try parser.parseProgram()
    }

    private mutating func intern(_ text: String) -> JavaString {
        if let existing = pool[text] { return existing }
        let created = JavaString(text)
        pool[text] = created
        return created
    }

    // MARK: - Token-Hilfen

    private var current: JavaToken { tokens[position] }
    private func peek(_ offset: Int = 1) -> JavaToken { tokens[min(position + offset, tokens.count - 1)] }
    private var previousLine: Int { position > 0 ? tokens[position - 1].line : current.line }

    private mutating func advance() -> JavaToken {
        let token = tokens[position]
        if position < tokens.count - 1 { position += 1 }
        return token
    }

    private mutating func accept(_ symbol: String) -> Bool {
        guard current.is(symbol) else { return false }
        position += 1
        return true
    }

    private mutating func expect(_ symbol: String, _ message: @autoclosure () -> String? = nil) throws(JavaProblem) {
        guard accept(symbol) else {
            if symbol == ";" {
                // Wie javac: Das fehlende Semikolon gehört zur vorigen Zeile.
                throw .syntax("Hier fehlt ein Semikolon (;) am Ende der Anweisung.", line: previousLine)
            }
            let found = current.kind == .end ? "das Ende des Codes" : "„\(current.text)“"
            throw .syntax(message() ?? "Erwartet wurde „\(symbol)“, gefunden \(found).", line: current.kind == .end ? previousLine : current.line)
        }
    }

    private mutating func identifier(_ what: String) throws(JavaProblem) -> String {
        guard current.kind == .identifier else {
            if current.kind == .keyword {
                throw .syntax("„\(current.text)“ ist ein reserviertes Java-Wort und kann nicht als \(what) dienen.", line: current.line)
            }
            throw .syntax("Hier wird ein Name für \(what) erwartet.", line: current.line)
        }
        return advance().text
    }

    // MARK: - Programm

    private static let modifiers: Set<String> = ["public", "private", "protected", "static", "final", "abstract"]

    mutating func parseProgram() throws(JavaProblem) -> JavaProgram {
        var program = JavaProgram()
        while current.kind != .end {
            if current.is("import") || current.is("package") {
                while current.kind != .end, !current.is(";") { _ = advance() }
                try expect(";")
                continue
            }
            if current.is("@") { try skipAnnotation(); continue }
            let start = position
            var mods: Set<String> = []
            while Self.modifiers.contains(current.text), current.kind == .keyword { mods.insert(advance().text) }
            if current.is("class") {
                try parseClass(into: &program)
                continue
            }
            if current.is("interface") || current.is("enum") || current.is("record") {
                throw .unsupported("\(current.text) kennt der eingebaute Interpreter nicht.", line: current.line)
            }
            if let method = try parseMethodIfPresent(modifiers: mods) {
                try add(method, to: &program)
                continue
            }
            if mods.contains("static") {
                // static int zaehler = 0; zwischen eigenen Methoden: ein Feld für alle Methoden.
                program.staticFields.append(try declarationStatement(isFinal: mods.contains("final")))
                continue
            }
            position = start
            program.statements.append(try statement())
        }
        // main ohne umgebende Klasse (wie in Java 21+ mit „implicit classes“).
        if !program.hasMain, let main = program.methods["main"]?.first, main.returnType == .void {
            if !program.statements.isEmpty {
                throw .syntax("Neben einer main-Methode dürfen keine losen Anweisungen stehen – sie gehören in main.", line: program.statements[0].line)
            }
            program.statements = main.body
            program.hasMain = true
            program.methods["main"] = nil
        }
        return program
    }

    private mutating func skipAnnotation() throws(JavaProblem) {
        try expect("@")
        _ = try identifier("die Annotation")
        if accept("(") {
            var depth = 1
            while depth > 0, current.kind != .end {
                if current.is("(") { depth += 1 }
                if current.is(")") { depth -= 1 }
                _ = advance()
            }
        }
    }

    private mutating func add(_ method: JavaMethod, to program: inout JavaProgram) throws(JavaProblem) {
        let existing = program.methods[method.name] ?? []
        if existing.contains(where: { $0.parameters.map(\.type) == method.parameters.map(\.type) }) {
            throw .syntax("Die Methode \(method.name) gibt es mit genau diesen Parametern schon.", line: method.line)
        }
        program.methods[method.name] = existing + [method]
    }

    private mutating func parseClass(into program: inout JavaProgram) throws(JavaProblem) {
        let line = current.line
        try expect("class")
        let name = try identifier("die Klasse")
        classCount += 1
        if classCount > 1 {
            throw .unsupported("Mehrere Klassen kennt der eingebaute Interpreter nicht.", line: line)
        }
        if current.is("extends") || current.is("implements") || current.is("<") {
            throw .unsupported("Vererbung und Interfaces kennt der eingebaute Interpreter nicht.", line: current.line)
        }
        try expect("{", "Nach „class \(name)“ beginnt der Klassenkörper mit {.")
        while !current.is("}") {
            guard current.kind != .end else { throw .syntax("Die Klasse \(name) wird nicht mit } geschlossen.", line: line) }
            if current.is("@") { try skipAnnotation(); continue }
            if accept(";") { continue }
            var mods: Set<String> = []
            while Self.modifiers.contains(current.text), current.kind == .keyword { mods.insert(advance().text) }
            if current.is("class") || current.is("interface") || current.is("enum") || current.is("record") {
                throw .unsupported("Verschachtelte Typen kennt der eingebaute Interpreter nicht.", line: current.line)
            }
            if current.kind == .identifier, current.text == name, peek().is("(") {
                throw .unsupported("Konstruktoren und Objekte eigener Klassen kennt der eingebaute Interpreter nicht.", line: current.line)
            }
            if let method = try parseMethodIfPresent(modifiers: mods) {
                if method.name == "main", method.returnType == .void, mods.contains("static") {
                    program.statements += method.body
                    program.hasMain = true
                } else if !mods.contains("static") {
                    throw .unsupported("Objektmethoden (ohne static) kennt der eingebaute Interpreter nicht.", line: method.line)
                } else {
                    try add(method, to: &program)
                }
                continue
            }
            guard mods.contains("static") else {
                throw .unsupported("Objekt-Felder (ohne static) kennt der eingebaute Interpreter nicht.", line: current.line)
            }
            program.staticFields.append(try declarationStatement(isFinal: mods.contains("final")))
        }
        try expect("}")
    }

    /// Erkennt `Typ name(` und liest die ganze Methode – sonst bleibt die Position unverändert.
    private mutating func parseMethodIfPresent(modifiers: Set<String>) throws(JavaProblem) -> JavaMethod? {
        let start = position
        if current.is("<") {
            throw .unsupported("Generische Methoden kennt der eingebaute Interpreter nicht.", line: current.line)
        }
        let line = current.line
        guard let returnType = try? typeIfPresent(allowVoid: true),
              current.kind == .identifier, peek().is("(") else {
            position = start
            return nil
        }
        let name = advance().text
        try expect("(")
        var parameters: [JavaParameter] = []
        if !current.is(")") {
            repeat {
                _ = accept("final")
                guard let type = try typeIfPresent(allowVoid: false) else {
                    throw .syntax("Jeder Parameter braucht einen Typ, z. B. „int zahl“.", line: current.line)
                }
                if accept("...") {
                    throw .unsupported("Variable Parameterlisten (…) kennt der eingebaute Interpreter nicht.", line: previousLine)
                }
                var parameterType = type
                let parameterName = try identifier("den Parameter")
                while accept("[") { try expect("]"); parameterType = .array(parameterType) }
                parameters.append(JavaParameter(type: parameterType, name: parameterName))
            } while accept(",")
        }
        try expect(")", "Die Parameterliste von \(name) wird mit ) geschlossen.")
        if accept("throws") {
            repeat { _ = try identifier("die Exception") } while accept(",")
        }
        if modifiers.contains("abstract") || current.is(";") {
            throw .unsupported("Methoden ohne Körper kennt der eingebaute Interpreter nicht.", line: line)
        }
        try expect("{", "Der Körper der Methode \(name) beginnt mit {.")
        let body = try blockBody(openedAt: line)
        return JavaMethod(name: name, returnType: returnType, parameters: parameters, body: body, line: line)
    }

    // MARK: - Typen

    private static let primitive: [String: JavaType] = ["int": .int, "long": .long, "double": .double, "boolean": .boolean, "char": .char]

    /// Liest einen Typ, falls einer kommt (inkl. `[]`). Wirft nur bei klar unpassendem Code.
    private mutating func typeIfPresent(allowVoid: Bool) throws(JavaProblem) -> JavaType? {
        var type: JavaType
        if current.kind == .keyword {
            switch current.text {
            case "void" where allowVoid: type = .void
            case "var": type = .inferred
            case "byte", "short", "float":
                throw .unsupported("Den Typ \(current.text) kennt der eingebaute Interpreter nicht – nimm int oder double.", line: current.line)
            default:
                guard let primitive = Self.primitive[current.text] else { return nil }
                type = primitive
            }
            _ = advance()
        } else if current.kind == .identifier {
            let name = advance().text
            if name == "String" {
                type = .string
            } else {
                var full = name
                // Qualifizierte Namen wie java.util.List
                while current.is("."), peek().kind == .identifier, position + 2 < tokens.count {
                    let save = position
                    _ = advance()
                    let part = advance().text
                    if !(current.kind == .identifier || current.is("<") || current.is("[")) {
                        position = save
                        break
                    }
                    full += "." + part
                }
                if current.is("<") {
                    var depth = 0
                    repeat {
                        if current.is("<") { depth += 1 }
                        if current.is(">") { depth -= 1 }
                        if current.is(">>") { depth -= 2 }
                        full += current.text
                        _ = advance()
                    } while depth > 0 && current.kind != .end
                }
                type = .unknown(full)
            }
        } else {
            return nil
        }
        while current.is("["), peek().is("]") {
            position += 2
            type = .array(type)
        }
        return type
    }

    /// Sieht nach `Typ Name` aus? Prüft ohne zu verbrauchen.
    private mutating func looksLikeDeclaration() -> Bool {
        let start = position
        defer { position = start }
        _ = accept("final")
        guard let type = try? typeIfPresent(allowVoid: false) else { return false }
        if type == .inferred, current.kind != .identifier { return false }
        guard current.kind == .identifier else { return false }
        let next = peek()
        return next.is("=") || next.is(";") || next.is(",") || next.is(":") || next.is("[")
    }

    // MARK: - Anweisungen

    private mutating func blockBody(openedAt line: Int) throws(JavaProblem) -> [JavaStmt] {
        var body: [JavaStmt] = []
        while !current.is("}") {
            guard current.kind != .end else {
                throw .syntax("Der Block aus Zeile \(line) wird nie mit } geschlossen.", line: line)
            }
            body.append(try statement())
        }
        _ = advance()
        return body
    }

    private mutating func statement() throws(JavaProblem) -> JavaStmt {
        let token = current
        let line = token.line
        if token.kind == .keyword || token.kind == .symbol {
            switch token.text {
            case "{":
                _ = advance()
                return .block(try blockBody(openedAt: line), line: line)
            case ";":
                _ = advance()
                return .empty(line: line)
            case "if":
                _ = advance()
                let condition = try parenthesized("if")
                let then = try statement()
                let otherwise: JavaStmt? = accept("else") ? try statement() : nil
                return .ifStmt(condition, then, otherwise, line: line)
            case "while":
                _ = advance()
                let condition = try parenthesized("while")
                return .whileStmt(condition, try statement(), line: line)
            case "do":
                _ = advance()
                let body = try statement()
                try expect("while", "Nach dem do-Block folgt while (…);")
                let condition = try parenthesized("while")
                try expect(";")
                return .doWhile(body, condition, line: line)
            case "for":
                return try forStatement()
            case "break":
                _ = advance()
                if current.kind == .identifier { throw .unsupported("break mit Sprungmarke kennt der eingebaute Interpreter nicht.", line: line) }
                try expect(";")
                return .breakStmt(line: line)
            case "continue":
                _ = advance()
                if current.kind == .identifier { throw .unsupported("continue mit Sprungmarke kennt der eingebaute Interpreter nicht.", line: line) }
                try expect(";")
                return .continueStmt(line: line)
            case "return":
                _ = advance()
                if accept(";") { return .returnStmt(nil, line: line) }
                let value = try expression()
                try expect(";")
                return .returnStmt(value, line: line)
            case "yield":
                _ = advance()
                let value = try expression()
                try expect(";")
                return .yieldStmt(value, line: line)
            case "switch":
                _ = advance()
                let subject = try parenthesized("switch")
                let cases = try switchBody(isExpression: false)
                return .switchStmt(subject, cases, line: line)
            case "throw":
                throw .unsupported("throw kennt der eingebaute Interpreter nicht.", line: line)
            case "try", "catch", "finally":
                throw .unsupported("try/catch kennt der eingebaute Interpreter nicht.", line: line)
            case "class", "interface", "enum", "record":
                throw .unsupported("Typen innerhalb von Methoden kennt der eingebaute Interpreter nicht.", line: line)
            case "else":
                throw .syntax("Zu diesem else gibt es kein passendes if (steht vielleicht ein ; hinter der if-Bedingung?).", line: line)
            case "case", "default":
                throw .syntax("„\(token.text)“ darf nur innerhalb von switch stehen.", line: line)
            case "public", "private", "protected", "static":
                throw .syntax("„\(token.text)“ darf nicht innerhalb einer Methode stehen.", line: line)
            default:
                break
            }
        }
        // Kontextuelle Schlüsselwörter (sealed, non-sealed, permits): gültiges Java, das hier nicht unterstützt wird.
        if token.kind == .identifier, ["sealed", "non", "permits"].contains(token.text)
            || (token.kind == .identifier && ["class", "interface", "enum", "record"].contains(peek().text) && peek().kind == .keyword) {
            throw .unsupported("„\(token.text) …“-Typen (z. B. sealed interface) kennt der eingebaute Interpreter nicht.", line: line)
        }
        if token.kind == .identifier, peek().is(":"), !peek(2).is(":") {
            throw .unsupported("Sprungmarken kennt der eingebaute Interpreter nicht.", line: line)
        }
        if looksLikeDeclaration() {
            let isFinal = accept("final")
            return try declarationStatement(isFinal: isFinal)
        }
        let expr = try expression()
        try expect(";")
        try requireStatementExpression(expr)
        return .expr(expr, line: line)
    }

    /// Java erlaubt als Anweisung nur Zuweisungen, ++/-- und Methodenaufrufe.
    private func requireStatementExpression(_ expr: JavaExpr) throws(JavaProblem) {
        switch expr {
        case .assign, .increment, .call, .switchExpr: return
        default:
            throw .syntax("Das ist keine vollständige Anweisung – der Wert wird berechnet, aber nirgends gespeichert oder ausgegeben.", line: expr.line)
        }
    }

    private mutating func declarationStatement(isFinal: Bool) throws(JavaProblem) -> JavaStmt {
        let line = current.line
        guard let type = try typeIfPresent(allowVoid: false) else {
            throw .syntax("Hier wird ein Typ erwartet, z. B. int oder String.", line: line)
        }
        if case .unknown(let name) = type.baseType {
            throw .unsupported("Den Typ \(name) kennt der eingebaute Interpreter nicht.", line: line)
        }
        var declarators: [JavaVarDeclarator] = []
        repeat {
            let declLine = current.line
            let name = try identifier("die Variable")
            var extra = 0
            while accept("[") { try expect("]"); extra += 1 }
            var initializer: JavaExpr?
            if accept("=") {
                if current.is("{") {
                    initializer = try arrayInitializer(element: elementType(of: type, extra: extra))
                } else {
                    initializer = try expression()
                }
            } else if type == .inferred {
                throw .syntax("Mit var braucht die Variable sofort einen Wert, z. B. var x = 5;", line: declLine)
            }
            declarators.append(JavaVarDeclarator(name: name, extraDimensions: extra, initializer: initializer, line: declLine))
        } while accept(",")
        try expect(";")
        return .varDecl(type, declarators, isFinal: isFinal, line: line)
    }

    private func elementType(of type: JavaType, extra: Int) -> JavaType? {
        var full = type
        for _ in 0..<extra { full = .array(full) }
        if case .array(let element) = full { return element }
        return nil
    }

    private mutating func arrayInitializer(element: JavaType?) throws(JavaProblem) -> JavaExpr {
        let line = current.line
        try expect("{")
        var items: [JavaExpr] = []
        let inner: JavaType? = if case .array(let nested)? = element { nested } else { nil }
        while !current.is("}") {
            items.append(current.is("{") ? try arrayInitializer(element: inner) : try expression())
            if !accept(",") { break }
        }
        try expect("}", "Die Werteliste wird mit } geschlossen.")
        return .arrayLiteral(element: element, items, line: line)
    }

    private mutating func parenthesized(_ keyword: String) throws(JavaProblem) -> JavaExpr {
        try expect("(", "Nach \(keyword) folgt die Bedingung in runden Klammern.")
        let expr = try expression()
        try expect(")", "Die Bedingung von \(keyword) wird mit ) geschlossen.")
        return expr
    }

    private mutating func forStatement() throws(JavaProblem) -> JavaStmt {
        let line = current.line
        try expect("for")
        try expect("(", "Nach for folgen runde Klammern.")
        // for-each: for (int z : zahlen)
        let start = position
        _ = accept("final")
        if let type = try? typeIfPresent(allowVoid: false), current.kind == .identifier, peek().is(":") {
            let name = advance().text
            try expect(":")
            let collection = try expression()
            try expect(")")
            return .forEach(type, name, collection, try statement(), line: line)
        }
        position = start

        var initializers: [JavaStmt] = []
        if !current.is(";") {
            if looksLikeDeclaration() {
                let isFinal = accept("final")
                initializers.append(try declarationStatement(isFinal: isFinal))
                position -= 1 // declarationStatement hat das ; gelesen – unten erneut erwartet.
            } else {
                repeat {
                    let expr = try expression()
                    initializers.append(.expr(expr, line: expr.line))
                } while accept(",")
            }
        }
        try expect(";", nil)
        let condition: JavaExpr? = current.is(";") ? nil : try expression()
        try expect(";")
        var updates: [JavaExpr] = []
        if !current.is(")") {
            repeat { updates.append(try expression()) } while accept(",")
        }
        try expect(")", "Der Kopf der for-Schleife wird mit ) geschlossen.")
        return .forStmt(init: initializers, condition: condition, update: updates, body: try statement(), line: line)
    }

    private mutating func switchBody(isExpression: Bool) throws(JavaProblem) -> [JavaSwitchCase] {
        let open = current.line
        try expect("{", "Der switch-Block beginnt mit {.")
        var cases: [JavaSwitchCase] = []
        while !current.is("}") {
            guard current.kind != .end else { throw .syntax("Der switch-Block wird nicht mit } geschlossen.", line: open) }
            let line = current.line
            var labels: [JavaExpr] = []
            var isDefault = false
            if accept("default") {
                isDefault = true
            } else {
                try expect("case", "Im switch-Block stehen case- und default-Zweige.")
                repeat {
                    if accept("default") { isDefault = true; continue }
                    labels.append(try ternary())
                } while accept(",")
            }
            if accept("->") {
                if current.is("{") {
                    let blockLine = advance().line
                    cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: true, body: try blockBody(openedAt: blockLine), value: nil, line: line))
                } else if current.is("throw") {
                    throw .unsupported("throw kennt der eingebaute Interpreter nicht.", line: current.line)
                } else {
                    let value = try expression()
                    try expect(";")
                    if isExpression {
                        cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: true, body: [], value: value, line: line))
                    } else {
                        try requireStatementExpression(value)
                        cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: true, body: [.expr(value, line: value.line)], value: nil, line: line))
                    }
                }
            } else {
                try expect(":", "Nach dem case-Wert folgt ein Doppelpunkt (:) oder ein Pfeil (->).")
                var body: [JavaStmt] = []
                while !current.is("case"), !current.is("default"), !current.is("}"), current.kind != .end {
                    body.append(try statement())
                }
                cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: false, body: body, value: nil, line: line))
            }
        }
        try expect("}")
        let arrows = Set(cases.map(\.isArrow))
        if arrows.count > 1 {
            throw .syntax("In einem switch dürfen „case …:“ und „case … ->“ nicht gemischt werden.", line: open)
        }
        return cases
    }

    // MARK: - Ausdrücke

    private static let assignmentOps: Set<String> = ["=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=", ">>>="]

    mutating func expression() throws(JavaProblem) -> JavaExpr {
        let target = try ternary()
        if current.kind == .symbol, Self.assignmentOps.contains(current.text) {
            let op = advance()
            switch target {
            case .name, .index, .field: break
            default: throw .syntax("Links vom „\(op.text)“ muss eine Variable stehen.", line: op.line)
            }
            let value = try expression()
            return .assign(op: op.text, target: target, value: value, line: op.line)
        }
        if current.is("->") {
            throw .unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", line: current.line)
        }
        return target
    }

    private mutating func ternary() throws(JavaProblem) -> JavaExpr {
        let condition = try binary(level: 0)
        guard current.is("?") else { return condition }
        let line = advance().line
        let then = try ternary()
        try expect(":", "Beim Bedingungsoperator ?: fehlt der Doppelpunkt.")
        let otherwise = try ternary()
        return .conditional(condition, then, otherwise, line: line)
    }

    private static let levels: [[String]] = [
        ["||"], ["&&"], ["|"], ["^"], ["&"], ["==", "!="], ["<", ">", "<=", ">=", "instanceof"],
        ["<<", ">>", ">>>"], ["+", "-"], ["*", "/", "%"],
    ]

    private mutating func binary(level: Int) throws(JavaProblem) -> JavaExpr {
        guard level < Self.levels.count else { return try unary() }
        var left = try binary(level: level + 1)
        while (current.kind == .symbol || current.is("instanceof")), Self.levels[level].contains(current.text) {
            let op = advance()
            if op.text == "instanceof" {
                guard let type = try typeIfPresent(allowVoid: false) else {
                    throw .syntax("Nach instanceof folgt ein Typ.", line: op.line)
                }
                if current.kind == .identifier {
                    throw .unsupported("instanceof mit Variable (Pattern Matching) kennt der eingebaute Interpreter nicht.", line: op.line)
                }
                left = .instanceOf(left, type, line: op.line)
                continue
            }
            let right = try binary(level: level + 1)
            if op.text == "&&" || op.text == "||" {
                left = .logical(op: op.text, left, right, line: op.line)
            } else {
                left = .binary(op: op.text, left, right, line: op.line)
            }
        }
        return left
    }

    private mutating func unary() throws(JavaProblem) -> JavaExpr {
        let token = current
        if token.kind == .symbol {
            switch token.text {
            case "++", "--":
                _ = advance()
                return .increment(op: token.text, prefix: true, try unary(), line: token.line)
            case "-", "+", "!", "~":
                _ = advance()
                let operand = try unary()
                // -2147483648 ist als Literal erlaubt, obwohl 2147483648 allein zu groß wäre.
                if token.text == "-", case .literal(.long(let value), let line) = operand, value == 2_147_483_648, wasIntLiteral {
                    return .literal(.int(Int32.min), line: line)
                }
                return .unary(op: token.text, operand, line: token.line)
            case "(":
                if let cast = try castIfPresent() { return cast }
            default:
                break
            }
        }
        return try postfix(try primary())
    }

    private var wasIntLiteral: Bool { position > 0 && tokens[position - 1].kind == .intLiteral }

    private mutating func castIfPresent() throws(JavaProblem) -> JavaExpr? {
        let start = position
        let line = current.line
        _ = advance() // (
        let isPrimitive = current.kind == .keyword && Self.primitive[current.text] != nil
        let isStringCast = current.kind == .identifier && current.text == "String" && peek().is(")")
        if ["byte", "short", "float"].contains(current.text), current.kind == .keyword, peek().is(")") {
            throw .unsupported("Den Typ \(current.text) kennt der eingebaute Interpreter nicht.", line: line)
        }
        guard isPrimitive || isStringCast, let type = try typeIfPresent(allowVoid: false), accept(")") else {
            position = start
            return nil
        }
        return .cast(type, try unary(), line: line)
    }

    private mutating func postfix(_ base: JavaExpr) throws(JavaProblem) -> JavaExpr {
        var expr = base
        while true {
            let token = current
            if accept(".") {
                let name = try identifier("das Feld oder die Methode")
                if current.is("(") {
                    expr = .call(target: expr, name: name, args: try arguments(), line: token.line)
                } else {
                    expr = .field(expr, name, line: token.line)
                }
            } else if accept("[") {
                let index = try expression()
                try expect("]", "Der Index wird mit ] geschlossen.")
                expr = .index(expr, index, line: token.line)
            } else if token.is("++") || token.is("--") {
                _ = advance()
                expr = .increment(op: token.text, prefix: false, expr, line: token.line)
            } else if token.is("::") {
                throw .unsupported("Methodenreferenzen (::) kennt der eingebaute Interpreter nicht.", line: token.line)
            } else {
                return expr
            }
        }
    }

    private mutating func arguments() throws(JavaProblem) -> [JavaExpr] {
        try expect("(")
        var args: [JavaExpr] = []
        if !current.is(")") {
            repeat { args.append(try expression()) } while accept(",")
        }
        try expect(")", "Die Argumentliste wird mit ) geschlossen.")
        return args
    }

    private mutating func primary() throws(JavaProblem) -> JavaExpr {
        let token = advance()
        let line = token.line
        switch token.kind {
        case .intLiteral:
            guard let value = Int64(token.text) else { throw .syntax("Die Zahl \(token.text) ist zu groß.", line: line) }
            if value > Int64(Int32.max) {
                if value == 2_147_483_648 { return .literal(.long(value), line: line) }
                throw .syntax("Die Zahl \(token.text) ist zu groß für int. Für große Zahlen: long mit L am Ende (\(token.text)L).", line: line)
            }
            return .literal(.int(Int32(truncatingIfNeeded: value)), line: line)
        case .longLiteral:
            guard let value = Int64(token.text) else { throw .syntax("Die Zahl \(token.text) ist zu groß für long.", line: line) }
            return .literal(.long(value), line: line)
        case .doubleLiteral:
            guard let value = Double(token.text) else { throw .syntax("„\(token.text)“ ist keine gültige Kommazahl.", line: line) }
            return .literal(.double(value), line: line)
        case .stringLiteral:
            return .literal(.string(intern(token.text)), line: line)
        case .charLiteral:
            return .literal(.char(token.text.utf16.first ?? 0), line: line)
        case .identifier:
            if current.is("->") {
                throw .unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", line: line)
            }
            if current.is("(") {
                return .call(target: nil, name: token.text, args: try arguments(), line: line)
            }
            return .name(token.text, line: line)
        case .keyword:
            switch token.text {
            case "true": return .literal(.boolean(true), line: line)
            case "false": return .literal(.boolean(false), line: line)
            case "null": return .literal(.null, line: line)
            case "new": return try newExpression(line: line)
            case "switch":
                let subject = try parenthesized("switch")
                return .switchExpr(subject, try switchBody(isExpression: true), line: line)
            case "this", "super":
                throw .unsupported("„\(token.text)“ gibt es nur in Objekten – die kennt der eingebaute Interpreter nicht.", line: line)
            case "int", "long", "double", "boolean", "char":
                if current.is("."), peek().text == "class" {
                    throw .unsupported("Klassenliterale kennt der eingebaute Interpreter nicht.", line: line)
                }
                throw .syntax("Hier wird ein Wert erwartet, kein Typ. Für eine neue Variable: \(token.text) name = …;", line: line)
            default:
                throw .syntax("„\(token.text)“ ist hier fehl am Platz.", line: line)
            }
        case .symbol:
            if token.text == "(" {
                if current.is(")") || (current.kind == .identifier && (peek().is(",") || (peek().is(")") && peek(2).is("->")))) {
                    throw .unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", line: line)
                }
                let inner = try expression()
                try expect(")", "Hier fehlt eine schließende Klammer ).")
                return inner
            }
            if token.text == "{" {
                throw .syntax("Eine Werteliste { … } ist nur direkt bei der Deklaration erlaubt – sonst new int[] { … }.", line: line)
            }
            throw .syntax("„\(token.text)“ ist hier fehl am Platz – erwartet wird ein Wert.", line: line)
        case .end:
            throw .syntax("Der Code endet mitten in einem Ausdruck.", line: previousLine)
        }
    }

    private mutating func newExpression(line: Int) throws(JavaProblem) -> JavaExpr {
        var element: JavaType
        if current.kind == .keyword, let primitive = Self.primitive[current.text] {
            element = primitive
            _ = advance()
        } else if current.kind == .identifier, current.text == "String" {
            element = .string
            _ = advance()
            if current.is("(") {
                return .newObject(className: "String", args: try arguments(), line: line)
            }
        } else if current.kind == .identifier {
            throw .unsupported("Objekte mit new \(current.text)(…) kennt der eingebaute Interpreter nicht.", line: line)
        } else {
            throw .syntax("Nach new folgt ein Typ, z. B. new int[5].", line: line)
        }
        guard current.is("[") else {
            throw .unsupported("Objekte mit new \(element)(…) kennt der eingebaute Interpreter nicht.", line: line)
        }
        var sizes: [JavaExpr] = []
        var extra = 0
        while current.is("[") {
            _ = advance()
            if accept("]") {
                extra += 1
            } else {
                if extra > 0 { throw .syntax("Größenangaben müssen vorne stehen: new int[3][].", line: line) }
                sizes.append(try expression())
                try expect("]")
            }
        }
        if sizes.isEmpty {
            var arrayType = element
            for _ in 1..<max(extra, 1) { arrayType = .array(arrayType) }
            guard current.is("{") else {
                throw .syntax("new \(element)[] braucht eine Größe in den Klammern oder eine Werteliste { … }.", line: line)
            }
            return try arrayInitializer(element: arrayType)
        }
        if current.is("{") {
            throw .syntax("Entweder Größe oder Werteliste – beides zusammen geht nicht.", line: line)
        }
        return .newArray(element: element, sizes: sizes, extraDimensions: extra, line: line)
    }
}

extension JavaType {
    var baseType: JavaType {
        if case .array(let element) = self { return element.baseType }
        return self
    }
}
