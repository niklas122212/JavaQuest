package app.javaquest.core.interpreter

/**
 * Rekursiver Abstiegsparser für die Java-Teilmenge des Interpreters (gleiche Regeln wie die Apple-App).
 * Akzeptiert lose Anweisungen mit statischen Methoden dazwischen oder ganze Programme mit Klassen,
 * Interfaces, Enums und Records. Lambdas, Streams, Threads & Co. melden „nicht unterstützt“ –
 * dann greift in der App die regelbasierte Prüfung.
 */
class JavaParser private constructor(private val tokens: List<Token>) {
    private var position = 0
    /** String-Pool: Gleiche Literale sind in Java dasselbe Objekt. */
    private val pool = mutableMapOf<String, JavaString>()
    /**
     * Namen aller Klassen, Interfaces, Enums und Records im Programm – vorab gesammelt,
     * damit `Hund h = …` schon vor der Klasse Hund als Deklaration erkannt wird.
     */
    private val declaredTypes = mutableSetOf<String>()
    /** Typparameter wie `T` in `class Box<T>` – sie stehen für „irgendein Objekt“. */
    private val typeParameters = mutableSetOf<String>()
    /** Klassen, die beim Lesen entstehen (auch lokale Klassen in Methoden). */
    private val classes = LinkedHashMap<String, ClassDecl>()
    private val classOrder = mutableListOf<String>()
    /** Gerade gelesene Annotation (`@Override`) – gilt für die nächste Methode. */
    private var sawOverride = false

    init {
        for (index in 0 until tokens.size - 1) {
            if (tokens[index].kind == Token.Kind.KEYWORD && tokens[index].text in setOf("class", "interface", "enum", "record") &&
                tokens[index + 1].kind == Token.Kind.IDENTIFIER
            ) declaredTypes += tokens[index + 1].text
        }
        // „record“ ist ein kontextuelles Wort – der Lexer kann es als Schlüsselwort oder Bezeichner liefern.
        for (index in 0 until tokens.size - 2) {
            if (tokens[index].kind != Token.Kind.STRING && tokens[index].text == "record" &&
                tokens[index + 1].kind == Token.Kind.IDENTIFIER && tokens[index + 2].isSym("(")
            ) declaredTypes += tokens[index + 1].text
        }
    }

    companion object {
        fun parse(source: String): Program = JavaParser(JavaLexer.tokenize(source)).parseProgram()

        private val modifierWords = setOf("public", "private", "protected", "static", "final", "abstract", "default", "synchronized")
        private val primitive = mapOf("int" to JType.IntT, "long" to JType.LongT, "double" to JType.DoubleT, "boolean" to JType.BooleanT, "char" to JType.CharT)
        private val assignmentOps = setOf("=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=", ">>>=")
        private val levels = listOf(
            listOf("||"), listOf("&&"), listOf("|"), listOf("^"), listOf("&"), listOf("==", "!="),
            listOf("<", ">", "<=", ">=", "instanceof"), listOf("<<", ">>", ">>>"), listOf("+", "-"), listOf("*", "/", "%"),
        )
    }

    // MARK: Token-Hilfen

    private val current: Token get() = tokens[position]
    private fun peek(offset: Int = 1): Token = tokens[minOf(position + offset, tokens.size - 1)]
    private val previousLine: Int get() = if (position > 0) tokens[position - 1].line else current.line

    private fun advance(): Token {
        val token = tokens[position]
        if (position < tokens.size - 1) position++
        return token
    }

    private fun accept(symbol: String): Boolean {
        if (!current.isSym(symbol)) return false
        position++
        return true
    }

    private fun expect(symbol: String, message: String? = null) {
        if (accept(symbol)) return
        // Wie javac: Das fehlende Semikolon gehört zur vorigen Zeile.
        if (symbol == ";") throw JavaProblem.syntax("Hier fehlt ein Semikolon (;) am Ende der Anweisung.", previousLine)
        val found = if (current.kind == Token.Kind.END) "das Ende des Codes" else "„${current.text}“"
        throw JavaProblem.syntax(message ?: "Erwartet wurde „$symbol“, gefunden $found.", if (current.kind == Token.Kind.END) previousLine else current.line)
    }

    private fun identifier(what: String): String {
        if (current.kind != Token.Kind.IDENTIFIER) {
            if (current.kind == Token.Kind.KEYWORD) {
                throw JavaProblem.syntax("„${current.text}“ ist ein reserviertes Java-Wort und kann nicht als $what dienen.", current.line)
            }
            throw JavaProblem.syntax("Hier wird ein Name für $what erwartet.", current.line)
        }
        return advance().text
    }

    private fun intern(text: String) = pool.getOrPut(text) { JavaString(text) }

    // MARK: Programm

    /** Liest Modifier wie public, static, sealed – und merkt sich @Override. */
    private fun modifiers(): MutableSet<String> {
        val mods = mutableSetOf<String>()
        while (true) {
            when {
                current.isSym("@") -> skipAnnotation()
                current.kind == Token.Kind.KEYWORD && current.text in modifierWords -> mods += advance().text
                current.kind == Token.Kind.IDENTIFIER && current.text == "sealed" && (isTypeKeyword(peek()) || peek().kind == Token.Kind.KEYWORD) -> advance()
                current.kind == Token.Kind.IDENTIFIER && current.text == "non" && peek().isSym("-") && peek(2).text == "sealed" -> position += 3
                else -> return mods
            }
        }
    }

    private fun isTypeKeyword(token: Token): Boolean =
        (token.kind == Token.Kind.KEYWORD && token.text in setOf("class", "interface", "enum")) ||
            (token.kind != Token.Kind.STRING && token.text == "record" && peek(2).kind == Token.Kind.IDENTIFIER)

    /** Steht hier `class`, `interface`, `enum` oder `record Name(`? */
    private val atTypeDeclaration: Boolean
        get() {
            if (current.kind == Token.Kind.KEYWORD && current.text in setOf("class", "interface", "enum")) return true
            return current.kind != Token.Kind.STRING && current.text == "record" && peek().kind == Token.Kind.IDENTIFIER && peek(2).isSym("(")
        }

