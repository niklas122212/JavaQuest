import Foundation

/// Statischer Typ, wie er im Quelltext steht.
indirect enum JavaType: Sendable, Hashable, CustomStringConvertible {
    case int, long, double, boolean, char, string, void
    /// `var` – der Typ ergibt sich aus dem zugewiesenen Wert.
    case inferred
    case array(JavaType)
    /// Ein Klassen-Typ, den der Interpreter nicht kennt (z. B. `ArrayList<String>`).
    case unknown(String)

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
    case instanceOf(JavaExpr, JavaType, line: Int)
    /// `new String("…")` – andere Klassen meldet der Interpreter als nicht unterstützt.
    case newObject(className: String, args: [JavaExpr], line: Int)

    var line: Int {
        switch self {
        case .literal(_, let line), .name(_, let line), .unary(_, _, let line), .increment(_, _, _, let line),
             .binary(_, _, _, let line), .logical(_, _, _, let line), .assign(_, _, _, let line),
             .conditional(_, _, _, let line), .cast(_, _, let line), .index(_, _, let line), .field(_, _, let line),
             .call(_, _, _, let line), .newArray(_, _, _, let line), .arrayLiteral(_, _, let line),
             .switchExpr(_, _, let line), .instanceOf(_, _, let line),
             .newObject(_, _, let line):
            line
        }
    }
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
    case empty(line: Int)

    var line: Int {
        switch self {
        case .varDecl(_, _, _, let line), .expr(_, let line), .block(_, let line), .ifStmt(_, _, _, let line),
             .whileStmt(_, _, let line), .doWhile(_, _, let line), .forStmt(_, _, _, _, let line),
             .forEach(_, _, _, _, let line), .breakStmt(let line), .continueStmt(let line), .returnStmt(_, let line),
             .yieldStmt(_, let line), .switchStmt(_, _, let line), .throwStmt(_, let line), .empty(let line):
            line
        }
    }
}

struct JavaParameter: Sendable {
    let type: JavaType
    let name: String
}

struct JavaMethod: Sendable {
    let name: String
    let returnType: JavaType
    let parameters: [JavaParameter]
    let body: [JavaStmt]
    let line: Int
}

/// Ein geparstes Programm: eigene (statische) Methoden, statische Felder und
/// die Anweisungen, die beim Start laufen (der Inhalt von `main`).
struct JavaProgram: Sendable {
    var methods: [String: [JavaMethod]] = [:]
    var staticFields: [JavaStmt] = []
    var statements: [JavaStmt] = []
    /// true, wenn es eine `main`-Methode gab (dann sind `statements` ihr Inhalt).
    var hasMain = false
}
