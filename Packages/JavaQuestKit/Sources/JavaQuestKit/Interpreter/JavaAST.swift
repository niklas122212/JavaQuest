import Foundation

/// Statischer Typ, wie er im Quelltext steht.
indirect enum JavaType: Sendable, Hashable, CustomStringConvertible {
    case int, long, double, boolean, char, string, void
    /// `var` – der Typ ergibt sich aus dem zugewiesenen Wert.
    case inferred
    case array(JavaType)
    /// Ein Klassen-Typ, den der Interpreter nicht kennt.
    case unknown(String)
    /// Ein Referenztyp, den der Interpreter kennt: eigene Klasse, Interface, Enum, Record oder Bibliotheksklasse
    /// (`Hund`, `List<String>`, `Integer` …). Der Text bleibt für die Anzeige erhalten; Generics spielen beim
    /// Ausführen keine Rolle.
    case object(String)

    var description: String {
        switch self {
        case .int: "int"
        case .long: "long"
        case .double: "double"
        case .boolean: "boolean"
        case .char: "char"
        case .string: "String"
        case .void: "void"
        case .inferred: "var"
        case .array(let element): "\(element)[]"
        case .unknown(let name): name
        case .object(let name): name
        }
    }

    /// Klassenname ohne Generics: `List<String>` → `List`.
    var className: String? {
        switch self {
        case .object(let name), .unknown(let name):
            return String(name.prefix { $0 != "<" })
        case .string: return "String"
        default: return nil
        }
    }

    var isNumeric: Bool { self == .int || self == .long || self == .double || self == .char }
}

indirect enum JavaExpr: Sendable {
    case literal(JavaValue, line: Int)
    case name(String, line: Int)
    case unary(op: String, JavaExpr, line: Int)
    /// `++x`, `x--` usw.; `prefix` entscheidet, ob der alte oder neue Wert zurückkommt.
    case increment(op: String, prefix: Bool, JavaExpr, line: Int)
    case binary(op: String, JavaExpr, JavaExpr, line: Int)
    case logical(op: String, JavaExpr, JavaExpr, line: Int)
    case assign(op: String, target: JavaExpr, value: JavaExpr, line: Int)
    case conditional(JavaExpr, JavaExpr, JavaExpr, line: Int)
    case cast(JavaType, JavaExpr, line: Int)
    case index(JavaExpr, JavaExpr, line: Int)
    /// `ziel.name` ohne Klammern, z. B. `zahlen.length` oder `Math.PI`.
    case field(JavaExpr, String, line: Int)
    /// Methodenaufruf; `target == nil` bei eigenen Methoden wie `istGerade(4)`.
    case call(target: JavaExpr?, name: String, args: [JavaExpr], line: Int)
    case newArray(element: JavaType, sizes: [JavaExpr], extraDimensions: Int, line: Int)
    case arrayLiteral(element: JavaType?, [JavaExpr], line: Int)
    case switchExpr(JavaExpr, [JavaSwitchCase], line: Int)
    /// `x instanceof Hund` – mit `binding` (`x instanceof Hund h`) entsteht dabei eine neue Variable.
    case instanceOf(JavaExpr, JavaType, binding: String?, line: Int)
    /// Record-Muster: `o instanceof Punkt(int x, int y)` – packt die Felder gleich in neue Variablen aus.
    case recordPattern(JavaExpr, JavaPattern, line: Int)
    /// `new Hund("Bello")`, `new ArrayList<>()`, `new String("…")`.
    case newObject(className: String, args: [JavaExpr], line: Int)
    /// `this` – das Objekt, dessen Methode gerade läuft.
    case this(line: Int)
    /// `super` vor einem Methodenaufruf (`super.laut()`).
    case superRef(line: Int)

    var line: Int {
        switch self {
        case .literal(_, let line), .name(_, let line), .unary(_, _, let line), .increment(_, _, _, let line),
             .binary(_, _, _, let line), .logical(_, _, _, let line), .assign(_, _, _, let line),
             .conditional(_, _, _, let line), .cast(_, _, let line), .index(_, _, let line), .field(_, _, let line),
             .call(_, _, _, let line), .newArray(_, _, _, let line), .arrayLiteral(_, _, let line),
             .switchExpr(_, _, let line), .instanceOf(_, _, _, let line), .recordPattern(_, _, let line),
             .newObject(_, _, let line), .this(let line), .superRef(let line):
            line
        }
    }
}

/// Muster in instanceof und switch: `int x`, `var y`, `Punkt(int x, int y)` (auch verschachtelt).
indirect enum JavaPattern: Sendable {
    case binding(JavaType, String)
    case record(String, [JavaPattern])
}

struct JavaSwitchCase: Sendable {
    /// Leer bei `default`.
    let labels: [JavaExpr]
    let isDefault: Bool
    /// Pfeil-Syntax (`case 1 ->`): kein Durchfallen in den nächsten Fall.
    let isArrow: Bool
    let body: [JavaStmt]
    /// Bei `case 1 -> wert;` in switch-Ausdrücken.
    let value: JavaExpr?
    let line: Int
    /// Zusatzbedingung bei Typ-Mustern: `case Kreis k when k.radius() > 2 ->`.
    var guardExpr: JavaExpr? = nil
}

struct JavaVarDeclarator: Sendable {
    let name: String
    let extraDimensions: Int
    let initializer: JavaExpr?
    let line: Int
}

