import SwiftUI
import JavaQuestKit

/// Automatische Auswertung am Ende einer Lektion oder Übung.
struct LessonSummaryView: View {
    let model: LessonFlowModel
    let onClose: () -> Void
    let onStartLesson: (String) -> Void
    var onTrainAgain: () -> Void = {}
    @State private var appeared = false

    private var summary: LessonSummary { model.session.summary }

    private var headline: String {
        if model.isTraining { return "Runde geschafft" }
        if model.isPractice { return "Übung abgeschlossen" }
        return summary.passed ? "Lektion gemeistert!" : "Fast geschafft!"
    }

    private var message: String {
        if model.isTraining { return "Was noch hakt, kommt in den nächsten Runden öfter dran – so lange, bis es sitzt." }
        if model.isPractice { return "Deine Wissensanalyse wurde aktualisiert." }
        if summary.passed { return "Stark! Dein Java Master Score ist gestiegen." }
        return "Ab \(Int(LessonSession.passThreshold * 100)) % gilt eine Lektion als bestanden. Wiederhole sie – es zählt immer dein Bestwert."
    }

    var body: some View {
        ScrollView {
            LessonSummaryContent(
                headline: headline,
                message: message,
                summary: summary,
                scoreChange: model.scoreChange,
                isPractice: model.isPractice,
                tasks: model.session.tasks,
                course: model.course,
                appeared: appeared
            )
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if model.isTraining {
                    Button(action: onTrainAgain) {
                        Label("Nächste Runde", systemImage: "infinity")
                    }
                    .buttonStyle(.primary)
                } else if let next = model.nextLessonAfterCurrent, summary.passed {
                    Button { onStartLesson(next.id) } label: {
                        Label("Nächste Lektion: \(next.title)", systemImage: "arrow.right")
                    }
                    .buttonStyle(.primary)
                } else if !summary.passed, let lessonId = model.session.lessonId {
                    Button { onStartLesson(lessonId) } label: {
                        Label("Lektion wiederholen", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.primary)
                }
                Button("Zur Übersicht", action: onClose)
                    .buttonStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .onAppear { appeared = true }
    }
}

struct LessonSummaryContent: View {
    let headline: String
    let message: String
    let summary: LessonSummary
    let scoreChange: ScoreChange?
    let isPractice: Bool
    let tasks: [LearningTask]
    let course: Course
    var appeared = true

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                Image(systemName: summary.passed || isPractice ? "trophy.fill" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 54))
                    .foregroundStyle(summary.passed || isPractice ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.indigo))
                    .symbolEffect(.bounce, value: appeared)
                Text(headline).font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
                Text(message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if !isPractice { StarsView(count: summary.stars, size: 30) }
            }
            .padding(.vertical, 8)

            HStack(spacing: 12) {
                MetricTile(value: "\(Int((summary.accuracy * 100).rounded())) %", label: "Trefferquote (gewichtet)", systemImage: "target", tint: Theme.orange)
                MetricTile(value: "\(summary.firstTryCount)/\(summary.taskCount)", label: "Beim ersten Versuch", systemImage: "bolt.fill", tint: Theme.violet)
            }

            if let scoreChange, !isPractice {
                ScoreChangeCard(change: scoreChange, passed: summary.passed)
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Auswertung je Aufgabe", subtitle: "Niveau steigt von 1 bis 5", systemImage: "list.bullet.clipboard")
                ForEach(tasks) { task in
                    let outcome = summary.outcomes.first { $0.taskId == task.id }
                    HStack(spacing: 10) {
                        Image(systemName: symbol(for: outcome))
                            .foregroundStyle(tint(for: outcome))
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.prompt).font(.subheadline).lineLimit(2)
                            Text(course.topic(id: task.topicId)?.title ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        DifficultyBadge(difficulty: task.difficulty, compact: true)
                    }
                }
            }
            .card()
        }
    }

    private func symbol(for outcome: TaskOutcome?) -> String {
        guard let outcome else { return "circle.dashed" }
        if outcome.solvedOnFirstTry { return "checkmark.circle.fill" }
        return outcome.solved ? "checkmark.circle" : "xmark.circle.fill"
    }

    private func tint(for outcome: TaskOutcome?) -> Color {
        guard let outcome else { return .secondary }
        if outcome.solvedOnFirstTry { return Theme.success }
        return outcome.solved ? Theme.orange : Theme.ember
    }
}

private struct ScoreChangeCard: View {
    let change: ScoreChange
    let passed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("JAVA MASTER SCORE").font(.caption.weight(.heavy)).tracking(1.2).opacity(0.85)
                Spacer()
                if change.delta > 0 {
                    Text("+\(change.delta)")
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.22), in: Capsule())
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(change.before)").font(.title2.weight(.semibold)).opacity(0.7)
                Image(systemName: "arrow.right").opacity(0.7)
                Text("\(change.after)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(change.after)))
            }
            .monospacedDigit()
            if let rank = change.newRank, change.delta > 0 {
                Label("Neuer Rang: \(rank.title)", systemImage: rank.symbolName)
                    .font(.headline)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if change.delta == 0 {
                Text(passed
                     ? "Dein Bestwert bleibt erhalten – für mehr Punkte brauchst du eine höhere Trefferquote."
                     : "Punkte gibt es, sobald du die Lektion mit mindestens \(Int(LessonSession.passThreshold * 100)) % bestehst.")
                    .font(.footnote)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}
