import Foundation

/// Ein UML-Klassendiagramm, wie es im Kurs gezeigt und abgefragt wird.
///
/// Bewusst schlank gehalten: genau das, was für Klassendiagramme gebraucht wird –
/// Kästen mit Feldern und Methoden sowie die Linien dazwischen. Die Anwendung zeichnet
/// daraus selbst ein Bild (siehe `UMLLayout`), ohne fremde Bibliothek.
public struct UMLDiagram: Decodable, Sendable, Hashable {
    /// Sichtbarkeit wie in UML: + öffentlich, - privat, # geschützt.
    public enum Visibility: String, Decodable, Sendable, Hashable, CaseIterable {
        case publicAccess = "+"
        case privateAccess = "-"
        case protectedAccess = "#"

        /// Was das Zeichen in Alltagssprache bedeutet.
        public var meaning: String {
            switch self {
            case .publicAccess: "öffentlich – von überall nutzbar"
            case .privateAccess: "privat – nur innerhalb der Klasse"
            case .protectedAccess: "geschützt – in der Klasse und in ihren Kind-Klassen"
            }
        }
    }

    /// Ein Feld oder eine Methode im Kasten.
    public struct Member: Decodable, Sendable, Hashable, Identifiable {
        public let visibility: Visibility
        public let name: String
        /// Bei Feldern der Typ, bei Methoden der Rückgabetyp (leer = void).
        public let type: String?

        public var id: String { "\(visibility.rawValue)\(name)\(type ?? "")" }

        /// Zeile wie im Diagramm: „- name: String“ bzw. „+ getName(): String“.
        public var line: String { type.map { "\(visibility.rawValue) \(name): \($0)" } ?? "\(visibility.rawValue) \(name)" }

        public init(visibility: Visibility, name: String, type: String? = nil) {
            self.visibility = visibility
            self.name = name
            self.type = type
        }
    }

    /// Was für ein Kasten das ist – steht in UML als «…» über dem Namen.
    public enum BoxKind: String, Decodable, Sendable, Hashable {
        case classType
        case interfaceType
        case abstractType
        case recordType

        public var stereotype: String? {
            switch self {
            case .classType: nil
            case .interfaceType: "«interface»"
            case .abstractType: "«abstract»"
            case .recordType: "«record»"
            }
        }
    }

    /// Ein Klassenkasten.
    public struct Box: Decodable, Sendable, Hashable, Identifiable {
        public let name: String
        public let kind: BoxKind
        public let fields: [Member]
        public let methods: [Member]

        public var id: String { name }

        public init(name: String, kind: BoxKind = .classType, fields: [Member] = [], methods: [Member] = []) {
            self.name = name
            self.kind = kind
            self.fields = fields
            self.methods = methods
        }

        enum CodingKeys: String, CodingKey { case name, kind, fields, methods }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            kind = try container.decodeIfPresent(BoxKind.self, forKey: .kind) ?? .classType
            fields = try container.decodeIfPresent([Member].self, forKey: .fields) ?? []
            methods = try container.decodeIfPresent([Member].self, forKey: .methods) ?? []
        }
    }

    /// Die Linie zwischen zwei Kästen.
    public enum RelationKind: String, Decodable, Sendable, Hashable, CaseIterable {
        case extendsRelation
        case implementsRelation
        case association
        case aggregation
        case composition
        case dependency

        /// Name und Bedeutung in Alltagssprache – erklärt im Diagramm und in Aufgaben.
        public var title: String {
            switch self {
            case .extendsRelation: "Vererbung (extends)"
            case .implementsRelation: "Interface umsetzen (implements)"
            case .association: "Assoziation"
            case .aggregation: "Aggregation"
            case .composition: "Komposition"
            case .dependency: "Abhängigkeit"
            }
        }

        public var meaning: String {
            switch self {
            case .extendsRelation: "„ist ein“: Die Kind-Klasse erbt alles von der Eltern-Klasse. Pfeil mit leerer Dreiecksspitze zur Eltern-Klasse."
            case .implementsRelation: "Die Klasse unterschreibt einen Vertrag. Gestrichelte Linie mit leerer Dreiecksspitze zum Interface."
            case .association: "„kennt“: Die eine Klasse benutzt die andere dauerhaft, z. B. als Feld."
            case .aggregation: "„hat“, aber die Teile leben weiter: Eine Schulklasse hat Schüler – ohne die Klasse gibt es sie trotzdem. Leere Raute an der Ganzes-Seite."
            case .composition: "„besteht aus“: Ohne das Ganze gibt es die Teile nicht – ein Haus und seine Räume. Gefüllte Raute an der Ganzes-Seite."
            case .dependency: "„benutzt kurz“: Die Klasse braucht die andere nur vorübergehend, z. B. als Parameter. Gestrichelter Pfeil."
            }
        }

        /// Gestrichelte Linien: Vertrag umsetzen und kurzfristige Abhängigkeit.
        public var isDashed: Bool { self == .implementsRelation || self == .dependency }
    }

    public struct Relation: Decodable, Sendable, Hashable, Identifiable {
        /// Kind-Klasse bzw. die Klasse, von der die Linie ausgeht.
        public let from: String
        /// Eltern-Klasse, Interface oder das „Ganze“.
        public let to: String
        public let kind: RelationKind
        /// Beschriftung an der Linie, z. B. „fährt“.
        public let label: String?
        /// Vielfachheit am Ziel, z. B. „1..*“.
        public let multiplicity: String?

        public var id: String { "\(from)-\(kind.rawValue)-\(to)" }

        public init(from: String, to: String, kind: RelationKind, label: String? = nil, multiplicity: String? = nil) {
            self.from = from
            self.to = to
            self.kind = kind
            self.label = label
            self.multiplicity = multiplicity
        }
    }

    public let classes: [Box]
    public let relations: [Relation]

    public init(classes: [Box], relations: [Relation] = []) {
        self.classes = classes
        self.relations = relations
    }

    public func box(named name: String) -> Box? { classes.first { $0.name == name } }
}

