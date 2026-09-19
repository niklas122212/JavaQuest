import Foundation
import SwiftData
import JavaQuestKit

// SwiftData-Modelle für den Lernfortschritt. Alle Eigenschaften haben Standardwerte
// und alle Beziehungen sind optional – damit bleibt das Schema kompatibel zu einer
// späteren iCloud-Synchronisierung (CloudKit verlangt genau das).
// Enums werden als String gespeichert und über berechnete Eigenschaften gelesen.

/// Die lernende Person. Es gibt genau ein Profil pro Gerät.
@Model
final class LearnerProfile {
    var createdAt: Date = Date.now
    var experienceLevelRaw: String = ExperienceLevel.beginner.rawValue
    var placedLevelRaw: String? = nil
    var placementScore: Int? = nil
    var onboardingCompleted: Bool = false
    /// Zwischengespeicherter Java Master Score (Quelle der Wahrheit sind die LessonRecords).
    var masterScore: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDay: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \LessonRecord.profile)
    var lessonRecords: [LessonRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \TopicMastery.profile)
    var topicMasteries: [TopicMastery]? = []

    @Relationship(deleteRule: .cascade, inverse: \TaskAttempt.profile)
    var attempts: [TaskAttempt]? = []

    @Relationship(deleteRule: .cascade, inverse: \ScoreSnapshot.profile)
    var scoreHistory: [ScoreSnapshot]? = []

    init(experienceLevel: ExperienceLevel) {
        self.experienceLevelRaw = experienceLevel.rawValue
    }
}

/// Bestwert und Status einer Lektion.
@Model
final class LessonRecord {
    var lessonId: String = ""
    var bestAccuracy: Double = 0
    var lastAccuracy: Double = 0
    var playCount: Int = 0
    var isCompleted: Bool = false
    var completedViaPlacement: Bool = false
    var firstCompletedAt: Date? = nil
    var lastPlayedAt: Date? = nil
    var profile: LearnerProfile? = nil

    init(lessonId: String) {
        self.lessonId = lessonId
    }
}

/// Aggregierte Leistung je Thema – Grundlage der Wissenslücken-Analyse.
@Model
final class TopicMastery {
    var topicId: String = ""
    var attempts: Int = 0
    var firstTryCorrect: Int = 0
    var weightedCorrect: Double = 0
    var weightedTotal: Double = 0
    var lastPracticedAt: Date? = nil
    var profile: LearnerProfile? = nil

    init(topicId: String) {
        self.topicId = topicId
    }
}

/// Protokoll jeder abgeschlossenen Aufgabe (Lektion, Übung oder Einstufung).
@Model
final class TaskAttempt {
    var taskId: String = ""
    var topicId: String = ""
    var lessonId: String? = nil
    var contextRaw: String = AttemptContext.lesson.rawValue
    var difficulty: Int = 1
    var credit: Double = 0
    var solved: Bool = false
    var tries: Int = 0
    var date: Date = Date.now
    var profile: LearnerProfile? = nil

    init(taskId: String, topicId: String, lessonId: String?, context: AttemptContext, difficulty: Int, credit: Double, solved: Bool, tries: Int) {
        self.taskId = taskId
        self.topicId = topicId
        self.lessonId = lessonId
        self.contextRaw = context.rawValue
        self.difficulty = difficulty
        self.credit = credit
        self.solved = solved
        self.tries = tries
    }
}

/// Verlauf des Java Master Scores für die Sparkline im Dashboard.
@Model
final class ScoreSnapshot {
    var date: Date = Date.now
    var score: Int = 0
    var reason: String = ""
    var profile: LearnerProfile? = nil

    init(score: Int, reason: String) {
        self.score = score
        self.reason = reason
    }
}

enum AttemptContext: String, Sendable {
    case lesson
    case practice
    case training
    case placement
}

extension LearnerProfile {
    var experienceLevel: ExperienceLevel { ExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner }
    var placedLevel: ExperienceLevel? { placedLevelRaw.flatMap(ExperienceLevel.init(rawValue:)) }
}

extension TopicMastery {
    var stats: TopicStats {
        TopicStats(attempts: attempts, weightedCorrect: weightedCorrect, weightedTotal: weightedTotal, lastPracticed: lastPracticedAt)
    }
}