    private fun parseProgram(): Program {
        val program = Program()
        while (current.kind != Token.Kind.END) {
            if (current.isSym("import") || current.isSym("package")) {
                while (current.kind != Token.Kind.END && !current.isSym(";")) advance()
                expect(";")
                continue
            }
            val start = position
            sawOverride = false
            val mods = modifiers()
            if (atTypeDeclaration) {
                parseTypeDeclaration(mods, null)
                continue
            }
            val method = parseMethodIfPresent(mods + "static")
            if (method != null) { add(method, program); continue }
            if ("static" in mods) {
                // static int zaehler = 0; zwischen eigenen Methoden: ein Feld für alle Methoden.
                program.staticFields += declarationStatement("final" in mods)
                continue
            }
            position = start
            program.statements += statement()
        }
        // Die Klasse mit main ist das Hauptprogramm: Ihre statischen Methoden und Felder gelten überall.
        val mainName = classOrder.firstOrNull { name -> classes[name]?.methods?.get("main")?.any { it.isStatic && it.returnType == JType.VoidT } == true }
        if (mainName != null) {
            if (program.hasMain || program.statements.isNotEmpty()) {
                throw JavaProblem.syntax("Neben einer main-Methode dürfen keine losen Anweisungen stehen – sie gehören in main.", program.statements.firstOrNull()?.line)
            }
            val mainClass = classes.getValue(mainName)
            for ((name, overloads) in mainClass.methods.entries.toList()) {
                for (method in overloads.filter { it.isStatic }) {
                    if (name == "main" && method.returnType == JType.VoidT) {
                        program.statements = method.body.toMutableList()
                        program.hasMain = true
                    } else {
                        add(method, program)
                    }
                }
                val remaining = overloads.filter { !it.isStatic }
                if (remaining.isEmpty()) mainClass.methods.remove(name) else mainClass.methods[name] = remaining.toMutableList()
            }
            for (field in mainClass.fields.filter { it.isStatic }) {
                program.staticFields += Stmt.VarDecl(field.type, listOf(Declarator(field.name, 0, field.initializer, field.line)), field.isFinal, field.line)
            }
            mainClass.fields.removeAll { it.isStatic }
            program.mainClass = mainName
        }
        // main ohne umgebende Klasse (wie in Java 21+ mit „implicit classes“).
        val main = program.methods["main"]?.firstOrNull()
        if (!program.hasMain && main != null && main.returnType == JType.VoidT) {
            if (program.statements.isNotEmpty()) {
                throw JavaProblem.syntax("Neben einer main-Methode dürfen keine losen Anweisungen stehen – sie gehören in main.", program.statements[0].line)
            }
            program.statements = main.body.toMutableList()
            program.hasMain = true
            program.methods.remove("main")
        }
        program.classes = classes
        program.classOrder = classOrder
        return program
    }

    private fun skipAnnotation() {
        expect("@")
        val name = identifier("die Annotation")
        if (name == "Override") sawOverride = true
        if (accept("(")) {
            var depth = 1
            while (depth > 0 && current.kind != Token.Kind.END) {
                if (current.isSym("(")) depth++
                if (current.isSym(")")) depth--
                advance()
            }
        }
    }

    private fun add(method: Method, program: Program) {
        val existing = program.methods.getOrPut(method.name) { mutableListOf() }
        if (existing.any { it.parameters.map(Parameter::type) == method.parameters.map(Parameter::type) }) {
            throw JavaProblem.syntax("Die Methode ${method.name} gibt es mit genau diesen Parametern schon.", method.line)
        }
        existing += method
    }

