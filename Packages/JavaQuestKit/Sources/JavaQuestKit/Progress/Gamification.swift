import Foundation

/// Ein gespeicherter Versuch mit allen Angaben, die XP und Abzeichen brauchen – Aufgaben und Arena-Missionen.
/// (Die Wiedervorlage nutzt die schlankere Form `AttemptRecord` aus SpacedRepetition.swift.)
///
/// Missionen werden im selben Protokoll abgelegt: `taskId` ist dann die Missions-ID und
/// `credit` die Sterne geteilt durch 3. So bleibt das Speicherschema unverändert.
public struct ActivityRecord: Sendable, Hashable {
    public enum Context: String, Sendable, Hashable {
        case lesson, practice, placement
        /// Endlos-, Freies und Wiederholungs-Training.
        case training
        /// Arena-Mission (aus der Lektion oder der Arena-Übersicht).
        case mission
        /// Die tägliche Mission – zählt zusätzlich als Tageserfolg.
        case daily

        public var isTask: Bool { self != .mission && self != .daily }
    }

    public let taskId: String
    public let topicId: String
    public let context: Context
    public let difficulty: Int
    public let credit: Double
    public let solved: Bool
    public let tries: Int
    public let date: Date

    public init(taskId: String, topicId: String, context: Context, difficulty: Int, credit: Double, solved: Bool, tries: Int, date: Date) {
        self.taskId = taskId
        self.topicId = topicId
        self.context = context
        self.difficulty = difficulty
        self.credit = credit
        self.solved = solved
        self.tries = tries
        self.date = date
    }

    public var solvedOnFirstTry: Bool { solved && tries == 1 }

    /// Sterne einer Mission (0–3).
    public var stars: Int { Int((credit * 3).rounded()) }

    /// Hilfswert zum Speichern einer Mission: Sterne → credit.
    public static func credit(forStars stars: Int) -> Double { Double(min(max(stars, 0), 3)) / 3 }
}

/// Alles, was Abzeichen, XP und Tagesziele brauchen – abgeleitet aus dem Fortschritt.
public struct LearnerFacts: Sendable {
    public let course: Course
    public let catalog: ArenaCatalog
    /// Chronologisch sortiert.
    public let attempts: [ActivityRecord]
    public let lessonResults: [String: LessonResult]
    public let longestStreak: Int

    public init(course: Course, catalog: ArenaCatalog, attempts: [ActivityRecord], lessonResults: [String: LessonResult], longestStreak: Int) {
        self.course = course
        self.catalog = catalog
        self.attempts = attempts.sorted { $0.date < $1.date }
        self.lessonResults = lessonResults
        self.longestStreak = longestStreak
    }

    public var taskAttempts: [ActivityRecord] { attempts.filter(\.context.isTask) }

    /// Beste Sterne je Mission (Lektion, Arena oder tägliche Mission zählen gleich).
    public var missionStars: [String: Int] { missionStars(before: .distantFuture) }

    /// Sterne-Stand zu einem Zeitpunkt – damit die Tagesmission den ganzen Tag dieselbe bleibt.
    public func missionStars(before date: Date) -> [String: Int] {
        var best: [String: Int] = [:]
        for attempt in attempts where !attempt.context.isTask && attempt.solved && attempt.date < date {
            best[attempt.taskId] = max(best[attempt.taskId] ?? 0, attempt.stars)
        }
        return best
    }

    public var completedLessonIds: Set<String> { Set(lessonResults.filter(\.value.isCompleted).map(\.key)) }

    /// Lektionen, die man selbst bestanden hat (nicht nur per Einstufung angerechnet).
    public var earnedLessonIds: Set<String> { Set(lessonResults.filter { $0.value.isCompleted && !$0.value.viaPlacement }.map(\.key)) }

    /// Längste Folge von Aufgaben, die beim ersten Versuch saßen (über Lektionen hinweg).
    public var bestCombo: Int {
        var best = 0
        var current = 0
        for attempt in taskAttempts where attempt.context != .placement {
            current = attempt.solvedOnFirstTry ? current + 1 : 0
            best = max(best, current)
        }
        return best
    }

    public func solvedCount(of type: TaskType) -> Int {
        let types = Dictionary(course.allTasks.map { ($0.id, $0.type) }, uniquingKeysWith: { first, _ in first })
        return Set(taskAttempts.filter { $0.solved && types[$0.taskId] == type }.map(\.taskId)).count
    }

    public var dailyCompletions: Int {
        let calendar = Calendar.current
        return Set(attempts.filter { $0.context == .daily && $0.solved }.map { calendar.startOfDay(for: $0.date) }).count
    }

    public func isDailyDone(on day: Date) -> Bool {
        dailyMissionId(doneOn: day) != nil
    }

    /// Die Tagesmission, die an diesem Tag geschafft wurde.
    public func dailyMissionId(doneOn day: Date) -> String? {
        attempts.last { $0.context == .daily && $0.solved && Calendar.current.isDate($0.date, inSameDayAs: day) }?.taskId
    }

