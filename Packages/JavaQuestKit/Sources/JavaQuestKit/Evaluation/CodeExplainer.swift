import Foundation

/// Eine erklärte Codezeile: was sie tut und welche Befehle darin vorkommen.
public struct ExplainedLine: Sendable, Hashable, Identifiable {
    /// Zeilennummer im Schnipsel (1-basiert, Leerzeilen mitgezählt).
    public let number: Int
    public let code: String
    public let explanation: String
    /// Befehle dieser Zeile, die im selben Schnipsel noch nicht erklärt wurden.
    public let terms: [GlossaryEntry]
    /// true, wenn keine Regel gegriffen hat – darf in Kursinhalten nie vorkommen (Test).
    public let isFallback: Bool

    public init(number: Int, code: String, explanation: String, terms: [GlossaryEntry], isFallback: Bool) {
        self.number = number
        self.code = code
        self.explanation = explanation
        self.terms = terms
        self.isFallback = isFallback
    }

    public var id: Int { number }
}

/// Erklärt Java-Code Zeile für Zeile in Alltagssprache – regelbasiert und komplett lokal.
///
/// Durchgängige Bilder, damit Anfänger nie im Fachjargon stecken bleiben:
/// Variable = Box mit Namen, Typ = Etikett der Box, Klasse = Kuchenform,
/// Objekt = Kuchen, Methode = Rezept, Parameter = Zutaten, Array = Eierkarton,
/// Liste = Einkaufszettel, Map = Wörterbuch, Exception = Alarm, try/catch =
/// Sicherheitsnetz, Stream = Fließband, Kommentar = Notizzettel.
///
/// Der Generator liefert die Erklärungen, die im Kurs-JSON gespeichert werden,
/// und springt zur Laufzeit ein, falls einer Zeile dort die Erklärung fehlt.
public enum CodeExplainer {
    public static func explain(_ code: String) -> [ExplainedLine] {
        var context = Context()
        var result: [ExplainedLine] = []
        var seenTerms = Set<String>()

        for (offset, raw) in code.components(separatedBy: "\n").enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let (statement, comment) = splitTrailingComment(line)

            var text: String
            var fallback = false
            if statement.isEmpty {
                text = commentLineText(comment ?? "")
            } else {
                let methodBefore = context.currentMethodName
                (text, fallback) = context.describe(statement)
                if let method = methodBefore,
                   statement.range(of: #"\b\#(method)\s*\("#, options: .regularExpression) != nil {
                    text += " Achtung, spannend: Hier ruft das Rezept „\(method)“ sich selbst auf (Rekursion) – mit einer kleineren Aufgabe. Das wiederholt sich, bis der Basisfall greift."
                }
                if let comment, !comment.isEmpty { text += " " + trailingCommentText(comment) }
            }
            let terms = JavaGlossary.terms(in: JavaSource.maskingLiterals(statement))
                .filter { seenTerms.insert($0.term).inserted }
            result.append(ExplainedLine(number: offset + 1, code: raw, explanation: text, terms: terms, isFallback: fallback))
        }
        return result
    }

    // MARK: - Kommentare

    /// Trennt einen Kommentar `// …` am Zeilenende ab (nicht innerhalb von Strings).
    static func splitTrailingComment(_ line: String) -> (statement: String, comment: String?) {
        let chars = Array(line)
        var inString = false
        var inChar = false
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if (inString || inChar) && c == "\\" { i += 2; continue }
            if c == "\"" && !inChar { inString.toggle() }
            if c == "'" && !inString { inChar.toggle() }
            if !inString && !inChar && c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                let statement = String(chars[..<i]).trimmingCharacters(in: .whitespaces)
                let comment = String(chars[(i + 2)...]).trimmingCharacters(in: .whitespaces)
                return (statement, comment)
            }
            i += 1
        }
        if line.hasPrefix("/*") || line.hasPrefix("*") {
            return ("", line.replacingOccurrences(of: "/*", with: "").replacingOccurrences(of: "*/", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "* ")))
        }
        return (line, nil)
    }

    static func commentLineText(_ comment: String) -> String {
        if comment.range(of: #"\bhier\b"#, options: .regularExpression) != nil {
            return "Ein Notizzettel als Platzhalter („\(comment)“): Genau an dieser Stelle schreibst du deinen eigenen Code hin. Java überliest Kommentare."
        }
        return "Das ist ein Kommentar – ein Notizzettel für Menschen: „\(comment)“. Java überliest diese Zeile komplett."
    }

    private static let resultLike = try? NSRegularExpression(
        pattern: #"^(-?[\d.]+(\s+-?[\d.]+)*|true|false|'.'|".*"|\[.*\]|\{.*\}|[A-ZÄÖÜ][\wäöüß]*(\[.*\])?)$"#
    )

    static func trailingCommentText(_ comment: String) -> String {
        let range = NSRange(comment.startIndex..., in: comment)
        if resultLike?.firstMatch(in: comment, range: range) != nil {
            return "Der Notizzettel dahinter verrät, was herauskommt: \(comment)."
        }
        return "Der Notizzettel dahinter („\(comment)“) ist nur für Menschen – Java überliest ihn."
    }
}

// MARK: - Zustand über die Zeilen hinweg

private enum Block: Equatable {
    case type(kind: String, name: String)
    case method(String)
    case constructor(String)
    case main
    case ifBlock, elseBlock, loop, doLoop
    case switchStatement, switchExpression, caseBlock
    case tryBlock, catchBlock, finallyBlock
    case lambda, other
}

private struct Context {
    var stack: [Block] = []
    /// Klassen mit main-Methode: Sie sind nur der Behälter ums Programm, keine Kuchenform.
    var programTypes: Set<String> = []
    /// Box, in der das Ergebnis des laufenden Fließbands landet (nil: Kette ohne Zuweisung).
    var chainTarget: String?
    /// Bekannte Boxen mit ihrem Etikett (Typ) – für passende Erklärungen von Aufrufen.
    var boxTypes: [String: String] = [:]
    /// Selbst angelegte Aufzählungen (enum).
    var enumTypes: Set<String> = []

    var currentMethodName: String? {
        for block in stack.reversed() { if case .method(let name) = block { return name } }
        return nil
    }

    var currentTypeKind: String? {
        for block in stack.reversed() { if case .type(let kind, _) = block { return kind } }
        return nil
    }

    func baseType(_ box: String) -> String? {
        boxTypes[box].map { $0.components(separatedBy: "<").first ?? $0 }
    }

    /// Wie Syntax.value, kennt aber die Etiketten der Boxen (Abholschein, Zähler, Stapel …).
    func phrase(_ raw: String) -> String {
        let e = raw.trimmingCharacters(in: .whitespaces)
        if let call = Syntax.topLevelCall(e), let receiver = call.receiver, Syntax.groups(Syntax.identifier, receiver) != nil {
            let type = baseType(receiver) ?? ""
            switch (call.method, type) {
            case ("get", "Future") where call.arguments.isEmpty:
                return "das Ergebnis vom Abholschein „\(receiver)“ (get wartet notfalls, bis es fertig ist)"
            case ("get", "AtomicInteger") where call.arguments.isEmpty:
                return "den aktuellen Stand des sicheren Zählers „\(receiver)“"
            case ("pop", _): return "den obersten Eintrag des Stapels „\(receiver)“ (pop nimmt ihn dabei weg)"
            case ("poll", _): return "den vordersten Eintrag der Warteschlange „\(receiver)“ (poll nimmt ihn dabei aus der Schlange)"
            case ("peek", _): return "den obersten Eintrag von „\(receiver)“ – nur angeschaut, nicht weggenommen (peek)"
            case ("contains", "Set"), ("contains", "TreeSet"), ("contains", "HashSet"):
                return "die Antwort auf die Frage „Steht \(Syntax.shortValue(call.arguments)) im Set „\(receiver)“?“ (true = ja, false = nein)"
            default: break
            }
        }
        return Syntax.value(e)
    }

    var currentTypeName: String? {
        for block in stack.reversed() { if case .type(_, let name) = block { return name } }
        return nil
    }

    var inTypeBody: Bool {
        if case .type? = stack.last { return true }
        return false
    }

    mutating func describe(_ s: String) -> (String, Bool) {
        // Zeilen, die mit } beginnen: Block schließen, eventuell neuen öffnen.
        if s.hasPrefix("}") {
            let closed = stack.popLast()
            let rest = String(s.dropFirst()).trimmed
            if rest.isEmpty || rest == ";" || rest == ")" || rest == ");" {
                return (closingText(closed, rest: rest), false)
            }
            if rest.hasPrefix("else if"), let (cond, _) = Syntax.parenthesized(after: "else if", in: rest) {
                stack.append(.ifBlock)
                return ("Falls die Antwort oben „nein“ war, stellt das Programm die nächste Frage: Stimmt „\(cond)“\(Syntax.idiomHint(cond))? Nur bei „ja“ läuft der folgende Block.\(Syntax.patternNote(cond))", false)
            }
            if rest.hasPrefix("else") {
                stack.append(.elseBlock)
                return ("Sonst (else): Wenn alle Fragen davor mit „nein“ beantwortet wurden, läuft stattdessen dieser Block.", false)
            }
            if rest.hasPrefix("catch"), let (inside, _) = Syntax.parenthesized(after: "catch", in: rest) {
                stack.append(.catchBlock)
                let parts = inside.split(separator: " ").map(String.init)
                let type = parts.first ?? "Exception"
                let variable = parts.last ?? "e"
                let meaning = JavaGlossary.words[type].map { " – \($0.trimmingCharacters(in: CharacterSet(charactersIn: ".")))" } ?? ""
                return ("Das Sicherheitsnetz (catch) für den Alarm \(type)\(meaning). Wurde im try-Block genau dieser Alarm ausgelöst, landet das Programm hier, statt abzustürzen. In „\(variable)“ stehen die Details zum Fehler.", false)
            }
            if rest.hasPrefix("finally") {
                stack.append(.finallyBlock)
                return ("finally: Dieser Block läuft zum Schluss immer – egal, ob ein Alarm kam oder nicht. Wie das Aufräumen nach dem Kochen.", false)
            }
            if rest.hasPrefix("while"), let (cond, _) = Syntax.parenthesized(after: "while", in: rest) {
                return ("Hier endet die do-while-Schleife. Erst jetzt kommt die Frage „\(cond)?“ – bei „ja“ beginnt eine neue Runde.", false)
            }
        }

        if s.hasPrefix("@Override") {
            return ("@Override ist ein Hinweiszettel: „Die folgende Methode ersetzt die gleichnamige Methode der Eltern-Form.“ Java prüft, ob es diese Methode dort wirklich gibt – so fallen Tippfehler sofort auf.", false)
        }
        if s == "@Test" {
            return ("@Test ist ein Hinweiszettel für JUnit: „Diese Methode ist ein Test.“ JUnit findet alle so markierten Methoden und startet sie automatisch.", false)
        }
        if s.hasPrefix("@") {
            return ("\(s) ist ein Hinweiszettel (Annotation) für Java.", false)
        }
        if s.hasPrefix("package ") {
            let name = String(s.dropFirst(8).dropLast()).trimmed
            return ("package: Diese Datei gehört zum Paket „\(name)“ – wie ein Ordner für Klassen. Auf der Festplatte liegt sie im Ordner \(name.replacingOccurrences(of: ".", with: "/")). Diese Zeile muss ganz oben stehen.", false)
        }
        if s.hasPrefix("import static ") {
            let target = String(s.dropFirst(14).dropLast())
            return ("Holt die Methode \(target.split(separator: ".").last ?? "") direkt in den Code (import static) – danach kann man sie ohne Klassennamen davor aufrufen.", false)
        }
        if s.hasPrefix("import ") {
            return ("Holt \(s.dropFirst(7).dropLast()) in den Code, damit wir es direkt benutzen können – wie Werkzeug aus dem Nachbarraum.", false)
        }

        if let text = typeDeclaration(s) { return (text, false) }
        if let text = methodDeclaration(s) { return (text, false) }
        if let text = controlStructure(s) { return (text, false) }
        if let text = printStatement(s) { return (text, false) }
        if let args = Syntax.groups(Syntax.superCall, s)?[1] {
            return ("Ruft zuerst die Backanleitung (den Konstruktor) der Eltern-Form auf und gibt ihr \(Syntax.list(Syntax.splitArguments(args))) als Zutaten mit. Damit sind die geerbten Fächer gefüllt.", false)
        }
        if let text = declaration(s) { return (text, false) }
        if let text = assignment(s) { return (text, false) }
        if let text = streamStep(s) { return (text, false) }
        if !s.hasSuffix(";"), s.hasSuffix(".stream()"), Syntax.groups(Syntax.identifier, String(s.dropLast(".stream()".count))) != nil {
            chainTarget = nil
            let source = String(s.dropLast(".stream()".count))
            return ("Legt alle Elemente von „\(source)“ aufs Fließband (Stream). Die nächsten Zeilen sind die Stationen, an denen sie vorbeikommen.", false)
        }
        if let text = callStatement(s) { return (text, false) }

        if s.hasSuffix("{") { stack.append(.other) }
        return ("Anweisung: \(s)", true)
    }

