import Foundation
import Testing
@testable import JavaQuestKit

/// Die Erinnerung soll helfen, nicht nerven: nur an Tagen, an denen etwas fällig ist,
/// und höchstens drei Tage hintereinander, wenn niemand übt.
@Suite("Erinnerung an Wiederholungen")
struct ReviewReminderTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func zeit(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func plan(_ faellig: [String], jetzt: String) -> [ReviewReminder.Slot] {
        ReviewReminder.plan(dueDates: faellig.map(zeit), now: zeit(jetzt), hour: 18, minute: 0, calendar: utc)
    }

    @Test("Nichts fällig – keine Erinnerung")
    func nichts() {
        #expect(plan([], jetzt: "2026-09-24T12:00:00Z").isEmpty)
    }

    @Test("Schon fällig und vor 18 Uhr: heute, dann höchstens noch zwei Tage")
    func heute() {
        let termine = plan(["2026-09-20T09:00:00Z"], jetzt: "2026-09-24T12:00:00Z")
        #expect(termine.map(\.date) == ["2026-09-24T18:00:00Z", "2026-09-25T18:00:00Z", "2026-09-26T18:00:00Z"].map(zeit))
        #expect(termine.allSatisfy { $0.count == 1 })
    }

    @Test("Schon fällig, aber nach 18 Uhr: erst morgen")
    func morgen() {
        #expect(plan(["2026-09-20T09:00:00Z"], jetzt: "2026-09-24T19:30:00Z").first?.date == zeit("2026-09-25T18:00:00Z"))
    }

    @Test("Erst nach 18 Uhr fällig: am Tag darauf")
    func spaeterAmTag() {
        #expect(plan(["2026-09-25T20:00:00Z"], jetzt: "2026-09-24T12:00:00Z").first?.date == zeit("2026-09-26T18:00:00Z"))
    }

    @Test("Die Zahl wächst mit dem, was dazukommt")
    func zahl() {
        let termine = plan(["2026-09-24T08:00:00Z", "2026-09-25T08:00:00Z", "2026-09-30T08:00:00Z"],
                           jetzt: "2026-09-24T12:00:00Z")
        #expect(termine.map(\.count) == [1, 2, 2])
    }

    @Test("Auf der gemeinsamen Beispiel-Sicherung gerechnet")
    func beispiel() throws {
        let course = try CourseLoader.loadBundled()
        let wurzel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let daten = try Data(contentsOf: wurzel.appendingPathComponent("Tests/Sicherungen/aus-der-app.json"))
        let stand = try #require(ProgressBackup.lesen(daten))
        let records = stand.attempts.filter { $0.context != "placement" }
            .map { AttemptRecord(taskId: $0.taskId, credit: $0.credit, date: $0.date) }
        let faellig = SpacedRepetition.goals(from: records, course: course).values.map(\.dueDate)

        // Mittags 3 fällig (siehe SicherungAustauschTests); um 18 Uhr kommt das Lernziel
        // dazu, das genau dann seinen Tag Pause hinter sich hat, am 26. das nächste.
        let termine = ReviewReminder.plan(dueDates: faellig, now: zeit("2026-09-24T12:00:00Z"),
                                          hour: 18, minute: 0, calendar: utc)
        #expect(termine.map(\.count) == [4, 4, 5])
    }

    @Test("Einzahl und Mehrzahl")
    func text() {
        #expect(ReviewReminder.message(count: 1).hasPrefix("1 Lernziel wartet"))
        #expect(ReviewReminder.message(count: 9).hasPrefix("9 Lernziele warten"))
    }
}
