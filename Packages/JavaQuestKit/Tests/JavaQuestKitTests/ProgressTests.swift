import Foundation
import Testing
@testable import JavaQuestKit

@Suite("Einstufungstest")
struct PlacementTests {
    let course: Course
    let evaluator = AnswerEvaluator()

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    func run(_ level: ExperienceLevel, answer: (LearningTask) -> Bool) -> PlacementTest {
        var test = PlacementTest(course: course, level: level)!
        while let task = test.currentTask {
            let result = answer(task)
                ? evaluator.evaluate(evaluator.referenceAnswer(for: task), for: task)
                : EvaluationResult(isCorrect: false, score: 0, findings: [])
            test.submit(result)
        }
        return test
    }

    /// Beantwortet die einzige Einstufungsfrage mit `correctBlanks` richtigen Lücken.
    func runPartial(correctBlanks: Int) -> PlacementTest {
        var test = PlacementTest(course: course, level: .intermediate)!
        let task = test.currentTask!
        guard case .fillBlank(let spec) = task.kind else { Issue.record("Einstufungsfrage ist kein Lückentext"); return test }
        let answers = spec.blanks.enumerated().map { index, blank in index < correctBlanks ? blank.accepted[0] : "falsch" }
        test.submit(evaluator.evaluate(.blanks(answers), for: task))
        return test
    }

    @Test("Nur „Ich habe schon Vorkenntnisse“ führt zur Einstufungsfrage")
    func onlyIntermediateIsPlaced() {
        #expect(ExperienceLevel.onboardingChoices == [.beginner, .intermediate])
        #expect(ExperienceLevel.beginner.onboardingTitle == "Ich habe 0 Erfahrung")
        #expect(ExperienceLevel.intermediate.onboardingTitle == "Ich habe schon Vorkenntnisse")
        #expect(PlacementTest(course: course, level: .beginner) == nil)
        #expect(PlacementTest(course: course, level: .intermediate) != nil)
    }

    @Test("Genau eine Frage mit sechs Lücken, Schwelle 65 %")
    func singleQuestion() {
        let test = PlacementTest(course: course, level: .intermediate)!
        #expect(test.questionCount == 1)
        #expect(test.passThreshold == 65)
        guard case .fillBlank(let spec) = test.currentTask?.kind else { Issue.record("kein Lückentext"); return }
        #expect(spec.blanks.count == 6)
    }

    @Test("Alles richtig → 100 %, Einstieg bei Objekten, Grundkurs angerechnet")
    func allCorrect() {
        let test = run(.intermediate) { _ in true }
        #expect(test.answers.count == 1)
        #expect(test.isFinished)
        #expect(test.scorePercent == 100)
        let outcome = test.outcome(in: course)
        #expect(outcome.passed)
        #expect(outcome.entryModuleId == "m3-objects")
        #expect(outcome.creditedLessonIds.count == 6)
        #expect(outcome.creditedAccuracy == 1)
    }

    @Test("Alles falsch → 0 %, Start im Grundkurs")
    func allWrong() {
        let outcome = run(.intermediate) { _ in false }.outcome(in: course)
        #expect(outcome.scorePercent == 0)
        #expect(!outcome.passed)
        #expect(outcome.placedLevel == .beginner)
        #expect(outcome.entryModuleId == "m1-first-steps")
        #expect(outcome.creditedLessonIds.isEmpty)
    }

    @Test("Teilpunkte: 4 von 6 Lücken (67 %) bestehen, 3 von 6 (50 %) nicht")
    func partialCredit() {
        let four = runPartial(correctBlanks: 4)
        #expect(four.scorePercent == 67)
        #expect(four.passed)
        #expect(four.outcome(in: course).entryModuleId == "m3-objects")

        let three = runPartial(correctBlanks: 3)
        #expect(three.scorePercent == 50)
        #expect(!three.passed)
        #expect(three.outcome(in: course).placedLevel == .beginner)
    }
}

@Suite("Lern-Loop")
struct LessonSessionTests {
    let course: Course
    let evaluator = AnswerEvaluator()

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    @Test("Theorie → Aufgaben → Auswertung, erster Versuch zählt voll")
    func happyPath() {
        let lesson = course.allLessons[0]
        var session = LessonSession(lesson: lesson)
        #expect(session.phase == .theory(page: 0))
        for _ in lesson.theory { session.advanceTheory() }
        #expect(session.phase == .task(index: 0))
        while let task = session.currentTask {
            session.submit(evaluator.referenceAnswer(for: task))
            #expect(session.finishedOutcome?.credit == 1)
            session.advanceToNextTask()
        }
        #expect(session.phase == .summary)
        #expect(session.summary.accuracy == 1)
        #expect(session.summary.stars == 3)
        #expect(session.summary.passed)
    }

