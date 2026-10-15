package app.javaquest.core

/**
 * Was der Code-Editor beim Tippen selbst erledigt – wie in einer echten IDE: Einrückung nach `{`, schließende `}`
 * zurück auf die Ebene ihrer `{`, Tab als vier Leerzeichen, Tab/Umschalt+Tab auf markierten Zeilen ein- und
 * ausrücken, Auskommentieren, Klammern und Anführungszeichen paarweise.
 * Dieselben Regeln wie in der Apple-App (`CodeEditing.swift`). Positionen sind String-Indizes (UTF-16).
 */
object CodeEditing {
    /**
     * Ersetzt [start] bis [end] (exklusiv) durch [replacement]; danach steht der Cursor bei [cursor],
     * mit [selectionLength] markierten Zeichen dahinter (0 = nur der Cursor).
     */
    data class Edit(val start: Int, val end: Int, val replacement: String, val cursor: Int, val selectionLength: Int = 0) {
        fun applyTo(text: String): String = text.substring(0, start) + replacement + text.substring(end)
    }

    const val INDENT = "    "

    /** Antwort auf eine Eingabe: [input] ersetzt den Bereich [selStart]..[selEnd] in [text]. Null heißt: normal eintippen. */
    fun edit(input: String, text: String, selStart: Int, selEnd: Int = selStart): Edit? {
        if (selStart < 0 || selEnd > text.length || selStart > selEnd) return null
        return when (input) {
            "\n", "\r", "\r\n" -> newline(text, selStart, selEnd)
            "\t" -> {
                // Mit Auswahl rückt Tab die Zeilen ein, statt sie durch Leerzeichen zu ersetzen.
                if (selStart != selEnd) return shiftLines(text, selStart, selEnd, outdent = false)
                val column = selStart - lineStart(text, selStart)
                val spaces = " ".repeat(4 - column % 4)
                Edit(selStart, selEnd, spaces, selStart + spaces.length)
            }
            "}" -> closingBrace(text, selStart, selEnd)
            "(", "[" -> {
                // Nur vor Leerraum, Zeilenende oder schließenden Zeichen – mitten in einem Wort störte es.
                if (selStart != selEnd || !isBoundary(text, selStart) || isInsideLiteral(text, selStart)) return null
                Edit(selStart, selEnd, if (input == "(") "()" else "[]", selStart + 1)
            }
            ")", "]" -> {
                // Über die schon vorhandene schließende Klammer hinwegtippen.
                if (selStart == selEnd && selStart < text.length && text[selStart].toString() == input) Edit(selStart, selStart, "", selStart + 1) else null
            }
            "\"" -> {
                if (selStart != selEnd) return null
                if (selStart < text.length && text[selStart] == '"' && isInsideLiteral(text, selStart)) return Edit(selStart, selStart, "", selStart + 1)
                if (!isBoundary(text, selStart) || isInsideLiteral(text, selStart)) return null
                Edit(selStart, selEnd, "\"\"", selStart + 1)
            }
            else -> null
        }
    }

    /**
     * Rückt die Zeilen ein bzw. aus, die die Auswahl berührt (Tab/Umschalt+Tab) – um vier Leerzeichen. Leere Zeilen
     * bleiben leer. Mit Auswahl sind danach die ganzen Zeilen markiert, sodass man weiter schieben kann; ohne bleibt
     * der Cursor an seiner Stelle im Code. Null: Es gibt nichts zu tun.
     */
    fun shiftLines(text: String, selStart: Int, selEnd: Int = selStart, outdent: Boolean): Edit? {
        if (selStart < 0 || selEnd > text.length || selStart > selEnd) return null
        val (start, end) = touchedLines(text, selStart, selEnd)
        val lines = text.substring(start, end).split("\n")
        val shifted = lines.map { line ->
            when {
                outdent -> line.drop(if (line.startsWith("\t")) 1 else minOf(line.takeWhile { it == ' ' }.length, INDENT.length))
                line.isBlank() -> line
                else -> INDENT + line
            }
        }
        return lineEdit(start, end, selStart, selEnd, lines, shifted) { 0 }
    }

