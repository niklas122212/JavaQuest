import Foundation

/// Der komplette, lokal gebündelte Kurs (siehe `Resources/java_course.json`).
public struct Course: Decodable, Sendable, Hashable {
    public let schemaVersion: Int
    public let id: String
    public let title: String
    public let topics: [Topic]
    public let modules: [CourseModule]
    public let placement: PlacementConfig
    public var allTasks: [LearningTask] {
        allLessons.flatMap(\.tasks) + ExperienceLevel.allCases.flatMap { placement.pool(for: $0) }
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
    public var difficultyWeight: Double { tasks.reduce(0) { $0 + $1.difficulty.weight } }
}

/// Ein „Theorie-Happen“: eine kurze Karte mit Text, optional Codebeispiel (mit
/// Zeile-für-Zeile-Erklärung) und Hinweis.
public struct TheoryCard: Decodable, Sendable, Hashable {
    public let title: String
    public let body: String
    public let example: CodeSnippet?
    public let callout: Callout?

    enum CodingKeys: String, CodingKey { case title, body, example = "code", callout }

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
    public let questionsPerTest: Int
    public let startDifficulty: Int
    /// Fragenpools je Stufe, Schlüssel ist `ExperienceLevel.rawValue`.
    public let pools: [String: [LearningTask]]

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
    public static func loadBundled() throws -> Course {
        guard let url = resourceBundle.url(forResource: bundledResourceName, withExtension: "json") else {
            throw CourseLoadingError.missingResource(bundledResourceName)
        }
        return try load(from: Data(contentsOf: url))
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
