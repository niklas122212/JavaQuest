import Foundation

/// Der komplette, lokal gebündelte Kurs (siehe `Resources/java_course.json`).
public struct Course: Decodable, Sendable, Hashable {
    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, title, topics, modules, placement, taskPool, equivalentSolutions
    }

    /// Eigener Decoder, damit ältere Kursdateien ohne `taskPool` weiterhin lesbar bleiben.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        topics = try container.decode([Topic].self, forKey: .topics)
        modules = try container.decode([CourseModule].self, forKey: .modules)
        placement = try container.decode(PlacementConfig.self, forKey: .placement)
        taskPool = try container.decodeIfPresent([LearningTask].self, forKey: .taskPool) ?? []
        equivalentSolutions = try container.decodeIfPresent([String: [String]].self, forKey: .equivalentSolutions) ?? [:]
    }

    public let schemaVersion: Int
    public let id: String
    public let title: String
    public let topics: [Topic]
    public let modules: [CourseModule]
    public let placement: PlacementConfig
    /// Übungsaufgaben außerhalb der Lektionen: zusätzliche Varianten und Aufgaben je Thema.
    /// Der Lernpfad bleibt davon unberührt; Übung, Training und freies Lernen ziehen daraus mit.
    public let taskPool: [LearningTask]
    /// Gleichwertige, ebenfalls richtige Lösungen zu Code-Aufgaben – Aufgaben-ID auf Lösungen.
    /// Sie werden nie angezeigt. Die Tests prüfen damit, dass der Prüfer das Ergebnis bewertet
    /// und nicht den Weg vorschreibt: Wer selbst denkt, soll nicht dafür bestraft werden.
    public let equivalentSolutions: [String: [String]]

    public var allTasks: [LearningTask] {
        allLessons.flatMap(\.tasks) + taskPool + ExperienceLevel.allCases.flatMap { placement.pool(for: $0) }
    }

    /// Alle übbaren Aufgaben (Lektionen + Pool) – ohne die Einstufungsfragen.
    public var practiceableTasks: [LearningTask] { allLessons.flatMap(\.tasks) + taskPool }

    /// Alle übbaren Aufgaben eines Themas, unabhängig davon, ob die Lektion schon frei ist.
    public func tasks(forTopic topicId: String) -> [LearningTask] {
        practiceableTasks.filter { $0.topicId == topicId }
    }

    /// Themen, zu denen es überhaupt Aufgaben gibt – Grundlage der freien Themenauswahl.
    public var practiceableTopics: [Topic] {
        let withTasks = Set(practiceableTasks.map(\.topicId))
        return topics.filter { withTasks.contains($0.id) }
    }

    /// Alle Code-Schnipsel des Kurses mit Fundstelle – für Tests und Validierung.
    public var allSnippets: [(location: String, snippet: CodeSnippet)] {
        var result: [(String, CodeSnippet)] = []
        for lesson in allLessons {
            for (index, card) in lesson.theory.enumerated() {
                if let example = card.example { result.append(("\(lesson.id) Theorie \(index + 1)", example)) }
            }
        }
        for task in allTasks {
            if let snippet = task.codeSnippet { result.append(("\(task.id) code", snippet)) }
            switch task.kind {
            case .fillBlank(let spec): result.append(("\(task.id) template", spec.templateSnippet))
            case .code(let spec):
                result.append(("\(task.id) starterCode", spec.starter))
                result.append(("\(task.id) sampleSolution", spec.solution))
            case .ordering(let spec):
                result.append(("\(task.id) puzzle", spec.puzzle))
            case .findBug(let spec):
                if let code = task.codeSnippet { result.append(("\(task.id) fixed", spec.fixed(code))) }
            default: break
            }
        }
        return result
    }

    public var allLessons: [Lesson] { modules.flatMap(\.lessons) }

    public func topic(id: String) -> Topic? { topics.first { $0.id == id } }

    public func lesson(id: String) -> Lesson? { allLessons.first { $0.id == id } }

    public func module(containingLesson lessonId: String) -> CourseModule? {
        modules.first { module in module.lessons.contains { $0.id == lessonId } }
    }

    /// Erstes Modul, das zur Stufe gehört – dort landet man nach der Einstufung.
    public func entryModule(for level: ExperienceLevel) -> CourseModule? {
        modules.first { $0.tier == level }
    }

    /// Erste Lektion, in der ein Thema behandelt wird.
    public func firstLesson(teaching topicId: String) -> Lesson? {
        allLessons.first { $0.topicIds.contains(topicId) }
    }
}

public struct Topic: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let symbol: String
    public let summary: String
}

public struct CourseModule: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let tier: ExperienceLevel
    public let symbol: String
    public let lessons: [Lesson]
}

public struct Lesson: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let summary: String
    public let topicIds: [String]
    public let estimatedMinutes: Int
    public let theory: [TheoryCard]
    public let tasks: [LearningTask]

    /// Punktgewicht der Lektion im Java Master Score (Summe der Aufgabenniveaus).
    /// Bonus-Aufgaben zählen nicht mit (siehe `TaskType.isBonus`).
    public var difficultyWeight: Double { tasks.filter { !$0.type.isBonus }.reduce(0) { $0 + $1.difficulty.weight } }
}

