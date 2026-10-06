import SwiftUI
import JavaQuestKit

/// Level, XP und alle Abzeichen – freigeschaltete in Farbe, die übrigen mit Fortschritt.
struct AchievementsView: View {
    @Environment(ProgressStore.self) private var store
    @State private var width: CGFloat = 400

    var body: some View {
        let facts = store.facts
        let unlocked = Achievement.unlocked(facts)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LevelCard(progress: store.levelProgress, unlockedCount: unlocked.count)
                SectionTitle(title: "Abzeichen", subtitle: "\(unlocked.count) von \(Achievement.all.count) freigeschaltet", systemImage: "rosette")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: width >= 760 ? 220 : 150), spacing: 12)], spacing: 12) {
                    // Freigeschaltete zuerst, dann die, denen am wenigsten fehlt.
                    ForEach(sorted(facts, unlocked: unlocked)) { achievement in
                        AchievementTile(achievement: achievement, current: achievement.current(facts), isUnlocked: unlocked.contains(achievement.id))
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
        .navigationTitle("Abzeichen")
    }

    private func sorted(_ facts: LearnerFacts, unlocked: Set<String>) -> [Achievement] {
        Achievement.all.sorted { a, b in
            let ua = unlocked.contains(a.id), ub = unlocked.contains(b.id)
            if ua != ub { return ua }
            let pa = Double(a.current(facts)) / Double(a.target), pb = Double(b.current(facts)) / Double(b.target)
            return pa > pb
        }
    }
}

/// XP-Fortschritt bis zum nächsten Level.
struct LevelCard: View {
    let progress: LevelProgress
    var unlockedCount: Int?
    /// Zeigt einen Link zur Abzeichen-Seite (im Dashboard).
    var showsLink = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    ProgressRing(progress: progress.fraction, lineWidth: 6, fill: AnyShapeStyle(Theme.accentGradient))
                    VStack(spacing: -2) {
                        Text("LVL").font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
                        Text("\(progress.level)").font(.system(.title2, design: .rounded).weight(.heavy)).monospacedDigit()
                    }
                }
                .frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(progress.level)").font(.title3.weight(.bold))
                    Text("\(progress.xp) XP · noch \(progress.remaining) bis Level \(progress.level + 1)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let unlockedCount {
                        Label("\(unlockedCount) von \(Achievement.all.count) Abzeichen", systemImage: "rosette")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.orange)
                    }
                }
                Spacer(minLength: 0)
                if showsLink {
                    NavigationLink("Abzeichen") { AchievementsView() }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.orange)
                }
            }
            ProgressBar(value: progress.fraction, height: 8)
            Text("XP gibt es für jede gelöste Aufgabe (beim ersten Versuch doppelt), für Sterne in der Arena, abgeschlossene Lektionen und die Tagesmission.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

private struct AchievementTile: View {
    let achievement: Achievement
    let current: Int
    let isUnlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                IconTile(systemImage: achievement.symbolName, tint: isUnlocked ? Theme.orange : .gray, size: 48)
                    .saturation(isUnlocked ? 1 : 0)
                    .opacity(isUnlocked ? 1 : 0.5)
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.gray, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }
            Text(achievement.title).font(.headline)
            Text(achievement.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if isUnlocked {
                Label("Freigeschaltet", systemImage: "checkmark.seal.fill").font(.caption.weight(.semibold)).foregroundStyle(Theme.success)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressBar(value: Double(current) / Double(achievement.target), height: 5)
                    Text("\(current) / \(achievement.target)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .card(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(isUnlocked ? "freigeschaltet" : "\(current) von \(achievement.target)"))
    }
}

#if DEBUG
#Preview("Abzeichen") {
    NavigationStack { AchievementsView() }
        .environment(PreviewSupport.makeStore())
}
#endif
