import Foundation

/// Was der Roboter in einem Animationsschritt tut.
public enum ArenaAction: Sendable, Hashable {
    case start
    case move
    case turnLeft
    case turnRight
    case pickCoin
    /// Eine Frage an den Roboter (z. B. frontIsClear) und seine Antwort.
    case look(question: String, answer: String)
    /// Gegen eine Wand gefahren (`wall` ist das Wandfeld) oder ins Leere gegriffen (`wall` ist nil) –
    /// das Programm bricht ab.
    case crash(wall: GridPoint?)

    public var isCrash: Bool {
        if case .crash = self { return true }
        return false
    }
}

/// Ein Standbild der Welt für die Wiedergabe – nach jeder Roboter-Aktion.
public struct ArenaFrame: Sendable, Hashable {
    public let robot: GridPoint
    public let heading: Heading
    public let coins: Set<GridPoint>
    public let collected: Int
    public let action: ArenaAction
    /// Zeile im Code, die diese Aktion ausgelöst hat.
    public let line: Int?
    /// Konsolenausgabe bis zu diesem Moment.
    public let output: String
    public let variables: [JavaVariable]
}

/// Die Befehle des Roboters – mit Kurzbeschreibung für die Befehlsleiste der App.
public struct RobotCommand: Sendable, Hashable, Identifiable {
    public let name: String
    public let returnType: String
    public let summary: String
    /// Was der Befehl genau tut – für die Befehlsliste im Auftrag.
    public let detail: String
    public var id: String { name }
    public var call: String { "robot.\(name)()" }

    public static let all: [RobotCommand] = [
        RobotCommand(name: "move", returnType: "void", summary: "Ein Feld vorwärts fahren",
                     detail: "Fährt ein Feld in Blickrichtung. Steht dort eine Wand, gibt es einen Unfall."),
        RobotCommand(name: "turnLeft", returnType: "void", summary: "Um 90° nach links drehen",
                     detail: "Dreht Byte auf der Stelle um 90° nach links – er fährt dabei nicht."),
        RobotCommand(name: "turnRight", returnType: "void", summary: "Um 90° nach rechts drehen",
                     detail: "Dreht Byte auf der Stelle um 90° nach rechts – er fährt dabei nicht."),
        RobotCommand(name: "pickCoin", returnType: "void", summary: "Münze auf dem Feld aufheben",
                     detail: "Hebt die Münze auf, auf der Byte gerade steht. Liegt dort keine, gibt es einen Fehler."),
        RobotCommand(name: "frontIsClear", returnType: "boolean", summary: "Ist vorne frei?",
                     detail: "Antwortet true, wenn das Feld vor Byte frei ist – sonst false."),
        RobotCommand(name: "leftIsClear", returnType: "boolean", summary: "Ist links frei?",
                     detail: "Antwortet true, wenn das Feld links neben Byte frei ist – sonst false."),
        RobotCommand(name: "rightIsClear", returnType: "boolean", summary: "Ist rechts frei?",
                     detail: "Antwortet true, wenn das Feld rechts neben Byte frei ist – sonst false."),
        RobotCommand(name: "onCoin", returnType: "boolean", summary: "Liegt hier eine Münze?",
                     detail: "Antwortet true, wenn auf dem Feld von Byte eine Münze liegt – sonst false."),
        RobotCommand(name: "atGoal", returnType: "boolean", summary: "Steht er auf dem Ziel?",
                     detail: "Antwortet true, wenn Byte auf der Zielflagge steht – sonst false."),
        RobotCommand(name: "coins", returnType: "int", summary: "Wie viele Münzen hat er?",
                     detail: "Antwortet mit der Zahl der Münzen, die Byte schon aufgehoben hat (eine ganze Zahl)."),
    ]
}

