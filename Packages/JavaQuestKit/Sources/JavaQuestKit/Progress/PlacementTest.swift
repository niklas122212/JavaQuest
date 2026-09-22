import Foundation

/// Adaptiver Einstufungstest.
///
/// Ablauf: Start auf `startDifficulty`. Nach einer richtigen Antwort steigt das
/// Zielniveau um 1, nach einer falschen sinkt es um 1. Gewählt wird jeweils die
/// noch ungestellte Frage mit dem Niveau, das am nächsten am Ziel liegt.
///
/// Score (0–100 %): Σ(Niveau × Teilpunkte) / Σ(Niveau) über alle gestellten Fragen.
/// Schwere Fragen zählen also mehr. Daraus folgt eine von drei Einstufungen:
/// unter `passThreshold` (65 %) der Grundkurs, darüber der Einstieg bei den Objekten,
/// ab `advancedThreshold` (85 %) der Sprung in den fortgeschrittenen Teil.
public struct PlacementTest: Sendable {
    public struct Answer: Sendable, Hashable {
        public let task: LearningTask
        public let result: EvaluationResult
    }

    public let level: ExperienceLevel
    public let questionCount: Int
    public let passThreshold: Int
    public let advancedThreshold: Int
    public private(set) var answers: [Answer] = []
    public private(set) var currentTask: LearningTask?
    public private(set) var targetDifficulty: Int

    private var remaining: [LearningTask]

    public init?(course: Course, level: ExperienceLevel) {
        let pool = course.placement.pool(for: level)
        guard level.requiresPlacement, !pool.isEmpty else { return nil }
        self.level = level
        self.questionCount = min(course.placement.questionsPerTest, pool.count)
        self.passThreshold = course.placement.passThreshold
        self.advancedThreshold = course.placement.advancedThreshold
        self.targetDifficulty = Difficulty.clamped(course.placement.startDifficulty).rawValue
        self.remaining = pool
        self.currentTask = nil
        self.currentTask = pickNext()
    }

    public var isFinished: Bool { currentTask == nil }

    /// Fortschritt 0…1 für die Anzeige.
    public var progress: Double { Double(answers.count) / Double(max(questionCount, 1)) }

    public var scorePercent: Int {
        let asked = answers.reduce(0.0) { $0 + $1.task.difficulty.weight }
        guard asked > 0 else { return 0 }
        let earned = answers.reduce(0.0) { $0 + $1.task.difficulty.weight * $1.result.score }
        return Int((earned / asked * 100).rounded())
    }

    public var passed: Bool { scorePercent >= passThreshold }

    public mutating func submit(_ result: EvaluationResult) {
        guard let task = currentTask else { return }
        answers.append(Answer(task: task, result: result))
        let step = result.isCorrect ? 1 : -1
        targetDifficulty = Difficulty.clamped(task.difficulty.rawValue + step).rawValue
        currentTask = answers.count < questionCount ? pickNext() : nil
    }

    private mutating func pickNext() -> LearningTask? {
        let askedTopics = Set(answers.map(\.task.topicId))
        let target = targetDifficulty
        let best = remaining.enumerated().min { lhs, rhs in
            let lhsDistance = abs(lhs.element.difficulty.rawValue - target)
            let rhsDistance = abs(rhs.element.difficulty.rawValue - target)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            // Bei gleichem Abstand: lieber ein Thema, das noch nicht abgefragt wurde.
            let lhsNew = !askedTopics.contains(lhs.element.topicId)
            let rhsNew = !askedTopics.contains(rhs.element.topicId)
            if lhsNew != rhsNew { return lhsNew }
            return lhs.offset < rhs.offset
        }
        guard let best else { return nil }
        remaining.remove(at: best.offset)
        return best.element
    }

    /// Die Stufe, in die das Ergebnis führt – drei Möglichkeiten statt bestanden/durchgefallen.
    public var placedLevel: ExperienceLevel {
        if scorePercent >= advancedThreshold { return .advanced }
        return scorePercent >= passThreshold ? level : level.fallback
    }

    public func outcome(in course: Course) -> PlacementOutcome {
        let score = scorePercent
        let placedLevel = self.placedLevel
        let entryModule = course.entryModule(for: placedLevel) ?? course.modules[0]
        let entryIndex = course.modules.firstIndex { $0.id == entryModule.id } ?? 0
        let skipped = course.modules.prefix(entryIndex).flatMap(\.lessons).map(\.id)
        // Übersprungene Lektionen zählen mit dem Testergebnis, mindestens mit der Schwelle.
        let credit = Double(max(score, passThreshold)) / 100
        return PlacementOutcome(
            chosenLevel: level,
            scorePercent: score,
            passed: score >= passThreshold,
            placedLevel: placedLevel,
            entryModuleId: entryModule.id,
            creditedLessonIds: skipped,
            creditedAccuracy: credit
        )
    }
}

public struct PlacementOutcome: Sendable, Hashable {
    public let chosenLevel: ExperienceLevel
    public let scorePercent: Int
    public let passed: Bool
    public let placedLevel: ExperienceLevel
    public let entryModuleId: String
    public let creditedLessonIds: [String]
    public let creditedAccuracy: Double
}
