import SwiftUI
import JavaQuestKit

/// Rückmeldung der automatischen Auswertung: Urteil, Teilpunkte, einzelne Befunde,
/// Tipp nach Fehlversuch und Erklärung, sobald die Aufgabe erledigt ist.
struct FeedbackPanel: View {
    let result: EvaluationResult?
    let isRevealed: Bool
    let attempts: Int
    let remainingAttempts: Int
    let hint: String?
    /// Der konkretere zweite Tipp – erscheint erst ab dem zweiten Fehlversuch.
    var secondHint: String?
    let explanation: String
    /// In Übung und Training zählt die Antwort für die Wissensanalyse, nicht für den Score.
    var countsForScore = true
    /// Die gewählte falsche Antwort und – falls hinterlegt – warum sie nicht stimmt.
    var wrongChoice: (label: String, reason: String?)?
    /// Was richtig gewesen wäre. Erscheint erst, wenn die Aufgabe abgeschlossen ist.
    var correctAnswer: String?

    private var isCorrect: Bool { result?.isCorrect == true }

    private var tint: Color {
        if isCorrect { return Theme.success }
        if isRevealed { return Theme.indigo }
        return Theme.orange
    }

    private var headline: String {
        // Wer nach einem Fehlversuch und dem Tipp selbst draufkommt, hat mehr geleistet
        // als wer es gleich wusste. Das soll auch so klingen.
        if isCorrect {
            if attempts == 1 { return "Richtig – volle Punktzahl!" }
            if attempts == 2 { return "Stark – nach dem Tipp selbst draufgekommen!" }
            return "Geschafft – im \(attempts). Anlauf, ohne die Lösung aufzudecken."
        }
        if isRevealed { return "Lösung aufgedeckt" }
        return "Noch nicht ganz"
    }

    private var subline: String {
        if isCorrect {
            let target = countsForScore ? "deinen Score" : "deine Wissensanalyse"
            return attempts == 1 ? "Das zählt voll für \(target)." : "Das zählt zur Hälfte für \(target)."
        }
        if isRevealed { return "Schau dir die Lösung in Ruhe an – beim nächsten Mal klappt’s." }
        if remainingAttempts == 0 { return "Keine Versuche mehr – unten steht, woran es lag." }
        return "Du hast noch \(remainingAttempts) \(remainingAttempts == 1 ? "Versuch" : "Versuche")."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : (isRevealed ? "lightbulb.fill" : "exclamationmark.circle.fill"))
                    .font(.title)
                    .foregroundStyle(tint)
                    .symbolEffect(.bounce, value: isCorrect)
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline).font(.headline)
                    Text(subline).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let result, !isCorrect, !isRevealed {
                    VStack(spacing: 0) {
                        Text("\(result.percent) %").font(.headline.monospacedDigit())
                        Text("erfüllt").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

                if let wrongChoice, !isCorrect {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("Deine Antwort: \(wrongChoice.label)")
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.ember)
                    }
                    if let reason = wrongChoice.reason {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.ember.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let correctAnswer, !isCorrect {
                Label {
                    Text("Richtig wäre: \(correctAnswer)")
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

        // Nach dem Aufdecken steht die Lösung im Eingabefeld – alte Befunde würden nur verwirren.
            if !isRevealed, let findings = result?.findings, !findings.isEmpty, !isCorrect || findings.count > 1 {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(findings.enumerated()), id: \.offset) { _, finding in
                        FindingRow(finding: finding)
                    }
                }
            }

            if !isCorrect, !isRevealed, let hint {
                Label {
                    Text(hint).font(.subheadline)
                } icon: {
                    Image(systemName: "lightbulb").foregroundStyle(Theme.orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !isCorrect, !isRevealed, let secondHint {
                Label {
                    Text(secondHint).font(.subheadline)
                } icon: {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Theme.orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if isCorrect || isRevealed {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Erklärung").font(.caption.weight(.bold)).foregroundStyle(tint)
                    Text(explanation).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.3))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FindingRow: View {
    let finding: Finding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .font(.subheadline)
            Text(finding.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var symbol: String {
        switch finding.kind {
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .hint: "lightbulb.fill"
        }
    }

    private var tint: Color {
        switch finding.kind {
        case .passed: Theme.success
        case .failed: Theme.ember
        case .hint: Theme.orange
        }
    }
}

/// Aktionen unten: Prüfen → (Erneut prüfen | Lösung zeigen) → Weiter.
struct TaskActionBar: View {
    @Bindable var model: LessonFlowModel

    var body: some View {
        HStack(spacing: 12) {
            if model.session.isCurrentTaskFinished {
                Button(action: { dismissKeyboard(); withAnimation(.smooth) { model.next() } }) {
                    Label(isLastTask ? "Zur Auswertung" : "Weiter", systemImage: isLastTask ? "chart.bar.doc.horizontal" : "arrow.right")
                }
                .buttonStyle(PrimaryButtonStyle(fill: Theme.successGradient))
                .keyboardShortcut(.return, modifiers: .command)
            } else {
                if model.session.lastResult != nil {
                    Button("Lösung zeigen", systemImage: "eye") { dismissKeyboard(); withAnimation(.smooth) { model.revealSolution() } }
                        .buttonStyle(.secondary)
                }
                if model.session.lastResult == nil || model.session.canRetry {
                    Button(action: { dismissKeyboard(); withAnimation(.smooth) { model.submit() } }) {
                        Label(model.session.lastResult == nil ? "Prüfen" : "Erneut prüfen", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.primary)
                    .disabled(!model.canSubmit)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var isLastTask: Bool {
        guard let position = model.taskPosition else { return false }
        return position.index == position.count
    }
}

/// Schließt die Tastatur, damit die Rückmeldung nach dem Prüfen sichtbar ist.
@MainActor
func dismissKeyboard() {
    #if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}
