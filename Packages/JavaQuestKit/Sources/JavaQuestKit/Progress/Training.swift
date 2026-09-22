import Foundation

/// Wie eine Aufgabe zuletzt lief – für die Auswahl im Endlos-Training.
public struct TaskHistory: Sendable, Hashable {
    public var attempts: Int
    public var lastCredit: Double
    public var lastDate: Date

    public init(attempts: Int, lastCredit: Double, lastDate: Date) {
        self.attempts = attempts
        self.lastCredit = lastCredit
        self.lastDate = lastDate
    }
}

/// Endlos-Training: gemischte Runden über alle abgeschlossenen Lektionen.
///
/// Jede Aufgabe bekommt ein Gewicht – je höher, desto eher kommt sie dran:
/// - schwaches Thema: bis zu +3 (nach der Beherrschung des Themas),
/// - noch nie geübt: +2,
/// - zuletzt nicht (voll) gelöst: bis zu +3,
/// - lange nicht gesehen: bis zu +2 (eine Woche = +1).
/// Zum Schluss kommt die Wiedervorlage dazu (siehe `SpacedRepetition`): Was gerade erst saß,
/// sinkt auf bis zu ein Viertel; was wieder fällig ist, steigt auf bis zum Doppelten.
/// Gezogen wird ohne Zurücklegen; die Runde steigt im Niveau an.
public enum TrainingBuilder {
    public static let roundSize = 8

    /// Trainiert wird nur, was schon gelernt ist: Aufgaben abgeschlossener Lektionen –
    /// dazu alle Übungsaufgaben aus dem Pool zu den Themen dieser Lektionen.
    public static func pool(course: Course, completedLessonIds: Set<String>) -> [LearningTask] {
        let lessons = course.allLessons.filter { completedLessonIds.contains($0.id) }
        let learnedTopics = Set(lessons.flatMap(\.tasks).map(\.topicId))
        return lessons.flatMap(\.tasks) + course.taskPool.filter { learnedTopics.contains($0.topicId) }
    }

    /// Aufgabentopf für das freie Training: nur die gewählten Themen, optional auf Niveaus begrenzt.
    /// Bewusst ohne Rücksicht auf den Lernpfad – jedes Thema ist jederzeit übbar.
    public static func freePool(course: Course, topicIds: Set<String>, difficulties: Set<Difficulty> = []) -> [LearningTask] {
        course.practiceableTasks.filter { task in
            (topicIds.isEmpty || topicIds.contains(task.topicId))
                && (difficulties.isEmpty || difficulties.contains(task.difficulty))
        }
    }

    public static func weight(
        for task: LearningTask,
        topicStats: [String: TopicStats],
        history: [String: TaskHistory],
        goals: [String: GoalHistory] = [:],
        now: Date
    ) -> Double {
        var weight = 1.0
        let mastery = topicStats[task.topicId].map { $0.attempts > 0 ? $0.mastery : 0.5 } ?? 0.5
        weight += (1 - mastery) * 3
        let goal = goals[task.groupKey]
        guard let past = history[task.id] else {
            // Noch nie geübt – aber vielleicht eine andere Variante desselben Lernziels.
            return (weight + 2) * SpacedRepetition.factor(for: goal, at: now)
        }
        weight += (1 - min(max(past.lastCredit, 0), 1)) * 3
        let days = max(now.timeIntervalSince(past.lastDate) / 86_400, 0)
        weight += min(days, 14) / 7
        if goal != nil { return weight * SpacedRepetition.factor(for: goal, at: now) }
        // Ohne Wiedervorlage-Daten bleibt die alte, gröbere Regel als Rückfallebene.
        if days < 1, past.lastCredit >= 1 { weight /= 3 }
        return weight
    }

    /// Aufgabentopf für die Wiederholung: nur Lernziele, deren Pause abgelaufen ist.
    /// Alles, was noch Schonfrist hat, bleibt draußen – genau das ist der Sinn der Wiedervorlage.
    public static func reviewPool(course: Course, goals: [String: GoalHistory], now: Date = .now) -> [LearningTask] {
        let faellig = Set(SpacedRepetition.due(goals, at: now))
        return course.practiceableTasks.filter { faellig.contains($0.groupKey) }
    }

    /// Eine Runde Wiederholung: was heute wieder dran ist, das am längsten Überfällige zuerst.
    public static func reviewRound(
        course: Course,
        history: [String: TaskHistory],
        goals: [String: GoalHistory],
        topicStats: [String: TopicStats] = [:],
        count: Int = roundSize,
        now: Date = .now,
        seed: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) -> [LearningTask] {
        round(
            from: reviewPool(course: course, goals: goals, now: now),
            topicStats: topicStats,
            history: history,
            goals: goals,
            now: now,
            size: count,
            seed: seed
        )
    }

    /// Eine Runde nur über das, was zuletzt nicht saß – mit anderen Varianten als beim Fehler.
    public static func weakRound(
        course: Course,
        history: [String: TaskHistory],
        topicStats: [String: TopicStats] = [:],
        goals: [String: GoalHistory] = [:],
        count: Int = roundSize,
        now: Date = .now,
        seed: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) -> [LearningTask] {
        round(
            from: WeakSpotFinder.pool(course: course, history: history),
            topicStats: topicStats,
            history: history,
            goals: goals,
            now: now,
            size: count,
            seed: seed
        )
    }

    /// Eine Runde freies Training: selbst gewählte Themen und Niveaus, beliebig viele Aufgaben.
    /// Funktioniert auch für Themen, deren Lektion noch nicht freigeschaltet ist.
    public static func freeRound(
        course: Course,
        topicIds: Set<String>,
        difficulties: Set<Difficulty> = [],
        count: Int = roundSize,
        topicStats: [String: TopicStats] = [:],
        history: [String: TaskHistory] = [:],
        goals: [String: GoalHistory] = [:],
        now: Date = .now,
        seed: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) -> [LearningTask] {
        round(
            from: freePool(course: course, topicIds: topicIds, difficulties: difficulties),
            topicStats: topicStats,
            history: history,
            goals: goals,
            now: now,
            size: count,
            seed: seed
        )
    }

    /// Eine Runde mit bis zu `size` verschiedenen Aufgaben. Gleicher `seed` → gleiche Runde (für Tests).
    public static func round(
        from pool: [LearningTask],
        topicStats: [String: TopicStats],
        history: [String: TaskHistory],
        goals: [String: GoalHistory] = [:],
        now: Date = .now,
        size: Int = roundSize,
        seed: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) -> [LearningTask] {
        var generator = SplitMix64(seed: seed)
        // Je Lernziel tritt nur eine Variante an – so kommt dieselbe Frage nicht zweimal
        // in einer Runde, und nach einem Fehler kommt beim nächsten Mal eine andere.
        let candidateTasks = VariantSelector.collapse(pool, history: history)
        var candidates = candidateTasks.map {
            (task: $0, weight: weight(for: $0, topicStats: topicStats, history: history, goals: goals, now: now))
        }
        var chosen: [LearningTask] = []
        while chosen.count < size, !candidates.isEmpty {
            let total = candidates.reduce(0) { $0 + $1.weight }
            var ticket = Double(generator.next() % 1_000_000) / 1_000_000 * total
            var index = candidates.count - 1
            for (i, candidate) in candidates.enumerated() {
                ticket -= candidate.weight
                if ticket <= 0 { index = i; break }
            }
            chosen.append(candidates.remove(at: index).task)
        }
        return chosen.sorted { $0.difficulty < $1.difficulty }
    }
}

/// Kleiner, deterministischer Zufallsgenerator (für reproduzierbare Runden in Tests).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
