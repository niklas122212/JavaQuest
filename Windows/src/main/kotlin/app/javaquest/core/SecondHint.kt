package app.javaquest.core

/**
 * Der zweite Tipp: konkreter als der erste, aber immer noch nicht die Lösung.
 *
 * Er wird nicht geschrieben, sondern aus der Aufgabe abgeleitet. Das hat zwei Gründe.
 * Erstens ist er dadurch für jede Aufgabe da und kann nicht vergessen werden. Zweitens
 * richtet er sich nach dem, was tatsächlich schon versucht wurde: Bei einer Auswahlaufgabe
 * streicht er zwei Antworten, die noch nicht dran waren – ein fest geschriebener Satz
 * könnte das nicht. Die Lösung nennt er in keinem Fall.
 *
 * Dieselben Formulierungen wie in der Apple- und der Web-Fassung.
 */
object SecondHint {
    /**
     * @param chosen die zuletzt gewählte Antwort, damit sie nicht noch einmal als
     *   „scheidet aus“ auftaucht. Nur bei Auswahlaufgaben von Bedeutung.
     */
    fun text(task: LearningTask, chosen: Int? = null): String? = when (val kind = task.kind) {
        is TaskKind.SingleChoice -> {
            // Zwei falsche Antworten streichen, die noch nicht dran waren – aus vier mach zwei.
            val streichbar = kind.choices.indices.mapNotNull { index ->
                val grund = kind.whyWrong(index)
                if (index != kind.correctIndex && index != chosen && !grund.isNullOrBlank()) {
                    kind.choices[index] to grund
                } else {
                    null
                }
            }
            when {
                streichbar.size >= 2 ->
                    "Streich schon mal zwei: „${streichbar[0].first}“ und „${streichbar[1].first}“ " +
                        "scheiden aus. ${streichbar[0].second}"
                streichbar.size == 1 -> "Auch „${streichbar[0].first}“ scheidet aus. ${streichbar[0].second}"
                else -> null
            }
        }

        is TaskKind.PredictOutput -> {
            val zeilen = AnswerEvaluator.outputLines(kind.expectedOutput)
            if (zeilen.size == 1) {
                "Die Ausgabe besteht aus genau einer Zeile."
            } else {
                "Die Ausgabe besteht aus genau ${zeilen.size} Zeilen. " +
                    "Geh den Code Anweisung für Anweisung durch und zähl mit."
            }
        }

        is TaskKind.FillBlank -> kind.blanks
            .mapIndexed { index, blank ->
                val wort = blank.accepted.firstOrNull() ?: ""
                "Lücke ${index + 1}: ${wort.length} Zeichen, beginnt mit „${wort.take(1)}“"
            }
            .ifEmpty { null }
            ?.joinToString(" · ")

        is TaskKind.Code -> {
            val zeilen = kind.solution.source.split("\n").count { it.isNotBlank() }
            if (zeilen > 0) "Die Musterlösung kommt mit $zeilen Zeilen aus – mehr brauchst du nicht." else null
        }
    }
}
