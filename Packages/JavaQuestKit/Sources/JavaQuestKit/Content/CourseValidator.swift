import Foundation

public struct CourseIssue: Sendable, Hashable, CustomStringConvertible {
    public let location: String
    public let message: String

    public var description: String { "\(location): \(message)" }
}

/// Prüft die Kursdatei auf Konsistenz. Läuft in den Tests und in Debug-Builds
/// beim App-Start, damit fehlerhafte Inhalte nie unbemerkt ausgeliefert werden.
public enum CourseValidator {
    public static func validate(_ course: Course) -> [CourseIssue] {
        var issues: [CourseIssue] = []
        let topicIds = Set(course.topics.map(\.id))
        var seenIds: Set<String> = []

        func unique(_ id: String, _ location: String) {
            if !seenIds.insert(id).inserted { issues.append(CourseIssue(location: location, message: "ID „\(id)“ ist doppelt vergeben")) }
        }

        course.topics.forEach { unique($0.id, "Thema \($0.id)") }

        for module in course.modules {
            unique(module.id, "Modul \(module.id)")
            if module.lessons.isEmpty { issues.append(CourseIssue(location: module.id, message: "Modul ohne Lektionen")) }
            for lesson in module.lessons {
                let location = "Lektion \(lesson.id)"
                unique(lesson.id, location)
                if lesson.theory.isEmpty { issues.append(CourseIssue(location: location, message: "Keine Theorie-Karten")) }
                if lesson.tasks.count < 3 { issues.append(CourseIssue(location: location, message: "Weniger als 3 Aufgaben")) }
                for topicId in lesson.topicIds where !topicIds.contains(topicId) {
                    issues.append(CourseIssue(location: location, message: "Unbekanntes Thema „\(topicId)“"))
                }
                let levels = lesson.tasks.map(\.difficulty)
                if levels != levels.sorted() {
                    issues.append(CourseIssue(location: location, message: "Aufgaben sind nicht nach Niveau aufsteigend sortiert"))
                }
                for task in lesson.tasks {
                    if !lesson.topicIds.contains(task.topicId) {
                        issues.append(CourseIssue(location: "Aufgabe \(task.id)", message: "Thema „\(task.topicId)“ fehlt in topicIds der Lektion"))
                    }
                    issues += validate(task, topicIds: topicIds, unique: unique)
                }
            }
        }

        for level in ExperienceLevel.allCases where course.entryModule(for: level) == nil {
            issues.append(CourseIssue(location: "Kurs", message: "Kein Einstiegsmodul für Stufe \(level.rawValue)"))
        }

        for (location, snippet) in course.allSnippets {
            let missing = snippet.linesMissingExplanation
            if !missing.isEmpty {
                issues.append(CourseIssue(location: location, message: "Zeile(n) \(missing.map(String.init).joined(separator: ", ")) ohne Erklärung"))
            }
        }

        let placement = course.placement
        if !(1...100).contains(placement.passThreshold) {
            issues.append(CourseIssue(location: "Einstufung", message: "passThreshold muss zwischen 1 und 100 liegen"))
        }
        for level in ExperienceLevel.allCases where level.requiresPlacement {
            let pool = placement.pool(for: level)
            if pool.count < placement.questionsPerTest {
                issues.append(CourseIssue(location: "Einstufung \(level.rawValue)", message: "Pool hat weniger Fragen als questionsPerTest"))
            }
            for task in pool { issues += validate(task, topicIds: topicIds, unique: unique) }
        }
        return issues
    }

    private static func validate(_ task: LearningTask, topicIds: Set<String>, unique: (String, String) -> Void) -> [CourseIssue] {
        let location = "Aufgabe \(task.id)"
        unique(task.id, location)
        var issues: [CourseIssue] = []
        if !topicIds.contains(task.topicId) {
            issues.append(CourseIssue(location: location, message: "Unbekanntes Thema „\(task.topicId)“"))
        }

        switch task.kind {
        case .singleChoice(let spec):
            if spec.choices.count < 2 { issues.append(CourseIssue(location: location, message: "Weniger als 2 Antwortoptionen")) }
            if !spec.choices.indices.contains(spec.correctIndex) {
                issues.append(CourseIssue(location: location, message: "correctIndex liegt außerhalb der Optionen"))
            }
            if Set(spec.choices).count != spec.choices.count {
                issues.append(CourseIssue(location: location, message: "Antwortoptionen sind nicht eindeutig"))
            }
        case .fillBlank(let spec):
            for index in spec.blanks.indices {
                let occurrences = spec.template.components(separatedBy: FillBlankSpec.placeholder(index)).count - 1
                if occurrences != 1 {
                    issues.append(CourseIssue(location: location, message: "Platzhalter {{\(index)}} kommt \(occurrences)-mal vor"))
                }
            }
            if spec.blanks.contains(where: { $0.accepted.isEmpty }) {
                issues.append(CourseIssue(location: location, message: "Lücke ohne akzeptierte Antwort"))
            }
        case .predictOutput(let spec):
            if spec.expectedOutput.isEmpty { issues.append(CourseIssue(location: location, message: "expectedOutput ist leer")) }
        case .code(let spec):
            // anyOf zählt wie require: Auch damit muss etwas erfüllt sein.
            if !spec.rules.contains(where: { $0.rule == .require || $0.rule == .anyOf }) {
                issues.append(CourseIssue(location: location, message: "Code-Aufgabe ohne fordernde Regel"))
            }
            for rule in spec.rules where rule.rule == .anyOf && rule.patterns.count < 2 {
                issues.append(CourseIssue(location: location,
                                          message: "anyOf mit \(rule.patterns.count) Muster – das ist ein require"))
            }
            for rule in spec.rules {
                for muster in rule.allPatterns where (try? NSRegularExpression(pattern: muster)) == nil {
                    issues.append(CourseIssue(location: location, message: "Ungültige RegEx „\(muster)“"))
                }
            }
        }

        let evaluator = AnswerEvaluator()
        if !evaluator.evaluate(evaluator.referenceAnswer(for: task), for: task).isCorrect {
            issues.append(CourseIssue(location: location, message: "Die Musterlösung wird vom Evaluator nicht akzeptiert"))
        }
        return issues
    }
}