/// Rechnet aus, wo die Kästen eines Diagramms liegen – dieselbe Anordnung auf allen Plattformen.
///
/// Regel: Eltern-Klassen und Interfaces stehen oben, ihre Kinder darunter. Kästen einer
/// Ebene stehen nebeneinander. Alles ohne Beziehung landet in der obersten Ebene.
public enum UMLLayout {
    public static let boxWidth: Double = 220
    public static let headerHeight: Double = 38
    public static let rowHeight: Double = 22
    public static let sectionPadding: Double = 8
    public static let horizontalGap: Double = 40
    public static let verticalGap: Double = 70

    public struct Placed: Sendable, Hashable {
        public let box: UMLDiagram.Box
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        public var centerX: Double { x + width / 2 }
        public var bottom: Double { y + height }
    }

    public struct Result: Sendable, Hashable {
        public let boxes: [Placed]
        public let width: Double
        public let height: Double

        public func placed(named name: String) -> Placed? { boxes.first { $0.box.name == name } }
    }

    /// Höhe eines Kastens: Kopf plus je eine Zeile für Felder und Methoden.
    public static func height(of box: UMLDiagram.Box) -> Double {
        let rows = Double(max(box.fields.count, 1) + max(box.methods.count, 1))
        return headerHeight + rows * rowHeight + sectionPadding * 2
    }

    /// Ebene je Klasse: 0 ganz oben, Kinder jeweils eine Ebene tiefer.
    public static func levels(_ diagram: UMLDiagram) -> [String: Int] {
        var level: [String: Int] = [:]
        for box in diagram.classes { level[box.name] = 0 }
        // Vererbung und Interfaces bestimmen die Ebenen; mehrfach laufen lassen,
        // damit auch Ketten (A erbt von B, B erbt von C) richtig einsortiert werden.
        for _ in 0..<max(diagram.classes.count, 1) {
            for relation in diagram.relations where relation.kind == .extendsRelation || relation.kind == .implementsRelation {
                let parent = level[relation.to] ?? 0
                if (level[relation.from] ?? 0) <= parent { level[relation.from] = parent + 1 }
            }
        }
        return level
    }

    public static func compute(_ diagram: UMLDiagram) -> Result {
        let levelOf = levels(diagram)
        let grouped = Dictionary(grouping: diagram.classes) { levelOf[$0.name] ?? 0 }
        var placed: [Placed] = []
        var y: Double = 0
        var maxWidth: Double = 0

        for level in grouped.keys.sorted() {
            let row = grouped[level] ?? []
            let rowWidth = Double(row.count) * boxWidth + Double(max(row.count - 1, 0)) * horizontalGap
            maxWidth = max(maxWidth, rowWidth)
            var x: Double = 0
            var rowHeightMax: Double = 0
            for box in row {
                let boxHeight = height(of: box)
                placed.append(Placed(box: box, x: x, y: y, width: boxWidth, height: boxHeight))
                x += boxWidth + horizontalGap
                rowHeightMax = max(rowHeightMax, boxHeight)
            }
            y += rowHeightMax + verticalGap
        }

        // Zeilen mittig ausrichten, damit das Bild ruhig wirkt.
        let centered = placed.map { item -> Placed in
            let row = placed.filter { $0.y == item.y }
            let rowWidth = (row.map { $0.x + $0.width }.max() ?? 0) - (row.map(\.x).min() ?? 0)
            let offset = (maxWidth - rowWidth) / 2
            return Placed(box: item.box, x: item.x + offset, y: item.y, width: item.width, height: item.height)
        }
        return Result(boxes: centered, width: maxWidth, height: max(y - verticalGap, 0))
    }
}
