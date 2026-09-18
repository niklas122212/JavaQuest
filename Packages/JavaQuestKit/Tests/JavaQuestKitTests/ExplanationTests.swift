import Foundation
import Testing
@testable import JavaQuestKit

/// Didaktik-Garantie: Jede Codezeile im Kurs ist in Alltagssprache erklärt,
/// und jeder Befehl steht im Befehlslexikon.
@Suite("Zeile-für-Zeile-Erklärungen")
struct ExplanationTests {
    let course: Course

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    /// Quelltext eines Snippets; Lückentexte werden mit der ersten richtigen Antwort gefüllt.
    func filledSources() -> [(String, String)] {
        // Lückentext-Vorlagen enthalten {{n}} – geprüft wird ihre ausgefüllte Fassung.
        var sources = course.allSnippets
            .filter { !$0.snippet.source.contains("{{") }
            .map { ($0.location, $0.snippet.source) }
        for task in course.allLessons.flatMap(\.tasks) + course.placement.pool(for: .intermediate) {
            guard case .fillBlank(let spec) = task.kind else { continue }
            var text = spec.template
            for (index, blank) in spec.blanks.enumerated() {
                text = text.replacingOccurrences(of: FillBlankSpec.placeholder(index), with: blank.accepted[0])
            }
            sources.append(("\(task.id) (ausgefüllt)", text))
        }
        return sources
    }

    @Test("Jede Codezeile im Kurs hat eine gespeicherte Erklärung")
    func everyLineIsExplained() {
        #expect(!course.allSnippets.isEmpty)
        for (location, snippet) in course.allSnippets {
            #expect(snippet.linesMissingExplanation.isEmpty, "\(location): Zeilen \(snippet.linesMissingExplanation)")
            for line in snippet.explained() {
                #expect(!line.explanation.isEmpty, "\(location) Zeile \(line.number)")
            }
        }
    }

    @Test("Die Erklär-Engine kennt jede Zeile des Kurses (keine Notlösung)")
    func engineHasNoFallbacks() {
        for (location, source) in filledSources() {
            for line in CodeExplainer.explain(source) where line.isFallback {
                Issue.record("\(location) Zeile \(line.number): \(line.code.trimmingCharacters(in: .whitespaces))")
            }
        }
    }

    @Test("Alltagssprache wie im Konzept: Box, Kuchenform, Kuchen")
    func everydayLanguage() {
        let box = CodeExplainer.explain("int alter = 25;")[0].explanation
        #expect(box.hasPrefix("Hier erstellen wir eine Box namens „alter“ und legen die Zahl 25 hinein."), "\(box)")

        let lines = CodeExplainer.explain("""
        class Hund {
            String name;
        }
        Hund bello = new Hund();
        """)
        #expect(lines[0].explanation.contains("Kuchenform"), "\(lines[0].explanation)")
        #expect(lines[2].explanation.contains("Hund"), "Schließende Klammer sagt, was endet: \(lines[2].explanation)")
        #expect(lines[3].explanation.contains("backen"), "\(lines[3].explanation)")
    }

    @Test("Schließende Klammern sagen, was genau endet")
    func closingBracesNameTheirBlock() {
        let lines = CodeExplainer.explain("""
        for (int i = 0; i < 3; i++) {
            if (i % 2 == 0) {
                System.out.println(i);
            }
        }
        """)
        #expect(lines[1].explanation.contains("gerade"), "\(lines[1].explanation)")
        #expect(lines[3].explanation.contains("„ja“"), "Ende des if-Blocks: \(lines[3].explanation)")
        #expect(lines[4].explanation.contains("Schleife"), "\(lines[4].explanation)")
    }

