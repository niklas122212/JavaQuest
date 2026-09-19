import Charts
import SwiftUI
import JavaQuestKit

struct ContinueLearningCard: View {
    let lesson: Lesson?
    let module: CourseModule?
    let onStart: () -> Void
    var onPractice: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let lesson {
                HStack(spacing: 12) {
                    IconTile(systemImage: module?.symbol ?? "book.fill", tint: Theme.color(for: module?.tier ?? .beginner), size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WEITER LERNEN")
                            .font(.caption.weight(.heavy))
                            .tracking(1.1)
                            .foregroundStyle(Theme.orange)
                        Text(module?.title ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(lesson.title).font(.title2.weight(.bold))
                Text(lesson.summary).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Chip(text: "\(lesson.estimatedMinutes) Min", systemImage: "clock")
                    Chip(text: "\(lesson.theory.count) Karten", systemImage: "book")
                    Chip(text: "\(lesson.tasks.count) Aufgaben", systemImage: "checklist")
                }
                .fixedSize(horizontal: false, vertical: true)
                Button(action: onStart) {
                    Label("Lektion starten", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
                .padding(.top, 4)
            } else {
                Label("Kurs abgeschlossen!", systemImage: "trophy.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.orange)
                Text("Du hast alle Lektionen gemeistert. Im Endlos-Training bleibt alles frisch – oder übe gezielt dein schwächstes Thema.")
                    .foregroundStyle(.secondary)
                if let onPractice {
                    Button("Schwächstes Thema üben", systemImage: "target", action: onPractice)
                        .buttonStyle(.primary)
                }
            }
        }
        .card()
    }
}

/// Endlos-Training: gemischte Runden über alles, was schon gelernt ist.
struct TrainingCard: View {
    let poolCount: Int
    let trainedTasks: Int
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconTile(systemImage: "infinity", tint: Theme.violet, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ENDLOS-TRAINING")
                        .font(.caption.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(Theme.violet)
                    Text(poolCount > 0 ? "\(poolCount) Aufgaben im Topf" : "Noch leer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if poolCount > 0 {
                Text("Runden mit \(TrainingBuilder.roundSize) gemischten Aufgaben aus deinen abgeschlossenen Lektionen. Was du falsch hattest, was lange her ist und deine schwachen Themen kommen öfter dran.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if trainedTasks > 0 {
                    Chip(text: "\(trainedTasks) Aufgaben trainiert", systemImage: "checkmark.seal")
                }
                Button(action: onStart) {
                    Label("Training starten", systemImage: "play.fill")
                }
                .buttonStyle(.secondary)
            } else {
                Text("Schließe deine erste Lektion ab – dann mischt dir das Training daraus immer neue Runden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

/// Kurzfassung der automatischen Auswertung: Stärken, Lücken, Unbekanntes.
struct KnowledgeSnapshotCard: View {
    let report: KnowledgeReport
    let canPracticeFocus: Bool
    let onPractice: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionTitle(title: "Wissenslücken-Analyse", subtitle: "Automatisch aus deinen Antworten", systemImage: "brain.head.profile")
                Button("Details", action: onOpen)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.orange)
            }

            KnowledgeDistributionBar(report: report)

            HStack(spacing: 10) {
                ForEach([TopicStatus.strength, .developing, .gap, .unknown], id: \.self) { status in
                    StatusCounter(status: status, count: report.topics(status).count)
                }
            }

            let practiced = report.insights.filter { $0.mastery != nil }
                .sorted { ($0.mastery ?? 0) < ($1.mastery ?? 0) }
            if !practiced.isEmpty {
                WeakestTopicsChart(insights: Array(practiced.prefix(4)))
            }

            if let focus = report.focusTopic {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        IconTile(systemImage: focus.topic.symbol, tint: Theme.color(for: focus.status), size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dein Fokus").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(focus.topic.title).font(.headline)
                        }
                        Spacer()
                        Text("\((focus.mastery ?? 0).masteryPercent) %")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Theme.color(for: focus.status))
                    }
                    ProgressBar(value: focus.mastery ?? 0, tint: AnyShapeStyle(Theme.color(for: focus.status)))
                    if canPracticeFocus {
                        Button("Lücke gezielt schließen", systemImage: "target", action: onPractice)
                            .buttonStyle(SecondaryButtonStyle(tint: Theme.color(for: focus.status)))
                    }
                }
                .padding(14)
                .background(Theme.color(for: focus.status).opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
            } else {
                Text("Löse ein paar Aufgaben – danach erkennt die App deine Stärken und Wissenslücken.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

private struct StatusCounter: View {
    let status: TopicStatus
    let count: Int

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: status.symbolName)
                .font(.headline)
                .foregroundStyle(Theme.color(for: status))
            Text("\(count)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(status.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.color(for: status).opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct PathPreviewCard: View {
    let modules: [ModuleProgress]
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "Lernpfad", subtitle: "\(modules.filter(\.isCompleted).count) von \(modules.count) Modulen gemeistert", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                Button("Öffnen", action: onOpen)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.orange)
            }
            VStack(spacing: 0) {
                ForEach(Array(modules.enumerated()), id: \.element.id) { index, progress in
                    HStack(spacing: 12) {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(index == 0 ? .clear : connectorColor(modules[index - 1]))
                                .frame(width: 3, height: 10)
                            ZStack {
                                Circle()
                                    .fill(progress.isUnlocked ? AnyShapeStyle(Theme.gradient(for: progress.module.tier)) : AnyShapeStyle(Color.secondary.opacity(0.15)))
                                Image(systemName: progress.isCompleted ? "checkmark" : (progress.isUnlocked ? progress.module.symbol : "lock.fill"))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(progress.isUnlocked ? .white : .secondary)
                            }
                            .frame(width: 32, height: 32)
                            Rectangle()
                                .fill(index == modules.count - 1 ? .clear : connectorColor(progress))
                                .frame(width: 3, height: 10)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(progress.module.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(progress.completedLessons)/\(progress.totalLessons)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressBar(value: progress.fraction, tint: AnyShapeStyle(Theme.gradient(for: progress.module.tier)), height: 6)
                        }
                        .opacity(progress.isUnlocked ? 1 : 0.5)
                    }
                }
            }
        }
        .card()
    }

    private func connectorColor(_ progress: ModuleProgress) -> Color {
        progress.isCompleted ? Theme.color(for: progress.module.tier) : Color.secondary.opacity(0.2)
    }
}

/// Alle Themen als ein gestapelter Balken: Stärken, im Aufbau, Lücken, unbekannt.
private struct KnowledgeDistributionBar: View {
    let report: KnowledgeReport

    private let order: [TopicStatus] = [.strength, .developing, .gap, .unknown]

    var body: some View {
        Chart {
            ForEach(order, id: \.self) { status in
                let count = report.topics(status).count
                if count > 0 {
                    BarMark(x: .value("Themen", count), y: .value("Wissen", "Alle Themen"))
                        .foregroundStyle(by: .value("Status", status.title))
                }
            }
        }
        .chartForegroundStyleScale(domain: order.map(\.title), range: order.map { Theme.color(for: $0) })
        .chartXScale(domain: 0...max(report.insights.count, 1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 16)
        .clipShape(Capsule())
        .accessibilityLabel("Wissensverteilung")
        .accessibilityValue(order.map { "\($0.title): \(report.topics($0).count)" }.joined(separator: ", "))
    }
}

/// Die schwächsten geübten Themen als kleine Balkengrafik mit der Lückengrenze (55 %).
private struct WeakestTopicsChart: View {
    let insights: [TopicInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHWÄCHSTE THEMEN").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Chart {
                ForEach(insights) { insight in
                    BarMark(
                        x: .value("Beherrschung", (insight.mastery ?? 0).masteryPercent),
                        y: .value("Thema", insight.topic.title)
                    )
                    .foregroundStyle(Theme.color(for: insight.status).gradient)
                    .cornerRadius(5)
                    .annotation(position: .trailing) {
                        Text("\((insight.mastery ?? 0).masteryPercent) %")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                RuleMark(x: .value("Lücke", 55))
                    .foregroundStyle(Theme.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartXScale(domain: 0...120)
            .chartXAxis(.hidden)
            .frame(height: CGFloat(insights.count) * 28 + 6)
        }
    }
}
