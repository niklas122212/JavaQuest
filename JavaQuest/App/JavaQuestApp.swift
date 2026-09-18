import SwiftUI

@main
struct JavaQuestApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                #if os(macOS)
                .frame(minWidth: 920, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 820)
        .windowResizability(.contentMinSize)
        .commands { LearningCommands(app: app) }
        #endif

        #if os(macOS)
        Settings {
            SettingsRoot()
                .environment(app)
                .frame(width: 520, height: 560)
        }
        #endif
    }
}

#if os(macOS)
/// Menü „Lernen“ mit Tastaturkürzeln für die Mac-App.
struct LearningCommands: Commands {
    let app: AppModel

    var body: some Commands {
        CommandMenu("Lernen") {
            Button("Nächste Lektion starten") { app.startNextLesson() }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(!app.canStartNextLesson)
            Divider()
            Button("Übersicht") { app.router.selection = .dashboard }
                .keyboardShortcut("1", modifiers: .command)
            Button("Lernpfad") { app.router.selection = .path }
                .keyboardShortcut("2", modifiers: .command)
            Button("Wissensanalyse") { app.router.selection = .analysis }
                .keyboardShortcut("3", modifiers: .command)
        }
    }
}

private struct SettingsRoot: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if case .ready(let store) = app.state {
            ProfileView()
                .environment(store)
                .environment(app.router)
        }
    }
}
#endif
