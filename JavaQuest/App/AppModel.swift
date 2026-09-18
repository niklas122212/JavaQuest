import Foundation
import Observation
import SwiftData
import JavaQuestKit

/// Startet die App: lädt den gebündelten Kurs und öffnet den lokalen Speicher.
@MainActor
@Observable
final class AppModel {
    enum State {
        case ready(ProgressStore)
        case failed(String)
    }

    private(set) var state: State = .failed("")
    let router = AppRouter()
    private let inMemory: Bool

    /// Mit dem Startargument `-inMemoryStore` (UI-Tests, Screenshots) wird nichts dauerhaft gespeichert.
    init(inMemory: Bool = ProcessInfo.processInfo.arguments.contains("-inMemoryStore")) {
        self.inMemory = inMemory
        load()
    }

    func load() {
        do {
            let course = try CourseLoader.loadBundled()
            #if DEBUG
            let issues = CourseValidator.validate(course)
            assert(issues.isEmpty, "Kursdatei fehlerhaft:\n" + issues.map(\.description).joined(separator: "\n"))
            #endif
            let container = try PersistenceController.makeContainer(inMemory: inMemory)
            state = .ready(ProgressStore(course: course, container: container))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func resetStoreAndReload() {
        try? PersistenceController.destroyPersistentStore()
        load()
    }

    var canStartNextLesson: Bool {
        guard case .ready(let store) = state else { return false }
        return !store.needsOnboarding && store.nextLesson != nil && router.activeSession == nil
    }

    func startNextLesson() {
        guard case .ready(let store) = state, let lesson = store.nextLesson else { return }
        router.startLesson(lesson.id)
    }
}

enum AppSection: Hashable {
    case dashboard
    case path
    case analysis
    case profile
    case module(String)
}

/// Eine laufende Lern-Sitzung, die als Vollbild bzw. Sheet angezeigt wird.
struct SessionRequest: Identifiable, Hashable {
    enum Kind: Hashable {
        case lesson(String)
        case practice(topicId: String)
    }

    let id = UUID()
    let kind: Kind
}

@MainActor
@Observable
final class AppRouter {
    var selection: AppSection? = .dashboard
    var activeSession: SessionRequest?

    func startLesson(_ lessonId: String) {
        activeSession = SessionRequest(kind: .lesson(lessonId))
    }

    func practice(topicId: String) {
        activeSession = SessionRequest(kind: .practice(topicId: topicId))
    }
}