    /// Die Mission des Tages – stabil vom Morgen bis zum Abend, auch wenn zwischendurch Sterne dazukommen.
    public func dailyMission(on day: Date, available: [ArenaMission]) -> ArenaMission? {
        if let done = dailyMissionId(doneOn: day), let mission = catalog.mission(id: done) { return mission }
        return DailyMission.mission(for: day, available: available, stars: missionStars(before: Calendar.current.startOfDay(for: day)))
    }

    public var experience: Int { Experience.points(self) }
}

// MARK: - XP & Level

/// Erfahrungspunkte: Jede gelöste Aufgabe, jede Mission und jeder Tageserfolg bringt XP.
/// Anders als der Master Score (Bestwerte, max. 1000) wächst XP mit jeder Übung weiter.
public enum Experience {
    public static func points(forTask attempt: ActivityRecord) -> Int {
        guard attempt.solved else { return 2 }
        return attempt.solvedOnFirstTry ? 10 * attempt.difficulty : 5 * attempt.difficulty
    }

    public static let pointsPerMissionStar = 25
    public static let pointsPerBossStar = 50
    public static let pointsPerDaily = 50
    public static let pointsPerLesson = 50

    public static func points(_ facts: LearnerFacts) -> Int {
        let tasks = facts.taskAttempts.reduce(0) { $0 + points(forTask: $1) }
        let missions = facts.missionStars.reduce(0) { total, entry in
            let isBoss = facts.catalog.mission(id: entry.key)?.kind == .boss
            return total + entry.value * (isBoss ? pointsPerBossStar : pointsPerMissionStar)
        }
        return tasks + missions + facts.dailyCompletions * pointsPerDaily + facts.earnedLessonIds.count * pointsPerLesson
    }

    /// XP, die man insgesamt braucht, um Level `level` zu erreichen (Level 1 ab 0 XP).
    public static func threshold(for level: Int) -> Int {
        let n = max(level - 1, 0)
        return 50 * n * (n + 1)
    }

    public static func level(for xp: Int) -> LevelProgress {
        var level = 1
        while threshold(for: level + 1) <= xp { level += 1 }
        let start = threshold(for: level)
        let end = threshold(for: level + 1)
        return LevelProgress(level: level, xp: xp, levelStart: start, nextLevelAt: end)
    }
}

public struct LevelProgress: Sendable, Hashable {
    public let level: Int
    public let xp: Int
    public let levelStart: Int
    public let nextLevelAt: Int

    public var fraction: Double { Double(xp - levelStart) / Double(max(nextLevelAt - levelStart, 1)) }
    public var remaining: Int { nextLevelAt - xp }
}

// MARK: - Abzeichen

