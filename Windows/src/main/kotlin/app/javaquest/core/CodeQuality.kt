package app.javaquest.core

import app.javaquest.core.interpreter.ClassDecl
import app.javaquest.core.interpreter.FieldDecl
import app.javaquest.core.interpreter.JavaParser
import app.javaquest.core.interpreter.JavaProblem
import app.javaquest.core.interpreter.JavaRunner
import app.javaquest.core.interpreter.Method
import app.javaquest.core.interpreter.Stmt

/** Ein Hinweis zur Code-Qualität – mit Zeile, damit der Editor sie markieren kann. */
data class QualityFinding(val line: Int?, val message: String)

/**
 * Sauberer Code, der Sterne bringt: Java-Namenskonventionen und saubere Einrückung.
 * Beides bewertet nur Programme, die sich lesen lassen – bei Syntaxfehlern gibt es kein Urteil. Wie in der Apple-App.
 */
object CodeQuality {
    // MARK: Namen

    /**
     * Klassen beginnen groß (`Golem`), Methoden und Variablen klein in camelCase (`getEnergie`),
     * Konstanten (`static final`) und Enum-Werte in GROSSBUCHSTABEN (`MAX_ENERGIE`).
     */
    fun naming(source: String): List<QualityFinding> {
        val program = try { JavaParser.parse(JavaSource.normalizingTypography(source)) } catch (e: JavaProblem) { return emptyList() }
        val findings = mutableListOf<QualityFinding>()
        val seen = mutableSetOf<String>()
        val report: (Int?, String) -> Unit = { line, message ->
            // Dieselbe Variable mit falschem Namen nur einmal nennen.
            if (seen.add(message)) findings += QualityFinding(line, message)
        }

        program.mainClass?.let { main ->
            if (!isTypeName(main)) report(lineOfClass(main, source), "Klassennamen beginnen mit einem Großbuchstaben: ${suggestedType(main)} statt $main.")
        }
        for (name in program.classOrder) {
            val decl: ClassDecl = program.classes[name] ?: continue
            if (!isTypeName(decl.name)) report(decl.line, "Klassennamen beginnen mit einem Großbuchstaben: ${suggestedType(decl.name)} statt ${decl.name}.")
            for (field in decl.fields) checkField(field, report)
            for (constant in decl.enumConstants) {
                if (!isConstantName(constant.name)) report(constant.line, "Enum-Werte schreibt man in Großbuchstaben: ${constant.name.uppercase()} statt ${constant.name}.")
            }
            for (component in decl.recordComponents) {
                if (!isVariableName(component.name)) report(decl.line, "Variablen und Felder beginnen klein: ${suggestedVariable(component.name)} statt ${component.name}.")
            }
            for (constructor in decl.constructors) {
                for (parameter in constructor.parameters) checkVariable(parameter.name, constructor.line, report)
                walk(constructor.body, report)
            }
            for (method in decl.methods.values.flatten()) checkMethod(method, report)
        }
        for (method in program.methods.values.flatten()) checkMethod(method, report)
        for (statement in program.staticFields) {
            if (statement is Stmt.VarDecl) {
                for (declarator in statement.declarators) {
                    val ok = if (statement.isFinal) isConstantName(declarator.name) || isVariableName(declarator.name) else isVariableName(declarator.name)
                    if (!ok) {
                        report(
                            declarator.line,
                            if (statement.isFinal) "Konstanten schreibt man in Großbuchstaben mit _: ${suggestedConstant(declarator.name)} statt ${declarator.name}."
                            else "Variablen und Felder beginnen klein: ${suggestedVariable(declarator.name)} statt ${declarator.name}.",
                        )
                    }
                }
            }
        }
        walk(program.statements, report)
        return findings.sortedBy { it.line ?: 0 }
    }

    private fun checkField(field: FieldDecl, report: (Int?, String) -> Unit) {
        if (field.isStatic && field.isFinal) {
            if (!isConstantName(field.name) && !isVariableName(field.name)) {
                report(field.line, "Konstanten schreibt man in Großbuchstaben mit _: ${suggestedConstant(field.name)} statt ${field.name}.")
            }
        } else if (!isVariableName(field.name)) {
            report(field.line, "Variablen und Felder beginnen klein: ${suggestedVariable(field.name)} statt ${field.name}.")
        }
    }

    private fun checkMethod(method: Method, report: (Int?, String) -> Unit) {
        if (!isVariableName(method.name)) {
            report(method.line, "Methodennamen beginnen klein, weitere Wörter groß: ${suggestedVariable(method.name)} statt ${method.name}.")
        }
        for (parameter in method.parameters) checkVariable(parameter.name, method.line, report)
        walk(method.body, report)
    }

    private fun checkVariable(name: String, line: Int, report: (Int?, String) -> Unit) {
        if (!isVariableName(name)) report(line, "Variablen und Parameter beginnen klein, weitere Wörter groß: ${suggestedVariable(name)} statt $name.")
    }

    /** Lokale Variablen in allen Anweisungen – auch in Schleifen, if, switch und try. */
    private fun walk(statements: List<Stmt>, report: (Int?, String) -> Unit) {
        for (statement in statements) walk(statement, report)
    }

