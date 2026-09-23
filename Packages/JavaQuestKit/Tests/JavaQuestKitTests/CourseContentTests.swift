import Foundation
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
        course.practiceableTasks + ExperienceLevel.allCases.flatMap { course.placement.pool(for: $0) }
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

    @Test("Einstufung: mehrere Fragen, auf jeder Stufe eine Auswahl")
    func placementPool() {
        let pool = course.placement.pool(for: .intermediate)
        #expect(course.placement.questionsPerTest == 5)
        #expect(course.placement.passThreshold == 65)
        #expect(course.placement.advancedThreshold == 85)
        // Der Test ist adaptiv: Er braucht auf jeder Stufe etwas zur Auswahl,
        // sonst kann er nach einer richtigen Antwort nicht schwerer werden.
        for level in Difficulty.allCases {
            let count = pool.filter { $0.difficulty == level }.count
            #expect(count >= 2, "Stufe \(level.rawValue) hat nur \(count) Einstufungsfrage(n)")
        }
        // Unterschiedliche Themen, damit nicht eine Wissenslücke das Ergebnis kippt.
        #expect(Set(pool.map(\.topicId)).count >= 8)
        #expect(pool.count >= course.placement.questionsPerTest)
    }

    @Test("Jede Erklärung sagt nicht nur WAS, sondern auch WARUM")
    func explanationsAreSubstantial() {
        // Die Länge ist kein Qualitätsmaß, sondern eine Untergrenze: Ein Satz wie
        // „int steht für ganze Zahlen.“ nennt nur den Begriff und hilft beim Lernen nicht weiter.
        let mindestens = 90
        let knapp = course.practiceableTasks.filter { $0.explanation.count < mindestens }
        #expect(knapp.isEmpty, "zu knapp: \(knapp.map { "\($0.id) (\($0.explanation.count))" })")
    }

    @Test("Nach einer falschen Antwort steht da, warum sie falsch war")
    func everyChoiceHasAReason() {
        for task in course.practiceableTasks {
            guard case .singleChoice(let spec) = task.kind else { continue }
            let richtig = spec.choices[spec.correctIndex]
            for index in spec.choices.indices where index != spec.correctIndex {
                guard let grund = spec.whyWrong(index), !grund.isEmpty else {
                    #expect(Bool(false), "\(task.id): keine Begründung für „\(spec.choices[index])“")
                    continue
                }
                // Die Begründung erscheint, solange noch Versuche offen sind. Nennt sie die
                // richtige Antwort, ist der Rest der Aufgabe erledigt.
                #expect(!Self.enthaeltWort(richtig, in: grund),
                        "\(task.id): Begründung zu „\(spec.choices[index])“ nennt die Lösung")
            }
        }
    }

    @Test("Jede Aufgabe hat einen Tipp – und der verrät die Lösung nicht")
    func everyTaskHasAHint() {
        // Ein Tipp ist die Zwischenstufe zwischen Feststecken und Lösung aufdecken.
        // Ohne ihn bleibt nur die Wahl zwischen Weiterraten und Aufgeben.
        let mindestens = 25
        for task in course.practiceableTasks {
            let tipp = (task.hint ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!tipp.isEmpty, "\(task.id): kein Tipp")
            #expect(tipp.count >= mindestens, "\(task.id): Tipp zu knapp (\(tipp.count))")
            #expect(tipp != task.explanation, "\(task.id): Tipp wiederholt nur die Erklärung")
            switch task.kind {
            case .singleChoice(let spec):
                let richtig = spec.choices[spec.correctIndex]
                #expect(!Self.enthaeltWort(richtig, in: tipp), "\(task.id): Tipp verrät die Antwort")
            case .predictOutput(let spec):
                for zeile in spec.expectedOutput.split(separator: "\n") {
                    let text = zeile.trimmingCharacters(in: .whitespaces)
                    guard text.count >= 4 else { continue }
                    #expect(!Self.enthaeltWort(text, in: tipp), "\(task.id): Tipp verrät die Ausgabe")
                }
            default:
                break
            }
        }
    }

    /// Kommt `wort` als eigenständiges Wort in `text` vor? „int“ steckt auch in
    /// „integer“ – das ist eine Umschreibung und keine verratene Lösung.
    static func enthaeltWort(_ wort: String, in text: String) -> Bool {
        let muster = "(?<!\\w)" + NSRegularExpression.escapedPattern(for: wort.lowercased()) + "(?!\\w)"
        guard let regex = try? NSRegularExpression(pattern: muster) else { return false }
        let ziel = text.lowercased()
        return regex.firstMatch(in: ziel, range: NSRange(ziel.startIndex..., in: ziel)) != nil
    }

    @Test("Keine Stufe besteht aus einem einzigen Aufgabentyp")
    func noLevelIsOneSided() {
        // Wer auf einer Stufe nur „Was gibt das aus?“ bekommt, übt eine einzige Fertigkeit.
        var nachStufe: [String: [TaskType]] = [:]
        for task in course.practiceableTasks {
            nachStufe["\(task.topicId)/\(task.difficulty.rawValue)", default: []].append(task.kind.type)
        }
        for (stufe, typen) in nachStufe where typen.count >= 3 {
            #expect(Set(typen).count > 1, "\(stufe): alle \(typen.count) Aufgaben vom selben Typ")
        }
    }

    @Test("Kein Thema besteht überwiegend aus „Was gibt das aus?“")
    func noTopicIsDominatedByPredictOutput() {
        var nachThema: [String: [TaskType]] = [:]
        for task in course.practiceableTasks {
            nachThema[task.topicId, default: []].append(task.kind.type)
        }
        for (thema, typen) in nachThema {
            let anteil = Double(typen.filter { $0 == .predictOutput }.count) / Double(typen.count)
            #expect(anteil <= 0.5, "\(thema): \(Int(anteil * 100)) % Ausgabe-Aufgaben")
        }
    }

    @Test("Jedes Lernziel hat mindestens drei Varianten")
    func everyGoalHasThreeVariants() {
        // Zwei Varianten reichen nicht: Wer eine falsch hat, bekommt beim nächsten Mal
        // zwangsläufig die andere – und kennt sie dann schon.
        var nachZiel: [String: Int] = [:]
        for task in course.practiceableTasks {
            nachZiel[task.groupKey, default: 0] += 1
        }
        let knapp = nachZiel.filter { $0.value < 3 }
        #expect(knapp.isEmpty, "zu wenige Varianten: \(knapp.keys.sorted())")
    }

    @Test("Alle Themen werden in einer Lektion behandelt")
    func everyTopicIsTaught() {
        for topic in course.topics {
            #expect(course.firstLesson(teaching: topic.id) != nil, "\(topic.id)")
        }
    }
}
