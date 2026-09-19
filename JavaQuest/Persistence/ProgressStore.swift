import Foundation
import Observation
import SwiftData
import JavaQuestKit

/// Ergebnis einer Score-Neuberechnung für die Anzeige („+36 Punkte“, Rangaufstieg).
struct ScoreChange: Equatable, Sendable {
    let before: Int
    let after: Int
    let newRank: MasterRank?

    var delta: Int { after - before }
}

/// Zentrale Schnittstelle zwischen UI und SwiftData.
///
/// Views lesen abgeleitete Werte (Score, Lernpfad, Wissensanalyse), die aus den
/// gespeicherten Modellen mit der reinen Logik aus JavaQuestKit berechnet werden.
/// Alle Schreibzugriffe laufen über die Methoden dieser Klasse.
@MainActor
@Observable
final class ProgressStore {
    let course: Course
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private(set) var profile: LearnerProfile?
    private(set) var lastSaveError: String?

    init(course: Course, container: ModelContainer) {
        self.course = course
        self.container = container
        let profiles = (try? container.mainContext.fetch(FetchDescriptor<LearnerProfile>())) ?? []
        profile = profiles.min { $0.createdAt < $1.createdAt }
    }

    var needsOnboarding: Bool { profile?.onboardingCompleted != true }

    // MARK: - Abgeleitete Werte

    var lessonResults: [String: LessonResult] {
        var results: [String: LessonResult] = [:]
        for record in profile?.lessonRecords ?? [] {
            let result = LessonResult(bestAccuracy: record.bestAccuracy, isCompleted: record.isCompleted, viaPlacement: record.completedViaPlacement)
            if let existing = results[record.lessonId], existing.bestAccuracy >= result.bestAccuracy { continue }
            results[record.lessonId] = result
        }
        return results
    }

    var topicStats: [String: TopicStats] {
        Dictionary((profile?.topicMasteries ?? []).map { ($0.topicId, $0.stats) }, uniquingKeysWith: { lhs, _ in lhs })
    }

    var lessonStates: [String: LessonState] { LearningPath.states(course: course, results: lessonResults) }
    var moduleProgress: [ModuleProgress] { LearningPath.moduleProgress(course: course, results: lessonResults) }
    var nextLesson: Lesson? { LearningPath.nextLesson(course: course, results: lessonResults) }
    var knowledgeReport: KnowledgeReport { KnowledgeAnalyzer.report(course: course, stats: topicStats) }

    var masterScore: Int { profile?.masterScore ?? 0 }
    var rank: MasterRank { MasterRank.rank(for: masterScore) }
    var nextRank: MasterRank? { MasterRank.next(after: masterScore) }
    var progressToNextRank: Double { MasterRank.progressToNext(for: masterScore) }

    var scoreHistory: [Int] {
        (profile?.scoreHistory ?? []).sorted { $0.date < $1.date }.map(\.score)
    }