    /**
     * Stehen vor allen markierten Codezeilen schon `//`, fallen sie weg – sonst kommt `// ` davor, und zwar auf die
     * Spalte der am wenigsten eingerückten Zeile (die Einrückung bleibt sauber).
     */
    fun toggleComment(text: String, selStart: Int, selEnd: Int = selStart): Edit? {
        if (selStart < 0 || selEnd > text.length || selStart > selEnd) return null
        val (start, end) = touchedLines(text, selStart, selEnd)
        val lines = text.substring(start, end).split("\n")
        val code = lines.filter { it.isNotBlank() }
        if (code.isEmpty()) return null
        val uncomment = code.all { it.trimStart(' ', '\t').startsWith("//") }
        val column = code.minOf { indentation(it).length }
        val changed = lines.map { line ->
            when {
                line.isBlank() -> line
                uncomment -> {
                    val indent = indentation(line)
                    indent + line.substring(indent.length + 2).removePrefix(" ")
                }
                else -> line.substring(0, column) + "// " + line.substring(column)
            }
        }
        return lineEdit(start, end, selStart, selEnd, lines, changed) { line -> if (uncomment) indentation(line).length else column }
    }

    /** Die ganzen Zeilen der Auswahl, ohne letzten Zeilenumbruch; endet sie am Anfang einer Zeile, zählt diese nicht mit. */
    private fun touchedLines(text: String, selStart: Int, selEnd: Int): Pair<Int, Int> {
        val start = lineStart(text, selStart)
        val last = if (selEnd > selStart && text[selEnd - 1] == '\n') selEnd - 1 else selEnd
        val end = text.indexOf('\n', last).let { if (it < 0) text.length else it }
        return start to maxOf(end, start)
    }

    /** Ersetzt die Zeilen; ohne Auswahl wandert der Cursor mit seinem Code ([at]: Spalte der Änderung in Zeile 1). */
    private fun lineEdit(start: Int, end: Int, selStart: Int, selEnd: Int, lines: List<String>, changed: List<String>, at: (String) -> Int): Edit? {
        val replacement = changed.joinToString("\n")
        if (replacement == lines.joinToString("\n")) return null
        if (selStart != selEnd) return Edit(start, end, replacement, start, replacement.length)
        val column = selStart - start
        val first = at(lines[0])
        val delta = changed[0].length - lines[0].length
        // Vor der Änderungsstelle bleibt der Cursor stehen; genau auf ihr wandert er mit Eingefügtem mit.
        val moved = if (column < first || (column == first && delta < 0)) column else maxOf(first, column + delta)
        return Edit(start, end, replacement, start + minOf(moved, changed[0].length))
    }

    /**
     * Fügt ein Stück Code (Bauplan, Symbolleiste) an der Cursorstelle ein. Mehrzeiliges rückt auf die Ebene der
     * aktuellen Zeile ein und beginnt in einer neuen Zeile, wenn davor schon Code steht.
     */
    fun insertion(snippet: String, text: String, selStart: Int, selEnd: Int = selStart): Edit {
        val start = selStart.coerceIn(0, text.length)
        val end = selEnd.coerceIn(start, text.length)
        if ('\n' !in snippet) return Edit(start, end, snippet, start + snippet.length)
        val before = text.substring(lineStart(text, start), start)
        val indent = indentation(before)
        var body = snippet.split("\n").mapIndexed { index, line -> if (index == 0 || line.isEmpty()) line else indent + line }.joinToString("\n")
        if (before.isNotBlank()) body = "\n" + indent + body
        return Edit(start, end, body, start + body.length)
    }

    /** Die Einrückung einer Zeile – Leerzeichen (und Tabs) am Zeilenanfang. */
    fun indentation(line: String): String = line.takeWhile { it == ' ' || it == '\t' }

    // MARK: Eingaben

    private fun newline(text: String, selStart: Int, selEnd: Int): Edit {
        val start = lineStart(text, selStart)
        val line = text.substring(start, selStart)
        val indent = indentation(line)
        val before = line.trim { it == ' ' || it == '\t' }
        val after = text.substring(selEnd, lineEnd(text, selEnd)).trim { it == ' ' || it == '\t' }
        if (!before.endsWith("{")) {
            // Nach `case …:` eine Stufe tiefer, sonst wie die Zeile davor.
            val extra = if (before.endsWith(":") && (before.startsWith("case ") || before.startsWith("default"))) INDENT else ""
            val inserted = "\n" + indent + extra
            return Edit(selStart, selEnd, inserted, selStart + inserted.length)
        }
        val inner = indent + INDENT
        if (after.startsWith("}")) {
            // `{|}` → Klammer auf eigene Zeile, Cursor dazwischen.
            var trailingEnd = selEnd
            while (trailingEnd < text.length && (text[trailingEnd] == ' ' || text[trailingEnd] == '\t')) trailingEnd++
            val inserted = "\n" + inner + "\n" + indent
            return Edit(selStart, trailingEnd, inserted, selStart + 1 + inner.length)
        }
        if (after.isEmpty() && needsClosingBrace(text)) {
            val inserted = "\n" + inner + "\n" + indent + "}"
            return Edit(selStart, selEnd, inserted, selStart + 1 + inner.length)
        }
        val inserted = "\n" + inner
        return Edit(selStart, selEnd, inserted, selStart + inserted.length)
    }