/// Ein „Theorie-Happen“: eine kurze Karte mit Text, optional Codebeispiel (mit
/// Zeile-für-Zeile-Erklärung) und Hinweis.
public struct TheoryCard: Decodable, Sendable, Hashable {
    public let title: String
    public let body: String
    public let example: CodeSnippet?
    public let callout: Callout?
    /// UML-Klassendiagramm zur Karte – wird unter dem Text gezeichnet.
    public let diagram: UMLDiagram?

    enum CodingKeys: String, CodingKey { case title, body, example = "code", callout, diagram }

    public var code: String? { example?.source }

    public struct Callout: Decodable, Sendable, Hashable {
        public enum Kind: String, Decodable, Sendable { case tip, warning, info }
        public let kind: Kind
        public let text: String
    }
}

public struct PlacementConfig: Decodable, Sendable, Hashable {
    /// Ab diesem Prozentwert gilt der Test als bestanden (Standard: 65).
    public let passThreshold: Int
    /// Ab diesem Prozentwert geht es nicht nur am Grundkurs, sondern auch am Mittelteil vorbei.
    /// Ältere Kursdateien ohne diesen Schlüssel bekommen einen Wert, der nie erreicht wird –
    /// dann verhält sich die Einstufung wie zuvor.
    public let advancedThreshold: Int
    public let questionsPerTest: Int
    public let startDifficulty: Int
    /// Fragenpools je Stufe, Schlüssel ist `ExperienceLevel.rawValue`.
    public let pools: [String: [LearningTask]]

    enum CodingKeys: String, CodingKey {
        case passThreshold, advancedThreshold, questionsPerTest, startDifficulty, pools
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        passThreshold = try container.decode(Int.self, forKey: .passThreshold)
        advancedThreshold = try container.decodeIfPresent(Int.self, forKey: .advancedThreshold) ?? 101
        questionsPerTest = try container.decode(Int.self, forKey: .questionsPerTest)
        startDifficulty = try container.decode(Int.self, forKey: .startDifficulty)
        pools = try container.decode([String: [LearningTask]].self, forKey: .pools)
    }

    public func pool(for level: ExperienceLevel) -> [LearningTask] { pools[level.rawValue] ?? [] }
}

public enum CourseLoadingError: Error, LocalizedError {
    case missingResource(String)

    public var errorDescription: String? {
        switch self {
        case .missingResource(let name): "Die Kursdatei „\(name).json“ fehlt im App-Bundle."
        }
    }
}

public enum CourseLoader {
    public static let bundledResourceName = "java_course"

    /// Lädt den mitgelieferten Kurs – synchron, weil die Datei klein ist und lokal liegt.
    /// Zusatzaufgaben nur für die Apple-App (Code-Puzzle, Bug-Jagd). Die gemeinsame Kursdatei bleibt
    /// unverändert, damit Windows, Android und Web sie weiter lesen können.
    public static let appleExtraTasksResourceName = "apple_extra_tasks"

    public static func loadBundled() throws -> Course {
        guard let url = resourceBundle.url(forResource: bundledResourceName, withExtension: "json") else {
            throw CourseLoadingError.missingResource(bundledResourceName)
        }
        var data = try Data(contentsOf: url)
        if let extra = resourceBundle.url(forResource: appleExtraTasksResourceName, withExtension: "json") {
            data = try mergingExtraTasks(into: data, extra: Data(contentsOf: extra))
        }
        return try load(from: data)
    }

    /// Sortiert Zusatzaufgaben in ihre Lektionen ein – hinter die letzte Aufgabe mit gleichem oder
    /// niedrigerem Niveau, damit jede Lektion aufsteigend bleibt.
    static func mergingExtraTasks(into course: Data, extra: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: course) as? [String: Any],
              var modules = root["modules"] as? [[String: Any]],
              let byLesson = (try JSONSerialization.jsonObject(with: extra) as? [String: Any])?["lessons"] as? [String: [[String: Any]]]
        else { return course }
        for m in modules.indices {
            guard var lessons = modules[m]["lessons"] as? [[String: Any]] else { continue }
            for l in lessons.indices {
                guard let id = lessons[l]["id"] as? String, let additions = byLesson[id],
                      var tasks = lessons[l]["tasks"] as? [[String: Any]] else { continue }
                for task in additions {
                    let level = task["difficulty"] as? Int ?? 1
                    let position = (tasks.lastIndex { ($0["difficulty"] as? Int ?? 1) <= level } ?? -1) + 1
                    tasks.insert(task, at: position)
                }
                lessons[l]["tasks"] = tasks
            }
            modules[m]["lessons"] = lessons
        }
        root["modules"] = modules
        return try JSONSerialization.data(withJSONObject: root)
    }

    public static func load(from data: Data) throws -> Course {
        try JSONDecoder().decode(Course.self, from: data)
    }

    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }
}

private final class BundleToken {}
