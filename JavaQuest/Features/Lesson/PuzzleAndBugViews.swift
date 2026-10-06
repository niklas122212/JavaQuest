import SwiftUI
import JavaQuestKit

/// Code-Puzzle: Bausteine antippen, um sie unten anzuhängen – angetippte Zeilen im
/// Programm wandern zurück. Die Einrückung ergibt sich automatisch aus den Klammern.
struct PuzzleBoard: View {
    let spec: OrderingSpec
    let taskId: String
    @Binding var order: [Int]
    let isLocked: Bool
    let evaluation: TaskEvaluationState

    private var pieces: [String] { spec.pieces }
    private var remaining: [Int] { spec.shuffledOrder(seed: taskId).filter { !order.contains($0) } }
    private var showsCorrectness: Bool { evaluation.hasResult || evaluation.isRevealed }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            program
            if !remaining.isEmpty, !isLocked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BAUSTEINE – ANTIPPEN ZUM EINFÜGEN").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(remaining, id: \.self) { index in
                            Button { withAnimation(.snappy) { order.append(index) } } label: {
                                Text(pieces[index])
                                    .font(.system(.footnote, design: .monospaced).weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(CodeTheme.plain)
                                    .background(CodeTheme.chrome, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.orange.opacity(0.5)))
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            if !order.isEmpty, !isLocked {
                Button("Alle zurücklegen", systemImage: "arrow.uturn.backward") { withAnimation(.snappy) { order.removeAll() } }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.orange)
            }
        }
    }

    private var program: some View {
        let lines = OrderingSpec.assemble(order.map { pieces[$0] }).components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 0) {
            if order.isEmpty {
                Text("Tippe unten die Zeilen in der richtigen Reihenfolge an.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(CodeTheme.plain.opacity(0.4))
                    .padding(14)
            }
            ForEach(Array(order.enumerated()), id: \.offset) { position, pieceIndex in
                let isRight = pieces[pieceIndex] == pieces[safe: position]
                Button {
                    guard !isLocked else { return }
                    withAnimation(.snappy) { _ = order.remove(at: position) }
                } label: {
                    HStack(spacing: 10) {
                        Text("\(position + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(CodeTheme.plain.opacity(0.35))
                            .frame(width: 20, alignment: .trailing)
                        Text(CodeBlockView.highlighted(position < lines.count ? lines[position] : pieces[pieceIndex]))
                            .font(.system(.footnote, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        Spacer(minLength: 0)
                        if showsCorrectness {
                            Image(systemName: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isRight ? Theme.success : Theme.ember)
                        } else if !isLocked {
                            Image(systemName: "minus.circle").foregroundStyle(CodeTheme.plain.opacity(0.3))
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(showsCorrectness ? (isRight ? Theme.success : Theme.ember).opacity(0.15) : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(isLocked ? "" : "Tippen, um die Zeile zurückzulegen"))
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

/// Bug-Jagd: Jede Codezeile ist antippbar. Nach dem Lösen erscheint die Korrektur direkt darunter.
struct BugLinePicker: View {
    let snippet: CodeSnippet
    let spec: FindBugSpec
    @Binding var selection: Int?
    let isLocked: Bool
    let evaluation: TaskEvaluationState

    private var isSolved: Bool { evaluation.isCorrect || evaluation.isRevealed }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(snippet.lines.enumerated()), id: \.offset) { index, line in
                let number = index + 1
                Button {
                    guard !isLocked, !line.code.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    withAnimation(.snappy) { selection = number }
                } label: {
                    HStack(spacing: 10) {
                        Text("\(number)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(CodeTheme.plain.opacity(0.35))
                            .frame(width: 22, alignment: .trailing)
                        Text(CodeBlockView.highlighted(line.code.isEmpty ? " " : line.code))
                            .font(.system(.footnote, design: .monospaced))
                            .strikethrough(isSolved && number == spec.bugLine, color: Theme.ember)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        Spacer(minLength: 0)
                        if let symbol = symbol(for: number) {
                            Image(systemName: symbol.name).foregroundStyle(symbol.tint)
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(background(for: number))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == number ? .isSelected : [])

                if isSolved, number == spec.bugLine {
                    HStack(spacing: 10) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.success)
                            .frame(width: 22, alignment: .trailing)
                        Text(CodeBlockView.highlighted(indentation(of: line.code) + spec.fix.code.trimmingCharacters(in: .whitespaces)))
                            .font(.system(.footnote, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Theme.success.opacity(0.22))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private func indentation(of code: String) -> String { String(code.prefix { $0 == " " }) }

    private func symbol(for number: Int) -> (name: String, tint: Color)? {
        if isSolved, number == spec.bugLine { return ("ant.fill", Theme.ember) }
        if number == selection, evaluation.hasResult, !evaluation.isCorrect { return ("checkmark.circle", Theme.success) }
        if number == selection { return ("scope", Theme.orange) }
        return nil
    }

    private func background(for number: Int) -> Color {
        if isSolved, number == spec.bugLine { return Theme.ember.opacity(0.25) }
        if number == selection, evaluation.hasResult, !evaluation.isCorrect { return Theme.success.opacity(0.12) }
        if number == selection { return Theme.orange.opacity(0.22) }
        return .clear
    }
}

/// Einfaches Fließlayout: Elemente nebeneinander, bei Platzmangel in die nächste Zeile.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = fitted(subviews[index], width: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    /// Natürliche Größe, aber höchstens so breit wie der Container (lange Bausteine brechen dann um).
    private func fitted(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard width.isFinite, natural.width > width else { return natural }
        return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = fitted(subviews[index], width: width)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