    /**
     * Liest `class`, `interface`, `enum` oder `record` samt Körper. Verschachtelte Typen werden
     * wie eigene Klassen abgelegt (mit `outer` für den Namen `Außen$Innen`).
     */
    private fun parseTypeDeclaration(mods: Set<String>, outer: String?) {
        val line = current.line
        val keyword = advance().text
        val name = identifier("den Typ")
        val kind = when (keyword) {
            "interface" -> ClassDecl.Kind.INTERFACE
            "enum" -> ClassDecl.Kind.ENUM
            "record" -> ClassDecl.Kind.RECORD
            else -> ClassDecl.Kind.CLASS
        }
        if (name in classes) throw JavaProblem.syntax("Den Typ $name gibt es schon.", line)
        val declaration = ClassDecl(name, kind, line)
        declaration.outer = outer
        declaration.isAbstract = "abstract" in mods || kind == ClassDecl.Kind.INTERFACE
        if (current.isSym("<")) typeParameterList()
        if (kind == ClassDecl.Kind.RECORD) {
            expect("(", "Nach record $name folgen die Felder in runden Klammern.")
            if (!current.isSym(")")) {
                do {
                    val type = typeIfPresent(allowVoid = false) ?: throw JavaProblem.syntax("Jedes Feld eines Records braucht einen Typ.", current.line)
                    declaration.recordComponents += Parameter(type, identifier("das Feld"))
                } while (accept(","))
            }
            expect(")")
        }
        if (accept("extends")) {
            if (kind == ClassDecl.Kind.INTERFACE) {
                do declaration.interfaces += typeName() while (accept(","))
            } else {
                declaration.superclass = typeName()
            }
        }
        if (accept("implements")) {
            do declaration.interfaces += typeName() while (accept(","))
        }
        if (current.kind == Token.Kind.IDENTIFIER && current.text == "permits") {
            advance()
            do typeName() while (accept(","))
        }
        expect("{", "Nach „$keyword $name“ beginnt der Körper mit {.")
        // Den Namen schon jetzt eintragen – Methoden dürfen sich auf den eigenen Typ beziehen.
        classOrder += name
        classes[name] = declaration
        if (kind == ClassDecl.Kind.ENUM) enumConstants(declaration)
        while (!current.isSym("}")) {
            if (current.kind == Token.Kind.END) throw JavaProblem.syntax("$name wird nicht mit } geschlossen.", line)
            if (accept(";")) continue
            sawOverride = false
            val memberMods = modifiers()
            if (atTypeDeclaration) {
                parseTypeDeclaration(memberMods, declaration.binaryName)
                continue
            }
            if (current.isSym("{")) throw JavaProblem.unsupported("Initialisierungsblöcke kennt der eingebaute Interpreter nicht.", current.line)
            val memberLine = current.line
            // Konstruktor: Name(…)
            if (current.kind == Token.Kind.IDENTIFIER && current.text == name && peek().isSym("(")) {
                advance()
                val parameters = parameterList(name)
                if (accept("throws")) { do typeName() while (accept(",")) }
                expect("{", "Der Körper des Konstruktors beginnt mit {.")
                declaration.constructors += Constructor(parameters, blockBody(memberLine), "private" in memberMods, memberLine)
                continue
            }
            if (kind == ClassDecl.Kind.RECORD && current.kind == Token.Kind.IDENTIFIER && current.text == name && peek().isSym("{")) {
                advance()
                val open = advance().line
                declaration.constructors += Constructor(declaration.recordComponents.toList(), blockBody(open), "private" in memberMods, memberLine, isCompact = true)
                continue
            }
            val isOverride = sawOverride
            val method = parseMethodIfPresent(memberMods, inInterface = kind == ClassDecl.Kind.INTERFACE)
            if (method != null) {
                method.isStatic = "static" in memberMods
                method.isPrivate = "private" in memberMods
                method.isOverride = isOverride
                method.owner = name
                if (method.isAbstract && kind != ClassDecl.Kind.INTERFACE && !declaration.isAbstract) {
                    throw JavaProblem.syntax("Die Methode ${method.name} hat keinen Körper – dann muss die Klasse $name abstract sein.", method.line)
                }
                val existing = declaration.methods.getOrPut(method.name) { mutableListOf() }
                if (existing.any { it.parameters.map(Parameter::type) == method.parameters.map(Parameter::type) }) {
                    throw JavaProblem.syntax("Die Methode ${method.name} gibt es mit genau diesen Parametern schon.", method.line)
                }
                existing += method
                continue
            }
            // Feld
            val type = typeIfPresent(allowVoid = false) ?: throw JavaProblem.syntax("Hier wird ein Feld, ein Konstruktor oder eine Methode erwartet.", current.line)
            val base = type.baseType
            if (base is JType.Unknown) throw JavaProblem.unsupported("Den Typ ${base.name} kennt der eingebaute Interpreter nicht.", memberLine)
            do {
                val fieldLine = current.line
                val fieldName = identifier("das Feld")
                var fieldType = type
                while (accept("[")) { expect("]"); fieldType = JType.Arr(fieldType) }
                var initializer: Expr? = null
                if (accept("=")) {
                    initializer = if (current.isSym("{")) arrayInitializer(elementType(fieldType, 0)) else expression()
                }
                // In Interfaces sind Felder immer Konstanten (static final).
                val isStatic = "static" in memberMods || kind == ClassDecl.Kind.INTERFACE
                declaration.fields += FieldDecl(
                    fieldType, fieldName, initializer, isStatic, "final" in memberMods || kind == ClassDecl.Kind.INTERFACE,
                    "private" in memberMods, fieldLine,
                )
            } while (accept(","))
            expect(";")
        }
        expect("}")
    }

    /** Enum-Konstanten: `ROT, GELB, GRUEN;` oder `ROT("Stehen"), …;` */
    private fun enumConstants(declaration: ClassDecl) {
        while (current.kind == Token.Kind.IDENTIFIER) {
            val line = current.line
            val constant = advance().text
            val args = if (current.isSym("(")) arguments() else emptyList()
            if (current.isSym("{")) throw JavaProblem.unsupported("Enum-Konstanten mit eigenem Körper kennt der eingebaute Interpreter nicht.", current.line)
            declaration.enumConstants += EnumConstant(constant, args, line)
            if (!accept(",")) break
        }
        accept(";")
    }

    /** `<T>`, `<K, V>`, `<T extends Comparable<T>>` – die Namen gelten als „irgendein Objekt“. */
    private fun typeParameterList() {
        expect("<")
        var depth = 1
        var expectName = true
        while (depth > 0 && current.kind != Token.Kind.END) {
            val token = advance()
            when {
                token.isSym("<") -> depth++
                token.isSym(">") -> depth--
                token.isSym(">>") -> depth -= 2
            }
            if (depth == 1 && expectName && token.kind == Token.Kind.IDENTIFIER) { typeParameters += token.text; expectName = false }
            if (depth == 1 && token.isSym(",")) expectName = true
        }
    }

    /** Name eines Typs nach extends/implements/throws – Generics werden überlesen. */
    private fun typeName(): String {
        var name = identifier("den Typ")
        while (current.isSym(".") && peek().kind == Token.Kind.IDENTIFIER) {
            advance()
            name += "." + advance().text
        }
        if (current.isSym("<")) skipGenerics()
        return name
    }

    private fun skipGenerics() {
        var depth = 0
        do {
            when {
                current.isSym("<") -> depth++
                current.isSym(">") -> depth--
                current.isSym(">>") -> depth -= 2
                current.isSym(">>>") -> depth -= 3
            }
            advance()
        } while (depth > 0 && current.kind != Token.Kind.END)
    }

    /** Parameterliste `(int a, String b)` – auch für Konstruktoren. */
    private fun parameterList(name: String): List<Parameter> {
        expect("(")
        val parameters = mutableListOf<Parameter>()
        if (!current.isSym(")")) {
            do {
                modifiers()
                val type = typeIfPresent(allowVoid = false)
                    ?: throw JavaProblem.syntax("Jeder Parameter braucht einen Typ, z. B. „int zahl“.", current.line)
                val base = type.baseType
                if (base is JType.Unknown) throw JavaProblem.unsupported("Den Typ ${base.name} kennt der eingebaute Interpreter nicht.", current.line)
                if (accept("...")) throw JavaProblem.unsupported("Variable Parameterlisten (…) kennt der eingebaute Interpreter nicht.", previousLine)
                var parameterType = type
                val parameterName = identifier("den Parameter")
                while (accept("[")) { expect("]"); parameterType = JType.Arr(parameterType) }
                parameters += Parameter(parameterType, parameterName)
            } while (accept(","))
        }
        expect(")", "Die Parameterliste von $name wird mit ) geschlossen.")
        return parameters
    }