    private fun closingBrace(text: String, selStart: Int, selEnd: Int): Edit? {
        val start = lineStart(text, selStart)
        val line = text.substring(start, selStart)
        // Nur, wenn vor der Klammer in dieser Zeile nichts steht.
        if (!line.all { it == ' ' || it == '\t' }) return null
        // Steht die passende } schon da (der Editor hat sie nach Enter gesetzt), springt der Cursor
        // hinter sie – statt eine zweite Klammer zu schreiben, die zu viel wäre.
        val code = codeChars(text)
        if (selStart == selEnd && code.count { it == '}' } >= code.count { it == '{' }) {
            var next = selEnd
            while (next < text.length && text[next] in " \t\n\r") next++
            if (next < text.length && code[next] == '}') {
                val braceLine = lineStart(text, next)
                val removed = braceLine - start
                return Edit(start, braceLine, "", next + 1 - removed)
            }
        }
        val target = matchingIndent(text, start)
        if (target == line) return null
        val inserted = "$target}"
        return Edit(start, selEnd, inserted, start + inserted.length)
    }

    // MARK: Hilfen

    internal fun lineStart(text: String, at: Int): Int = text.lastIndexOf('\n', (at - 1).coerceAtLeast(-1)).let { if (at == 0) 0 else it + 1 }

    internal fun lineEnd(text: String, at: Int): Int = text.indexOf('\n', at).let { if (it < 0) text.length else it }.let {
        if (it > at && text[it - 1] == '\r') it - 1 else it
    }

    private fun isBoundary(text: String, at: Int): Boolean {
        if (at >= text.length) return true
        val next = text[at]
        return next.isWhitespace() || next in ")];,"
    }

    /** Steht die Stelle in einem String- oder Char-Literal? (Nur die aktuelle Zeile zählt – Literale enden am Zeilenende.) */
    private fun isInsideLiteral(text: String, at: Int): Boolean {
        val line = text.substring(lineStart(text, at), at)
        var quote: Char? = null
        var i = 0
        while (i < line.length) {
            val c = line[i]
            if (quote != null) {
                if (c == '\\') i++ else if (c == quote) quote = null
            } else if (c == '"' || c == '\'') {
                quote = c
            } else if (c == '/' && i + 1 < line.length && line[i + 1] == '/') {
                return false
            }
            i++
        }
        return quote != null
    }

    /** Fehlt zu einer `{` noch eine `}`? Gezählt wird ohne Kommentare und Literale. */
    private fun needsClosingBrace(text: String): Boolean {
        val code = codeChars(text)
        return code.count { it == '{' } > code.count { it == '}' }
    }

    /** Der Text, Kommentare und Literale durch Leerzeichen ersetzt – gleich lang wie das Original. */
    internal fun codeChars(text: String): CharArray {
        val chars = text.toCharArray()
        var state = 0 // 0 Code, 1 Zeilenkommentar, 2 Blockkommentar, 3 Literal
        var quote = ' '
        var i = 0
        while (i < chars.size) {
            val c = chars[i]
            val next = if (i + 1 < chars.size) chars[i + 1] else null
            when (state) {
                0 -> when {
                    c == '/' && next == '/' -> { state = 1; chars[i] = ' ' }
                    c == '/' && next == '*' -> { state = 2; chars[i] = ' '; chars[i + 1] = ' '; i++ }
                    c == '"' || c == '\'' -> { state = 3; quote = c }
                }
                1 -> if (c == '\n') state = 0 else chars[i] = ' '
                2 -> if (c == '*' && next == '/') { chars[i] = ' '; chars[i + 1] = ' '; i++; state = 0 } else if (c != '\n') chars[i] = ' '
                3 -> when {
                    c == '\\' && next != null && next != '\n' -> { chars[i] = ' '; chars[i + 1] = ' '; i++ }
                    c == quote || c == '\n' -> state = 0
                    else -> chars[i] = ' '
                }
            }
            i++
        }
        return chars
    }

    /** Die Einrückung der Zeile mit der passenden `{` – dort hin gehört die `}`. */
    private fun matchingIndent(text: String, before: Int): String {
        val code = codeChars(text.substring(0, before))
        var depth = 0
        for (i in code.indices.reversed()) {
            if (code[i] == '}') depth++
            if (code[i] == '{') {
                if (depth == 0) {
                    val start = lineStart(text, i)
                    return indentation(text.substring(start, i))
                }
                depth--
            }
        }
        return ""
    }
}
