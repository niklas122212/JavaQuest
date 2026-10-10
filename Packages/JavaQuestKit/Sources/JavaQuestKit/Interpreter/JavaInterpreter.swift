import Foundation

/// Eine sichtbare Variable zum Zeitpunkt eines Programmschritts (für die Arena-Anzeige).
public struct JavaVariable: Sendable, Hashable {
    public let name: String
    public let type: String
    public let value: String
}

/// Ort, an dem ein Host-Objekt (z. B. der Roboter) aufgerufen wurde.
public struct JavaCallContext: Sendable {
    public let line: Int
    public let variables: [JavaVariable]
    /// Bisherige Konsolenausgabe – damit der Host sie z. B. in Animations-Frames übernehmen kann.
    public let output: String
}

/// Stellt Objekte bereit, die im Code ohne Deklaration benutzt werden dürfen – etwa `robot`.
public protocol JavaHost: AnyObject, Sendable {
    var objectNames: Set<String> { get }
    /// Braucht der Host beim nächsten Aufruf Variablen und Ausgabe? (Spart Zeit, wenn nicht.)
    var wantsSnapshot: Bool { get }
    func call(object: String, method: String, args: [JavaValue], context: JavaCallContext) throws(JavaProblem) -> JavaValue
}

public struct JavaWarning: Sendable, Hashable {
    public let message: String
    public let line: Int
}

/// Ein Schritt beim Zusehen: Diese Zeile ist als Nächstes dran – mit allem, was bis dahin passiert ist.
public struct JavaTraceStep: Sendable, Hashable {
    /// Zeile, die gleich ausgeführt wird; `nil` beim letzten Bild (Programm zu Ende).
    public let line: Int?
    /// Methode, in der das Programm gerade steckt (`nil` = Hauptprogramm).
    public let method: String?
    public let variables: [JavaVariable]
    /// Konsolenausgabe bis zu diesem Moment.
    public let output: String
}

/// Der aufgezeichnete Ablauf eines Programms – für „Ausführen und zusehen“.
public struct JavaTrace: Sendable {
    public let steps: [JavaTraceStep]
    /// Laufzeitfehler, an dem das Programm stehen blieb (Teil der Lektion, z. B. Division durch 0).
    public let problem: JavaProblem?
    /// Mehr Schritte als aufgezeichnet – der Ablauf zeigt nur den Anfang.
    public let isTruncated: Bool

    /// Lohnt sich das Zusehen? Der Interpreter kennt alle Bausteine, und es passiert mehr als ein Schritt.
    public var isUseful: Bool {
        guard steps.count >= 3 else { return false }
        if let problem, problem.kind == .syntax || problem.kind == .unsupported { return false }
        return true
    }
}

public struct JavaRunResult: Sendable {
    /// Alles, was das Programm bis zum Ende (oder bis zum Fehler) ausgegeben hat.
    public let output: String
    public let problem: JavaProblem?
    public let steps: Int
    /// Hinweise auf typische Stolpersteine, z. B. Strings mit == vergleichen.
    public let warnings: [JavaWarning]

    public var succeeded: Bool { problem == nil }
}

/// Führt Java-Code aus – komplett lokal, ohne JVM.
public enum JavaRunner {
    public static let defaultStepLimit = 200_000

    /// Prüft nur die Syntax (und ob der Interpreter alle Bausteine kennt).
    public static func check(_ source: String) -> JavaProblem? {
        do {
            _ = try JavaParser.parse(source)
            return nil
        } catch {
            return error
        }
    }

    /// Führt das Programm aus. Läuft auf einem eigenen Thread mit großem Stack,
    /// damit auch tiefe Rekursion sauber als StackOverflowError gemeldet wird statt abzustürzen.
    public static func run(_ source: String, stepLimit: Int = defaultStepLimit, host: (any JavaHost)? = nil) -> JavaRunResult {
        let box = ResultBox()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            box.result = runDirectly(source, stepLimit: stepLimit, host: host)
            done.signal()
        }
        thread.stackSize = 64 << 20
        thread.start()
        done.wait()
        return box.result ?? JavaRunResult(output: "", problem: .runtime("Das Programm konnte nicht gestartet werden.", line: nil), steps: 0, warnings: [])
    }

    static func runDirectly(_ source: String, stepLimit: Int, host: (any JavaHost)?) -> JavaRunResult {
        let program: JavaProgram
        do {
            program = try JavaParser.parse(source)
        } catch {
            return JavaRunResult(output: "", problem: error, steps: 0, warnings: [])
        }
        let interpreter = JavaInterpreter(program: program, stepLimit: stepLimit, host: host)
        let problem = interpreter.run()
        return JavaRunResult(output: interpreter.output, problem: problem, steps: interpreter.steps, warnings: interpreter.warnings)
    }

    /// Führt das Programm aus und zeichnet jeden Schritt auf: welche Zeile dran ist, welche Variablen es
    /// gibt und was schon ausgegeben wurde. Höchstens `maxSteps` Bilder – längere Läufe werden abgeschnitten.
    public static func trace(_ source: String, maxSteps: Int = 400) -> JavaTrace {
        let box = TraceBox()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            box.trace = traceDirectly(source, maxSteps: maxSteps)
            done.signal()
        }
        thread.stackSize = 64 << 20
        thread.start()
        done.wait()
        return box.trace ?? JavaTrace(steps: [], problem: .runtime("Das Programm konnte nicht gestartet werden.", line: nil), isTruncated: false)
    }

    static func traceDirectly(_ source: String, maxSteps: Int) -> JavaTrace {
        let program: JavaProgram
        do {
            program = try JavaParser.parse(JavaSource.normalizingTypography(source))
        } catch {
            return JavaTrace(steps: [], problem: error, isTruncated: false)
        }
        // Zusehen soll schnell gehen: Lange Programme werden nach den ersten Schritten abgeschnitten.
        let interpreter = JavaInterpreter(program: program, stepLimit: maxSteps * 20, host: nil)
        let recorder = TraceRecorder(limit: maxSteps)
        interpreter.recorder = recorder
        let problem = interpreter.run()
        let stoppedEarly = recorder.isFull || problem?.kind == .stepLimit
        if !stoppedEarly {
            recorder.steps.append(JavaTraceStep(line: problem?.line, method: nil, variables: interpreter.visibleVariables(), output: interpreter.output))
        }
        return JavaTrace(steps: recorder.steps, problem: problem?.kind == .stepLimit ? nil : problem, isTruncated: stoppedEarly)
    }

    private final class ResultBox: @unchecked Sendable {
        var result: JavaRunResult?
    }

    private final class TraceBox: @unchecked Sendable {
        var trace: JavaTrace?
    }

}

/// Sammelt die Schritte für „Ausführen und zusehen“.
final class TraceRecorder {
    let limit: Int
    var steps: [JavaTraceStep] = []
    var isFull: Bool { steps.count >= limit }

    init(limit: Int) {
        self.limit = limit
    }
}

// MARK: - Interpreter

final class JavaInterpreter {
    struct Slot {
        var type: JavaType
        var value: JavaValue?
        var isFinal: Bool
    }

    final class Frame {
        var scopes: [[String: Slot]] = [[:]]
        let method: JavaMethod?
        /// Das Objekt, dessen Methode oder Konstruktor gerade läuft (`this`).
        let thisObject: JavaObject?
        /// Die Klasse, deren Code gerade läuft – für Felder, statische Methoden und private Zugriffe.
        let currentClass: String?

        init(method: JavaMethod?, thisObject: JavaObject? = nil, currentClass: String? = nil) {
            self.method = method
            self.thisObject = thisObject
            self.currentClass = currentClass
        }
    }

    enum Flow {
        case normal
        case breakLoop
        case continueLoop
        case returned(JavaValue)
        case yielded(JavaValue)
    }

    static let maxCallDepth = 400
    static let maxOutput = 60_000

    let program: JavaProgram
    let stepLimit: Int
    let host: (any JavaHost)?
    private(set) var output = ""
    private(set) var steps = 0
    private(set) var warnings: [JavaWarning] = []
    var globals: [String: Slot] = [:]
    var frames: [Frame] = [Frame(method: nil)]
    /// Statische Felder eigener Klassen (die Hauptklasse nutzt `globals`).
    var statics: [String: [String: Slot]] = [:]
    /// Enum-Konstanten je Enum, in Deklarationsreihenfolge.
    var enumConstants: [String: [JavaObject]] = [:]
    private var randomState: UInt64 = 0x9E37_79B9_7F4A_7C15
    /// Beim Zusehen: zeichnet vor jeder Anweisung und jeder neuen Schleifenrunde ein Bild auf.
    var recorder: TraceRecorder?

