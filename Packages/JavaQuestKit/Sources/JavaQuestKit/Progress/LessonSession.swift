import Foundation

/// Zustandsautomat für den Lern-Loop einer Lektion:
/// Theorie-Happen → Aufgaben (Niveau aufsteigend) → Arena-Mission (falls vorhanden) → Auswertung.
///
/// Wertung pro Aufgabe: beim ersten Versuch gelöst = 100 %, später gelöst = 50 %,
/// Lösung angezeigt = 0 %.
public struct LessonSession: Sendable {
    public enum Mode: Sendable, Hashable {
        case lesson(lessonId: String)
        case practice(topicId: String)
        /// Endlos-Training: gemischte Runde über alle abgeschlossenen Lektionen.
        case training
        /// Freies Training: selbst gewählte Themen, unabhängig vom Lernpfad.
        case free(topicIds: [String])
    }

    public enum Phase: Sendable, Hashable {
        case theory(page: Int)
        case task(index: Int)
        /// Abschluss-Mission in der Arena – zählt nicht zur Trefferquote.
        case mission(id: String)
        case summary
    }

    public static let maxAttempts = 3
    /// Eine Lektion gilt ab 69 % (gewichtete Trefferquote) als bestanden.
    /// Einzige Quelle für die Bestehensgrenze – Sterne und Anzeigetexte leiten sich davon ab.
    public static let passThreshold = 0.69

    public let mode: Mode
    public let title: String
    public let theory: [TheoryCard]
    public let tasks: [LearningTask]
    public private(set) var phase: Phase
    public private(set) var outcomes: [TaskOutcome] = []
    public private(set) var attempts = 0
    public private(set) var lastResult: EvaluationResult?
    public private(set) var isRevealed = false
    /// Arena-Mission, die nach der letzten Aufgabe kommt.
    public let missionId: String?

    public init(lesson: Lesson, missionId: String? = nil) {
        self.init(mode: .lesson(lessonId: lesson.id), title: lesson.title, theory: lesson.theory, tasks: lesson.tasks, missionId: missionId)
    }

    public init(mode: Mode, title: String, theory: [TheoryCard], tasks: [LearningTask], missionId: String? = nil) {
        self.mode = mode
        self.title = title
        self.theory = theory
        self.tasks = tasks.sorted { $0.difficulty < $1.difficulty }
        self.missionId = missionId
        if !theory.isEmpty {
            phase = .theory(page: 0)
        } else if !self.tasks.isEmpty {
            phase = .task(index: 0)
        } else {
            phase = .summary
        }
    }

    /// Aufgaben in Folge, die zuletzt beim ersten Versuch saßen.
    public var currentCombo: Int {
        outcomes.reversed().prefix { $0.solvedOnFirstTry }.count
    }

    /// Längste Combo dieser Sitzung.
    public var bestCombo: Int {
        var best = 0
        var current = 0
        for outcome in outcomes {
            current = outcome.solvedOnFirstTry ? current + 1 : 0
            best = max(best, current)
        }
        return best
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

    /// Gesamtfortschritt 0…1 über Theorie, Aufgaben und Mission.
    public var progress: Double {
        let steps = Double(theory.count + tasks.count + (missionId == nil ? 0 : 1))
        guard steps > 0 else { return 1 }
        switch phase {
        case .theory(let page): return Double(page) / steps
        case .task(let index): return Double(theory.count + index + (isCurrentTaskFinished ? 1 : 0)) / steps
        case .mission: return Double(theory.count + tasks.count) / steps
        case .summary: return 1
        }
    }

    public mutating func advanceTheory() {
        guard case .theory(let page) = phase else { return }
        if page + 1 < theory.count {
            phase = .theory(page: page + 1)
        } else {
            phase = tasks.isEmpty ? afterTasks : .task(index: 0)
        }
    }

    private var afterTasks: Phase { missionId.map { .mission(id: $0) } ?? .summary }

    /// Mission geschafft oder übersprungen – weiter zur Auswertung.
    public mutating func finishMission() {
        if case .mission = phase { phase = .summary }
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
        phase = index + 1 < tasks.count ? .task(index: index + 1) : afterTasks
    }

    public var summary: LessonSummary {
        LessonSummary(outcomes: outcomes, taskCount: tasks.count, bonusTaskCount: tasks.filter(\.type.isBonus).count)
    }
}

public struct TaskOutcome: Sendable, Hashable {
    public let taskId: String
    public let topicId: String
    public let difficulty: Difficulty
    public let attempts: Int
    public let solved: Bool
    public let credit: Double
    /// Bonus-Aufgabe: zählt nicht für Trefferquote und Score.
    public let isBonus: Bool

    public init(task: LearningTask, attempts: Int, solved: Bool, credit: Double) {
        taskId = task.id
        topicId = task.topicId
        difficulty = task.difficulty
        self.attempts = attempts
        self.solved = solved
        self.credit = credit
        isBonus = task.type.isBonus
    }

    public var solvedOnFirstTry: Bool { solved && attempts == 1 }
}

public struct LessonSummary: Sendable, Hashable {
    public let outcomes: [TaskOutcome]
    public let taskCount: Int
    /// Davon Bonus-Aufgaben – sie zählen weder für die Trefferquote noch fürs Bestehen.
    public let bonusTaskCount: Int

    public init(outcomes: [TaskOutcome], taskCount: Int, bonusTaskCount: Int = 0) {
        self.outcomes = outcomes
        self.taskCount = taskCount
        self.bonusTaskCount = bonusTaskCount
    }

    private var scoredOutcomes: [TaskOutcome] { outcomes.filter { !$0.isBonus } }

    /// Nach Niveau gewichtete Trefferquote 0…1 (ohne Bonus-Aufgaben).
    public var accuracy: Double {
        let total = scoredOutcomes.reduce(0.0) { $0 + $1.difficulty.weight }
        guard total > 0 else { return 0 }
        return scoredOutcomes.reduce(0.0) { $0 + $1.difficulty.weight * $1.credit } / total
    }

    public var passed: Bool { accuracy >= LessonSession.passThreshold && scoredOutcomes.count == taskCount - bonusTaskCount }
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
    /// Zweiter Stern auf halbem Weg zwischen Bestehensgrenze und fehlerfrei –
    /// so bleiben die Stufen sinnvoll, egal wie die Grenze eingestellt ist.
    public static var twoStarThreshold: Double { LessonSession.passThreshold + (1 - LessonSession.passThreshold) / 2 }

    public static func forAccuracy(_ accuracy: Double) -> Int {
        // Bestanden = 1 Stern, deutlich darüber = 2 Sterne, fehlerfrei = 3 Sterne.
        switch accuracy {
        case 0.999...: 3
        case twoStarThreshold...: 2
        case LessonSession.passThreshold...: 1
        default: 0
        }
    }
}
