import Foundation

/// Der zweite Tipp: konkreter als der erste, aber immer noch nicht die Lösung.
///
/// Er wird nicht geschrieben, sondern aus der Aufgabe abgeleitet. Das hat zwei Gründe.
/// Erstens ist er dadurch für jede Aufgabe da und kann nicht vergessen werden. Zweitens
/// richtet er sich nach dem, was tatsächlich schon versucht wurde: Bei einer Auswahlaufgabe
/// streicht er zwei Antworten, die noch nicht dran waren – ein fest geschriebener Satz
/// könnte das nicht. Die Lösung nennt er in keinem Fall.
public enum SecondHint {
    /// - Parameter chosen: die zuletzt gewählte Antwort, damit sie nicht noch einmal
    ///   als „scheidet aus“ auftaucht. Nur bei Auswahlaufgaben von Bedeutung.
    public static func text(for task: LearningTask, chosen: Int? = nil) -> String? {
        switch task.kind {
        case .singleChoice(let spec):
            // Zwei falsche Antworten streichen, die noch nicht dran waren – aus vier mach zwei.
            let streichbar = spec.choices.indices.compactMap { index -> (text: String, grund: String)? in
                guard index != spec.correctIndex, index != chosen,
                      let grund = spec.whyWrong(index), !grund.isEmpty else { return nil }
                return (spec.choices[index], grund)
            }
            if streichbar.count >= 2 {
                return "Streich schon mal zwei: „\(streichbar[0].text)“ und „\(streichbar[1].text)“ "
                     + "scheiden aus. \(streichbar[0].grund)"
            }
            if let einer = streichbar.first {
                return "Auch „\(einer.text)“ scheidet aus. \(einer.grund)"
            }
            return nil

        case .predictOutput(let spec):
            let zeilen = AnswerEvaluator.outputLines(spec.expectedOutput)
            return zeilen.count == 1
                ? "Die Ausgabe besteht aus genau einer Zeile."
                : "Die Ausgabe besteht aus genau \(zeilen.count) Zeilen. "
                + "Geh den Code Anweisung für Anweisung durch und zähl mit."

        case .fillBlank(let spec):
            let teile = spec.blanks.enumerated().map { index, blank -> String in
                let wort = blank.accepted.first ?? ""
                return "Lücke \(index + 1): \(wort.count) Zeichen, beginnt mit „\(wort.prefix(1))“"
            }
            return teile.isEmpty ? nil : teile.joined(separator: " · ")

        case .code(let spec):
            let zeilen = spec.sampleSolution
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count
            return zeilen > 0 ? "Die Musterlösung kommt mit \(zeilen) Zeilen aus – mehr brauchst du nicht." : nil
        }
    }
}