    init(program: JavaProgram, stepLimit: Int, host: (any JavaHost)?) {
        self.program = program
        self.stepLimit = stepLimit
        self.host = host
    }

    func run() -> JavaProblem? {
        do throws(JavaProblem) {
            try validateClasses()
            try initializeClasses()
            for field in program.staticFields {
                _ = try execute(field, global: true)
            }
            for statement in program.statements {
                switch try execute(statement) {
                case .normal: continue
                case .returned: return nil
                case .breakLoop: throw JavaProblem.syntax("break steht außerhalb einer Schleife oder eines switch.", line: statement.line)
                case .continueLoop: throw JavaProblem.syntax("continue steht außerhalb einer Schleife.", line: statement.line)
                case .yielded: throw JavaProblem.syntax("yield gibt es nur in switch-Ausdrücken.", line: statement.line)
                }
            }
            return nil
        } catch {
            return error
        }
    }

    // MARK: Variablen

    var frame: Frame { frames[frames.count - 1] }

    private func tick(_ line: Int) throws(JavaProblem) {
        if let recorder {
            if recorder.isFull {
                throw JavaProblem(.stepLimit, "Aufzeichnung voll.", line: line)
            }
            let step = JavaTraceStep(line: line, method: frame.method?.name, variables: visibleVariables(), output: output)
            // Ein Block und seine erste Anweisung können auf derselben Zeile stehen – das ist ein Schritt.
            if recorder.steps.last != step { recorder.steps.append(step) }
        }
        steps += 1
        if steps > stepLimit {
            throw JavaProblem(.stepLimit, "Dein Programm hört nach \(stepLimit.formatted(.number.locale(Locale(identifier: "de_DE")))) Schritten immer noch nicht auf – vermutlich eine Endlosschleife. Prüfe, ob sich die Bedingung der Schleife irgendwann ändert.", line: line)
        }
    }

    func declare(_ name: String, type: JavaType, value: JavaValue?, isFinal: Bool, line: Int, global: Bool = false) throws(JavaProblem) {
        if global {
            if globals[name] != nil { throw .syntax("Das Feld „\(name)“ gibt es schon.", line: line) }
            globals[name] = Slot(type: type, value: value, isFinal: isFinal)
            return
        }
        if frame.scopes.contains(where: { $0[name] != nil }) {
            throw .syntax("Die Variable „\(name)“ gibt es hier schon. Eine Box mit demselben Namen darf es nur einmal geben – zum Ändern einfach \(name) = …; schreiben.", line: line)
        }
        frame.scopes[frame.scopes.count - 1][name] = Slot(type: type, value: value, isFinal: isFinal)
    }

    func lookup(_ name: String) -> Slot? {
        for scope in frame.scopes.reversed() {
            if let slot = scope[name] { return slot }
        }
        // Felder des eigenen Objekts (this.name ohne this)
        if let object = frame.thisObject, let type = object.fieldTypes[name] {
            return Slot(type: type, value: object.fields[name], isFinal: false)
        }
        // Statische Felder der eigenen Klasse und ihrer Oberklassen
        if let slot = staticSlot(name, from: frame.currentClass) { return slot.slot }
        return globals[name]
    }

    func read(_ name: String, line: Int) throws(JavaProblem) -> JavaValue {
        if frame.thisObject == nil, isInstanceField(name), !frame.scopes.contains(where: { $0[name] != nil }) {
            throw .syntax("„\(name)“ ist ein Feld des Objekts – in einer static-Methode gibt es aber kein Objekt (this). Lass static weg oder nimm ein Objekt: objekt.\(name).", line: line)
        }
        guard let slot = lookup(name) else { throw unknownName(name, line: line) }
        guard let value = slot.value else {
            throw .syntax("Die Variable „\(name)“ hat noch keinen Wert. Gib ihr zuerst einen, z. B. \(name) = 0;", line: line)
        }
        return value
    }

    @discardableResult
    func write(_ name: String, _ value: JavaValue, line: Int) throws(JavaProblem) -> JavaValue {
        for index in frame.scopes.indices.reversed() {
            if var slot = frame.scopes[index][name] {
                if slot.isFinal, slot.value != nil {
                    throw .syntax("„\(name)“ ist final – der Wert darf nach dem ersten Festlegen nicht mehr geändert werden.", line: line)
                }
                let stored = try coerce(value, to: slot.type, line: line, what: "Die Variable „\(name)“")
                slot.value = stored
                frame.scopes[index][name] = slot
                return stored
            }
        }
        if let object = frame.thisObject, object.fieldTypes[name] != nil {
            return try writeField(object, name, value, line: line)
        }
        if let found = staticSlot(name, from: frame.currentClass) {
            return try writeStatic(found.owner, name, value, line: line)
        }
        if var slot = globals[name] {
            if slot.isFinal, slot.value != nil {
                throw .syntax("„\(name)“ ist final – der Wert darf nicht mehr geändert werden.", line: line)
            }
            let stored = try coerce(value, to: slot.type, line: line, what: "Das Feld „\(name)“")
            slot.value = stored
            globals[name] = slot
            return stored
        }
        if frame.thisObject == nil, isInstanceField(name) {
            throw .syntax("„\(name)“ ist ein Feld des Objekts – in einer static-Methode gibt es aber kein Objekt (this).", line: line)
        }
        throw unknownName(name, line: line)
    }

    func unknownName(_ name: String, line: Int) -> JavaProblem {
        if host?.objectNames.contains(name) == true {
            return .syntax("„\(name)“ ist ein Objekt – rufe eine seiner Methoden auf, z. B. \(name).move();", line: line)
        }
        if let similar = similarName(to: name) {
            return .syntax("„\(name)“ kennt Java hier nicht. Meintest du „\(similar)“? Achte auf Groß- und Kleinschreibung.", line: line)
        }
        return .syntax("„\(name)“ kennt Java hier nicht. Ist die Variable deklariert (z. B. int \(name) = 0;) und richtig geschrieben?", line: line)
    }

    private func similarName(to name: String) -> String? {
        let known = frame.scopes.flatMap(\.keys) + Array(globals.keys) + Array(host?.objectNames ?? [])
        return known.first { $0.lowercased() == name.lowercased() && $0 != name }
    }

    func visibleVariables() -> [JavaVariable] {
        var merged: [String: Slot] = globals
        var order: [String] = globals.keys.sorted()
        if let object = frame.thisObject {
            // Beim Zusehen: das eigene Objekt mit seinen Feldern
            merged["this"] = Slot(type: .object(object.className), value: .object(object), isFinal: true)
            order.append("this")
        }
        for scope in frame.scopes {
            for (name, slot) in scope.sorted(by: { $0.key < $1.key }) {
                if merged[name] == nil { order.append(name) }
                merged[name] = slot
            }
        }
        return order.compactMap { name in
            guard let slot = merged[name], let value = slot.value else { return nil }
            let type = slot.type == .inferred ? value.type.description : slot.type.description
            return JavaVariable(name: name, type: type, value: value.debugDisplay)
        }
    }

    func warn(_ message: String, line: Int) {
        let warning = JavaWarning(message: message, line: line)
        if !warnings.contains(warning) { warnings.append(warning) }
    }

    // MARK: Anweisungen

    func executeBlock(_ statements: [JavaStmt]) throws(JavaProblem) -> Flow {
        frame.scopes.append([:])
        defer { frame.scopes.removeLast() }
        for statement in statements {
            let flow = try execute(statement)
            if case .normal = flow { continue }
            return flow
        }
        return .normal
    }

    /// Ein einzelner Schleifen-/if-Körper ohne Klammern bekommt trotzdem einen eigenen Bereich.
    func executeBody(_ statement: JavaStmt) throws(JavaProblem) -> Flow {
        if case .block(let statements, _) = statement { return try executeBlock(statements) }
        if case .varDecl(_, _, _, let line) = statement {
            throw .syntax("Eine Variablen-Deklaration braucht hier geschweifte Klammern { … } drumherum.", line: line)
        }
        return try execute(statement)
    }

