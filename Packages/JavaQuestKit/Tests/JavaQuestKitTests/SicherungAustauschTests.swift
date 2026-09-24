import Foundation
import Testing
@testable import JavaQuestKit

/// Eine Sicherung muss in jeder Fassung lesbar sein – sonst hat, wer am Mac und im Browser
/// lernt, zwei getrennte Lernstände. Lange hat das kein Test geprüft: Mac und Windows
/// passten nur auf dem Papier zusammen, und die Web-App schrieb einen ganz anderen Aufbau.
///
/// Dieselben zwei Dateien liest auch die Windows-Testreihe (SicherungAustauschTest.kt) und
/// die Web-Prüfung (Web/tests/pruefungen.mjs) – mit denselben erwarteten Zahlen. Wer eine
/// davon ändert, muss sie überall ändern.
@Suite("Sicherung zwischen den Fassungen")
struct SicherungAustauschTests {
    let course: Course
    /// Zu diesem Zeitpunkt sind die Dateien „erstellt“; die fälligen Lernziele beziehen sich darauf.
    let stichtag = ISO8601DateFormatter().date(from: "2026-09-24T12:00:00Z")!

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    private func datei(_ name: String) throws -> Data {
        let wurzel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: wurzel.appendingPathComponent("Tests/Sicherungen/\(name)"))
    }

    /// Fällige Lernziele wie im ProgressStore: ohne die Einstufung.
    private func faellig(_ stand: ProgressBackup.Stand) -> Int {
        let records = stand.attempts
            .filter { $0.context != "placement" }
            .map { AttemptRecord(taskId: $0.taskId, credit: $0.credit, date: $0.date) }
        return SpacedRepetition.goals(from: records, course: course).values.filter { $0.isDue(at: stichtag) }.count
    }

    @Test("Eine Sicherung aus der App wird gelesen, und so schreibt sie auch Swift")
    func ausDerApp() throws {
        let daten = try datei("aus-der-app.json")
        let stand = try #require(ProgressBackup.lesen(daten))

        #expect(stand.attempts.count == 10)
        #expect(stand.lessonRecords.values.filter(\.isCompleted).count == 2)
        #expect(faellig(stand) == 3)
        #expect(ProgressBackup.vereine(stand, stand, course: course).masterScore == 32)

        // Die Datei steht in genau der Form, die der Swift-Coder schreibt – leere Felder
        // weggelassen, Zeiten ohne Sekundenbruchteile. Nur dann prüft die Windows-Testreihe
        // an ihr wirklich, ob sie eine Mac-Sicherung lesen kann.
        let sicherung = try ProgressBackup.coder.1.decode(ProgressBackup.self, from: daten)
        let neu = try ProgressBackup.coder.0.encode(sicherung)
        let erwartet = try JSONSerialization.jsonObject(with: daten) as? NSDictionary
        let geschrieben = try JSONSerialization.jsonObject(with: neu) as? NSDictionary
        #expect(erwartet == geschrieben)
    }

    @Test("Eine Sicherung aus der Web-App wird gelesen – mit derselben Wiedervorlage")
    func ausDemWeb() throws {
        let stand = try #require(ProgressBackup.lesen(try datei("aus-dem-web.json")))

        #expect(stand.attempts.count == 7)
        #expect(stand.lessonRecords.values.filter(\.isCompleted).count == 1)
        // 4 fällige Lernziele – genau so viele zählt die Web-App in ihrem eigenen Stand.
        #expect(faellig(stand) == 4)
        #expect(ProgressBackup.vereine(stand, stand, course: course).masterScore == 12)
    }

    @Test("Zweimal eingelesen ergibt keine doppelten Einträge")
    func keineDoppelten() throws {
        for name in ["aus-der-app.json", "aus-dem-web.json"] {
            let stand = try #require(ProgressBackup.lesen(try datei(name)))
            #expect(ProgressBackup.vereine(stand, stand, course: course).attempts.count == stand.attempts.count)
        }
    }
}