    @Test("Bestanden erst ab 90 %, Sterne bei 90 / 95 / 100 %")
    func passThresholdAndStars() {
        #expect(LessonSession.passThreshold == 0.9)
        #expect(Stars.forAccuracy(0.89) == 0)
        #expect(Stars.forAccuracy(0.9) == 1)
        #expect(Stars.forAccuracy(0.94) == 1)
        #expect(Stars.forAccuracy(0.95) == 2)
        #expect(Stars.forAccuracy(1) == 3)
    }

    @Test("Halbe Punkte auf der schwersten Aufgabe → unter 90 %, nicht bestanden")
    func ninetyPercentIsStrict() {
        let lesson = course.allLessons[0]
        var session = LessonSession(mode: .lesson(lessonId: lesson.id), title: "", theory: [], tasks: lesson.tasks)
        let lastIndex = lesson.tasks.count - 1
        var index = 0
        while let task = session.currentTask {
            if index == lastIndex {
                session.submit(.choice(99))
                session.prepareRetry()
            }
            session.submit(evaluator.referenceAnswer(for: task))
            session.advanceToNextTask()
            index += 1
        }
        let weights = lesson.tasks.map(\.difficulty.weight)
        let expected = (weights.dropLast().reduce(0, +) + weights.last! * 0.5) / weights.reduce(0, +)
        #expect(abs(session.summary.accuracy - expected) < 0.0001)
        #expect(session.summary.passed == (expected >= 0.9))
        #expect(!session.summary.passed, "Halbe Punkte auf die schwerste Aufgabe drücken unter 90 %")
    }

    @Test("Zweiter Versuch zählt halb, Lösung zeigen zählt nichts")
    func retryAndReveal() {
        let lesson = course.allLessons[1]
        var session = LessonSession(mode: .lesson(lessonId: lesson.id), title: "", theory: [], tasks: Array(lesson.tasks.prefix(2)))
        let first = session.currentTask!
        session.submit(.choice(99))
        #expect(session.canRetry)
        session.prepareRetry()
        session.submit(evaluator.referenceAnswer(for: first))
        #expect(session.finishedOutcome?.credit == 0.5)
        session.advanceToNextTask()

        session.submit(.blanks(["falsch"]))
        session.revealSolution()
        #expect(session.finishedOutcome?.credit == 0)
        session.advanceToNextTask()
        #expect(session.phase == .summary)
        // Gewichtet: (1 × 0,5 + 2 × 0) / 3
        #expect(abs(session.summary.accuracy - 0.5 / 3) < 0.0001)
        #expect(!session.summary.passed)
    }

    @Test("Nach drei Fehlversuchen bleibt nur „Lösung zeigen“")
    func attemptLimit() {
        var session = LessonSession(mode: .practice(topicId: "x"), title: "", theory: [], tasks: [course.allLessons[0].tasks[0]])
        for _ in 0..<LessonSession.maxAttempts {
            session.submit(.choice(99))
            session.prepareRetry()
        }
        #expect(!session.canRetry)
        #expect(session.submit(.choice(0)) == nil)
    }
}

@Suite("Score, Lernpfad, Wissensanalyse")
struct ProgressTests {
    let course: Course

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    @Test("Master Score: 0 ohne Fortschritt, 1000 bei allem mit 100 %")
    func scoreBounds() {
        #expect(MasterScore.compute(course: course, results: [:]) == 0)
        let perfect = Dictionary(uniqueKeysWithValues: course.allLessons.map { ($0.id, LessonResult(bestAccuracy: 1, isCompleted: true)) })
        #expect(MasterScore.compute(course: course, results: perfect) == 1000)
    }

