import Foundation

/// Eine Aufgabe. Im JSON stehen die typspezifischen Felder flach neben den
/// gemeinsamen Feldern; `type` wählt die Variante.
public struct LearningTask: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let topicId: String
    public let difficulty: Difficulty
    public let prompt: String
    /// Code, der zur Aufgabe angezeigt wird (z. B. bei Multiple Choice oder Ausgabe vorhersagen).
    public let codeSnippet: CodeSnippet?
    public var code: String? { codeSnippet?.source }
    public let hint: String?
    public let explanation: String
    public let javaContext: JavaContext
    public let kind: TaskKind
    /// Aufgaben mit derselben Gruppe fragen dasselbe Lernziel auf verschiedene Weise ab.
    /// Aus einer Gruppe kommt pro Sitzung höchstens eine Variante dran – so lässt sich
    /// eine falsch beantwortete Aufgabe später üben, ohne die Antwort auswendig zu können.
    /// Ohne Angabe ist die Aufgabe ihre eigene Gruppe.
    public let variantGroup: String?
    /// UML-Klassendiagramm, das zur Aufgabe gezeigt wird (statt oder neben Code).
    public let diagram: UMLDiagram?

    /// Gruppenschlüssel für die Variantenauswahl (eigene ID, falls keine Gruppe gesetzt ist).
    public var groupKey: String { variantGroup ?? id }

    /// Wie ein Code-Schnipsel zu verstehen ist: Anweisungen im `main`-Block,
    /// Klassenmitglieder oder eine vollständige Quelldatei.
    public enum JavaContext: String, Decodable, Sendable {
        case statements
        case members
        case file

        public var instruction: String {
            switch self {
            case .statements: "Schreibe nur die Anweisungen – der main-Block ist schon da."
            case .members: "Schreibe die Methoden bzw. Felder innerhalb der Klasse."
            case .file: "Schreibe den vollständigen Code inklusive Klassen."
            }
        }
    }

    public var type: TaskType { kind.type }

    enum CodingKeys: String, CodingKey {
        case id, type, topicId, difficulty, prompt, code, hint, explanation, javaContext, variantGroup, diagram
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        topicId = try container.decode(String.self, forKey: .topicId)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        prompt = try container.decode(String.self, forKey: .prompt)
        codeSnippet = try container.decodeIfPresent(CodeSnippet.self, forKey: .code)
        hint = try container.decodeIfPresent(String.self, forKey: .hint)
        explanation = try container.decode(String.self, forKey: .explanation)
        javaContext = try container.decodeIfPresent(JavaContext.self, forKey: .javaContext) ?? .statements
        variantGroup = try container.decodeIfPresent(String.self, forKey: .variantGroup)
        diagram = try container.decodeIfPresent(UMLDiagram.self, forKey: .diagram)
        switch try container.decode(TaskType.self, forKey: .type) {
        case .singleChoice: kind = .singleChoice(try SingleChoiceSpec(from: decoder))
        case .fillBlank: kind = .fillBlank(try FillBlankSpec(from: decoder))
        case .predictOutput: kind = .predictOutput(try PredictOutputSpec(from: decoder))
        case .code: kind = .code(try CodeTaskSpec(from: decoder))
        }
    }

    public init(
        id: String,
        topicId: String,
        difficulty: Difficulty,
        prompt: String,
        code: String? = nil,
        hint: String? = nil,
        explanation: String,
        javaContext: JavaContext = .statements,
        variantGroup: String? = nil,
        diagram: UMLDiagram? = nil,
        kind: TaskKind
    ) {
        self.id = id
        self.topicId = topicId
        self.difficulty = difficulty
        self.prompt = prompt
        self.codeSnippet = code.map(CodeSnippet.init(source:))
        self.hint = hint
        self.explanation = explanation
        self.javaContext = javaContext
        self.variantGroup = variantGroup
        self.diagram = diagram
        self.kind = kind
    }
}

public enum TaskType: String, Decodable, Sendable, CaseIterable {
    case singleChoice
    case fillBlank
    case predictOutput
    case code

    public var title: String {
        switch self {
        case .singleChoice: "Multiple Choice"
        case .fillBlank: "Lückentext"
        case .predictOutput: "Ausgabe vorhersagen"
        case .code: "Code schreiben"
        }
    }

