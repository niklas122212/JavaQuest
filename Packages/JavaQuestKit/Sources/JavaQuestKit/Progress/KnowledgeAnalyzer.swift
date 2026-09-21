import Foundation

/// Aggregierte Leistung in einem Thema, wie sie aus der Persistenz gelesen wird.
public struct TopicStats: Sendable, Hashable {
    public var attempts: Int
    public var weightedCorrect: Double
    public var weightedTotal: Double
    public var lastPracticed: Date?

    public init(attempts: Int = 0, weightedCorrect: Double = 0, weightedTotal: Double = 0, lastPracticed: Date? = nil) {
        self.attempts = attempts
        self.weightedCorrect = weightedCorrect
        self.weightedTotal = weightedTotal
        self.lastPracticed = lastPracticed
    }

    /// Geschätzte Beherrschung 0…1 mit Laplace-Glättung: Wenige Antworten
    /// führen nicht sofort zu 0 % oder 100 %.
    public var mastery: Double { (weightedCorrect + 1) / (weightedTotal + 2) }

    public mutating func record(difficulty: Difficulty, credit: Double, at date: Date) {
        attempts += 1
        weightedTotal += difficulty.weight
        weightedCorrect += difficulty.weight * min(max(credit, 0), 1)
        lastPracticed = date
    }
}

public enum TopicStatus: String, Sendable, CaseIterable {
    case strength
    case developing
    case gap
    case unknown

    public var title: String {
        switch self {
        case .strength: "Stärken"
        case .developing: "Im Aufbau"
        case .gap: "Wissenslücken"
        case .unknown: "Noch unbekannt"
        }
    }

    public var symbolName: String {
        switch self {
        case .strength: "checkmark.seal.fill"
        case .developing: "chart.line.uptrend.xyaxis"
        case .gap: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

public struct TopicInsight: Sendable, Hashable, Identifiable {
    public let topic: Topic
    public let status: TopicStatus
    public let stats: TopicStats
    /// Lektion, in der das Thema behandelt wird (Einstieg oder Wiederholung).
    public let lessonId: String?

    public var id: String { topic.id }
    public var mastery: Double? { stats.attempts > 0 ? stats.mastery : nil }
}

public struct KnowledgeReport: Sendable, Hashable {
    public let insights: [TopicInsight]

    public func topics(_ status: TopicStatus) -> [TopicInsight] { insights.filter { $0.status == status } }

    public var strengths: [TopicInsight] { topics(.strength) }
    public var gaps: [TopicInsight] { topics(.gap).sorted { ($0.mastery ?? 0) < ($1.mastery ?? 0) } }
    public var developing: [TopicInsight] { topics(.developing) }
    public var unknown: [TopicInsight] { topics(.unknown) }

    /// Durchschnittliche Beherrschung aller bereits geübten Themen.
    public var overallMastery: Double? {
        let values = insights.compactMap(\.mastery)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// Das Thema, das sich als Nächstes am meisten lohnt.
    public var focusTopic: TopicInsight? {
        gaps.first ?? developing.min { ($0.mastery ?? 1) < ($1.mastery ?? 1) }
    }
}

/// Automatische Auswertung: Stärken, Wissenslücken und noch unbekannte Themen.
public enum KnowledgeAnalyzer {
    public static let strengthThreshold = 0.75
    public static let gapThreshold = 0.55
    public static let minimumAttemptsForStrength = 3
    public static let minimumAttemptsForGap = 2

    public static func classify(_ stats: TopicStats) -> TopicStatus {
        guard stats.attempts > 0 else { return .unknown }
        if stats.attempts >= minimumAttemptsForStrength, stats.mastery >= strengthThreshold { return .strength }
        if stats.attempts >= minimumAttemptsForGap, stats.mastery < gapThreshold { return .gap }
        return .developing
    }

    public static func report(course: Course, stats: [String: TopicStats]) -> KnowledgeReport {
        let insights = course.topics.map { topic in
            let topicStats = stats[topic.id] ?? TopicStats()
            return TopicInsight(
                topic: topic,
                status: classify(topicStats),
                stats: topicStats,
                lessonId: course.firstLesson(teaching: topic.id)?.id
            )
        }
        return KnowledgeReport(insights: insights)
    }
}

/// Stellt gezielte Übungssitzungen für ein Thema zusammen.
public enum PracticeBuilder {
    /// Bis zu `limit` Aufgaben des Themas aus freigeschalteten Lektionen und dem
    /// Übungspool, über die Niveaus verteilt und aufsteigend sortiert.
    /// Je Lernziel kommt nur eine Variante dran (siehe `VariantSelector`).
    public static func tasks(
        for topicId: String,
        in course: Course,
        unlockedLessonIds: Set<String>,
        limit: Int = 5,
        history: [String: TaskHistory] = [:]
    ) -> [LearningTask] {
        let unlockedTopics = Set(course.allLessons.filter { unlockedLessonIds.contains($0.id) }.flatMap(\.topicIds))
        let fromLessons = course.allLessons
            .filter { unlockedLessonIds.contains($0.id) }
            .flatMap(\.tasks)
            .filter { $0.topicId == topicId }
        // Aus dem Pool nur Themen, die im Lernpfad schon dran waren – das freie Training
        // (siehe `TrainingBuilder.freePool`) umgeht diese Sperre bewusst.
        let fromPool = unlockedTopics.contains(topicId) ? course.taskPool.filter { $0.topicId == topicId } : []
        let candidates = VariantSelector.collapse(fromLessons + fromPool, history: history)
            .sorted { $0.difficulty < $1.difficulty }
        guard limit > 1, candidates.count > limit else { return Array(candidates.prefix(max(limit, 0))) }
        let step = Double(candidates.count - 1) / Double(limit - 1)
        return (0..<limit).map { candidates[Int((Double($0) * step).rounded())] }
    }
}
