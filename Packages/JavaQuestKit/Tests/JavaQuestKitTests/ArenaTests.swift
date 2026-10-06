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
}
