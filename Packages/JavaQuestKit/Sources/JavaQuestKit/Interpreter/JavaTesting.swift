import Foundation

/// Ergebnis eines versteckten Tests: der Wert des Ausdrucks, die Ausgabe dabei – oder der Fehler.
public struct JavaTestOutcome: Sendable {
    /// Der Wert in vergleichbarer Form; nil, wenn der Test mit einem Fehler endete.
    public let value: JavaTestValue?
    /// So würde `System.out.println` den Wert zeigen (bei Objekten über `toString()`).
    public let text: String?
    /// Typ des Werts, wie Java ihn nennt (`int`, `boolean`, `String`, `Golem` …).
    public let typeName: String?
    /// Was das Programm während des Tests ausgegeben hat.
    public let output: String
    public let problem: JavaProblem?
    /// Scheitert schon der Testcode selbst (fehlende Methode, falscher Konstruktor), steht hier die Zeile
    /// des Tests, die nicht klappt – z. B. `Tuer.unlock(105)`. Die Zeilennummer im Fehler gehört dann nicht
    /// zum Code des Spielers und ist entfernt.
    public var failingTestCode: String? = nil
}

/// Ein Testwert ohne Interpreter-Innenleben – damit Quests ihn mit dem erwarteten Wert vergleichen können.
public enum JavaTestValue: Sendable, Hashable {
    case integer(Int64)
    case double(Double)
    case boolean(Bool)
    case char(String)
    case string(String)
    case null
    case void
    /// Objekte, Arrays und Sammlungen – verglichen wird über ihren Text.
    case other(String)
}

extension JavaRunner {
    /// Testet ein Programm wie ein JUnit-Test: Klassen und statische Felder werden geladen, `main`
    /// läuft nicht. Dann kommen die Anweisungen aus `setup` und zuletzt der Ausdruck `expression`
    /// (z. B. `Tuer.unlock(105)`), dessen Wert zurückkommt. Ohne Ausdruck zählt nur die Ausgabe.
    public static func test(_ source: String, setup: String = "", expression: String?, stepLimit: Int = 40_000) -> JavaTestOutcome {
        let box = TestBox()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            box.outcome = testDirectly(source, setup: setup, expression: expression, stepLimit: stepLimit)
            done.signal()
        }
        thread.stackSize = 64 << 20
        thread.start()
        done.wait()
        return box.outcome ?? JavaTestOutcome(value: nil, text: nil, typeName: nil, output: "",
                                              problem: .runtime("Der Test konnte nicht gestartet werden.", line: nil))
    }

    /// Name der Hilfsklasse, in der Vorbereitung und Ausdruck eines Tests stehen.
    static let testClassName = "QuestTest__"

    static func testDirectly(_ source: String, setup: String, expression: String?, stepLimit: Int) -> JavaTestOutcome {
        let failed = { (problem: JavaProblem) in JavaTestOutcome(value: nil, text: nil, typeName: nil, output: "", problem: problem) }
        let normalized = JavaSource.normalizingTypography(source)
        // Erst den Code des Spielers allein – damit Fehler darin ihre echte Zeilennummer behalten.
        do {
            _ = try JavaParser.parse(normalized)
        } catch {
            return failed(error)
        }
        // Dann zusammen mit dem Testcode: So kennt die Vorbereitung alle Klassen des Spielers
        // (`Golem g = new Golem("Rolf");`). Der Ausdruck steht in einem println und wird dort herausgelöst.
        let harness = """
        \(normalized)

        class \(testClassName) {
            static void vorbereiten() {
        \(setup)
            }
            static void ausdruck() {
                System.out.println(\(expression ?? "0"));
            }
        }
        """
        var program: JavaProgram
        let setupStatements: [JavaStmt]
        let expr: JavaExpr?
        do {
            program = try JavaParser.parse(harness)
            guard let testClass = program.classes[testClassName],
                  let prepare = testClass.methods["vorbereiten"]?.first,
                  let evaluate = testClass.methods["ausdruck"]?.first,
                  case .expr(.call(_, "println", let args, _), _)? = evaluate.body.first, args.count == 1 else {
                return failed(JavaProblem(.unsupported, "Testcode: Der Test lässt sich nicht aufbauen.", line: nil))
            }
            setupStatements = prepare.body
            expr = expression == nil ? nil : args[0]
        } catch {
            return failed(JavaProblem(.unsupported, "Testcode: \(error.description)", line: nil))
        }
        program.classes[testClassName] = nil
        program.classOrder.removeAll { $0 == testClassName }

        let interpreter = JavaInterpreter(program: program, stepLimit: stepLimit, host: nil)
        let (value, problem) = interpreter.runTest(setup: setupStatements, expression: expr)
        guard let value, problem == nil else {
            let playerLines = normalized.components(separatedBy: "\n").count
            if let problem, let line = problem.line, line > playerLines {
                // Der Fehler steckt im Testcode – meist ruft der Test etwas auf, das es (so) noch nicht gibt.
                let harnessLines = harness.components(separatedBy: "\n")
                var code = line <= harnessLines.count ? harnessLines[line - 1].trimmingCharacters(in: .whitespaces) : ""
                if code.hasPrefix("System.out.println("), code.hasSuffix(");") {
                    code = String(code.dropFirst("System.out.println(".count).dropLast(2))
                }
                var moved = JavaProblem(problem.kind, problem.message, line: nil)
                moved.exceptionClass = problem.exceptionClass
                moved.javaMessage = problem.javaMessage
                moved.thrown = problem.thrown
                return JavaTestOutcome(value: nil, text: nil, typeName: nil, output: interpreter.output, problem: moved,
                                       failingTestCode: code.isEmpty ? nil : code)
            }
            return JavaTestOutcome(value: nil, text: nil, typeName: nil, output: interpreter.output, problem: problem)
        }
        let text = (try? interpreter.printable(value, line: 0)) ?? value.javaString
        return JavaTestOutcome(value: JavaTestValue(value, text: text), text: text, typeName: value.typeName,
                               output: interpreter.output, problem: nil)
    }

    private final class TestBox: @unchecked Sendable {
        var outcome: JavaTestOutcome?
    }
}

extension JavaTestValue {
    init(_ value: JavaValue, text: String) {
        switch value {
        case .int(let v): self = .integer(Int64(v))
        case .long(let v): self = .integer(v)
        case .double(let v): self = .double(v)
        case .boolean(let v): self = .boolean(v)
        case .char: self = .char(value.javaString)
        case .string(let s): self = .string(s.text)
        case .null: self = .null
        case .void: self = .void
        case .array, .object: self = .other(text)
        }
    }
}

extension JavaInterpreter {
    /// Lädt Klassen und statische Felder, führt die Testanweisungen aus und wertet den Ausdruck aus –
    /// ohne `main` des Programms.
    func runTest(setup: [JavaStmt], expression: JavaExpr?) -> (JavaValue?, JavaProblem?) {
        do throws(JavaProblem) {
            try validateClasses()
            try initializeClasses()
            for field in program.staticFields {
                _ = try execute(field, global: true)
            }
            for statement in setup {
                _ = try execute(statement)
            }
            guard let expression else { return (.void, nil) }
            return (try evaluate(expression), nil)
        } catch {
            return (nil, error)
        }
    }
}
