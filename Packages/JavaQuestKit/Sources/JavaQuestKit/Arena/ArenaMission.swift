import Foundation

/// Blickrichtung des Roboters.
public enum Heading: String, Decodable, Sendable, Hashable, CaseIterable {
    case north, east, south, west

    public var left: Heading {
        switch self {
        case .north: .west
        case .west: .south
        case .south: .east
        case .east: .north
        }
    }

    public var right: Heading {
        switch self {
        case .north: .east
        case .east: .south
        case .south: .west
        case .west: .north
        }
    }

    var delta: (dx: Int, dy: Int) {
        switch self {
        case .north: (0, -1)
        case .east: (1, 0)
        case .south: (0, 1)
        case .west: (-1, 0)
        }
    }

    /// Drehwinkel für die Darstellung (0° = nach rechts/Osten).
    public var degrees: Double {
        switch self {
        case .east: 0
        case .south: 90
        case .west: 180
        case .north: 270
        }
    }
}

public struct GridPoint: Sendable, Hashable, Comparable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public func moved(_ heading: Heading) -> GridPoint {
        GridPoint(x: x + heading.delta.dx, y: y + heading.delta.dy)
    }

    public static func < (lhs: GridPoint, rhs: GridPoint) -> Bool {
        (lhs.y, lhs.x) < (rhs.y, rhs.x)
    }
}

/// Eine Spielwelt als Textkarte:
/// `#` Wand · `.` Boden · `o` Münze · `G` Ziel · `R` Startfeld des Roboters.
public struct ArenaWorldSpec: Decodable, Sendable, Hashable {
    public let map: [String]
    public let facing: Heading
    /// Erwartete Konsolenausgabe in genau dieser Welt (optional).
    public let expectedOutput: String?

    enum CodingKeys: String, CodingKey { case map, facing, expectedOutput }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        map = try container.decode([String].self, forKey: .map)
        facing = try container.decodeIfPresent(Heading.self, forKey: .facing) ?? .east
        expectedOutput = try container.decodeIfPresent(String.self, forKey: .expectedOutput)
    }

    public init(map: [String], facing: Heading = .east, expectedOutput: String? = nil) {
        self.map = map
        self.facing = facing
        self.expectedOutput = expectedOutput
    }

    public var width: Int { map.map(\.count).max() ?? 0 }
    public var height: Int { map.count }

    func cell(_ point: GridPoint) -> Character {
        guard point.y >= 0, point.y < map.count else { return "#" }
        let row = Array(map[point.y])
        guard point.x >= 0, point.x < row.count else { return "#" }
        return row[point.x]
    }

    func points(where predicate: (Character) -> Bool) -> [GridPoint] {
        var result: [GridPoint] = []
        for (y, row) in map.enumerated() {
            for (x, character) in row.enumerated() where predicate(character) {
                result.append(GridPoint(x: x, y: y))
            }
        }
        return result
    }

    public var walls: Set<GridPoint> { Set(points { $0 == "#" }) }
    public var coins: Set<GridPoint> { Set(points { $0 == "o" }) }
    public var goal: GridPoint? { points { $0 == "G" }.first }
    public var start: GridPoint? { points { $0 == "R" }.first }

    public func isWall(_ point: GridPoint) -> Bool { cell(point) == "#" }
}

/// Zusatzziel für Stern 2 und 3. Stern 1 gibt es für das Lösen der Mission.
public enum StarCriterion: Decodable, Sendable, Hashable {
    /// Alle Münzen in allen Welten einsammeln.
    case allCoins
    /// Höchstens so viele Codezeilen (ohne Leerzeilen, Kommentare und reine Klammerzeilen).
    case maxLines(Int)
    /// Der Roboter kommt mit höchstens so vielen Aktionen (Fahren, Drehen, Aufheben) aus – je Welt.
    case maxActions(Int)
    /// Der Code nutzt einen bestimmten Baustein (RegEx auf dem Code ohne Kommentare/Literale).
    case uses(pattern: String, label: String)

    enum CodingKeys: String, CodingKey { case type, value, pattern, label }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "allCoins": self = .allCoins
        case "maxLines": self = .maxLines(try container.decode(Int.self, forKey: .value))
        case "maxActions": self = .maxActions(try container.decode(Int.self, forKey: .value))
        case "uses": self = .uses(pattern: try container.decode(String.self, forKey: .pattern), label: try container.decode(String.self, forKey: .label))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unbekanntes Sternziel \(other)")
        }
    }

    public var title: String {
        switch self {
        case .allCoins: "Alle Münzen eingesammelt"
        case .maxLines(let lines): "Höchstens \(lines) Zeilen Code"
        case .maxActions(let actions): "Höchstens \(actions) Roboter-Aktionen"
        case .uses(_, let label): label
        }
    }

    public var symbolName: String {
        switch self {
        case .allCoins: "circle.circle.fill"
        case .maxLines: "text.alignleft"
        case .maxActions: "figure.walk"
        case .uses: "puzzlepiece.extension.fill"
        }
    }
}

