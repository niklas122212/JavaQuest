import Foundation

/// Wie weit man im Abenteuer ist: welche Quest offen ist, was im Inventar liegt, welche Baupläne
/// freigeschaltet sind und ob die Werkstatt (freies Bauen) schon offen steht.
///
/// Quest-Ergebnisse liegen im selben Protokoll wie Arena-Missionen (Kontext „mission“, ID `quest-…`,
/// credit = Sterne / 3). So zählen sie für XP und bleiben auf allen Plattformen in Sicherungen erhalten.
public struct QuestProgress: Sendable {
    public enum State: Sendable, Hashable {
        /// Noch gesperrt – mit dem Grund („Erst „Die Tür“ lösen“).
        case locked(String)
        case open
        case solved(stars: Int)

        public var isPlayable: Bool { if case .locked = self { false } else { true } }
    }

    public let book: QuestBook
    /// Beste Sterne je Quest-ID.
    public let stars: [String: Int]
    private let unlockedLessonIds: Set<String>
    private let lessonTitles: [String: (number: Int, title: String)]

    public init(book: QuestBook, course: Course, stars: [String: Int], unlockedLessonIds: Set<String>) {
        self.book = book
        self.stars = stars.filter { book.quest(id: $0.key) != nil && $0.value > 0 }
        self.unlockedLessonIds = unlockedLessonIds
        var titles: [String: (Int, String)] = [:]
        for (index, lesson) in course.allLessons.enumerated() { titles[lesson.id] = (index + 1, lesson.title) }
        lessonTitles = titles
    }

    public func state(of quest: CodeQuest) -> State {
        if let best = stars[quest.id] { return .solved(stars: best) }
        if let previous = book.previous(of: quest), stars[previous.id] == nil {
            return .locked("Erst „\(previous.title)“ lösen")
        }
        if !unlockedLessonIds.contains(quest.lessonId) {
            let lesson = lessonTitles[quest.lessonId]
            return .locked(lesson.map { "Ab Lektion \($0.number): \($0.title)" } ?? "Lektion noch nicht erreicht")
        }
        return .open
    }

    public var solvedCount: Int { stars.count }
    public var totalStars: Int { stars.values.reduce(0, +) }
    public var maxStars: Int { book.quests.count * 3 }

    /// Die nächste Quest, die man spielen kann – oder nil, wenn alles gelöst oder noch gesperrt ist.
    public var nextQuest: CodeQuest? { book.quests.first { state(of: $0) == .open } }

    public func solvedCount(in chapter: QuestChapter) -> Int {
        book.quests(in: chapter).filter { stars[$0.id] != nil }.count
    }

    /// Gegenstände aus gelösten Quests, in der Reihenfolge der Geschichte.
    public var inventory: [QuestReward] {
        book.quests.filter { stars[$0.id] != nil }.map(\.reward)
    }

    /// Baupläne gibt es für sauberen Code: Erst mit allen 3 Sternen landet der Bauplan der Quest in der Werkstatt.
    public func isBlueprintUnlocked(_ quest: CodeQuest) -> Bool {
        quest.blueprint != nil && stars[quest.id] == 3
    }

    public var blueprints: [(quest: CodeQuest, blueprint: QuestBlueprint)] {
        book.quests.compactMap { quest in quest.blueprint.flatMap { isBlueprintUnlocked(quest) ? (quest, $0) : nil } }
    }

    /// Die Werkstatt öffnet, sobald das erste Kapitel geschafft ist.
    public var isWorkshopUnlocked: Bool {
        guard let first = book.chapters.first else { return false }
        return book.quests(in: first).allSatisfy { stars[$0.id] != nil }
    }
}

extension QuestBook {
    /// Quest-IDs beginnen damit – so lassen sie sich im Protokoll von Arena-Missionen unterscheiden.
    public static let idPrefix = "quest-"
}