/// Simuliert eine Welt und stellt dem Interpreter das Objekt `robot` bereit.
/// Wird nur von einem Thread nacheinander benutzt (vor, während und nach dem Lauf).
final class ArenaSimulation: JavaHost, @unchecked Sendable {
    static let maxActions = 400
    static let maxFrames = 1_500
    /// So oft darf der Roboter hintereinander gefragt werden, ohne sich zu bewegen.
    static let maxQuestionsInARow = 250
    /// So viele Fragen hintereinander zeigt die Wiedergabe als Sprechblase. Mehr braucht keine
    /// Mission zwischen zwei Aktionen – eine Schleife ohne robot.move(); hätte sonst 250 gleiche Bilder.
    static let shownQuestionsInARow = 6

    let world: ArenaWorldSpec
    /// Befehle, die Byte in dieser Mission kann – für die Liste bei einem unbekannten Befehl.
    let commandNames: [String]
    let objectNames: Set<String> = ["robot"]
    private(set) var robot: GridPoint
    private(set) var heading: Heading
    private(set) var coins: Set<GridPoint>
    private(set) var collected = 0
    private(set) var actions = 0
    private(set) var frames: [ArenaFrame] = []
    private var questionsInARow = 0

    var wantsSnapshot: Bool { frames.count < Self.maxFrames }

    init(world: ArenaWorldSpec, commandNames: [String] = RobotCommand.all.map(\.name)) {
        self.world = world
        self.commandNames = commandNames
        robot = world.start ?? GridPoint(x: 0, y: 0)
        heading = world.facing
        coins = world.coins
        record(.start, context: nil)
    }

    private func record(_ action: ArenaAction, context: JavaCallContext?) {
        guard frames.count < Self.maxFrames else { return }
        frames.append(ArenaFrame(
            robot: robot, heading: heading, coins: coins, collected: collected, action: action,
            line: context?.line, output: context?.output ?? "", variables: context?.variables ?? []
        ))
    }

    func call(object: String, method: String, args: [JavaValue], context: JavaCallContext) throws(JavaProblem) -> JavaValue {
        guard let command = RobotCommand.all.first(where: { $0.name == method }) else {
            let similar = RobotCommand.all.first { $0.name.lowercased() == method.lowercased() }
            let tip = similar.map { " Meintest du robot.\($0.name)()? Achte auf Groß- und Kleinschreibung." }
                ?? " Er kann hier: " + commandNames.map { "\($0)()" }.joined(separator: ", ") + "."
            throw .syntax("Der Roboter kennt den Befehl \(method)() nicht.\(tip)", line: context.line)
        }
        guard args.isEmpty else {
            throw .syntax("robot.\(method)() braucht nichts in den Klammern.", line: context.line)
        }
        if command.returnType == "void" {
            questionsInARow = 0
            actions += 1
            guard actions <= Self.maxActions else {
                throw JavaProblem(.stepLimit, "Der Roboter hat schon \(Self.maxActions) Aktionen gemacht und ist immer noch unterwegs – läuft er im Kreis?", line: context.line)
            }
        }

        switch method {
        case "move":
            let next = robot.moved(heading)
            guard !world.isWall(next) else {
                record(.crash(wall: next), context: context)
                throw .runtime("Bumm! Der Roboter ist gegen eine Wand gefahren. Prüfe vorher mit robot.frontIsClear(), ob der Weg frei ist.", line: context.line)
            }
            robot = next
            record(.move, context: context)
        case "turnLeft":
            heading = heading.left
            record(.turnLeft, context: context)
        case "turnRight":
            heading = heading.right
            record(.turnRight, context: context)
        case "pickCoin":
            guard coins.contains(robot) else {
                record(.crash(wall: nil), context: context)
                throw .runtime("Hier liegt keine Münze – der Roboter greift ins Leere. Prüfe vorher mit robot.onCoin().", line: context.line)
            }
            coins.remove(robot)
            collected += 1
            record(.pickCoin, context: context)
        case "coins":
            return .int(Int32(collected))
        default:
            questionsInARow += 1
            if questionsInARow > Self.maxQuestionsInARow {
                throw JavaProblem(.stepLimit, "Byte wird immer wieder gefragt, bewegt sich aber nicht – vermutlich eine Schleife ohne robot.move(); im Körper.", line: context.line)
            }
            let answer: Bool = switch method {
            case "frontIsClear": !world.isWall(robot.moved(heading))
            case "leftIsClear": !world.isWall(robot.moved(heading.left))
            case "rightIsClear": !world.isWall(robot.moved(heading.right))
            case "onCoin": coins.contains(robot)
            default: robot == world.goal
            }
            if questionsInARow <= Self.shownQuestionsInARow {
                record(.look(question: method, answer: answer ? "true" : "false"), context: context)
            }
            return .boolean(answer)
        }
        return .void
    }
}

