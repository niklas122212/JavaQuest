import Foundation
import Testing
@testable import JavaQuestKit

@Suite("Verteiltes Wiederholen")
struct SpacedRepetitionTests {
    let course: Course

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    /// Zwei Aufgaben desselben Lernziels – damit sich prüfen lässt, dass über Varianten
    /// hinweg gezählt wird und nicht je Aufgabe.
    var goalWithTwoVariants: (key: String, tasks: [LearningTask]) {
        let byGroup = Dictionary(grouping: course.practiceableTasks, by: \.groupKey)
        let pick = byGroup.first { $0.value.count >= 2 }!
        return (pick.key, pick.value)
    }

    func day(_ offset: Double) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + offset * 86_400) }

    @Test("Die Serie zählt über Varianten hinweg – und ein Fehler setzt sie zurück")
    func streakCountsAcrossVariants() {
        let (key, tasks) = goalWithTwoVariants
        let records = [
            AttemptRecord(taskId: tasks[0].id, credit: 1, date: day(0)),
            AttemptRecord(taskId: tasks[1].id, credit: 1, date: day(1)),
            AttemptRecord(taskId: tasks[0].id, credit: 1, date: day(2)),
        ]
        let goals = SpacedRepetition.goals(from: records, course: course)
        #expect(goals[key]?.streak == 3)
        #expect(goals[key]?.attempts == 3)

        // Ein Fehler am Ende wirft das Lernziel zurück in Fach 0.
        let mitFehler = records + [AttemptRecord(taskId: tasks[1].id, credit: 0, date: day(3))]
        let danach = SpacedRepetition.goals(from: mitFehler, course: course)
        #expect(danach[key]?.streak == 0)
        #expect(danach[key]?.box == 0)
        #expect(danach[key]?.attempts == 4)
    }

    @Test("Halbe Wertung zählt nicht als Treffer")
    func halfCreditBreaksStreak() {
        let (key, tasks) = goalWithTwoVariants
        let goals = SpacedRepetition.goals(from: [
            AttemptRecord(taskId: tasks[0].id, credit: 1, date: day(0)),
            AttemptRecord(taskId: tasks[1].id, credit: 0.5, date: day(1)),
        ], course: course)
        #expect(goals[key]?.streak == 0)
    }

    @Test("Die Pausen wachsen: 1, 3, 7, 16, 35 Tage")
    func intervalsGrow() {
        let erwartet: [Double] = [0, 1, 3, 7, 16, 35]
        #expect(SpacedRepetition.intervalDays == erwartet)
        for streak in 0...8 {
            let goal = GoalHistory(attempts: streak, streak: streak, lastCredit: 1, lastDate: day(0))
            #expect(goal.box == min(streak, 5))
            #expect(goal.intervalDays == erwartet[min(streak, 5)])
        }
    }

    @Test("Vor dem Termin gedämpft, danach angehoben")
    func factorFollowsSchedule() {
        // Dreimal in Folge getroffen → Fach 3 → sieben Tage Pause.
        let goal = GoalHistory(attempts: 3, streak: 3, lastCredit: 1, lastDate: day(0))
        #expect(goal.intervalDays == 7)

        // Direkt danach: stark gedämpft.
        #expect(SpacedRepetition.factor(for: goal, at: day(0)) == SpacedRepetition.minimumFactor)
        // Auf halbem Weg: schon wieder deutlich häufiger.
        let mitte = SpacedRepetition.factor(for: goal, at: day(3.5))
        #expect(mitte > SpacedRepetition.minimumFactor && mitte < 1)
        // Am Termin: normal.
        #expect(abs(SpacedRepetition.factor(for: goal, at: day(7)) - 1) < 0.001)
        // Doppelt überfällig: doppeltes Gewicht, aber nicht mehr.
        #expect(SpacedRepetition.factor(for: goal, at: day(14)) == 2)
        #expect(SpacedRepetition.factor(for: goal, at: day(400)) == 2)
    }

    @Test("Was zuletzt gehakt hat, wird nicht gedämpft")
    func missedGoalsAreNotDamped() {
        let goal = GoalHistory(attempts: 4, streak: 0, lastCredit: 0, lastDate: day(0))
        #expect(SpacedRepetition.factor(for: goal, at: day(0)) == 1)
        #expect(goal.isDue(at: day(0)))
    }

    @Test("Ohne Vorgeschichte bleibt alles wie bisher")
    func unknownGoalsAreNeutral() {
        #expect(SpacedRepetition.factor(for: nil, at: day(0)) == 1)
    }

    @Test("Die Wiederholung nimmt nur, was fällig ist")
    func reviewPoolOnlyContainsDueGoals() {
        let (key, tasks) = goalWithTwoVariants
        let anderes = course.practiceableTasks.first { $0.groupKey != key }!

        // Dieses Lernziel saß dreimal und hat noch sechs Tage Pause.
        let frisch = GoalHistory(attempts: 3, streak: 3, lastCredit: 1, lastDate: day(1))
        // Jenes ist seit Langem überfällig.
        let alt = GoalHistory(attempts: 2, streak: 2, lastCredit: 1, lastDate: day(-30))
        let goals = [key: frisch, anderes.groupKey: alt]

        let pool = TrainingBuilder.reviewPool(course: course, goals: goals, now: day(2))
        let keys = Set(pool.map(\.groupKey))
        #expect(!keys.contains(key))
        #expect(keys.contains(anderes.groupKey))
        #expect(Set(tasks.map(\.id)).isDisjoint(with: Set(pool.map(\.id))))
    }

    @Test("Gemessen: frisch Gesessenes kommt im Training deutlich seltener dran")
    func recentlyMasteredAppearsLessOften() {
        let pool = VariantSelector.collapse(Array(course.practiceableTasks.prefix(400)), history: [:])
        let frischesZiel = pool[0].groupKey
        let faelligesZiel = pool[1].groupKey

        let jetzt = day(10)
        let goals = [
            // Dreimal in Folge gesessen, heute geübt → sieben Tage Ruhe.
            frischesZiel: GoalHistory(attempts: 3, streak: 3, lastCredit: 1, lastDate: jetzt),
            // Ebenfalls gekonnt, aber die Pause ist längst vorbei.
            faelligesZiel: GoalHistory(attempts: 3, streak: 3, lastCredit: 1, lastDate: day(-10)),
        ]
        let history = [
            pool[0].id: TaskHistory(attempts: 3, lastCredit: 1, lastDate: jetzt),
            pool[1].id: TaskHistory(attempts: 3, lastCredit: 1, lastDate: day(-10)),
        ]

        var frisch = 0, faellig = 0
        for seed in 1...400 {
            let runde = TrainingBuilder.round(
                from: pool, topicStats: [:], history: history, goals: goals,
                now: jetzt, size: 8, seed: UInt64(seed)
            )
            for task in runde {
                if task.groupKey == frischesZiel { frisch += 1 }
                if task.groupKey == faelligesZiel { faellig += 1 }
            }
        }
        #expect(faellig > frisch * 3, "fällig \(faellig), frisch \(frisch)")
    }
}

