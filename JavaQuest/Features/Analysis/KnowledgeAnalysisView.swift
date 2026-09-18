import Charts
import SwiftUI
import JavaQuestKit

/// Automatische Auswertung: Stärken, Wissenslücken, Themen im Aufbau und noch unbekannte Themen.
struct KnowledgeAnalysisView: View {
    var body: some View {
        ScrollView {
            KnowledgeAnalysisContent()
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Wissensanalyse")
    }
}

struct KnowledgeAnalysisContent: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let report = store.knowledgeReport
        let practiced = report.insights.filter { $0.mastery != nil }
        VStack(spacing: 20) {
            AnalysisSummaryCard(report: report)
            if practiced.isEmpty {
                ContentUnavailableView(
                    "Noch keine Auswertung",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Sobald du Aufgaben löst, zeigt dir die App hier Stärken und Wissenslücken.")
                )
                .card()
            } else {
                MasteryChartCard(insights: practiced)
            }
            ForEach([TopicStatus.gap, .developing, .strength, .unknown], id: \.self) { status in
                let topics = status == .gap ? report.gaps : report.topics(status)
                if !topics.isEmpty {
                    TopicStatusSection(status: status, insights: topics, lessonTitle: lessonTitle) { topicId in
                        store.practiceTasks(for: topicId).isEmpty ? nil : { router.practice(topicId: topicId) }
                    }
                }
            }
        }
    }

    private func lessonTitle(_ id: String?) -> String? {
        id.flatMap { store.course.lesson(id: $0)?.title }
    }
}

private struct AnalysisSummaryCard: View {
    let report: KnowledgeReport

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: report.overallMastery ?? 0, lineWidth: 10)
                VStack(spacing: 0) {
                    Text(report.overallMastery.map { "\($0.masteryPercent)" } ?? "–")
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text("%").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                Text("Gesamte Beherrschung").font(.headline)
                Text("Gewichtet nach Niveau: Schwere Aufgaben zählen mehr. Wenige Antworten werden vorsichtig bewertet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // Auf schmalen Displays zweizeilig, damit kein Zähler abgeschnitten wird.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { chips(TopicStatus.allCases) }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) { chips([.strength, .developing]) }
                        HStack(spacing: 6) { chips([.gap, .unknown]) }
                    }
                }
            }
        }
        .card()
    }

    private func chips(_ statuses: [TopicStatus]) -> some View {
        ForEach(statuses, id: \.self) { status in
            Chip(text: "\(report.topics(status).count)", systemImage: status.symbolName, tint: Theme.color(for: status))
                .fixedSize()
        }
    }
}

private struct MasteryChartCard: View {
    let insights: [TopicInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Beherrschung je Thema", subtitle: "Ab 75 % Stärke · unter 55 % Wissenslücke", systemImage: "chart.bar.fill")
            Chart {
                ForEach(insights) { insight in
                    BarMark(
                        x: .value("Beherrschung", (insight.mastery ?? 0).masteryPercent),
                        y: .value("Thema", insight.topic.title)
                    )
                    .foregroundStyle(Theme.color(for: insight.status).gradient)
                    .cornerRadius(6)
                    .annotation(position: .trailing) {
                        Text("\((insight.mastery ?? 0).masteryPercent) %")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                RuleMark(x: .value("Lücke", 55))
                    .foregroundStyle(Theme.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                RuleMark(x: .value("Stärke", 75))
                    .foregroundStyle(Theme.success.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartXScale(domain: 0...115)
            .chartXAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Int.self) ?? 0)") }
                }
            }
            .frame(height: CGFloat(insights.count) * 34 + 30)
        }
        .card()
    }
}

private struct TopicStatusSection: View {
    let status: TopicStatus
    let insights: [TopicInsight]
    let lessonTitle: (String?) -> String?
    let practiceAction: (String) -> (() -> Void)?

    private var subtitle: String {
        switch status {
        case .gap: "Hier lohnt sich gezieltes Üben am meisten."
        case .developing: "Auf gutem Weg – noch ein paar Aufgaben bis zur Stärke."
        case .strength: "Sicher beherrscht."
        case .unknown: "Kommt noch im Lernpfad."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: status.symbolName).foregroundStyle(Theme.color(for: status))
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(insights) { insight in
                TopicRow(insight: insight, lessonTitle: lessonTitle(insight.lessonId), onPractice: practiceAction(insight.topic.id))
                if insight.id != insights.last?.id { Divider() }
            }
        }
        .card()
    }
}

private struct TopicRow: View {
    let insight: TopicInsight
    let lessonTitle: String?
    let onPractice: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconTile(systemImage: insight.topic.symbol, tint: Theme.color(for: insight.status), size: 38)
            VStack(alignment: .leading, spacing: 5) {
                Text(insight.topic.title).font(.subheadline.weight(.semibold))
                if let mastery = insight.mastery {
                    ProgressBar(value: mastery, tint: AnyShapeStyle(Theme.color(for: insight.status)), height: 6)
                    Text(detailLine(mastery: mastery))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(lessonTitle.map { "Wird behandelt in „\($0)“" } ?? insight.topic.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let onPractice, insight.status == .gap || insight.status == .developing {
                Button("Üben", action: onPractice)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(Theme.color(for: insight.status))
                    .background(Theme.color(for: insight.status).opacity(0.12), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detailLine(mastery: Double) -> String {
        let count = insight.stats.attempts
        var parts = ["\(mastery.masteryPercent) %", count == 1 ? "1 Aufgabe" : "\(count) Aufgaben"]
        if let last = insight.stats.lastPracticed {
            parts.append("zuletzt " + last.formatted(.relative(presentation: .named)))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Previews

#Preview("Wissensanalyse") {
    NavigationStack { KnowledgeAnalysisView() }
        .environment(PreviewSupport.makeStore())
        .environment(AppRouter())
}