/// Ergebnis in einer einzelnen Welt.
public struct ArenaWorldRun: Sendable {
    public let world: ArenaWorldSpec
    public let frames: [ArenaFrame]
    public let output: String
    public let problem: JavaProblem?
    public let reachedGoal: Bool
    public let coinsLeft: Int
    public let actions: Int
    public let outputMatches: Bool?
    /// Warum die Welt nicht geschafft ist – leer bei Erfolg.
    public let failures: [String]

    public var succeeded: Bool { failures.isEmpty }
}

public struct StarCriterionResult: Sendable, Hashable, Identifiable {
    public let criterion: StarCriterion
    public let met: Bool
    /// Was der Code tatsächlich geschafft hat („du: 9“) – damit klar ist, was zum Stern fehlt.
    /// Nur bei gelöster Mission, sonst nil.
    public var progress: String?
    public var id: String { criterion.title }
}

public struct ArenaResult: Sendable {
    public let runs: [ArenaWorldRun]
    /// Nicht erfüllte Pflicht-Bausteine (z. B. „Nutze eine Schleife“).
    public let missingRequirements: [String]
    public let solved: Bool
    public let criteria: [StarCriterionResult]
    public let codeLines: Int
    public let warnings: [JavaWarning]

    /// 1 Stern fürs Lösen, je ein weiterer pro erfülltem Zusatzziel.
    public var stars: Int { solved ? 1 + criteria.filter(\.met).count : 0 }

    /// Die erste Welt, in der etwas schiefging – die zeigt die App zuerst.
    public var firstFailingWorld: Int? { runs.firstIndex { !$0.succeeded } }
}

/// Führt Code in allen Welten einer Mission aus und bewertet das Ergebnis.
public enum ArenaEngine {
    public static let stepLimit = 60_000

    public static func run(_ code: String, mission: ArenaMission) -> ArenaResult {
        let source = JavaSource.normalizingTypography(code)
        var runs: [ArenaWorldRun] = []
        var warnings: [JavaWarning] = []
        for world in mission.worlds {
            let simulation = ArenaSimulation(world: world, commandNames: mission.commandNames)
            let result = JavaRunner.run(source, stepLimit: stepLimit, host: simulation)
            for warning in result.warnings where !warnings.contains(warning) { warnings.append(warning) }
            runs.append(evaluate(world: world, simulation: simulation, result: result, mission: mission))
            // Ein Syntaxfehler ist in jeder Welt derselbe – ein Lauf reicht.
            if result.problem?.kind == .syntax || result.problem?.kind == .unsupported { break }
        }

        let masked = JavaSource.maskingLiterals(source)
        let missing = mission.requirements.filter { rule in
            let matches = AnswerEvaluator.matches(rule.pattern, in: rule.scope == .raw ? JavaSource.strippingComments(source) : masked)
            return rule.rule == .require ? !matches : matches
        }.map(\.message)

        let solved = runs.count == mission.worlds.count && runs.allSatisfy(\.succeeded) && missing.isEmpty
        let lines = codeLineCount(source)
        let criteria = mission.bonus.map { criterion in
            let met: Bool = switch criterion {
            case .allCoins: runs.count == mission.worlds.count && runs.allSatisfy { $0.coinsLeft == 0 }
            case .maxLines(let limit): lines <= limit
            case .maxActions(let limit): runs.allSatisfy { $0.actions <= limit }
            case .uses(let pattern, _): AnswerEvaluator.matches(pattern, in: masked)
            }
            return StarCriterionResult(criterion: criterion, met: solved && met,
                                       progress: solved ? progress(of: criterion, met: met, runs: runs, lines: lines) : nil)
        }
        return ArenaResult(runs: runs, missingRequirements: missing, solved: solved, criteria: criteria, codeLines: lines, warnings: warnings)
    }