@Suite("Schwächen nach Schwierigkeitsstufe")
struct LevelPerformanceTests {
    let course: Course

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    /// Ein Thema, das auf jeder Stufe genug Aufgaben hat – seit der Auffüllaktion sind das alle.
    let topicId = "inheritance"

    @Test("Leichte Stufen sitzen, schwere nicht – genau das wird sichtbar")
    func weakLevelsAreFound() {
        var history: [String: TaskHistory] = [:]
        for task in course.tasks(forTopic: topicId) {
            // Bis Stufe 3 alles richtig, ab Stufe 4 alles falsch.
            let credit: Double = task.difficulty.rawValue <= 3 ? 1 : 0
            history[task.id] = TaskHistory(attempts: 1, lastCredit: credit, lastDate: .now)
        }
        let levels = WeakSpotFinder.levels(course: course, history: history, topicId: topicId)
        #expect(levels.count == 5)
        #expect(levels.map(\.difficulty.rawValue) == [1, 2, 3, 4, 5])
        for level in levels {
            #expect(level.isWeak == (level.difficulty.rawValue >= 4), "\(level.summary)")
        }
        let weak = WeakSpotFinder.weakDifficulties(course: course, history: history, topicId: topicId)
        #expect(weak == [.demanding, .hard])
    }

    @Test("Ein einzelner Fehlversuch macht noch keine Schwäche")
    func oneMissIsNotAWeakness() {
        let einmal = LevelPerformance(difficulty: .medium, seen: 1, solved: 0)
        #expect(!einmal.isWeak)
        let mehrfach = LevelPerformance(difficulty: .medium, seen: 3, solved: 0)
        #expect(mehrfach.isWeak)
    }

    @Test("Genau an der Bestehensgrenze gilt eine Stufe noch als sicher")
    func thresholdIsShared() {
        // 69 % ist bestanden – dieselbe Grenze wie bei den Lektionen, nicht eine zweite Zahl.
        let knappDrueber = LevelPerformance(difficulty: .demanding, seen: 100, solved: 69)
        #expect(!knappDrueber.isWeak)
        let knappDrunter = LevelPerformance(difficulty: .demanding, seen: 100, solved: 68)
        #expect(knappDrunter.isWeak)
    }

    @Test("Stufen ohne Vorgeschichte tauchen nicht auf")
    func untouchedLevelsAreOmitted() {
        let levels = WeakSpotFinder.levels(course: course, history: [:], topicId: topicId)
        #expect(levels.isEmpty)
    }
}
