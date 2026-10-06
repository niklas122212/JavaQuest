import SwiftUI
import JavaQuestKit

/// Arena-Übersicht: Tagesmission, Spielplatz und alle Missionen nach Modul.
struct ArenaHomeView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var width: CGFloat = 400

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ArenaHero(stars: totalStars, maxStars: store.catalog.missions.count * 3)
                if width >= 760 {
                    HStack(alignment: .top, spacing: 16) {
                        DailyMissionCard()
                        PlaygroundCard { router.openPlayground() }
                    }
                } else {
                    DailyMissionCard()
                    PlaygroundCard { router.openPlayground() }
                }
                ForEach(store.course.modules) { module in
                    let missions = missions(in: module)
                    if !missions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: module.title, subtitle: module.subtitle, systemImage: module.symbol)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                                ForEach(missions) { mission in
                                    MissionRow(mission: mission, stars: store.missionStars[mission.id] ?? 0, isUnlocked: store.isUnlocked(mission), lockReason: lockReason(mission)) {
                                        router.startMission(mission.id)
                                    }
                                }
                            }
                        }
                    }
                }
                RobotCommandReference()
            }
            .padding(.horizontal, width >= 760 ? 28 : 16)
            .padding(.vertical, 20)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Theme.screenBackground)
        .navigationTitle("Arena")
    }

    private var totalStars: Int { store.missionStars.values.reduce(0, +) }

    /// Missionen eines Moduls: Lektionen der Reihe nach, Boss am Ende.
    private func missions(in module: CourseModule) -> [ArenaMission] {
        let lessonIds = module.lessons.map(\.id)
        let order: [ArenaMission.Kind: Int] = [.lesson: 0, .training: 1, .boss: 2]
        return store.catalog.missions
            .filter { $0.kind == .boss ? $0.moduleId == module.id : lessonIds.contains($0.lessonId) && $0.kind != .boss }
            .sorted {
                ($0.kind == .boss ? 1 : 0, lessonIds.firstIndex(of: $0.lessonId) ?? 99, order[$0.kind] ?? 0)
                    < ($1.kind == .boss ? 1 : 0, lessonIds.firstIndex(of: $1.lessonId) ?? 99, order[$1.kind] ?? 0)
            }
    }

    private func lockReason(_ mission: ArenaMission) -> String {
        let lesson = store.course.lesson(id: mission.lessonId)?.title ?? mission.lessonId
        switch mission.kind {
        case .lesson: return "Erreiche die Lektion „\(lesson)“"
        case .training: return "Schließe „\(lesson)“ ab"
        case .boss: return "Schließe das ganze Modul ab"
        }
    }
}