    private fun walk(statement: Stmt, report: (Int?, String) -> Unit) {
        when (statement) {
            is Stmt.VarDecl -> for (declarator in statement.declarators) {
                if (!(isVariableName(declarator.name) || (statement.isFinal && isConstantName(declarator.name)))) {
                    report(declarator.line, "Variablen beginnen klein, weitere Wörter groß: ${suggestedVariable(declarator.name)} statt ${declarator.name}.")
                }
            }
            is Stmt.Block -> walk(statement.statements, report)
            is Stmt.If -> {
                walk(statement.then, report)
                statement.otherwise?.let { walk(it, report) }
            }
            is Stmt.While -> walk(statement.body, report)
            is Stmt.DoWhile -> walk(statement.body, report)
            is Stmt.For -> {
                walk(statement.init, report)
                walk(statement.body, report)
            }
            is Stmt.ForEach -> {
                checkVariable(statement.name, statement.line, report)
                walk(statement.body, report)
            }
            is Stmt.Switch -> for (case in statement.cases) walk(case.body, report)
            is Stmt.Try -> {
                walk(statement.body, report)
                for (handler in statement.catches) {
                    checkVariable(handler.name, handler.line, report)
                    walk(handler.body, report)
                }
                statement.finallyBody?.let { walk(it, report) }
            }
            else -> Unit
        }
    }

    fun isTypeName(name: String) = Regex("^[A-Z][A-Za-z0-9]*$").matches(name)
    fun isVariableName(name: String) = Regex("^[a-z][A-Za-z0-9]*$").matches(name)
    fun isConstantName(name: String) = Regex("^[A-Z][A-Z0-9_]*$").matches(name)

    private fun words(name: String): List<String> =
        name.replace(Regex("([a-z0-9])([A-Z])"), "$1_$2").split("_").map { it.lowercase() }.filter { it.isNotEmpty() }

    fun suggestedVariable(name: String): String {
        val parts = words(name)
        val first = parts.firstOrNull() ?: return name
        return first + parts.drop(1).joinToString("") { it.replaceFirstChar(Char::uppercaseChar) }
    }

    fun suggestedType(name: String): String = words(name).joinToString("") { it.replaceFirstChar(Char::uppercaseChar) }

    fun suggestedConstant(name: String): String = words(name).joinToString("_") { it.uppercase() }

    private fun lineOfClass(name: String, source: String): Int? {
        val pattern = Regex("\\bclass\\s+${Regex.escape(name)}\\b")
        val index = source.split("\n").indexOfFirst { pattern.containsMatchIn(it) }
        return if (index >= 0) index + 1 else null
    }

    // MARK: Einrückung

    /**
     * Jede Klammerebene 4 Leerzeichen tiefer, die schließende Klammer zurück auf die Ebene ihrer Zeile.
     * Erlaubt: eine Stufe mehr nach `case …:` und Fortsetzungszeilen, die tiefer stehen als ihre Ebene.
     */
    fun indentation(source: String): List<QualityFinding> {
        if (JavaRunner.check(JavaSource.normalizingTypography(source))?.kind == JavaProblem.Kind.SYNTAX) return emptyList()
        val masked = JavaSource.maskingLiterals(JavaSource.normalizingTypography(source)).split("\n")
        val original = source.split("\n")
        val findings = mutableListOf<QualityFinding>()
        var depth = 0
        var afterCase = false
        var previousCode = ""
        for ((index, maskedLine) in masked.withIndex()) {
            val code = maskedLine.trim { it == ' ' || it == '\t' }
            val opens = maskedLine.count { it == '{' }
            val closes = maskedLine.count { it == '}' }
            if (code.isNotEmpty() && index < original.size) {
                val raw = original[index]
                val indent = raw.takeWhile { it == ' ' || it == '\t' }.sumOf { if (it == '\t') 4 else 1 }
                val level = if (code.startsWith("}")) maxOf(depth - 1, 0) else depth
                val expected = level * 4
                val isCaseLabel = code.startsWith("case ") || code.startsWith("default")
                // Eine Anweisung, die über mehrere Zeilen geht, darf tiefer stehen.
                val isContinuation = previousCode.isNotEmpty() && !(previousCode.endsWith(";") || previousCode.endsWith("{") ||
                    previousCode.endsWith("}") || previousCode.endsWith(":") || previousCode.startsWith("@") || previousCode.endsWith("->"))
                val allowed = when {
                    isContinuation -> indent >= expected
                    afterCase && !isCaseLabel && !code.startsWith("}") -> indent == expected || indent == expected + 4
                    else -> indent == expected
                }
                if (isCaseLabel) afterCase = true else if (code.startsWith("}")) afterCase = false
                if (!allowed) {
                    findings += QualityFinding(index + 1, "Zeile ${index + 1} ist mit $indent statt $expected Leerzeichen eingerückt – je Klammerebene 4 Leerzeichen.")
                }
            }
            depth = maxOf(depth + opens - closes, 0)
            if (code.isNotEmpty()) previousCode = code
        }
        return findings
    }
}
