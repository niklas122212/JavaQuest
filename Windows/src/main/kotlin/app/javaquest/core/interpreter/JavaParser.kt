package app.javaquest.core.interpreter

/**
 * Rekursiver Abstiegsparser für die Java-Teilmenge des Interpreters (gleiche Regeln wie die iOS-App).
 * Akzeptiert lose Anweisungen mit statischen Methoden dazwischen oder eine Klasse mit main.
 * Objekte eigener Klassen, Lambdas, Generics oder try/catch melden „nicht unterstützt“.
 */
class JavaParser private constructor(private val tokens: List<Token>) {
    private var position = 0
    private var classCount = 0
    /** String-Pool: Gleiche Literale sind in Java dasselbe Objekt. */
    private val pool = mutableMapOf<String, JavaString>()

    companion object {
        fun parse(source: String): Program = JavaParser(JavaLexer.tokenize(source)).parseProgram()

        private val modifiers = setOf("public", "private", "protected", "static", "final", "abstract")
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

    private fun parseProgram(): Program {
        val program = Program()
        while (current.kind != Token.Kind.END) {
            if (current.isSym("import") || current.isSym("package")) {
                while (current.kind != Token.Kind.END && !current.isSym(";")) advance()
                expect(";")
                continue
            }
            if (current.isSym("@")) { skipAnnotation(); continue }
            val start = position
            val mods = mutableSetOf<String>()
            while (current.kind == Token.Kind.KEYWORD && current.text in modifiers) mods += advance().text
            if (current.isSym("class")) { parseClass(program); continue }
            if (current.isSym("interface") || current.isSym("enum") || current.isSym("record")) {
                throw JavaProblem.unsupported("${current.text} kennt der eingebaute Interpreter nicht.", current.line)
            }
            val method = parseMethodIfPresent(mods)
            if (method != null) { add(method, program); continue }
            if ("static" in mods) {
                program.staticFields += declarationStatement("final" in mods)
                continue
            }
            position = start
            program.statements += statement()
        }
        // main ohne umgebende Klasse.
        val main = program.methods["main"]?.firstOrNull()
        if (!program.hasMain && main != null && main.returnType == JType.VoidT) {
            if (program.statements.isNotEmpty()) {
                throw JavaProblem.syntax("Neben einer main-Methode dürfen keine losen Anweisungen stehen – sie gehören in main.", program.statements[0].line)
            }
            program.statements = main.body.toMutableList()
            program.hasMain = true
            program.methods.remove("main")
        }
        return program
    }

    private fun skipAnnotation() {
        expect("@")
        identifier("die Annotation")
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

    private fun parseClass(program: Program) {
        val line = current.line
        expect("class")
        val name = identifier("die Klasse")
        classCount++
        if (classCount > 1) throw JavaProblem.unsupported("Mehrere Klassen kennt der eingebaute Interpreter nicht.", line)
        if (current.isSym("extends") || current.isSym("implements") || current.isSym("<")) {
            throw JavaProblem.unsupported("Vererbung und Interfaces kennt der eingebaute Interpreter nicht.", current.line)
        }
        expect("{", "Nach „class $name“ beginnt der Klassenkörper mit {.")
        while (!current.isSym("}")) {
            if (current.kind == Token.Kind.END) throw JavaProblem.syntax("Die Klasse $name wird nicht mit } geschlossen.", line)
            if (current.isSym("@")) { skipAnnotation(); continue }
            if (accept(";")) continue
            val mods = mutableSetOf<String>()
            while (current.kind == Token.Kind.KEYWORD && current.text in modifiers) mods += advance().text
            if (current.isSym("class") || current.isSym("interface") || current.isSym("enum") || current.isSym("record")) {
                throw JavaProblem.unsupported("Verschachtelte Typen kennt der eingebaute Interpreter nicht.", current.line)
            }
            if (current.kind == Token.Kind.IDENTIFIER && current.text == name && peek().isSym("(")) {
                throw JavaProblem.unsupported("Konstruktoren und Objekte eigener Klassen kennt der eingebaute Interpreter nicht.", current.line)
            }
            val method = parseMethodIfPresent(mods)
            if (method != null) {
                when {
                    method.name == "main" && method.returnType == JType.VoidT && "static" in mods -> {
                        program.statements += method.body
                        program.hasMain = true
                    }
                    "static" !in mods -> throw JavaProblem.unsupported("Objektmethoden (ohne static) kennt der eingebaute Interpreter nicht.", method.line)
                    else -> add(method, program)
                }
                continue
            }
            if ("static" !in mods) throw JavaProblem.unsupported("Objekt-Felder (ohne static) kennt der eingebaute Interpreter nicht.", current.line)
            program.staticFields += declarationStatement("final" in mods)
        }
        expect("}")
    }

    private fun parseMethodIfPresent(mods: Set<String>): Method? {
        val start = position
        if (current.isSym("<")) throw JavaProblem.unsupported("Generische Methoden kennt der eingebaute Interpreter nicht.", current.line)
        val line = current.line
        val returnType = try { typeIfPresent(allowVoid = true) } catch (e: JavaProblem) { null }
        if (returnType == null || current.kind != Token.Kind.IDENTIFIER || !peek().isSym("(")) {
            position = start
            return null
        }
        val name = advance().text
        expect("(")
        val parameters = mutableListOf<Parameter>()
        if (!current.isSym(")")) {
            do {
                accept("final")
                val type = typeIfPresent(allowVoid = false)
                    ?: throw JavaProblem.syntax("Jeder Parameter braucht einen Typ, z. B. „int zahl“.", current.line)
                if (accept("...")) throw JavaProblem.unsupported("Variable Parameterlisten (…) kennt der eingebaute Interpreter nicht.", previousLine)
                var parameterType = type
                val parameterName = identifier("den Parameter")
                while (accept("[")) { expect("]"); parameterType = JType.Arr(parameterType) }
                parameters += Parameter(parameterType, parameterName)
            } while (accept(","))
        }
        expect(")", "Die Parameterliste von $name wird mit ) geschlossen.")
        if (accept("throws")) {
            do identifier("die Exception") while (accept(","))
        }
        if ("abstract" in mods || current.isSym(";")) throw JavaProblem.unsupported("Methoden ohne Körper kennt der eingebaute Interpreter nicht.", line)
        expect("{", "Der Körper der Methode $name beginnt mit {.")
        return Method(name, returnType, parameters, blockBody(line), line)
    }

    // MARK: Typen

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
                while (current.isSym(".") && peek().kind == Token.Kind.IDENTIFIER) {
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
                type = JType.Unknown(full)
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
                "throw" -> throw JavaProblem.unsupported("throw kennt der eingebaute Interpreter nicht.", line)
                "try", "catch", "finally" -> throw JavaProblem.unsupported("try/catch kennt der eingebaute Interpreter nicht.", line)
                "class", "interface", "enum", "record" -> throw JavaProblem.unsupported("Typen innerhalb von Methoden kennt der eingebaute Interpreter nicht.", line)
                "else" -> throw JavaProblem.syntax("Zu diesem else gibt es kein passendes if (steht vielleicht ein ; hinter der if-Bedingung?).", line)
                "case", "default" -> throw JavaProblem.syntax("„${token.text}“ darf nur innerhalb von switch stehen.", line)
                "public", "private", "protected", "static" -> throw JavaProblem.syntax("„${token.text}“ darf nicht innerhalb einer Methode stehen.", line)
            }
        }
        // Kontextuelle Schlüsselwörter (sealed, non-sealed, permits): gültiges Java, hier nicht unterstützt.
        if (token.kind == Token.Kind.IDENTIFIER && (token.text in setOf("sealed", "non", "permits") ||
                (peek().kind == Token.Kind.KEYWORD && peek().text in setOf("class", "interface", "enum", "record")))) {
            throw JavaProblem.unsupported("„${token.text} …“-Typen (z. B. sealed interface) kennt der eingebaute Interpreter nicht.", line)
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
        if (expr is Expr.Assign || expr is Expr.Increment || expr is Expr.Call || expr is Expr.SwitchExpr) return
        throw JavaProblem.syntax("Das ist keine vollständige Anweisung – der Wert wird berechnet, aber nirgends gespeichert oder ausgegeben.", expr.line)
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
                    labels += ternary()
                } while (accept(","))
            }
            if (accept("->")) {
                when {
                    current.isSym("{") -> {
                        val blockLine = advance().line
                        cases += SwitchCase(labels, isDefault, true, blockBody(blockLine), null, line)
                    }
                    current.isSym("throw") -> throw JavaProblem.unsupported("throw kennt der eingebaute Interpreter nicht.", current.line)
                    else -> {
                        val value = expression()
                        expect(";")
                        if (isExpression) {
                            cases += SwitchCase(labels, isDefault, true, emptyList(), value, line)
                        } else {
                            requireStatementExpression(value)
                            cases += SwitchCase(labels, isDefault, true, listOf(Stmt.ExprStmt(value, value.line)), null, line)
                        }
                    }
                }
            } else {
                expect(":", "Nach dem case-Wert folgt ein Doppelpunkt (:) oder ein Pfeil (->).")
                val body = mutableListOf<Stmt>()
                while (!current.isSym("case") && !current.isSym("default") && !current.isSym("}") && current.kind != Token.Kind.END) {
                    body += statement()
                }
                cases += SwitchCase(labels, isDefault, false, body, null, line)
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
                if (current.kind == Token.Kind.IDENTIFIER) {
                    throw JavaProblem.unsupported("instanceof mit Variable (Pattern Matching) kennt der eingebaute Interpreter nicht.", op.line)
                }
                left = Expr.InstanceOf(left, type, op.line)
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
                        tokens[position - 1].kind == Token.Kind.INT) {
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
        advance()
        val isPrimitive = current.kind == Token.Kind.KEYWORD && current.text in primitive
        val isStringCast = current.kind == Token.Kind.IDENTIFIER && current.text == "String" && peek().isSym(")")
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
                "this", "super" -> throw JavaProblem.unsupported("„${token.text}“ gibt es nur in Objekten – die kennt der eingebaute Interpreter nicht.", line)
                "int", "long", "double", "boolean", "char" ->
                    throw JavaProblem.syntax("Hier wird ein Wert erwartet, kein Typ. Für eine neue Variable: ${token.text} name = …;", line)
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
            throw JavaProblem.unsupported("Objekte mit new ${current.text}(…) kennt der eingebaute Interpreter nicht.", line)
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
