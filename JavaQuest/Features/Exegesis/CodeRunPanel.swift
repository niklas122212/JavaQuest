import SwiftUI
import JavaQuestKit

/// „Ausführen und zusehen“: Das Beispiel läuft wirklich – Zeile für Zeile, mit Erklärung,
/// Variablen und Konsole. Wie ein Debugger, nur zum Zuschauen.
/// Der Knopf erscheint nur, wenn der eingebaute Interpreter das Programm versteht.
struct CodeRunPanel: View {
    let source: String
    let lines: [ExplainedLine]

    @State private var trace: JavaTrace?
    @State private var isOpen = Self.debugOpen
    @State private var index = Self.debugStep
    @State private var isPlaying = false
    @State private var width: CGFloat = 400

    var body: some View {
        // Ein fester Rahmen statt Group: Eine leere Group bekäme kein .task – die Aufzeichnung startete nie.
        VStack(alignment: .leading, spacing: 0) {
            if let trace, trace.isUseful {
                if isOpen {
                    panel(trace)
                } else {
                    Button {
                        index = 0
                        withAnimation(.smooth) { isOpen = true }
                    } label: {
                        Label("Ausführen und zusehen", systemImage: "play.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.teal)
                    .accessibilityHint(Text("Das Programm läuft Schritt für Schritt – mit Variablen und Ausgabe."))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: source) {
            let source = source
            trace = await Task.detached(priority: .utility) { JavaRunner.trace(source) }.value
        }
        .task(id: isPlaying) {
            // Abspielen: alle 0,8 Sekunden ein Schritt – bis zum Ende.
            while isPlaying, let trace, index < trace.steps.count - 1 {
                try? await Task.sleep(for: .milliseconds(800))
                guard isPlaying, !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { index += 1 }
            }
            isPlaying = false
        }
    }

    #if DEBUG
    /// Für Simulator-Screenshots: `-openRunPanel` öffnet das Zusehen, `-runPanelStep N` springt zu Schritt N.
    private static var debugOpen: Bool { ProcessInfo.processInfo.arguments.contains("-openRunPanel") }
    private static var debugStep: Int { max(UserDefaults.standard.integer(forKey: "runPanelStep") - 1, 0) }
    #else
    private static let debugOpen = false
    private static let debugStep = 0
    #endif

    private func panel(_ trace: JavaTrace) -> some View {
        let step = trace.steps[min(index, trace.steps.count - 1)]
        let isLast = index >= trace.steps.count - 1
        let failed = isLast && trace.problem != nil
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("So läuft das Programm", systemImage: "play.rectangle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.teal)
                Spacer()
                Button {
                    isPlaying = false
                    withAnimation(.smooth) { isOpen = false }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Zusehen beenden"))
            }

            TraceCodeView(code: source, currentLine: failed ? nil : step.line, errorLine: failed ? step.line : nil, minHeight: 0)

            explanation(step, isLast: isLast, trace: trace)

            if width >= 520 {
                HStack(alignment: .top, spacing: 12) {
                    console(step).frame(maxWidth: .infinity)
                    variables(step).frame(maxWidth: 260)
                }
            } else {
                console(step)
                variables(step)
            }

            controls(trace)
        }
        .padding(14)
        .background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// Was in der markierten Zeile gleich passiert – aus der Zeilen-Erklärung.
    @ViewBuilder
    private func explanation(_ step: JavaTraceStep, isLast: Bool, trace: JavaTrace) -> some View {
        let text: String = {
            if isLast, let problem = trace.problem { return "Hier bleibt das Programm stehen: \(problem.message)" }
            if isLast { return trace.isTruncated ? "Hier endet die Aufzeichnung – das Programm liefe noch weiter." : "Das Programm ist fertig." }
            guard let line = step.line else { return "" }
            let explained = lines.first { $0.number == line }?.explanation ?? ""
            return "Als Nächstes Zeile \(line): \(explained)"
        }()
        VStack(alignment: .leading, spacing: 6) {
            if let method = step.method, !isLast {
                Label("in der Methode \(method)()", systemImage: "arrow.turn.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.violet)
            }
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func console(_ step: JavaTraceStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Konsole", systemImage: "terminal.fill").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(step.output.isEmpty ? "(noch keine Ausgabe)" : step.output.trimmingCharacters(in: .newlines))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(step.output.isEmpty ? CodeTheme.plain.opacity(0.4) : CodeTheme.plain)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                .padding(10)
                .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func variables(_ step: JavaTraceStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Variablen", systemImage: "shippingbox.fill").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                if step.variables.isEmpty {
                    Text("keine").foregroundStyle(.secondary)
                }
                ForEach(step.variables, id: \.name) { variable in
                    HStack(spacing: 4) {
                        Text(variable.type).foregroundStyle(.secondary)
                        Text(variable.name).fontWeight(.semibold)
                        Text("=").foregroundStyle(.secondary)
                        Text(variable.value).foregroundStyle(Theme.indigo)
                    }
                    .lineLimit(1)
                }
            }
            .font(.system(.footnote, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Theme.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.smooth, value: step.variables)
        }
    }

    private func controls(_ trace: JavaTrace) -> some View {
        let last = trace.steps.count - 1
        return HStack(spacing: 6) {
            control("backward.end.fill", "Zum Anfang", disabled: index == 0) { isPlaying = false; index = 0 }
            control("backward.frame.fill", "Ein Schritt zurück", disabled: index == 0) { isPlaying = false; index -= 1 }
            control(isPlaying ? "pause.fill" : "play.fill", isPlaying ? "Pause" : "Abspielen", disabled: index >= last, prominent: true) {
                isPlaying.toggle()
            }
            control("forward.frame.fill", "Ein Schritt weiter", disabled: index >= last) { isPlaying = false; index += 1 }
            control("forward.end.fill", "Zum Ende", disabled: index >= last) { isPlaying = false; index = last }
            Spacer(minLength: 4)
            Text("Schritt \(index + 1) von \(trace.steps.count)\(trace.isTruncated ? "+" : "")")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func control(_ symbol: String, _ label: LocalizedStringKey, disabled: Bool, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .frame(width: prominent ? 44 : 36, height: 36)
                .foregroundStyle(prominent ? .white : Theme.teal)
                .background(prominent ? AnyShapeStyle(Theme.teal) : AnyShapeStyle(Theme.teal.opacity(0.14)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(Text(label))
    }
}
