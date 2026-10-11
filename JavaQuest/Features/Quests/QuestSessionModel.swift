import Foundation
import Observation
import JavaQuestKit

/// Zustand einer laufenden Quest: Code (als Entwurf gespeichert), Testlauf, Mentor und Belohnung.
@MainActor
@Observable
final class QuestSessionModel {
    let quest: CodeQuest
    private let store: ProgressStore

    var code: String {
        didSet { Self.saveDraft(code, for: quest.id) }
    }
    private(set) var result: QuestResult?
    private(set) var isRunning = false
    /// Läufe ohne Erfolg – nach dreien bietet der Mentor die Musterlösung zum Ansehen an.
    private(set) var failedRuns = 0
    private(set) var rewardGain: RewardGain?
    /// Sterne vor diesem Besuch – „Neuer Bestwert“ und frisch freigeschaltete Baupläne.
    let previousStars: Int
    /// Der Code, der zuletzt geprüft wurde – ändert man danach etwas, gilt das Ergebnis als veraltet.
    private(set) var checkedCode: String?
    let editor = CodeEditorController()

    init(quest: CodeQuest, store: ProgressStore) {
        self.quest = quest
        self.store = store
        previousStars = store.questProgress.stars[quest.id] ?? 0
        code = Self.draft(for: quest.id) ?? quest.starterCode
    }

    var isSolved: Bool { result?.solved == true }
    var isStale: Bool { checkedCode != nil && checkedCode != code }
    var nextQuest: CodeQuest? {
        guard let index = store.questBook.quests.firstIndex(of: quest), index + 1 < store.questBook.quests.count else { return nil }
        let next = store.questBook.quests[index + 1]
        return store.questProgress.state(of: next).isPlayable ? next : nil
    }

    /// Die Zeile, an der der letzte Lauf hängen blieb – der Editor markiert sie rot.
    var errorLine: Int? {
        guard !isStale, let result else { return nil }
        return result.compileProblem?.line ?? result.mentor.line
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        let code = code
        let quest = quest
        let before = store.rewardSnapshot()
        let result = await Task.detached(priority: .userInitiated) { QuestRunner.run(code, quest: quest) }.value
        self.result = result
        checkedCode = code
        isRunning = false
        if result.solved {
            store.recordQuest(quest, stars: result.stars)
            let gain = store.rewardSnapshot().gains(since: before)
            rewardGain = gain.isEmpty ? nil : gain
        } else {
            failedRuns += 1
        }
    }

    func reset() {
        code = quest.starterCode
        result = nil
        checkedCode = nil
    }

    #if DEBUG
    func fillSolution() { code = quest.solution }
    #endif

    // MARK: Entwürfe

    private static func draftKey(_ id: String) -> String { "questDraft.\(id)" }

    static func draft(for id: String) -> String? {
        guard LocalDrafts.isEnabled else { return nil }
        return UserDefaults.standard.string(forKey: draftKey(id))
    }

    private static func saveDraft(_ code: String, for id: String) {
        guard LocalDrafts.isEnabled else { return }
        UserDefaults.standard.set(code, forKey: draftKey(id))
    }
}

/// Entwürfe der Quests und Programme der Werkstatt liegen nur auf diesem Gerät (nicht in der Sicherung).
enum LocalDrafts {
    /// Bei Tests und Screenshots (`-inMemoryStore`) bleibt nichts liegen – und nichts Altes taucht auf.
    static let isEnabled = !ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
}