    /** Erkennt `Typ name(` und liest die ganze Methode – sonst bleibt die Position unverändert. */
    private fun parseMethodIfPresent(mods: Set<String>, inInterface: Boolean = false): Method? {
        val start = position
        // Generische Methode: <T> void zeige(T wert) – T steht für „irgendein Objekt“.
        if (current.isSym("<")) typeParameterList()
        val line = current.line
        val returnType = try { typeIfPresent(allowVoid = true) } catch (e: JavaProblem) { null }
        if (returnType == null || current.kind != Token.Kind.IDENTIFIER || !peek().isSym("(")) {
            position = start
            return null
        }
        val base = returnType.baseType
        if (base is JType.Unknown) throw JavaProblem.unsupported("Den Typ ${base.name} kennt der eingebaute Interpreter nicht.", line)
        val name = advance().text
        val parameters = parameterList(name)
        if (accept("throws")) { do typeName() while (accept(",")) }
        if (accept(";")) {
            if (!("abstract" in mods || (inInterface && "default" !in mods && "static" !in mods))) {
                throw JavaProblem.syntax("Die Methode $name braucht einen Körper in { }.", line)
            }
            return Method(name, returnType, parameters, emptyList(), line, isStatic = false, isAbstract = true)
        }
        if ("abstract" in mods) throw JavaProblem.syntax("Eine abstrakte Methode hat keinen Körper – statt { … } steht dort nur ein Semikolon.", line)
        expect("{", "Der Körper der Methode $name beginnt mit {.")
        return Method(name, returnType, parameters, blockBody(line), line, isStatic = "static" in mods)
    }

    // MARK: Typen

    /** Liest einen Typ, falls einer kommt (inkl. `[]`). Wirft nur bei klar unpassendem Code. */
    private fun typeIfPresent(allowVoid: Boolean): JType? {
        var type: JType
        if (current.kind == Token.Kind.KEYWORD) {
            type = when (current.text) {
                "void" -> if (allowVoid) JType.VoidT else return null
                "var" -> JType.Inferred
                "byte", "short", "float" -> throw JavaProblem.unsupported("Den Typ ${current.text} kennt der eingebaute Interpreter nicht – nimm int oder double.", current.line)
                else -> primitive[current.text] ?: return null
            }
            advance()
        } else if (current.kind == Token.Kind.IDENTIFIER) {
            val name = advance().text
            if (name == "String") {
                type = JType.StringT
            } else {
                var full = name
                // Qualifizierte Namen wie java.util.List
                while (current.isSym(".") && peek().kind == Token.Kind.IDENTIFIER && position + 2 < tokens.size) {
                    val save = position
                    advance()
                    val part = advance().text
                    if (!(current.kind == Token.Kind.IDENTIFIER || current.isSym("<") || current.isSym("["))) {
                        position = save
                        break
                    }
                    full += ".$part"
                }
                if (current.isSym("<")) {
                    var depth = 0
                    do {
                        if (current.isSym("<")) depth++
                        if (current.isSym(">")) depth--
                        if (current.isSym(">>")) depth -= 2
                        full += current.text
                        advance()
                    } while (depth > 0 && current.kind != Token.Kind.END)
                }
                val base = full.substringBefore('<')
                type = when {
                    base in typeParameters -> JType.Obj("Object")
                    base in declaredTypes || base in JavaBuiltins.knownTypes -> JType.Obj(full)
                    else -> JType.Unknown(full)
                }
            }
        } else {
            return null
        }
        while (current.isSym("[") && peek().isSym("]")) {
            position += 2
            type = JType.Arr(type)
        }
        return type
    }

    /** Sieht nach `Typ Name` aus? Prüft ohne zu verbrauchen. */
    private fun looksLikeDeclaration(): Boolean {
        val start = position
        try {
            accept("final")
            val type = try { typeIfPresent(allowVoid = false) } catch (e: JavaProblem) { null } ?: return false
            if (type == JType.Inferred && current.kind != Token.Kind.IDENTIFIER) return false
            if (current.kind != Token.Kind.IDENTIFIER) return false
            val next = peek()
            return next.isSym("=") || next.isSym(";") || next.isSym(",") || next.isSym(":") || next.isSym("[")
        } finally {
            position = start
        }
    }

    // MARK: Anweisungen

    private fun blockBody(line: Int): List<Stmt> {
        val body = mutableListOf<Stmt>()
        while (!current.isSym("}")) {
            if (current.kind == Token.Kind.END) throw JavaProblem.syntax("Der Block aus Zeile $line wird nie mit } geschlossen.", line)
            body += statement()
        }
        advance()
        return body
    }

