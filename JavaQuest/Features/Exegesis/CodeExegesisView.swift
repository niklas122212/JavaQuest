import SwiftUI
import JavaQuestKit

/// Code-Exegese: oben der Code mit nummerierten, antippbaren Zeilen, darunter die
/// Erklärung jeder Zeile in Alltagssprache. Die gewählte Zeile ist im Code und in
/// der Erklärung markiert; Befehle der Zeile erklärt das Befehlslexikon.
///
/// Zwei Darstellungen, jederzeit umschaltbar:
/// - **Alle Zeilen** – die komplette Zerlegung untereinander (Theorie, Lösungen).
/// - **Schritt für Schritt** – eine Zeile nach der anderen mit Vor/Zurück (Aufgaben).
struct CodeExegesisView: View {
    enum Presentation: String, CaseIterable, Identifiable {
        case steps = "Schritt für Schritt"
        case all = "Alle Zeilen"
        var id: String { rawValue }
    }

    let lines: [ExplainedLine]
    var caption = "Java"
    /// Anfangsdarstellung. `nil` = Erklärungen erst nach Antippen einer Zeile oder des Knopfs.
    var initialPresentation: Presentation? = .all
    /// Zeilen, deren Erklärung (noch) verborgen bleibt – z. B. Lücken vor dem Lösen.
    var hiddenLines: Set<Int> = []
    /// Eigene Darstellung einzelner Zeilen (Lückentext mit den aktuellen Eingaben).
    var render: ((ExplainedLine) -> AttributedString)?

    @State private var selected: Int?
    @State private var presentation: Presentation?
    @State private var panelWidth: CGFloat = 0
    @State private var codeWidth: CGFloat = 0

    /// Alle Zeilen inklusive Leerzeilen (die der Erklärer überspringt) – für den Code oben.
    private var displayLines: [ExplainedLine] {
        let byNumber = Dictionary(lines.map { ($0.number, $0) }, uniquingKeysWith: { first, _ in first })
        let count = lines.map(\.number).max() ?? 0
        return (0..<count).map { index in
            byNumber[index + 1] ?? ExplainedLine(number: index + 1, code: "", explanation: "", terms: [], isFallback: false)
        }
    }

    /// Zeilenbreite: mindestens die sichtbare Breite, damit die Markierung ganz durchgeht.
    private var rowWidth: CGFloat { max(panelWidth, codeWidth + 20 + 10 + 24) }

