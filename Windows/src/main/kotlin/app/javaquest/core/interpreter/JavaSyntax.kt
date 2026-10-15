package app.javaquest.core.interpreter

import app.javaquest.core.JavaSource

/** Ein Fehler beim Ausführen von Java-Code – mit Zeile und Erklärung in Alltagssprache. */
class JavaProblem(val kind: Kind, override val message: String, val line: Int?) : Exception(message) {
    enum class Kind {
        /** Kein gültiges Java (würde auch javac ablehnen). */
        SYNTAX,
        /** Gültiges Java, das der eingebaute Interpreter nicht kennt (Lambdas, Threads …). */
        UNSUPPORTED,
        /** Fehler zur Laufzeit, z. B. Division durch 0. */
        RUNTIME,
        /** Das Programm hört nicht auf. */
        STEP_LIMIT,
    }

    /** Bei Laufzeitfehlern: die Java-Exception, z. B. `ArithmeticException` – damit try/catch sie auffangen kann. */
    var exceptionClass: String? = null
    /** Javas eigene Meldung (`getMessage()`), z. B. „/ by zero“. */
    var javaMessage: String? = null
    /** Das geworfene Exception-Objekt (bei `throw` oder eigenen Exceptions). */
    var thrown: JValue? = null

    init {
        if (kind == Kind.RUNTIME) {
            // „ArithmeticException: / by zero – …“: Die Klasse steht vorne.
            val name = message.substringBefore(':', "")
            if ((name.endsWith("Exception") || name.endsWith("Error")) && ' ' !in name) exceptionClass = name
        }
    }

    /** Meldung mit vorangestellter Zeilennummer. */
    val description: String get() = if (line == null) message else "Zeile $line: $message"

    override fun fillInStackTrace(): Throwable = this

    companion object {
        fun syntax(message: String, line: Int?) = JavaProblem(Kind.SYNTAX, message, line)
        fun unsupported(message: String, line: Int?) = JavaProblem(Kind.UNSUPPORTED, message, line)
        fun runtime(message: String, line: Int?) = JavaProblem(Kind.RUNTIME, message, line)

        /** Laufzeitfehler mit Exception-Klasse und Javas Originalmeldung; [explanation] ist der Text für Lernende. */
        fun exception(className: String, javaMessage: String?, explanation: String, line: Int?) =
            JavaProblem(Kind.RUNTIME, "$className: $explanation", line).also {
                it.exceptionClass = className
                it.javaMessage = javaMessage
            }
    }
}

// ---------------------------------------------------------------- Tokens

data class Token(val kind: Kind, val text: String, val line: Int) {
    enum class Kind { IDENTIFIER, KEYWORD, INT, LONG, DOUBLE, STRING, CHAR, SYMBOL, END }

    fun isSym(symbol: String) = (kind == Kind.SYMBOL || kind == Kind.KEYWORD) && text == symbol
}

/** Zerlegt Java-Quelltext in Tokens. Kommentare und Leerraum fallen weg. */
object JavaLexer {
    val keywords = setOf(
        "abstract", "boolean", "break", "byte", "case", "catch", "char", "class", "continue", "default",
        "do", "double", "else", "enum", "extends", "final", "finally", "float", "for", "if", "implements",
        "import", "instanceof", "int", "interface", "long", "new", "null", "package", "private", "protected",
        "public", "return", "short", "static", "super", "switch", "this", "throw", "throws", "true", "false",
        "try", "void", "while", "var", "yield", "record",
    )

    private val symbols = listOf(
        ">>>=", "<<=", ">>=", ">>>", "...", "->", "::", "++", "--", "&&", "||", "==", "!=", "<=", ">=",
        "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<", ">>",
        "(", ")", "{", "}", "[", "]", ";", ",", ".", "=", "<", ">", "!", "~", "?", ":",
        "+", "-", "*", "/", "%", "&", "|", "^", "@",
    )

