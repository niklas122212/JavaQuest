import Foundation

/// Zustandsautomat für den Lern-Loop einer Lektion:
/// Theorie-Happen → Aufgaben (Niveau aufsteigend) → Auswertung.
///
/// Wertung pro Aufgabe: beim ersten Versuch gelöst = 100 %, später gelöst = 50 %,
/// Lösung angezeigt = 0 %.
public struct LessonSession: Sendable {
    public enum Mode: Sendable, Hashable {
        case lesson(lessonId: String)
        case practice(topicId: String)
        /// Endlos-Training: gemischte Runde über alle abgeschlossenen Lektionen.
        case training
    }

    public enum Phase: Sendable, Hashable {
        case theory(page: Int)
        case task(index: Int)
        case summary
    }

    public static let maxAttempts = 3
    /// Eine Lektion gilt ab 90 % (gewichtete Trefferquote) als bestanden.
    public static let passThreshold = 0.9

    public let mode: Mode
    public let title: String
    public let theory: [TheoryCard]
    public let tasks: [LearningTask]
    public private(set) var phase: Phase
    public private(set) var outcomes: [TaskOutcome] = []
    public private(set) var attempts = 0
    public private(set) var lastResult: EvaluationResult?
    public private(set) var isRevealed = false

    public init(lesson: Lesson) {
        self.init(mode: .lesson(lessonId: lesson.id), title: lesson.title, theory: lesson.theory, tasks: lesson.tasks)
    }

    public init(mode: Mode, title: String, theory: [TheoryCard], tasks: [LearningTask]) {
        self.mode = mode
        self.title = title
        self.theory = theory
        self.tasks = tasks.sorted { $0.difficulty < $1.difficulty }
        if !theory.isEmpty {
            phase = .theory(page: 0)
        } else if !self.tasks.isEmpty {
            phase = .task(index: 0)
        } else {
            phase = .summary
        }
    }

    public var lessonId: String? {
        if case .lesson(let id) = mode { return id }
        return nil
    }

    public var currentTask: LearningTask? {
        if case .task(let index) = phase { return tasks[index] }
        return nil
    }

    /// Aufgabe abgeschlossen (gelöst oder Lösung gezeigt) – dann geht es nur noch weiter.
    public var isCurrentTaskFinished: Bool { lastResult?.isCorrect == true || isRevealed }

    public var canRetry: Bool { !isCurrentTaskFinished && lastResult != nil && attempts < Self.maxAttempts }

    /// Gesamtfortschritt 0…1 über Theorie und Aufgaben.
    public var progress: Double {
        let steps = Double(theory.count + tasks.count)
        guard steps > 0 else { return 1 }
        switch phase {
        case .theory(let page): return Double(page) / steps
        case .task(let index): return Double(theory.count + index + (isCurrentTaskFinished ? 1 : 0)) / steps
        case .summary: return 1
        }
    }

    public mutating func advanceTheory() {
        guard case .theory(let page) = phase else { return }
        if page + 1 < theory.count {
            phase = .theory(page: page + 1)
        } else {
            phase = tasks.isEmpty ? .summary : .task(index: 0)
        }
    }

    public mutating func goBackInTheory() {
        if case .theory(let page) = phase, page > 0 { phase = .theory(page: page - 1) }
    }

    /// Wertet eine Antwort aus. Ist die Aufgabe damit erledigt, liefert `finishedOutcome`
    /// das Ergebnis, das gespeichert werden soll.
    @discardableResult
    public mutating func submit(_ answer: TaskAnswer, using evaluator: AnswerEvaluator = AnswerEvaluator()) -> EvaluationResult? {
        guard let task = currentTask, !isCurrentTaskFinished, attempts < Self.maxAttempts else { return nil }
        let result = evaluator.evaluate(answer, for: task)
        attempts += 1
        lastResult = result
        if result.isCorrect {
            outcomes.append(TaskOutcome(task: task, attempts: attempts, solved: true, credit: attempts == 1 ? 1 : 0.5))
        }
        return result
    }

    /// Setzt nur die angezeigte Rückmeldung zurück, damit erneut geantwortet werden kann.
    public mutating func prepareRetry() {
        if canRetry { lastResult = nil }
    }

    public mutating func revealSolution() {
        guard let task = currentTask, !isCurrentTaskFinished else { return }
        isRevealed = true
        outcomes.append(TaskOutcome(task: task, attempts: max(attempts, 1), solved: false, credit: 0))
    }

    /// Das zuletzt abgeschlossene Aufgabenergebnis (für die Speicherung).
    public var finishedOutcome: TaskOutcome? {
        guard isCurrentTaskFinished, let task = currentTask else { return nil }
        return outcomes.last { $0.taskId == task.id }
    }

    public mutating func advanceToNextTask() {
        guard case .task(let index) = phase, isCurrentTaskFinished else { return }
        attempts = 0
        lastResult = nil
        isRevealed = false
        phase = index + 1 < tasks.count ? .task(index: index + 1) : .summary
    }

    public var summary: LessonSummary { LessonSummary(outcomes: outcomes, taskCount: tasks.count) }
}

public struct TaskOutcome: Sendable, Hashable {
    public let taskId: String
    public let topicId: String
    public let difficulty: Difficulty
    public let attempts: Int
    public let solved: Bool
    public let credit: Double

    public init(task: LearningTask, attempts: Int, solved: Bool, credit: Double) {
        taskId = task.id
        topicId = task.topicId
        difficulty = task.difficulty
        self.attempts = attempts
        self.solved = solved
        self.credit = credit
    }

    public var solvedOnFirstTry: Bool { solved && attempts == 1 }
}

public struct LessonSummary: Sendable, Hashable {
    public let outcomes: [TaskOutcome]
    public let taskCount: Int

    /// Nach Niveau gewichtete Trefferquote 0…1.
    public var accuracy: Double {
        let total = outcomes.reduce(0.0) { $0 + $1.difficulty.weight }
        guard total > 0 else { return 0 }
        return outcomes.reduce(0.0) { $0 + $1.difficulty.weight * $1.credit } / total
    }

    public var passed: Bool { accuracy >= LessonSession.passThreshold && outcomes.count == taskCount }
    public var solvedCount: Int { outcomes.filter(\.solved).count }
    public var firstTryCount: Int { outcomes.filter(\.solvedOnFirstTry).count }
    public var stars: Int { Stars.forAccuracy(accuracy) }

    /// Trefferquote je Thema dieser Sitzung.
    public var accuracyByTopic: [String: Double] {
        Dictionary(grouping: outcomes, by: \.topicId).mapValues { items in
            let total = items.reduce(0.0) { $0 + $1.difficulty.weight }
            return total > 0 ? items.reduce(0.0) { $0 + $1.difficulty.weight * $1.credit } / total : 0
        }
    }
}

public enum Stars {
    public static func forAccuracy(_ accuracy: Double) -> Int {
        // Bestanden (ab 90 %) = 1 Stern, ab 95 % = 2 Sterne, fehlerfrei = 3 Sterne.
        switch accuracy {
        case 0.999...: 3
        case 0.95...: 2
        case LessonSession.passThreshold...: 1
        default: 0
        }
    }
}