    @Test("Jedes Java-Schlüsselwort im Kurs steht im Befehlslexikon")
    func glossaryCoversKeywords() throws {
        let keywords: Set<String> = [
            "abstract", "boolean", "break", "case", "catch", "char", "class", "continue", "default", "do",
            "double", "else", "enum", "extends", "final", "finally", "float", "for", "if", "implements",
            "import", "instanceof", "int", "interface", "long", "new", "private", "protected", "public",
            "record", "return", "static", "super", "switch", "this", "throw", "throws", "try", "var",
            "void", "while", "yield", "true", "false", "null",
        ]
        let word = try NSRegularExpression(pattern: #"\b[a-z]+\b"#)
        var used: Set<String> = []
        for (_, source) in filledSources() {
            let masked = JavaSource.maskingLiterals(JavaSource.strippingComments(source))
            for match in word.matches(in: masked, range: NSRange(masked.startIndex..., in: masked)) {
                let token = String(masked[Range(match.range, in: masked)!])
                if keywords.contains(token) { used.insert(token) }
            }
        }
        #expect(used.count >= 30, "Kurs nutzt \(used.count) Schlüsselwörter")
        for keyword in used.sorted() {
            #expect(JavaGlossary.entry(for: keyword) != nil, "Schlüsselwort „\(keyword)“ fehlt im Lexikon")
        }
    }

    @Test("Jeder JDK-Befehl im Kurs steht im Befehlslexikon")
    func glossaryCoversMethods() throws {
        let sources = filledSources().map { JavaSource.maskingLiterals(JavaSource.strippingComments($0.1)) }
        let all = sources.joined(separator: "\n")
        func names(_ pattern: String) throws -> Set<String> {
            let regex = try NSRegularExpression(pattern: pattern)
            return Set(regex.matches(in: all, range: NSRange(all.startIndex..., in: all)).map {
                String(all[Range($0.range(at: 1), in: all)!])
            })
        }
        // Selbst geschriebene Methoden (Deklarationen und Record-Felder) erklärt die Engine im Kontext.
        var declared = try names(#"[\w>\]]\s+(\w+)\s*\([^;{]*\)\s*(?:throws\s+\w+\s*)?[{;]"#)
        for components in try names(#"record\s+\w+\s*\(([^)]*)\)"#) {
            for part in components.split(separator: ",") {
                if let name = part.split(separator: " ").last { declared.insert(String(name)) }
            }
        }
        let called = try names(#"\.\s*(\w+)\s*\("#).union(try names(#"::\s*(\w+)"#))
        let qualifiedMethods = Set(JavaGlossary.qualified.keys.compactMap { $0.split(separator: ".").last.map(String.init) })
        let missing = called.subtracting(declared).subtracting(qualifiedMethods).filter { JavaGlossary.methods[$0] == nil }
        #expect(missing.isEmpty, "Fehlen im Lexikon: \(missing.sorted())")
        #expect(called.count >= 25, "Kurs ruft \(called.count) Methoden auf")
    }

    @Test("Lexikon-Begriffe erscheinen zur Zeile")
    func termsPerLine() {
        let line = CodeExplainer.explain("List<String> namen = new ArrayList<>();")[0]
        let terms = Set(line.terms.map(\.term))
        #expect(terms.isSuperset(of: ["List", "String", "new", "ArrayList", "<>", "="]), "\(terms)")
        let compare = Set(CodeExplainer.explain("if (a < b && x % 2 == 0) {")[0].terms.map(\.term))
        #expect(compare.isSuperset(of: ["if", "<", "&&", "%", "=="]), "\(compare)")
    }

    @Test("JSON: Snippet mit Zeilen und Erklärungen, einfacher Text bleibt erlaubt")
    func snippetCoding() throws {
        let json = #"{"lines":[{"code":"int alter = 25;","explain":"Eine Box namens alter."},{"code":""}]}"#
        let snippet = try JSONDecoder().decode(CodeSnippet.self, from: Data(json.utf8))
        #expect(snippet.source == "int alter = 25;\n")
        #expect(snippet.explained()[0].explanation == "Eine Box namens alter.")
        #expect(snippet.linesMissingExplanation.isEmpty)

        let plain = try JSONDecoder().decode(CodeSnippet.self, from: Data(#""int x = 1;""#.utf8))
        #expect(plain.linesMissingExplanation == [1])
        #expect(plain.explained()[0].explanation.contains("Box namens „x“"))

        let roundTrip = try JSONDecoder().decode(CodeSnippet.self, from: JSONEncoder().encode(snippet))
        #expect(roundTrip == snippet)
    }
}