    public var symbolName: String {
        switch self {
        case .singleChoice: "list.bullet.circle.fill"
        case .fillBlank: "rectangle.and.pencil.and.ellipsis"
        case .predictOutput: "terminal.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }
}

public enum TaskKind: Sendable, Hashable {
    case singleChoice(SingleChoiceSpec)
    case fillBlank(FillBlankSpec)
    case predictOutput(PredictOutputSpec)
    case code(CodeTaskSpec)

    public var type: TaskType {
        switch self {
        case .singleChoice: .singleChoice
        case .fillBlank: .fillBlank
        case .predictOutput: .predictOutput
        case .code: .code
        }
    }
}

public struct SingleChoiceSpec: Decodable, Sendable, Hashable {
    public let choices: [String]
    public let correctIndex: Int
    /// Warum die jeweilige Antwort nicht stimmt – gleiche Reihenfolge wie `choices`,
    /// beim richtigen Eintrag leer. Wird nach einer falschen Antwort angezeigt.
    public let wrongExplanations: [String?]

    enum CodingKeys: String, CodingKey { case choices, correctIndex, whyWrong }

    public init(choices: [String], correctIndex: Int, wrongExplanations: [String?] = []) {
        self.choices = choices
        self.correctIndex = correctIndex
        self.wrongExplanations = wrongExplanations
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        choices = try container.decode([String].self, forKey: .choices)
        correctIndex = try container.decode(Int.self, forKey: .correctIndex)
        wrongExplanations = try container.decodeIfPresent([String?].self, forKey: .whyWrong) ?? []
    }

    /// Erklärung zur gewählten Antwort – nur für falsche Antworten und nur, wenn hinterlegt.
    public func whyWrong(_ index: Int) -> String? {
        guard index != correctIndex, wrongExplanations.indices.contains(index) else { return nil }
        return wrongExplanations[index]
    }
}

/// Lückentext: `template` enthält Platzhalter `{{0}}`, `{{1}}`, … für die Lücken.
/// Die Zeilenerklärungen beschreiben den vollständigen (richtig ausgefüllten) Code.
public struct FillBlankSpec: Decodable, Sendable, Hashable {
    public let templateSnippet: CodeSnippet
    public let blanks: [Blank]

    public var template: String { templateSnippet.source }

    enum CodingKeys: String, CodingKey { case templateSnippet = "template", blanks }

    public struct Blank: Decodable, Sendable, Hashable {
        /// Akzeptierte Antworten; die erste gilt als Musterlösung.
        public let accepted: [String]
        public let caseSensitive: Bool

        enum CodingKeys: String, CodingKey { case accepted, caseSensitive }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accepted = try container.decode([String].self, forKey: .accepted)
            caseSensitive = try container.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? true
        }

        public init(accepted: [String], caseSensitive: Bool = true) {
            self.accepted = accepted
            self.caseSensitive = caseSensitive
        }

        /// Gleiche Regeln wie der Evaluator – für die farbige Markierung einzelner Lücken.
        public func accepts(_ value: String) -> Bool {
            AnswerEvaluator.blank(self, accepts: JavaSource.normalizingTypography(value))
        }
    }

    public init(template: String, blanks: [Blank]) {
        self.templateSnippet = CodeSnippet(source: template)
        self.blanks = blanks
    }

    public static func placeholder(_ index: Int) -> String { "{{\(index)}}" }

    /// Setzt Werte in die Lücken ein (fehlende Werte bleiben als Platzhalter stehen).
    public func filled(with values: [String]) -> String {
        var result = template
        for index in blanks.indices where index < values.count {
            result = result.replacingOccurrences(of: Self.placeholder(index), with: values[index])
        }
        return result
    }

    /// Die Vorlage mit der ersten richtigen Antwort in jeder Lücke – samt der
    /// gespeicherten Zeilen-Erklärungen (für „Lösung Zeile für Zeile“).
    public var solvedSnippet: CodeSnippet {
        CodeSnippet(lines: templateSnippet.lines.map { line in
            var code = line.code
            for (index, blank) in blanks.enumerated() {
                code = code.replacingOccurrences(of: Self.placeholder(index), with: blank.accepted.first ?? "")
            }
            return CodeSnippet.Line(code: code, explain: line.explain)
        })
    }

    /// Zeilennummern (ab 1), in denen eine Lücke steht. Ihre Erklärung würde die
    /// Lösung verraten und bleibt bis zum Lösen verborgen.
    public var blankLineNumbers: Set<Int> {
        Set(templateSnippet.lines.enumerated().compactMap { $0.element.code.contains("{{") ? $0.offset + 1 : nil })
    }

    /// Zerlegt die Vorlage in Text- und Lückenstücke für die Darstellung.
    public var segments: [Segment] {
        var segments: [Segment] = []
        var rest = Substring(template)
        while let open = rest.range(of: "{{"),
              let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex),
              let index = Int(rest[open.upperBound..<close.lowerBound]) {
            if open.lowerBound > rest.startIndex {
                segments.append(.text(String(rest[rest.startIndex..<open.lowerBound])))
            }
            segments.append(.blank(index))
            rest = rest[close.upperBound...]
        }
        if !rest.isEmpty { segments.append(.text(String(rest))) }
        return segments
    }

    public enum Segment: Sendable, Hashable {
        case text(String)
        case blank(Int)
    }
}