    fun tokenize(source: String): List<Token> {
        val chars = JavaSource.normalizingTypography(source)
        val tokens = mutableListOf<Token>()
        var i = 0
        var line = 1
        fun peek(offset: Int = 0): Char? = chars.getOrNull(i + offset)

        while (i < chars.length) {
            val c = chars[i]
            if (c == '\n') { line++; i++; continue }
            if (c.isWhitespace()) { i++; continue }

            if (c == '/' && peek(1) == '/') {
                while (i < chars.length && chars[i] != '\n') i++
                continue
            }
            if (c == '/' && peek(1) == '*') {
                val start = line
                i += 2
                while (i < chars.length && !(chars[i] == '*' && peek(1) == '/')) {
                    if (chars[i] == '\n') line++
                    i++
                }
                if (i >= chars.length) throw JavaProblem.syntax("Der Kommentar /* … wird nie mit */ geschlossen.", start)
                i += 2
                continue
            }

            if (c.isDigit() || (c == '.' && peek(1)?.isDigit() == true)) {
                if (c == '0' && (peek(1) == 'x' || peek(1) == 'X')) {
                    i += 2
                    val hex = StringBuilder()
                    while (peek()?.let { it.isLetterOrDigit() || it == '_' } == true && peek()!!.let { it in "0123456789abcdefABCDEF_" }) {
                        if (peek() != '_') hex.append(peek())
                        i++
                    }
                    val isLong = peek() == 'L' || peek() == 'l'
                    if (isLong) i++
                    val value = hex.toString().toULongOrNull(16)?.toLong()
                        ?: throw JavaProblem.syntax("„0x$hex“ ist keine gültige Hexadezimalzahl.", line)
                    tokens += Token(if (isLong) Token.Kind.LONG else Token.Kind.INT, value.toString(), line)
                    continue
                }
                val text = StringBuilder()
                var isDouble = false
                while (true) {
                    val d = peek() ?: break
                    val ok = d.isDigit() || d == '_' || d == '.' || d == 'e' || d == 'E' ||
                        ((d == '+' || d == '-') && (text.lastOrNull() == 'e' || text.lastOrNull() == 'E'))
                    if (!ok) break
                    if (d == '.') {
                        val next = peek(1)
                        if (next != null && next.isLetter()) break
                        if (isDouble) break
                        isDouble = true
                    }
                    if (d == 'e' || d == 'E') isDouble = true
                    if (d != '_') text.append(d)
                    i++
                }
                val suffix = peek()
                if (suffix != null && suffix in "lLdDfF") {
                    i++
                    when (suffix) {
                        'l', 'L' -> tokens += Token(Token.Kind.LONG, text.toString(), line)
                        'f', 'F' -> throw JavaProblem.unsupported("float-Zahlen (mit f am Ende) kennt der eingebaute Interpreter nicht – nimm double.", line)
                        else -> tokens += Token(Token.Kind.DOUBLE, text.toString(), line)
                    }
                    continue
                }
                tokens += Token(if (isDouble) Token.Kind.DOUBLE else Token.Kind.INT, text.toString(), line)
                continue
            }

            if (c.isLetter() || c == '_' || c == '$') {
                val text = StringBuilder()
                while (peek()?.let { it.isLetterOrDigit() || it == '_' || it == '$' } == true) { text.append(peek()); i++ }
                val word = text.toString()
                tokens += Token(if (word in keywords) Token.Kind.KEYWORD else Token.Kind.IDENTIFIER, word, line)
                continue
            }

            if (c == '"') {
                if (peek(1) == '"' && peek(2) == '"') throw JavaProblem.unsupported("Text-Blöcke (\"\"\") kennt der eingebaute Interpreter nicht.", line)
                i++
                val value = StringBuilder()
                while (true) {
                    val d = peek()
                    if (d == null || d == '\n') throw JavaProblem.syntax("Der Text wird nicht mit \" geschlossen.", line)
                    if (d == '"') { i++; break }
                    if (d == '\\') { value.append(escape(chars, i, line).also { i = it.second }.first); continue }
                    value.append(d)
                    i++
                }
                tokens += Token(Token.Kind.STRING, value.toString(), line)
                continue
            }
            if (c == '\'') {
                i++
                val value = StringBuilder()
                if (peek() == '\\') {
                    value.append(escape(chars, i, line).also { i = it.second }.first)
                } else if (peek() != null && peek() != '\'' && peek() != '\n') {
                    value.append(peek())
                    i++
                }
                if (peek() != '\'' || value.length != 1) {
                    throw JavaProblem.syntax("Ein char steht in einfachen Anführungszeichen und enthält genau ein Zeichen, z. B. 'a'.", line)
                }
                i++
                tokens += Token(Token.Kind.CHAR, value.toString(), line)
                continue
            }

            val symbol = symbols.firstOrNull { chars.startsWith(it, i) }
            if (symbol != null) {
                tokens += Token(Token.Kind.SYMBOL, symbol, line)
                i += symbol.length
                continue
            }
            throw JavaProblem.syntax("Das Zeichen „$c“ gehört nicht in Java-Code.", line)
        }
        tokens += Token(Token.Kind.END, "", line)
        return tokens
    }

