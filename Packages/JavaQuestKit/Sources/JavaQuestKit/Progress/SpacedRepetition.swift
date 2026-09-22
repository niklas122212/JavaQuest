import Foundation

/// Ein einzelner Eintrag aus dem Aufgaben-Protokoll – die Rohform, aus der alles Weitere entsteht.
///
/// Bewusst nur diese drei Angaben: Welche Aufgabe, wie gut sie lief und wann. Damit lässt sich
/// die Wiedervorlage vollständig aus dem berechnen, was ohnehin schon gespeichert wird –
/// es braucht kein zusätzliches Feld und damit auch keine Wanderung alter Nutzerdaten.
public struct AttemptRecord: Sendable, Hashable {
    public let taskId: String
    /// 1 = auf Anhieb gelöst, 0,5 = erst im zweiten Anlauf, 0 = falsch oder aufgedeckt.
    public let credit: Double
    public let date: Date

    public init(taskId: String, credit: Double, date: Date) {
        self.taskId = taskId
        self.credit = credit
        self.date = date
    }
}

/// Wie ein Lernziel über die Zeit lief – Grundlage für „wann ist es wieder dran?“.
public struct GoalHistory: Sendable, Hashable {
    /// Wie oft dieses Lernziel insgesamt dran war, über alle Varianten.
    public let attempts: Int
    /// Wie oft es zuletzt **hintereinander** auf Anhieb saß. 0 heißt: beim letzten Mal hat es gehakt.
    public let streak: Int
    public let lastCredit: Double
    public let lastDate: Date

    public init(attempts: Int, streak: Int, lastCredit: Double, lastDate: Date) {
        self.attempts = attempts
        self.streak = streak
        self.lastCredit = lastCredit
        self.lastDate = lastDate
    }

    /// Das Fach, in dem das Lernziel gerade liegt – je höher, desto länger die Pause.
    public var box: Int { min(streak, SpacedRepetition.intervalDays.count - 1) }

    /// Die Pause bis zur nächsten Wiederholung, in Tagen.
    public var intervalDays: Double { SpacedRepetition.intervalDays[box] }

    /// Wann das Lernziel wieder abgefragt werden sollte.
    public var dueDate: Date { lastDate.addingTimeInterval(intervalDays * 86_400) }

    public func isDue(at now: Date) -> Bool { now >= dueDate }

    /// Wie viele Tage die Wiederholung schon überfällig ist (negativ: noch nicht fällig).
    public func daysOverdue(at now: Date) -> Double {
        now.timeIntervalSince(dueDate) / 86_400
    }
}

/// Verteiltes Wiederholen nach dem Karteikasten-Prinzip.
///
/// Der Gedanke: Was dreimal hintereinander saß, muss nicht morgen schon wieder abgefragt werden –
/// aber in einer Woche, bevor es verblasst. Jedes Lernziel wandert bei einem Treffer ein Fach
/// weiter und fällt bei einem Fehler sofort zurück ganz nach vorn.
///
/// Fach 0 heißt: hat zuletzt gehakt, kommt sofort wieder dran.
/// Fächer 1 bis 5: Pause von einem Tag bis fünf Wochen.
public enum SpacedRepetition {
    /// Pause je Fach, in Tagen. Die Abstände wachsen, aber nicht so steil, dass Stoff verloren geht.
    public static let intervalDays: [Double] = [0, 1, 3, 7, 16, 35]

    /// Wie stark ein noch nicht fälliges Lernziel gedämpft wird (0,25 = kommt nur noch ein Viertel so oft).
    public static let minimumFactor = 0.25

    /// Baut aus dem Aufgaben-Protokoll die Historie je Lernziel.
    ///
    /// Zusammengefasst wird über das Lernziel, nicht über die einzelne Aufgabe: Wer dasselbe
    /// Lernziel dreimal mit drei verschiedenen Varianten getroffen hat, hat es verstanden –
    /// und nicht eine Frage auswendig gelernt.
    public static func goals(from attempts: [AttemptRecord], course: Course) -> [String: GoalHistory] {
        var groupKeys: [String: String] = [:]
        for task in course.practiceableTasks { groupKeys[task.id] = task.groupKey }

        var byGoal: [String: [AttemptRecord]] = [:]
        for attempt in attempts {
            guard let key = groupKeys[attempt.taskId] else { continue }
            byGoal[key, default: []].append(attempt)
        }

        var result: [String: GoalHistory] = [:]
        for (key, list) in byGoal {
            let sorted = list.sorted { $0.date < $1.date }
            guard let last = sorted.last else { continue }
            var streak = 0
            for attempt in sorted.reversed() {
                guard attempt.credit >= 1 else { break }
                streak += 1
            }
            result[key] = GoalHistory(
                attempts: sorted.count,
                streak: streak,
                lastCredit: last.credit,
                lastDate: last.date
            )
        }
        return result
    }

    /// Der Faktor, mit dem das Gewicht einer Aufgabe im Training multipliziert wird.
    ///
    /// - Was zuletzt gehakt hat (Fach 0), bleibt unangetastet – darum kümmern sich die anderen Regeln.
    /// - Was fällig oder überfällig ist, wird bis auf das Doppelte angehoben.
    /// - Was noch Pause hat, sinkt auf bis zu ein Viertel und steigt mit näher rückendem Termin wieder an.
    public static func factor(for goal: GoalHistory?, at now: Date) -> Double {
        guard let goal, goal.streak > 0 else { return 1 }
        let interval = goal.intervalDays
        guard interval > 0 else { return 1 }
        let elapsed = max(now.timeIntervalSince(goal.lastDate) / 86_400, 0)
        if elapsed >= interval {
            let overdue = (elapsed - interval) / interval
            return 1 + min(overdue, 1)
        }
        return minimumFactor + (1 - minimumFactor) * (elapsed / interval)
    }

    /// Die Lernziele, die heute zur Wiederholung anstehen – fürs Dashboard.
    public static func due(_ goals: [String: GoalHistory], at now: Date) -> [String] {
        goals.filter { $0.value.isDue(at: now) }.map(\.key)
    }
}