    private fun statement(): Stmt {
        val token = current
        val line = token.line
        if (token.kind == Token.Kind.KEYWORD || token.kind == Token.Kind.SYMBOL) {
            when (token.text) {
                "{" -> { advance(); return Stmt.Block(blockBody(line), line) }
                ";" -> { advance(); return Stmt.Empty(line) }
                "if" -> {
                    advance()
                    val condition = parenthesized("if")
                    val then = statement()
                    val otherwise = if (accept("else")) statement() else null
                    return Stmt.If(condition, then, otherwise, line)
                }
                "while" -> {
                    advance()
                    val condition = parenthesized("while")
                    return Stmt.While(condition, statement(), line)
                }
                "do" -> {
                    advance()
                    val body = statement()
                    expect("while", "Nach dem do-Block folgt while (…);")
                    val condition = parenthesized("while")
                    expect(";")
                    return Stmt.DoWhile(body, condition, line)
                }
                "for" -> return forStatement()
                "break" -> {
                    advance()
                    if (current.kind == Token.Kind.IDENTIFIER) throw JavaProblem.unsupported("break mit Sprungmarke kennt der eingebaute Interpreter nicht.", line)
                    expect(";")
                    return Stmt.Break(line)
                }
                "continue" -> {
                    advance()
                    if (current.kind == Token.Kind.IDENTIFIER) throw JavaProblem.unsupported("continue mit Sprungmarke kennt der eingebaute Interpreter nicht.", line)
                    expect(";")
                    return Stmt.Continue(line)
                }
                "return" -> {
                    advance()
                    if (accept(";")) return Stmt.Return(null, line)
                    val value = expression()
                    expect(";")
                    return Stmt.Return(value, line)
                }
                "yield" -> {
                    advance()
                    val value = expression()
                    expect(";")
                    return Stmt.Yield(value, line)
                }
                "switch" -> {
                    advance()
                    val subject = parenthesized("switch")
                    return Stmt.Switch(subject, switchBody(isExpression = false), line)
                }
                "throw" -> {
                    advance()
                    val value = expression()
                    expect(";")
                    return Stmt.Throw(value, line)
                }
                "try" -> return tryStatement()
                "catch", "finally" -> throw JavaProblem.syntax("„${token.text}“ gehört direkt hinter einen try-Block.", line)
                "class", "interface", "enum", "abstract" -> {
                    // Lokale Klasse: wird wie jede andere Klasse abgelegt.
                    val mods = modifiers()
                    parseTypeDeclaration(mods, null)
                    return Stmt.Empty(line)
                }
                "else" -> throw JavaProblem.syntax("Zu diesem else gibt es kein passendes if (steht vielleicht ein ; hinter der if-Bedingung?).", line)
                "case", "default" -> throw JavaProblem.syntax("„${token.text}“ darf nur innerhalb von switch stehen.", line)
                "public", "private", "protected", "static" -> throw JavaProblem.syntax("„${token.text}“ darf nicht innerhalb einer Methode stehen.", line)
            }
        }
        // Lokaler Record (record ist kein echtes Schlüsselwort) oder sealed interface in einer Methode.
        if (atTypeDeclaration || (token.kind == Token.Kind.IDENTIFIER && token.text == "sealed")) {
            val mods = modifiers()
            parseTypeDeclaration(mods, null)
            return Stmt.Empty(line)
        }
        if (token.kind == Token.Kind.IDENTIFIER && peek().isSym(":") && !peek(2).isSym(":")) {
            throw JavaProblem.unsupported("Sprungmarken kennt der eingebaute Interpreter nicht.", line)
        }
        if (looksLikeDeclaration()) {
            val isFinal = accept("final")
            return declarationStatement(isFinal)
        }
        val expr = expression()
        expect(";")
        requireStatementExpression(expr)
        return Stmt.ExprStmt(expr, line)
    }

    /** Java erlaubt als Anweisung nur Zuweisungen, ++/-- und Methodenaufrufe. */
    private fun requireStatementExpression(expr: Expr) {
        if (expr is Expr.Assign || expr is Expr.Increment || expr is Expr.Call || expr is Expr.SwitchExpr || expr is Expr.NewObject) return
        throw JavaProblem.syntax("Das ist keine vollständige Anweisung – der Wert wird berechnet, aber nirgends gespeichert oder ausgegeben.", expr.line)
    }

    /** `try { … } catch (A | B e) { … } finally { … }` */
    private fun tryStatement(): Stmt {
        val line = current.line
        expect("try")
        if (current.isSym("(")) throw JavaProblem.unsupported("try mit Ressourcen (try (…)) kennt der eingebaute Interpreter nicht.", line)
        expect("{", "Nach try folgt ein Block in { }.")
        val body = blockBody(line)
        val catches = mutableListOf<Catch>()
        while (current.isSym("catch")) {
            val catchLine = advance().line
            expect("(", "Nach catch folgt in Klammern, welche Exception aufgefangen wird.")
            modifiers()
            val types = mutableListOf(typeName())
            while (accept("|")) types += typeName()
            val name = identifier("die Exception-Variable")
            expect(")")
            expect("{", "Der catch-Block beginnt mit {.")
            catches += Catch(types, name, blockBody(catchLine), catchLine)
        }
        var finallyBody: List<Stmt>? = null
        if (current.isSym("finally")) {
            val finallyLine = advance().line
            expect("{", "Der finally-Block beginnt mit {.")
            finallyBody = blockBody(finallyLine)
        }
        if (catches.isEmpty() && finallyBody == null) throw JavaProblem.syntax("Zu try gehört mindestens ein catch- oder finally-Block.", line)
        return Stmt.Try(body, catches, finallyBody, line)
    }

    private fun declarationStatement(isFinal: Boolean): Stmt {
        val line = current.line
        val type = typeIfPresent(allowVoid = false) ?: throw JavaProblem.syntax("Hier wird ein Typ erwartet, z. B. int oder String.", line)
        val base = type.baseType
        if (base is JType.Unknown) throw JavaProblem.unsupported("Den Typ ${base.name} kennt der eingebaute Interpreter nicht.", line)
        val declarators = mutableListOf<Declarator>()
        do {
            val declLine = current.line
            val name = identifier("die Variable")
            var extra = 0
            while (accept("[")) { expect("]"); extra++ }
            var initializer: Expr? = null
            if (accept("=")) {
                initializer = if (current.isSym("{")) arrayInitializer(elementType(type, extra)) else expression()
            } else if (type == JType.Inferred) {
                throw JavaProblem.syntax("Mit var braucht die Variable sofort einen Wert, z. B. var x = 5;", declLine)
            }
            declarators += Declarator(name, extra, initializer, declLine)
        } while (accept(","))
        expect(";")
        return Stmt.VarDecl(type, declarators, isFinal, line)
    }

    private fun elementType(type: JType, extra: Int): JType? {
        var full = type
        repeat(extra) { full = JType.Arr(full) }
        return (full as? JType.Arr)?.element
    }

    private fun arrayInitializer(element: JType?): Expr {
        val line = current.line
        expect("{")
        val items = mutableListOf<Expr>()
        val inner = (element as? JType.Arr)?.element
        while (!current.isSym("}")) {
            items += if (current.isSym("{")) arrayInitializer(inner) else expression()
            if (!accept(",")) break
        }
        expect("}", "Die Werteliste wird mit } geschlossen.")
        return Expr.ArrayLiteral(element, items, line)
    }

    private fun parenthesized(keyword: String): Expr {
        expect("(", "Nach $keyword folgt die Bedingung in runden Klammern.")
        val expr = expression()
        expect(")", "Die Bedingung von $keyword wird mit ) geschlossen.")
        return expr
    }