    @Test("Master Score steigt mit jeder gelösten Lektion")
    func scoreIsMonotonic() {
        var results: [String: LessonResult] = [:]
        var previous = 0
        for lesson in course.allLessons {
            results[lesson.id] = LessonResult(bestAccuracy: 0.8, isCompleted: true)
            let score = MasterScore.compute(course: course, results: results)
            #expect(score > previous, "\(lesson.id)")
            previous = score
        }
        // Nicht abgeschlossene Lektionen zählen nicht.
        let unfinished = [course.allLessons[0].id: LessonResult(bestAccuracy: 1, isCompleted: false)]
        #expect(MasterScore.compute(course: course, results: unfinished) == 0)
    }

    @Test("Ränge und Fortschritt zum nächsten Rang")
    func ranks() {
        #expect(MasterRank.rank(for: 0).title == "Neuling")
        #expect(MasterRank.rank(for: 1000).title == "Java Master")
        #expect(MasterRank.next(after: 1000) == nil)
        #expect(MasterRank.progressToNext(for: 75) == 0.5)
    }

    @Test("Lernpfad ist linear, Einstufung schaltet frei")
    func pathStates() {
        let lessons = course.allLessons
        let fresh = LearningPath.states(course: course, results: [:])
        #expect(fresh[lessons[0].id] == .current)
        #expect(fresh[lessons[1].id] == .locked)

        var placed: [String: LessonResult] = [:]
        for lesson in lessons.prefix(6) { placed[lesson.id] = LessonResult(bestAccuracy: 0.95, isCompleted: true, viaPlacement: true) }
        let states = LearningPath.states(course: course, results: placed)
        #expect(states[lessons[5].id] == .completed(stars: 2, viaPlacement: true))
        #expect(states[lessons[6].id] == .current)
        #expect(LearningPath.nextLesson(course: course, results: placed)?.id == lessons[6].id)
        let modules = LearningPath.moduleProgress(course: course, results: placed)
        #expect(modules[0].isCompleted && modules[1].isCompleted)
        #expect(modules[2].isUnlocked && !modules[3].isUnlocked)
    }

    @Test("Wissensanalyse: unbekannt, Lücke, im Aufbau, Stärke")
    func classification() {
        let now = Date()
        var gap = TopicStats()
        gap.record(difficulty: .medium, credit: 0, at: now)
        gap.record(difficulty: .hard, credit: 0.5, at: now)
        var strength = TopicStats()
        for difficulty in [Difficulty.easy, .medium, .demanding, .hard] { strength.record(difficulty: difficulty, credit: 1, at: now) }
        var single = TopicStats()
        single.record(difficulty: .hard, credit: 0, at: now)

        #expect(KnowledgeAnalyzer.classify(TopicStats()) == .unknown)
        #expect(KnowledgeAnalyzer.classify(gap) == .gap)
        #expect(KnowledgeAnalyzer.classify(strength) == .strength)
        #expect(KnowledgeAnalyzer.classify(single) == .developing, "Ein einzelner Fehler ist noch keine Lücke")

        let report = KnowledgeAnalyzer.report(course: course, stats: ["loops": gap, "variables": strength])
        #expect(report.gaps.map(\.topic.id) == ["loops"])
        #expect(report.strengths.map(\.topic.id) == ["variables"])
        #expect(report.unknown.count == course.topics.count - 2)
        #expect(report.focusTopic?.topic.id == "loops")
        #expect(report.gaps.first?.lessonId == "l05-loops")
    }

    @Test("Übungssitzung: nur freigeschaltete Lektionen, aufsteigend, begrenzt")
    func practiceTasks() {
        let unlocked = Set(course.allLessons.prefix(7).map(\.id))
        let tasks = PracticeBuilder.tasks(for: "loops", in: course, unlockedLessonIds: unlocked)
        #expect(!tasks.isEmpty && tasks.count <= 5)
        #expect(tasks.allSatisfy { $0.topicId == "loops" })
        #expect(tasks.map(\.difficulty) == tasks.map(\.difficulty).sorted())
        #expect(PracticeBuilder.tasks(for: "lambdas", in: course, unlockedLessonIds: unlocked).isEmpty)
    }

