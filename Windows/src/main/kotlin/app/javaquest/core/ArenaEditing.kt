package app.javaquest.core

/**
 * Tempo der Wiedergabe: Wie lange jedes Standbild stehen bleibt (wie ArenaPlayback.swift).
 *
 * Fragen an Byte („Ist vorne frei?“) bewegen ihn nicht und ziehen deshalb schneller vorbei als
 * Fahrten. Und eine lange Fahrt – im Labyrinth über 200 Bilder – wird schneller abgespielt, damit
 * niemand anderthalb Minuten zuschauen muss: Beim gewählten Tempo dauert keine Wiedergabe länger
 * als [MAX_STEPS] normale Schritte.
 */
object ArenaPlayback {
    /** Anteil einer normalen Schrittdauer, den eine Frage bekommt. */
    const val QUESTION_WEIGHT = 0.4
    /** So viele normale Schritte lang darf eine Wiedergabe höchstens dauern. */
    const val MAX_STEPS = 50.0
    /** Kürzer wird kein Bild – sonst sieht man die Bewegung nicht mehr. */
    const val MINIMUM_DELAY = 0.05

    /**
     * Wartezeit in Sekunden, bevor Bild `i` erscheint (`[0]` ist das Startbild und immer 0).
     * [base] ist die Dauer eines normalen Schritts beim gewählten Tempo.
     */
    fun delays(frames: List<ArenaFrame>, base: Double): List<Double> {
        if (frames.isEmpty()) return emptyList()
        val weights = frames.mapIndexed { index, frame -> if (index == 0) 0.0 else weight(frame.action) }
        val total = weights.sum()
        val scale = if (total > MAX_STEPS) MAX_STEPS / total else 1.0
        return weights.mapIndexed { index, weight -> if (index == 0) 0.0 else maxOf(base * weight * scale, MINIMUM_DELAY) }
    }

    private fun weight(action: ArenaAction) = if (action is ArenaAction.Look) QUESTION_WEIGHT else 1.0
}

/**
 * Fügt einen Befehl oder eine Vorlage aus der Befehlsleiste in den Code ein – als eigene Zeile,
 * richtig eingerückt und an der Stelle, an der man gerade schreibt (wie CodeInsertion.swift).
 */
object CodeInsertion {
    /**
     * @param cursor Position im Code (UTF-16, wie Kotlin-Strings zählen), an der man gerade schreibt –
     *   oder null, wenn sie unbekannt ist. Steht sie am Anfang einer Zeile, kommt der Befehl davor, sonst
     *   dahinter. Ohne Position kommt er in den ersten leeren Block mit Platzhalter-Kommentar
     *   (`// Was soll in jeder Runde passieren?` direkt vor `}`), sonst ans Ende.
     * @return der neue Code und die Position direkt hinter dem Eingefügten – dort geht es beim nächsten Klick weiter.
     */
    fun insert(snippet: String, code: String, cursor: Int?): Pair<String, Int> {
        if (code.isBlank()) return snippet to snippet.length
        val lines = code.split("\n").toMutableList()

        val (index, before) = if (cursor != null) position(cursor, lines) else (placeholderLine(lines) ?: lastCodeLine(lines)) to false
        val line = lines[index]
        val isBlank = line.isBlank()
        var indent = line.takeWhile { it == ' ' || it == '\t' }
        if (!before && !isBlank && opensBlock(line)) indent += "    "
        val block = snippet.split("\n").map { if (it.isEmpty()) it else indent + it }

        val insertAt: Int
        if (isBlank) {
            // Eine leere Zeile wird zur Befehlszeile.
            lines.removeAt(index)
            lines.addAll(index, block)
            insertAt = index
        } else {
            insertAt = if (before) index else index + 1
            lines.addAll(insertAt, block)
        }
        val lastInserted = insertAt + block.size - 1
        val newCursor = lines.take(lastInserted + 1).sumOf { it.length } + lastInserted
        return lines.joinToString("\n") to newCursor
    }

    /** Zeile, in der der Cursor steht – und ob er vor ihrem ersten Zeichen steht. */
    private fun position(cursor: Int, lines: List<String>): Pair<Int, Boolean> {
        var offset = 0
        lines.forEachIndexed { index, line ->
            if (cursor <= offset + line.length) {
                val column = cursor - offset
                val leading = line.takeWhile { it == ' ' || it == '\t' }.length
                return index to (line.isNotBlank() && column <= leading)
            }
            offset += line.length + 1
        }
        return lines.lastIndex to false
    }

    /** Ein Kommentar direkt vor einer schließenden Klammer: der Platzhalter eines leeren Blocks. */
    private fun placeholderLine(lines: List<String>): Int? = (0 until lines.lastIndex).firstOrNull { index ->
        lines[index].trim().startsWith("//") && lines[index + 1].trim().startsWith("}")
    }

    /** Die letzte Zeile mit Inhalt – Leerzeilen am Ende bleiben dahinter. */
    private fun lastCodeLine(lines: List<String>): Int = lines.indexOfLast { it.isNotBlank() }.let { if (it < 0) lines.lastIndex else it }

    private fun opensBlock(line: String): Boolean = line.substringBefore("//").trim().endsWith("{")
}
