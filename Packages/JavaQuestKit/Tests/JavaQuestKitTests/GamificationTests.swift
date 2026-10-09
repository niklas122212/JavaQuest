import Foundation
import Testing
@testable import JavaQuestKit

@Suite("Motivation: XP, Abzeichen, Tagesmission")
struct GamificationTests {
    let course: Course
    let catalog: ArenaCatalog
    let day = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!

    init() throws {
        course = try CourseLoader.loadBundled()
        catalog = try ArenaCatalog.loadBundled()
    }

    func attempt(_ id: String, _ context: ActivityRecord.Context = .lesson, difficulty: Int = 2, solved: Bool = true, tries: Int = 1, daysAgo: Int = 0, credit: Double = 1) -> ActivityRecord {
        ActivityRecord(taskId: id, topicId: "loops", context: context, difficulty: difficulty, credit: credit, solved: solved, tries: tries,
                      date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: day)!)
    }

    func facts(_ attempts: [ActivityRecord], results: [String: LessonResult] = [:], streak: Int = 0) -> LearnerFacts {
        LearnerFacts(course: course, catalog: catalog, attempts: attempts, lessonResults: results, longestStreak: streak)
    }

    @Test("XP: erster Versuch zählt doppelt, Missionen nach Bestwert, Boss-Sterne mehr")
    func experiencePoints() {
        let xp = facts([
            attempt("t01-1", difficulty: 1),                 // 10
            attempt("t01-3", difficulty: 2, tries: 2),       // 10
            attempt("t01-4", solved: false, tries: 3),       // 2
            attempt("a01-erste-schritte", .mission, credit: ActivityRecord.credit(forStars: 2)),
            attempt("a01-erste-schritte", .mission, credit: ActivityRecord.credit(forStars: 3)), // Bestwert 3 × 25
            attempt("b1-tunnelschatz", .mission, credit: ActivityRecord.credit(forStars: 1)),    // 1 × 50
        ]).experience
        #expect(xp == 10 + 10 + 2 + 75 + 50)
    }

    @Test("Level-Kurve: 100, 300, 600 … XP")
    func levels() {
        #expect(Experience.level(for: 0).level == 1)
        #expect(Experience.level(for: 99).level == 1)
        #expect(Experience.level(for: 100).level == 2)
        #expect(Experience.level(for: 300).level == 3)
        let progress = Experience.level(for: 200)
        #expect(progress.level == 2 && progress.fraction == 0.5 && progress.remaining == 100)
    }

    @Test("Abzeichen: Combo, Bug-Jäger, Boss")
    func achievements() {
        let combo = facts((1...5).map { attempt("t0\($0)-1") })
        #expect(Achievement.unlocked(combo).contains("combo-5"))
        #expect(!Achievement.unlocked(combo).contains("combo-10"))

        let broken = facts([attempt("t01-1"), attempt("t01-2"), attempt("t01-3", tries: 2), attempt("t01-4"), attempt("t01-5")])
        #expect(broken.bestCombo == 2)

        let bugs = facts(["t02-b", "t04-b", "t06-b", "t07-b", "t09-b"].map { attempt($0) })
        #expect(Achievement.unlocked(bugs).contains("bug-hunter"))

        let boss = facts([attempt("b2-labyrinth", .mission, credit: ActivityRecord.credit(forStars: 1))])
        #expect(Achievement.unlocked(boss).contains("boss"))
        #expect(Achievement.unlocked(boss).contains("first-mission"))
        #expect(!Achievement.unlocked(boss).contains("all-bosses"))
        #expect(Set(Achievement.all.map(\.id)).count == Achievement.all.count)
    }

    @Test("„Java Master“ gibt es erst, wenn wirklich alle Lektionen geschafft sind")
    func courseAchievementNeedsEveryLesson() {
        #expect(Achievement.courseLessons == course.allLessons.count, "Ziel des Abzeichens an den Kurs anpassen")
        var results: [String: LessonResult] = [:]
        for lesson in course.allLessons.dropLast() { results[lesson.id] = LessonResult(bestAccuracy: 1, isCompleted: true) }
        // Früher reichten 13 Lektionen
        #expect(!Achievement.unlocked(facts([], results: results)).contains("course"))
        results[course.allLessons.last!.id] = LessonResult(bestAccuracy: 1, isCompleted: true)
        #expect(Achievement.unlocked(facts([], results: results)).contains("course"))
    }

    @Test("Tägliche Mission: stabil pro Tag, nur freigeschaltete, Unfertiges zuerst")
    func dailyMission() throws {
        let fresh = DailyMission.availableMissions(catalog: catalog, course: course, results: [:])
        #expect(fresh.map(\.id) == ["a01-erste-schritte"], "Am Anfang ist nur die erste Mission spielbar")

        var results: [String: LessonResult] = [:]
        for lesson in course.allLessons.prefix(6) { results[lesson.id] = LessonResult(bestAccuracy: 1, isCompleted: true) }
        let available = DailyMission.availableMissions(catalog: catalog, course: course, results: results)
        #expect(available.contains { $0.id == "b2-labyrinth" }, "Boss nach Abschluss von Modul 2")
        #expect(!available.contains { $0.id == "b3-codeknacker" })
        let first = try #require(DailyMission.mission(for: day, available: available, stars: [:]))
        #expect(DailyMission.mission(for: day.addingTimeInterval(3_600), available: available, stars: [:])?.id == first.id)
        let allThree = Dictionary(uniqueKeysWithValues: available.filter { $0.id != "t1-countdown" }.map { ($0.id, 3) })
        #expect(DailyMission.mission(for: day, available: available, stars: allThree)?.id == "t1-countdown")
    }

    @Test("Lektion endet mit Mission, Combos werden mitgezählt")
    func lessonWithMission() throws {
        let lesson = try #require(course.lesson(id: "l01-hello"))
        var session = LessonSession(lesson: lesson, missionId: "a01-erste-schritte")
        while case .theory = session.phase { session.advanceTheory() }
        let evaluator = AnswerEvaluator()
        for (index, task) in session.tasks.enumerated() {
            let answer = index == 2 ? PreviewAnswers.wrong(task) : evaluator.referenceAnswer(for: task)
            session.submit(answer)
            if !session.isCurrentTaskFinished { session.revealSolution() }
            session.advanceToNextTask()
        }
        #expect(session.phase == .mission(id: "a01-erste-schritte"))
        #expect(session.bestCombo == 3)
        #expect(session.currentCombo == 3)
        #expect(session.progress < 1)
        session.finishMission()
        #expect(session.phase == .summary)
    }
}