    private var codeLines: [ExplainedLine] { lines.filter { !$0.code.trimmingCharacters(in: .whitespaces).isEmpty } }
    private var selectedIndex: Int? { codeLines.firstIndex { $0.number == selected } }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                codePanel(proxy)
                if let presentation {
                    Picker("Darstellung", selection: presentationBinding) {
                        ForEach(Presentation.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch presentation {
                    case .steps: stepCard
                    case .all: allLines
                    }
                } else {
                    Button {
                        withAnimation(.smooth) {
                            presentation = .steps
                            selected = codeLines.first?.number
                        }
                    } label: {
                        Label("Code Zeile für Zeile erklären", systemImage: "text.magnifyingglass")
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
        .onAppear {
            if presentation == nil { presentation = initialPresentation }
            if presentation != nil, selected == nil { selected = codeLines.first?.number }
        }
        .onChange(of: initialPresentation) { _, new in
            // Nach dem Lösen klappt die komplette Zerlegung auf.
            guard let new else { return }
            withAnimation(.smooth) {
                presentation = new
                if selected == nil { selected = codeLines.first?.number }
            }
        }
    }

    private var presentationBinding: Binding<Presentation> {
        Binding { presentation ?? .all } set: { new in withAnimation(.smooth) { presentation = new } }
    }

    private func select(_ number: Int, _ proxy: ScrollViewProxy? = nil) {
        withAnimation(.smooth) {
            selected = number
            if presentation == nil { presentation = .steps }
        }
        if presentation == .all, let proxy {
            withAnimation(.smooth) { proxy.scrollTo(Self.rowId(number), anchor: .center) }
        }
    }

    private static func rowId(_ number: Int) -> String { "exegesis-line-\(number)" }

    // MARK: Code oben

    private func codePanel(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach([Color.red, .yellow, .green], id: \.self) { color in
                    Circle().fill(color.opacity(0.75)).frame(width: 9, height: 9)
                }
                Spacer()
                Label("Zeile antippen", systemImage: "hand.tap")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(CodeTheme.plain.opacity(0.5))
                Text(caption)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(CodeTheme.plain.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(CodeTheme.chrome)

            // Nicht umbrechen (deutsche Silbentrennung würde Code zerteilen) – lange Zeilen scrollen seitlich.
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(displayLines, id: \.number) { line in
                        codeRow(line, proxy)
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { panelWidth = $0 }
        }
        .background(CodeTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private func codeRow(_ line: ExplainedLine, _ proxy: ScrollViewProxy) -> some View {
        let isEmpty = line.code.trimmingCharacters(in: .whitespaces).isEmpty
        let isSelected = line.number == selected
        return Button { select(line.number, proxy) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(line.number)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isSelected ? Theme.orange : CodeTheme.plain.opacity(0.35))
                    .frame(width: 20, alignment: .trailing)
                Text(render?(line) ?? CodeBlockView.highlighted(isEmpty ? " " : line.code))
                    .font(.system(.footnote, design: .monospaced))
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                        if width > codeWidth { codeWidth = width }
                    }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 12)
            .frame(width: rowWidth > 0 ? rowWidth : nil, alignment: .leading)
            .background(isSelected ? Theme.orange.opacity(0.24) : .clear)
            .overlay(alignment: .leading) {
                if isSelected { Rectangle().fill(Theme.orange).frame(width: 3) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .accessibilityHidden(isEmpty)
        .accessibilityLabel("Zeile \(line.number): \(line.code.trimmingCharacters(in: .whitespaces))")
        .accessibilityHint("Zeigt die Erklärung dieser Zeile")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Schritt für Schritt

    @ViewBuilder private var stepCard: some View {
        if let index = selectedIndex {
            let line = codeLines[index]
            VStack(alignment: .leading, spacing: 12) {
                ExplanationRow(line: line, isSelected: true, isHidden: hiddenLines.contains(line.number), showsTerms: true)

                if codeLines.count > 1 {
                    HStack(spacing: 10) {
                        Button {
                            select(codeLines[index - 1].number)
                        } label: {
                            Label("Vorige", systemImage: "chevron.left")
                        }
                        .buttonStyle(.secondary)
                        .disabled(index == 0)

                        Text("\(index + 1) / \(codeLines.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize()

                        Button {
                            select(codeLines[index + 1].number)
                        } label: {
                            Label("Nächste", systemImage: "chevron.right")
                                .labelStyle(TrailingIconLabelStyle())
                        }
                        .buttonStyle(.secondary)
                        .disabled(index + 1 == codeLines.count)
                    }
                }
            }
        }
    }

    // MARK: Alle Zeilen

    private var allLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(codeLines, id: \.number) { line in
                ExplanationRow(
                    line: line,
                    isSelected: line.number == selected,
                    isHidden: hiddenLines.contains(line.number),
                    showsTerms: line.number == selected
                )
                .id(Self.rowId(line.number))
                .onTapGesture { select(line.number) }
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}

/// Eine erklärte Zeile: Nummer, Code, Erklärung in Alltagssprache, dazu (bei der
/// markierten Zeile) die Befehle aus dem Lexikon.
struct ExplanationRow: View {
    let line: ExplainedLine
    let isSelected: Bool
    let isHidden: Bool
    let showsTerms: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(line.number)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(isSelected ? Theme.orange : Color.secondary.opacity(0.55), in: Circle())
                Text(Self.readable(line.code))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if isHidden {
                Label("Hier steckt eine Lücke – die ganze Erklärung erscheint, sobald du die Aufgabe gelöst hast.", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Die übrigen Befehle der Zeile verraten die Lösung nicht.
                if showsTerms, !line.terms.isEmpty {
                    TermList(terms: line.terms)
                }
            } else {
                Text(line.explanation)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                if showsTerms, !line.terms.isEmpty {
                    TermList(terms: line.terms)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Theme.orange.opacity(0.1) : Theme.fieldBackground.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Theme.orange.opacity(0.8) : .clear, lineWidth: 1.5)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension ExplanationRow {
    /// Codezeile für die Vorschau: Lücken-Platzhalter {{0}} werden zu [Lücke 1].
    static func readable(_ code: String) -> String {
        var text = code.trimmingCharacters(in: .whitespaces)
        while let open = text.range(of: "{{"),
              let close = text.range(of: "}}", range: open.upperBound..<text.endIndex),
              let index = Int(text[open.upperBound..<close.lowerBound]) {
            text.replaceSubrange(open.lowerBound..<close.upperBound, with: "[Lücke \(index + 1)]")
        }
        return text
    }
}

/// Befehlslexikon für eine Zeile: Begriff und Bedeutung untereinander.
struct TermList: View {
    let terms: [GlossaryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BEFEHLE IN DIESER ZEILE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.orange)
            ForEach(terms) { term in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(term.term)
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(Theme.indigo)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .fixedSize()
                    Text(term.meaning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Label mit Symbol hinter dem Text („Nächste Zeile ›“).
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}

extension CodeBlockView {
    /// Eine Zeile des Lückentexts mit den aktuellen Eingaben (für die Code-Exegese).
    static func fillBlankLine(_ line: String, values: [String], states: [Bool]?) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(line)
        while let open = rest.range(of: "{{"),
              let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex),
              let index = Int(rest[open.upperBound..<close.lowerBound]) {
            result += highlighted(String(rest[rest.startIndex..<open.lowerBound]))
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
            rest = rest[close.upperBound...]
        }
        result += highlighted(String(rest))
        return result
    }
}
