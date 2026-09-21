import SwiftUI
import JavaQuestKit

/// Freies Lernen: Alle Themen des Kurses auf einen Blick, unabhängig vom Lernpfad.
/// Man wählt Themen, Niveau und Anzahl – daraus entsteht eine eigene Übungsrunde.
struct TopicCatalogView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var selectedTopics: Set<String> = []
    @State private var selectedDifficulties: Set<Difficulty> = []
    @State private var taskCount = 10
    @State private var width: CGFloat = 400

    private var topics: [Topic] { store.course.practiceableTopics }
    private var matchingTasks: Int {
        TrainingBuilder.freePool(course: store.course, topicIds: selectedTopics, difficulties: selectedDifficulties).count
    }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: width >= 900 ? 3 : (width >= 620 ? 2 : 1))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                filters
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(topics) { topic in
                        TopicTile(
                            topic: topic,
                            stats: store.topicPractice(for: topic.id),
                            taskCount: store.course.tasks(forTopic: topic.id).count,
                            isSelected: selectedTopics.contains(topic.id)
                        ) {
                            toggle(topic.id)
                        }
                    }
                }
            }
            .padding(.horizontal, width >= 760 ? 28 : 16)
            .padding(.vertical, 20)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Theme.screenBackground)
        .navigationTitle("Alle Themen")
        .safeAreaInset(edge: .bottom) { startBar }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Such dir aus, was du üben willst")
                .font(.largeTitle.weight(.bold))
            Text("Jedes Thema ist sofort übbar – auch wenn die Lektion im Lernpfad noch nicht dran war. Ohne Auswahl kommt alles gemischt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "Niveau", subtitle: "Ohne Auswahl: alle Niveaus", systemImage: "chart.bar.fill")
                HStack(spacing: 8) {
                    ForEach(Difficulty.allCases) { difficulty in
                        FilterChip(
                            text: "\(difficulty.rawValue)",
                            isSelected: selectedDifficulties.contains(difficulty),
                            tint: Theme.color(for: difficulty)
                        ) {
                            toggle(difficulty)
                        }
                        .accessibilityLabel(Text("Niveau \(difficulty.rawValue): \(difficulty.label)"))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "Wie viele Aufgaben?", subtitle: nil, systemImage: "number")
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 25], id: \.self) { count in
                        FilterChip(text: "\(count)", isSelected: taskCount == count, tint: Theme.indigo) {
                            taskCount = count
                        }
                    }
                }
            }

            if !selectedTopics.isEmpty {
                Button("Auswahl zurücksetzen", systemImage: "arrow.counterclockwise") {
                    selectedTopics.removeAll()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.orange)
            }
        }
        .card()
    }

    private var startBar: some View {
        VStack(spacing: 8) {
            Text(summaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                router.train(topicIds: selectedTopics, difficulties: selectedDifficulties, count: taskCount)
            } label: {
                Label(selectedTopics.isEmpty ? "Gemischt üben" : "\(selectedTopics.count) Thema\(selectedTopics.count == 1 ? "" : "s") üben", systemImage: "play.fill")
            }
            .buttonStyle(.primary)
            .disabled(matchingTasks == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var summaryText: String {
        guard matchingTasks > 0 else { return "Zu dieser Auswahl gibt es keine Aufgaben – nimm ein Niveau dazu." }
        let level = selectedDifficulties.isEmpty ? "allen Niveaus" : selectedDifficulties.sorted().map { "\($0.rawValue)" }.joined(separator: ", ")
        return "\(min(taskCount, matchingTasks)) von \(matchingTasks) passenden Aufgaben · Niveau: \(level)"
    }

    private func toggle(_ topicId: String) {
        if selectedTopics.contains(topicId) { selectedTopics.remove(topicId) } else { selectedTopics.insert(topicId) }
    }

    private func toggle(_ difficulty: Difficulty) {
        if selectedDifficulties.contains(difficulty) { selectedDifficulties.remove(difficulty) } else { selectedDifficulties.insert(difficulty) }
    }
}

/// Ein Thema mit Fortschritt: wie viele Aufgaben gesehen, wie viele davon richtig.
private struct TopicTile: View {
    let topic: Topic
    let stats: TopicPractice
    let taskCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    IconTile(systemImage: topic.symbol, tint: isSelected ? Theme.orange : Theme.indigo, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(topic.title).font(.headline).lineLimit(1)
                        Text("\(taskCount) Aufgaben").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Theme.orange : .secondary)
                        .font(.title3)
                }
                Text(topic.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
                if stats.seen > 0 {
                    ProgressBar(value: stats.successRate, height: 6)
                    Text("\(stats.correct) von \(stats.seen) richtig · \(Int((stats.successRate * 100).rounded())) %")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Noch nicht geübt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 16)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.orange : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChip: View {
    let text: String
    let isSelected: Bool
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? tint : Theme.fieldBackground, in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Alle Themen") {
    NavigationStack { TopicCatalogView() }
        .environment(PreviewSupport.makeStore())
        .environment(AppRouter())
}
#endif