    /** Liefert (Zeichen, neue Position). */
    private fun escape(chars: String, start: Int, line: Int): Pair<Char, Int> {
        val e = chars.getOrNull(start + 1) ?: throw JavaProblem.syntax("Nach \\ fehlt ein Zeichen.", line)
        var i = start + 2
        val result = when (e) {
            'n' -> '\n'
            't' -> '\t'
            'r' -> '\r'
            'b' -> '\b'
            'f' -> '\u000C'
            '0' -> '\u0000'
            '\\' -> '\\'
            '\'' -> '\''
            '"' -> '"'
            'u' -> {
                val hex = chars.substring(i, minOf(i + 4, chars.length))
                if (hex.length != 4 || hex.toIntOrNull(16) == null) throw JavaProblem.syntax("\\u braucht genau vier Hex-Ziffern, z. B. \\u00e4.", line)
                i += 4
                hex.toInt(16).toChar()
            }
            else -> throw JavaProblem.syntax("„\\$e“ ist keine gültige Escape-Sequenz.", line)
        }
        return result to i
    }
}

// ---------------------------------------------------------------- Syntaxbaum

sealed interface JType {
    data object IntT : JType { override fun toString() = "int" }
    data object LongT : JType { override fun toString() = "long" }
    data object DoubleT : JType { override fun toString() = "double" }
    data object BooleanT : JType { override fun toString() = "boolean" }
    data object CharT : JType { override fun toString() = "char" }
    data object StringT : JType { override fun toString() = "String" }
    data object VoidT : JType { override fun toString() = "void" }
    /** `var` – der Typ ergibt sich aus dem Wert. */
    data object Inferred : JType { override fun toString() = "var" }
    data class Arr(val element: JType) : JType { override fun toString() = "$element[]" }
    /** Ein Klassen-Typ, den der Interpreter nicht kennt. */
    data class Unknown(val name: String) : JType { override fun toString() = name }
    /**
     * Ein Referenztyp, den der Interpreter kennt: eigene Klasse, Interface, Enum, Record oder Bibliotheksklasse
     * (`Hund`, `List<String>`, `Integer` …). Der Text bleibt für die Anzeige erhalten; Generics spielen beim Ausführen keine Rolle.
     */
    data class Obj(val name: String) : JType { override fun toString() = name }

    val baseType: JType get() = if (this is Arr) element.baseType else this

    /** Klassenname ohne Generics: `List<String>` → `List`. */
    val className: String?
        get() = when (this) {
            is Obj -> name.substringBefore('<')
            is Unknown -> name.substringBefore('<')
            StringT -> "String"
            else -> null
        }

    val isPrimitive: Boolean get() = this == IntT || this == LongT || this == DoubleT || this == BooleanT || this == CharT
}

