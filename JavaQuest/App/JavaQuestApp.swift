import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct JavaQuestApp: App {
    @State private var app = AppModel()

    init() {
        #if os(macOS)
        // Ein Fenster, keine Tabs: Ein zweites Fenster teilte sich denselben Lernzustand und spränge mit.
        NSWindow.allowsAutomaticWindowTabbing = false
        #endif
    }

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
        .commands {
            LearningCommands(app: app)
            CodeCommands()
            CommandGroup(replacing: .newItem) {}
            // Ohne „Neues Fenster“ fiele das Menü „Ablage“ samt ⌘W weg – Schließen bleibt.
            CommandGroup(replacing: .saveItem) {
                Button("Fenster schließen") { NSApp.keyWindow?.performClose(nil) }
                    .keyboardShortcut("w", modifiers: .command)
            }
        }
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
            Button("Tagesmission starten") { app.startDailyMission() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(!app.canStartDailyMission)
            Divider()
            Button("Übersicht") { app.router.selection = .dashboard }
                .keyboardShortcut("1", modifiers: .command)
            Button("Lernpfad") { app.router.selection = .path }
                .keyboardShortcut("2", modifiers: .command)
            Button("Wissensanalyse") { app.router.selection = .analysis }
                .keyboardShortcut("3", modifiers: .command)
            Button("Arena") { app.router.selection = .arena }
                .keyboardShortcut("4", modifiers: .command)
            Button("Abzeichen") { app.router.selection = .achievements }
                .keyboardShortcut("5", modifiers: .command)
            Button("Code-Quests") { app.router.selection = .quests }
                .keyboardShortcut("6", modifiers: .command)
        }
    }
}

/// Menü „Code“ und Suchen unter „Bearbeiten“ – sie wirken auf den Editor, in dem man gerade schreibt
/// (über die Responder-Kette; ohne Editor im Fokus passiert nichts).
struct CodeCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Suchen …") { find(.showFindInterface) }
                .keyboardShortcut("f", modifiers: .command)
            Button("Suchen und Ersetzen …") { find(.showReplaceInterface) }
                .keyboardShortcut("f", modifiers: [.command, .option])
            Button("Weitersuchen") { find(.nextMatch) }
                .keyboardShortcut("g", modifiers: .command)
            Button("Rückwärts suchen") { find(.previousMatch) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
        }
        CommandMenu("Code") {
            Button("Einrücken") { send(#selector(CodeNSTextView.indentLines(_:))) }
                .keyboardShortcut("]", modifiers: .command)
            Button("Ausrücken") { send(#selector(CodeNSTextView.outdentLines(_:))) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Kommentar ein/aus") { send(#selector(CodeNSTextView.toggleLineComment(_:))) }
                .keyboardShortcut("/", modifiers: .command)
            Divider()
            Button("Schrift größer") { EditorStyle.changeFontSize(by: 1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Schrift kleiner") { EditorStyle.changeFontSize(by: -1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Originalgröße") { EditorStyle.resetFontSize() }
                .keyboardShortcut("0", modifiers: .command)
        }
    }

    private func send(_ action: Selector, tag: Int = 0) {
        let sender = NSMenuItem()
        sender.tag = tag
        NSApp.sendAction(action, to: nil, from: sender)
    }

    private func find(_ action: NSTextFinder.Action) {
        send(#selector(NSResponder.performTextFinderAction(_:)), tag: action.rawValue)
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