private struct ArenaHero: View {
    let stars: Int
    let maxStars: Int

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RobotView(size: 64)
                .padding(8)
                .background(.white.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text("Die Arena").font(.title.weight(.heavy))
                Text("Steuere Byte mit echtem Java-Code: Jede Zeile, die du schreibst, wird wirklich ausgeführt – und du siehst sofort, was sie bewirkt.")
                    .font(.subheadline)
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                Label("\(stars) von \(maxStars) Sternen", systemImage: "star.fill")
                    .font(.subheadline.weight(.bold))
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(LinearGradient(colors: [ArenaColors.board, Theme.indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// Die Mission des Tages – auf dem Dashboard und in der Arena.
struct DailyMissionCard: View {
    /// In der Übersicht zeigt die Karte zusätzlich den Weg in die Arena.
    var showsArenaLink = false
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(systemImage: "sun.max.fill", tint: Theme.orange, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TAGESMISSION").font(.caption.weight(.heavy)).tracking(1.1).foregroundStyle(Theme.orange)
                    Text("+\(Experience.pointsPerDaily) XP Bonus · hält deine Serie am Leben").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if store.isDailyMissionDone {
                    Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Theme.success)
                }
                if showsArenaLink {
                    // Auf dem iPhone ist die Arena kein eigener Tab – hier geht es hinein.
                    NavigationLink { ArenaHomeView() } label: {
                        Label("Arena", systemImage: "gamecontroller.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.indigo)
                }
            }
            if let mission = store.dailyMission {
                Text(mission.title).font(.title3.weight(.bold))
                Text(mission.story).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                if store.isDailyMissionDone {
                    Label("Für heute geschafft – morgen wartet eine neue Mission.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.success)
                } else {
                    Button { router.startMission(mission.id) } label: {
                        Label("Mission starten", systemImage: "gamecontroller.fill")
                    }
                    .buttonStyle(.primary)
                }
            } else {
                Text("Starte die erste Lektion – danach wartet hier jeden Tag eine Mission auf dich.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

private struct PlaygroundCard: View {
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(systemImage: "sparkles", tint: Theme.teal, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPIELPLATZ").font(.caption.weight(.heavy)).tracking(1.1).foregroundStyle(Theme.teal)
                    Text("Ohne Ziel, ohne Bewertung").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Freies Ausprobieren").font(.title3.weight(.bold))
            Text("Eine offene Welt mit Münzen und Mauern: Teste Schleifen, Methoden und Ideen, ganz ohne Druck.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onOpen) {
                Label("Spielplatz öffnen", systemImage: "play.fill")
            }
            .buttonStyle(SecondaryButtonStyle(tint: Theme.teal))
        }
        .card()
    }
}

private struct MissionRow: View {
    let mission: ArenaMission
    let stars: Int
    let isUnlocked: Bool
    let lockReason: String
    let onStart: () -> Void

    private var style: (symbol: String, tint: Color, label: String) {
        switch mission.kind {
        case .lesson: ("gamecontroller.fill", Theme.indigo, "Mission")
        case .training: ("dumbbell.fill", Theme.violet, "Training")
        case .boss: ("shield.lefthalf.filled", Theme.ember, "Boss")
        }
    }

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 12) {
                IconTile(systemImage: isUnlocked ? style.symbol : "lock.fill", tint: isUnlocked ? style.tint : .gray, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(style.label.uppercased()).font(.caption2.weight(.heavy)).foregroundStyle(style.tint)
                        if mission.worlds.count > 1 {
                            Text("· \(mission.worlds.count) Welten").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                    Text(mission.title).font(.headline).foregroundStyle(.primary)
                    if isUnlocked {
                        StarsView(count: stars, size: 13)
                    } else {
                        Text(lockReason).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .card(padding: 14)
            .opacity(isUnlocked ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }
}

/// Alle Befehle von Byte auf einen Blick.
private struct RobotCommandReference: View {
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(RobotCommand.all) { command in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(command.call)
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        Spacer(minLength: 8)
                        Text(command.summary).font(.subheadline).foregroundStyle(.secondary)
                        Text(command.returnType)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.fieldBackground, in: Capsule())
                    }
                }
                Text("Befehle mit void tun etwas. Befehle mit boolean beantworten eine Frage mit true oder false – perfekt für if und while. robot.coins() liefert eine Zahl (int).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.top, 10)
        } label: {
            Label("Was Byte alles kann", systemImage: "list.bullet.rectangle.portrait.fill")
                .font(.headline)
        }
        .tint(Theme.orange)
        .card()
    }
}

// MARK: - Sitzung (Vollbild bzw. Sheet)

/// Eine Mission oder der Spielplatz außerhalb einer Lektion.
struct ArenaSessionContainer: View {
    let request: SessionRequest
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var model: ArenaMissionModel?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Theme.fieldBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(Text("Schließen"))
                Text(model?.mission.title ?? "Arena").font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            if let model {
                ArenaMissionView(model: model, context: .standalone(onClose: { dismiss() }, onNext: nextMission(after: model).map { next in
                    { router.startMission(next.id) }
                }))
            } else {
                ContentUnavailableView("Mission nicht gefunden", systemImage: "questionmark.circle")
            }
        }
        .background(Theme.screenBackground)
        .onAppear {
            guard model == nil else { return }
            switch request.kind {
            case .mission(let id):
                if let mission = store.catalog.mission(id: id) { model = ArenaMissionModel(mission: mission, store: store) }
            case .playground:
                model = ArenaMissionModel(mission: .playground(store.catalog.playground), store: store, isPlayground: true)
            default:
                break
            }
        }
    }
}

extension ArenaSessionContainer {
    /// Die nächste freigeschaltete Mission ohne volle Sterne – in Katalog-Reihenfolge nach der aktuellen.
    func nextMission(after model: ArenaMissionModel) -> ArenaMission? {
        guard !model.isPlayground else { return nil }
        let missions = store.catalog.missions
        let start = (missions.firstIndex { $0.id == model.mission.id } ?? -1) + 1
        let ordered = Array(missions[start...]) + Array(missions[..<max(start - 1, 0)])
        return ordered.first { store.isUnlocked($0) && (store.missionStars[$0.id] ?? 0) < 3 && $0.id != model.mission.id }
    }
}

#if DEBUG
#Preview("Arena") {
    NavigationStack { ArenaHomeView() }
        .environment(PreviewSupport.makeStore())
        .environment(AppRouter())
}

#Preview("Mission") {
    let store = PreviewSupport.makeStore()
    ArenaSessionContainer(request: SessionRequest(kind: .mission("b2-labyrinth")))
        .environment(store)
}
#endif
