import Foundation

public enum LessonState: Sendable, Hashable {
    case locked
    case current
    case completed(stars: Int, viaPlacement: Bool)

    public var isPlayable: Bool { self != .locked }

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}

public struct ModuleProgress: Sendable, Hashable, Identifiable {
    public let module: CourseModule
    public let completedLessons: Int
    public let isUnlocked: Bool

    public var id: String { module.id }
    public var totalLessons: Int { module.lessons.count }
    public var fraction: Double { totalLessons > 0 ? Double(completedLessons) / Double(totalLessons) : 0 }
    public var isCompleted: Bool { completedLessons == totalLessons }
}

/// Linearer Lernpfad: Eine Lektion wird freigeschaltet, sobald die vorherige
/// abgeschlossen ist. Abgeschlossene Lektionen bleiben wiederholbar.
public enum LearningPath {
    public static func states(course: Course, results: [String: LessonResult]) -> [String: LessonState] {
        var states: [String: LessonState] = [:]
        var foundCurrent = false
        for lesson in course.allLessons {
            if let result = results[lesson.id], result.isCompleted {
                states[lesson.id] = .completed(stars: result.stars, viaPlacement: result.viaPlacement)
            } else if !foundCurrent {
                states[lesson.id] = .current
                foundCurrent = true
            } else {
                states[lesson.id] = .locked
            }
        }
        return states
    }

    public static func nextLesson(course: Course, results: [String: LessonResult]) -> Lesson? {
        course.allLessons.first { results[$0.id]?.isCompleted != true }
    }

    public static func moduleProgress(course: Course, results: [String: LessonResult]) -> [ModuleProgress] {
        let states = states(course: course, results: results)
        return course.modules.map { module in
            let completed = module.lessons.filter { results[$0.id]?.isCompleted == true }.count
            let unlocked = module.lessons.contains { states[$0.id]?.isPlayable == true }
            return ModuleProgress(module: module, completedLessons: completed, isUnlocked: unlocked)
        }
    }
}
