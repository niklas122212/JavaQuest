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
    /// String-Pool: Gleiche Literale sind in Java dasselbe Objekt ("a" == "a" ist true).
    private var pool: [String: JavaString] = [:]
    /// Namen aller Klassen, Interfaces, Enums und Records im Programm – vorab gesammelt,
    /// damit `Hund h = …` schon vor der Klasse Hund als Deklaration erkannt wird.
    private var declaredTypes: Set<String> = []
    /// Typparameter wie `T` in `class Box<T>` – sie stehen für „irgendein Objekt“.
    private var typeParameters: Set<String> = []
    /// Klassen, die beim Lesen entstehen (auch lokale Klassen in Methoden).
    private var classes: [String: JavaClass] = [:]
    private var classOrder: [String] = []
    /// Gerade gelesene Annotation (`@Override`) – gilt für die nächste Methode.
    private var sawOverride = false

    init(tokens: [JavaToken]) {
        self.tokens = tokens
        for index in tokens.indices.dropLast() where tokens[index].kind == .keyword
            && ["class", "interface", "enum", "record"].contains(tokens[index].text) && tokens[index + 1].kind == .identifier {
            declaredTypes.insert(tokens[index + 1].text)
        }
        // „record“ ist ein kontextuelles Wort – der Lexer kann es als Schlüsselwort oder Bezeichner liefern.
        for index in tokens.indices.dropLast(2) where tokens[index].kind != .stringLiteral && tokens[index].text == "record"
            && tokens[index + 1].kind == .identifier && tokens[index + 2].is("(") {
            declaredTypes.insert(tokens[index + 1].text)
        }
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

    private static let modifiers: Set<String> = ["public", "private", "protected", "static", "final", "abstract", "default", "synchronized"]

    /// Liest Modifier wie public, static, sealed – und merkt sich @Override.
    private mutating func modifiers() throws(JavaProblem) -> Set<String> {
        var mods: Set<String> = []
        while true {
            if current.is("@") { try skipAnnotation(); continue }
            if Self.modifiers.contains(current.text), current.kind == .keyword {
                mods.insert(advance().text)
            } else if current.kind == .identifier, current.text == "sealed", isTypeKeyword(peek()) || peek().kind == .keyword {
                _ = advance()
            } else if current.kind == .identifier, current.text == "non", peek().is("-"), peek(2).text == "sealed" {
                position += 3
            } else {
                return mods
            }
        }
    }

    private func isTypeKeyword(_ token: JavaToken) -> Bool {
        (token.kind == .keyword && ["class", "interface", "enum"].contains(token.text))
            || (token.kind != .stringLiteral && token.text == "record" && peek(2).kind == .identifier)
    }

    /// Steht hier `class`, `interface`, `enum` oder `record Name(`?
    private var atTypeDeclaration: Bool {
        if current.kind == .keyword, ["class", "interface", "enum"].contains(current.text) { return true }
        return current.kind != .stringLiteral && current.text == "record" && peek().kind == .identifier && peek(2).is("(")
    }

    mutating func parseProgram() throws(JavaProblem) -> JavaProgram {
        var program = JavaProgram()
        while current.kind != .end {
            if current.is("import") || current.is("package") {
                while current.kind != .end, !current.is(";") { _ = advance() }
                try expect(";")
                continue
            }
            let start = position
            sawOverride = false
            let mods = try modifiers()
            if atTypeDeclaration {
                try parseTypeDeclaration(modifiers: mods, outer: nil)
                continue
            }
            if let method = try parseMethodIfPresent(modifiers: mods.union(["static"])) {
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
        // Die Klasse mit main ist das Hauptprogramm: Ihre statischen Methoden und Felder gelten überall.
        if let mainName = classOrder.first(where: { classes[$0]?.methods["main"]?.contains { $0.isStatic && $0.returnType == .void } == true }) {
            if program.hasMain || !program.statements.isEmpty {
                throw .syntax("Neben einer main-Methode dürfen keine losen Anweisungen stehen – sie gehören in main.", line: program.statements.first?.line)
            }
            var mainClass = classes[mainName]!
            for (name, overloads) in mainClass.methods {
                for method in overloads where method.isStatic {
                    if name == "main", method.returnType == .void {
                        program.statements = method.body
                        program.hasMain = true
                    } else {
                        try add(method, to: &program)
                    }
                }
                mainClass.methods[name] = overloads.filter { !$0.isStatic }
                if mainClass.methods[name]?.isEmpty == true { mainClass.methods[name] = nil }
            }
            for field in mainClass.fields where field.isStatic {
                program.staticFields.append(.varDecl(field.type, [JavaVarDeclarator(name: field.name, extraDimensions: 0, initializer: field.initializer, line: field.line)], isFinal: field.isFinal, line: field.line))
            }
            mainClass.fields = mainClass.fields.filter { !$0.isStatic }
            classes[mainName] = mainClass
            program.mainClass = mainName
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
        program.classes = classes
        program.classOrder = classOrder
        return program
    }

    private mutating func skipAnnotation() throws(JavaProblem) {
        try expect("@")
        let name = try identifier("die Annotation")
        if name == "Override" { sawOverride = true }
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

    /// Liest `class`, `interface`, `enum` oder `record` samt Körper. Verschachtelte Typen werden
    /// wie eigene Klassen abgelegt (mit `outer` für den Namen `Außen$Innen`).
    private mutating func parseTypeDeclaration(modifiers mods: Set<String>, outer: String?) throws(JavaProblem) {
        let line = current.line
        let keyword = advance().text
        let name = try identifier("den Typ")
        let kind: JavaClass.Kind = switch keyword {
        case "interface": .interface
        case "enum": .enumType
        case "record": .record
        default: .classType
        }
        if classes[name] != nil { throw .syntax("Den Typ \(name) gibt es schon.", line: line) }
        var declaration = JavaClass(name: name, kind: kind, line: line)
        declaration.outer = outer
        declaration.isAbstract = mods.contains("abstract") || kind == .interface
        if current.is("<") { try typeParameterList() }
        if kind == .record {
            try expect("(", "Nach record \(name) folgen die Felder in runden Klammern.")
            if !current.is(")") {
                repeat {
                    guard let type = try typeIfPresent(allowVoid: false) else {
                        throw .syntax("Jedes Feld eines Records braucht einen Typ.", line: current.line)
                    }
                    declaration.recordComponents.append(JavaParameter(type: type, name: try identifier("das Feld")))
                } while accept(",")
            }
            try expect(")")
        }
        if accept("extends") {
            if kind == .interface {
                repeat { declaration.interfaces.append(try typeName()) } while accept(",")
            } else {
                declaration.superclass = try typeName()
            }
        }
        if accept("implements") {
            repeat { declaration.interfaces.append(try typeName()) } while accept(",")
        }
        if current.kind == .identifier, current.text == "permits" {
            _ = advance()
            repeat { _ = try typeName() } while accept(",")
        }
        try expect("{", "Nach „\(keyword) \(name)“ beginnt der Körper mit {.")
        // Den Namen schon jetzt eintragen – Methoden dürfen sich auf den eigenen Typ beziehen.
        classOrder.append(name)
        if kind == .enumType { try enumConstants(into: &declaration) }
        while !current.is("}") {
            guard current.kind != .end else { throw .syntax("\(name) wird nicht mit } geschlossen.", line: line) }
            if accept(";") { continue }
            sawOverride = false
            let memberMods = try modifiers()
            if atTypeDeclaration {
                classes[name] = declaration
                try parseTypeDeclaration(modifiers: memberMods, outer: declaration.binaryName)
                declaration = classes[name] ?? declaration
                continue
            }
            if current.is("{") {
                throw .unsupported("Initialisierungsblöcke kennt der eingebaute Interpreter nicht.", line: current.line)
            }
            let memberLine = current.line
            // Konstruktor: Name(…)
            if current.kind == .identifier, current.text == name, peek().is("(") {
                _ = advance()
                let parameters = try parameterList(methodName: name)
                if accept("throws") { repeat { _ = try typeName() } while accept(",") }
                try expect("{", "Der Körper des Konstruktors beginnt mit {.")
                let body = try blockBody(openedAt: memberLine)
                declaration.constructors.append(JavaConstructor(parameters: parameters, body: body, isPrivate: memberMods.contains("private"), line: memberLine))
                continue
            }
            if kind == .record, current.kind == .identifier, current.text == name, peek().is("{") {
                _ = advance()
                let open = advance().line
                let body = try blockBody(openedAt: open)
                declaration.constructors.append(JavaConstructor(parameters: declaration.recordComponents, body: body,
                                                                isPrivate: memberMods.contains("private"), line: memberLine, isCompact: true))
                continue
            }
            let isOverride = sawOverride
            if var method = try parseMethodIfPresent(modifiers: memberMods, inInterface: kind == .interface) {
                method.isStatic = memberMods.contains("static")
                method.isPrivate = memberMods.contains("private")
                method.isOverride = isOverride
                method.owner = name
                if method.isAbstract, kind != .interface, !declaration.isAbstract {
                    throw .syntax("Die Methode \(method.name) hat keinen Körper – dann muss die Klasse \(name) abstract sein.", line: method.line)
                }
                let existing = declaration.methods[method.name] ?? []
                if existing.contains(where: { $0.parameters.map(\.type) == method.parameters.map(\.type) }) {
                    throw .syntax("Die Methode \(method.name) gibt es mit genau diesen Parametern schon.", line: method.line)
                }
                declaration.methods[method.name] = existing + [method]
                continue
            }
            // Feld
            guard let type = try typeIfPresent(allowVoid: false) else {
                throw .syntax("Hier wird ein Feld, ein Konstruktor oder eine Methode erwartet.", line: current.line)
            }
            if case .unknown(let typeName) = type.baseType {
                throw .unsupported("Den Typ \(typeName) kennt der eingebaute Interpreter nicht.", line: memberLine)
            }
            repeat {
                let fieldLine = current.line
                let fieldName = try identifier("das Feld")
                var fieldType = type
                while accept("[") { try expect("]"); fieldType = .array(fieldType) }
                var initializer: JavaExpr?
                if accept("=") {
                    initializer = current.is("{") ? try arrayInitializer(element: elementType(of: fieldType, extra: 0)) : try expression()
                }
                // In Interfaces sind Felder immer Konstanten (static final).
                let isStatic = memberMods.contains("static") || kind == .interface
                declaration.fields.append(JavaField(type: fieldType, name: fieldName, initializer: initializer, isStatic: isStatic,
                                                    isFinal: memberMods.contains("final") || kind == .interface,
                                                    isPrivate: memberMods.contains("private"), line: fieldLine))
            } while accept(",")
            try expect(";")
        }
        try expect("}")
        classes[name] = declaration
    }

    /// Enum-Konstanten: `ROT, GELB, GRUEN;` oder `ROT("Stehen"), …;`
    private mutating func enumConstants(into declaration: inout JavaClass) throws(JavaProblem) {
        while current.kind == .identifier {
            let line = current.line
            let constant = advance().text
            let args = current.is("(") ? try arguments() : []
            if current.is("{") {
                throw .unsupported("Enum-Konstanten mit eigenem Körper kennt der eingebaute Interpreter nicht.", line: current.line)
            }
            declaration.enumConstants.append(JavaEnumConstant(name: constant, args: args, line: line))
            if !accept(",") { break }
        }
        _ = accept(";")
    }

    /// `<T>`, `<K, V>`, `<T extends Comparable<T>>` – die Namen gelten als „irgendein Objekt“.
    private mutating func typeParameterList() throws(JavaProblem) {
        try expect("<")
        var depth = 1
        var expectName = true
        while depth > 0, current.kind != .end {
            let token = advance()
            if token.is("<") { depth += 1 } else if token.is(">") { depth -= 1 } else if token.is(">>") { depth -= 2 }
            if depth == 1, expectName, token.kind == .identifier { typeParameters.insert(token.text); expectName = false }
            if depth == 1, token.is(",") { expectName = true }
        }
    }

    /// Name eines Typs nach extends/implements/throws – Generics werden überlesen.
    private mutating func typeName() throws(JavaProblem) -> String {
        var name = try identifier("den Typ")
        while current.is("."), peek().kind == .identifier {
            _ = advance()
            name += "." + advance().text
        }
        if current.is("<") { try skipGenerics() }
        return name
    }

    private mutating func skipGenerics() throws(JavaProblem) {
        var depth = 0
        repeat {
            if current.is("<") { depth += 1 }
            if current.is(">") { depth -= 1 }
            if current.is(">>") { depth -= 2 }
            if current.is(">>>") { depth -= 3 }
            _ = advance()
        } while depth > 0 && current.kind != .end
    }

    /// Parameterliste `(int a, String b)` – auch für Konstruktoren.
    private mutating func parameterList(methodName name: String) throws(JavaProblem) -> [JavaParameter] {
        try expect("(")
        var parameters: [JavaParameter] = []
        if !current.is(")") {
            repeat {
                _ = try modifiers()
                guard let type = try typeIfPresent(allowVoid: false) else {
                    throw .syntax("Jeder Parameter braucht einen Typ, z. B. „int zahl“.", line: current.line)
                }
                if case .unknown(let typeName) = type.baseType {
                    throw .unsupported("Den Typ \(typeName) kennt der eingebaute Interpreter nicht.", line: current.line)
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
        return parameters
    }

    /// Erkennt `Typ name(` und liest die ganze Methode – sonst bleibt die Position unverändert.
    private mutating func parseMethodIfPresent(modifiers: Set<String>, inInterface: Bool = false) throws(JavaProblem) -> JavaMethod? {
        let start = position
        if current.is("<") {
            // Generische Methode: <T> void zeige(T wert) – T steht für „irgendein Objekt“.
            try typeParameterList()
        }
        let line = current.line
        guard let returnType = try? typeIfPresent(allowVoid: true),
              current.kind == .identifier, peek().is("(") else {
            position = start
            return nil
        }
        if case .unknown(let typeName) = returnType.baseType {
            throw .unsupported("Den Typ \(typeName) kennt der eingebaute Interpreter nicht.", line: line)
        }
        let name = advance().text
        let parameters = try parameterList(methodName: name)
        if accept("throws") {
            repeat { _ = try typeName() } while accept(",")
        }
        if accept(";") {
            guard modifiers.contains("abstract") || (inInterface && !modifiers.contains("default") && !modifiers.contains("static")) else {
                throw .syntax("Die Methode \(name) braucht einen Körper in { }.", line: line)
            }
            return JavaMethod(name: name, returnType: returnType, parameters: parameters, body: [], line: line, isStatic: false, isAbstract: true)
        }
        if modifiers.contains("abstract") {
            throw .syntax("Eine abstrakte Methode hat keinen Körper – statt { … } steht dort nur ein Semikolon.", line: line)
        }
        try expect("{", "Der Körper der Methode \(name) beginnt mit {.")
        let body = try blockBody(openedAt: line)
        return JavaMethod(name: name, returnType: returnType, parameters: parameters, body: body, line: line, isStatic: modifiers.contains("static"))
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
                let base = String(full.prefix { $0 != "<" })
                if typeParameters.contains(base) {
                    type = .object("Object")
                } else if declaredTypes.contains(base) || JavaBuiltins.knownTypes.contains(base) {
                    type = .object(full)
                } else {
                    type = .unknown(full)
                }
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
                _ = advance()
                let value = try expression()
                try expect(";")
                return .throwStmt(value, line: line)
            case "try":
                return try tryStatement()
            case "catch", "finally":
                throw .syntax("„\(token.text)“ gehört direkt hinter einen try-Block.", line: line)
            case "class", "interface", "enum", "abstract":
                // Lokale Klasse: wird wie jede andere Klasse abgelegt.
                let mods = try modifiers()
                try parseTypeDeclaration(modifiers: mods, outer: nil)
                return .empty(line: line)
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
        // Lokaler Record (record ist kein echtes Schlüsselwort) oder sealed interface in einer Methode.
        if atTypeDeclaration || (token.kind == .identifier && token.text == "sealed") {
            let mods = try modifiers()
            try parseTypeDeclaration(modifiers: mods, outer: nil)
            return .empty(line: line)
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
        case .assign, .increment, .call, .switchExpr, .newObject: return
        default:
            throw .syntax("Das ist keine vollständige Anweisung – der Wert wird berechnet, aber nirgends gespeichert oder ausgegeben.", line: expr.line)
        }
    }

    /// `try { … } catch (A | B e) { … } finally { … }`
    private mutating func tryStatement() throws(JavaProblem) -> JavaStmt {
        let line = current.line
        try expect("try")
        if current.is("(") {
            throw .unsupported("try mit Ressourcen (try (…)) kennt der eingebaute Interpreter nicht.", line: line)
        }
        try expect("{", "Nach try folgt ein Block in { }.")
        let body = try blockBody(openedAt: line)
        var catches: [JavaCatch] = []
        while current.is("catch") {
            let catchLine = advance().line
            try expect("(", "Nach catch folgt in Klammern, welche Exception aufgefangen wird.")
            _ = try modifiers()
            var types = [try typeName()]
            while accept("|") { types.append(try typeName()) }
            let name = try identifier("die Exception-Variable")
            try expect(")")
            try expect("{", "Der catch-Block beginnt mit {.")
            catches.append(JavaCatch(types: types, name: name, body: try blockBody(openedAt: catchLine), line: catchLine))
        }
        var finallyBody: [JavaStmt]?
        if current.is("finally") {
            let finallyLine = advance().line
            try expect("{", "Der finally-Block beginnt mit {.")
            finallyBody = try blockBody(openedAt: finallyLine)
        }
        if catches.isEmpty, finallyBody == nil {
            throw .syntax("Zu try gehört mindestens ein catch- oder finally-Block.", line: line)
        }
        return .tryStmt(body: body, catches: catches, finally: finallyBody, line: line)
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

    /// `(int x, var y, Punkt(int a, int b))` hinter einem Record-Namen.
    private mutating func patternComponents() throws(JavaProblem) -> [JavaPattern] {
        let open = current.line
        try expect("(")
        var parts: [JavaPattern] = []
        while !current.is(")") {
            guard current.kind != .end else { throw .syntax("Das Record-Muster wird nicht mit ) geschlossen.", line: open) }
            if current.kind == .identifier, peek().is("("), declaredTypes.contains(current.text) {
                let name = advance().text
                parts.append(.record(name, try patternComponents()))
            } else {
                guard let type = try typeIfPresent(allowVoid: false), current.kind == .identifier else {
                    throw .syntax("Im Record-Muster steht für jedes Feld ein Typ und ein Name, z. B. Punkt(int x, int y).", line: current.line)
                }
                parts.append(.binding(type, advance().text))
            }
            if !accept(",") { break }
        }
        try expect(")", "Das Record-Muster wird mit ) geschlossen.")
        return parts
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
                    // Enum-Konstante: case ROT -> … (sonst sähe „ROT -> …“ wie ein Lambda aus)
                    if current.kind == .identifier, peek().is("->") || peek().is(",") || peek().is(":") {
                        let constant = advance()
                        labels.append(.name(constant.text, line: constant.line))
                        continue
                    }
                    // Record-Muster: case Punkt(int x, int y) -> …
                    if current.kind == .identifier, peek().is("("), declaredTypes.contains(current.text) {
                        let patternLine = current.line
                        let name = advance().text
                        labels.append(.recordPattern(.name("$switch", line: patternLine), .record(name, try patternComponents()), line: patternLine))
                        continue
                    }
                    // Typ-Muster: case Kreis k -> …
                    if current.kind == .identifier, peek().kind == .identifier || peek().is("<"), !peek().is("->") {
                        let patternLine = current.line
                        let save = position
                        if let type = try typeIfPresent(allowVoid: false), current.kind == .identifier {
                            let binding = advance().text
                            labels.append(.instanceOf(.name("$switch", line: patternLine), type, binding: binding, line: patternLine))
                            continue
                        }
                        position = save
                    }
                    labels.append(try ternary())
                } while accept(",")
            }
            var guardExpr: JavaExpr?
            if current.kind == .identifier, current.text == "when" {
                _ = advance()
                guardExpr = try ternary()
            }
            if accept("->") {
                if current.is("{") {
                    let blockLine = advance().line
                    cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: true, body: try blockBody(openedAt: blockLine), value: nil, line: line, guardExpr: guardExpr))
                } else if current.is("throw") {
                    let throwLine = advance().line
                    let value = try expression()
                    try expect(";")
                    cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: true, body: [.throwStmt(value, line: throwLine)], value: nil, line: line, guardExpr: guardExpr))
                } else {
                    let value = try expression()
                    try expect(";")
                    if isExpression {
                        cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: true, body: [], value: value, line: line, guardExpr: guardExpr))
                    } else {
                        try requireStatementExpression(value)
                        cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: true, body: [.expr(value, line: value.line)], value: nil, line: line, guardExpr: guardExpr))
                    }
                }
            } else {
                try expect(":", "Nach dem case-Wert folgt ein Doppelpunkt (:) oder ein Pfeil (->).")
                var body: [JavaStmt] = []
                while !current.is("case"), !current.is("default"), !current.is("}"), current.kind != .end {
                    body.append(try statement())
                }
                cases.append(JavaSwitchCase(labels: labels, isDefault: isDefault, isArrow: false, body: body, value: nil, line: line, guardExpr: guardExpr))
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
                if current.is("("), let name = type.className {
                    left = .recordPattern(left, .record(name, try patternComponents()), line: op.line)
                    continue
                }
                var binding: String?
                if current.kind == .identifier { binding = advance().text }
                left = .instanceOf(left, type, binding: binding, line: op.line)
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
        // (Hund) tier, (List<String>) objekt: nur bei bekannten Typen und wenn danach ein Wert kommt.
        if current.kind == .identifier, !isStringCast, declaredTypes.contains(current.text) || JavaBuiltins.knownTypes.contains(current.text) {
            if let type = try? typeIfPresent(allowVoid: false), accept(")"),
               current.kind == .identifier || current.kind == .stringLiteral || current.is("(") || current.is("this") || current.is("new") || current.is("!") {
                return .cast(type, try unary(), line: line)
            }
            position = start
            return nil
        }
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
                // Ausdrückliche Typangabe bei generischen Methoden: Liste.<Integer>leer()
                if current.is("<") { try skipGenerics() }
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
            case "this":
                // this(…) im Konstruktor ruft einen anderen Konstruktor derselben Klasse auf.
                if current.is("(") { return .call(target: nil, name: "this", args: try arguments(), line: line) }
                return .this(line: line)
            case "super":
                if current.is("(") { return .call(target: nil, name: "super", args: try arguments(), line: line) }
                guard current.is(".") else { throw .syntax("Nach super folgt ein Punkt und eine Methode, z. B. super.laut().", line: line) }
                return .superRef(line: line)
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
            let typeLine = current.line
            guard let type = try typeIfPresent(allowVoid: false) else {
                throw .syntax("Nach new folgt ein Typ, z. B. new int[5].", line: line)
            }
            if case .unknown(let name) = type {
                // Diamant-Operator: new ArrayList<>() – die Generics stehen schon im Typ.
                throw .unsupported("Objekte mit new \(name)(…) kennt der eingebaute Interpreter nicht.", line: typeLine)
            }
            if current.is("(") {
                let args = try arguments()
                if current.is("{") {
                    throw .unsupported("Anonyme Klassen (new …() { … }) kennt der eingebaute Interpreter nicht.", line: current.line)
                }
                return .newObject(className: type.className ?? "Object", args: args, line: line)
            }
            // new Object[] { … }: Die leeren Klammern gehören schon zum Typ.
            if case .array(let inner) = type, current.is("{") {
                return try arrayInitializer(element: inner)
            }
            element = type
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