sealed class Expr(val line: Int) {
    class Literal(val value: JValue, line: Int) : Expr(line)
    class Name(val name: String, line: Int) : Expr(line)
    class Unary(val op: String, val operand: Expr, line: Int) : Expr(line)
    class Increment(val op: String, val prefix: Boolean, val target: Expr, line: Int) : Expr(line)
    class Binary(val op: String, val left: Expr, val right: Expr, line: Int) : Expr(line)
    class Logical(val op: String, val left: Expr, val right: Expr, line: Int) : Expr(line)
    class Assign(val op: String, val target: Expr, val value: Expr, line: Int) : Expr(line)
    class Conditional(val condition: Expr, val then: Expr, val otherwise: Expr, line: Int) : Expr(line)
    class Cast(val type: JType, val operand: Expr, line: Int) : Expr(line)
    class Index(val base: Expr, val index: Expr, line: Int) : Expr(line)
    class Field(val base: Expr, val name: String, line: Int) : Expr(line)
    /** Methodenaufruf; `target == null` bei eigenen Methoden wie `istGerade(4)`. */
    class Call(val target: Expr?, val name: String, val args: List<Expr>, line: Int) : Expr(line)
    class NewArray(val element: JType, val sizes: List<Expr>, val extraDimensions: Int, line: Int) : Expr(line)
    class ArrayLiteral(val element: JType?, val items: List<Expr>, line: Int) : Expr(line)
    class SwitchExpr(val subject: Expr, val cases: List<SwitchCase>, line: Int) : Expr(line)
    /** `x instanceof Hund` – mit [binding] (`x instanceof Hund h`) entsteht dabei eine neue Variable. */
    class InstanceOf(val value: Expr, val type: JType, val binding: String?, line: Int) : Expr(line)
    /** Record-Muster: `o instanceof Punkt(int x, int y)` – packt die Felder gleich in neue Variablen aus. */
    class RecordPattern(val value: Expr, val pattern: Pattern, line: Int) : Expr(line)
    /** `new Hund("Bello")`, `new ArrayList<>()`, `new String("…")`. */
    class NewObject(val className: String, val args: List<Expr>, line: Int) : Expr(line)
    /** `this` – das Objekt, dessen Methode gerade läuft. */
    class This(line: Int) : Expr(line)
    /** `super` vor einem Methodenaufruf (`super.laut()`). */
    class SuperRef(line: Int) : Expr(line)
}

/** Muster in instanceof und switch: `int x`, `var y`, `Punkt(int x, int y)` (auch verschachtelt). */
sealed interface Pattern {
    class Binding(val type: JType, val name: String) : Pattern
    class Record(val className: String, val parts: List<Pattern>) : Pattern
}

class SwitchCase(
    val labels: List<Expr>,
    val isDefault: Boolean,
    val isArrow: Boolean,
    val body: List<Stmt>,
    val value: Expr?,
    val line: Int,
    /** Zusatzbedingung bei Typ-Mustern: `case Kreis k when k.radius() > 2 ->`. */
    val guardExpr: Expr? = null,
)

class Declarator(val name: String, val extraDimensions: Int, val initializer: Expr?, val line: Int)

sealed class Stmt(val line: Int) {
    class VarDecl(val type: JType, val declarators: List<Declarator>, val isFinal: Boolean, line: Int) : Stmt(line)
    class ExprStmt(val expr: Expr, line: Int) : Stmt(line)
    class Block(val statements: List<Stmt>, line: Int) : Stmt(line)
    class If(val condition: Expr, val then: Stmt, val otherwise: Stmt?, line: Int) : Stmt(line)
    class While(val condition: Expr, val body: Stmt, line: Int) : Stmt(line)
    class DoWhile(val body: Stmt, val condition: Expr, line: Int) : Stmt(line)
    class For(val init: List<Stmt>, val condition: Expr?, val update: List<Expr>, val body: Stmt, line: Int) : Stmt(line)
    class ForEach(val type: JType, val name: String, val collection: Expr, val body: Stmt, line: Int) : Stmt(line)
    class Break(line: Int) : Stmt(line)
    class Continue(line: Int) : Stmt(line)
    class Return(val value: Expr?, line: Int) : Stmt(line)
    class Yield(val value: Expr, line: Int) : Stmt(line)
    class Switch(val subject: Expr, val cases: List<SwitchCase>, line: Int) : Stmt(line)
    class Throw(val value: Expr, line: Int) : Stmt(line)
    /** `try { … } catch (A | B e) { … } finally { … }` */
    class Try(val body: List<Stmt>, val catches: List<Catch>, val finallyBody: List<Stmt>?, line: Int) : Stmt(line)
    class Empty(line: Int) : Stmt(line)
}

