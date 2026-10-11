import Foundation

/// „Code-Quests“: Ein Abenteuer, das durch Code vorankommt. Jede Quest führt ein Java-Konzept ein,
/// erzählt eine Szene („Die Tür ist verschlossen …“) und prüft den Code des Spielers mit versteckten
/// Tests – wie JUnit. Die Daten stehen in `Resources/code_quests.json`.
public struct QuestBook: Decodable, Sendable {
    public let title: String
    public let intro: String
    public let chapters: [QuestChapter]
    public let quests: [CodeQuest]

    public func quest(id: String) -> CodeQuest? { quests.first { $0.id == id } }
    public func quests(in chapter: QuestChapter) -> [CodeQuest] { quests.filter { $0.chapterId == chapter.id } }
    public func chapter(id: String) -> QuestChapter? { chapters.first { $0.id == id } }

    /// Die Quest davor in der Geschichte – sie muss geschafft sein, damit es weitergeht.
    public func previous(of quest: CodeQuest) -> CodeQuest? {
        guard let index = quests.firstIndex(where: { $0.id == quest.id }), index > 0 else { return nil }
        return quests[index - 1]
    }

    public static let bundledResourceName = "code_quests"

    public static func loadBundled() throws -> QuestBook {
        guard let url = CourseLoader.resourceBundle.url(forResource: bundledResourceName, withExtension: "json") else {
            throw CourseLoadingError.missingResource(bundledResourceName)
        }
        return try JSONDecoder().decode(QuestBook.self, from: Data(contentsOf: url))
    }
}

public struct QuestChapter: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    /// Kurze Einleitung des Kapitels – die Szene, in der die Quests spielen.
    public let story: String
    /// SF-Symbol für die Karte.
    public let symbol: String
}

/// Eine Quest: Szene, Auftrag, neues Konzept, Startcode, Musterlösung und versteckte Tests.
public struct CodeQuest: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let chapterId: String
    public let title: String
    /// Die Quest wird frei, sobald diese Lektion erreicht ist.
    public let lessonId: String
    public let topicId: String
    public let difficulty: Int
    /// Was die Szene erzählt, bevor man loslegt.
    public let story: String
    /// Was genau zu tun ist – mit der verlangten Signatur.
    public let task: String
    /// Das Java-Konzept, das diese Quest einführt – mit Mini-Beispiel.
    public let concept: QuestConcept
    /// Die Klasse, um die es geht (und damit der Dateiname `Tuer.java`).
    public let className: String
    public let starterCode: String
    public let solution: String
    public let tests: [QuestTest]
    /// Bausteine, die verlangt oder verboten sind (z. B. „Nutze eine Schleife“).
    public let requirements: [CodeRule]
    /// Was nach dem Lösen passiert – die Geschichte geht weiter.
    public let success: String
    public let reward: QuestReward
    /// Ein Bauplan für die Werkstatt, den man mit dieser Quest freischaltet.
    public let blueprint: QuestBlueprint?

    enum CodingKeys: String, CodingKey {
        case id, chapterId, title, lessonId, topicId, difficulty, story, task, concept, className
        case starterCode, solution, tests, requirements, success, reward, blueprint
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        chapterId = try c.decode(String.self, forKey: .chapterId)
        title = try c.decode(String.self, forKey: .title)
        lessonId = try c.decode(String.self, forKey: .lessonId)
        topicId = try c.decode(String.self, forKey: .topicId)
        difficulty = try c.decode(Int.self, forKey: .difficulty)
        story = try c.decode(String.self, forKey: .story)
        task = try c.decode(String.self, forKey: .task)
        concept = try c.decode(QuestConcept.self, forKey: .concept)
        className = try c.decode(String.self, forKey: .className)
        starterCode = try c.decode(String.self, forKey: .starterCode)
        solution = try c.decode(String.self, forKey: .solution)
        tests = try c.decode([QuestTest].self, forKey: .tests)
        requirements = try c.decodeIfPresent([CodeRule].self, forKey: .requirements) ?? []
        success = try c.decode(String.self, forKey: .success)
        reward = try c.decode(QuestReward.self, forKey: .reward)
        blueprint = try c.decodeIfPresent(QuestBlueprint.self, forKey: .blueprint)
    }

    /// Die sichtbaren Beispiel-Tests – die übrigen bleiben bis zum Lösen geheim.
    public var visibleTests: [QuestTest] { tests.filter(\.isVisible) }
}

