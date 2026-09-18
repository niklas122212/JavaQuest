import SwiftUI
import JavaQuestKit

/// Java-Code mit Syntaxhervorhebung im Stil eines Editorfensters.
/// Lange Zeilen werden nicht umbrochen, sondern horizontal scrollbar.
struct CodeBlockView: View {
    let content: AttributedString
    var caption: String = "Java"

    init(code: String, caption: String = "Java") {
        self.content = Self.highlighted(code)
        self.caption = caption
    }

    init(attributed: AttributedString, caption: String = "Java") {
        self.content = attributed
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach([Color.red, .yellow, .green], id: \.self) { color in
                    Circle().fill(color.opacity(0.75)).frame(width: 9, height: 9)
                }
                Spacer()
                Text(caption)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(CodeTheme.plain.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(CodeTheme.chrome)

            ViewThatFits(in: .horizontal) {
                codeText
                ScrollView(.horizontal, showsIndicators: false) { codeText }
            }
        }
        .background(CodeTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private var codeText: some View {
        Text(content)
            .font(.system(.footnote, design: .monospaced))
            .lineSpacing(3)
            .fixedSize(horizontal: true, vertical: true)
            .textSelection(.enabled)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func highlighted(_ code: String) -> AttributedString {
        var result = AttributedString()
        for token in JavaHighlighter.tokenize(code) {
            var part = AttributedString(token.text)
            part.foregroundColor = CodeTheme.color(for: token.kind)
            result += part
        }
        return result
    }

    /// Lückentext: Lücken werden farbig markiert und zeigen live die Eingabe.
    static func fillBlank(_ spec: FillBlankSpec, values: [String], states: [Bool]? = nil) -> AttributedString {
        var result = AttributedString()
        for segment in spec.segments {
            switch segment {
            case .text(let text):
                result += highlighted(text)
            case .blank(let index):
                let value = index < values.count ? values[index].trimmingCharacters(in: .whitespaces) : ""
                var part = AttributedString(value.isEmpty ? " \(index + 1) " : " \(value) ")
                let tint: Color = switch states.flatMap({ index < $0.count ? $0[index] : nil }) {
                case true?: Theme.success
                case false?: Theme.ember
                case nil: Theme.orange
                }
                part.foregroundColor = value.isEmpty ? tint : .white
                part.backgroundColor = tint.opacity(value.isEmpty ? 0.25 : 0.55)
                result += part
            }
        }
        return result
    }
}