    private fun forStatement(): Stmt {
        val line = current.line
        expect("for")
        expect("(", "Nach for folgen runde Klammern.")
        // for-each: for (int z : zahlen)
        val start = position
        accept("final")
        val type = try { typeIfPresent(allowVoid = false) } catch (e: JavaProblem) { null }
        if (type != null && current.kind == Token.Kind.IDENTIFIER && peek().isSym(":")) {
            val name = advance().text
            expect(":")
            val collection = expression()
            expect(")")
            return Stmt.ForEach(type, name, collection, statement(), line)
        }
        position = start

        val initializers = mutableListOf<Stmt>()
        if (!current.isSym(";")) {
            if (looksLikeDeclaration()) {
                val isFinal = accept("final")
                initializers += declarationStatement(isFinal)
                position-- // declarationStatement hat das ; gelesen – unten erneut erwartet.
            } else {
                do {
                    val expr = expression()
                    initializers += Stmt.ExprStmt(expr, expr.line)
                } while (accept(","))
            }
        }
        expect(";")
        val condition = if (current.isSym(";")) null else expression()
        expect(";")
        val updates = mutableListOf<Expr>()
        if (!current.isSym(")")) {
            do updates += expression() while (accept(","))
        }
        expect(")", "Der Kopf der for-Schleife wird mit ) geschlossen.")
        return Stmt.For(initializers, condition, updates, statement(), line)
    }

    /** `(int x, var y, Punkt(int a, int b))` hinter einem Record-Namen. */
    private fun patternComponents(): List<Pattern> {
        val open = current.line
        expect("(")
        val parts = mutableListOf<Pattern>()
        while (!current.isSym(")")) {
            if (current.kind == Token.Kind.END) throw JavaProblem.syntax("Das Record-Muster wird nicht mit ) geschlossen.", open)
            if (current.kind == Token.Kind.IDENTIFIER && peek().isSym("(") && current.text in declaredTypes) {
                val name = advance().text
                parts += Pattern.Record(name, patternComponents())
            } else {
                val type = typeIfPresent(allowVoid = false)
                if (type == null || current.kind != Token.Kind.IDENTIFIER) {
                    throw JavaProblem.syntax("Im Record-Muster steht für jedes Feld ein Typ und ein Name, z. B. Punkt(int x, int y).", current.line)
                }
                parts += Pattern.Binding(type, advance().text)
            }
            if (!accept(",")) break
        }
        expect(")", "Das Record-Muster wird mit ) geschlossen.")
        return parts
    }

    private fun switchBody(isExpression: Boolean): List<SwitchCase> {
        val open = current.line
        expect("{", "Der switch-Block beginnt mit {.")
        val cases = mutableListOf<SwitchCase>()
        while (!current.isSym("}")) {
            if (current.kind == Token.Kind.END) throw JavaProblem.syntax("Der switch-Block wird nicht mit } geschlossen.", open)
            val line = current.line
            val labels = mutableListOf<Expr>()
            var isDefault = false
            if (accept("default")) {
                isDefault = true
            } else {
                expect("case", "Im switch-Block stehen case- und default-Zweige.")
                do {
                    if (accept("default")) { isDefault = true; continue }
                    // Enum-Konstante: case ROT -> … (sonst sähe „ROT -> …“ wie ein Lambda aus)
                    if (current.kind == Token.Kind.IDENTIFIER && (peek().isSym("->") || peek().isSym(",") || peek().isSym(":"))) {
                        val constant = advance()
                        labels += Expr.Name(constant.text, constant.line)
                        continue
                    }
                    // Record-Muster: case Punkt(int x, int y) -> …
                    if (current.kind == Token.Kind.IDENTIFIER && peek().isSym("(") && current.text in declaredTypes) {
                        val patternLine = current.line
                        val name = advance().text
                        labels += Expr.RecordPattern(Expr.Name("\$switch", patternLine), Pattern.Record(name, patternComponents()), patternLine)
                        continue
                    }
                    // Typ-Muster: case Kreis k -> …
                    if (current.kind == Token.Kind.IDENTIFIER && (peek().kind == Token.Kind.IDENTIFIER || peek().isSym("<")) && !peek().isSym("->")) {
                        val patternLine = current.line
                        val save = position
                        val type = typeIfPresent(allowVoid = false)
                        if (type != null && current.kind == Token.Kind.IDENTIFIER) {
                            val binding = advance().text
                            labels += Expr.InstanceOf(Expr.Name("\$switch", patternLine), type, binding, patternLine)
                            continue
                        }
                        position = save
                    }
                    labels += ternary()
                } while (accept(","))
            }
            var guardExpr: Expr? = null
            if (current.kind == Token.Kind.IDENTIFIER && current.text == "when") {
                advance()
                guardExpr = ternary()
            }
            if (accept("->")) {
                when {
                    current.isSym("{") -> {
                        val blockLine = advance().line
                        cases += SwitchCase(labels, isDefault, true, blockBody(blockLine), null, line, guardExpr)
                    }
                    current.isSym("throw") -> {
                        val throwLine = advance().line
                        val value = expression()
                        expect(";")
                        cases += SwitchCase(labels, isDefault, true, listOf(Stmt.Throw(value, throwLine)), null, line, guardExpr)
                    }
                    else -> {
                        val value = expression()
                        expect(";")
                        if (isExpression) {
                            cases += SwitchCase(labels, isDefault, true, emptyList(), value, line, guardExpr)
                        } else {
                            requireStatementExpression(value)
                            cases += SwitchCase(labels, isDefault, true, listOf(Stmt.ExprStmt(value, value.line)), null, line, guardExpr)
                        }
                    }
                }
            } else {
                expect(":", "Nach dem case-Wert folgt ein Doppelpunkt (:) oder ein Pfeil (->).")
                val body = mutableListOf<Stmt>()
                while (!current.isSym("case") && !current.isSym("default") && !current.isSym("}") && current.kind != Token.Kind.END) {
                    body += statement()
                }
                cases += SwitchCase(labels, isDefault, false, body, null, line, guardExpr)
            }
        }
        expect("}")
        if (cases.map { it.isArrow }.toSet().size > 1) {
            throw JavaProblem.syntax("In einem switch dürfen „case …:“ und „case … ->“ nicht gemischt werden.", open)
        }
        return cases
    }