public struct Achievement: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbolName: String
    public let target: Int
    let measure: @Sendable (LearnerFacts) -> Int

    public static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    public func current(_ facts: LearnerFacts) -> Int { min(measure(facts), target) }
    public func isUnlocked(_ facts: LearnerFacts) -> Bool { measure(facts) >= target }

    public static let all: [Achievement] = [
        Achievement(id: "first-task", title: "Hallo, Welt!", detail: "Löse deine erste Aufgabe.", symbolName: "hand.wave.fill", target: 1) {
            Set($0.taskAttempts.filter { $0.solved && $0.context != .placement }.map(\.taskId)).count
        },
        Achievement(id: "first-lesson", title: "Durchstarter", detail: "Schließe deine erste Lektion ab.", symbolName: "flag.checkered", target: 1) {
            $0.earnedLessonIds.count
        },
        Achievement(id: "perfect", title: "Fehlerfrei", detail: "Hol in einer Lektion alle 3 Sterne.", symbolName: "star.circle.fill", target: 1) { facts in
            facts.lessonResults.values.filter { $0.isCompleted && !$0.viaPlacement && $0.stars == 3 }.count
        },
        Achievement(id: "combo-5", title: "Combo ×5", detail: "Löse 5 Aufgaben in Folge beim ersten Versuch.", symbolName: "bolt.fill", target: 5) {
            $0.bestCombo
        },
        Achievement(id: "combo-10", title: "Unaufhaltsam", detail: "Löse 10 Aufgaben in Folge beim ersten Versuch.", symbolName: "bolt.horizontal.fill", target: 10) {
            $0.bestCombo
        },
        Achievement(id: "streak-3", title: "Dranbleiber", detail: "Lerne 3 Tage in Folge.", symbolName: "flame", target: 3) {
            $0.longestStreak
        },
        Achievement(id: "streak-7", title: "Wochenkrieger", detail: "Lerne 7 Tage in Folge.", symbolName: "flame.fill", target: 7) {
            $0.longestStreak
        },
        Achievement(id: "coder", title: "Selbst geschrieben", detail: "Löse 5 Aufgaben, in denen du eigenen Code schreibst.", symbolName: "chevron.left.forwardslash.chevron.right", target: 5) {
            $0.solvedCount(of: .code)
        },
        Achievement(id: "bug-hunter", title: "Bug-Jäger", detail: "Finde den Fehler in 5 Bug-Jagden.", symbolName: "ant.fill", target: 5) {
            $0.solvedCount(of: .findBug)
        },
        Achievement(id: "puzzler", title: "Puzzle-Profi", detail: "Löse 5 Code-Puzzles.", symbolName: "puzzlepiece.fill", target: 5) {
            $0.solvedCount(of: .ordering)
        },
        Achievement(id: "first-mission", title: "Roboter-Pilot", detail: "Schaffe deine erste Arena-Mission.", symbolName: "gamecontroller.fill", target: 1) {
            $0.missionStars.count
        },
        Achievement(id: "star-collector", title: "Sternensammler", detail: "Sammle 15 Sterne in der Arena.", symbolName: "sparkles", target: 15) {
            $0.missionStars.values.reduce(0, +)
        },
        Achievement(id: "boss", title: "Bossbezwinger", detail: "Besiege ein Boss-Level.", symbolName: "shield.lefthalf.filled", target: 1) { facts in
            facts.missionStars.keys.filter { facts.catalog.mission(id: $0)?.kind == .boss }.count
        },
        Achievement(id: "all-bosses", title: "Endgegner", detail: "Besiege alle Boss-Level.", symbolName: "crown.fill", target: 3) { facts in
            facts.missionStars.keys.filter { facts.catalog.mission(id: $0)?.kind == .boss }.count
        },
        Achievement(id: "daily-3", title: "Tagesheld", detail: "Schaffe 3 tägliche Missionen.", symbolName: "sun.max.fill", target: 3) {
            $0.dailyCompletions
        },
        Achievement(id: "training-10", title: "Wiederholungstäter", detail: "Löse 10 Aufgaben im Training oder in der Wiederholung.", symbolName: "arrow.triangle.2.circlepath", target: 10) {
            $0.taskAttempts.filter { $0.context == .training && $0.solved }.count
        },
        Achievement(id: "module-1", title: "Grundlagen sitzen", detail: "Schließe Modul 1 ab.", symbolName: "1.circle.fill", target: 1) { facts in
            let lessons = facts.course.modules.first?.lessons.map(\.id) ?? []
            return !lessons.isEmpty && lessons.allSatisfy(facts.completedLessonIds.contains) ? 1 : 0
        },
        Achievement(id: "level-5", title: "Aufsteiger", detail: "Erreiche Level 5.", symbolName: "arrow.up.forward.circle.fill", target: 5) {
            Experience.level(for: $0.experience).level
        },
        Achievement(id: "course", title: "Java Master", detail: "Schließe alle Lektionen ab.", symbolName: "trophy.fill", target: 13) {
            $0.completedLessonIds.count
        },
    ]

    public static func unlocked(_ facts: LearnerFacts) -> Set<String> {
        Set(all.filter { $0.isUnlocked(facts) }.map(\.id))
    }
}

// MARK: - Tägliche Mission

public enum DailyMission {
    /// Missionen, die man spielen darf: Lektion erreicht (Lektion/Training) bzw. Modul geschafft (Boss).
    public static func availableMissions(catalog: ArenaCatalog, course: Course, results: [String: LessonResult]) -> [ArenaMission] {
        let states = LearningPath.states(course: course, results: results)
        return catalog.missions.filter { isUnlocked($0, course: course, results: results, states: states) }
    }

    public static func isUnlocked(_ mission: ArenaMission, course: Course, results: [String: LessonResult], states: [String: LessonState]? = nil) -> Bool {
        let states = states ?? LearningPath.states(course: course, results: results)
        switch mission.kind {
        case .lesson:
            return states[mission.lessonId]?.isPlayable == true
        case .training:
            return results[mission.lessonId]?.isCompleted == true
        case .boss:
            guard let module = course.modules.first(where: { $0.id == mission.moduleId }) else { return false }
            return module.lessons.allSatisfy { results[$0.id]?.isCompleted == true }
        }
    }

    /// Die Mission des Tages: deterministisch je Kalendertag, bevorzugt Trainingsmissionen
    /// und Missionen, die noch nicht alle Sterne haben.
    public static func mission(for day: Date, available: [ArenaMission], stars: [String: Int]) -> ArenaMission? {
        guard !available.isEmpty else { return nil }
        let unfinished = available.filter { (stars[$0.id] ?? 0) < 3 }
        let pool = unfinished.isEmpty ? available : unfinished
        let dayNumber = Int(Calendar.current.startOfDay(for: day).timeIntervalSinceReferenceDate / 86_400)
        let sorted = pool.sorted { ($0.kind == .training ? 0 : 1, $0.id) < ($1.kind == .training ? 0 : 1, $1.id) }
        return sorted[((dayNumber % sorted.count) + sorted.count) % sorted.count]
    }
}
