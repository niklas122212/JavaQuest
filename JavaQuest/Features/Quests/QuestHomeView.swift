import SwiftUI
import JavaQuestKit

/// Die Karte des Abenteuers: Kapitel mit ihren Quests, Inventar, Baupläne und die Werkstatt.
struct QuestHomeView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var width: CGFloat = 400

    private var isWide: Bool { width >= 760 }

    var body: some View {
        let progress = store.questProgress
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                QuestHeroCard(progress: progress) { router.startQuest($0.id) }
                ForEach(Array(progress.book.chapters.enumerated()), id: \.element.id) { index, chapter in
                    QuestChapterCard(number: index + 1, chapter: chapter, progress: progress) { router.startQuest($0.id) }
                }
                if isWide {
                    HStack(alignment: .top, spacing: 20) {
                        InventoryCard(progress: progress)
                        VStack(spacing: 20) {
                            WorkshopCard(progress: progress) { router.openWorkshop() }
                            BlueprintCard(progress: progress)
                        }
                    }
                } else {
                    WorkshopCard(progress: progress) { router.openWorkshop() }
                    InventoryCard(progress: progress)
                    BlueprintCard(progress: progress)
                }
            }
            .padding(.horizontal, isWide ? 28 : 16)
            .padding(.vertical, 20)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Theme.screenBackground)
        .navigationTitle("Code-Quests")
    }
}

private struct QuestHeroCard: View {
    let progress: QuestProgress
    let onStart: (CodeQuest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 26, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ABENTEUER").font(.caption.weight(.heavy)).tracking(1.2).opacity(0.85)
                    Text(progress.book.title).font(.title.weight(.bold))
                }
            }
            Text(progress.book.intro)
                .font(.subheadline)
                .opacity(0.92)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Label("\(progress.solvedCount)/\(progress.book.quests.count) Quests", systemImage: "flag.checkered")
                Label("\(progress.totalStars)/\(progress.maxStars)", systemImage: "star.fill")
                Label("\(progress.inventory.count) Gegenstände", systemImage: "bag.fill")
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())
            ProgressBar(value: Double(progress.solvedCount) / Double(max(progress.book.quests.count, 1)),
                        tint: AnyShapeStyle(Color.white), track: .white.opacity(0.25), height: 7)
            if let next = progress.nextQuest {
                Button { onStart(next) } label: {
                    Label(progress.solvedCount == 0 ? "Abenteuer beginnen: \(next.title)" : "Weiter: \(next.title)", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(fill: LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.18)], startPoint: .top, endPoint: .bottom)))
            } else if progress.solvedCount == progress.book.quests.count {
                Label("Javahall ist gerettet – alle Quests gelöst!", systemImage: "crown.fill").font(.headline)
            } else if let locked = progress.book.quests.first(where: { progress.stars[$0.id] == nil }),
                      case .locked(let reason) = progress.state(of: locked) {
                Label("Nächste Quest „\(locked.title)“ · \(reason)", systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

private struct QuestChapterCard: View {
    let number: Int
    let chapter: QuestChapter
    let progress: QuestProgress
    let onStart: (CodeQuest) -> Void

    var body: some View {
        let quests = progress.book.quests(in: chapter)
        let solved = progress.solvedCount(in: chapter)
        let isOpen = quests.contains { progress.state(of: $0).isPlayable }
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconTile(systemImage: isOpen ? chapter.symbol : "lock.fill", tint: solved == quests.count ? Theme.success : (isOpen ? Theme.violet : .gray), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kapitel \(number)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(chapter.title).font(.title3.weight(.bold))
                }
                Spacer()
                Text("\(solved)/\(quests.count)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(solved == quests.count ? Theme.success : .secondary)
            }
            Text(chapter.story)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                ForEach(quests) { quest in
                    QuestRow(quest: quest, state: progress.state(of: quest)) { onStart(quest) }
                }
            }
        }
        .card(padding: 18)
        .opacity(isOpen || solved > 0 ? 1 : 0.7)
    }
}

