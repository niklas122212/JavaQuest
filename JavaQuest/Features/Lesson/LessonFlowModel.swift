import Foundation
import Observation
import JavaQuestKit

/// Eingaben der lernenden Person für die aktuelle Aufgabe.
struct AnswerDraft: Equatable {
    var choice: Int?
    var blanks: [String] = []
    var text: String = ""
    /// Code-Puzzle: gewählte Teile in Reihenfolge (Indizes in `OrderingSpec.pieces`).
    var order: [Int] = []
    /// Bug-Jagd: angetippte Zeile (ab 1).
    var selectedLine: Int?

    init(task: LearningTask? = nil) {
        guard let task else { return }
        switch task.kind {
        case .fillBlank(let spec): blanks = Array(repeating: "", count: spec.blanks.count)
        case .code(let spec): text = spec.starterCode
        case .singleChoice, .predictOutput, .ordering, .findBug: break
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
        case .ordering(let spec):
            // Geprüft wird erst, wenn alle Teile liegen.
            return order.count == spec.pieces.count ? .order(order) : nil
        case .findBug:
            return selectedLine.map(TaskAnswer.line)
        }
    }

    mutating func apply(_ answer: TaskAnswer) {
        switch answer {
        case .choice(let index): choice = index
        case .blanks(let values): blanks = values
        case .text(let value): text = value
        case .order(let value): order = value
        case .line(let value): selectedLine = value
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
    /// XP der zuletzt gelösten Aufgabe – für die kleine „+20 XP“-Einblendung.
    private(set) var lastAwardedXP: Int?
    /// Was die ganze Sitzung gebracht hat (XP, Level, Abzeichen) – gesetzt bei der Auswertung.
    private(set) var rewardGain: RewardGain?
    /// Ergebnis der Abschluss-Mission, falls gespielt.
    private(set) var missionResult: ArenaResult?
    /// Die laufende Abschluss-Mission (entsteht beim Erreichen der Missions-Phase).
    private(set) var missionModel: ArenaMissionModel?
    /// Ergebnis des letzten Testlaufs (Code ausführen, ohne einen Versuch zu verbrauchen).
    private(set) var testRunResult: JavaRunResult?
    private(set) var isTestRunning = false

    var canTestRun: Bool {
        guard let task = currentTask, case .code = task.kind, !session.isCurrentTaskFinished else { return false }
        return !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTestRunning
    }

    func testRun() {
        guard canTestRun else { return }
        let source = draft.text
        isTestRunning = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { AnswerEvaluator.testRun(source) }.value
            self.testRunResult = result
            self.isTestRunning = false
        }
    }

    let store: ProgressStore
    private let evaluator = AnswerEvaluator()
    private let rewardStart: RewardSnapshot
    private var lessonRecorded = false

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
                    tasks: store.lessonTasks(for: lesson),
                    missionId: store.catalog.lessonMission(for: id)?.id
                )
            } else {
                session = LessonSession(mode: .lesson(lessonId: id), title: "Lektion nicht gefunden", theory: [], tasks: [])
            }
        case .practice(let topicId):
            let title = store.course.topic(id: topicId).map { "Gezielt üben: \($0.title)" } ?? "Gezielt üben"
            session = LessonSession(mode: .practice(topicId: topicId), title: title, theory: [], tasks: store.practiceTasks(for: topicId))
        case .training:
            session = LessonSession(mode: .training, title: "Endlos-Training", theory: [], tasks: store.trainingTasks())
        case .weakSpots(let count):
            session = LessonSession(
                mode: .free(topicIds: []),
                title: "Meine Schwächen",
                theory: [],
                tasks: store.weakSpotTasks(count: count)
            )
        case .review(let count):
            session = LessonSession(
                mode: .free(topicIds: []),
                title: "Wiederholung",
                theory: [],
                tasks: store.reviewTasks(count: count)
            )
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
        case .mission, .playground:
            // Missionen laufen im eigenen Arena-Bildschirm, nicht im Lern-Loop.
            session = LessonSession(mode: .free(topicIds: []), title: "", theory: [], tasks: [])
        }
        self.store = store
        self.session = session
        self.draft = AnswerDraft(task: session.currentTask)
        self.rewardStart = store.rewardSnapshot()
        #if DEBUG
        applyDebugSkip()
        #endif
    }

    #if DEBUG
    /// Nur für Screenshots (`-inMemoryStore`): `-skipToTask N` löst die ersten N Aufgaben mit der Musterlösung,
    /// `-skipToTask 99` springt bis zur Mission bzw. Auswertung. `-answerWrong` beantwortet die Zielaufgabe falsch.
    private func applyDebugSkip() {
        let defaults = UserDefaults.standard
        guard ProcessInfo.processInfo.arguments.contains("-inMemoryStore"), defaults.object(forKey: "skipToTask") != nil else { return }
        let count = defaults.integer(forKey: "skipToTask")
        while case .theory = session.phase { session.advanceTheory() }
        for _ in 0..<count {
            guard let task = currentTask else { break }
            draft.apply(evaluator.referenceAnswer(for: task))
            submit()
            next()
        }
        if ProcessInfo.processInfo.arguments.contains("-answerWrong"), let task = currentTask {
            draft.apply(PreviewSupport.wrongAnswer(for: task))
            submit()
        }
    }
    #endif

    var mission: ArenaMission? {
        guard case .mission(let id) = session.phase else { return nil }
        return store.catalog.mission(id: id)
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
        if session.lastResult != nil, let answer = draft.answer(for: task), answer == lastSubmittedAnswer {
            // Dieselbe Antwort noch einmal zu prüfen, kostet nur einen Versuch.
            return false
        }
        return draft.answer(for: task) != nil
    }

    var remainingAttempts: Int { max(LessonSession.maxAttempts - session.attempts, 0) }

    /// Die gewählte falsche Antwort einer Multiple-Choice-Aufgabe – mit Begründung, falls hinterlegt.
    /// Ab dem zweiten Fehlversuch wird der Tipp konkreter, statt sich zu wiederholen.
    /// Bei Auswahlaufgaben bekommt er die gewählte Antwort mit, damit er sie nicht noch
    /// einmal als „scheidet aus“ nennt.
    var secondHint: String? {
        guard let task = currentTask, session.attempts >= 2, !session.isRevealed,
              session.lastResult?.isCorrect != true
        else { return nil }
        return SecondHint.text(for: task, chosen: draft.choice)
    }

    var wrongChoice: (label: String, reason: String?)? {
        guard let task = currentTask, case .singleChoice(let spec) = task.kind,
              let gewaehlt = draft.choice, gewaehlt != spec.correctIndex,
              spec.choices.indices.contains(gewaehlt),
              session.lastResult != nil || session.isRevealed
        else { return nil }
        return (spec.choices[gewaehlt], spec.whyWrong(gewaehlt))
    }

    /// Was richtig gewesen wäre – erst, wenn nichts mehr zu versuchen ist.
    var correctAnswer: String? {
        guard let task = currentTask, session.isCurrentTaskFinished || remainingAttempts == 0,
              session.lastResult?.isCorrect != true
        else { return nil }
        switch task.kind {
        case .singleChoice(let spec):
            return spec.choices.indices.contains(spec.correctIndex) ? spec.choices[spec.correctIndex] : nil
        case .predictOutput(let spec):
            return "die Ausgabe\n\(spec.expectedOutput)"
        case .fillBlank(let spec):
            let werte = spec.blanks.enumerated().map { "Lücke \($0.offset + 1): \($0.element.accepted.first ?? "")" }
            return werte.joined(separator: " · ")
        case .code, .ordering:
            // Bei Code und Puzzle steht die Lösung ohnehin Zeile für Zeile darunter.
            return nil
        case .findBug(let spec):
            return "Zeile \(spec.bugLine) – richtig wäre: \(spec.fix.code.trimmingCharacters(in: .whitespaces))"
        }
    }

    /// Die Musterlösung, sobald sie angezeigt werden darf.
    var revealedAnswer: TaskAnswer? {
        guard session.isRevealed, let task = currentTask else { return nil }
        return evaluator.referenceAnswer(for: task)
    }

    func advanceTheory() { session.advanceTheory() }
    func goBackInTheory() { session.goBackInTheory() }

    private var lastSubmittedAnswer: TaskAnswer?

    func submit() {
        guard canSubmit, let task = currentTask, let answer = draft.answer(for: task) else { return }
        if session.lastResult != nil { session.prepareRetry() }
        guard let result = session.submit(answer, using: evaluator) else { return }
        lastSubmittedAnswer = answer
        if result.isCorrect {
            successCount += 1
            persistFinishedOutcome()
            if let outcome = session.finishedOutcome {
                lastAwardedXP = Experience.points(forTask: ActivityRecord(
                    taskId: outcome.taskId, topicId: outcome.topicId, context: .lesson, difficulty: outcome.difficulty.rawValue,
                    credit: outcome.credit, solved: true, tries: outcome.attempts, date: .now
                ))
            }
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
        lastAwardedXP = nil
        lastSubmittedAnswer = nil
        testRunResult = nil
        recordLessonIfFinished()
    }

    /// Die Lektion zählt, sobald die letzte Aufgabe erledigt ist – auch wenn die Mission danach abgebrochen wird.
    private func recordLessonIfFinished() {
        if case .mission(let id) = session.phase, missionModel == nil, let mission = store.catalog.mission(id: id) {
            missionModel = ArenaMissionModel(mission: mission, store: store)
        }
        switch session.phase {
        case .mission, .summary:
            if !lessonRecorded, let lessonId = session.lessonId {
                lessonRecorded = true
                scoreChange = store.completeLesson(lessonId, summary: session.summary)
            }
            if session.phase == .summary { rewardGain = store.rewardSnapshot().gains(since: rewardStart) }
        default:
            break
        }
    }

    /// Mission geschafft (Ergebnis wird gespeichert) oder übersprungen (`nil`).
    func finishMission(with result: ArenaResult?) {
        missionResult = result
        session.finishMission()
        recordLessonIfFinished()
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
