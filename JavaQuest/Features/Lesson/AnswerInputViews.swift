import SwiftUI
import JavaQuestKit

struct ChoiceListView: View {
    let choices: [String]
    @Binding var selection: Int?
    /// Wird gesetzt, sobald die Lösung feststeht (richtig beantwortet oder aufgedeckt).
    let correctIndex: Int?
    let showsWrongSelection: Bool
    let isLocked: Bool

    var body: some View {
        // Schrift wird pro Frage einheitlich gewählt – sonst verriete Monospace die Code-Antwort.
        let monospaced = choices.allSatisfy(Self.looksLikeCode)
        VStack(spacing: 10) {
            ForEach(choices.indices, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    row(index, monospaced: monospaced)
                }
                .buttonStyle(.plain)
                // Nicht .disabled: das würde auch die grün markierte Lösung ausgrauen.
                .allowsHitTesting(!isLocked)
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
    }

    private func row(_ index: Int, monospaced: Bool) -> some View {
        let state = state(for: index)
        return HStack(spacing: 12) {
            Text(String(UnicodeScalar(UInt8(65 + index))))
                .font(.subheadline.weight(.bold))
                .frame(width: 30, height: 30)
                .foregroundStyle(state.letterForeground)
                .background(state.letterBackground, in: Circle())
            Text(choices[index])
                .font(monospaced ? .system(.subheadline, design: .monospaced) : .body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let symbol = state.symbol {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(state.tint)
            }
        }
        .padding(14)
        .background(state.tint.opacity(state.isHighlighted ? 0.12 : 0), in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .background(Theme.fieldBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous)
                .strokeBorder(state.isHighlighted ? state.tint : Color.primary.opacity(0.08), lineWidth: state.isHighlighted ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
    }

    private struct RowState {
        var tint: Color = .secondary
        var isHighlighted = false
        var symbol: String?
        var letterForeground: Color = .secondary
        var letterBackground: Color = Color.secondary.opacity(0.12)
    }

    private func state(for index: Int) -> RowState {
        if let correctIndex, index == correctIndex {
            return RowState(tint: Theme.success, isHighlighted: true, symbol: "checkmark.circle.fill", letterForeground: .white, letterBackground: Theme.success)
        }
        if index == selection {
            if showsWrongSelection {
                return RowState(tint: Theme.ember, isHighlighted: true, symbol: "xmark.circle.fill", letterForeground: .white, letterBackground: Theme.ember)
            }
            return RowState(tint: Theme.orange, isHighlighted: true, letterForeground: .white, letterBackground: Theme.orange)
        }
        return RowState()
    }

    static func looksLikeCode(_ text: String) -> Bool {
        text.contains { "();{}=<>\"[]".contains($0) }
    }
}

struct BlankFieldsView: View {
    let count: Int
    @Binding var values: [String]
    let states: [Bool]?
    let isLocked: Bool
    @FocusState private var focused: Int?

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(tint(index), in: Circle())
                    TextField("Lücke \(index + 1)", text: binding(index))
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        #endif
                        .focused($focused, equals: index)
                        .submitLabel(index + 1 < count ? .next : .done)
                        .onSubmit { focused = index + 1 < count ? index + 1 : nil }
                        .disabled(isLocked)
                    if let state = states.flatMap({ index < $0.count ? $0[index] : nil }) {
                        Image(systemName: state ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(state ? Theme.success : Theme.ember)
                    }
                }
                .padding(12)
                .background(Theme.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(focused == index ? Theme.orange : .clear, lineWidth: 2)
                }
            }
        }
    }

    private func tint(_ index: Int) -> Color {
        switch states.flatMap({ index < $0.count ? $0[index] : nil }) {
        case true?: Theme.success
        case false?: Theme.ember
        case nil: Theme.orange
        }
    }

    private func binding(_ index: Int) -> Binding<String> {
        Binding(
            get: { index < values.count ? values[index] : "" },
            set: { newValue in
                if values.count <= index { values += Array(repeating: "", count: index + 1 - values.count) }
                values[index] = newValue
            }
        )
    }
}

/// Monospace-Editor im dunklen Code-Stil. Autokorrektur und Großschreibung sind aus;
/// typografische Anführungszeichen normalisiert der Evaluator.
struct CodeEditorView: View {
    @Binding var text: String
    let placeholder: String
    var minHeight: CGFloat = 180
    let isLocked: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(CodeTheme.plain)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                #endif
                .disabled(isLocked)
                .padding(10)
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(CodeTheme.plain.opacity(0.35))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: minHeight)
        .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        }
        .environment(\.colorScheme, .dark)
        .tint(Theme.orange)
    }
}