    // MARK: Ausdrücke

    private fun expression(): Expr {
        val target = ternary()
        if (current.kind == Token.Kind.SYMBOL && current.text in assignmentOps) {
            val op = advance()
            if (target !is Expr.Name && target !is Expr.Index && target !is Expr.Field) {
                throw JavaProblem.syntax("Links vom „${op.text}“ muss eine Variable stehen.", op.line)
            }
            return Expr.Assign(op.text, target, expression(), op.line)
        }
        if (current.isSym("->")) throw JavaProblem.unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", current.line)
        return target
    }

    private fun ternary(): Expr {
        val condition = binary(0)
        if (!current.isSym("?")) return condition
        val line = advance().line
        val then = ternary()
        expect(":", "Beim Bedingungsoperator ?: fehlt der Doppelpunkt.")
        return Expr.Conditional(condition, then, ternary(), line)
    }

    private fun binary(level: Int): Expr {
        if (level >= levels.size) return unary()
        var left = binary(level + 1)
        while ((current.kind == Token.Kind.SYMBOL || current.isSym("instanceof")) && current.text in levels[level]) {
            val op = advance()
            if (op.text == "instanceof") {
                val type = typeIfPresent(allowVoid = false) ?: throw JavaProblem.syntax("Nach instanceof folgt ein Typ.", op.line)
                val name = type.className
                if (current.isSym("(") && name != null) {
                    left = Expr.RecordPattern(left, Pattern.Record(name, patternComponents()), op.line)
                    continue
                }
                val binding = if (current.kind == Token.Kind.IDENTIFIER) advance().text else null
                left = Expr.InstanceOf(left, type, binding, op.line)
                continue
            }
            val right = binary(level + 1)
            left = if (op.text == "&&" || op.text == "||") Expr.Logical(op.text, left, right, op.line) else Expr.Binary(op.text, left, right, op.line)
        }
        return left
    }

    private fun unary(): Expr {
        val token = current
        if (token.kind == Token.Kind.SYMBOL) {
            when (token.text) {
                "++", "--" -> { advance(); return Expr.Increment(token.text, true, unary(), token.line) }
                "-", "+", "!", "~" -> {
                    advance()
                    val operand = unary()
                    // -2147483648 ist als Literal erlaubt, obwohl 2147483648 allein zu groß wäre.
                    if (token.text == "-" && operand is Expr.Literal && (operand.value as? JValue.LongV)?.value == 2_147_483_648L &&
                        tokens[position - 1].kind == Token.Kind.INT
                    ) {
                        return Expr.Literal(JValue.IntV(Int.MIN_VALUE), operand.line)
                    }
                    return Expr.Unary(token.text, operand, token.line)
                }
                "(" -> castIfPresent()?.let { return it }
            }
        }
        return postfix(primary())
    }

    private fun castIfPresent(): Expr? {
        val start = position
        val line = current.line
        advance() // (
        val isPrimitive = current.kind == Token.Kind.KEYWORD && current.text in primitive
        val isStringCast = current.kind == Token.Kind.IDENTIFIER && current.text == "String" && peek().isSym(")")
        // (Hund) tier, (List<String>) objekt: nur bei bekannten Typen und wenn danach ein Wert kommt.
        if (current.kind == Token.Kind.IDENTIFIER && !isStringCast && (current.text in declaredTypes || current.text in JavaBuiltins.knownTypes)) {
            val type = try { typeIfPresent(allowVoid = false) } catch (e: JavaProblem) { null }
            if (type != null && accept(")") &&
                (current.kind == Token.Kind.IDENTIFIER || current.kind == Token.Kind.STRING || current.isSym("(") || current.isSym("this") ||
                    current.isSym("new") || current.isSym("!"))
            ) {
                return Expr.Cast(type, unary(), line)
            }
            position = start
            return null
        }
        if (current.kind == Token.Kind.KEYWORD && current.text in listOf("byte", "short", "float") && peek().isSym(")")) {
            throw JavaProblem.unsupported("Den Typ ${current.text} kennt der eingebaute Interpreter nicht.", line)
        }
        if (isPrimitive || isStringCast) {
            val type = typeIfPresent(allowVoid = false)
            if (type != null && accept(")")) return Expr.Cast(type, unary(), line)
        }
        position = start
        return null
    }

    private fun postfix(base: Expr): Expr {
        var expr = base
        while (true) {
            val token = current
            when {
                accept(".") -> {
                    // Ausdrückliche Typangabe bei generischen Methoden: Liste.<Integer>leer()
                    if (current.isSym("<")) skipGenerics()
                    val name = identifier("das Feld oder die Methode")
                    expr = if (current.isSym("(")) Expr.Call(expr, name, arguments(), token.line) else Expr.Field(expr, name, token.line)
                }
                accept("[") -> {
                    val index = expression()
                    expect("]", "Der Index wird mit ] geschlossen.")
                    expr = Expr.Index(expr, index, token.line)
                }
                token.isSym("++") || token.isSym("--") -> {
                    advance()
                    expr = Expr.Increment(token.text, false, expr, token.line)
                }
                token.isSym("::") -> throw JavaProblem.unsupported("Methodenreferenzen (::) kennt der eingebaute Interpreter nicht.", token.line)
                else -> return expr
            }
        }
    }

    private fun arguments(): List<Expr> {
        expect("(")
        val args = mutableListOf<Expr>()
        if (!current.isSym(")")) {
            do args += expression() while (accept(","))
        }
        expect(")", "Die Argumentliste wird mit ) geschlossen.")
        return args
    }

