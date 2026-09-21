import Testing
@testable import JavaQuestKit

/// Prüft die ausgelieferte Kursdatei als Ganzes.
@Suite("Kursinhalt")
struct CourseContentTests {
    let course: Course
    let evaluator = AnswerEvaluator()

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    var allTasks: [LearningTask] {
        course.allLessons.flatMap(\.tasks) + ExperienceLevel.allCases.flatMap { course.placement.pool(for: $0) }
    }

    @Test("Kursdatei ist konsistent (Validator ohne Befund)")
    func validatorFindsNoIssues() {
        let issues = CourseValidator.validate(course)
        #expect(issues.isEmpty, "\(issues.map(\.description).joined(separator: "\n"))")
    }

    @Test("Umfang: 13 Module, 32 Lektionen, 160 Lektionsaufgaben plus Übungspool")
    func courseShape() {
        #expect(course.modules.count == 13)
        #expect(course.allLessons.count == 32)
        #expect(course.allLessons.flatMap(\.tasks).count == 160)
        // Der Übungspool speist Übung, Training und freies Lernen – er wächst unabhängig von den Lektionen.
        #expect(course.taskPool.count >= 50)
        #expect(course.practiceableTasks.count == course.allLessons.flatMap(\.tasks).count + course.taskPool.count)
        #expect(course.entryModule(for: .beginner)?.id == "m1-first-steps")
        #expect(course.entryModule(for: .intermediate)?.id == "m3-objects")
        #expect(course.entryModule(for: .advanced)?.id == "m5-modern")
    }

    @Test("Jede Lektion steigt im Niveau an und endet anspruchsvoll")
    func lessonDifficultyRamps() {
        for lesson in course.allLessons {
            let levels = lesson.tasks.map(\.difficulty.rawValue)
            #expect(levels == levels.sorted(), "\(lesson.id): \(levels)")
            #expect(levels.first == 1, "\(lesson.id) beginnt nicht bei Niveau 1")
            #expect((levels.last ?? 0) >= 3, "\(lesson.id) endet unter Niveau 3")
        }
        // Anfänger-Einstieg: sehr einfache Aufgaben, höchstens Niveau 3.
        #expect(course.allLessons[0].tasks.allSatisfy { $0.difficulty <= .medium })
    }

    @Test("Musterlösung jeder Aufgabe wird akzeptiert")
    func referenceAnswersPass() {
        for task in allTasks {
            let result = evaluator.evaluate(evaluator.referenceAnswer(for: task), for: task)
            #expect(result.isCorrect, "\(task.id): \(result.findings.map(\.message))")
            #expect(result.score == 1, "\(task.id): Score \(result.score)")
        }
    }

    @Test("Falsche Antworten werden abgelehnt")
    func wrongAnswersFail() {
        for task in allTasks {
            switch task.kind {
            case .singleChoice(let spec):
                for index in spec.choices.indices where index != spec.correctIndex {
                    #expect(!evaluator.evaluate(.choice(index), for: task).isCorrect, "\(task.id) Option \(index)")
                }
            case .fillBlank(let spec):
                let empty = evaluator.evaluate(.blanks(Array(repeating: "", count: spec.blanks.count)), for: task)
                #expect(!empty.isCorrect, "\(task.id) leer")
                let garbage = evaluator.evaluate(.blanks(Array(repeating: "xyz", count: spec.blanks.count)), for: task)
                #expect(!garbage.isCorrect, "\(task.id) Unsinn")
            case .predictOutput(let spec):
                #expect(!evaluator.evaluate(.text(""), for: task).isCorrect, "\(task.id) leer")
                #expect(!evaluator.evaluate(.text(spec.expectedOutput + "\nx"), for: task).isCorrect, "\(task.id) Zusatzzeile")
            case .code(let spec):
                let starter = evaluator.evaluate(.text(spec.starterCode), for: task)
                #expect(!starter.isCorrect, "\(task.id): Startercode gilt schon als Lösung")
            }
        }
    }

    @Test("Multiple-Choice-Lösungen sind über die Positionen verteilt")
    func choicePositionsVary() {
        let positions = allTasks.compactMap { task -> Int? in
            if case .singleChoice(let spec) = task.kind { return spec.correctIndex }
            return nil
        }
        #expect(Set(positions).count >= 3)
    }

    @Test("Einstufung: eine Frage nur für „Vorkenntnisse“")
    func placementPool() {
        #expect(course.placement.pool(for: .intermediate).count == 1)
        #expect(course.placement.questionsPerTest == 1)
        #expect(course.placement.passThreshold == 65)
    }

    @Test("Alle Themen werden in einer Lektion behandelt")
    func everyTopicIsTaught() {
        for topic in course.topics {
            #expect(course.firstLesson(teaching: topic.id) != nil, "\(topic.id)")
        }
    }
}
