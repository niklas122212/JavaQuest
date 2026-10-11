#if DEBUG && os(macOS)
import AppKit
import SwiftUI

/// `-snapshotPath <Name>` (nur Debug, nur mit `-inMemoryStore`): Nach einigen Sekunden (`-snapshotDelay`)
/// landen die Fenster als PNG im temporären Ordner der App – wegen der Sandbox unter
/// `~/Library/Containers/<App>/Data/tmp/<Name>-1.png`. Für Prüfungen ohne Bildschirmaufnahme.
/// Gibt es kein Fenster (Sitzung ohne Anzeige), zeichnet es die laufende Sitzung in einem unsichtbaren Fenster.
/// `-typeText "…"` tippt vorher in den ersten Code-Editor (`\n` = Enter, `\t` = Tab).
@MainActor
enum DebugSnapshot {
    static func start(name: String, app: AppModel, store: ProgressStore) {
        let delay = UserDefaults.standard.double(forKey: "snapshotDelay")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay > 0 ? delay : 6))
            var windows = NSApp.windows.filter { $0.contentView != nil && $0.frame.width > 200 }
            if windows.isEmpty {
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
                window.contentView = NSHostingView(rootView: content(app: app, store: store).frame(width: 1300, height: 900))
                window.orderBack(nil)
                // Zeit für Layout, Testläufe (-autoRun) und die Prüfung beim Tippen.
                try? await Task.sleep(for: .seconds(delay > 0 ? delay : 6))
                windows = [window]
            }
            if let typed = UserDefaults.standard.string(forKey: "typeText"), let window = windows.first,
               let textView = window.contentView.flatMap(firstTextView) {
                // Wie auf der Tastatur: Zeichen für Zeichen, Enter und Tab über die Befehle von NSTextView.
                window.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
                for character in typed.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\t", with: "\t") {
                    switch character {
                    case "\n": textView.insertNewline(nil)
                    case "\t": textView.insertTab(nil)
                    default: textView.insertText(String(character), replacementRange: textView.selectedRange())
                    }
                }
                try? await Task.sleep(for: .seconds(1))
            }
            for (index, window) in windows.enumerated() {
                guard let view = window.contentView else { continue }
                view.layoutSubtreeIfNeeded()
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: rep)
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name)-\(index + 1).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
                NSLog("JavaQuest-Snapshot: %@", url.path)
            }
        }
    }

    private static func firstTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView, textView.isEditable { return textView }
        for subview in view.subviews {
            if let found = firstTextView(in: subview) { return found }
        }
        return nil
    }

    @ViewBuilder
    private static func content(app: AppModel, store: ProgressStore) -> some View {
        switch app.router.activeSession?.kind {
        case .quest(let id)?:
            QuestSessionContainer(questId: id).environment(store).environment(app.router)
        case .workshop?:
            WorkshopContainer().environment(store).environment(app.router)
        default:
            RootView().environment(app)
        }
    }
}
#endif

#if DEBUG && os(iOS)
import UIKit

/// `-typeText "…"` (nur Debug, nur mit `-inMemoryStore`): tippt nach `-snapshotDelay` Sekunden in den ersten
/// Code-Editor – wie über die Tastatur, mit `\n` als Enter und `\t` als Tab. Für Prüfungen im Simulator.
@MainActor
enum DebugTyping {
    static func start() {
        guard let typed = UserDefaults.standard.string(forKey: "typeText") else { return }
        let delay = UserDefaults.standard.double(forKey: "snapshotDelay")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay > 0 ? delay : 6))
            let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            guard let textView = windows.lazy.compactMap({ firstTextView(in: $0) }).first else { return }
            textView.becomeFirstResponder()
            textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
            for character in typed.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\t", with: "\t") {
                textView.smartInput?(String(character))
            }
        }
    }

    private static func firstTextView(in view: UIView) -> CodeTextView? {
        if let textView = view as? CodeTextView { return textView }
        for subview in view.subviews {
            if let found = firstTextView(in: subview) { return found }
        }
        return nil
    }
}
#endif