public struct QuestConcept: Decodable, Sendable, Hashable {
    public let title: String
    public let text: String
    public let code: String
}

public struct QuestReward: Decodable, Sendable, Hashable {
    /// Gegenstand fürs Inventar, z. B. „Messingschlüssel“.
    public let item: String
    /// SF-Symbol des Gegenstands.
    public let symbol: String
    public let text: String
}

/// Vorlage für die Werkstatt („Bauplan“) – ein Stück Code, das man dort einfügen kann.
public struct QuestBlueprint: Decodable, Sendable, Hashable {
    public let title: String
    public let text: String
    public let code: String
}

/// Ein versteckter Test – wie eine JUnit-Assertion: Vorbereitung, Ausdruck und erwarteter Wert.
public struct QuestTest: Decodable, Sendable, Hashable {
    /// Wofür der Test steht, in Alltagssprache („Ein falscher Schlüssel öffnet nicht“).
    public let name: String
    /// Anweisungen vor dem Ausdruck, z. B. `Golem g = new Golem("Rolf");`.
    public let setup: String
    /// Ausdruck, dessen Wert geprüft wird (`Tuer.unlock(105)`); nil, wenn nur die Ausgabe zählt.
    public let expression: String?
    public let expect: QuestExpectation
    /// Sichtbar als Beispiel im Auftrag – sonst geheim, bis die Quest gelöst ist.
    public let isVisible: Bool
    /// Mentor-Hinweis, wenn genau dieser Test scheitert.
    public let hint: String

    enum CodingKeys: String, CodingKey { case name, setup, expression, expect, visible, hint }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        setup = try c.decodeIfPresent(String.self, forKey: .setup) ?? ""
        expression = try c.decodeIfPresent(String.self, forKey: .expression)
        expect = try c.decode(QuestExpectation.self, forKey: .expect)
        isVisible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? false
        hint = try c.decode(String.self, forKey: .hint)
    }

    /// Der Test als Java-Code, wie er in einer JUnit-Testklasse stünde.
    public var assertion: String {
        let prefix = setup.isEmpty ? "" : setup + "\n"
        switch expect {
        case .value(let value): return prefix + "assertEquals(\(value.javaLiteral), \(expression ?? ""));"
        case .text(let text): return prefix + "assertEquals(\"\(text)\", String.valueOf(\(expression ?? "")));"
        case .output(let output): return prefix + "// Ausgabe: " + output.replacingOccurrences(of: "\n", with: " ⏎ ")
        case .exception(let name): return prefix + "assertThrows(\(name).class, () -> \(expression ?? ""));"
        }
    }
}

/// Was ein Test erwartet.
public enum QuestExpectation: Decodable, Sendable, Hashable {
    /// Ein Wert – verglichen mit Typ: `true`, `42`, `2.5`, `"Hallo"`.
    case value(QuestValue)
    /// Der Text, den `println` zeigen würde – für Objekte, Listen und Maps.
    case text(String)
    /// Die Ausgabe auf der Konsole.
    case output(String)
    /// Eine Exception dieser Klasse, z. B. `IllegalArgumentException`.
    case exception(String)

    enum CodingKeys: String, CodingKey { case value, text, output, exception }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.value) {
            self = .value(try c.decode(QuestValue.self, forKey: .value))
        } else if let text = try c.decodeIfPresent(String.self, forKey: .text) {
            self = .text(text)
        } else if let output = try c.decodeIfPresent(String.self, forKey: .output) {
            self = .output(output)
        } else if let exception = try c.decodeIfPresent(String.self, forKey: .exception) {
            self = .exception(exception)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .value, in: c, debugDescription: "Ein Test braucht value, text, output oder exception.")
        }
    }
}

/// Ein erwarteter Wert aus dem JSON: Wahrheitswert, ganze Zahl, Kommazahl, Text oder null.
public enum QuestValue: Decodable, Sendable, Hashable {
    case boolean(Bool)
    case integer(Int64)
    case double(Double)
    case string(String)
    case null

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .boolean(b) }
        else if let i = try? c.decode(Int64.self) { self = .integer(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else { self = .string(try c.decode(String.self)) }
    }

    /// Der Wert, wie er in Java-Code stünde.
    public var javaLiteral: String {
        switch self {
        case .boolean(let b): b ? "true" : "false"
        case .integer(let i): String(i)
        case .double(let d): JavaFormat.double(d)
        case .string(let s): "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        case .null: "null"
        }
    }
}