    // MARK: Blöcke schließen

    func closingText(_ block: Block?, rest: String) -> String {
        let suffix: String
        switch rest {
        case ";": suffix = " Das Semikolon beendet die ganze Anweisung."
        case ")", ");": suffix = " Die runde Klammer schließt den Aufruf, zu dem der Block gehört."
        default: suffix = ""
        }
        let text: String
        switch block {
        case .type(let kind, let name)?:
            switch kind {
            case "Interface": text = "Hier endet das Interface (der Vertrag) „\(name)“."
            case "Record": text = "Hier endet der Record „\(name)“."
            default:
                text = programTypes.contains(name)
                    ? "Hier endet die Klasse „\(name)“ – der Behälter um unser Programm ist zu."
                    : "Hier endet die Klasse „\(name)“ – die Kuchenform ist fertig beschrieben."
            }
        case .method(let name)?: text = "Hier endet die Methode (das Rezept) „\(name)“."
        case .constructor?: text = "Hier endet der Konstruktor (die Backanleitung)."
        case .main?: text = "Hier endet die main-Methode – danach ist das Programm fertig."
        case .ifBlock?: text = "Hier endet der Block, der nur bei „ja“ ausgeführt wird."
        case .elseBlock?: text = "Hier endet der Sonst-Block (else)."
        case .loop?: text = "Hier endet eine Runde der Schleife. Das Programm springt wieder nach oben und prüft, ob noch eine Runde kommt."
        case .doLoop?: text = "Hier endet die do-while-Schleife."
        case .switchStatement?: text = "Hier endet der Weichensteller (switch)."
        case .switchExpression?: text = "Hier endet der Weichensteller (switch-Ausdruck)."
        case .caseBlock?: text = "Hier endet der Block für diesen Fall."
        case .tryBlock?: text = "Hier endet der Versuch (try)."
        case .catchBlock?: text = "Hier endet das Sicherheitsnetz (catch)."
        case .finallyBlock?: text = "Hier endet der Aufräum-Block (finally)."
        case .lambda?: text = "Hier endet die Mini-Anweisung (Lambda)."
        case .other?, nil: text = "Diese Klammer schließt den Block, der weiter oben geöffnet wurde."
        }
        return text + suffix
    }

    // MARK: Klassen, Interfaces, Records

    mutating func typeDeclaration(_ s: String) -> String? {
        guard let g = Syntax.groups(Syntax.typeDecl, s) else { return nil }
        let modifiers = g[1], keyword = g[2], name = g[3], generic = g[4]
        let components = g[5], superclass = g[6], interfaces = g[7], permitted = g[8], tail = g[9]
        var text: String
        switch keyword {
        case "interface":
            text = "Hier beginnt das Interface „\(name)“ – ein Vertrag: Es legt nur fest, WAS eine Klasse können muss (welche Methoden), aber nicht WIE."
        case "record":
            let fields = Syntax.parameters(String(components.dropFirst().dropLast()))
            text = "Hier definieren wir den Record „\(name)“ – wie ein Formular mit festen Feldern: \(Syntax.list(fields.map { "\($0.name) (\(Syntax.typeAccusative($0.type)))" })). "
                + "Den Rest erledigt Java automatisch: Konstruktor, Lesemethoden \(Syntax.list(fields.map { "\($0.name)()" })), Vergleich (equals) und Textdarstellung (toString)."
            if tail.replacingOccurrences(of: " ", with: "") == "{}" { text += " Die leeren Klammern {} heißen: Mehr braucht es nicht." }
        case "enum":
            enumTypes.insert(name)
            let body = tail.trimmingCharacters(in: CharacterSet(charactersIn: "{} ;"))
            if tail.hasSuffix("}"), !body.isEmpty {
                let values = body.split(separator: ",").map { String($0).trimmed }
                text = "Hier legen wir die Aufzählung (enum) „\(name)“ an – eine feste Auswahl mit genau \(values.count) erlaubten Werten: \(Syntax.list(values)). Andere Werte kann es nicht geben."
            } else {
                text = "Hier beginnt die Aufzählung (enum) „\(name)“ – eine feste Liste möglicher Werte."
            }
        default:
            text = "Hier beginnt die Klasse „\(name)“. Stell sie dir als Kuchenform vor: Sie beschreibt, welche Eigenschaften und Fähigkeiten jedes Objekt vom Typ \(name) hat. Die echten Objekte sind die Kuchen, die später mit new aus dieser Form gebacken werden."
            if modifiers.contains("abstract") { text += " abstract: Eine unfertige Form – aus ihr selbst kann man keine Kuchen backen, nur aus ihren Erweiterungen." }
        }
        if !generic.isEmpty { text += " \(generic) ist ein Platzhalter-Etikett: Erst beim Benutzen wird festgelegt, welcher Typ gemeint ist." }
        if !superclass.isEmpty { text += " extends \(superclass): „\(name)“ ist eine erweiterte \(superclass)-Form. Sie übernimmt (erbt) alles, was \(superclass) hat und kann, und darf Dinge ergänzen oder ändern." }
        if !interfaces.isEmpty {
            let who = keyword == "record" ? "Der Record" : keyword == "enum" ? "Die Aufzählung" : "Die Klasse"
            text += " implements \(interfaces): \(who) unterschreibt einen Vertrag – \(keyword == "class" ? "sie" : keyword == "record" ? "er" : "sie") verspricht, alle Methoden anzubieten, die \(interfaces) verlangt."
        }
        if modifiers.contains("sealed") && !modifiers.contains("non-sealed") {
            let members = permitted.split(separator: ",").map { String($0).trimmed }
            text += members.isEmpty
                ? " sealed: Die Familie ist geschlossen – nur ausdrücklich erlaubte Typen dürfen dazugehören."
                : " sealed … permits: Die Familie ist geschlossen – nur \(Syntax.list(members)) dürfen dazugehören. So weiß Java genau, welche Sorten es gibt."
        }
        if tail.replacingOccurrences(of: " ", with: "") == "{}" && keyword != "record" { text += " Die leeren Klammern {} heißen: Mehr braucht es nicht." }
        if tail.hasSuffix("{") && !tail.contains("}") {
            let kind = keyword == "interface" ? "Interface" : keyword == "record" ? "Record" : keyword == "enum" ? "Enum" : "Klasse"
            stack.append(.type(kind: kind, name: name))
        }
        return text
    }

    // MARK: Methoden und Konstruktoren

    mutating func methodDeclaration(_ s: String) -> String? {
        if s.hasPrefix("public static void main(") || s.hasPrefix("static void main(") {
            if s.hasSuffix("{") { stack.append(.main) }
            if let name = currentTypeName { programTypes.insert(name) }
            return "Die main-Methode ist der Startknopf des Programms: Hier beginnt Java, die Anweisungen von oben nach unten auszuführen. (public: von außen startbar · static: ohne Objekt nutzbar · void: liefert kein Ergebnis · String[] args: mögliche Startwerte.)"
        }

        if let g = Syntax.groups(Syntax.constructorDecl, s), g[2] == currentTypeName {
            let params = Syntax.parameters(g[3])
            for param in params { boxTypes[param.name] = param.type }
            stack.append(.constructor(g[2]))
            let ingredients = params.isEmpty ? "Er braucht keine Zutaten." : "Als Zutaten bekommt er \(Syntax.list(params.map { "\($0.name) (\(Syntax.typeAccusative($0.type)))" }))."
            return "Das ist der Konstruktor – die Backanleitung, die automatisch abläuft, sobald mit new \(g[2])(…) ein neues Objekt gebacken wird. \(ingredients) Hier bekommt das neue Objekt seine Startwerte."
        }

        guard let g = Syntax.groups(Syntax.methodDecl, s) else { return nil }
        let modifiers = g[1], generic = g[2].trimmed, returnType = g[3], name = g[4], params = Syntax.parameters(g[5])
        let tail = g[7].trimmed
        guard !Syntax.statementKeywords.contains(returnType) else { return nil }

        for param in params { boxTypes[param.name] = param.type }
        let ingredients = params.isEmpty
            ? "Sie braucht keine Zutaten"
            : "Als Zutaten bekommt sie \(Syntax.list(params.map { "\($0.name) (\(Syntax.typeAccusative($0.type)))" }))"
        let result = returnType == "void"
            ? "liefert kein Ergebnis zurück (void = „leer“) – sie erledigt nur eine Aufgabe"
            : "liefert am Ende \(Syntax.typeAccusative(returnType)) als Ergebnis zurück"

        if tail == ";" {
            let owner = currentTypeName.map { " „\($0)“" } ?? ""
            if currentTypeKind == "Interface" {
                return "Hier steht nur der Name des Rezepts „\(name)“ – ohne Anleitung. \(ingredients) und \(result). Jede Klasse, die den Vertrag\(owner) unterschreibt, muss die Anleitung selbst liefern."
            }
            return "Hier steht nur der Name des Rezepts „\(name)“ – ohne Anleitung (abstract). \(ingredients) und \(result). Jede Kind-Klasse, die\(owner) erweitert (extends), muss die fehlende Anleitung selbst liefern."
        }

        var text = "Hier beginnt die Methode „\(name)“ – ein Rezept mit Namen. \(ingredients) und \(result)."
        if modifiers.contains("static") { text += " static: Das Rezept gehört zur Kuchenform selbst – man braucht kein Objekt, um es zu benutzen." }
        if modifiers.contains("public") && !modifiers.contains("static") { text += " public: Jeder darf dieses Rezept benutzen." }
        if !generic.isEmpty {
            text += " \(generic) ist ein Platzhalter-Etikett: T steht für einen beliebigen Typ, der erst beim Benutzen feststeht."
            if generic.contains("extends") { text += " „extends Comparable<T>“ verlangt: Werte vom Typ T müssen sich vergleichen lassen (mit compareTo)." }
        }
        if !g[6].isEmpty { text += " \(g[6].trimmed): Das Rezept warnt vorab, dass es diesen Alarm auslösen kann." }

        if tail == "{" {
            stack.append(.method(name))
        } else if tail.hasPrefix("{"), tail.hasSuffix("}") {
            let body = String(tail.dropFirst().dropLast()).trimmed
            var inner = Context()
            inner.stack = [.method(name)]
            if body.hasPrefix("return ") {
                let expr = String(body.dropFirst(7)).trimmingCharacters(in: CharacterSet(charactersIn: " ;"))
                text += " Die ganze Anleitung steht gleich dahinter: Sie gibt \(Syntax.value(expr)) zurück."
            } else {
                let (bodyText, _) = inner.describe(body)
                text += " Die ganze Anleitung steht gleich dahinter: \(bodyText)"
            }
        }
        return text
    }

