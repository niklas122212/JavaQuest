import Foundation
import Testing
@testable import JavaQuestKit

@Suite("Java-Interpreter")
struct InterpreterTests {
    struct DifferentialCase: Decodable {
        let name: String
        let source: String
        let expected: String
    }

    static func differentialCases() throws -> [DifferentialCase] {
        let url = try #require(Bundle.module.url(forResource: "java_differential", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode([DifferentialCase].self, from: Data(contentsOf: url))
    }

    @Test("Gleiche Ausgabe wie ein echtes JDK")
    func matchesRealJava() throws {
        for testCase in try Self.differentialCases() {
            let result = JavaRunner.run(testCase.source)
            #expect(result.problem == nil, "\(testCase.name): \(result.problem?.description ?? "")")
            let expected = testCase.expected.components(separatedBy: "\n")
            let actual = result.output.components(separatedBy: "\n")
            for (index, line) in expected.enumerated() where index >= actual.count || actual[index] != line {
                Issue.record("\(testCase.name) Zeile \(index + 1): erwartet „\(line)“, bekommen „\(index < actual.count ? actual[index] : "<fehlt>")“")
                break
            }
            #expect(actual.count == expected.count, "\(testCase.name): \(actual.count) statt \(expected.count) Zeilen")
        }
    }

    func problem(_ source: String) -> JavaProblem? { JavaRunner.run(source).problem }

    @Test("Fehler werden mit Zeile und verständlicher Meldung gemeldet")
    func errorsAreExplained() throws {
        let semicolon = try #require(problem("int x = 5\nSystem.out.println(x);"))
        #expect(semicolon.kind == .syntax)
        #expect(semicolon.line == 1)
        #expect(semicolon.message.contains("Semikolon"))

        let unknown = try #require(problem("int zahl = 3;\nSystem.out.println(Zahl);"))
        #expect(unknown.line == 2)
        #expect(unknown.message.contains("Meintest du „zahl“"))

        let types = try #require(problem("int x = 2.5;"))
        #expect(types.message.contains("(int)"))

        let index = try #require(problem("int[] a = new int[3];\na[3] = 1;"))
        #expect(index.kind == .runtime)
        #expect(index.message.contains("ArrayIndexOutOfBoundsException"))
        #expect(index.line == 2)

        let division = try #require(problem("int a = 5;\nint b = 0;\nSystem.out.println(a / b);"))
        #expect(division.kind == .runtime)
        #expect(division.line == 3)

        let duplicate = try #require(problem("int x = 1;\nint x = 2;"))
        #expect(duplicate.message.contains("gibt es hier schon"))

        let assignInIf = try #require(problem("int x = 1;\nif (x = 2) { }"))
        #expect(assignInIf.message.contains("=="))

        let missingReturn = try #require(problem("static int f(int x) {\n  if (x > 0) return 1;\n}\nSystem.out.println(f(-1));"))
        #expect(missingReturn.message.contains("return"))

        let finalChange = try #require(problem("final int MAX = 3;\nMAX = 4;"))
        #expect(finalChange.message.contains("final"))
    }

    @Test("Endlosschleifen und endlose Rekursion werden sauber gestoppt")
    func limits() throws {
        let loop = JavaRunner.run("int i = 0;\nwhile (i < 10) {\n  System.out.print(\"\");\n}", stepLimit: 5_000)
        #expect(loop.problem?.kind == .stepLimit)

        let recursion = try #require(problem("static int f(int n) { return f(n + 1); }\nSystem.out.println(f(0));"))
        #expect(recursion.message.contains("StackOverflowError"))
    }

    @Test("Unbekannte Java-Bausteine werden als „nicht unterstützt“ erkannt, nicht als Fehler")
    func unsupportedConstructs() {
        let samples = [
            "List<String> l = new ArrayList<>();",
            "class Hund { String name; Hund(String n) { name = n; } }",
            "try { int x = 1; } catch (Exception e) { }",
            "Runnable r = () -> System.out.println(1);",
            "float f = 1.5f;",
            "sealed interface Form permits Kreis {}\nrecord Kreis(double r) implements Form {}",
        ]
        for sample in samples {
            #expect(problem(sample)?.kind == .unsupported, "\(sample): \(problem(sample)?.description ?? "kein Problem")")
        }
    }

    @Test("Strings mit == vergleichen erzeugt einen Hinweis")
    func stringComparisonWarning() {
        let result = JavaRunner.run("String a = \"x\";\nString b = \"x\";\nif (a == b) System.out.println(1);")
        #expect(result.warnings.contains { $0.message.contains("equals") && $0.line == 3 })
    }

    @Test("Java-Formatierung von Kommazahlen")
    func doubleFormatting() {
        #expect(JavaFormat.double(1e7) == "1.0E7")
        #expect(JavaFormat.double(1.5e-5) == "1.5E-5")
        #expect(JavaFormat.double(123.0) == "123.0")
        #expect(JavaFormat.double(0.001) == "0.001")
        #expect(JavaFormat.double(-2.5) == "-2.5")
    }
}

@Suite("Interpreter × Kursinhalt")
struct InterpreterCourseTests {
    let course: Course

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    /// Jede Aufgabe mit bekannter Ausgabe, deren Code der Interpreter versteht, muss exakt diese Ausgabe liefern.
    @Test("Wo der Interpreter den Kurscode versteht, rechnet er wie Java")
    func runnableCourseCodeMatchesExpectedOutput() {
        var supported = 0
        var unsupported: [String] = []
        for task in course.allTasks {
            let source: String
            let expected: String
            switch task.kind {
            case .predictOutput(let spec):
                guard let code = task.code else { continue }
                source = code
                expected = spec.expectedOutput
            case .code(let spec):
                guard let output = spec.expectedOutput else { continue }
                source = spec.sampleSolution
                expected = output
            default:
                continue
            }
            let result = JavaRunner.run(source)
            if result.problem?.kind == .unsupported {
                unsupported.append(task.id)
                continue
            }
            supported += 1
            #expect(result.problem == nil, "\(task.id): \(result.problem?.description ?? "")")
            #expect(AnswerEvaluator.outputLines(result.output) == AnswerEvaluator.outputLines(expected), "\(task.id): „\(result.output)“ statt „\(expected)“")
        }
        print("Interpreter versteht \(supported) Aufgaben, nicht: \(unsupported.joined(separator: ", "))")
        // Module 1–3: Variablen, Kontrollfluss, Methoden, Arrays, Strings. Klassen, Collections und Lambdas bleiben bei der Regelprüfung.
        #expect(supported >= 17)
    }
}