class Parameter(val type: JType, val name: String)

/** Ein catch-Zweig: ein oder mehrere Exception-Typen (`catch (A | B e)`). */
class Catch(val types: List<String>, val name: String, val body: List<Stmt>, val line: Int)

class Method(
    val name: String,
    val returnType: JType,
    val parameters: List<Parameter>,
    val body: List<Stmt>,
    val line: Int,
    var isStatic: Boolean = true,
    /** Ohne Körper (in Interfaces und abstrakten Klassen). */
    var isAbstract: Boolean = false,
    var isPrivate: Boolean = false,
    /** Mit @Override markiert – dann muss es die Methode in einer Oberklasse oder einem Interface geben. */
    var isOverride: Boolean = false,
    /** Klasse, in der die Methode steht (`null` = Hauptklasse bzw. lose Methoden). */
    var owner: String? = null,
)

/** Konstruktor einer eigenen Klasse. */
class Constructor(
    val parameters: List<Parameter>,
    val body: List<Stmt>,
    val isPrivate: Boolean,
    val line: Int,
    /** Kompakter Record-Konstruktor `Punkt { … }`: prüft die Werte, danach landen sie automatisch in den Feldern. */
    val isCompact: Boolean = false,
)

/** Ein Feld einer eigenen Klasse. */
class FieldDecl(val type: JType, val name: String, val initializer: Expr?, val isStatic: Boolean, val isFinal: Boolean, val isPrivate: Boolean, val line: Int)

/** Eine Enum-Konstante, z. B. `ROT("Stehen")`. */
class EnumConstant(val name: String, val args: List<Expr>, val line: Int)

/** Eine eigene Klasse, ein Interface, ein Enum oder ein Record. */
class ClassDecl(val name: String, val kind: Kind, val line: Int) {
    enum class Kind { CLASS, INTERFACE, ENUM, RECORD }

    /** Oberklasse (`extends`); `null` = Object. Für eigene Exceptions z. B. `Exception`. */
    var superclass: String? = null
    val interfaces = mutableListOf<String>()
    var isAbstract = false
    /** Äußere Klasse bei verschachtelten Klassen – für den Namen `Main$Inner` und private Zugriffe. */
    var outer: String? = null
    val fields = mutableListOf<FieldDecl>()
    val constructors = mutableListOf<Constructor>()
    val methods = LinkedHashMap<String, MutableList<Method>>()
    val enumConstants = mutableListOf<EnumConstant>()
    val recordComponents = mutableListOf<Parameter>()

    /** Name, wie ihn Java bei `getName()` und im Standard-`toString()` zeigt. */
    val binaryName: String get() = outer?.let { "$it$$name" } ?: name
    val isInterface: Boolean get() = kind == Kind.INTERFACE
}

/** Ein geparstes Programm: eigene statische Methoden, statische Felder, die Startanweisungen und eigene Klassen. */
class Program {
    val methods = LinkedHashMap<String, MutableList<Method>>()
    val staticFields = mutableListOf<Stmt>()
    var statements = mutableListOf<Stmt>()
    var hasMain = false
    /** Eigene Klassen, Interfaces, Enums und Records (ohne die Hauptklasse mit main). */
    var classes = LinkedHashMap<String, ClassDecl>()
    /** Reihenfolge, in der die Klassen im Quelltext stehen – für die Initialisierung statischer Felder. */
    var classOrder = mutableListOf<String>()
    /** Name der Hauptklasse (mit main), falls es eine gab. */
    var mainClass: String? = null
}
