#if DEBUG
import Foundation
import JavaQuestKit

/// Beispielzustände für Xcode-Previews und Screenshots. Die Daten entstehen über
/// die echten Abläufe (Einstufungstest, Lektionen, Übungen) – nicht über Attrappen.
@MainActor
enum PreviewSupport {
    enum Scenario {
        case fresh
        case beginnerStarted
        case intermediateMidway
    }

    static func makeStore(_ scenario: Scenario = .intermediateMidway) -> ProgressStore {
        do {
            let course = try CourseLoader.loadBundled()
            let catalog = try ArenaCatalog.loadBundled()
            let container = try PersistenceController.makeContainer(inMemory: true)
            let store = ProgressStore(course: course, catalog: catalog, container: container)
            seed(store, scenario)
            return store
        } catch {
            fatalError("Preview-Daten konnten nicht erzeugt werden: \(error)")
        }
    }

    static func seed(_ store: ProgressStore, _ scenario: Scenario) {
        switch scenario {
        case .fresh:
            break
        case .beginnerStarted:
            store.completeOnboarding(level: .beginner, placement: nil)
            // Lektion 1 fehlerfrei (alle weiteren Aufgaben werden ebenfalls richtig beantwortet).
            playLesson(store, index: 0, firstTry: [true])
            playMission(store, "a01-erste-schritte")
        case .intermediateMidway:
            store.completeOnboarding(level: .intermediate, placement: placementRun(store.course, wrongAt: [1]))
            playLesson(store, index: 6, firstTry: [false])   // erste Aufgabe aufgedeckt, Rest richtig → bestanden
            playLesson(store, index: 7, firstTry: [true])    // fehlerfrei → 3 Sterne
            playPractice(store, topicId: "loops", firstTry: [false, true, false, false])
            playPractice(store, topicId: "methods", firstTry: [true, true, true, true])
            playMission(store, "a05-langer-gang")
            playMission(store, "b2-labyrinth")
        }
    }

    static func placementRun(_ course: Course, level: ExperienceLevel = .intermediate, wrongAt: Set<Int>) -> PlacementTest? {
        guard var test = PlacementTest(course: course, level: level) else { return nil }
        let evaluator = AnswerEvaluator()
        var index = 0
        while let task = test.currentTask {
            let answer = wrongAt.contains(index) ? wrongAnswer(for: task) : evaluator.referenceAnswer(for: task)
            test.submit(evaluator.evaluate(answer, for: task))
            index += 1
        }
        return test
    }

    /// `true` = beim ersten Versuch richtig, `false` = falsch versucht und Lösung aufgedeckt.
    static func playLesson(_ store: ProgressStore, index: Int, firstTry: [Bool]) {
        let lesson = store.course.allLessons[index]
        play(LessonFlowModel(request: SessionRequest(kind: .lesson(lesson.id)), store: store), theoryPages: lesson.theory.count, firstTry: firstTry)
    }

    static func playPractice(_ store: ProgressStore, topicId: String, firstTry: [Bool]) {
        play(LessonFlowModel(request: SessionRequest(kind: .practice(topicId: topicId)), store: store), theoryPages: 0, firstTry: firstTry)
    }

    /// Spielt eine Mission mit der Musterlösung (3 Sterne).
    static func playMission(_ store: ProgressStore, _ missionId: String) {
        guard let mission = store.catalog.mission(id: missionId) else { return }
        store.recordMission(mission, result: ArenaEngine.run(mission.solution.source, mission: mission))
    }

    /// Spielt die Sitzung bis zum Ende: `firstTry` legt die ersten Antworten fest, alle weiteren sind richtig.
    /// So bleiben die Beispielstände stimmig, auch wenn Lektionen Aufgaben dazubekommen.
    private static func play(_ model: LessonFlowModel, theoryPages: Int, firstTry: [Bool]) {
        let evaluator = AnswerEvaluator()
        for _ in 0..<theoryPages { model.advanceTheory() }
        var index = 0
        while let task = model.currentTask {
            let correct = index < firstTry.count ? firstTry[index] : true
            index += 1
            model.draft.apply(correct ? evaluator.referenceAnswer(for: task) : wrongAnswer(for: task))
            model.submit()
            if !correct { model.revealSolution() }
            model.next()
        }
    }

    static func wrongAnswer(for task: LearningTask) -> TaskAnswer {
        switch task.kind {
        case .singleChoice(let spec): .choice((spec.correctIndex + 1) % spec.choices.count)
        case .fillBlank(let spec): .blanks(Array(repeating: "???", count: spec.blanks.count))
        case .predictOutput: .text("keine Ahnung")
        case .code(let spec): .text(spec.starterCode + "\nSystem.out.println(\"x\")")
        case .ordering(let spec): .order(spec.shuffledOrder(seed: task.id))
        case .findBug(let spec): .line(spec.bugLine == 1 ? 2 : 1)
        }
    }
}
#endif
