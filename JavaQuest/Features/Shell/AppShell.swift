import SwiftUI
import JavaQuestKit

/// Adaptive Hauptnavigation:
/// - iPhone (kompakte Breite): Tab-Leiste
/// - iPad und Mac: Sidebar-Layout mit NavigationSplitView
struct AppShell: View {
    @Environment(AppRouter.self) private var router
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        @Bindable var router = router
        Group {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                CompactShell()
            } else {
                SplitShell()
            }
            #else
            SplitShell()
            #endif
        }
        .modifier(SessionPresenter(request: $router.activeSession))
    }
}

/// Zeigt Lektionen auf iOS im Vollbild (Fokus!), auf dem Mac als großes Sheet.
private struct SessionPresenter: ViewModifier {
    @Binding var request: SessionRequest?
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(item: $request) { request in
            flow(for: request)
        }
        #else
        content.sheet(item: $request) { request in
            flow(for: request)
                .frame(minWidth: 780, idealWidth: 980, minHeight: 660, idealHeight: 800)
        }
        #endif
    }

    private func flow(for request: SessionRequest) -> some View {
        // Neue Identität je Anfrage: „Lektion wiederholen“ und „Nächste Lektion“
        // ersetzen die laufende Sitzung, statt das alte Modell weiterzuverwenden.
        Group {
            switch request.kind {
            case .mission, .playground:
                ArenaSessionContainer(request: request)
            case .lesson, .practice, .training, .free, .weakSpots, .review:
                LessonFlowContainer(request: request)
            }
        }
        .id(request.id)
        .environment(store)
        .environment(router)
        .tint(Theme.orange)
    }
}

private struct SplitShell: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            SidebarView(selection: $router.selection)
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 340)
        } detail: {
            NavigationStack {
                SectionScreen(section: router.selection ?? .dashboard)
            }
            .id(router.selection)
        }
    }
}

private struct CompactShell: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selection) {
            tab(.dashboard, title: "Übersicht", systemImage: "square.grid.2x2.fill")
            tab(.path, title: "Lernpfad", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
            tab(.topics, title: "Themen", systemImage: "square.grid.3x3.fill")
            tab(.analysis, title: "Analyse", systemImage: "brain.head.profile")
            tab(.profile, title: "Profil", systemImage: "person.crop.circle")
        }
        .onChange(of: router.selection) { _, newValue in normalize(newValue) }
        // Auch beim Wechsel aus dem Sidebar-Layout (iPad wird schmal) – sonst bliebe kein Tab ausgewählt.
        .onAppear { normalize(router.selection) }
    }

    private func normalize(_ selection: AppSection?) {
        // Modul-Auswahl aus dem Sidebar-Layout gibt es auf dem iPhone nicht als Tab.
        if case .module? = selection { router.selection = .path }
        // „Meine Schwächen“, Arena und Abzeichen sind auf dem iPhone keine Tabs, sondern hängen an der Übersicht.
        if selection == .weakSpots || selection == .arena || selection == .achievements { router.selection = .dashboard }
    }

    private func tab(_ section: AppSection, title: LocalizedStringKey, systemImage: String) -> some View {
        NavigationStack { SectionScreen(section: section) }
            .tabItem { Label(title, systemImage: systemImage) }
            .tag(Optional(section))
    }
}

struct SectionScreen: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .dashboard: DashboardView()
        case .path: LearningPathView()
        case .topics: TopicCatalogView()
        case .weakSpots: WeakSpotsView()
        case .arena: ArenaHomeView()
        case .achievements: AchievementsView()
        case .analysis: KnowledgeAnalysisView()
        case .profile: ProfileView()
        case .module(let id): LearningPathView(focusModuleId: id)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("App") {
    AppShell()
        .environment(PreviewSupport.makeStore())
        .environment(AppRouter())
}
#endif
