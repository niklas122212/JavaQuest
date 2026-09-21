import SwiftUI
import JavaQuestKit

/// Ein Theorie-Happen pro Seite – kurz, prägnant, mit Codebeispiel.
struct TheoryStepView: View {
    private static let topAnchor = "theory-top"
    let cards: [TheoryCard]
    let page: Int
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 0).id(Self.topAnchor)
                TheoryCardContent(card: cards[page], page: page, count: cards.count)
                    .id(page)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                    .padding(20)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
            }
            // Neue Karte beginnt immer oben – nicht mitten im Text der vorigen.
            .onChange(of: page) { _, _ in proxy.scrollTo(Self.topAnchor, anchor: .top) }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                if page > 0 {
                    Button("Zurück", systemImage: "chevron.left", action: onBack)
                        .buttonStyle(.secondary)
                        .frame(maxWidth: 140)
                }
                Button(action: onNext) {
                    Label(page + 1 < cards.count ? "Weiter" : "Zu den Aufgaben",
                          systemImage: page + 1 < cards.count ? "chevron.right" : "flag.checkered")
                }
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }
}

struct TheoryCardContent: View {
    let card: TheoryCard
    let page: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Chip(text: "Theorie-Happen \(page + 1)/\(count)", systemImage: "book.fill", tint: Theme.indigo)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<count, id: \.self) { index in
                        Capsule()
                            .fill(index <= page ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.secondary.opacity(0.25)))
                            .frame(width: index == page ? 22 : 8, height: 8)
                    }
                }
                .accessibilityHidden(true)
            }
            Text(card.title)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(card.body)
                .font(.title3)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            if let diagram = card.diagram {
                UMLDiagramView(diagram: diagram)
            }
            if let example = card.example {
                CodeExegesisView(lines: example.explained(), caption: "Beispiel")
            }
            if let callout = card.callout {
                CalloutView(callout: callout)
            }
        }
        .card(padding: 24)
    }
}
