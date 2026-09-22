import SwiftUI
import JavaQuestKit

struct SidebarView: View {
    @Binding var selection: AppSection?
    @Environment(ProgressStore.self) private var store

    var body: some View {
        List(selection: $selection) {
            Section("Lernen") {
                Label("Übersicht", systemImage: "square.grid.2x2.fill")
                    .tag(AppSection.dashboard)
                Label("Lernpfad", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .tag(AppSection.path)
                Label("Alle Themen", systemImage: "square.grid.3x3.fill")
                    .tag(AppSection.topics)
                Label("Meine Schwächen", systemImage: "arrow.counterclockwise")
                    .tag(AppSection.weakSpots)
                Label("Wissensanalyse", systemImage: "brain.head.profile")
                    .tag(AppSection.analysis)
            }

            Section("Module") {
                ForEach(Array(store.moduleProgress.enumerated()), id: \.element.id) { index, progress in
                    SidebarModuleRow(number: index + 1, progress: progress)
                        .tag(AppSection.module(progress.id))
                }
            }

            Section {
                Label("Profil", systemImage: "person.crop.circle")
                    .tag(AppSection.profile)
            }
        }
        .navigationTitle("JavaQuest")
        .safeAreaInset(edge: .bottom) {
            SidebarScoreFooter(score: store.masterScore, rank: store.rank, progress: store.progressToNextRank)
                .padding(12)
        }
    }
}

private struct SidebarModuleRow: View {
    let number: Int
    let progress: ModuleProgress

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: progress.fraction, lineWidth: 3, fill: AnyShapeStyle(Theme.color(for: progress.module.tier)))
                    .frame(width: 26, height: 26)
                Image(systemName: progress.isUnlocked ? progress.module.symbol : "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(progress.isUnlocked ? Theme.color(for: progress.module.tier) : .secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(progress.module.title).lineLimit(1)
                Text("Modul \(number) · \(progress.completedLessons)/\(progress.totalLessons)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(progress.isUnlocked ? 1 : 0.55)
    }
}

private struct SidebarScoreFooter: View {
    let score: Int
    let rank: MasterRank
    let progress: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: rank.symbolName)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.heroGradient, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(score)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(score)))
                    Text("Master Score").font(.caption).foregroundStyle(.secondary)
                }
                ProgressBar(value: progress, height: 5)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Java Master Score \(score), Rang \(rank.title)"))
    }
}
