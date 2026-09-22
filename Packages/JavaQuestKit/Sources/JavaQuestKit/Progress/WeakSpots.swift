import Foundation

/// Eine Stelle, an der es zuletzt gehakt hat – ein Lernziel, nicht eine einzelne Aufgabe.
///
/// Absichtlich auf Lernziel-Ebene: Wer „7 % 3“ falsch hatte, hat nicht diese eine Frage
/// nicht verstanden, sondern den Rest bei der Division. Geübt wird deshalb mit einer
/// anderen Variante desselben Lernziels.
public struct WeakSpot: Sendable, Hashable, Identifiable {
    /// Die Aufgabe, an der es zuletzt scheiterte.
    public let task: LearningTask
    public let topicId: String
    /// Wie oft dieses Lernziel schon dran war (über alle Varianten).
    public let attempts: Int
    /// Wertung des letzten Versuchs: 0 = falsch oder aufgedeckt, 0,5 = erst im zweiten Anlauf.
    public let lastCredit: Double
    public let lastDate: Date
    /// Wie viele andere Varianten zum Üben bereitstehen.
    public let otherVariants: Int

    public var id: String { task.groupKey }

    /// Was beim letzten Mal passiert ist – in Alltagssprache.
    public var summary: String {
        switch lastCredit {
        case 0: "zuletzt nicht gelöst"
        case ..<1: "erst im zweiten Anlauf"
        default: "zuletzt gelöst"
        }
    }
}

/// Findet die Lernziele, die zuletzt nicht saßen.
public enum WeakSpotFinder {
    /// Alles unter voller Wertung gilt als wacklig – auch „erst im zweiten Anlauf“.
    public static let creditThreshold = 1.0

    /// Die schwächsten Lernziele, das wackligste zuerst.
    ///
    /// Sortiert nach Wertung (falsch vor halb), dann nach Häufigkeit (was oft haktet,
    /// steht oben) und zuletzt nach Datum.
    public static func spots(
        course: Course,
        history: [String: TaskHistory],
        limit: Int = 20
    ) -> [WeakSpot] {
        let byGroup = Dictionary(grouping: course.practiceableTasks, by: \.groupKey)
        var spots: [WeakSpot] = []

        for (group, variants) in byGroup {
            // Der jüngste Versuch innerhalb dieses Lernziels zählt.
            let versuche = variants.compactMap { task -> (LearningTask, TaskHistory)? in
                history[task.id].map { (task, $0) }
            }
            guard let letzter = versuche.max(by: { $0.1.lastDate < $1.1.lastDate }) else { continue }
            guard letzter.1.lastCredit < creditThreshold else { continue }
            _ = group
            spots.append(WeakSpot(
                task: letzter.0,
                topicId: letzter.0.topicId,
                attempts: versuche.reduce(0) { $0 + $1.1.attempts },
                lastCredit: letzter.1.lastCredit,
                lastDate: letzter.1.lastDate,
                otherVariants: max(variants.count - 1, 0)
            ))
        }

        return spots.sorted {
            if $0.lastCredit != $1.lastCredit { return $0.lastCredit < $1.lastCredit }
            if $0.attempts != $1.attempts { return $0.attempts > $1.attempts }
            return $0.lastDate > $1.lastDate
        }
        .prefix(limit)
        .map { $0 }
    }

    /// Alle Aufgaben zu den wackligen Lernzielen – Grundlage für „Schwächen üben“.
    /// Enthält bewusst alle Varianten, damit die Auswahl eine andere als zuletzt nehmen kann.
    public static func pool(course: Course, history: [String: TaskHistory], limit: Int = 20) -> [LearningTask] {
        let gruppen = Set(spots(course: course, history: history, limit: limit).map { $0.task.groupKey })
        return course.practiceableTasks.filter { gruppen.contains($0.groupKey) }
    }
}

/// Wie ein Thema auf einer einzelnen Schwierigkeitsstufe läuft.
///
/// „Vererbung wackelt“ ist eine unbrauchbare Auskunft, wenn die leichten Aufgaben sitzen
/// und erst ab Stufe 4 etwas schiefgeht. Deshalb wird je Stufe getrennt gezählt.
public struct LevelPerformance: Sendable, Hashable, Identifiable {
    public let difficulty: Difficulty
    /// Wie viele Aufgaben dieser Stufe schon dran waren.
    public let seen: Int
    /// Davon beim letzten Versuch auf Anhieb gelöst.
    public let solved: Int

    public var id: Int { difficulty.rawValue }
    public var accuracy: Double { seen > 0 ? Double(solved) / Double(seen) : 0 }

    /// Wacklig ist eine Stufe erst, wenn sie mehrfach dran war und unter der Bestehensgrenze liegt.
    /// Ein einzelner Fehlversuch macht noch keine Schwäche.
    public var isWeak: Bool { seen >= 2 && accuracy < LessonSession.passThreshold }

    /// Kurzform für die Anzeige, z. B. „Stufe 4: 1 von 3“.
    public var summary: String { "Stufe \(difficulty.rawValue): \(solved) von \(seen)" }
}

public extension WeakSpotFinder {
    /// Die Leistung eines Themas, aufgeschlüsselt nach Schwierigkeitsstufe.
    /// Stufen, die noch nie dran waren, fehlen bewusst – über sie lässt sich nichts sagen.
    static func levels(
        course: Course,
        history: [String: TaskHistory],
        topicId: String
    ) -> [LevelPerformance] {
        var seen: [Difficulty: Int] = [:]
        var solved: [Difficulty: Int] = [:]
        for task in course.tasks(forTopic: topicId) {
            guard let past = history[task.id] else { continue }
            seen[task.difficulty, default: 0] += 1
            if past.lastCredit >= creditThreshold { solved[task.difficulty, default: 0] += 1 }
        }
        return seen.keys.sorted().map {
            LevelPerformance(difficulty: $0, seen: seen[$0] ?? 0, solved: solved[$0] ?? 0)
        }
    }

    /// Nur die Stufen, auf denen es hakt – als Vorauswahl für „genau das üben“.
    static func weakDifficulties(
        course: Course,
        history: [String: TaskHistory],
        topicId: String
    ) -> Set<Difficulty> {
        Set(levels(course: course, history: history, topicId: topicId).filter(\.isWeak).map(\.difficulty))
    }
}
