import SwiftUI
import JavaQuestKit

struct DashboardView: View {
    @State private var width: CGFloat = 400

    var body: some View {
        ScrollView {
            DashboardContent(isWide: width >= 760)
                .padding(.horizontal, width >= 760 ? 28 : 16)
                .padding(.vertical, 20)
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Theme.screenBackground)
        .navigationTitle("Übersicht")
        #if os(iOS)
        // Die Begrüßung ist schon eine große Überschrift – der Titel bleibt klein.
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Inhalt des Dashboards. Zweispaltig auf iPad/Mac, einspaltig auf dem iPhone.
struct DashboardContent: View {
    let isWide: Bool
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DashboardHeader(streak: store.displayedStreak, level: store.profile?.experienceLevel)
            if isWide {
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 20) {
                        scoreCard
                        continueCard
                        statsGrid
                    }
                    VStack(spacing: 20) {
                        knowledgeCard
                        pathCard
                    }
                }
            } else {
                scoreCard
                continueCard
                knowledgeCard
                pathCard
                statsGrid
            }
        }
    }

    private var scoreCard: some View {
        MasterScoreCard(
            score: store.masterScore,
            rank: store.rank,
            nextRank: store.nextRank,
            progressToNext: store.progressToNextRank,
            weeklyDelta: store.weeklyScoreDelta,
            history: store.scoreHistory
        )
    }

    private var continueCard: some View {
        let lesson = store.nextLesson
        return ContinueLearningCard(
            lesson: lesson,
            module: lesson.flatMap { store.course.module(containingLesson: $0.id) },
            onStart: { if let lesson { router.startLesson(lesson.id) } },
            onPractice: store.knowledgeReport.focusTopic.map { focus in { router.practice(topicId: focus.topic.id) } }
        )
    }

    private var knowledgeCard: some View {
        let report = store.knowledgeReport
        let focus = report.focusTopic
        return KnowledgeSnapshotCard(
            report: report,
            canPracticeFocus: focus.map { !store.practiceTasks(for: $0.topic.id).isEmpty } ?? false,
            onPractice: { if let focus { router.practice(topicId: focus.topic.id) } },
            onOpen: { router.selection = .analysis }
        )
    }

    private var pathCard: some View {
        PathPreviewCard(modules: store.moduleProgress) { router.selection = .path }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            MetricTile(value: "\(store.completedLessonCount)/\(store.course.allLessons.count)", label: "Lektionen abgeschlossen", systemImage: "checkmark.circle.fill", tint: Theme.success)
            MetricTile(value: "\(store.solvedTaskCount)", label: "Aufgaben gelöst", systemImage: "chevron.left.forwardslash.chevron.right", tint: Theme.indigo)
            MetricTile(value: store.firstTryRate.map { "\(Int(($0 * 100).rounded())) %" } ?? "–", label: "Beim ersten Versuch", systemImage: "scope", tint: Theme.violet)
            MetricTile(value: "\(store.displayedStreak)", label: store.displayedStreak == 1 ? "Tag in Folge" : "Tage in Folge", systemImage: "flame.fill", tint: Theme.orange)
        }
    }
}

private struct DashboardHeader: View {
    let streak: Int
    let level: ExperienceLevel?

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "Guten Morgen!"
        case 11..<17: "Schön, dass du da bist!"
        case 17..<23: "Guten Abend!"
        default: "Noch wach? Dann los!"
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.largeTitle.weight(.bold))
                Text("Ein Theorie-Happen, ein paar Aufgaben – Schritt für Schritt zum Java Master.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if streak > 0 {
                Chip(text: "\(streak)", systemImage: "flame.fill", tint: Theme.orange)
                    .font(.headline)
                    .accessibilityLabel(Text("Serie: \(streak) Tage"))
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Übersicht") {
    NavigationStack { DashboardView() }
        .environment(PreviewSupport.makeStore())
        .environment(AppRouter())
}
#endif
