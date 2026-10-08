import Foundation
import Testing
@testable import JavaQuestKit

@Suite("Arena")
struct ArenaTests {
    let catalog: ArenaCatalog
    let course: Course

    init() throws {
        catalog = try ArenaCatalog.loadBundled()
        course = try CourseLoader.loadBundled()
    }

    @Test("Missionen sind vollständig und passen zum Kurs")
    func catalogIsConsistent() {
        #expect(catalog.missions.count >= 13)
        #expect(Set(catalog.missions.map(\.id)).count == catalog.missions.count, "IDs doppelt")
        let lessonIds = Set(course.allLessons.map(\.id))
        let topicIds = Set(course.topics.map(\.id))
        for mission in catalog.missions {
            #expect(lessonIds.contains(mission.lessonId), "\(mission.id): Lektion \(mission.lessonId)")
            #expect(topicIds.contains(mission.topicId), "\(mission.id): Thema \(mission.topicId)")
            #expect(mission.bonus.count == 2, "\(mission.id): genau zwei Zusatzziele")
            #expect(!mission.worlds.isEmpty)
            if mission.kind == .boss {
                #expect(course.modules.contains { $0.id == mission.moduleId }, "\(mission.id): Modul")
            }
            for (index, world) in mission.worlds.enumerated() {
                #expect(world.start != nil, "\(mission.id) Welt \(index + 1): kein Startfeld R")
                if mission.reachGoal { #expect(world.goal != nil, "\(mission.id) Welt \(index + 1): kein Ziel G") }
                #expect(Set(world.map.map(\.count)).count == 1, "\(mission.id) Welt \(index + 1): Zeilen ungleich lang")
            }
        }
        // Jede Lektion der Module 1–2 und Lektion 7 endet mit einer Mission.
        for lessonId in ["l01-hello", "l02-variables", "l03-operators", "l04-conditionals", "l05-loops", "l06-methods", "l07-arrays-strings"] {
            #expect(catalog.lessonMission(for: lessonId) != nil, "Keine Mission für \(lessonId)")
        }
        for moduleId in ["m1-first-steps", "m2-control-flow", "m3-objects"] {
            #expect(catalog.bossMission(for: moduleId) != nil, "Kein Boss für \(moduleId)")
        }
        #expect(catalog.playground.start != nil)
    }

    @Test("Jede Musterlösung schafft alle Welten mit 3 Sternen")
    func solutionsEarnThreeStars() {
        for mission in catalog.missions {
            let result = ArenaEngine.run(mission.solution.source, mission: mission)
            let problems = result.runs.flatMap(\.failures) + result.missingRequirements
            #expect(result.solved, "\(mission.id): \(problems)")
            #expect(result.stars == 3, "\(mission.id): \(result.criteria.filter { !$0.met }.map(\.criterion.title))")
        }
    }

    @Test("Der Startcode allein löst keine Mission")
    func starterCodeDoesNotSolve() {
        for mission in catalog.missions {
            #expect(!ArenaEngine.run(mission.starterCode, mission: mission).solved, "\(mission.id)")
        }
    }

    @Test("Jede Zeile von Startcode und Lösung ist in Alltagssprache erklärt")
    func everyLineExplained() {
        for mission in catalog.missions {
            for snippet in [mission.starter, mission.solution] {
                for line in CodeExplainer.explain(snippet.source) where line.isFallback {
                    Issue.record("\(mission.id) Zeile \(line.number): \(line.code)")
                }
            }
        }
    }

    func mission(_ map: [String], coins: Bool = false, output: String? = nil) -> ArenaMission {
        let json = """
        {"id":"test","kind":"training","title":"T","story":"","lessonId":"l01-hello","topicId":"syntax","difficulty":1,
         "worlds":[{"map":\(String(data: try! JSONEncoder().encode(map), encoding: .utf8)!)\(output.map { ",\"expectedOutput\":\"\($0)\"" } ?? "")}],
         "solution":"","hint":"","collectAllCoins":\(coins),"bonus":[{"type":"allCoins"},{"type":"maxLines","value":3}]}
        """
        return try! JSONDecoder().decode(ArenaMission.self, from: Data(json.utf8))
    }

    @Test("Gegen die Wand fahren bricht mit Zeilennummer ab und wird animiert")
    func crashIntoWall() throws {
        let corridor = mission(["#####", "#R.G#", "#####"])
        let result = ArenaEngine.run("robot.move();\nrobot.move();\nrobot.move();", mission: corridor)
        #expect(!result.solved)
        let run = try #require(result.runs.first)
        #expect(run.problem?.line == 3)
        #expect(run.problem?.message.contains("Wand") == true)
        #expect(run.frames.last?.action == .crash(wall: GridPoint(x: 4, y: 1)), "Das Wandfeld, gegen das Byte fährt")
        #expect(run.frames.first?.action == .start)
        #expect(run.frames.map(\.robot.x) == [1, 2, 3, 3])

        let grab = ArenaEngine.run("robot.pickCoin();", mission: corridor)
        #expect(grab.runs[0].frames.last?.action == .crash(wall: nil), "Ins Leere gegriffen: keine Wand")
    }

    @Test("Ziel, Münzen und Ausgabe werden geprüft")
    func goalsAreChecked() {
        let level = mission(["######", "#Ro.G#", "######"], coins: true, output: "fertig")
        let lazy = ArenaEngine.run("robot.move();\nrobot.move();\nrobot.move();\nSystem.out.println(\"fertig\");", mission: level)
        #expect(!lazy.solved)
        #expect(lazy.runs[0].failures.contains { $0.contains("Münze") })

        let wrongOutput = ArenaEngine.run("robot.move();\nrobot.pickCoin();\nrobot.move();\nrobot.move();", mission: level)
        #expect(!wrongOutput.solved)

        let good = ArenaEngine.run("robot.move();\nrobot.pickCoin();\nrobot.move();\nrobot.move();\nSystem.out.println(\"fertig\");", mission: level)
        #expect(good.solved)
        #expect(good.stars == 2, "Alle Münzen ja, aber mehr als 3 Zeilen")
        #expect(good.runs[0].frames.last?.output == "")
    }

    @Test("Hilfreiche Meldungen bei Tippfehlern im Roboter-Befehl")
    func unknownCommand() {
        let level = mission(["####", "#RG#", "####"])
        let result = ArenaEngine.run("robot.Move();", mission: level)
        #expect(result.runs[0].problem?.message.contains("robot.move()") == true)
        let bare = ArenaEngine.run("move();", mission: level)
        #expect(bare.runs[0].problem?.message.contains("robot.move()") == true)
    }

    @Test("Ein Roboter, der im Kreis fährt, wird gestoppt")
    func endlessRobot() {
        let room = mission(["#####", "#R..#", "#..G#", "#####"])
        let result = ArenaEngine.run("while (true) {\n  robot.turnLeft();\n}", mission: room)
        #expect(result.runs[0].problem?.kind == .stepLimit)
    }

    @Test("Eine Schleife ohne robot.move(); zeigt nur wenige Fragen, nicht 250 gleiche Bilder")
    func endlessQuestionsAreShortened() {
        let corridor = mission(["######", "#R..G#", "######"])
        let result = ArenaEngine.run("while (!robot.atGoal()) {\n}", mission: corridor)
        let run = result.runs[0]
        #expect(run.problem?.kind == .stepLimit)
        #expect(run.frames.count == 1 + ArenaSimulation.shownQuestionsInARow)
    }

    @Test("Sterne nennen, was der Code geschafft hat")
    func starProgressIsReported() throws {
        let level = mission(["######", "#Ro.G#", "######"])
        let result = ArenaEngine.run("robot.move();\nrobot.move();\nrobot.move();\nrobot.move();", mission: level)
        #expect(!result.solved)
        #expect(result.criteria.allSatisfy { $0.progress == nil }, "Ohne Lösung keine Messwerte")

        let solved = ArenaEngine.run("robot.move();\nrobot.move();\nrobot.move();", mission: level)
        let coins = try #require(solved.criteria.first { $0.criterion == .allCoins })
        let lines = try #require(solved.criteria.first { $0.criterion == .maxLines(3) })
        #expect(!coins.met && coins.progress == "1 Münze liegt noch")
        #expect(lines.met && lines.progress == "du: 3 Zeilen")
    }

    @Test("Wiedergabe: Fragen sind kürzer, lange Fahrten werden gestaucht")
    func playbackDelays() throws {
        let catalog = catalog
        let short = try #require(catalog.mission(id: "a01-erste-schritte"))
        let quick = ArenaEngine.run(short.solution.source, mission: short).runs[0].frames
        #expect(ArenaPlayback.delays(for: quick, base: 0.4) == [0] + Array(repeating: 0.4, count: quick.count - 1))

        for mission in catalog.missions {
            for run in ArenaEngine.run(mission.solution.source, mission: mission).runs {
                let delays = ArenaPlayback.delays(for: run.frames, base: 0.38)
                #expect(delays.reduce(0, +) <= 0.38 * ArenaPlayback.maxSteps + 0.001, "\(mission.id): zu lang")
                for (frame, delay) in zip(run.frames, delays).dropFirst() {
                    if case .look = frame.action { #expect(delay < 0.38) }
                }
            }
        }
    }

    @Test("Befehle landen an der Stelle, an der man schreibt")
    func commandInsertion() {
        let loop = "while (!robot.atGoal()) {\n    // Was soll in jeder Runde passieren?\n}"
        // Ohne Cursor: in den leeren Block, eingerückt
        let first = CodeInsertion.insert("robot.move();", into: loop, cursor: nil)
        #expect(first.code == "while (!robot.atGoal()) {\n    // Was soll in jeder Runde passieren?\n    robot.move();\n}")
        // Weiter hinter dem zuletzt Eingefügten
        let second = CodeInsertion.insert("robot.pickCoin();", into: first.code, cursor: first.cursor)
        #expect(second.code.hasSuffix("    robot.move();\n    robot.pickCoin();\n}"))
        // Vorlagen werden als Ganzes eingerückt
        let template = CodeInsertion.insert("if (robot.onCoin()) {\n    robot.pickCoin();\n}", into: loop, cursor: nil)
        #expect(template.code.contains("\n    if (robot.onCoin()) {\n        robot.pickCoin();\n    }\n}"))
        // Cursor hinter einer Zeile mit { : eine Stufe tiefer
        let afterBrace = CodeInsertion.insert("robot.move();", into: "while (true) {\n}", cursor: 14)
        #expect(afterBrace.code == "while (true) {\n    robot.move();\n}")
        // Cursor am Zeilenanfang: davor
        let atStart = CodeInsertion.insert("robot.move();", into: "robot.turnLeft();\nrobot.pickCoin();", cursor: 18)
        #expect(atStart.code == "robot.turnLeft();\nrobot.move();\nrobot.pickCoin();")
        // Leere Zeile wird zur Befehlszeile
        let blank = CodeInsertion.insert("robot.move();", into: "int a = 0;\n\nrobot.turnLeft();", cursor: 11)
        #expect(blank.code == "int a = 0;\nrobot.move();\nrobot.turnLeft();")
        // Kein leerer Block: ans Ende
        let plain = CodeInsertion.insert("robot.move();", into: "// Start\nrobot.move();\n", cursor: nil)
        #expect(plain.code == "// Start\nrobot.move();\nrobot.move();\n")
        #expect(CodeInsertion.insert("robot.move();", into: "", cursor: nil).code == "robot.move();")
    }

    @Test("Codezeilen zählen nur echte Anweisungen")
    func lineCount() {
        #expect(ArenaEngine.codeLineCount("// Kommentar\nrobot.move();\n\n}\n  }\nrobot.move(); // weiter") == 2)
        // Der Programmrahmen zählt nicht – mit und ohne Rahmen gleich viele Zeilen.
        let framed = "public class Test {\n    public static void main(String[] args) {\n        robot.move();\n    }\n}"
        #expect(ArenaEngine.codeLineCount(framed) == 1)
    }

    static let frame = """
    public class Test {
        static void schritt() {
            robot.move();
        }

        public static void main(String[] args) {
            robot.move();
        }
    }
    """

    @Test("Im echten Programm landen Befehle in main und Methoden in der Klasse")
    func insertionRespectsTheProgramFrame() {
        // Ohne Cursor: ans Ende von main, nicht hinter die letzte }
        let appended = CodeInsertion.insert("robot.turnLeft();", into: Self.frame, cursor: nil)
        #expect(appended.code.contains("        robot.move();\n        robot.turnLeft();\n    }\n}"))
        // Cursor auf der Klassenzeile oder hinter der letzten }: trotzdem in main
        let onClassLine = CodeInsertion.insert("robot.turnLeft();", into: Self.frame, cursor: 5)
        #expect(onClassLine.code == appended.code)
        let atEnd = CodeInsertion.insert("robot.turnLeft();", into: Self.frame, cursor: Self.frame.utf16.count)
        #expect(atEnd.code == appended.code)
        // Cursor in einer Methode: dort
        let inMethod = CodeInsertion.insert("robot.pickCoin();", into: Self.frame, cursor: "public class Test {\n    static void schritt() {\n        robot.move();".utf16.count)
        #expect(inMethod.code.contains("        robot.move();\n        robot.pickCoin();\n    }\n\n    public static void main"))
        // Eine Methode kommt in die Klasse über main – egal, wo man schreibt
        let method = CodeInsertion.insert("static void drehen() {\n    robot.turnLeft();\n}", into: Self.frame, cursor: nil)
        #expect(method.code.contains("    static void drehen() {\n        robot.turnLeft();\n    }\n\n    public static void main"))
        // Leeres main: eine Stufe tiefer als main
        let empty = CodeInsertion.insert("robot.move();", into: "public class A {\n    public static void main(String[] args) {\n    }\n}", cursor: nil)
        #expect(empty.code == "public class A {\n    public static void main(String[] args) {\n        robot.move();\n    }\n}")
    }

    @Test("Jede Mission ist ein echtes Java-Programm: Klasse mit main, Datei passt zum Namen")
    func missionsAreRealPrograms() {
        for mission in catalog.missions {
            #expect(mission.className.range(of: #"^[A-Z][A-Za-z0-9]*$"#, options: .regularExpression) != nil, "\(mission.id): \(mission.className)")
            for snippet in [mission.starterCode, mission.solution.source] {
                #expect(snippet.hasPrefix("public class \(mission.className) {"), "\(mission.id)")
                #expect(snippet.contains("    public static void main(String[] args) {"), "\(mission.id)")
            }
        }
        #expect(Set(catalog.missions.map(\.className)).count == catalog.missions.count, "Klassennamen doppelt")
        let playground = ArenaMission.playground(catalog.playground)
        #expect(playground.starterCode.hasPrefix("public class Spielplatz {"))
        #expect(ArenaEngine.run(playground.starterCode, mission: playground).runs[0].problem == nil)
    }

    // MARK: Nur Bekanntes – und ein klarer Auftrag

    var lessonOrder: [String] { course.allLessons.map(\.id) }

    func lessonIndex(_ mission: ArenaMission) -> Int { lessonOrder.firstIndex(of: mission.lessonId) ?? .max }

    @Test("Missionen stehen in Kursreihenfolge")
    func missionsFollowTheCourse() {
        let indices = catalog.missions.map(lessonIndex)
        #expect(indices == indices.sorted(), "\(catalog.missions.map(\.lessonId))")
    }

    @Test("Jede Mission sagt in Schritten, was zu tun ist, und nennt ihre Bausteine")
    func briefingIsComplete() {
        for mission in catalog.missions {
            #expect(mission.steps.count >= 2, "\(mission.id): Schritte fehlen")
            #expect(!mission.goals.isEmpty, "\(mission.id): kein Auftrag")
            #expect(!mission.conceptIds.isEmpty, "\(mission.id): keine Bausteine")
            for id in mission.conceptIds {
                guard let concept = catalog.concept(id: id) else {
                    Issue.record("\(mission.id): Baustein \(id) fehlt im Katalog")
                    continue
                }
                // Was der Kurs erst später erklärt, darf keine Mission voraussetzen.
                if let taughtIn = concept.lessonId {
                    let taught = lessonOrder.firstIndex(of: taughtIn)
                    #expect(taught != nil, "\(id): Lektion \(taughtIn) gibt es nicht")
                    #expect((taught ?? .max) <= lessonIndex(mission), "\(mission.id) braucht \(id) aus \(taughtIn)")
                }
            }
        }
        #expect(Set(catalog.concepts.map(\.id)).count == catalog.concepts.count, "Baustein-IDs doppelt")
    }

    /// Welche Bausteine ein Programm benutzt – grob per Muster, für die Prüfung der Missionen.
    static func usedConcepts(_ source: String) -> Set<String> {
        let raw = JavaSource.strippingComments(source)
        let masked = JavaSource.maskingLiterals(source)
        let patterns: [(String, String, String)] = [
            ("ausgabe", #"System\.out\.print"#, masked),
            ("variable", #"(?m)^\s*(int|String|double|boolean)\s+\w+\s*="#, masked),
            ("hochzaehlen", #"\b(\w+)\s*=\s*\1\s*\+\s*1\b|\w\+\+\s*;|\+=\s*1\b"#, masked),
            ("textUndZahl", #""\s*\+|\+\s*""#, raw),
            ("antwort", #"=\s*robot\.\w+\(\)"#, masked),
            ("rechnen", #"[\w)]\s*\*\s*[\w(]"#, masked),
            ("if", #"\bif\s*\("#, masked),
            ("ifElse", #"\belse\b(?!\s+if\b)"#, masked),
            ("elseIf", #"\belse\s+if\b"#, masked),
            ("nicht", #"!(?!=)"#, masked),
            ("while", #"\bwhile\s*\("#, masked),
            ("for", #"\bfor\s*\(\s*int\s+\w+\s*="#, masked),
            ("forRunter", #"\bfor\s*\([^)]*--"#, masked),
            ("methode", #"\bstatic\s+void\s+\w+\s*\(\s*\)"#, masked),
            ("methodeMitWert", #"\bstatic\s+void\s+\w+\s*\(\s*\w+\s+\w+"#, masked),
            ("array", #"\[\]\s*\w+\s*=\s*\{"#, masked),
            ("forEach", #"\bfor\s*\(\s*\w+\s+\w+\s*:"#, masked),
            ("textAnhaengen", #"\+=\s*""#, raw),
        ]
        return Set(patterns.filter { $0.2.range(of: $0.1, options: .regularExpression) != nil }.map(\.0))
    }

    /// Eine Schleife steht im Block einer anderen – das erklärt der Kurs bis Lektion 8 nicht.
    static func hasNestedLoop(_ source: String) -> Bool {
        var blocks: [Bool] = []
        for line in JavaSource.maskingLiterals(source).components(separatedBy: "\n") {
            let isLoop = line.range(of: #"^\s*(\}\s*)?(for|while)\s*\("#, options: .regularExpression) != nil
            if isLoop, blocks.contains(true) { return true }
            for character in line {
                if character == "}" { _ = blocks.popLast() }
                if character == "{" { blocks.append(isLoop) }
            }
        }
        return false
    }

    @Test("Die Bausteine-Erkennung trifft, was sie soll")
    func conceptDetection() {
        #expect(Self.usedConcepts("while (!robot.atGoal()) {\n    robot.move();\n}") == ["while", "nicht"])
        #expect(Self.usedConcepts("if (a != b) {\n} else if (c) {\n} else {\n}") == ["if", "elseIf", "ifElse"])
        #expect(Self.usedConcepts("muster += \"x\";\nSystem.out.println(\"Wert: \" + wert);") == ["textAnhaengen", "ausgabe", "textUndZahl"])
        #expect(Self.hasNestedLoop("for (int a : b) {\n    for (int i = 0; i < a; i++) {\n    }\n}"))
        #expect(!Self.hasNestedLoop("for (int a : b) {\n    fahre(a);\n}\nwhile (x) {\n}"))
    }

    @Test("Missionen brauchen nur, was der Kurs oder der Auftrag schon erklärt hat")
    func missionsNeedOnlyKnownConcepts() {
        // Ein Baustein im Auftrag deckt auch die einfacheren mit ab (if–else enthält if).
        let coveredBy: [String: Set<String>] = [
            "ausgabe": ["textUndZahl"],
            "variable": ["antwort", "rechnen", "text"],
            "if": ["ifElse", "elseIf"],
            "ifElse": ["elseIf"],
            "for": ["forRunter"],
        ]
        for mission in catalog.missions {
            for snippet in [mission.starterCode, mission.solution.source] {
                for used in Self.usedConcepts(snippet) {
                    let listed = mission.conceptIds.contains { $0 == used || coveredBy[used, default: []].contains($0) }
                    let taught = catalog.concept(id: used)?.lessonId.flatMap { lessonOrder.firstIndex(of: $0) }.map { $0 <= lessonIndex(mission) } ?? false
                    #expect(listed || taught, "\(mission.id) braucht „\(used)“, ohne es zu erklären")
                }
                #expect(!Self.hasNestedLoop(snippet), "\(mission.id): Schleife in der Schleife")
                // Der Kurs schreibt if immer mit geschweiften Klammern – die Missionen auch.
                #expect(JavaSource.maskingLiterals(snippet).range(of: #"(?m)^[^{\n]*\bif\s*\([^{\n]*;\s*$"#, options: .regularExpression) == nil, "\(mission.id): if ohne Klammern")
            }
        }
    }

    @Test("Lösung und Startcode brauchen nur Befehle, die Byte schon kann")
    func missionsNeedOnlyKnownCommands() {
        let names = Set(RobotCommand.all.map(\.name))
        for mission in catalog.missions {
            #expect(Set(mission.newCommands).isSubset(of: names), "\(mission.id): unbekannter neuer Befehl")
            #expect(Set(mission.newCommands).isSubset(of: mission.commandNames), "\(mission.id)")
            for snippet in [mission.starterCode, mission.solution.source] {
                let masked = JavaSource.maskingLiterals(snippet)
                let used = masked.matches(of: /robot\.(\w+)\s*\(/).map { String($0.output.1) }
                for name in used where !mission.commandNames.contains(name) {
                    Issue.record("\(mission.id) nutzt robot.\(name)(), das erst später eingeführt wird")
                }
            }
        }
        #expect(catalog.mission(id: "a01-erste-schritte")?.commandNames == ["move", "pickCoin"])
    }

    @Test("Die Befehlsleiste bietet nur an, was schon erklärt ist")
    func paletteOffersOnlyKnownTemplates() throws {
        func templates(_ id: String) throws -> [String] {
            try catalog.templates(for: #require(catalog.mission(id: id)), lessonOrder: lessonOrder).map(\.name)
        }
        #expect(try templates("a01-erste-schritte").isEmpty)
        #expect(try templates("b1-tunnelschatz").isEmpty)
        #expect(try templates("a04-die-weiche") == ["if"])
        #expect(try templates("a05-langer-gang") == ["if", "while", "for"])
        #expect(try !templates("t2-zickzack").contains("Methode"), "Methoden kommen erst in Lektion 6")
        #expect(try templates("a06-die-treppe").contains("Methode"))
    }

    @Test("Neues ist markiert – Bekanntes nicht")
    func newConceptsAreMarked() throws {
        let gang = try #require(catalog.mission(id: "a05-langer-gang"))
        #expect(catalog.conceptUses(for: gang).first { $0.id == "nicht" }?.isNew == true)
        #expect(catalog.conceptUses(for: gang).first { $0.id == "while" }?.isNew == false, "while kommt aus Lektion 5")
        let huerden = try #require(catalog.mission(id: "t3-huerdenlauf"))
        #expect(catalog.conceptUses(for: huerden).first { $0.id == "nicht" }?.isNew == false, "schon im endlosen Gang erklärt")
    }

    @Test("Der Auftrag nennt Ziel, Ausgabe, Pflicht und Welten")
    func goalsDescribeTheMission() throws {
        let first = try #require(catalog.mission(id: "a01-erste-schritte"))
        #expect(first.goals.map(\.kind) == [.reachGoal, .output])
        #expect(first.goals[1].outputs == [ArenaGoal.ExpectedOutput(world: nil, text: "Angekommen!")])

        let knacker = try #require(catalog.mission(id: "b3-codeknacker"))
        let output = try #require(knacker.goals.first { $0.kind == .output })
        #expect(output.outputs.map(\.world) == [1, 2])

        let weiche = try #require(catalog.mission(id: "a04-die-weiche"))
        #expect(weiche.goals.map(\.kind) == [.reachGoal, .collectCoins, .rule, .allWorlds])
    }
}