private struct QuestRow: View {
    let quest: CodeQuest
    let state: QuestProgress.State
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(quest.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Group {
                        if case .locked(let reason) = state {
                            Text(reason)
                        } else {
                            Text("Neu: \(quest.concept.title)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                switch state {
                case .solved(let stars): StarsView(count: stars, size: 13)
                case .open: Image(systemName: "chevron.right").foregroundStyle(Theme.orange)
                case .locked: EmptyView()
                }
            }
            .padding(12)
            .background(state == .open ? Theme.orange.opacity(0.1) : Theme.fieldBackground.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
            .overlay {
                if state == .open {
                    RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous).strokeBorder(Theme.orange.opacity(0.5), lineWidth: 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!state.isPlayable)
        .accessibilityHint(Text(state.isPlayable ? "Quest öffnen" : "Noch gesperrt"))
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .solved: IconTile(systemImage: quest.reward.symbol, tint: Theme.success, size: 34)
        case .open: IconTile(systemImage: "play.fill", tint: Theme.orange, size: 34)
        case .locked: IconTile(systemImage: "lock.fill", tint: .gray, size: 34)
        }
    }
}

private struct InventoryCard: View {
    let progress: QuestProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Inventar", subtitle: "Für jede gelöste Quest ein Gegenstand", systemImage: "bag.fill")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(progress.book.quests) { quest in
                    let owned = progress.stars[quest.id] != nil
                    VStack(spacing: 6) {
                        IconTile(systemImage: owned ? quest.reward.symbol : "questionmark", tint: owned ? Theme.orange : .gray.opacity(0.6), size: 40)
                        Text(owned ? quest.reward.item : "???")
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundStyle(owned ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .padding(8)
                    .background(Theme.fieldBackground.opacity(owned ? 0.7 : 0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .help(owned ? quest.reward.text : "Löse „\(quest.title)“")
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(owned ? "\(quest.reward.item): \(quest.reward.text)" : "Noch nicht gefunden"))
                }
            }
        }
        .card(padding: 18)
    }
}

private struct WorkshopCard: View {
    let progress: QuestProgress
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(systemImage: progress.isWorkshopUnlocked ? "hammer.fill" : "lock.fill", tint: progress.isWorkshopUnlocked ? Theme.teal : .gray, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WERKSTATT").font(.caption.weight(.heavy)).tracking(1.1).foregroundStyle(Theme.teal)
                    Text("Freies Bauen – eigene Java-Programme").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Schreib, was du willst: eigene Klassen, Schleifen, Spiele. Mit Konsole, Zusehen Schritt für Schritt und deinen Bauplänen zum Einfügen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if progress.isWorkshopUnlocked {
                Button(action: onOpen) {
                    Label("Werkstatt öffnen", systemImage: "hammer")
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.teal))
            } else {
                Label("Öffnet sich nach Kapitel 1 „\(progress.book.chapters.first?.title ?? "")“", systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 18)
    }
}

private struct BlueprintCard: View {
    let progress: QuestProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Baupläne", subtitle: "Code-Bausteine für sauberen Code – mit 3 Sternen", systemImage: "scroll.fill")
            ForEach(progress.book.quests.filter { $0.blueprint != nil }) { quest in
                if let blueprint = quest.blueprint {
                    let unlocked = progress.isBlueprintUnlocked(quest)
                    HStack(spacing: 10) {
                        Image(systemName: unlocked ? "scroll.fill" : "lock.fill")
                            .foregroundStyle(unlocked ? Theme.teal : .secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(blueprint.title).font(.subheadline.weight(.semibold))
                            Text(unlocked ? blueprint.text : "3 Sterne in „\(quest.title)“")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .opacity(unlocked ? 1 : 0.6)
                }
            }
        }
        .card(padding: 18)
    }
}

/// Kurzer Einstieg auf der Übersicht – auf dem iPhone auch der Weg zur Questkarte.
struct QuestDashboardCard: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let progress = store.questProgress
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(systemImage: "map.fill", tint: Theme.violet, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CODE-QUESTS").font(.caption.weight(.heavy)).tracking(1.1).foregroundStyle(Theme.violet)
                    Text("\(progress.book.title) · \(progress.solvedCount)/\(progress.book.quests.count)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                NavigationLink { QuestHomeView() } label: {
                    Label("Karte", systemImage: "map")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.indigo)
            }
            if let next = progress.nextQuest {
                Text(next.title).font(.title3.weight(.bold))
                Text(next.story).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                Button { router.startQuest(next.id) } label: {
                    Label("Quest starten", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(fill: LinearGradient(colors: [Theme.violet, Theme.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)))
            } else if progress.solvedCount == progress.book.quests.count {
                Label("Alle Quests gelöst – baue frei in der Werkstatt weiter.", systemImage: "crown.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.success)
            } else {
                Text("Die nächste Quest öffnet sich mit der nächsten Lektion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}