    func execute(_ statement: JavaStmt, global: Bool = false) throws(JavaProblem) -> Flow {
        try tick(statement.line)
        switch statement {
        case .varDecl(let type, let declarators, let isFinal, _):
            for declarator in declarators {
                var declared = type
                for _ in 0..<declarator.extraDimensions { declared = .array(declared) }
                var value: JavaValue?
                if let initializer = declarator.initializer {
                    let raw = try evaluate(initializer, expected: declared)
                    if declared == .inferred {
                        if case .null = raw { throw .syntax("Mit var kann Java aus null keinen Typ ableiten.", line: declarator.line) }
                        if case .void = raw { throw .syntax("Die Methode gibt nichts zurück (void) – das kann man nicht speichern.", line: declarator.line) }
                        declared = raw.type
                    }
                    value = try coerce(raw, to: declared, line: declarator.line, what: "Die Variable „\(declarator.name)“")
                } else if global {
                    value = .defaultValue(for: declared)
                }
                try declare(declarator.name, type: declared, value: value, isFinal: isFinal, line: declarator.line, global: global)
            }
            return .normal

        case .expr(let expr, _):
            _ = try evaluate(expr)
            return .normal

        case .block(let statements, _):
            return try executeBlock(statements)

        case .ifStmt(let condition, let then, let otherwise, let line):
            if try test(condition, keyword: "if", line: line) {
                return try executeBody(then)
            } else if let otherwise {
                return try executeBody(otherwise)
            }
            return .normal

        case .whileStmt(let condition, let body, let line):
            while try self.test(condition, keyword: "while", line: line) {
                let flow = try executeBody(body)
                switch flow {
                case .breakLoop: return .normal
                case .returned, .yielded: return flow
                case .normal, .continueLoop: break
                }
                try tick(line)
            }
            return .normal

        case .doWhile(let body, let condition, let line):
            repeat {
                let flow = try executeBody(body)
                switch flow {
                case .breakLoop: return .normal
                case .returned, .yielded: return flow
                case .normal, .continueLoop: break
                }
                try tick(line)
            } while try self.test(condition, keyword: "while", line: line)
            return .normal

        case .forStmt(let initializers, let condition, let updates, let body, let line):
            frame.scopes.append([:])
            defer { frame.scopes.removeLast() }
            for initializer in initializers { _ = try execute(initializer) }
            while try condition.map({ (c) throws(JavaProblem) in try self.test(c, keyword: "for", line: line) }) ?? true {
                let flow = try executeBody(body)
                switch flow {
                case .breakLoop: return .normal
                case .returned, .yielded: return flow
                case .normal, .continueLoop: break
                }
                for update in updates { _ = try evaluate(update) }
                try tick(line)
            }
            return .normal

        case .forEach(let type, let name, let collection, let body, let line):
            let source = try evaluate(collection)
            let items: [JavaValue]
            var itemType: JavaType = .inferred
            switch source {
            case .array(let array):
                items = array.elements
                itemType = array.elementType
            case .object(let object) where [.list, .set, .deque].contains(object.kind):
                // Sammlungen: in derselben Reihenfolge wie in Java (HashSet nach Hash-Fächern).
                items = try iterationOrder(object)
            case .object(let object) where object.kind == .map:
                throw .syntax("Über eine Map kann for-each nicht direkt laufen – nimm map.keySet(), map.values() oder map.entrySet().", line: line)
            case .string:
                throw .syntax("Über einen String kann for-each nicht direkt laufen – nimm text.toCharArray().", line: line)
            case .null:
                throw .exception("NullPointerException", javaMessage: nil, explanation: "Das Array bzw. die Liste ist null.", line: line)
            default:
                throw .syntax("for-each braucht ein Array oder eine Sammlung, bekommt aber \(source.typeName).", line: line)
            }
            var index = 0
            while index < items.count {
                let element = items[index]
                frame.scopes.append([:])
                let declared = type == .inferred ? itemType : type
                let value = try coerce(element, to: declared, line: line, what: "Die Schleifenvariable „\(name)“")
                try declare(name, type: declared, value: value, isFinal: false, line: line)
                let flow: Flow
                do {
                    flow = try executeBody(body)
                } catch {
                    frame.scopes.removeLast()
                    throw error
                }
                frame.scopes.removeLast()
                switch flow {
                case .breakLoop: return .normal
                case .returned, .yielded: return flow
                case .normal, .continueLoop: break
                }
                index += 1
                try tick(line)
            }
            return .normal

        case .breakStmt:
            return .breakLoop
        case .continueStmt:
            return .continueLoop

        case .returnStmt(let expr, let line):
            guard let method = frame.method else {
                // return im main-Block beendet das Programm.
                if expr != nil { throw .syntax("main gibt nichts zurück – return steht hier ohne Wert.", line: line) }
                return .returned(.void)
            }
            guard let expr else {
                if method.returnType != .void {
                    throw .syntax("Die Methode \(method.name) muss einen Wert vom Typ \(method.returnType) zurückgeben: return …;", line: line)
                }
                return .returned(.void)
            }
            if method.returnType == .void {
                throw .syntax("\(method.name) ist void und gibt nichts zurück – hinter return darf hier kein Wert stehen.", line: line)
            }
            let value = try evaluate(expr, expected: method.returnType)
            return .returned(try coerce(value, to: method.returnType, line: line, what: "Der Rückgabewert von \(method.name)"))

        case .yieldStmt(let expr, _):
            return .yielded(try evaluate(expr))

        case .switchStmt(let subject, let cases, let line):
            let value = try evaluate(subject)
            // Muster-Variablen (case Kreis k) gelten nur im switch.
            frame.scopes.append([:])
            defer { frame.scopes.removeLast() }
            guard let start = try matchingCase(value, cases, line: line) else { return .normal }
            if cases[start].isArrow {
                let flow = try executeBlock(cases[start].body)
                if case .breakLoop = flow { return .normal }
                return flow
            }
            for index in start..<cases.count {
                for statement in cases[index].body {
                    let flow = try execute(statement)
                    switch flow {
                    case .normal: continue
                    case .breakLoop: return .normal
                    default: return flow
                    }
                }
            }
            return .normal

        case .throwStmt(let expr, let line):
            throw try throwing(try evaluate(expr), line: line)

        case .tryStmt(let body, let catches, let finallyBody, let line):
            return try executeTry(body, catches, finallyBody, line: line)

        case .empty:
            return .normal
        }
    }

    func test(_ expr: JavaExpr, keyword: String, line: Int) throws(JavaProblem) -> Bool {
        let value = try evaluate(expr)
        guard case .boolean(let result) = value else {
            if case .assign(op: "=", _, _, _) = expr {
                throw .syntax("In der Bedingung steht = (Zuweisung). Zum Vergleichen braucht man ==.", line: expr.line)
            }
            throw .syntax("Die Bedingung von \(keyword) muss true oder false ergeben, nicht \(value.typeName).", line: expr.line)
        }
        return result
    }

    func matchingCase(_ value: JavaValue, _ cases: [JavaSwitchCase], line: Int) throws(JavaProblem) -> Int? {
        func isNullLabel(_ label: JavaExpr) -> Bool { if case .literal(.null, _) = label { true } else { false } }
        if case .null = value {
            // Nur mit „case null“ darf ein switch null bekommen.
            if let index = cases.firstIndex(where: { $0.labels.contains(where: isNullLabel) }) { return index }
            throw .exception("NullPointerException", javaMessage: nil, explanation: "switch über null – ohne „case null“ geht das nicht.", line: line)
        }
        var defaultIndex: Int?
        for (index, switchCase) in cases.enumerated() {
            if switchCase.isDefault { defaultIndex = index }
            for label in switchCase.labels {
                if isNullLabel(label) { continue }
                // Typ-Muster: case Kreis k -> … (die Variable k gilt im Zweig)
                if case .instanceOf(.name("$switch", _), let type, let binding, let patternLine) = label {
                    guard try isInstance(value, of: type, line: patternLine) else { continue }
                    if let binding { frame.scopes[frame.scopes.count - 1][binding] = Slot(type: type, value: value, isFinal: false) }
                    if let guardExpr = switchCase.guardExpr, !(try test(guardExpr, keyword: "when", line: patternLine)) { continue }
                    return index
                }
                if case .recordPattern(.name("$switch", _), let pattern, let patternLine) = label {
                    guard let bindings = try match(value, pattern, line: patternLine) else { continue }
                    for (name, slot) in bindings { frame.scopes[frame.scopes.count - 1][name] = slot }
                    if let guardExpr = switchCase.guardExpr, !(try test(guardExpr, keyword: "when", line: patternLine)) { continue }
                    return index
                }
                // Enum-Konstante ohne Klassennamen: case ROT ->
                if case .object(let object) = value, let constantName = object.fields["$name"]?.stringValue,
                   case .name(let name, _) = label, lookup(name) == nil {
                    if name == constantName { return index }
                    continue
                }
                let candidate = try evaluate(label)
                if try valuesEqual(value, candidate, line: label.line) { return index }
            }
        }
        return defaultIndex
    }

