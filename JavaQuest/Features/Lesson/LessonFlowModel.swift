import Foundation
import Observation
import JavaQuestKit

/// Eingaben der lernenden Person für die aktuelle Aufgabe.
struct AnswerDraft: Equatable {
    var choice: Int?
    var blanks: [String] = []
    var text: String = ""

    init(task: LearningTask? = nil) {
        guard let task else { return }
        switch task.kind {
        case .fillBlank(let spec): blanks = Array(repeating: "", count: spec.blanks.count)
        case .code(let spec): text = spec.starterCode
        case .singleChoice, .predictOutput: break
        }
    }

    /// Antwort für den Evaluator – `nil`, solange nichts eingegeben wurde.
    func answer(for task: LearningTask) -> TaskAnswer? {
        switch task.kind {
        case .singleChoice:
            return choice.map(TaskAnswer.choice)
        case .fillBlank:
            return blanks.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ? .blanks(blanks) : nil
        case .predictOutput, .code:
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .text(text)
        }
    }

    mutating func apply(_ answer: TaskAnswer) {
        switch answer {
        case .choice(let index): choice = index
        case .blanks(let values): blanks = values
        case .text(let value): text = value
        }
    }
}

/// Steuert eine Lern-Sitzung (Lektion, gezielte Übung oder Training) und speichert Ergebnisse.
@MainActor
@Observable
final class LessonFlowModel {
    private(set) var session: LessonSession
    var draft: AnswerDraft
    private(set) var scoreChange: ScoreChange?
    private(set) var successCount = 0
    private(set) var failureCount = 0

    private let store: ProgressStore
    private let evaluator = AnswerEvaluator()

    init(request: SessionRequest, store: ProgressStore) {
        let session: LessonSession
        switch request.kind {
        case .lesson(let id):
            if let lesson = store.course.lesson(id: id) {
                // Varianten je Lernziel: beim Wiederholen kommen andere Aufgaben.
                session = LessonSession(
                    mode: .lesson(lessonId: lesson.id),
                    title: lesson.title,
                    theory: lesson.theory,
                    tasks: store.lessonTasks(for: lesson)
                )
            } else {
                session = LessonSession(mode: .lesson(lessonId: id), title: "Lektion nicht gefunden", theory: [], tasks: [])
            }
        case .practice(let topicId):
            let title = store.course.topic(id: topicId).map { "Gezielt üben: \($0.title)" } ?? "Gezielt üben"
            session = LessonSession(mode: .practice(topicId: topicId), title: title, theory: [], tasks: store.practiceTasks(for: topicId))
        case .training:
            session = LessonSession(mode: .training, title: "Endlos-Training", theory: [], tasks: store.trainingTasks())
        case .free(let topicIds, let difficulties, let count):
            let topics = Set(topicIds)
            let levels = Set(difficulties.compactMap(Difficulty.init(rawValue:)))
            let names = topicIds.compactMap { store.course.topic(id: $0)?.title }
            let title = names.isEmpty ? "Freies Training" : "Freies Training: \(names.joined(separator: ", "))"
            session = LessonSession(
                mode: .free(topicIds: topicIds),
                title: title,
                theory: [],
                tasks: store.freeTrainingTasks(topicIds: topics, difficulties: levels, count: count)
            )
        }
        self.store = store
        self.session = session
        self.draft = AnswerDraft(task: session.currentTask)
    }

    var course: Course { store.course }
    var currentTask: LearningTask? { session.currentTask }
    var isPractice: Bool { session.lessonId == nil }
    var isTraining: Bool {
        if case .free = session.mode { return true }
        return session.mode == .training
    }
    var isAnswerLocked: Bool { session.isCurrentTaskFinished }

    var taskPosition: (index: Int, count: Int)? {
        if case .task(let index) = session.phase { return (index + 1, session.tasks.count) }
        return nil
    }

    var canSubmit: Bool {
        guard let task = currentTask, !session.isCurrentTaskFinished else { return false }
        guard session.lastResult == nil || session.canRetry else { return false }
        if case .code(let spec) = task.kind,
           draft.text.trimmingCharacters(in: .whitespacesAndNewlines) == spec.starterCode.trimmingCharacters(in: .whitespacesAndNewlines) {
            return false
        }
        return draft.answer(for: task) != nil
    }

    var remainingAttempts: Int { max(LessonSession.maxAttempts - session.attempts, 0) }

    /// Die Musterlösung, sobald sie angezeigt werden darf.
    var revealedAnswer: TaskAnswer? {
        guard session.isRevealed, let task = currentTask else { return nil }
        return evaluator.referenceAnswer(for: task)
    }

    func advanceTheory() { session.advanceTheory() }
    func goBackInTheory() { session.goBackInTheory() }

    func submit() {
        guard canSubmit, let task = currentTask, let answer = draft.answer(for: task) else { return }
        if session.lastResult != nil { session.prepareRetry() }
        guard let result = session.submit(answer, using: evaluator) else { return }
        if result.isCorrect {
            successCount += 1
            persistFinishedOutcome()
        } else {
            failureCount += 1
        }
    }

    func revealSolution() {
        guard let task = currentTask else { return }
        session.revealSolution()
        draft.apply(evaluator.referenceAnswer(for: task))
        persistFinishedOutcome()
    }

    func next() {
        session.advanceToNextTask()
        draft = AnswerDraft(task: session.currentTask)
        if session.phase == .summary, let lessonId = session.lessonId {
            scoreChange = store.completeLesson(lessonId, summary: session.summary)
        }
    }

    /// Ergebnis einer bereits bewerteten Lücke, für die farbige Markierung.
    func blankStates(for task: LearningTask) -> [Bool]? {
        guard case .fillBlank(let spec) = task.kind, session.lastResult != nil || session.isRevealed else { return nil }
        return spec.blanks.enumerated().map { index, blank in
            blank.accepts(index < draft.blanks.count ? draft.blanks[index] : "")
        }
    }

    var nextLessonAfterCurrent: Lesson? {
        guard let id = session.lessonId else { return nil }
        let lessons = store.course.allLessons
        guard let index = lessons.firstIndex(where: { $0.id == id }), index + 1 < lessons.count else { return nil }
        return lessons[index + 1]
    }

    private func persistFinishedOutcome() {
        guard let outcome = session.finishedOutcome else { return }
        store.record(outcome, lessonId: session.lessonId, context: isTraining ? .training : isPractice ? .practice : .lesson)
    }
}
