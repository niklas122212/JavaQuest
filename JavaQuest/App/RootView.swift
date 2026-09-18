import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        switch app.state {
        case .ready(let store):
            ContentRoot()
                .environment(store)
                .environment(app.router)
                .tint(Theme.orange)
        case .failed(let message):
            StartupErrorView(message: message) { app.resetStoreAndReload() }
        }
    }
}

/// Wechselt zwischen Onboarding und der eigentlichen App.
private struct ContentRoot: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        Group {
            if store.needsOnboarding {
                OnboardingFlowView()
                    .transition(.opacity)
            } else {
                AppShell()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: store.needsOnboarding)
    }
}

private struct StartupErrorView: View {
    let message: String
    let reset: () -> Void
    @State private var confirmReset = false

    var body: some View {
        ContentUnavailableView {
            Label("Speicher nicht verfügbar", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Der lokale Lernfortschritt konnte nicht geöffnet werden.\n\(message)")
        } actions: {
            Button("Speicher zurücksetzen", role: .destructive) { confirmReset = true }
        }
        .confirmationDialog("Alle Fortschritte löschen und neu starten?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive, action: reset)
        }
    }
}
