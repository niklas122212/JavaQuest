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
        #expect(run.frames.last?.action == .crash)
        #expect(run.frames.first?.action == .start)
        #expect(run.frames.map(\.robot.x) == [1, 2, 3, 3])
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

    @Test("Codezeilen zählen nur echte Anweisungen")
    func lineCount() {
        #expect(ArenaEngine.codeLineCount("// Kommentar\nrobot.move();\n\n}\n  }\nrobot.move(); // weiter") == 2)
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