indirect enum JavaStmt: Sendable {
    case varDecl(JavaType, [JavaVarDeclarator], isFinal: Bool, line: Int)
    case expr(JavaExpr, line: Int)
    case block([JavaStmt], line: Int)
    case ifStmt(JavaExpr, JavaStmt, JavaStmt?, line: Int)
    case whileStmt(JavaExpr, JavaStmt, line: Int)
    case doWhile(JavaStmt, JavaExpr, line: Int)
    case forStmt(init: [JavaStmt], condition: JavaExpr?, update: [JavaExpr], body: JavaStmt, line: Int)
    case forEach(JavaType, String, JavaExpr, JavaStmt, line: Int)
    case breakStmt(line: Int)
    case continueStmt(line: Int)
    case returnStmt(JavaExpr?, line: Int)
    case yieldStmt(JavaExpr, line: Int)
    case switchStmt(JavaExpr, [JavaSwitchCase], line: Int)
    case throwStmt(JavaExpr, line: Int)
    /// `try { … } catch (A | B e) { … } finally { … }`
    case tryStmt(body: [JavaStmt], catches: [JavaCatch], finally: [JavaStmt]?, line: Int)
    case empty(line: Int)

    var line: Int {
        switch self {
        case .varDecl(_, _, _, let line), .expr(_, let line), .block(_, let line), .ifStmt(_, _, _, let line),
             .whileStmt(_, _, let line), .doWhile(_, _, let line), .forStmt(_, _, _, _, let line),
             .forEach(_, _, _, _, let line), .breakStmt(let line), .continueStmt(let line), .returnStmt(_, let line),
             .yieldStmt(_, let line), .switchStmt(_, _, let line), .throwStmt(_, let line),
             .tryStmt(_, _, _, let line), .empty(let line):
            line
        }
    }
}

struct JavaParameter: Sendable {
    let type: JavaType
    let name: String
}

struct JavaCatch: Sendable {
    /// Ein oder mehrere Exception-Typen (`catch (A | B e)`).
    let types: [String]
    let name: String
    let body: [JavaStmt]
    let line: Int
}

struct JavaMethod: Sendable {
    let name: String
    let returnType: JavaType
    let parameters: [JavaParameter]
    let body: [JavaStmt]
    let line: Int
    var isStatic = true
    /// Ohne Körper (in Interfaces und abstrakten Klassen).
    var isAbstract = false
    var isPrivate = false
    /// Mit @Override markiert – dann muss es die Methode in einer Oberklasse oder einem Interface geben.
    var isOverride = false
    /// Klasse, in der die Methode steht (`nil` = Hauptklasse bzw. lose Methoden).
    var owner: String?
}

/// Konstruktor einer eigenen Klasse.
struct JavaConstructor: Sendable {
    let parameters: [JavaParameter]
    let body: [JavaStmt]
    let isPrivate: Bool
    let line: Int
    /// Kompakter Record-Konstruktor `Punkt { … }`: prüft die Werte, danach landen sie automatisch in den Feldern.
    var isCompact = false
}

/// Ein Feld einer eigenen Klasse.
struct JavaField: Sendable {
    let type: JavaType
    let name: String
    let initializer: JavaExpr?
    let isStatic: Bool
    let isFinal: Bool
    let isPrivate: Bool
    let line: Int
}

/// Eine Enum-Konstante, z. B. `ROT("Stehen")`.
struct JavaEnumConstant: Sendable {
    let name: String
    let args: [JavaExpr]
    let line: Int
}

/// Eine eigene Klasse, ein Interface, ein Enum oder ein Record.
struct JavaClass: Sendable {
    enum Kind: Sendable { case classType, interface, enumType, record }

    let name: String
    let kind: Kind
    /// Oberklasse (`extends`); `nil` = Object. Für eigene Exceptions z. B. `Exception`.
    var superclass: String?
    var interfaces: [String] = []
    var isAbstract = false
    /// Äußere Klasse bei verschachtelten Klassen – für den Namen `Main$Inner` und private Zugriffe.
    var outer: String?
    var fields: [JavaField] = []
    var constructors: [JavaConstructor] = []
    var methods: [String: [JavaMethod]] = [:]
    var enumConstants: [JavaEnumConstant] = []
    var recordComponents: [JavaParameter] = []
    let line: Int

    /// Name, wie ihn Java bei `getName()` und im Standard-`toString()` zeigt.
    var binaryName: String { outer.map { "\($0)$\(name)" } ?? name }
    var isInterface: Bool { kind == .interface }
}

/// Ein geparstes Programm: eigene (statische) Methoden, statische Felder und
/// die Anweisungen, die beim Start laufen (der Inhalt von `main`).
struct JavaProgram: Sendable {
    var methods: [String: [JavaMethod]] = [:]
    var staticFields: [JavaStmt] = []
    var statements: [JavaStmt] = []
    /// true, wenn es eine `main`-Methode gab (dann sind `statements` ihr Inhalt).
    var hasMain = false
    /// Eigene Klassen, Interfaces, Enums und Records (ohne die Hauptklasse mit main).
    var classes: [String: JavaClass] = [:]
    /// Reihenfolge, in der die Klassen im Quelltext stehen – für die Initialisierung statischer Felder.
    var classOrder: [String] = []
    /// Name der Hauptklasse (mit main), falls es eine gab.
    var mainClass: String?
}