    /// Zuwachs der letzten sieben Tage.
    var weeklyScoreDelta: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let history = (profile?.scoreHistory ?? []).sorted { $0.date < $1.date }
        let baseline = history.last { $0.date < weekAgo }?.score ?? 0
        return max(masterScore - baseline, 0)
    }

    /// Serie zählt nur, wenn heute oder gestern gelernt wurde.
    var displayedStreak: Int {
        guard let profile, let last = profile.lastActiveDay else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: Calendar.current.startOfDay(for: .now)).day ?? 0
        return days <= 1 ? profile.currentStreak : 0
    }

    var completedLessonCount: Int { lessonResults.values.filter(\.isCompleted).count }
    var solvedTaskCount: Int { (profile?.attempts ?? []).filter(\.solved).count }

    /// Anteil der beim ersten Versuch gelösten Aufgaben (ohne Einstufung).
    var firstTryRate: Double? {
        let relevant = (profile?.attempts ?? []).filter { $0.contextRaw != AttemptContext.placement.rawValue }
        guard !relevant.isEmpty else { return nil }
        return Double(relevant.filter { $0.solved && $0.tries == 1 }.count) / Double(relevant.count)
    }

    var unlockedLessonIds: Set<String> {
        Set(lessonStates.filter { $0.value.isPlayable }.map(\.key))
    }

    func practiceTasks(for topicId: String) -> [LearningTask] {
        PracticeBuilder.tasks(for: topicId, in: course, unlockedLessonIds: unlockedLessonIds)
    }

    // MARK: - Endlos-Training

    var completedLessonIds: Set<String> {
        Set(lessonResults.filter { $0.value.isCompleted }.map(\.key))
    }

    /// Alle Aufgaben, die im Endlos-Training vorkommen können.
    var trainingPool: [LearningTask] {
        TrainingBuilder.pool(course: course, completedLessonIds: completedLessonIds)
    }

    /// Wie jede Aufgabe zuletzt lief (aus dem Aufgaben-Protokoll).
    var taskHistory: [String: TaskHistory] {
        var history: [String: TaskHistory] = [:]
        for attempt in (profile?.attempts ?? []).sorted(by: { $0.date < $1.date }) {
            let count = (history[attempt.taskId]?.attempts ?? 0) + 1
            history[attempt.taskId] = TaskHistory(attempts: count, lastCredit: attempt.credit, lastDate: attempt.date)
        }
        return history
    }

    /// Wie viele Aufgaben schon im Endlos-Training gelöst oder aufgelöst wurden.
    var trainingTaskCount: Int {
        (profile?.attempts ?? []).filter { $0.contextRaw == AttemptContext.training.rawValue }.count
    }

    func trainingTasks() -> [LearningTask] {
        TrainingBuilder.round(from: trainingPool, topicStats: topicStats, history: taskHistory)
    }

    // MARK: - Onboarding & Einstufung

    /// Schließt das Onboarding ab. Bei einem Einstufungstest werden die Antworten
    /// in die Wissensanalyse übernommen und übersprungene Lektionen angerechnet.
    func completeOnboarding(level: ExperienceLevel, placement: PlacementTest?) {
        let profile = self.profile ?? {
            let created = LearnerProfile(experienceLevel: level)
            context.insert(created)
            self.profile = created
            return created
        }()
        profile.experienceLevelRaw = level.rawValue

        if let placement {
            for answer in placement.answers {
                let outcome = TaskOutcome(task: answer.task, attempts: 1, solved: answer.result.isCorrect, credit: answer.result.score)
                store(outcome, lessonId: nil, context: .placement)
            }
            let outcome = placement.outcome(in: course)
            profile.placementScore = outcome.scorePercent
            profile.placedLevelRaw = outcome.placedLevel.rawValue
            for lessonId in outcome.creditedLessonIds {
                let record = lessonRecord(for: lessonId)
                record.isCompleted = true
                record.completedViaPlacement = true
                record.bestAccuracy = max(record.bestAccuracy, outcome.creditedAccuracy)
                record.firstCompletedAt = record.firstCompletedAt ?? .now
            }
        } else {
            profile.placedLevelRaw = ExperienceLevel.beginner.rawValue
        }

        profile.onboardingCompleted = true
        touchStreak()
        recomputeScore(reason: placement == nil ? "start" : "placement")
        save()
    }

    // MARK: - Lernen

    /// Speichert eine abgeschlossene Aufgabe (gelöst oder Lösung angezeigt).
    func record(_ outcome: TaskOutcome, lessonId: String?, context attemptContext: AttemptContext) {
        guard profile != nil else { return }
        store(outcome, lessonId: lessonId, context: attemptContext)
        touchStreak()
        save()
    }

    /// Schließt eine Lektion ab. Nur bestandene Lektionen zählen für den Score,
    /// und es zählt immer der Bestwert – der Score kann also nicht sinken.
    @discardableResult
    func completeLesson(_ lessonId: String, summary: LessonSummary) -> ScoreChange? {
        guard profile != nil else { return nil }
        let record = lessonRecord(for: lessonId)
        record.playCount += 1
        record.lastAccuracy = summary.accuracy
        record.lastPlayedAt = .now
        if summary.passed {
            if !record.isCompleted || record.completedViaPlacement || summary.accuracy > record.bestAccuracy {
                record.bestAccuracy = max(record.bestAccuracy, summary.accuracy)
            }
            record.isCompleted = true
            record.completedViaPlacement = false
            record.firstCompletedAt = record.firstCompletedAt ?? .now
        }
        let change = recomputeScore(reason: lessonId)
        save()
        return change
    }

    /// Löscht alle Fortschritte; danach startet das Onboarding neu.
    func resetAllProgress() {
        if let profile { context.delete(profile) }
        profile = nil
        save()
    }

    // MARK: - Intern

    private func store(_ outcome: TaskOutcome, lessonId: String?, context attemptContext: AttemptContext) {
        guard let profile else { return }
        let attempt = TaskAttempt(
            taskId: outcome.taskId,
            topicId: outcome.topicId,
            lessonId: lessonId,
            context: attemptContext,
            difficulty: outcome.difficulty.rawValue,
            credit: outcome.credit,
            solved: outcome.solved,
            tries: outcome.attempts
        )
        context.insert(attempt)
        profile.attempts?.append(attempt)

        let mastery = topicMastery(for: outcome.topicId)
        var stats = mastery.stats
        stats.record(difficulty: outcome.difficulty, credit: outcome.credit, at: .now)
        mastery.attempts = stats.attempts
        mastery.weightedCorrect = stats.weightedCorrect
        mastery.weightedTotal = stats.weightedTotal
        mastery.lastPracticedAt = stats.lastPracticed
        if outcome.solvedOnFirstTry { mastery.firstTryCorrect += 1 }
    }

    private func lessonRecord(for lessonId: String) -> LessonRecord {
        if let existing = profile?.lessonRecords?.first(where: { $0.lessonId == lessonId }) { return existing }
        let record = LessonRecord(lessonId: lessonId)
        context.insert(record)
        profile?.lessonRecords?.append(record)
        return record
    }

    private func topicMastery(for topicId: String) -> TopicMastery {
        if let existing = profile?.topicMasteries?.first(where: { $0.topicId == topicId }) { return existing }
        let mastery = TopicMastery(topicId: topicId)
        context.insert(mastery)
        profile?.topicMasteries?.append(mastery)
        return mastery
    }

    @discardableResult
    private func recomputeScore(reason: String) -> ScoreChange {
        let before = profile?.masterScore ?? 0
        let after = MasterScore.compute(course: course, results: lessonResults)
        profile?.masterScore = after
        if after != before || (profile?.scoreHistory ?? []).isEmpty {
            let snapshot = ScoreSnapshot(score: after, reason: reason)
            context.insert(snapshot)
            profile?.scoreHistory?.append(snapshot)
        }
        let newRank = MasterRank.rank(for: after)
        return ScoreChange(before: before, after: after, newRank: newRank != MasterRank.rank(for: before) ? newRank : nil)
    }

    private func touchStreak(now: Date = .now) {
        guard let profile else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if let last = profile.lastActiveDay {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 0
            guard days > 0 else { return }
            profile.currentStreak = days == 1 ? profile.currentStreak + 1 : 1
        } else {
            profile.currentStreak = 1
        }
        profile.longestStreak = max(profile.longestStreak, profile.currentStreak)
        profile.lastActiveDay = today
    }

    private func save() {
        do {
            try context.save()
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
        }
    }
}