    @Test("Endlos-Training: nur abgeschlossene Lektionen, 8 verschiedene Aufgaben, aufsteigend")
    func trainingRound() {
        #expect(TrainingBuilder.pool(course: course, completedLessonIds: []).isEmpty)
        let completed = Set(course.allLessons.prefix(4).map(\.id))
        let pool = TrainingBuilder.pool(course: course, completedLessonIds: completed)
        let allowed = Set(course.allLessons.prefix(4).flatMap(\.tasks).map(\.id))
        #expect(Set(pool.map(\.id)) == allowed)

        let round = TrainingBuilder.round(from: pool, topicStats: [:], history: [:], seed: 42)
        #expect(round.count == TrainingBuilder.roundSize)
        #expect(Set(round.map(\.id)).count == round.count, "keine Aufgabe doppelt")
        #expect(round.allSatisfy { allowed.contains($0.id) })
        #expect(round.map(\.difficulty) == round.map(\.difficulty).sorted())
        #expect(round.map(\.id) == TrainingBuilder.round(from: pool, topicStats: [:], history: [:], seed: 42).map(\.id))
        #expect(round.map(\.id) != TrainingBuilder.round(from: pool, topicStats: [:], history: [:], seed: 7).map(\.id))

        let small = Array(pool.prefix(3))
        #expect(Set(TrainingBuilder.round(from: small, topicStats: [:], history: [:], seed: 1).map(\.id)) == Set(small.map(\.id)))
    }

    @Test("Endlos-Training: Fehler, Lücken und Vergessenes kommen öfter dran")
    func trainingWeights() {
        let now = Date()
        let task = course.allLessons[0].tasks[0]
        func weight(_ history: TaskHistory?, _ stats: TopicStats? = nil) -> Double {
            TrainingBuilder.weight(
                for: task,
                topicStats: stats.map { [task.topicId: $0] } ?? [:],
                history: history.map { [task.id: $0] } ?? [:],
                now: now
            )
        }
        let solvedToday = TaskHistory(attempts: 1, lastCredit: 1, lastDate: now)
        let solvedLongAgo = TaskHistory(attempts: 1, lastCredit: 1, lastDate: now.addingTimeInterval(-20 * 86_400))
        let failed = TaskHistory(attempts: 1, lastCredit: 0, lastDate: now.addingTimeInterval(-2 * 86_400))
        var weak = TopicStats()
        weak.record(difficulty: .medium, credit: 0, at: now)
        weak.record(difficulty: .medium, credit: 0, at: now)
        var strong = TopicStats()
        for _ in 0..<4 { strong.record(difficulty: .medium, credit: 1, at: now) }

        #expect(weight(nil) > weight(solvedToday), "Neues vor gerade Gelöstem")
        #expect(weight(failed) > weight(solvedLongAgo), "Fehler vor Gelöstem")
        #expect(weight(solvedLongAgo) > weight(solvedToday), "lange nicht gesehen kommt wieder")
        #expect(weight(solvedLongAgo, weak) > weight(solvedLongAgo, strong), "schwaches Thema vor starkem")

        // Gemessen über viele Runden: eine falsch gelöste Aufgabe kommt deutlich öfter dran
        // als eine, die heute schon fehlerfrei gelöst wurde.
        let pool = TrainingBuilder.pool(course: course, completedLessonIds: Set(course.allLessons.prefix(6).map(\.id)))
        let wrong = pool[3], done = pool[4]
        let history = [
            wrong.id: TaskHistory(attempts: 2, lastCredit: 0, lastDate: now.addingTimeInterval(-86_400)),
            done.id: TaskHistory(attempts: 2, lastCredit: 1, lastDate: now),
        ]
        var wrongCount = 0, doneCount = 0
        for seed in 1...400 as ClosedRange<UInt64> {
            let ids = Set(TrainingBuilder.round(from: pool, topicStats: [:], history: history, now: now, seed: seed).map(\.id))
            if ids.contains(wrong.id) { wrongCount += 1 }
            if ids.contains(done.id) { doneCount += 1 }
        }
        #expect(wrongCount > doneCount * 3, "falsch: \(wrongCount)×, heute gelöst: \(doneCount)×")
    }

    @Test("Syntaxhervorhebung erkennt Schlüsselwörter, Strings und Kommentare")
    func highlighter() {
        let tokens = JavaHighlighter.tokenize("int x = 5; // Zahl\nString s = \"hi\";")
        #expect(tokens.contains { $0.kind == .keyword && $0.text == "int" })
        #expect(tokens.contains { $0.kind == .comment && $0.text == "// Zahl" })
        #expect(tokens.contains { $0.kind == .string && $0.text == "\"hi\"" })
        #expect(tokens.contains { $0.kind == .type && $0.text == "String" })
        #expect(tokens.map(\.text).joined() == "int x = 5; // Zahl\nString s = \"hi\";")
    }
}