enum PreviewAnswers {
    static func wrong(_ task: LearningTask) -> TaskAnswer {
        switch task.kind {
        case .singleChoice(let spec): .choice((spec.correctIndex + 1) % spec.choices.count)
        case .fillBlank(let spec): .blanks(Array(repeating: "???", count: spec.blanks.count))
        case .predictOutput: .text("???")
        case .code: .text("???")
        case .ordering(let spec): .order(spec.shuffledOrder(seed: task.id))
        case .findBug(let spec): .line(spec.bugLine == 1 ? 2 : 1)
        }
    }
}

@Suite("Tagesmission bleibt den ganzen Tag gleich")
struct DailyStabilityTests {
    @Test("Neue Sterne am selben Tag ändern die Tagesmission nicht, die geschaffte bleibt sichtbar")
    func stableDuringDay() throws {
        let course = try CourseLoader.loadBundled()
        let catalog = try ArenaCatalog.loadBundled()
        var results: [String: LessonResult] = [:]
        for lesson in course.allLessons.prefix(6) { results[lesson.id] = LessonResult(bestAccuracy: 1, isCompleted: true) }
        let available = DailyMission.availableMissions(catalog: catalog, course: course, results: results)
        let morning = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 8))!
        let start = LearnerFacts(course: course, catalog: catalog, attempts: [], lessonResults: results, longestStreak: 0)
        let daily = try #require(start.dailyMission(on: morning, available: available))

        // Mittags: 3 Sterne in genau dieser Mission, aber nicht als Tagesmission gezählt.
        let noon = morning.addingTimeInterval(4 * 3600)
        let played = ActivityRecord(taskId: daily.id, topicId: daily.topicId, context: .mission, difficulty: 2, credit: 1, solved: true, tries: 1, date: noon)
        let later = LearnerFacts(course: course, catalog: catalog, attempts: [played], lessonResults: results, longestStreak: 0)
        #expect(later.dailyMission(on: noon, available: available)?.id == daily.id)

        let done = ActivityRecord(taskId: daily.id, topicId: daily.topicId, context: .daily, difficulty: 2, credit: 1, solved: true, tries: 1, date: noon)
        let finished = LearnerFacts(course: course, catalog: catalog, attempts: [played, done], lessonResults: results, longestStreak: 0)
        #expect(finished.isDailyDone(on: noon))
        #expect(finished.dailyMission(on: noon, available: available)?.id == daily.id)
    }
}

@Suite("Bonus-Aufgaben verändern nichts am bestehenden Lernstand")
struct BonusTaskTests {
    @Test("Master Score ist mit und ohne Bonus-Aufgaben gleich – wie auf Windows, Android und Web")
    func masterScoreUnchanged() throws {
        let url = try #require(CourseLoader.resourceBundle.url(forResource: CourseLoader.bundledResourceName, withExtension: "json"))
        let shared = try CourseLoader.load(from: Data(contentsOf: url))   // so lesen es die anderen Plattformen
        let apple = try CourseLoader.loadBundled()                          // mit Puzzle und Bug-Jagd
        #expect(apple.allLessons.flatMap(\.tasks).count == shared.allLessons.flatMap(\.tasks).count + 35)
        for (index, lessons) in [3, 9, 20, 35].enumerated() {
            var results: [String: LessonResult] = [:]
            for (i, lesson) in shared.allLessons.prefix(lessons).enumerated() {
                results[lesson.id] = LessonResult(bestAccuracy: [1, 0.8, 0.95, 0.7][(i + index) % 4], isCompleted: true)
            }
            #expect(MasterScore.compute(course: apple, results: results) == MasterScore.compute(course: shared, results: results))
        }
    }

    @Test("Eine Lektion mit falsch gelöster Bonus-Aufgabe ist trotzdem perfekt")
    func bonusDoesNotLowerAccuracy() throws {
        let course = try CourseLoader.loadBundled()
        let lesson = try #require(course.lesson(id: "l02-variables"))
        var session = LessonSession(lesson: lesson)
        while case .theory = session.phase { session.advanceTheory() }
        let evaluator = AnswerEvaluator()
        while let task = session.currentTask {
            if task.type.isBonus { session.revealSolution() } else { session.submit(evaluator.referenceAnswer(for: task)) }
            session.advanceToNextTask()
        }
        #expect(session.summary.accuracy == 1)
        #expect(session.summary.passed)
    }
}