    private static func progress(of criterion: StarCriterion, met: Bool, runs: [ArenaWorldRun], lines: Int) -> String? {
        switch criterion {
        case .allCoins:
            let left = runs.map(\.coinsLeft).reduce(0, +)
            if met { return nil }
            return left == 1 ? "1 Münze liegt noch" : "\(left) Münzen liegen noch"
        case .maxLines:
            return lines == 1 ? "du: 1 Zeile" : "du: \(lines) Zeilen"
        case .maxActions:
            // Bei mehreren Welten zählt die Welt mit den meisten Aktionen.
            return "du: \(runs.map(\.actions).max() ?? 0)"
        case .uses:
            return nil
        }
    }

    private static func evaluate(world: ArenaWorldSpec, simulation: ArenaSimulation, result: JavaRunResult, mission: ArenaMission) -> ArenaWorldRun {
        var failures: [String] = []
        if let problem = result.problem {
            failures.append(problem.description)
        }
        let reachedGoal = world.goal == nil || simulation.robot == world.goal
        if result.problem == nil {
            if mission.reachGoal, !reachedGoal {
                failures.append("Der Roboter steht am Ende nicht auf dem Zielfeld.")
            }
            if mission.collectAllCoins, !simulation.coins.isEmpty {
                let count = simulation.coins.count
                failures.append(count == 1 ? "Es liegt noch 1 Münze herum." : "Es liegen noch \(count) Münzen herum.")
            }
        }
        var outputMatches: Bool?
        if let expected = world.expectedOutput {
            let matches = AnswerEvaluator.outputLines(result.output) == AnswerEvaluator.outputLines(expected)
            outputMatches = matches
            if result.problem == nil, !matches {
                failures.append(AnswerEvaluator.outputDifference(result.output, expected: expected).replacingOccurrences(of: "Ausgeführt – ", with: ""))
            }
        }
        return ArenaWorldRun(
            world: world, frames: simulation.frames, output: result.output, problem: result.problem,
            reachedGoal: reachedGoal, coinsLeft: simulation.coins.count, actions: simulation.actions,
            outputMatches: outputMatches, failures: failures
        )
    }

    /// Zählt „echte“ Codezeilen: ohne Leerzeilen, Kommentare, Zeilen, die nur Klammern enthalten,
    /// und ohne den Programmrahmen (`public class …` und `public static void main(…)`) –
    /// der gehört zu jedem Programm und soll bei „Höchstens N Zeilen“ nicht zählen.
    public static func codeLineCount(_ code: String) -> Int {
        JavaSource.strippingComments(code)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in !line.isEmpty && !line.allSatisfy { "{}();".contains($0) } && !isFrameLine(line) }
            .count
    }

    /// Kopf der Klasse oder der main-Methode.
    static func isFrameLine(_ line: String) -> Bool {
        line.range(of: #"^(public\s+)?(final\s+)?class\s+\w+\s*\{?$"#, options: .regularExpression) != nil
            || line.range(of: #"^public\s+static\s+void\s+main\s*\(\s*String\s*(\[\]\s*\w+|\.\.\.\s*\w+|\w+\s*\[\])\s*\)\s*\{?$"#, options: .regularExpression) != nil
    }
}