public struct PredictOutputSpec: Decodable, Sendable, Hashable {
    public let expectedOutput: String
    /// Weitere Schreibweisen, die ebenfalls korrekt sind.
    public let alsoAccepted: [String]

    enum CodingKeys: String, CodingKey { case expectedOutput, alsoAccepted }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        expectedOutput = try container.decode(String.self, forKey: .expectedOutput)
        alsoAccepted = try container.decodeIfPresent([String].self, forKey: .alsoAccepted) ?? []
    }

    public init(expectedOutput: String, alsoAccepted: [String] = []) {
        self.expectedOutput = expectedOutput
        self.alsoAccepted = alsoAccepted
    }
}

/// Freie Code-Eingabe, geprüft durch Plausibilitätsregeln statt durch einen Compiler.
public struct CodeTaskSpec: Decodable, Sendable, Hashable {
    public let starter: CodeSnippet
    public let solution: CodeSnippet
    public var starterCode: String { starter.source }
    public var sampleSolution: String { solution.source }
    /// Optional: Konsolenausgabe der Musterlösung, wird der lernenden Person gezeigt.
    public let expectedOutput: String?
    public let rules: [CodeRule]
    public let structure: [StructureCheck]

    enum CodingKeys: String, CodingKey { case starterCode, sampleSolution, expectedOutput, rules, structure }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        starter = try container.decodeIfPresent(CodeSnippet.self, forKey: .starterCode) ?? CodeSnippet(source: "")
        solution = try container.decode(CodeSnippet.self, forKey: .sampleSolution)
        expectedOutput = try container.decodeIfPresent(String.self, forKey: .expectedOutput)
        rules = try container.decode([CodeRule].self, forKey: .rules)
        structure = try container.decodeIfPresent([StructureCheck].self, forKey: .structure) ?? StructureCheck.allCases
    }

    public init(
        starterCode: String = "",
        sampleSolution: String,
        expectedOutput: String? = nil,
        rules: [CodeRule],
        structure: [StructureCheck] = StructureCheck.allCases
    ) {
        self.starter = CodeSnippet(source: starterCode)
        self.solution = CodeSnippet(source: sampleSolution)
        self.expectedOutput = expectedOutput
        self.rules = rules
        self.structure = structure
    }
}

/// Eine RegEx-Regel für Code-Aufgaben.
public struct CodeRule: Decodable, Sendable, Hashable {
    public enum Kind: String, Decodable, Sendable {
        /// Das Muster muss vorkommen.
        case require
        /// Das Muster darf nicht vorkommen (z. B. hart codiertes Ergebnis).
        case forbid
        /// Mindestens eines der Muster in `patterns` muss vorkommen. Für Aufgaben, die
        /// sich auf mehreren gleichwertigen Wegen lösen lassen – eine Schleife als for
        /// oder als while, eine Summe mit Index oder mit for-each. Wer selbst denkt,
        /// soll nicht dafür bestraft werden, dass ihm ein anderer Weg eingefallen ist.
        case anyOf
    }

    /// Worauf das Muster angewendet wird.
    public enum Scope: String, Decodable, Sendable {
        /// Code ohne Kommentare, Inhalte von String-/Char-Literalen geleert.
        case code
        /// Code ohne Kommentare, Literale bleiben erhalten.
        case raw
    }

    public let rule: Kind
    public let pattern: String
    /// Die gleichwertigen Muster bei `anyOf`; bei den anderen Arten leer.
    public let patterns: [String]
    public let message: String
    public let scope: Scope
    public let weight: Double

    /// Alle Muster, von denen je nach Art eines oder genau dieses passen muss.
    public var allPatterns: [String] { patterns.isEmpty ? [pattern] : patterns }

    enum CodingKeys: String, CodingKey { case rule, pattern, patterns, message, scope, weight }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rule = try container.decode(Kind.self, forKey: .rule)
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern) ?? ""
        patterns = try container.decodeIfPresent([String].self, forKey: .patterns) ?? []
        message = try container.decode(String.self, forKey: .message)
        scope = try container.decodeIfPresent(Scope.self, forKey: .scope) ?? .code
        weight = try container.decodeIfPresent(Double.self, forKey: .weight) ?? 1
    }

    public init(rule: Kind, pattern: String = "", patterns: [String] = [], message: String,
                scope: Scope = .code, weight: Double = 1) {
        self.rule = rule
        self.pattern = pattern
        self.patterns = patterns
        self.message = message
        self.scope = scope
        self.weight = weight
    }
}

public enum StructureCheck: String, Decodable, Sendable, CaseIterable {
    /// Klammern (), [] und {} sind ausgeglichen und korrekt verschachtelt.
    case balancedDelimiters
    /// Anweisungen enden mit Semikolon (heuristisch).
    case semicolons
}