/// Eine Arena-Mission: Der Roboter muss in einer oder mehreren Welten ans Ziel –
/// mit demselben Code. Mehrere Welten zwingen zu Bedingungen und Schleifen statt Auswendiglernen.
public struct ArenaMission: Decodable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Decodable, Sendable {
        /// Abschluss einer Lektion.
        case lesson
        /// Großes Abschlusslevel eines Moduls.
        case boss
        /// Zusätzliche Trainingsmission (z. B. als tägliche Mission).
        case training
    }

    public let id: String
    public let kind: Kind
    public let title: String
    /// Kurze Geschichte und Auftrag in Alltagssprache.
    public let story: String
    /// Mission gehört zu dieser Lektion (Abschluss) bzw. wird mit ihr freigeschaltet.
    public let lessonId: String
    /// Bei Boss-Missionen: das Modul, dessen Abschluss sie freischaltet.
    public let moduleId: String?
    public let topicId: String
    public let difficulty: Difficulty
    public let worlds: [ArenaWorldSpec]
    public let starter: CodeSnippet
    public let solution: CodeSnippet
    public let hint: String
    /// Muss der Roboter am Ende auf dem Zielfeld stehen?
    public let reachGoal: Bool
    /// Müssen alle Münzen eingesammelt werden, damit die Mission als gelöst gilt?
    public let collectAllCoins: Bool
    /// Bausteine, die genutzt werden müssen (z. B. eine Schleife) – sonst ist die Mission nicht gelöst.
    public let requirements: [CodeRule]
    /// Genau zwei Zusatzziele für Stern 2 und 3.
    public let bonus: [StarCriterion]
    /// Roboter-Befehle, die in dieser Mission neu sind (werden hervorgehoben).
    public let newCommands: [String]

    enum CodingKeys: String, CodingKey {
        case id, kind, title, story, lessonId, moduleId, topicId, difficulty, worlds
        case starterCode, solution, hint, reachGoal, collectAllCoins, requirements, bonus, newCommands
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        story = try container.decode(String.self, forKey: .story)
        lessonId = try container.decode(String.self, forKey: .lessonId)
        moduleId = try container.decodeIfPresent(String.self, forKey: .moduleId)
        topicId = try container.decode(String.self, forKey: .topicId)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        worlds = try container.decode([ArenaWorldSpec].self, forKey: .worlds)
        starter = try container.decodeIfPresent(CodeSnippet.self, forKey: .starterCode) ?? CodeSnippet(source: "")
        solution = try container.decode(CodeSnippet.self, forKey: .solution)
        hint = try container.decode(String.self, forKey: .hint)
        reachGoal = try container.decodeIfPresent(Bool.self, forKey: .reachGoal) ?? true
        collectAllCoins = try container.decodeIfPresent(Bool.self, forKey: .collectAllCoins) ?? false
        requirements = try container.decodeIfPresent([CodeRule].self, forKey: .requirements) ?? []
        bonus = try container.decode([StarCriterion].self, forKey: .bonus)
        newCommands = try container.decodeIfPresent([String].self, forKey: .newCommands) ?? []
    }

    public var starterCode: String { starter.source }

    public init(
        id: String, kind: Kind, title: String, story: String, lessonId: String, moduleId: String? = nil,
        topicId: String, difficulty: Difficulty, worlds: [ArenaWorldSpec], starter: CodeSnippet, solution: CodeSnippet,
        hint: String, reachGoal: Bool = true, collectAllCoins: Bool = false, requirements: [CodeRule] = [],
        bonus: [StarCriterion] = [], newCommands: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.story = story
        self.lessonId = lessonId
        self.moduleId = moduleId
        self.topicId = topicId
        self.difficulty = difficulty
        self.worlds = worlds
        self.starter = starter
        self.solution = solution
        self.hint = hint
        self.reachGoal = reachGoal
        self.collectAllCoins = collectAllCoins
        self.requirements = requirements
        self.bonus = bonus
        self.newCommands = newCommands
    }

    /// Der Spielplatz: eine freie Welt ohne Ziel, ohne Pflicht und ohne Sterne.
    public static func playground(_ world: ArenaWorldSpec) -> ArenaMission {
        ArenaMission(
            id: "playground", kind: .training, title: "Spielplatz",
            story: "Hier gibt es kein Ziel und keine Bewertung – probier einfach aus, was Byte alles kann.",
            lessonId: "", topicId: "syntax", difficulty: .veryEasy, worlds: [world],
            starter: CodeSnippet(source: "// Probier dich aus!\nrobot.move();\nrobot.turnLeft();"),
            solution: CodeSnippet(source: ""), hint: "Tippe unten auf einen Befehl, um ihn einzufügen.", reachGoal: false
        )
    }
}

/// Alle Missionen der Arena (siehe `Resources/arena_missions.json`).
public struct ArenaCatalog: Decodable, Sendable, Hashable {
    public let missions: [ArenaMission]
    /// Freie Welt für den Spielplatz – ohne Ziel und ohne Bewertung.
    public let playground: ArenaWorldSpec

    public init(missions: [ArenaMission], playground: ArenaWorldSpec) {
        self.missions = missions
        self.playground = playground
    }

    public func mission(id: String) -> ArenaMission? { missions.first { $0.id == id } }

    /// Die Abschluss-Mission einer Lektion.
    public func lessonMission(for lessonId: String) -> ArenaMission? {
        missions.first { $0.kind == .lesson && $0.lessonId == lessonId }
    }

    public func bossMission(for moduleId: String) -> ArenaMission? {
        missions.first { $0.kind == .boss && $0.moduleId == moduleId }
    }

    public static let bundledResourceName = "arena_missions"

    public static func loadBundled() throws -> ArenaCatalog {
        guard let url = CourseLoader.resourceBundle.url(forResource: bundledResourceName, withExtension: "json") else {
            throw CourseLoadingError.missingResource(bundledResourceName)
        }
        return try JSONDecoder().decode(ArenaCatalog.self, from: Data(contentsOf: url))
    }
}