    // MARK: Kontrollstrukturen

    mutating func controlStructure(_ s: String) -> String? {
        if s.hasPrefix("if ") || s.hasPrefix("if(") {
            guard let (cond, rest) = Syntax.parenthesized(after: "if", in: s) else { return nil }
            if rest == "{" {
                stack.append(.ifBlock)
                return "Hier stellt das Programm eine Frage: Stimmt „\(cond)“\(Syntax.idiomHint(cond))? Nur bei „ja“ (true) werden die Zeilen im folgenden Block ausgeführt – sonst springt das Programm darüber hinweg.\(Syntax.patternNote(cond))"
            }
            let (inner, _) = describe(rest)
            return "Frage: Stimmt „\(cond)“\(Syntax.idiomHint(cond))? Wenn ja: \(inner)"
        }

        if s.hasPrefix("for ") || s.hasPrefix("for(") {
            guard let (inside, rest) = Syntax.parenthesized(after: "for", in: s) else { return nil }
            var text: String
            if !inside.contains(";"), let colon = inside.range(of: " : ") {
                let declaration = inside[..<colon.lowerBound].split(separator: " ").map(String.init)
                let variable = declaration.last ?? "x"
                if declaration.count >= 2 { boxTypes[variable] = declaration.dropLast().joined(separator: " ") }
                var collection = String(inside[colon.upperBound...])
                if let g = Syntax.groups(Syntax.rx(#"^List\.of\((.*)\)$"#), collection) {
                    collection = "der Liste " + Syntax.list(Syntax.splitArguments(g[1]).map(Syntax.shortValue))
                    text = "Eine Schleife, die jedes Element aus \(collection) der Reihe nach durchgeht – wie beim Durchblättern eines Kartenstapels. In jeder Runde liegt das aktuelle Element in der Box „\(variable)“."
                    if rest == "{" { stack.append(.loop) }
                    return text
                }
                text = "Eine Schleife, die jedes Element aus „\(collection)“ der Reihe nach durchgeht – wie beim Durchblättern eines Kartenstapels. In jeder Runde liegt das aktuelle Element in der Box „\(variable)“."
            } else {
                let parts = inside.components(separatedBy: ";").map { $0.trimmed }
                let start = parts.first ?? ""
                let condition = parts.count > 1 ? parts[1] : ""
                let step = parts.count > 2 ? parts[2] : ""
                let startGroups = Syntax.groups(Syntax.counterStart, start)
                let counter = startGroups?[1] ?? "i"
                let startValue = startGroups?[2] ?? start
                text = "Eine Schleife: Das Programm wiederholt die Zeilen im Block mehrmals. Der Zähler „\(counter)“ startet bei \(startValue). Vor jeder Runde fragt das Programm „\(condition)?“ – nur bei „ja“ gibt es eine weitere Runde. Nach jeder Runde \(Syntax.stepPhrase(step))."
            }
            if rest == "{" {
                stack.append(.loop)
            } else if !rest.isEmpty {
                let (inner, _) = describe(rest)
                text += " In jeder Runde: \(inner)"
            }
            return text
        }

        if s.hasPrefix("while ") || s.hasPrefix("while(") {
            guard let (cond, rest) = Syntax.parenthesized(after: "while", in: s) else { return nil }
            if rest == "{" { stack.append(.loop) }
            return "Eine Schleife: Solange die Frage „\(cond)?“ mit „ja“ beantwortet wird, wiederholt das Programm die Zeilen im Block. Ist die Antwort schon am Anfang „nein“, läuft der Block gar nicht."
        }

        if s == "do {" {
            stack.append(.doLoop)
            return "Beginnt eine do-while-Schleife: „Mach erst einmal – und frag danach, ob du es wiederholen sollst.“ Der Block läuft also mindestens einmal."
        }

        if s.hasPrefix("switch ") || s.hasPrefix("switch(") {
            guard let (value, rest) = Syntax.parenthesized(after: "switch", in: s), rest == "{" else { return nil }
            stack.append(.switchStatement)
            return "Ein Weichensteller (switch): Je nach Wert von „\(value)“ fährt das Programm in einen der folgenden Fälle (case)."
        }

        if s.hasPrefix("case ") || s.hasPrefix("default ") || s.hasPrefix("default->") {
            let isDefault = s.hasPrefix("default")
            guard let arrow = s.range(of: "->") else { return nil }
            let labels = isDefault ? "" : String(s[s.index(s.startIndex, offsetBy: 5)..<arrow.lowerBound]).trimmed
            let body = String(s[arrow.upperBound...]).trimmed
            var intro: String
            var pattern = labels
            var guardCondition = ""
            if let when = labels.range(of: " when ") {
                pattern = String(labels[..<when.lowerBound]).trimmed
                guardCondition = String(labels[when.upperBound...]).trimmed
            }
            let extra = guardCondition.isEmpty ? "" : " und stimmt zusätzlich „\(guardCondition)“ (when)"
            if isDefault {
                intro = "Bei allen anderen Werten"
            } else if let g = Syntax.groups(Syntax.typePattern, pattern) {
                intro = "Ist der Wert ein \(g[1]) (er bekommt das Namensschild „\(g[2])“)\(extra),"
            } else if let g = Syntax.groups(Syntax.rx(#"^([A-Z]\w*)\((.*)\)$"#), pattern) {
                let names = Syntax.parameters(g[2]).map(\.name)
                intro = "Ist der Wert ein \(g[1]) – seine Zutaten landen gleich in den Boxen \(Syntax.list(names)) (Record-Muster) –\(extra),"
                if extra.isEmpty { intro = "Ist der Wert ein \(g[1]) – seine Zutaten landen gleich in den Boxen \(Syntax.list(names)) (Record-Muster) –" }
            } else {
                let values = Syntax.splitArguments(labels).map(Syntax.shortValue)
                intro = "Ist der Wert \(Syntax.list(values, conjunction: "oder")),"
            }
            let lead = intro
            if body == "{" {
                stack.append(.caseBlock)
                return "\(lead) läuft der folgende Block."
            }
            if stack.last == .switchExpression {
                return "\(lead) liefert der Weichensteller \(Syntax.value(String(body.dropLast()).trimmed))."
            }
            let (inner, _) = describe(body)
            return "\(lead) passiert Folgendes: \(inner)"
        }

        if s.hasPrefix("try ("), s.hasSuffix("{"), let (resource, _) = Syntax.parenthesized(after: "try", in: s),
           let g = Syntax.groups(Syntax.variableDecl, resource), !g[5].isEmpty {
            stack.append(.tryBlock)
            boxTypes[g[3]] = g[2]
            let value = g[5].trimmed
            return "Versuch mit Ressource (try-with-resources): Hier legen wir die Box „\(g[3])“ an und legen \(Syntax.value(value)) hinein. Am Ende des Blocks wird sie automatisch geschlossen und aufgeräumt – wie eine Tür, die von selbst zufällt. \(Syntax.labelPhrase(g[2], value: value))"
        }
        if s == "try {" {
            stack.append(.tryBlock)
            return "Beginnt einen Versuch mit Sicherheitsnetz (try): Geht in diesem Block etwas schief – Java nennt das eine Exception, also einen Alarm –, stürzt das Programm nicht ab. Stattdessen fängt das passende catch den Alarm auf."
        }

        if s.hasPrefix("return") && (s.count == 6 || s.dropFirst(6).first == " " || s.dropFirst(6).first == ";") {
            let expr = String(s.dropFirst(6)).trimmed
            if expr.hasPrefix("switch"), let (value, rest) = Syntax.parenthesized(after: "switch", in: expr), rest == "{" {
                stack.append(.switchExpression)
                return "Das Rezept gibt zurück, was der folgende Weichensteller (switch) je nach „\(value)“ auswählt."
            }
            let value = expr.hasSuffix(";") ? String(expr.dropLast()).trimmed : expr
            if value.isEmpty { return "Beendet das Rezept (die Methode) sofort – ohne Ergebnis." }
            return "Das Rezept ist fertig: Es gibt \(phrase(value)) zurück an die Stelle, die es aufgerufen hat – wie ein Automat, der sein Produkt ausgibt."
        }

        if let g = Syntax.groups(Syntax.throwNew, s) {
            let args = Syntax.splitArguments(g[2])
            let message = args.first.map { " mit der Meldung \(Syntax.shortValue($0))" } ?? ""
            return "Löst absichtlich einen Alarm aus: eine \(g[1])\(message). Das Rezept bricht hier sofort ab, und der Alarm wandert zu dem, der es aufgerufen hat."
        }

        switch s {
        case "break;": return "Mit break geht es sofort raus aus der Schleife – auch wenn noch Runden übrig wären."
        case "continue;": return "Mit continue wird diese Runde hier abgebrochen; die Schleife macht direkt mit der nächsten Runde weiter."
        default: break
        }
        if s.hasPrefix("yield ") {
            return "yield: Gibt \(Syntax.value(String(s.dropFirst(6).dropLast()).trimmed)) als Ergebnis dieses Falls an den Weichensteller zurück."
        }
        return nil
    }

    // MARK: Ausgabe

    func printStatement(_ s: String) -> String? {
        guard let g = Syntax.groups(Syntax.printCall, s) else { return nil }
        let arg = g[2].trimmed
        if let chain = Syntax.chainSteps(arg) {
            let ending = g[1] == "println" ? " Danach springt die Ausgabe in eine neue Zeile." : ""
            return "Schreibt das Ergebnis einer Kette von Schritten auf den Bildschirm: \(chain).\(ending)"
        }
        if g[1] == "println" {
            if arg.isEmpty { return "Schreibt eine leere Zeile auf den Bildschirm." }
            return "Schreibt \(phrase(arg)) auf den Bildschirm (in die Konsole) und springt danach in eine neue Zeile – wie ein Druck auf die Enter-Taste."
        }
        return "Schreibt \(phrase(arg)) auf den Bildschirm – aber ohne neue Zeile: Die nächste Ausgabe kommt direkt dahinter."
    }

    // MARK: Variablen und Felder

    mutating func declaration(_ s: String) -> String? {
        guard let g = Syntax.groups(Syntax.variableDecl, s) else { return nil }
        let modifiers = g[1], type = g[2], name = g[3]
        guard !Syntax.statementKeywords.contains(type), !type.isEmpty else { return nil }
        let hasInitializer = !g[4].isEmpty
        let rhs = g[5].trimmed
        let label = Syntax.labelPhrase(type, value: rhs, container: inTypeBody ? "dieses Fach" : "diese Box")
        var text: String

        boxTypes[name] = type
        if inTypeBody && modifiers.contains("static") && modifiers.contains("final") {
            text = "Hier legen wir die Konstante „\(name)“ an. Es gibt sie nur ein einziges Mal – sie gehört der Kuchenform selbst (static) –, und ihr Inhalt ist fest: \(phrase(rhs)) (final: nie mehr änderbar). Konstanten schreibt man üblicherweise GROSS. \(label)"
            if modifiers.contains("private") { text += " private: Nur die Klasse selbst darf sie benutzen." }
            return text
        } else if inTypeBody && modifiers.contains("static") {
            text = "Hier legen wir ein gemeinsames Fach „\(name)“ an. Anders als normale Fächer gibt es dieses nur ein einziges Mal: Es gehört der Kuchenform selbst (static), und alle Objekte teilen es sich"
            text += hasInitializer ? ". Zu Beginn liegt \(phrase(rhs)) darin." : "."
            text += " \(label)"
        } else if inTypeBody {
            text = "Jedes Objekt, das aus dieser Kuchenform gebacken wird, bekommt ein eigenes Fach namens „\(name)“"
            text += hasInitializer ? " und darin zu Beginn \(phrase(rhs))." : "."
            text += " \(label)"
            if modifiers.contains("private") { text += " private: Nur die Klasse selbst darf in dieses Fach schauen – von außen ist es verschlossen." }
            if modifiers.contains("protected") { text += " protected: Auch Kind-Formen (Unterklassen) dürfen hineinschauen." }
        } else if !hasInitializer {
            text = "Hier erstellen wir eine leere Box namens „\(name)“. Einen Inhalt bekommt sie erst später. \(label)"
        } else if rhs.hasPrefix("switch"), let (value, rest) = Syntax.parenthesized(after: "switch", in: rhs), rest == "{" {
            stack.append(.switchExpression)
            text = "Hier erstellen wir eine Box namens „\(name)“. Was hineinkommt, entscheidet der folgende Weichensteller (switch) anhand von „\(value)“. \(label)"
        } else if !s.hasSuffix(";"), rhs.hasSuffix(".stream()") {
            chainTarget = name
            let source = String(rhs.dropLast(".stream()".count))
            text = "Hier erstellen wir eine Box namens „\(name)“. Hineinkommen soll das Ergebnis eines Fließbands (Stream): \(source).stream() legt alle Elemente von „\(source)“ aufs Band, die nächsten Zeilen sind die Stationen. \(label)"
        } else if let g = Syntax.groups(Syntax.newArray, rhs) {
            text = "Hier erstellen wir einen Eierkarton namens „\(name)“ mit \(g[2]) nummerierten Fächern für \(Syntax.plural(g[1])). Am Anfang liegt in jedem Fach der Startwert – bei Zahlen eine 0."
        } else if rhs.hasPrefix("new ") && !rhs.contains(").") {
            let (sentence, pronoun) = Syntax.newSentence(rhs)
            text = "\(sentence) und legen \(pronoun) in die Box „\(name)“. \(label)"
            text += Syntax.polymorphismNote(declared: type, created: rhs)
        } else if rhs.hasPrefix("{") {
            let items = Syntax.splitArguments(String(rhs.dropFirst().dropLast())).map(Syntax.itemPhrase)
            text = "Hier erstellen wir einen Eierkarton namens „\(name)“ mit \(items.count) nummerierten Fächern und legen \(Syntax.list(items)) hinein. Die Fächer sind ab 0 nummeriert: In Fach 0 liegt \(items.first ?? "")."
        } else if rhs.hasSuffix("{"), let lambda = Syntax.lambdaParts(rhs), lambda.1.trimmingCharacters(in: .whitespaces) == "{" {
            stack.append(.lambda)
            let inputs = Syntax.splitArguments(lambda.0.trimmingCharacters(in: CharacterSet(charactersIn: "() ")))
            let takes = inputs.isEmpty ? "Sie braucht keine Zutaten" : "Sie nimmt \(Syntax.list(inputs))"
            text = "Hier erstellen wir eine Box namens „\(name)“ und legen eine Mini-Anweisung ohne Namen hinein (ein Lambda). \(takes); was sie tun soll, steht im folgenden Block. Ausgeführt wird er erst, wenn jemand die Mini-Anweisung laufen lässt. \(label)"
        } else if let lambda = Syntax.lambdaParts(rhs), rhs.contains("->") {
            text = "Hier erstellen wir eine Box namens „\(name)“ und legen eine Mini-Anweisung ohne Namen hinein (ein Lambda): Sie nimmt \(Syntax.list(Syntax.splitArguments(lambda.0.trimmingCharacters(in: CharacterSet(charactersIn: "()"))))) und liefert \(lambda.1). \(label)"
        } else if let chain = Syntax.chainSteps(rhs) {
            text = "Hier erstellen wir eine Box namens „\(name)“. Hinein kommt das Ergebnis einer Kette von Schritten: \(chain). \(label)"
        } else if enumTypes.contains(type) {
            text = "Hier erstellen wir eine Box namens „\(name)“ und legen \(phrase(rhs)) hinein. Das Etikett \(type) heißt: In diese Box passt nur einer der festen \(type)-Werte."
        } else {
            text = "Hier erstellen wir eine Box namens „\(name)“ und legen \(phrase(rhs)) hinein. \(label)"
        }
        if modifiers.contains("final") { text += " final heißt: Die Box wird danach versiegelt – der Inhalt kann sich nie mehr ändern." }
        return text
    }

    func assignment(_ s: String) -> String? {
        if let g = Syntax.groups(Syntax.increment, s) {
            return g[2] == "++"
                ? "Zählt die Box „\(g[1])“ um 1 hoch – wie ein Klick auf einen Handzähler. (Kurzform für \(g[1]) = \(g[1]) + 1.)"
                : "Zählt die Box „\(g[1])“ um 1 herunter. (Kurzform für \(g[1]) = \(g[1]) - 1.)"
        }
        if let g = Syntax.groups(Syntax.compound, s) {
            let target = g[1], op = g[2], amount = g[3].trimmed
            switch op {
            case "+=" where amount.contains("("):
                return "Legt \(phrase(amount)) zum Inhalt der Box „\(target)“ dazu. (Kurzform für \(target) = \(target) + \(amount).)"
            case "+=": return "Legt \(amount) zum Inhalt der Box „\(target)“ dazu – sie wird um \(amount) größer. (Kurzform für \(target) = \(target) + \(amount).)"
            case "-=": return "Nimmt \(amount) vom Inhalt der Box „\(target)“ weg. (Kurzform für \(target) = \(target) - \(amount).)"
            case "*=": return "Nimmt den Inhalt der Box „\(target)“ mal \(amount) und legt das Ergebnis zurück. (Kurzform für \(target) = \(target) * \(amount).)"
            case "/=": return "Teilt den Inhalt der Box „\(target)“ durch \(amount) und legt das Ergebnis zurück."
            default: return "Rechnet \(target) \(op.dropLast()) \(amount) und legt das Ergebnis zurück in die Box „\(target)“."
            }
        }
        guard let g = Syntax.groups(Syntax.assignment, s) else { return nil }
        let target = g[1], rhs = g[2].trimmed
        if let field = Syntax.groups(Syntax.thisField, target)?[1] {
            if rhs == field {
                return "Legt die mitgegebene Zutat „\(field)“ in das Fach „\(field)“ genau dieses Objekts. this.\(field) meint das Fach („dieser Kuchen hier“), \(field) allein die mitgegebene Zutat."
            }
            let what = Syntax.groups(Syntax.identifier, rhs) != nil ? "die mitgegebene Zutat „\(rhs)“" : Syntax.value(rhs)
            return "Legt \(what) in das Fach „\(field)“ dieses Objekts (this = „dieser Kuchen hier“)."
        }
        if let element = Syntax.groups(Syntax.arrayElement, target) {
            return "Legt \(Syntax.value(rhs)) in Fach Nummer \(element[2]) des Eierkartons „\(element[1])“ – gezählt wird ab 0."
        }
        if target.contains(".") {
            let parts = target.split(separator: ".")
            return "Legt \(Syntax.value(rhs)) in das Fach „\(parts.last ?? "")“ des Objekts „\(parts.first ?? "")“."
        }
        if rhs.range(of: #"\b\#(target)\b"#, options: .regularExpression) != nil, !rhs.contains(").") {
            return "Rechnet \(rhs) aus und legt das Ergebnis zurück in die Box „\(target)“ – der alte Inhalt wird ersetzt."
        }
        return "Wir nehmen den alten Inhalt aus der Box „\(target)“ heraus und legen stattdessen \(phrase(rhs)) hinein."
    }

    // MARK: Streams und Methodenaufrufe

    mutating func streamStep(_ s: String) -> String? {
        guard s.hasPrefix(".") else { return nil }
        let ends = s.hasSuffix(";")
        let call = ends ? String(s.dropFirst().dropLast()) : String(s.dropFirst())
        guard let (name, args) = Syntax.callParts(call) else { return nil }
        var text = Syntax.stationSentence(name: name, args: args)
        if ends {
            text += chainTarget.map { " Damit ist das Fließband fertig – das Ergebnis kommt in die Box „\($0)“." } ?? " Damit ist das Fließband fertig."
            chainTarget = nil
        }
        return text
    }

    func callStatement(_ s: String) -> String? {
        guard s.hasSuffix(";") else { return nil }
        let expression = String(s.dropLast()).trimmed
        guard let call = Syntax.topLevelCall(expression) else { return nil }
        let name = call.method, args = call.arguments
        let argumentList = Syntax.splitArguments(args)

        guard let receiver = call.receiver else {
            if name == "assertEquals", argumentList.count == 2 {
                return "Prüft (assertEquals): Erwartet wird \(Syntax.shortValue(argumentList[0])), tatsächlich herausgekommen ist \(Syntax.value(argumentList[1])). Stimmen die beiden nicht überein, schlägt der Test fehl – die Entwicklungsumgebung zeigt dann Rot."
            }
            let with = argumentList.isEmpty ? "ohne Zutaten" : "und gibt ihm \(Syntax.list(argumentList.map(Syntax.shortValue))) als Zutat mit"
            return "Ruft das Rezept (die Methode) „\(name)“ auf \(with). Jetzt läuft der Code, der darin steht."
        }

        // Verkettete Aufrufe wie sb.append(a).append(b)
        let chained = Syntax.chainedCalls(expression)
        if chained.calls.count >= 2, chained.calls.allSatisfy({ $0.0 == "append" }) {
            let parts = chained.calls.map { Syntax.shortValue($0.1) }
            return "Hängt nacheinander \(Syntax.list(parts)) an den Notizblock „\(chained.base)“ an. Das klappt in einer Zeile, weil jedes append den Notizblock gleich wieder zurückgibt."
        }
        let type = baseType(receiver) ?? ""
        let argPhrase = Syntax.argumentPhrase(args)
        switch name {
        case "add" where ["Set", "HashSet", "TreeSet"].contains(type):
            return "Legt \(argPhrase) ins Set „\(receiver)“. Steht es schon drin, passiert nichts – jeder Eintrag kommt nur einmal vor."
        case "add":
            return "Schreibt \(argPhrase) ans Ende der Liste „\(receiver)“ – wie ein neuer Eintrag auf dem Einkaufszettel."
        case "append":
            return "Hängt \(argPhrase) an den Notizblock „\(receiver)“ an."
        case "reverse":
            return "Dreht die Reihenfolge aller Zeichen im Notizblock „\(receiver)“ um."
        case "push":
            return "Legt \(argPhrase) oben auf den Stapel „\(receiver)“ (push)."
        case "pop":
            return "Nimmt den obersten Eintrag vom Stapel „\(receiver)“ weg (pop)."
        case "offer":
            return "Stellt \(argPhrase) hinten an die Warteschlange „\(receiver)“ an (offer)."
        case "poll":
            return "Holt den vordersten Eintrag aus der Warteschlange „\(receiver)“ (poll)."
        case "start":
            return "Lässt den Thread „\(receiver)“ loslaufen (start). Ab jetzt arbeitet er gleichzeitig mit dem Hauptprogramm."
        case "join":
            return "Wartet (join), bis der Thread „\(receiver)“ fertig ist – erst dann geht es mit der nächsten Zeile weiter."
        case "incrementAndGet":
            return "Zählt den sicheren Zähler „\(receiver)“ um 1 hoch (incrementAndGet). Auch wenn mehrere Threads gleichzeitig zählen, geht kein Schritt verloren."
        case "addAndGet":
            return "Zählt \(argPhrase) zum sicheren Zähler „\(receiver)“ dazu (addAndGet)."
        case "set" where argumentList.count == 2:
            return "Ersetzt in der Liste „\(receiver)“ den Eintrag an Position \(argumentList[0]) (gezählt ab 0) durch \(Syntax.argumentPhrase(argumentList[1]))."
        case "sort" where receiver == "Arrays":
            return "Sortiert den Eierkarton „\(args)“ – danach liegen die Werte aufsteigend in den Fächern (Arrays.sort)."
        case "sort":
            return "Sortiert die Liste „\(receiver)“ \(Syntax.comparatorPhrase(args))."
        case "writeString" where receiver == "Files" && argumentList.count == 2:
            return "Schreibt \(Syntax.value(argumentList[1])) in die Datei „\(argumentList[0])“ (Files.writeString). Was vorher darin stand, wird ersetzt."
        case "delete" where receiver == "Files":
            return "Löscht die Datei „\(args)“ wieder (Files.delete)."
        case "put" where argumentList.count == 2:
            return "Trägt ins Wörterbuch „\(receiver)“ ein: \(Syntax.shortValue(argumentList[0])) → \(Syntax.shortValue(argumentList[1])). Stand \(Syntax.shortValue(argumentList[0])) schon drin, wird der alte Eintrag überschrieben."
        case "remove":
            return "Streicht \(Syntax.shortValue(args)) aus „\(receiver)“ – alles dahinter rückt nach vorn."
        case "forEach":
            if let g = Syntax.groups(Syntax.lambda, args), args.contains("->") {
                var inner = Context()
                let (body, _) = inner.describe(g[2].hasSuffix(";") ? g[2] : g[2] + ";")
                return "Geht jedes Element von „\(receiver)“ der Reihe nach durch – jeweils unter dem Namen „\(g[1])“ – und macht damit Folgendes: \(body)"
            }
            return "Macht für jedes Element von „\(receiver)“: \(args)."
        default:
            if let result = JavaGlossary.resultPhrase(forMethod: name) {
                return "Fragt \(expression) ab – das liefert \(result). Das Ergebnis wird hier nur gezeigt, nicht in einer Box gespeichert."
            }
            let with = argumentList.isEmpty ? "" : " und gibt \(Syntax.list(argumentList.map(Syntax.shortValue))) als Zutat mit"
            if receiver.first?.isUppercase == true {
                return "Ruft das Rezept „\(name)“ der Klasse \(receiver) auf\(with)."
            }
            return "Bittet das Objekt „\(receiver)“, seine Methode \(name)() auszuführen\(with). Dann läuft der Code, der in der Kuchenform für \(name)() steht – für genau dieses Objekt."
        }
    }
}

// MARK: - Syntax-Helfer

private enum Syntax {
    static let statementKeywords: Set<String> = ["return", "new", "else", "throw", "case", "yield", "default", "import", "package"]

    static func rx(_ pattern: String) -> NSRegularExpression {
        // Muster sind konstant – ein Tippfehler fällt sofort in den Tests auf.
        try! NSRegularExpression(pattern: pattern)
    }

    static let generics = #"(?:<(?:[^<>]|<[^<>]*>)*>)"#
    static let typeDecl = rx(#"^((?:(?:public|private|protected|abstract|final|sealed|non-sealed|static)\s+)*)(class|interface|record|enum)\s+(\w+)(\#(generics)?)(\([^)]*\))?(?:\s+extends\s+([\w<>, ]+?))?(?:\s+implements\s+([\w<>, ]+?))?(?:\s+permits\s+([\w, ]+?))?\s*(\{.*)?$"#)
    static let constructorDecl = rx(#"^((?:public|private|protected)\s+)?([A-Z]\w*)\s*\(([^)]*)\)\s*\{$"#)
    static let methodDecl = rx(#"^((?:(?:public|private|protected|static|final|abstract)\s+)*)(\#(generics)\s+)?([\w.]+\#(generics)?(?:\[\])*)\s+(\w+)\s*\(([^)]*)\)\s*(throws\s+[\w, ]+)?\s*(\{.*|;)$"#)
    static let variableDecl = rx(#"^((?:(?:final|private|public|protected|static)\s+)*)([A-Za-z_][\w.]*\#(generics)?(?:\[\])*)\s+([a-zA-Z_]\w*)\s*(=\s*(.*?))?\s*;?$"#)
    static let printCall = rx(#"^System\.out\.(println|print)\((.*)\);$"#)
    static let superCall = rx(#"^super\((.*)\);$"#)
    static let throwNew = rx(#"^throw\s+new\s+(\w+)\((.*)\);$"#)
    static let increment = rx(#"^([\w.\[\]]+)(\+\+|--);$"#)
    static let compound = rx(#"^([\w.\[\]]+)\s*(\+=|-=|\*=|/=|%=)\s*(.+);$"#)
    static let assignment = rx(#"^([\w.\[\]]+)\s*=(?!=)\s*(.+);$"#)
    static let thisField = rx(#"^this\.(\w+)$"#)
    static let arrayElement = rx(#"^(\w+)\[(.+)\]$"#)
    static let lambda = rx(#"^\(?\s*([\w, ]*?)\s*\)?\s*->\s*(.+)$"#)
    static let typePattern = rx(#"^([A-Z]\w*)\s+(\w+)$"#)
    static let instanceofPattern = rx(#"(\w+)\s+instanceof\s+([A-Z]\w*)\s+(\w+)"#)
    static let identifier = rx(#"^[A-Za-z_]\w*$"#)
    static let arrayLength = rx(#"^(\w+)\.length$"#)
    static let counterStart = rx(#"^(?:int|long|var)?\s*(\w+)\s*=\s*(.+)$"#)
    static let newArray = rx(#"^new\s+(\w+)\[(.+)\]$"#)
    static let newObject = rx(#"^new\s+(\w+)(<[^>]*>)?\((.*)\)$"#)
    static let newName = rx(#"^new\s+(\w+)"#)
    static let methodReference = rx(#"^[\w.]+::\w+$"#)

    static func groups(_ regex: NSRegularExpression, _ text: String) -> [String]? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let r = match.range(at: index)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return "" }
            return String(text[swiftRange])
        }
    }

    /// Inhalt der Klammer nach einem Schlüsselwort und der Rest der Zeile.
    static func parenthesized(after keyword: String, in s: String) -> (inside: String, rest: String)? {
        guard let open = s.firstIndex(of: "("), String(s[..<open]).trimmed == keyword else { return nil }
        var depth = 0
        var inString = false
        var index = open
        while index < s.endIndex {
            let c = s[index]
            if c == "\"" { inString.toggle() }
            if !inString {
                if c == "(" { depth += 1 }
                if c == ")" {
                    depth -= 1
                    if depth == 0 {
                        let inside = String(s[s.index(after: open)..<index]).trimmed
                        let rest = String(s[s.index(after: index)...]).trimmed
                        return (inside, rest)
                    }
                }
            }
            index = s.index(after: index)
        }
        return nil
    }

    static func splitArguments(_ s: String) -> [String] {
        split(s, separator: ",")
    }

    /// Teilt an einem Zeichen der obersten Ebene (nicht in Klammern oder Strings).
    static func split(_ s: String, separator: Character, requireSpaces: Bool = false) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inString = false
        var inChar = false
        let chars = Array(s)
        for (i, c) in chars.enumerated() {
            if c == "\"" && !inChar { inString.toggle() }
            if c == "'" && !inString { inChar.toggle() }
            if !inString && !inChar {
                if "([{<".contains(c) && !(c == "<" && requireSpaces) { depth += 1 }
                if ")]}>".contains(c) && !(c == ">" && requireSpaces) && !(c == ">" && i > 0 && chars[i - 1] == "-") { depth -= 1 }
                let spaced = !requireSpaces || (i > 0 && i + 1 < chars.count && chars[i - 1] == " " && chars[i + 1] == " ")
                if c == separator && depth == 0 && spaced {
                    parts.append(current.trimmed)
                    current = ""
                    continue
                }
            }
            current.append(c)
        }
        if !current.trimmed.isEmpty { parts.append(current.trimmed) }
        return parts
    }

    static func parameters(_ s: String) -> [(type: String, name: String)] {
        splitArguments(s).compactMap { parameter in
            let trimmed = parameter.trimmed
            guard let space = trimmed.lastIndex(of: " ") else { return nil }
            return (String(trimmed[..<space]).trimmed, String(trimmed[trimmed.index(after: space)...]))
        }
    }

    static func list(_ items: [String], conjunction: String = "und") -> String {
        switch items.count {
        case 0: return "nichts"
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " \(conjunction) " + items[items.count - 1]
        }
    }

    /// „eine ganze Zahl“, „einen Text“ … (für Zutaten und Rückgaben).
    static func typeAccusative(_ type: String) -> String {
        switch type {
        case "int": return "eine ganze Zahl"
        case "long": return "eine große ganze Zahl"
        case "double", "float": return "eine Kommazahl"
        case "boolean": return "einen Ja/Nein-Wert (true oder false)"
        case "char": return "ein einzelnes Zeichen"
        case "String": return "einen Text"
        case "Object": return "ein beliebiges Objekt"
        case "T": return "einen Wert vom Platzhalter-Typ T"
        case "String[]": return "eine Reihe von Texten"
        default:
            if type.hasPrefix("List<") { return "eine Liste" }
            if type.hasSuffix("[]") { return "einen Eierkarton (Array)" }
            return "ein Objekt vom Typ \(type)"
        }
    }


    /// Zerlegt „bedingung ? a : b“ auf oberster Ebene (nicht in Texten oder Klammern).
    static func ternaryParts(_ e: String) -> (String, String, String)? {
        let chars = Array(e)
        var depth = 0, inString = false, question: Int?, colon: Int?
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\" { i += 2; continue }
                if c == "\"" { inString = false }
            } else if c == "\"" {
                inString = true
            } else if "([{".contains(c) {
                depth += 1
            } else if ")]}".contains(c) {
                depth -= 1
            } else if depth == 0 && c == "?" && question == nil {
                question = i
            } else if depth == 0 && c == ":" && question != nil && colon == nil {
                colon = i
            }
            i += 1
        }
        guard let q = question, let k = colon, q > 0, k > q + 1 else { return nil }
        let condition = String(chars[..<q]).trimmingCharacters(in: .whitespaces)
        let yes = String(chars[(q + 1)..<k]).trimmingCharacters(in: .whitespaces)
        let no = String(chars[(k + 1)...]).trimmingCharacters(in: .whitespaces)
        return condition.isEmpty || yes.isEmpty || no.isEmpty ? nil : (condition, yes, no)
    }

    /// Argument in Worten: neues Objekt, Aufrufergebnis oder einfacher Wert.
    static func argumentPhrase(_ a: String) -> String {
        let t = a.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("new "), !t.contains(")."), groups(newObject, t) != nil { return newObjectPhrase(t) }
        if isStringLiteral(t) || Int(t) != nil || groups(identifier, t) != nil { return shortValue(t) }
        if t.hasSuffix(")") { return value(t) }
        return shortValue(t)
    }

    /// Sortierregel in Worten („nach der Länge, absteigend“).
    static func comparatorPhrase(_ c: String) -> String {
        var text = c.trimmingCharacters(in: .whitespaces)
        var descending = false
        if text.hasSuffix(".reversed()") { descending = true; text = String(text.dropLast(".reversed()".count)) }
        var rule = "nach der Regel \(text)"
        if let g = groups(rx(#"^Comparator\.comparing\((.+)\)$"#), text) {
            rule = g[1] == "String::length" ? "nach der Länge der Texte" : "nach \(g[1])"
        }
        return rule + (descending ? ", absteigend – das Größte zuerst (reversed)" : ", aufsteigend")
    }

    /// Basis und Aufrufe einer Kette wie sb.append(a).append(b).
    static func chainedCalls(_ e: String) -> (base: String, calls: [(String, String)]) {
        var calls: [(String, String)] = []
        var rest = e
        while let call = topLevelCall(rest), let receiver = call.receiver {
            calls.insert((call.method, call.arguments), at: 0)
            rest = receiver
        }
        return (rest, calls)
    }

    /// Erklärt das „Etikett“ (den Typ) einer Box oder eines Fachs.
    static func labelPhrase(_ type: String, value: String, container: String = "diese Box") -> String {
        switch type {
        case "int": return "Das Etikett int heißt: In \(container) passen nur ganze Zahlen."
        case "long": return "Das Etikett long heißt: In \(container) passen ganze Zahlen – auch sehr große."
        case "double", "float": return "Das Etikett \(type) heißt: In \(container) passen Kommazahlen (mit Punkt geschrieben, z. B. 9.99)."
        case "boolean": return "Das Etikett boolean heißt: In \(container) passt nur „wahr“ (true) oder „falsch“ (false)."
        case "char": return "Das Etikett char heißt: In \(container) passt genau ein einzelnes Zeichen."
        case "String": return "Das Etikett String heißt: In \(container) passen Texte."
        case "var": return "var heißt: Java schaut sich den Inhalt an und klebt das passende Etikett selbst drauf – hier \(inferType(value))."
        case "T": return "T ist ein Platzhalter-Etikett: Es steht für den Typ, mit dem die Methode gerade benutzt wird."
        case "Object": return "Das Etikett Object passt für jedes beliebige Objekt."
        default:
            if type.hasSuffix("[]") {
                return "Das Etikett \(type) heißt: Es ist ein Eierkarton mit nummerierten Fächern für \(plural(String(type.dropLast(2))))."
            }
            if type.hasPrefix("List<") {
                return "Das Etikett \(type) heißt: Darin liegt eine Liste, und auf ihr dürfen nur \(genericPlural(type)) stehen."
            }
            if type.hasPrefix("Map<") {
                return "Das Etikett \(type) heißt: Darin liegt ein Wörterbuch – zu jedem Schlüssel gehört ein Wert."
            }
            if type.hasPrefix("Set<") {
                return "Das Etikett \(type) heißt: Darin liegt eine Menge (Set) – jeder Eintrag kommt höchstens einmal vor."
            }
            if type.hasPrefix("Deque<") {
                return "Das Etikett \(type) heißt: Darin liegt eine Reihe, an der man vorne und hinten anbauen kann – als Stapel oder Warteschlange."
            }
            if type.hasPrefix("Queue<") {
                return "Das Etikett \(type) heißt: Darin liegt eine Warteschlange – wer zuerst kommt, ist zuerst dran."
            }
            if type.hasPrefix("Future<") {
                return "Das Etikett \(type) heißt: Darin liegt ein Abholschein für ein Ergebnis, das erst später fertig wird."
            }
            if let meaning = ["ExecutorService": "ein Team von Threads, das eingereichte Aufgaben abarbeitet",
                              "Runnable": "eine Aufgabe, die man laufen lassen kann – ohne Zutaten und ohne Ergebnis",
                              "Thread": "ein eigener Arbeitsstrang, der gleichzeitig mit dem Hauptprogramm arbeiten kann",
                              "AtomicInteger": "ein Zähler, der auch dann richtig zählt, wenn mehrere Threads gleichzeitig daran drehen",
                              "StringBuilder": "ein Notizblock für Text, auf dem man immer weiterschreiben kann",
                              "Scanner": "ein Lesegerät, das Text Stück für Stück liest",
                              "LocalDate": "ein Kalenderdatum (ohne Uhrzeit)",
                              "Period": "ein Zeitabstand in Jahren, Monaten und Tagen",
                              "DateTimeFormatter": "eine Formatvorlage, die bestimmt, wie ein Datum als Text aussieht",
                              "Path": "die Adresse einer Datei"][type] {
                return "Das Etikett \(type) heißt: Darin liegt \(meaning)."
            }
            if type.hasPrefix("Optional<") {
                return "Das Etikett \(type) heißt: Darin liegt eine Schachtel (Optional), die etwas enthalten kann – oder leer ist."
            }
            if type.hasPrefix("Comparator") || type.hasPrefix("Function") {
                return "Das Etikett \(type) heißt: Darin liegt eine kleine Funktion, die man später benutzen kann."
            }
            return "Das Etikett \(type) heißt: In \(container) passt ein Objekt vom Typ \(type)."
        }
    }

    /// „ganze Zahlen“, „Texte“ … für Eierkartons.
    static func plural(_ type: String) -> String {
        switch type {
        case "int", "long", "Integer": return "ganze Zahlen"
        case "double", "float": return "Kommazahlen"
        case "boolean": return "Ja/Nein-Werte"
        case "char": return "Zeichen"
        case "String": return "Texte"
        default: return "\(type)-Objekte"
        }
    }

    /// Einträge in einem Array-Literal in Worten.
    static func itemPhrase(_ item: String) -> String {
        if let g = groups(newObject, item) { return "ein neues \(g[1])-Objekt" }
        return shortValue(item)
    }

    /// Alltagsübersetzung typischer Bedingungen.
    static func idiomHint(_ condition: String) -> String {
        if let g = groups(rx(#"^(\w+)\s*%\s*2\s*==\s*0$"#), condition) { return " – ist \(g[1]) also gerade" }
        if let g = groups(rx(#"^(\w+)\s*%\s*2\s*!=\s*0$"#), condition) { return " – ist \(g[1]) also ungerade" }
        return ""
    }

    /// Häufige „Fabrik“-Aufrufe in Alltagssprache.
    static func knownFactory(_ e: String) -> String? {
        if let g = groups(rx(#"^LocalDate\.of\((\d+),\s*(\d+),\s*(\d+)\)$"#), e), let m = Int(g[2]), let d = Int(g[3]) {
            return "das Datum \(String(format: "%02d.%02d.", d, m))\(g[1]) (LocalDate.of(Jahr, Monat, Tag))"
        }
        if let g = groups(rx(#"^DateTimeFormatter\.ofPattern\("(.*)"\)$"#), e) {
            return "eine Formatvorlage „\(g[1])“ (dd = Tag, MM = Monat, yyyy = Jahr – jeweils mit führender Null)"
        }
        if let g = groups(rx(#"^Executors\.newFixedThreadPool\((\d+)\)$"#), e) {
            return "ein Team aus \(g[1]) festen Arbeitern (Threads) für eingereichte Aufgaben"
        }
        if e == "Executors.newVirtualThreadPerTaskExecutor()" {
            return "ein Team, das jeder Aufgabe einen eigenen, leichten virtuellen Thread gibt"
        }
        if e == "Map.of()" { return "ein leeres, unveränderliches Wörterbuch" }
        if let g = groups(rx(#"^Map\.of\((.+)\)$"#), e) {
            let parts = splitArguments(g[1])
            if parts.count % 2 == 0 {
                let pairs = stride(from: 0, to: parts.count, by: 2).map { "\(shortValue(parts[$0])) → \(shortValue(parts[$0 + 1]))" }
                return "ein fertiges Wörterbuch mit \(list(pairs)) (Map.of – danach unveränderlich)"
            }
        }
        if groups(rx(#"^Files\.createTempFile\(.*\)$"#), e) != nil { return "die Adresse einer neuen, leeren Übungsdatei" }
        if let g = groups(rx(#"^Files\.readAllLines\((\w+)\)$"#), e) { return "alle Zeilen der Datei „\(g[1])“ – als Liste von Texten" }
        if let g = groups(rx(#"^Period\.between\((\w+),\s*(\w+)\)$"#), e) {
            return "den Abstand zwischen „\(g[1])“ und „\(g[2])“ – in Jahren, Monaten und Tagen"
        }
        if let g = groups(rx(#"^Objects\.hash\((.*)\)$"#), e) { return "eine Kennnummer (Hash-Wert), berechnet aus \(list(splitArguments(g[1])))" }
        if let g = groups(rx(#"^Arrays\.toString\((\w+)\)$"#), e) { return "den Inhalt des Eierkartons „\(g[1])“ als Text (in eckigen Klammern)" }
        if let g = groups(rx(#"^List\.of\((.*)\)$"#), e) {
            return "einen fertigen Einkaufszettel mit \(list(splitArguments(g[1]).map(shortValue))) (List.of – danach unveränderlich)"
        }
        if let g = groups(rx(#"^Optional\.of\((.*)\)$"#), e) { return "eine Schachtel (Optional) mit \(value(g[1]))" }
        if e == "Optional.empty()" { return "eine leere Schachtel (Optional)" }
        if let g = groups(rx(#"^Optional\.ofNullable\((\w+)\)$"#), e) {
            return "eine Schachtel (Optional) mit dem Inhalt von „\(g[1])“ – sie bleibt leer, falls dort null (nichts) steht"
        }
        if let g = groups(rx(#"^Integer\.parseInt\((.*)\)$"#), e) {
            return "die Zahl, die in \(shortValue(g[1])) als Text steht (Integer.parseInt verwandelt Text in eine Zahl)"
        }
        return nil
    }

    static func genericPlural(_ type: String) -> String {
        if let open = type.firstIndex(of: "<"), type.hasSuffix(">") {
            let inner = String(type[type.index(after: open)..<type.index(before: type.endIndex)])
            if inner.hasPrefix("Future<") { return "Abholscheine (\(inner))" }
            if inner.hasPrefix("List<") { return "Listen (\(inner))" }
            if inner.contains("<") { return "Werte vom Typ \(inner)" }
            if !["String", "Integer", "T"].contains(inner) { return "\(inner)-Objekte" }
        }
        if type.contains("<String>") { return "Texte (String)" }
        if type.contains("<Integer>") { return "ganze Zahlen (Integer)" }
        if type.contains("<T>") { return "Werte vom Platzhalter-Typ T" }
        return "Werte vom angegebenen Typ"
    }

    static func inferType(_ rhs: String) -> String {
        if rhs.hasPrefix("\"") { return "String (Text)" }
        if rhs.hasPrefix("'") { return "char (Zeichen)" }
        if rhs == "true" || rhs == "false" { return "boolean" }
        if Int(rhs) != nil { return "int (ganze Zahl)" }
        if Double(rhs) != nil { return "double (Kommazahl)" }
        if let g = groups(newName, rhs) { return g[1] }
        return "der Typ des Werts rechts"
    }

    static func isStringLiteral(_ s: String) -> Bool {
        s.count >= 2 && s.hasPrefix("\"") && s.hasSuffix("\"") && !s.dropFirst().dropLast().contains("\"")
    }

    /// Kurzform für Aufzählungen: Strings als „…“, alles andere als Code.
    static func shortValue(_ s: String) -> String {
        let t = s.trimmed
        if isStringLiteral(t) { return "„\(t.dropFirst().dropLast())“" }
        return t
    }

    /// Teil eines zusammengeklebten Texts, im Dativ („aus … und dem Inhalt der Box „x““).
    static func piecePhrase(_ s: String) -> String {
        let t = s.trimmed
        if isStringLiteral(t) { return "„\(t.dropFirst().dropLast())“" }
        if groups(identifier, t) != nil { return "dem Inhalt der Box „\(t)“" }
        if let g = groups(thisField, t) { return "dem Inhalt des Fachs „\(g[1])“" }
        if let g = groups(arrayLength, t) { return "der Anzahl der Fächer in „\(g[1])“" }
        if let g = groups(rx(#"^([a-z]\w*)\.([a-z]\w*)$"#), t) { return "dem Inhalt des Fachs „\(g[2])“ von „\(g[1])“" }
        if let g = groups(arrayElement, t) { return "dem Inhalt von Fach \(g[2]) in „\(g[1])“" }
        if t.hasPrefix("("), t.hasSuffix(")"), !t.dropFirst().contains("(") { return "dem Ergebnis der Rechnung \(t.dropFirst().dropLast())" }
        if t.hasSuffix(")"), let open = t.firstIndex(of: "("), !t[..<open].contains(" ") {
            return "dem Ergebnis von \(t)"
        }
        return t
    }

    /// Beschreibt einen Ausdruck als Objekt eines Satzes („legt … hinein“, „schreibt … auf den Bildschirm“).
    static func value(_ raw: String) -> String {
        let e = raw.trimmed
        if e.isEmpty { return "nichts" }
        if isStringLiteral(e) { return "den Text „\(e.dropFirst().dropLast())“" }
        if e.hasPrefix("'") && e.hasSuffix("'") && e.count <= 4 { return "das Zeichen \(e)" }
        if Int(e) != nil { return "die Zahl \(e)" }
        if Double(e) != nil { return "die Kommazahl \(e)" }
        if e == "true" { return "den Wert true (wahr)" }
        if e == "false" { return "den Wert false (falsch)" }
        if e == "null" { return "den Wert null („nichts drin“)" }
        if let ternary = ternaryParts(e) {
            return "\(value(ternary.1)) oder \(value(ternary.2)) – je nachdem, ob „\(ternary.0)“ stimmt (? : ist eine Kurzform von if-else) –"
        }
        if let g = groups(rx(#"^\((double|int|long)\)\s*(.+)$"#), e) {
            return g[1] == "double"
                ? "das Ergebnis der Rechnung \(g[2]) als Kommazahl (double macht vorher aus der ganzen Zahl eine Kommazahl, damit beim Teilen nichts abgeschnitten wird)"
                : "das Ergebnis von \(g[2]) als ganze Zahl (\(g[1]) schneidet die Nachkommastellen ab)"
        }

        let pieces = split(e, separator: "+", requireSpaces: true)
        if pieces.count > 1 && pieces.contains(where: isStringLiteral) {
            return "den zusammengesetzten Text aus \(list(pieces.map(piecePhrase))) (das + klebt die Teile aneinander)"
        }
        if e.hasPrefix("new ") && !e.contains(").") { return newObjectPhrase(e) }
        if e.contains("->"), groups(lambda, e) != nil { return "eine Mini-Anweisung ohne Namen (ein Lambda): \(e)" }
        if groups(methodReference, e) != nil { return "einen Verweis auf die fertige Methode \(e)" }
        if let known = knownFactory(e) { return known }
        if let g = groups(thisField, e) { return "den Inhalt des Fachs „\(g[1])“ dieses Objekts" }
        if JavaGlossary.qualified[e] == nil, let g = groups(rx(#"^([A-Z]\w*)\.([A-Z][A-Z0-9_]*)$"#), e) {
            return "den festen Wert \(g[2]) aus „\(g[1])“"
        }
        if let g = groups(rx(#"^([A-Z]\w*)\.([a-z]\w*)$"#), e) {
            return "den Inhalt des gemeinsamen Fachs „\(g[2])“ der Klasse \(g[1])"
        }
        if let g = groups(rx(#"^([a-z]\w*)\.([a-z]\w*)$"#), e), g[2] != "length" {
            return "den Inhalt des Fachs „\(g[2])“ von „\(g[1])“"
        }
        if e.hasSuffix(").length"), let base = e.range(of: ".length", options: .backwards) {
            return "die Anzahl der Werte in \(e[..<base.lowerBound])"
        }
        if let g = groups(rx(#"^(\w+)\.get\((.+?)\)\.getOrDefault\((.+)\)$"#), e) {
            let parts = splitArguments(g[3])
            if parts.count == 2 {
                return "den Eintrag zum Schlüssel \(shortValue(parts[0])) aus dem inneren Wörterbuch \(g[1]).get(\(g[2])) – oder den Ersatz \(shortValue(parts[1])), falls es ihn dort nicht gibt –"
            }
        }
        if let call = topLevelCall(e), let receiver = call.receiver, groups(identifier, receiver) != nil {
            switch call.method {
            case "plusDays": return "das Datum \(call.arguments) Tage nach „\(receiver)“"
            case "format" where !call.arguments.contains("\""): return "das Datum „\(receiver)“ als Text im Format der Vorlage „\(call.arguments)“"
            case "submit":
                if let lambda = lambdaParts(call.arguments) {
                    return "einen Abholschein (Future) für die Aufgabe „\(lambda.1)“ (das Team „\(receiver)“ erledigt sie im Hintergrund)"
                }
            default: break
            }
        }
        if groups(identifier, e) != nil { return "den Inhalt der Box „\(e)“" }
        if let g = groups(arrayLength, e) { return "die Anzahl der Fächer im Eierkarton „\(g[1])“" }
        if let g = groups(arrayElement, e), groups(identifier, g[2]) != nil || Int(g[2]) != nil {
            return "den Inhalt von Fach Nummer \(g[2]) im Eierkarton „\(g[1])“"
        }
        // Operatoren zählen nur auf oberster Ebene – nicht innerhalb von Klammern (z. B. Lambdas).
        let masked = topLevelOnly(JavaSource.maskingLiterals(e))
        if masked.range(of: #" (==|!=|<=|>=|<|>|&&|\|\|) "#, options: .regularExpression) != nil
            || masked.range(of: #"\binstanceof\b"#, options: .regularExpression) != nil {
            let hint = idiomHint(e).replacingOccurrences(of: " – ist ", with: "also: ist ").replacingOccurrences(of: " also ", with: " ")
            return hint.isEmpty ? "die Antwort auf die Frage „\(e)?“ (true = ja, false = nein)"
                : "die Antwort auf die Frage „\(e)?“ (\(hint)? true = ja, false = nein)"
        }
        if masked.range(of: #" [-+*/%] "#, options: .regularExpression) != nil {
            return "das Ergebnis der Rechnung \(e)"
        }
        if let chain = chainSteps(e) { return "das Ergebnis dieser Schritte: \(chain)" }
        if let call = topLevelCall(e), let result = JavaGlossary.resultPhrase(forMethod: call.method) {
            return "das Ergebnis von \(e) (\(result))"
        }
        return "das Ergebnis von \(e)"
    }

    /// Entfernt alles innerhalb von Klammern, damit nur die oberste Ebene übrig bleibt.
    static func topLevelOnly(_ s: String) -> String {
        var result = ""
        var depth = 0
        for c in s {
            if c == "(" { depth += 1; continue }
            if c == ")" { depth -= 1; continue }
            if depth == 0 { result.append(c) }
        }
        return result
    }

    /// Satzanfang für eine Deklaration mit `new` („Hier backen wir …“) und das passende Pronomen.
    static func newSentence(_ e: String) -> (String, String) {
        if let g = groups(newObject, e) {
            let args = splitArguments(g[3])
            switch g[1] {
            case "ArrayList": return ("Hier erstellen wir mit new eine neue, leere ArrayList – eine Liste, die wachsen kann wie ein Einkaufszettel –", "sie")
            case "HashMap": return ("Hier erstellen wir mit new ein neues, leeres Wörterbuch (HashMap)", "es")
            case "TreeMap": return ("Hier erstellen wir mit new ein neues, leeres Wörterbuch, das seine Schlüssel automatisch alphabetisch sortiert (TreeMap),", "es")
            case "TreeSet": return ("Hier erstellen wir mit new ein TreeSet – eine Menge, die jeden Eintrag nur einmal aufnimmt und alles automatisch sortiert\(args.isEmpty ? "" : ", gefüllt mit \(list(args.map(argumentPhrase)))") –", "es")
            case "HashSet": return ("Hier erstellen wir mit new ein HashSet – eine Menge ohne Doppelte\(args.isEmpty ? "" : ", gefüllt mit \(list(args.map(argumentPhrase)))") –", "es")
            case "ArrayDeque": return ("Hier erstellen wir mit new eine leere ArrayDeque – eine Reihe, die als Stapel oder als Warteschlange dienen kann –", "sie")
            case "StringBuilder": return ("Hier erstellen wir mit new einen Notizblock für Text (StringBuilder)\(args.isEmpty ? "" : ", auf dem schon \(list(args.map(shortValue))) steht,")", "ihn")
            case "Scanner": return ("Hier erstellen wir mit new einen Scanner – ein Lesegerät, das \(list(args.map(argumentPhrase))) Stück für Stück liest –", "ihn")
            case "AtomicInteger": return ("Hier erstellen wir mit new einen sicheren Zähler (AtomicInteger), der bei 0 beginnt,", "ihn")
            case "Thread":
                if let lambda = lambdaParts(args.first ?? "") {
                    return ("Hier erstellen wir mit new einen Thread (einen eigenen Arbeitsstrang) mit der Aufgabe „\(lambda.1)“", "ihn")
                }
                return ("Hier erstellen wir mit new einen Thread (einen eigenen Arbeitsstrang), der die Aufgabe „\(args.first ?? "")“ erledigen soll,", "ihn")
            case "String": return ("Hier erstellen wir mit new ein brandneues Text-Objekt mit dem Inhalt \(list(args.map(shortValue))) – wichtig: ein eigenes Objekt, auch wenn der Inhalt gleich aussieht –", "es")
            default:
                let with = args.isEmpty ? "" : " mit den Zutaten \(list(args.map(shortValue)))"
                return ("Hier backen wir mit new aus der Kuchenform „\(g[1])“ ein neues Objekt\(with)", "es")
            }
        }
        return ("Hier erstellen wir mit new ein neues Objekt (\(e))", "es")
    }

    /// Dasselbe als Satzglied („… ein frisch gebackenes Objekt …“).
    static func newObjectPhrase(_ e: String) -> String {
        if let g = groups(newArray, e) { return "einen neuen Eierkarton mit \(g[2]) Fächern für \(g[1])-Werte" }
        if let g = groups(newObject, e) {
            let args = splitArguments(g[3])
            let with = args.isEmpty ? "" : " mit den Zutaten \(list(args.map(shortValue)))"
            return "ein frisch gebackenes Objekt aus der Kuchenform „\(g[1])“\(with)"
        }
        return "ein neues Objekt (\(e))"
    }

    static func polymorphismNote(declared: String, created: String) -> String {
        guard let g = groups(newName, created) else { return "" }
        let base = declared.components(separatedBy: "<").first ?? declared
        let concrete = g[1]
        if base == concrete || base == "var" || base.hasSuffix("[]") { return "" }
        if (base == "List" && concrete == "ArrayList") || (base == "Map" && (concrete == "HashMap" || concrete == "TreeMap")) {
            return " Auf dem Etikett steht allgemein „\(base)“, drin liegt eine \(concrete) – so kann man später leicht eine andere Sorte nehmen."
        }
        if (base == "Set" && (concrete == "HashSet" || concrete == "TreeSet")) || ((base == "Deque" || base == "Queue") && concrete == "ArrayDeque") {
            return " Auf dem Etikett steht allgemein „\(base)“, drin liegt \(concrete == "ArrayDeque" ? "eine" : "ein") \(concrete) – so kann man später leicht eine andere Sorte nehmen."
        }
        if base == "Object" { return " Drin liegt hier ein \(concrete)-Objekt." }
        return " Achtung, spannend: Das Etikett sagt „\(base)“, drin liegt aber ein \(concrete)-Objekt. Das passt, denn jedes \(concrete)-Objekt zählt auch als \(base)-Objekt (es wurde aus einer erweiterten \(base)-Form gebacken). Fragt man es später etwas, antwortet trotzdem das \(concrete)-Objekt – das nennt man Polymorphie („Vielgestaltigkeit“)."
    }

    static func patternNote(_ condition: String) -> String {
        if let g = groups(rx(#"(\w+)\s+instanceof\s+([A-Z]\w*)\((.*)\)"#), condition) {
            let names = parameters(g[3]).map(\.name)
            return " Dabei schaut instanceof nach, ob „\(g[1])“ ein \(g[2]) ist – und packt seine Zutaten gleich in die Boxen \(list(names)) aus (Record-Muster)."
        }
        guard let g = groups(instanceofPattern, condition) else { return "" }
        return " Dabei schaut instanceof nach, ob „\(g[1])“ ein \(g[2]) ist. Wenn ja, bekommt der Wert sofort das Namensschild „\(g[3])“ und kann als \(g[2]) benutzt werden."
    }

    static func stepPhrase(_ step: String) -> String {
        if let g = groups(rx(#"^(\w+)\+\+$"#), step) { return "wird „\(g[1])“ um 1 erhöht" }
        if let g = groups(rx(#"^(\w+)--$"#), step) { return "wird „\(g[1])“ um 1 verringert" }
        if let g = groups(rx(#"^(\w+)\s*\+=\s*(.+)$"#), step) { return "wird „\(g[1])“ um \(g[2]) erhöht" }
        if let g = groups(rx(#"^(\w+)\s*-=\s*(.+)$"#), step) { return "wird „\(g[1])“ um \(g[2]) verringert" }
        return "wird \(step) ausgeführt"
    }

    /// Name und Argumente eines Aufrufs `name(args)`.
    static func callParts(_ s: String) -> (String, String)? {
        guard let open = s.firstIndex(of: "("), s.hasSuffix(")") else { return nil }
        let name = String(s[..<open])
        guard groups(identifier, name) != nil else { return nil }
        return (name, String(s[s.index(after: open)..<s.index(before: s.endIndex)]))
    }

    /// Letzter Methodenaufruf der obersten Ebene: `empfaenger.methode(argumente)`.
    static func topLevelCall(_ e: String) -> (receiver: String?, method: String, arguments: String)? {
        guard e.hasSuffix(")") else { return nil }
        let chars = Array(e)
        var depth = 0
        var inString = false
        var openIndex: Int?
        var i = chars.count - 1
        while i >= 0 {
            let c = chars[i]
            if c == "\"" { inString.toggle() }
            if !inString {
                if c == ")" { depth += 1 }
                if c == "(" {
                    depth -= 1
                    if depth == 0 { openIndex = i; break }
                }
            }
            i -= 1
        }
        guard let open = openIndex else { return nil }
        var nameStart = open
        while nameStart > 0, chars[nameStart - 1].isLetter || chars[nameStart - 1].isNumber || chars[nameStart - 1] == "_" {
            nameStart -= 1
        }
        let name = String(chars[nameStart..<open])
        guard !name.isEmpty else { return nil }
        let arguments = String(chars[(open + 1)..<(chars.count - 1)])
        if nameStart > 0 && chars[nameStart - 1] == "." {
            return (String(chars[0..<(nameStart - 1)]), name, arguments)
        }
        guard nameStart == 0 else { return nil }
        return (nil, name, arguments)
    }

    /// Beschreibt Ketten wie `zahlen.stream().filter(…).count()` Schritt für Schritt
    /// („wir starten mit …, dann …“). Liefert nil für einfache Aufrufe.
    static func chainSteps(_ e: String) -> String? {
        var calls: [(String, String)] = []
        var rest = e
        while let call = topLevelCall(rest), let receiver = call.receiver {
            calls.insert((call.method, call.arguments), at: 0)
            rest = receiver
        }
        if rest == "Arrays", let first = calls.first, first.0 == "stream" {
            rest = first.1
            calls[0] = ("stream", "")
        }
        guard calls.count >= 2, groups(identifier, rest) != nil || rest.hasPrefix("new ") else { return nil }
        let steps = calls.map { shortStep(name: $0.0, args: $0.1) }
        let head = rest.hasPrefix("new ") ? newObjectPhrase(rest) : "„\(rest)“"
        return "Wir starten mit \(head), dann \(steps.joined(separator: ", dann "))"
    }

    static func lambdaParts(_ args: String) -> (String, String)? {
        guard args.contains("->"), let g = groups(lambda, args) else { return nil }
        return (g[1], g[2])
    }

    /// Kurzer Schritt innerhalb einer Kette.
    static func shortStep(name: String, args: String) -> String {
        let parts = lambdaParts(args)
        switch name {
        case "stream": return "stream() legt alles aufs Fließband"
        case "filter": return parts.map { "filter lässt nur die Elemente durch, für die „\($0.1)“ stimmt" } ?? "filter siebt aus"
        case "map": return parts.map { "map macht aus jedem \($0.0) den Wert \($0.1)" } ?? "map wendet \(args) auf den Inhalt an"
        case "mapToInt": return parts.map { "mapToInt macht aus jedem \($0.0) die ganze Zahl \($0.1)" } ?? "mapToInt macht daraus ganze Zahlen"
        case "sum": return "sum() zählt alles zusammen"
        case "count": return "count() zählt, wie viele übrig sind"
        case "toList": return "toList() packt alles in eine neue Liste"
        case "orElse": return "orElse nimmt den Inhalt der Schachtel – oder \(shortValue(args)), falls sie leer ist"
        case "reverse": return "reverse() dreht die Reihenfolge der Zeichen um"
        case "sorted": return args.isEmpty ? "sorted() bringt alles in Reihenfolge" : "sorted sortiert nach der Regel \(args)"
        case "max": return "max sucht das größte Element (verglichen mit \(args))"
        case "min": return args.isEmpty ? "min() sucht den kleinsten Wert" : "min sucht das kleinste Element (verglichen mit \(args))"
        case "average": return "average() bildet den Durchschnitt"
        case "flatMap": return "flatMap macht aus allen Teillisten eine flache Liste"
        case "reduce": return "reduce fasst alles zu einem einzigen Wert zusammen"
        case "forEach": return "forEach macht mit jedem Element \(args)"
        case "toString": return "toString() macht daraus wieder einen normalen Text"
        default:
            let meaning = JavaGlossary.resultPhrase(forMethod: name).map { " (liefert \($0))" } ?? ""
            return "\(name)(\(args))\(meaning)"
        }
    }

    /// Eine Station am Fließband als ganzer Satz.
    static func stationSentence(name: String, args: String) -> String {
        let parts = lambdaParts(args)
        switch name {
        case "filter":
            if let (x, cond) = parts {
                return "Station „Sieb“ (filter): Nur die Elemente \(x), für die „\(cond)“ stimmt, dürfen weiter aufs Band – die anderen fallen heraus."
            }
            return "Station „Sieb“ (filter): Nur passende Elemente dürfen weiter (\(args))."
        case "map":
            if let (x, body) = parts { return "Station „Umformer“ (map): Aus jedem Element \(x) wird \(body)." }
            return "Station „Umformer“ (map): Jedes Element wird mit \(args) umgewandelt."
        case "mapToInt":
            if let (x, body) = parts { return "Station „Umformer zu Zahlen“ (mapToInt): Aus jedem \(x) wird die ganze Zahl \(body) – damit man danach rechnen kann." }
            return "Station „Umformer zu Zahlen“ (mapToInt): wandelt in ganze Zahlen um."
        case "toList": return "Ende des Bandes (toList): Alles, was übrig ist, kommt in eine neue Liste."
        case "sorted":
            return args.isEmpty
                ? "Station „Sortierer“ (sorted): Die Elemente werden der Reihe nach geordnet – Zahlen aufsteigend, Texte alphabetisch."
                : "Station „Sortierer“ (sorted): Die Elemente werden nach der Regel \(args) geordnet."
        case "flatMap":
            return "Station „Auspacker“ (flatMap): Jede Teilliste wird ausgepackt (\(args)) – aus vielen kleinen Listen wird ein einziges flaches Band."
        case "max":
            return "Ende des Bandes (max): Das größte Element wird gesucht – verglichen mit \(args). Heraus kommt eine Schachtel (Optional), weil das Band auch leer sein könnte."
        case "min":
            return args.isEmpty
                ? "Ende des Bandes (min): Der kleinste Wert wird gesucht – heraus kommt eine Schachtel, weil das Band leer sein könnte."
                : "Ende des Bandes (min): Das kleinste Element wird gesucht – verglichen mit \(args)."
        case "average":
            return "Ende des Bandes (average): Aus allen Zahlen wird der Durchschnitt gebildet – in einer Schachtel, weil das Band leer sein könnte."
        case "orElse":
            return "Die Schachtel wird geöffnet (orElse): Ist etwas drin, kommt es heraus – sonst der Ersatz \(shortValue(args))."
        case "forEach":
            return "Ende des Bandes (forEach): Mit jedem Element, das übrig ist, passiert \(args) – hier also: ausgeben."
        case "reduce":
            let parts = splitArguments(args)
            if parts.count == 2, let (vars, body) = lambdaParts(parts[1]) {
                return "Ende des Bandes (reduce): Alles wird zu einem Wert zusammengefasst – wie ein Trichter. Start ist \(parts[0]), dann wird Schritt für Schritt \(body) gerechnet (\(vars): bisheriges Ergebnis und nächstes Element)."
            }
            return "Ende des Bandes (reduce): Alles wird zu einem einzigen Wert zusammengefasst."
        case "sum": return "Ende des Bandes (sum): Alle Zahlen werden zusammengezählt."
        case "count": return "Ende des Bandes (count): Die übrig gebliebenen Elemente werden gezählt."
        case "collect":
            if let g = groups(rx(#"^Collectors\.joining\((.*)\)$"#), args) {
                let separator = g[1].isEmpty ? "ohne Trennzeichen" : "getrennt durch \(shortValue(g[1]))"
                return "Ende des Bandes (collect): Alle Texte werden zu einem einzigen Text zusammengeklebt, \(separator)."
            }
            if let g = groups(rx(#"^Collectors\.groupingBy\((.*)\)$"#), args) {
                let parts = splitArguments(g[1])
                var text = "Ende des Bandes (collect mit groupingBy): Die Elemente werden in Fächer sortiert wie Post in Briefkästen – welches Fach, bestimmt \(parts.first ?? "")."
                if parts.contains("TreeMap::new") { text += " TreeMap::new hält die Fächer sortiert." }
                if parts.last == "Collectors.counting()" { text += " Collectors.counting() zählt, wie viele in jedem Fach liegen." }
                if parts.last == "Collectors.toList()" { text += " Collectors.toList() sammelt pro Fach eine Liste." }
                return text + " Heraus kommt ein Wörterbuch (Map): Fach → Inhalt."
            }
            return "Ende des Bandes (collect): Das Ergebnis wird eingesammelt."
        default:
            return "Station \(name)(\(args)): \(shortStep(name: name, args: args))."
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
