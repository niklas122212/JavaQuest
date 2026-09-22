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
                reviewCard
                if spots.isEmpty {
                    if store.dueGoalCount == 0 { emptyState }
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

    /// Wiederholung: Lernziele, die saßen, deren Pause aber abgelaufen ist.
    /// Bewusst getrennt von den Schwächen – hier geht es nicht um Fehler, sondern ums Vergessen.
    @ViewBuilder
    private var reviewCard: some View {
        let faellig = store.dueGoalCount
        if faellig > 0 {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(
                    title: "Heute zur Wiederholung fällig",
                    subtitle: "Was du kannst, wird in wachsenden Abständen abgefragt – bevor es verblasst",
                    systemImage: "calendar.badge.clock"
                )
                Text("\(faellig) \(faellig == 1 ? "Lernziel wartet" : "Lernziele warten"). Je öfter etwas hintereinander sitzt, desto länger die nächste Pause: erst am nächsten Tag, dann nach 3, 7, 16 und 35 Tagen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { router.review() } label: {
                    Label("Wiederholung starten", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(.primary)
            }
            .card()
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
                WeakTopicRow(topicId: topicId, openGoals: anzahl)
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

/// Ein Thema, in dem sich die Schwächen häufen – mit der Aufschlüsselung nach Stufe.
///
/// Die Stufen sind der eigentliche Punkt: „Vererbung wackelt“ hilft nicht weiter, wenn die
/// leichten Aufgaben sitzen und erst Stufe 4 danebengeht. Der Knopf übt dann genau diese Stufen.
private struct WeakTopicRow: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router
    let topicId: String
    let openGoals: Int

    private var topic: Topic? { store.course.topic(id: topicId) }
    private var levels: [LevelPerformance] { store.levels(forTopic: topicId) }
    private var weakLevels: [LevelPerformance] { levels.filter(\.isWeak) }

    /// Satz in Alltagssprache: Wo genau hakt es?
    private var levelSummary: String {
        guard !weakLevels.isEmpty else {
            return "Kein Niveau fällt heraus – es verteilt sich gleichmäßig."
        }
        let nummern = weakLevels.map { "\($0.difficulty.rawValue)" }
        let wo = nummern.count == 1 ? "Stufe \(nummern[0])" : "Stufe \(nummern.dropLast().joined(separator: ", ")) und \(nummern.last!)"
        return "Es hakt ab \(wo) – die leichteren sitzen."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconTile(systemImage: topic?.symbol ?? "questionmark", tint: Theme.ember, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic?.title ?? topicId)
                        .font(.subheadline.weight(.semibold))
                    Text("\(openGoals) \(openGoals == 1 ? "Lernziel" : "Lernziele") offen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(weakLevels.isEmpty ? "Üben" : "Stufen üben") {
                    router.train(
                        topicIds: [topicId],
                        difficulties: Set(weakLevels.map(\.difficulty)),
                        count: 10
                    )
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.orange)
            }
            if !levels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(levels) { level in
                        LevelPill(level: level)
                    }
                }
                Text(levelSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Eine Stufe mit ihrer Trefferquote – rot, wenn sie unter der Bestehensgrenze liegt.
private struct LevelPill: View {
    let level: LevelPerformance

    var body: some View {
        VStack(spacing: 2) {
            Text("\(level.difficulty.rawValue)")
                .font(.caption2.weight(.bold))
            Text("\(level.solved)/\(level.seen)")
                .font(.system(size: 10))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(level.isWeak ? Theme.ember.opacity(0.16) : Color.secondary.opacity(0.10), in: .rect(cornerRadius: 8))
        .foregroundStyle(level.isWeak ? Theme.ember : .secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(level.summary) richtig\(level.isWeak ? ", wacklig" : "")")
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
