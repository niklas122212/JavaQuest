import SwiftUI
import JavaQuestKit

/// „Meine Schwächen“: Was zuletzt nicht saß – und ein Knopf, es mit anderen Aufgaben zu üben.
struct WeakSpotsView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var width: CGFloat = 400

    private var spots: [WeakSpot] { store.weakSpots }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if spots.isEmpty {
                    emptyState
                } else {
                    weakTopics
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(
                            title: "Das saß zuletzt nicht",
                            subtitle: "Geübt wird mit anderen Aufgaben zum selben Lernziel",
                            systemImage: "arrow.counterclockwise"
                        )
                        ForEach(spots) { spot in
                            WeakSpotRow(spot: spot, topic: store.course.topic(id: spot.topicId))
                        }
                    }
                    .card()
                }
            }
            .padding(.horizontal, width >= 760 ? 28 : 16)
            .padding(.vertical, 20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Theme.screenBackground)
        .navigationTitle("Meine Schwächen")
        .safeAreaInset(edge: .bottom) {
            if !spots.isEmpty { startBar }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(spots.isEmpty ? "Nichts offen" : "\(spots.count) \(spots.count == 1 ? "Lernziel" : "Lernziele") zum Nacharbeiten")
                .font(.largeTitle.weight(.bold))
            Text("Hier steht, was beim letzten Mal nicht saß. Wichtig: Du bekommst nicht dieselbe Frage noch einmal, sondern eine andere Aufgabe zum gleichen Lernziel.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Alles sitzt", systemImage: "checkmark.seal.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.success)
            Text(store.taskHistory.isEmpty
                 ? "Sobald du die ersten Aufgaben gelöst hast, sammelt sich hier, was noch wackelt."
                 : "Alles, was du zuletzt geübt hast, hat im ersten Anlauf gesessen. Weiter so!")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// Die Themen, in denen sich die Schwächen häufen.
    private var weakTopics: some View {
        let counts = Dictionary(grouping: spots, by: \.topicId).mapValues(\.count)
        let sorted = counts.sorted { $0.value > $1.value }.prefix(4)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Wo es sich häuft", subtitle: nil, systemImage: "chart.bar.fill")
            ForEach(Array(sorted), id: \.key) { topicId, anzahl in
                let practice = store.topicPractice(for: topicId)
                HStack(spacing: 10) {
                    IconTile(systemImage: store.course.topic(id: topicId)?.symbol ?? "questionmark", tint: Theme.ember, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.course.topic(id: topicId)?.title ?? topicId)
                            .font(.subheadline.weight(.semibold))
                        Text("\(anzahl) \(anzahl == 1 ? "Lernziel" : "Lernziele") offen · \(practice.correct) von \(practice.seen) richtig")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("Üben") { router.train(topicIds: [topicId], difficulties: [], count: 10) }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.orange)
                }
            }
        }
        .card()
    }

    private var startBar: some View {
        VStack(spacing: 8) {
            Text("Jede Runde nimmt eine andere Variante als beim letzten Fehler.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { router.trainWeakSpots() } label: {
                Label("Schwächen üben", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

/// Ein wackliges Lernziel mit dem, was beim letzten Mal passiert ist.
private struct WeakSpotRow: View {
    let spot: WeakSpot
    let topic: Topic?

    private var tint: Color { spot.lastCredit == 0 ? Theme.ember : Theme.orange }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: spot.lastCredit == 0 ? "xmark.circle.fill" : "checkmark.circle")
                .foregroundStyle(tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.task.prompt)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Chip(text: topic?.title ?? spot.topicId, systemImage: topic?.symbol ?? "tag")
                    DifficultyBadge(difficulty: spot.task.difficulty, compact: true)
                }
                Text("\(spot.summary) · \(spot.attempts)× geübt · \(spot.otherVariants) andere \(spot.otherVariants == 1 ? "Aufgabe" : "Aufgaben") dazu vorhanden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
#Preview("Meine Schwächen") {
    NavigationStack { WeakSpotsView() }
        .environment(PreviewSupport.makeStore())
        .environment(AppRouter())
}
#endif