    func valuesEqual(_ lhs: JavaValue, _ rhs: JavaValue, line: Int) throws(JavaProblem) -> Bool {
        if let a = Numeric(lhs), let b = Numeric(rhs) { return Numeric.compare(a, b) == .orderedSame }
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a.text == b.text
        case (.boolean(let a), .boolean(let b)): return a == b
        case (.object(let a), .object(let b)): return a === b
        default:
            throw .syntax("Der case-Wert (\(rhs.typeName)) passt nicht zum Typ im switch (\(lhs.typeName)).", line: line)
        }
    }

    // MARK: Ausdrücke

    func evaluate(_ expr: JavaExpr, expected: JavaType? = nil) throws(JavaProblem) -> JavaValue {
        switch expr {
        case .literal(let value, _):
            return value

        case .name(let name, let line):
            return try read(name, line: line)

        case .unary(let op, let operand, let line):
            let value = try evaluate(operand)
            return try unary(op, value, line: line)

        case .increment(let op, let prefix, let target, let line):
            let old = try evaluate(target)
            guard let number = Numeric(old) else {
                throw .syntax("\(op) funktioniert nur mit Zahlen, nicht mit \(old.typeName).", line: line)
            }
            let changed = Numeric.apply(op == "++" ? "+" : "-", number, .int(1))
            let new = try cast(changed.value, to: old.type, line: line)
            try store(new, into: target, line: line)
            return prefix ? new : old

        case .binary(let op, let lhs, let rhs, let line):
            let left = try evaluate(lhs)
            let right = try evaluate(rhs)
            if op == "==" || op == "!=", let same = try boxedIdentity(lhs, rhs, left, right, line: line) {
                return .boolean(op == "==" ? same : !same)
            }
            return try binary(op, left, right, line: line)

        case .logical(let op, let lhs, let rhs, let line):
            let left = try evaluate(lhs)
            guard case .boolean(let a) = left else {
                throw .syntax("\(op) verknüpft nur true/false-Werte, links steht aber \(left.typeName).", line: line)
            }
            if op == "&&" && !a { return .boolean(false) }
            if op == "||" && a { return .boolean(true) }
            let right = try evaluate(rhs)
            guard case .boolean(let b) = right else {
                throw .syntax("\(op) verknüpft nur true/false-Werte, rechts steht aber \(right.typeName).", line: line)
            }
            return .boolean(b)

        case .assign(let op, let target, let valueExpr, let line):
            if op == "=" {
                let targetType = try storageType(of: target, line: line)
                let value = try evaluate(valueExpr, expected: targetType)
                if case .void = value { throw .syntax("Die Methode gibt nichts zurück (void) – das kann man nicht speichern.", line: line) }
                return try store(value, into: target, line: line)
            }
            let old = try evaluate(target)
            let operand = try evaluate(valueExpr)
            let combined = try binary(String(op.dropLast()), old, operand, line: line)
            // Zusammengesetzte Zuweisungen enthalten in Java einen versteckten Cast: int x += 1.5 ist erlaubt.
            let result = try cast(combined, to: old.type, line: line)
            try store(result, into: target, line: line)
            return result

        case .conditional(let condition, let then, let otherwise, let line):
            let test = try evaluate(condition)
            guard case .boolean(let flag) = test else {
                throw .syntax("Vor dem ? muss eine Bedingung stehen (true/false).", line: line)
            }
            return try evaluate(flag ? then : otherwise, expected: expected)

        case .cast(let type, let operand, let line):
            return try cast(try evaluate(operand), to: type, line: line)

        case .index(let base, let indexExpr, let line):
            let container = try evaluate(base)
            let index = try evaluate(indexExpr)
            let (array, position) = try arrayAccess(container, index, line: line)
            return array.elements[position]

        case .field(let base, let name, let line):
            return try field(base, name, line: line)

        case .call(let target, let name, let args, let line):
            return try call(target, name, args, line: line)

        case .newArray(let element, let sizes, let extra, let line):
            let counts = try sizes.map { (size) throws(JavaProblem) -> Int in
                let value = try evaluate(size)
                guard let number = Numeric(value), case .int(let count) = number.promotedToInt else {
                    throw .syntax("Die Größe eines Arrays muss eine ganze Zahl (int) sein.", line: line)
                }
                if count < 0 { throw .exception("NegativeArraySizeException", javaMessage: "\(count)", explanation: "Ein Array kann nicht \(count) Plätze haben.", line: line) }
                return Int(count)
            }
            var leaf = element
            for _ in 0..<extra { leaf = .array(leaf) }
            return makeArray(counts[...], leaf: leaf)

        case .arrayLiteral(let element, let items, let line):
            var elementType = element
            if elementType == nil, case .array(let inner)? = expected { elementType = inner }
            guard let elementType else {
                throw .syntax("Bei einer Werteliste { … } muss klar sein, welcher Array-Typ entsteht.", line: line)
            }
            let values = try items.map { (item) throws(JavaProblem) -> JavaValue in
                let raw = try evaluate(item, expected: elementType)
                return try coerce(raw, to: elementType, line: item.line, what: "Ein Element des Arrays")
            }
            return .array(JavaArray(elementType: elementType, elements: values))

        case .switchExpr(let subject, let cases, let line):
            let value = try evaluate(subject)
            frame.scopes.append([:])
            defer { frame.scopes.removeLast() }
            guard let start = try matchingCase(value, cases, line: line) else {
                throw .syntax("Der switch-Ausdruck braucht einen default-Zweig, damit immer ein Wert herauskommt.", line: line)
            }
            for index in start..<cases.count {
                let switchCase = cases[index]
                if let valueExpr = switchCase.value { return try evaluate(valueExpr, expected: expected) }
                for statement in switchCase.body {
                    let flow = try execute(statement)
                    switch flow {
                    case .normal: continue
                    case .yielded(let result): return result
                    case .breakLoop: throw .syntax("In einem switch-Ausdruck verlässt man einen Zweig mit yield, nicht mit break.", line: statement.line)
                    default: throw .syntax("Ein Zweig des switch-Ausdrucks muss mit yield einen Wert liefern.", line: switchCase.line)
                    }
                }
                if switchCase.isArrow {
                    throw .syntax("Ein Zweig des switch-Ausdrucks muss mit yield einen Wert liefern.", line: switchCase.line)
                }
            }
            throw .syntax("Der switch-Ausdruck liefert keinen Wert (yield fehlt).", line: line)

        case .this(let line):
            guard let object = frame.thisObject else {
                throw .syntax("this gibt es nur in Methoden eines Objekts – in einer static-Methode wie main gibt es kein this.", line: line)
            }
            return .object(object)

        case .superRef(let line):
            throw .syntax("super allein ist kein Wert – nach super folgt eine Methode, z. B. super.laut().", line: line)

        case .newObject(let className, let argExprs, let line):
            guard className == "String" else {
                return try instantiate(className, try evaluateArgs(argExprs), line: line)
            }
            let args = try evaluateArgs(argExprs)
            switch args.count {
            case 0: return .str("")
            case 1:
                if case .array(let array) = args[0], array.elementType == .char {
                    return .str(array.elements.map(\.javaString).joined())
                }
                guard let text = args[0].stringValue else {
                    throw .syntax("new String(…) erwartet einen Text.", line: line)
                }
                // Absichtlich ein neues Objekt – genau deshalb ist new String("a") == "a" in Java false.
                return .str(text)
            default:
                throw .unsupported("new String mit mehreren Werten kennt der eingebaute Interpreter nicht.", line: line)
            }

        case .recordPattern(let value, let pattern, let line):
            let evaluated = try evaluate(value)
            guard let bindings = try match(evaluated, pattern, line: line) else { return .boolean(false) }
            for (name, slot) in bindings { frame.scopes[frame.scopes.count - 1][name] = slot }
            return .boolean(true)
        case .instanceOf(let value, let type, let binding, let line):
            let evaluated = try evaluate(value)
            let matches = try isInstance(evaluated, of: type, line: line)
            if matches, let binding {
                // Muster-Variable: x instanceof Hund h – h ist ab hier ein Hund.
                frame.scopes[frame.scopes.count - 1][binding] = Slot(type: type, value: evaluated, isFinal: false)
            }
            return .boolean(matches)
        }
    }

    private func makeArray(_ counts: ArraySlice<Int>, leaf: JavaType) -> JavaValue {
        guard let first = counts.first else { return .defaultValue(for: leaf) }
        var elementType = leaf
        for _ in 0..<(counts.count - 1) { elementType = .array(elementType) }
        let rest = counts.dropFirst()
        let elements = (0..<first).map { _ in rest.isEmpty ? JavaValue.defaultValue(for: leaf) : makeArray(rest, leaf: leaf) }
        return .array(JavaArray(elementType: elementType, elements: elements))
    }

    func storageType(of target: JavaExpr, line: Int) throws(JavaProblem) -> JavaType? {
        switch target {
        case .name(let name, _):
            guard let slot = lookup(name) else { throw unknownName(name, line: line) }
            return slot.type
        case .index(let base, _, _):
            if case .array(let array) = try evaluate(base) { return array.elementType }
            return nil
        case .field(let base, let name, _):
            return try fieldType(base, name, line: line)
        default:
            return nil
        }
    }

    /// Speichert den Wert und liefert ihn so zurück, wie er abgelegt wurde (z. B. int → double).
    @discardableResult
    func store(_ value: JavaValue, into target: JavaExpr, line: Int) throws(JavaProblem) -> JavaValue {
        switch target {
        case .name(let name, _):
            return try write(name, value, line: line)
        case .index(let base, let indexExpr, _):
            let container = try evaluate(base)
            let index = try evaluate(indexExpr)
            let (array, position) = try arrayAccess(container, index, line: line)
            let stored = try coerce(value, to: array.elementType, line: line, what: "Ein Platz im Array")
            array.elements[position] = stored
            return stored
        case .field(let base, let name, _):
            if let stored = try storeField(base, name, value, line: line) { return stored }
            if name == "length" {
                throw .syntax("length eines Arrays kann man nicht ändern – die Größe steht beim Erzeugen fest.", line: line)
            }
            throw .syntax("„\(name)“ kann man nicht verändern.", line: line)
        default:
            throw .syntax("Links vom = muss eine Variable stehen.", line: line)
        }
    }

    func arrayAccess(_ container: JavaValue, _ index: JavaValue, line: Int) throws(JavaProblem) -> (JavaArray, Int) {
        guard case .array(let array) = container else {
            if case .string = container {
                throw .syntax("Bei Strings holt man ein Zeichen mit charAt(i), nicht mit [i].", line: line)
            }
            if case .null = container { throw .runtime("NullPointerException: Das Array ist null.", line: line) }
            throw .syntax("[ ] gibt es nur bei Arrays, nicht bei \(container.typeName).", line: line)
        }
        guard let number = Numeric(index), case .int(let position) = number.promotedToInt, !(number.isLong || number.isDouble) else {
            throw .syntax("Der Index in [ ] muss eine ganze Zahl (int) sein.", line: line)
        }
        guard position >= 0, Int(position) < array.elements.count else {
            let range = array.elements.isEmpty ? "das Array ist leer" : "erlaubt sind nur 0 bis \(array.elements.count - 1)"
            throw .exception("ArrayIndexOutOfBoundsException", javaMessage: "Index \(position) out of bounds for length \(array.elements.count)",
                             explanation: "Index \(position) gibt es nicht – \(range). Denk dran: Gezählt wird ab 0.", line: line)
        }
        return (array, Int(position))
    }

    // MARK: Operatoren

    private func unary(_ op: String, _ value: JavaValue, line: Int) throws(JavaProblem) -> JavaValue {
        switch op {
        case "!":
            guard case .boolean(let flag) = value else { throw .syntax("! (nicht) funktioniert nur mit true/false.", line: line) }
            return .boolean(!flag)
        case "-", "+":
            guard let number = Numeric(value) else { throw .syntax("\(op) funktioniert nur mit Zahlen.", line: line) }
            if op == "+" { return number.promotedToInt.value }
            switch number.promotedToInt {
            case .int(let v): return .int(0 &- v)
            case .long(let v): return .long(0 &- v)
            case .double(let v): return .double(-v)
            }
        case "~":
            guard let number = Numeric(value) else { throw .syntax("~ funktioniert nur mit ganzen Zahlen.", line: line) }
            switch number.promotedToInt {
            case .int(let v): return .int(~v)
            case .long(let v): return .long(~v)
            case .double: throw .syntax("~ funktioniert nur mit ganzen Zahlen.", line: line)
            }
        default:
            throw .syntax("Unbekannter Operator \(op).", line: line)
        }
    }

    /// `Integer a = 1000, b = 1000; a == b` ist in Java false: == vergleicht hier Objekte.
    /// Java hält nur kleine Zahlen (-128 bis 127) als gemeinsame Objekte vorrätig.
    private func boxedIdentity(_ lhs: JavaExpr, _ rhs: JavaExpr, _ left: JavaValue, _ right: JavaValue, line: Int) throws(JavaProblem) -> Bool? {
        let boxes: Set<String> = ["Integer", "Long", "Short", "Byte", "Character", "Double", "Boolean"]
        guard case .object(let leftType)? = try declaredType(of: lhs), case .object(let rightType)? = try declaredType(of: rhs),
              boxes.contains(leftType), boxes.contains(rightType) else { return nil }
        if case .null = left { return nil }
        if case .null = right { return nil }
        warn("\(leftType)-Werte vergleicht man mit equals(), nicht mit ==. == prüft, ob es dasselbe Objekt ist – das klappt nur bei kleinen Zahlen (-128 bis 127) zufällig.", line: line)
        guard try valuesEqual(left, right, line: line) else { return false }
        if case .name(let a, _) = lhs, case .name(let b, _) = rhs, a == b { return true }
        switch left {
        case .boolean: return true
        case .double: return false
        case .char(let c): return c <= 127
        default:
            guard let number = Numeric(left), !number.isDouble else { return false }
            return (-128...127).contains(number.toDouble)
        }
    }

    func binary(_ op: String, _ lhs: JavaValue, _ rhs: JavaValue, line: Int) throws(JavaProblem) -> JavaValue {
        if case .void = lhs { throw .syntax("Links von \(op) steht ein Methodenaufruf, der nichts zurückgibt (void).", line: line) }
        if case .void = rhs { throw .syntax("Rechts von \(op) steht ein Methodenaufruf, der nichts zurückgibt (void).", line: line) }

        if op == "+" {
            switch (lhs, rhs) {
            case (.string, _), (_, .string):
                // Objekte werden mit ihrem toString() angehängt – wie in Java.
                return .str(try stringify(lhs, line: line) + stringify(rhs, line: line))
            default: break
            }
        }

        switch op {
        case "==", "!=":
            let equal: Bool
            if let a = Numeric(lhs), let b = Numeric(rhs) {
                equal = Numeric.compare(a, b) == .orderedSame
            } else {
                switch (lhs, rhs) {
                case (.boolean(let a), .boolean(let b)): equal = a == b
                case (.string(let a), .string(let b)):
                    // Wie in Java: == prüft, ob beide auf dasselbe String-Objekt zeigen.
                    equal = a === b
                    do {
                        warn("Strings vergleicht man mit equals(), nicht mit \(op). == prüft nur, ob beide Variablen auf dasselbe Objekt zeigen – nicht, ob der Text gleich ist.", line: line)
                    }
                case (.null, .null): equal = true
                case (.null, .string), (.string, .null), (.null, .array), (.array, .null), (.null, .object), (.object, .null): equal = false
                case (.array(let a), .array(let b)): equal = a === b
                // Objekte: == prüft, ob es dasselbe Objekt ist (gleicher Inhalt reicht nicht – dafür gibt es equals).
                case (.object(let a), .object(let b)): equal = a === b
                case (.null, _), (_, .null):
                    throw .exception("NullPointerException", javaMessage: nil,
                                     explanation: "Ein Wert ist null – null lässt sich nicht als \((lhs.isNull ? rhs : lhs).typeName) vergleichen (z. B. weil get(…) nichts gefunden hat).", line: line)
                default:
                    throw .syntax("\(lhs.typeName) und \(rhs.typeName) kann man nicht mit \(op) vergleichen.", line: line)
                }
            }
            return .boolean(op == "==" ? equal : !equal)
        case "&", "|", "^":
            if case .boolean(let a) = lhs, case .boolean(let b) = rhs {
                switch op {
                case "&": return .boolean(a && b)
                case "|": return .boolean(a || b)
                default: return .boolean(a != b)
                }
            }
        default:
            break
        }

        guard let a = Numeric(lhs), let b = Numeric(rhs) else {
            let offender = Numeric(lhs) == nil ? lhs : rhs
            if offender.isNull {
                throw .exception("NullPointerException", javaMessage: nil,
                                 explanation: "Mit null kann man nicht rechnen – der Wert fehlt (z. B. weil get(…) den Schlüssel nicht gefunden hat).", line: line)
            }
            if case .boolean = offender {
                throw .syntax("Mit \(op) kann man nicht mit true/false rechnen.", line: line)
            }
            if case .string = offender {
                throw .syntax("Mit \(op) kann man nicht mit Text (String) rechnen. Nur + hängt Texte aneinander.", line: line)
            }
            if case .null = offender {
                throw .runtime("NullPointerException: Mit null kann man nicht rechnen.", line: line)
            }
            throw .syntax("\(op) passt nicht zu \(lhs.typeName) und \(rhs.typeName).", line: line)
        }

        switch op {
        case "<", ">", "<=", ">=":
            if a.isNaN || b.isNaN { return .boolean(false) }
            let order = Numeric.compare(a, b)
            switch op {
            case "<": return .boolean(order == .orderedAscending)
            case ">": return .boolean(order == .orderedDescending)
            case "<=": return .boolean(order != .orderedDescending)
            default: return .boolean(order != .orderedAscending)
            }
        case "/", "%":
            let (x, y) = Numeric.promote(a, b)
            if y.isZeroIntegral {
                throw .exception("ArithmeticException", javaMessage: "/ by zero", explanation: "/ by zero – durch 0 teilen geht bei ganzen Zahlen nicht.", line: line)
            }
            return Numeric.apply(op, x, y).value
        case "+", "-", "*":
            return Numeric.apply(op, a, b).value
        case "&", "|", "^", "<<", ">>", ">>>":
            guard !a.isDouble, !b.isDouble else {
                throw .syntax("\(op) funktioniert nur mit ganzen Zahlen.", line: line)
            }
            return Numeric.bitwise(op, a, b).value
        default:
            throw .syntax("Unbekannter Operator \(op).", line: line)
        }
    }

    // MARK: Typen

    /// Implizite Umwandlung wie bei Zuweisung und Methodenaufruf: nur verlustfreie Verbreiterung.
    func coerce(_ value: JavaValue, to type: JavaType, line: Int, what: String) throws(JavaProblem) -> JavaValue {
        func mismatch() -> JavaProblem {
            var message = "Typen passen nicht: \(what) erwartet \(type), bekommt aber \(value.typeName)."
            switch (value, type) {
            case (.double, .int), (.double, .long), (.long, .int):
                message += " Das ginge nur mit Verlust. Wenn du die Nachkommastellen bewusst abschneiden willst: (\(type)) davor schreiben."
            case (.string, .int), (.string, .double), (.string, .long):
                message += " Ein Text ist keine Zahl – umwandeln geht mit Integer.parseInt(text) bzw. Double.parseDouble(text)."
            case (.int, .string), (.double, .string), (.long, .string), (.boolean, .string), (.char, .string):
                message += " Eine Zahl ist kein Text – umwandeln geht mit String.valueOf(wert) oder \"\" + wert."
            case (.string, .char):
                message += " Ein einzelnes Zeichen (char) steht in einfachen Anführungszeichen: 'a'."
            case (.void, _):
                message = "Die Methode gibt nichts zurück (void) – \(what) bekommt deshalb keinen Wert."
            default: break
            }
            return .syntax(message, line: line)
        }

        if value.isNull, [.int, .long, .double, .boolean, .char].contains(type) {
            throw .exception("NullPointerException", javaMessage: nil,
                             explanation: "\(what) erwartet \(type), bekommt aber null – zum Beispiel, weil get(…) den Schlüssel nicht gefunden hat. null passt in keine Zahlen-Variable.", line: line)
        }
        switch type {
        case .inferred:
            return value
        case .int:
            switch value {
            case .int: return value
            case .char(let c): return .int(Int32(c))
            default: throw mismatch()
            }
        case .long:
            switch value {
            case .long: return value
            case .int(let v): return .long(Int64(v))
            case .char(let c): return .long(Int64(c))
            default: throw mismatch()
            }
        case .double:
            switch value {
            case .double: return value
            case .int(let v): return .double(Double(v))
            case .long(let v): return .double(Double(v))
            case .char(let c): return .double(Double(c))
            default: throw mismatch()
            }
        case .boolean:
            if case .boolean = value { return value }
            throw mismatch()
        case .char:
            switch value {
            case .char: return value
            // Ganzzahl-Konstanten im char-Bereich darf man direkt zuweisen (char c = 65;).
            case .int(let v) where (0...65_535).contains(v): return .char(UInt16(v))
            default: throw mismatch()
            }
        case .string:
            switch value {
            case .string, .null: return value
            default: throw mismatch()
            }
        case .array(let element):
            switch value {
            case .null: return value
            case .array(let array) where array.elementType == element: return value
            default: throw mismatch()
            }
        case .void:
            throw .syntax("Eine Variable kann nicht den Typ void haben.", line: line)
        case .unknown(let name):
            throw .unsupported("Den Typ \(name) kennt der eingebaute Interpreter nicht.", line: line)
        case .object(let name):
            if try canAssign(value, to: name) { return value }
            throw mismatch()
        }
    }

    /// Expliziter Cast `(int) x` – mit Javas Regeln für Abschneiden und Überlauf.
    func cast(_ value: JavaValue, to type: JavaType, line: Int) throws(JavaProblem) -> JavaValue {
        if case .object(let name) = type {
            return try castObject(value, to: name, line: line)
        }
        if case .string = type {
            switch value {
            case .string, .null: return value
            default: throw .syntax("\(value.typeName) kann man nicht in String casten – nimm String.valueOf(wert).", line: line)
            }
        }
        if case .boolean = type {
            if case .boolean = value { return value }
            throw .syntax("Zahlen lassen sich nicht in boolean umwandeln.", line: line)
        }
        guard let number = Numeric(value) else {
            if case .boolean = value { throw .syntax("true/false lässt sich nicht in eine Zahl umwandeln.", line: line) }
            return try coerce(value, to: type, line: line, what: "Der Cast")
        }
        switch type {
        case .int: return .int(number.toInt32)
        case .long: return .long(number.toInt64)
        case .double: return .double(number.toDouble)
        case .char: return .char(UInt16(truncatingIfNeeded: number.toInt32))
        default: return try coerce(value, to: type, line: line, what: "Der Cast")
        }
    }

    // MARK: Felder

    func field(_ base: JavaExpr, _ name: String, line: Int) throws(JavaProblem) -> JavaValue {
        if let value = try objectField(base, name, line: line) { return value }
        if case .name(let className, _) = base, lookup(className) == nil {
            if className == "java" || className == "javax" {
                throw .unsupported("Voll qualifizierte Klassen (\(className).\(name)…) kennt der eingebaute Interpreter nicht.", line: line)
            }
            switch (className, name) {
            case ("Math", "PI"): return .double(Double.pi)
            case ("Math", "E"): return .double(M_E)
            case ("Integer", "MAX_VALUE"): return .int(Int32.max)
            case ("Integer", "MIN_VALUE"): return .int(Int32.min)
            case ("Long", "MAX_VALUE"): return .long(Int64.max)
            case ("Long", "MIN_VALUE"): return .long(Int64.min)
            case ("Double", "MAX_VALUE"): return .double(Double.greatestFiniteMagnitude)
            case ("Double", "MIN_VALUE"): return .double(Double.leastNonzeroMagnitude)
            case ("Double", "POSITIVE_INFINITY"): return .double(.infinity)
            case ("Double", "NEGATIVE_INFINITY"): return .double(-.infinity)
            case ("Double", "NaN"): return .double(.nan)
            case ("System", "out"):
                throw .syntax("System.out allein macht nichts – zum Ausgeben: System.out.println(…);", line: line)
            default:
                if host?.objectNames.contains(className) == true {
                    throw .syntax("\(className).\(name) braucht runde Klammern: \(className).\(name)();", line: line)
                }
                if className.first?.isUppercase == true {
                    throw .unsupported("\(className).\(name) kennt der eingebaute Interpreter nicht.", line: line)
                }
                throw unknownName(className, line: line)
            }
        }
        let value = try evaluate(base)
        switch (value, name) {
        case (.array(let array), "length"):
            return .int(Int32(array.elements.count))
        case (.string, "length"):
            throw .syntax("Bei Strings ist length eine Methode und braucht Klammern: length().", line: line)
        case (.null, _):
            throw .exception("NullPointerException", javaMessage: nil, explanation: "Der Wert ist null – darauf gibt es kein „\(name)“.", line: line)
        case (.object(let object), _):
            return try readField(object, name, line: line)
        default:
            throw .syntax("\(value.typeName) hat kein Feld „\(name)“.", line: line)
        }
    }

    // MARK: Methodenaufrufe

    func call(_ target: JavaExpr?, _ name: String, _ argExprs: [JavaExpr], line: Int) throws(JavaProblem) -> JavaValue {
        guard let target else {
            if name == "this" || name == "super" {
                throw .syntax("\(name)(…) darf nur als erste Zeile in einem Konstruktor stehen.", line: line)
            }
            return try callUserMethod(name, argExprs, line: line)
        }
        if let result = try callOnClassOrObject(target, name, argExprs, line: line) { return result }
        // System.out.println(…)
        if case .field(.name("System", _), let stream, _) = target, lookup("System") == nil {
            guard stream == "out" || stream == "err" else {
                throw .unsupported("System.\(stream) kennt der eingebaute Interpreter nicht.", line: line)
            }
            let args = try evaluateArgs(argExprs)
            return try printCall(name, args, line: line)
        }
        if case .name(let objectName, _) = target, lookup(objectName) == nil {
            let args = try evaluateArgs(argExprs)
            if let host, host.objectNames.contains(objectName) {
                for (index, arg) in args.enumerated() {
                    if case .void = arg { throw .syntax("Argument \(index + 1) gibt keinen Wert zurück (void).", line: line) }
                }
                let context = host.wantsSnapshot
                    ? JavaCallContext(line: line, variables: visibleVariables(), output: output)
                    : JavaCallContext(line: line, variables: [], output: "")
                return try host.call(object: objectName, method: name, args: args, context: context)
            }
            return try JavaLibrary.callStatic(objectName, name, args, line: line, interpreter: self)
        }
        let receiver = try evaluate(target)
        let args = try evaluateArgs(argExprs)
        if case .object(let object) = receiver {
            // list.remove(Integer.valueOf(7)) entfernt den Wert 7, list.remove(7) die Stelle 7.
            if name == "remove", object.kind == .list, argExprs.count == 1, try isBoxed(argExprs[0]) {
                return try JavaLibrary.callObject(object, "$removeValue", args, line: line, interpreter: self)
            }
            return try callMethod(on: object, name, args, line: line, staticType: try declaredType(of: target))
        }
        // Zahlen aus Sammlungen oder Integer-Variablen sind in Java Objekte: liste.get(0).equals(…)
        if try !isPlainPrimitive(target), let result = try JavaLibrary.boxedMethod(receiver, name, args, line: line, interpreter: self) {
            return result
        }
        return try JavaLibrary.callInstance(receiver, name, args, line: line, interpreter: self)
    }

    /// Ist der Ausdruck sicher ein einfacher Wert (int, double …)? Daran gibt es in Java keine Methoden.
    private func isPlainPrimitive(_ expr: JavaExpr) throws(JavaProblem) -> Bool {
        switch expr {
        case .literal, .binary, .unary, .increment: return true
        case .cast(let type, _, _): return type.className == nil
        case .field(_, "length", _): return true
        case .name(let name, _):
            guard let type = lookup(name)?.type else { return false }
            return [.int, .long, .double, .char, .boolean].contains(type)
        default: return false
        }
    }

    /// Steht hier eine Zahl als Objekt (Integer statt int)?
    private func isBoxed(_ expr: JavaExpr) throws(JavaProblem) -> Bool {
        let boxes: Set<String> = ["Integer", "Long", "Double", "Character", "Boolean", "Object", "Number"]
        switch expr {
        case .call(.name(let className, _)?, "valueOf", _, _): return boxes.contains(className)
        case .cast(.object(let name), _, _), .newObject(let name, _, _): return boxes.contains(name)
        default:
            if case .object(let name)? = try declaredType(of: expr) { return boxes.contains(name) }
            return false
        }
    }

    func evaluateArgs(_ exprs: [JavaExpr]) throws(JavaProblem) -> [JavaValue] {
        try exprs.map { (expr) throws(JavaProblem) in try evaluate(expr) }
    }

    func printCall(_ name: String, _ args: [JavaValue], line: Int) throws(JavaProblem) -> JavaValue {
        switch name {
        case "println":
            guard args.count <= 1 else { throw .syntax("println nimmt höchstens einen Wert – verbinde mehrere mit +.", line: line) }
            if let arg = args.first { try emit(printable(arg, line: line), line: line) }
            try emit("\n", line: line)
        case "print":
            guard args.count == 1 else { throw .syntax("print braucht genau einen Wert in den Klammern.", line: line) }
            try emit(printable(args[0], line: line), line: line)
        case "printf", "format":
            guard let pattern = args.first?.stringValue else {
                throw .syntax("printf braucht als Erstes einen Format-Text, z. B. printf(\"%d%n\", zahl).", line: line)
            }
            try emit(try JavaFormat.format(pattern, try formatArgs(Array(args.dropFirst()), line: line), line: line), line: line)
        default:
            throw .syntax("System.out.\(name) gibt es nicht. Meintest du println oder print?", line: line)
        }
        return .void
    }

    /// Objekte für `%s` vorab in Text verwandeln – mit ihrer eigenen toString-Methode.
    func formatArgs(_ args: [JavaValue], line: Int) throws(JavaProblem) -> [JavaValue] {
        try args.map { (arg) throws(JavaProblem) -> JavaValue in
            if case .object = arg { return .str(try stringify(arg, line: line)) }
            return arg
        }
    }

    func printable(_ value: JavaValue, line: Int) throws(JavaProblem) -> String {
        switch value {
        case .void: throw .syntax("Diese Methode gibt nichts zurück (void) – es gibt nichts auszugeben.", line: line)
        case .array(let array) where array.elementType == .char:
            return array.elements.map(\.javaString).joined()
        default: return try stringify(value, line: line)
        }
    }

    func emit(_ text: String, line: Int) throws(JavaProblem) {
        output += text
        if output.count > Self.maxOutput {
            throw JavaProblem(.stepLimit, "Dein Programm gibt sehr viel aus und wurde gestoppt – vermutlich eine Endlosschleife mit println.", line: line)
        }
    }

    func callUserMethod(_ name: String, _ argExprs: [JavaExpr], line: Int) throws(JavaProblem) -> JavaValue {
        // In einer Klasse: erst deren Methoden (Objektmethoden über this, dann statische), dann die des Hauptprogramms.
        if let result = try callInClassContext(name, argExprs, line: line) { return result }
        guard let candidates = program.methods[name] else {
            if name == "println" || name == "print" {
                throw .syntax("\(name) allein kennt Java nicht – es heißt System.out.\(name)(…).", line: line)
            }
            if let similar = program.methods.keys.first(where: { $0.lowercased() == name.lowercased() }) {
                throw .syntax("Die Methode \(name)(…) gibt es nicht. Meintest du \(similar)? Achte auf Groß- und Kleinschreibung.", line: line)
            }
            if host?.objectNames.isEmpty == false, let object = host?.objectNames.sorted().first {
                throw .syntax("Die Methode \(name)(…) gibt es nicht. Befehle für den Roboter schreibt man mit Punkt davor: \(object).\(name)();", line: line)
            }
            throw .syntax("Die Methode \(name)(…) gibt es nicht. Ist sie geschrieben und richtig benannt?", line: line)
        }
        let args = try evaluateArgs(argExprs)
        let matching = candidates.filter { $0.parameters.count == args.count }
        guard !matching.isEmpty else {
            let counts = candidates.map { "\($0.parameters.count)" }.joined(separator: " oder ")
            throw .syntax("\(name) erwartet \(counts) Wert(e) in den Klammern, bekommt aber \(args.count).", line: line)
        }
        return try invoke(try selectOverload(matching, args, name: name, line: line), args, line: line)
    }

    /// Wählt die passende Variante: erst exakte Typen, dann erlaubte Verbreiterung (int → double usw.).
    func selectOverload(_ matching: [JavaMethod], _ args: [JavaValue], name: String, line: Int) throws(JavaProblem) -> JavaMethod {
        let exact = matching.first { method in zip(method.parameters, args).allSatisfy { $0.type == $1.type || $0.type == .inferred } }
        let widening = matching.first { method in
            zip(method.parameters, args).allSatisfy { parameter, arg in
                (try? coerce(arg, to: parameter.type, line: line, what: "")) != nil
            }
        }
        guard let method = exact ?? widening else {
            // Keine passt: die Meldung der ersten Variante erklärt, welcher Parameter nicht passt.
            let method = matching[0]
            for (parameter, arg) in zip(method.parameters, args) {
                _ = try coerce(arg, to: parameter.type, line: line, what: "Der Parameter „\(parameter.name)“ von \(name)")
            }
            throw .syntax("Die Werte passen nicht zu den Parametern von \(name).", line: line)
        }
        return method
    }

    func invoke(_ method: JavaMethod, _ args: [JavaValue], line: Int, this: JavaObject? = nil) throws(JavaProblem) -> JavaValue {
        guard frames.count < Self.maxCallDepth else {
            throw .runtime("StackOverflowError: \(method.name) ruft sich immer wieder selbst auf und hört nie auf. Jede Rekursion braucht einen Abbruchfall.", line: line)
        }
        if method.isAbstract {
            throw .syntax("\(method.name) hat keinen Körper (abstract) – aufrufen kann man nur eine Klasse, die die Methode umsetzt.", line: line)
        }
        let newFrame = Frame(method: method, thisObject: method.isStatic ? nil : this, currentClass: method.owner)
        for (parameter, arg) in zip(method.parameters, args) {
            let value = try coerce(arg, to: parameter.type, line: line, what: "Der Parameter „\(parameter.name)“ von \(method.name)")
            newFrame.scopes[0][parameter.name] = Slot(type: parameter.type, value: value, isFinal: false)
        }
        frames.append(newFrame)
        defer { frames.removeLast() }
        for statement in method.body {
            let flow = try execute(statement)
            switch flow {
            case .normal: continue
            case .returned(let value): return value
            case .breakLoop: throw .syntax("break steht außerhalb einer Schleife.", line: statement.line)
            case .continueLoop: throw .syntax("continue steht außerhalb einer Schleife.", line: statement.line)
            case .yielded: throw .syntax("yield gibt es nur in switch-Ausdrücken.", line: statement.line)
            }
        }
        if method.returnType != .void {
            throw .syntax("Die Methode \(method.name) endet, ohne einen Wert zurückzugeben. Es fehlt ein return mit einem \(method.returnType)-Wert.", line: method.line)
        }
        return .void
    }

    func nextRandom() -> Double {
        // SplitMix64 – reproduzierbar, damit Programme bei jedem Lauf gleich ablaufen.
        randomState &+= 0x9E37_79B9_7F4A_7C15
        var z = randomState
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

// MARK: - Zahlen

/// Javas binäre numerische Typanpassung: char/int → int, dann long, dann double.
enum Numeric {
    case int(Int32)
    case long(Int64)
    case double(Double)

    init?(_ value: JavaValue) {
        switch value {
        case .int(let v): self = .int(v)
        case .char(let c): self = .int(Int32(c))
        case .long(let v): self = .long(v)
        case .double(let v): self = .double(v)
        default: return nil
        }
    }

    var value: JavaValue {
        switch self {
        case .int(let v): .int(v)
        case .long(let v): .long(v)
        case .double(let v): .double(v)
        }
    }

    var promotedToInt: Numeric { self }
    var isDouble: Bool { if case .double = self { true } else { false } }
    var isLong: Bool { if case .long = self { true } else { false } }
    var isNaN: Bool { if case .double(let v) = self { v.isNaN } else { false } }

    var isZeroIntegral: Bool {
        switch self {
        case .int(let v): v == 0
        case .long(let v): v == 0
        case .double: false
        }
    }

    var toDouble: Double {
        switch self {
        case .int(let v): Double(v)
        case .long(let v): Double(v)
        case .double(let v): v
        }
    }

    var toInt64: Int64 {
        switch self {
        case .int(let v): return Int64(v)
        case .long(let v): return v
        case .double(let v):
            if v.isNaN { return 0 }
            if v >= 9.223372036854775807e18 { return Int64.max }
            if v <= -9.223372036854775808e18 { return Int64.min }
            return Int64(v.rounded(.towardZero))
        }
    }

    var toInt32: Int32 {
        switch self {
        case .int(let v): return v
        case .long(let v): return Int32(truncatingIfNeeded: v)
        case .double(let v):
            if v.isNaN { return 0 }
            if v >= Double(Int32.max) { return Int32.max }
            if v <= Double(Int32.min) { return Int32.min }
            return Int32(v.rounded(.towardZero))
        }
    }

    static func promote(_ a: Numeric, _ b: Numeric) -> (Numeric, Numeric) {
        switch (a, b) {
        case (.double, _), (_, .double): (.double(a.toDouble), .double(b.toDouble))
        case (.long, _), (_, .long): (.long(a.toInt64), .long(b.toInt64))
        default: (a, b)
        }
    }

    static func compare(_ a: Numeric, _ b: Numeric) -> ComparisonResult {
        switch promote(a, b) {
        case (.int(let x), .int(let y)): x < y ? .orderedAscending : (x > y ? .orderedDescending : .orderedSame)
        case (.long(let x), .long(let y)): x < y ? .orderedAscending : (x > y ? .orderedDescending : .orderedSame)
        case let (x, y):
            x.toDouble < y.toDouble ? .orderedAscending : (x.toDouble > y.toDouble ? .orderedDescending : (x.toDouble == y.toDouble ? .orderedSame : .orderedAscending))
        }
    }

    static func apply(_ op: String, _ a: Numeric, _ b: Numeric) -> Numeric {
        switch promote(a, b) {
        case (.int(let x), .int(let y)):
            switch op {
            case "+": return .int(x &+ y)
            case "-": return .int(x &- y)
            case "*": return .int(x &* y)
            case "/": return .int(x.dividedReportingOverflow(by: y).partialValue)
            default: return .int(x.remainderReportingOverflow(dividingBy: y).partialValue)
            }
        case (.long(let x), .long(let y)):
            switch op {
            case "+": return .long(x &+ y)
            case "-": return .long(x &- y)
            case "*": return .long(x &* y)
            case "/": return .long(x.dividedReportingOverflow(by: y).partialValue)
            default: return .long(x.remainderReportingOverflow(dividingBy: y).partialValue)
            }
        case let (x, y):
            let p = x.toDouble, q = y.toDouble
            switch op {
            case "+": return .double(p + q)
            case "-": return .double(p - q)
            case "*": return .double(p * q)
            case "/": return .double(p / q)
            default: return .double(p.truncatingRemainder(dividingBy: q))
            }
        }
    }

    static func bitwise(_ op: String, _ a: Numeric, _ b: Numeric) -> Numeric {
        if op == "<<" || op == ">>" || op == ">>>" {
            // Bei Shifts bestimmt nur der linke Operand den Typ.
            switch a {
            case .int(let x):
                let n = Int32(truncatingIfNeeded: b.toInt64 & 31)
                switch op {
                case "<<": return .int(x << n)
                case ">>": return .int(x >> n)
                default: return .int(Int32(bitPattern: UInt32(bitPattern: x) >> UInt32(n)))
                }
            default:
                let x = a.toInt64
                let n = b.toInt64 & 63
                switch op {
                case "<<": return .long(x << n)
                case ">>": return .long(x >> n)
                default: return .long(Int64(bitPattern: UInt64(bitPattern: x) >> UInt64(n)))
                }
            }
        }
        switch promote(a, b) {
        case (.int(let x), .int(let y)):
            switch op {
            case "&": return .int(x & y)
            case "|": return .int(x | y)
            default: return .int(x ^ y)
            }
        case let (x, y):
            let p = x.toInt64, q = y.toInt64
            switch op {
            case "&": return .long(p & q)
            case "|": return .long(p | q)
            default: return .long(p ^ q)
            }
        }
    }
}
