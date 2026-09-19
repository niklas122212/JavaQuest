import Foundation
// Liest Jobs {explain, show} (stdin) und liefert je Job die Erklärung pro Zeile
// (aus dem vollständigen Code) und die Befehle pro Zeile (aus dem angezeigten Code,
// damit Lücken nichts verraten). Mit --glossary: das komplette Befehlslexikon.
struct Job: Decodable { let explain: String; let show: String }
struct Output: Encodable { let explain: [String?]; let terms: [[String]] }
struct Entry: Encodable { let term: String; let meaning: String }

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

if CommandLine.arguments.contains("--glossary") {
    var entries = JavaGlossary.words.map { Entry(term: $0.key, meaning: $0.value) }
    entries += JavaGlossary.qualified.map { Entry(term: $0.key, meaning: $0.value) }
    entries += JavaGlossary.methods.map { Entry(term: $0.key + "()", meaning: $0.value.meaning) }
    entries += JavaGlossary.operators.map { Entry(term: $0.symbol, meaning: $0.meaning) }
    entries.append(Entry(term: ".length", meaning: "Zählt die Fächer eines Eierkartons (Array) – ohne Klammern dahinter."))
    FileHandle.standardOutput.write(try encoder.encode(entries.sorted { $0.term < $1.term }))
    exit(0)
}

let jobs = try JSONDecoder().decode([Job].self, from: FileHandle.standardInput.readDataToEndOfFile())
let result: [Output] = jobs.map { job in
    var perLine = [String?](repeating: nil, count: job.explain.components(separatedBy: "\n").count)
    for line in CodeExplainer.explain(job.explain) {
        perLine[line.number - 1] = line.isFallback ? "FALLBACK: " + line.explanation : line.explanation
    }
    let terms = job.show.components(separatedBy: "\n").map { line in
        JavaGlossary.terms(in: JavaSource.maskingLiterals(line)).map(\.term)
    }
    return Output(explain: perLine, terms: terms)
}
FileHandle.standardOutput.write(try encoder.encode(result))
