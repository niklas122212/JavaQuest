import Foundation

/// Bestwert einer Lektion, wie er aus der Persistenz gelesen wird.
public struct LessonResult: Sendable, Hashable {
    public var bestAccuracy: Double
    public var isCompleted: Bool
    public var viaPlacement: Bool

    public init(bestAccuracy: Double, isCompleted: Bool, viaPlacement: Bool = false) {
        self.bestAccuracy = bestAccuracy
        self.isCompleted = isCompleted
        self.viaPlacement = viaPlacement
    }

    public var stars: Int { isCompleted ? Stars.forAccuracy(bestAccuracy) : 0 }
}

/// Java Master Score: 0 bis 1000 Punkte.
///
/// Jede abgeschlossene Lektion bringt `Gewicht × Bestwert`. Das Gewicht ist die
/// Summe ihrer Aufgabenniveaus, multipliziert mit dem Stufenfaktor (Anfänger 1,0 –
/// Fortgeschritten 1,25 – Erfahren 1,5). 1000 Punkte = alle Lektionen mit 100 %.
/// Weil nur Bestwerte zählen, kann der Score nie sinken.
public enum MasterScore {
    public static let maximum = 1000

    public static func tierFactor(_ tier: ExperienceLevel) -> Double {
        switch tier {
        case .beginner: 1.0
        case .intermediate: 1.25
        case .advanced: 1.5
        }
    }

    public static func compute(course: Course, results: [String: LessonResult]) -> Int {
        var total = 0.0
        var earned = 0.0
        for module in course.modules {
            let factor = tierFactor(module.tier)
            for lesson in module.lessons {
                let weight = lesson.difficultyWeight * factor
                total += weight
                if let result = results[lesson.id], result.isCompleted {
                    earned += weight * min(max(result.bestAccuracy, 0), 1)
                }
            }
        }
        guard total > 0 else { return 0 }
        return Int((earned / total * Double(maximum)).rounded())
    }
}

public struct MasterRank: Sendable, Hashable {
    public let title: String
    public let symbolName: String
    public let minimumScore: Int

    public static let all: [MasterRank] = [
        MasterRank(title: "Neuling", symbolName: "leaf.fill", minimumScore: 0),
        MasterRank(title: "Code-Talent", symbolName: "sparkles", minimumScore: 150),
        MasterRank(title: "Java-Profi", symbolName: "hammer.fill", minimumScore: 350),
        MasterRank(title: "Architektur-Ass", symbolName: "building.columns.fill", minimumScore: 600),
        MasterRank(title: "Java Master", symbolName: "crown.fill", minimumScore: 850),
    ]

    public static func rank(for score: Int) -> MasterRank {
        all.last { score >= $0.minimumScore } ?? all[0]
    }

    public static func next(after score: Int) -> MasterRank? {
        all.first { $0.minimumScore > score }
    }

    /// Fortschritt 0…1 innerhalb des aktuellen Rangs.
    public static func progressToNext(for score: Int) -> Double {
        let current = rank(for: score)
        guard let next = next(after: score) else { return 1 }
        let span = Double(next.minimumScore - current.minimumScore)
        return Double(score - current.minimumScore) / span
    }
}
