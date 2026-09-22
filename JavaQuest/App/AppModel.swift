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
    case topics
    case weakSpots
    case analysis
    case profile
    case module(String)
}

/// Eine laufende Lern-Sitzung, die als Vollbild bzw. Sheet angezeigt wird.
struct SessionRequest: Identifiable, Hashable {
    enum Kind: Hashable {
        case lesson(String)
        case practice(topicId: String)
        case training
        /// Freies Training: selbst gewählte Themen, Niveaus und Aufgabenzahl.
        case free(topicIds: [String], difficulties: [Int], count: Int)
        /// Nur das üben, was zuletzt nicht saß.
        case weakSpots(count: Int)
        /// Wiederholung: Lernziele, deren Pause abgelaufen ist.
        case review(count: Int)
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

    /// Startet eine neue Runde Endlos-Training (auch direkt aus der Auswertung heraus).
    func train() {
        activeSession = SessionRequest(kind: .training)
    }

    /// Übt gezielt die Lernziele, die zuletzt nicht saßen.
    func trainWeakSpots(count: Int = TrainingBuilder.roundSize) {
        activeSession = SessionRequest(kind: .weakSpots(count: count))
    }

    /// Startet die fällige Wiederholung – das, was sonst langsam verblasst.
    func review(count: Int = TrainingBuilder.roundSize) {
        activeSession = SessionRequest(kind: .review(count: count))
    }

    /// Startet eine selbst zusammengestellte Übungsrunde aus dem freien Lernen.
    func train(topicIds: Set<String>, difficulties: Set<Difficulty>, count: Int) {
        activeSession = SessionRequest(kind: .free(
            topicIds: topicIds.sorted(),
            difficulties: difficulties.map(\.rawValue).sorted(),
            count: count
        ))
    }
}