    private fun primary(): Expr {
        val token = advance()
        val line = token.line
        return when (token.kind) {
            Token.Kind.INT -> {
                val value = token.text.toLongOrNull() ?: throw JavaProblem.syntax("Die Zahl ${token.text} ist zu groß.", line)
                when {
                    value == 2_147_483_648L -> Expr.Literal(JValue.LongV(value), line)
                    value > Int.MAX_VALUE -> throw JavaProblem.syntax("Die Zahl ${token.text} ist zu groß für int. Für große Zahlen: long mit L am Ende (${token.text}L).", line)
                    else -> Expr.Literal(JValue.IntV(value.toInt()), line)
                }
            }
            Token.Kind.LONG -> Expr.Literal(JValue.LongV(token.text.toLongOrNull() ?: throw JavaProblem.syntax("Die Zahl ${token.text} ist zu groß für long.", line)), line)
            Token.Kind.DOUBLE -> Expr.Literal(JValue.DoubleV(token.text.toDoubleOrNull() ?: throw JavaProblem.syntax("„${token.text}“ ist keine gültige Kommazahl.", line)), line)
            Token.Kind.STRING -> Expr.Literal(JValue.StrV(intern(token.text)), line)
            Token.Kind.CHAR -> Expr.Literal(JValue.CharV(token.text[0]), line)
            Token.Kind.IDENTIFIER -> {
                if (current.isSym("->")) throw JavaProblem.unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", line)
                if (current.isSym("(")) Expr.Call(null, token.text, arguments(), line) else Expr.Name(token.text, line)
            }
            Token.Kind.KEYWORD -> when (token.text) {
                "true" -> Expr.Literal(JValue.BoolV(true), line)
                "false" -> Expr.Literal(JValue.BoolV(false), line)
                "null" -> Expr.Literal(JValue.Null, line)
                "new" -> newExpression(line)
                "switch" -> {
                    val subject = parenthesized("switch")
                    Expr.SwitchExpr(subject, switchBody(isExpression = true), line)
                }
                // this(…) im Konstruktor ruft einen anderen Konstruktor derselben Klasse auf.
                "this" -> if (current.isSym("(")) Expr.Call(null, "this", arguments(), line) else Expr.This(line)
                "super" -> when {
                    current.isSym("(") -> Expr.Call(null, "super", arguments(), line)
                    current.isSym(".") -> Expr.SuperRef(line)
                    else -> throw JavaProblem.syntax("Nach super folgt ein Punkt und eine Methode, z. B. super.laut().", line)
                }
                "int", "long", "double", "boolean", "char" -> {
                    if (current.isSym(".") && peek().text == "class") throw JavaProblem.unsupported("Klassenliterale kennt der eingebaute Interpreter nicht.", line)
                    throw JavaProblem.syntax("Hier wird ein Wert erwartet, kein Typ. Für eine neue Variable: ${token.text} name = …;", line)
                }
                else -> throw JavaProblem.syntax("„${token.text}“ ist hier fehl am Platz.", line)
            }
            Token.Kind.SYMBOL -> {
                if (token.text == "(") {
                    if (current.isSym(")") || (current.kind == Token.Kind.IDENTIFIER && (peek().isSym(",") || (peek().isSym(")") && peek(2).isSym("->"))))) {
                        throw JavaProblem.unsupported("Lambdas (->) kennt der eingebaute Interpreter nicht.", line)
                    }
                    val inner = expression()
                    expect(")", "Hier fehlt eine schließende Klammer ).")
                    inner
                } else if (token.text == "{") {
                    throw JavaProblem.syntax("Eine Werteliste { … } ist nur direkt bei der Deklaration erlaubt – sonst new int[] { … }.", line)
                } else {
                    throw JavaProblem.syntax("„${token.text}“ ist hier fehl am Platz – erwartet wird ein Wert.", line)
                }
            }
            Token.Kind.END -> throw JavaProblem.syntax("Der Code endet mitten in einem Ausdruck.", previousLine)
        }
    }

    private fun newExpression(line: Int): Expr {
        val element: JType
        if (current.kind == Token.Kind.KEYWORD && current.text in primitive) {
            element = primitive.getValue(current.text)
            advance()
        } else if (current.kind == Token.Kind.IDENTIFIER && current.text == "String") {
            element = JType.StringT
            advance()
            if (current.isSym("(")) return Expr.NewObject("String", arguments(), line)
        } else if (current.kind == Token.Kind.IDENTIFIER) {
            val typeLine = current.line
            val type = typeIfPresent(allowVoid = false) ?: throw JavaProblem.syntax("Nach new folgt ein Typ, z. B. new int[5].", line)
            // Diamant-Operator: new ArrayList<>() – die Generics stehen schon im Typ.
            if (type is JType.Unknown) throw JavaProblem.unsupported("Objekte mit new ${type.name}(…) kennt der eingebaute Interpreter nicht.", typeLine)
            if (current.isSym("(")) {
                val args = arguments()
                if (current.isSym("{")) throw JavaProblem.unsupported("Anonyme Klassen (new …() { … }) kennt der eingebaute Interpreter nicht.", current.line)
                return Expr.NewObject(type.className ?: "Object", args, line)
            }
            // new Object[] { … }: Die leeren Klammern gehören schon zum Typ.
            if (type is JType.Arr && current.isSym("{")) return arrayInitializer(type.element)
            element = type
        } else {
            throw JavaProblem.syntax("Nach new folgt ein Typ, z. B. new int[5].", line)
        }
        if (!current.isSym("[")) throw JavaProblem.unsupported("Objekte mit new $element(…) kennt der eingebaute Interpreter nicht.", line)
        val sizes = mutableListOf<Expr>()
        var extra = 0
        while (current.isSym("[")) {
            advance()
            if (accept("]")) {
                extra++
            } else {
                if (extra > 0) throw JavaProblem.syntax("Größenangaben müssen vorne stehen: new int[3][].", line)
                sizes += expression()
                expect("]")
            }
        }
        if (sizes.isEmpty()) {
            var arrayType = element
            repeat(maxOf(extra, 1) - 1) { arrayType = JType.Arr(arrayType) }
            if (!current.isSym("{")) throw JavaProblem.syntax("new $element[] braucht eine Größe in den Klammern oder eine Werteliste { … }.", line)
            return arrayInitializer(arrayType)
        }
        if (current.isSym("{")) throw JavaProblem.syntax("Entweder Größe oder Werteliste – beides zusammen geht nicht.", line)
        return Expr.NewArray(element, sizes, extra, line)
    }
}
