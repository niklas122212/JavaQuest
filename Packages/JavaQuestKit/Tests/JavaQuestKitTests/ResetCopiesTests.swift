import Foundation
import Testing
@testable import JavaQuestKit

/// Die Regeln für Kopien vom Zurücksetzen – dieselben wie unter Windows und im Web.
@Suite("Kopie vor dem Zurücksetzen")
struct ResetCopiesTests {
    private func zeit(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func stand(versuche: Int, lektionen: Int) -> ProgressBackup.Stand {
        ProgressBackup.Stand(
            createdAt: zeit("2026-09-19T08:00:00Z"), experienceLevel: "beginner", placedLevel: nil,
            placementScore: nil, onboardingCompleted: true, masterScore: 0, currentStreak: 0,
            longestStreak: 0, lastActiveDay: nil,
            lessonRecords: Dictionary(uniqueKeysWithValues: (0..<lektionen).map {
                ("l0\($0 + 1)", ProgressBackup.Lektion(bestAccuracy: 0.9, lastAccuracy: 0.9, playCount: 1, isCompleted: true,
                                                        completedViaPlacement: false, firstCompletedAt: nil, lastPlayedAt: nil))
            }),
            topicMasteries: [:],
            attempts: (0..<versuche).map {
                ProgressBackup.Versuch(taskId: "t0\($0 % 3)", topicId: "syntax", lessonId: nil, context: "lesson",
                                       difficulty: 1, credit: 1, solved: true, tries: 1,
                                       date: zeit("2026-09-19T08:00:00Z").addingTimeInterval(Double($0)))
            },
            scoreHistory: [])
    }

    @Test("Dateiname mit Zeitstempel in UTC – sortiert sich von selbst")
    func name() {
        #expect(ResetCopies.fileName(for: zeit("2026-09-24T10:20:05Z")) == "stand-20260924-102005.json")
        #expect(ResetCopies.isCopy("stand-20260924-102005.json"))
        #expect(!ResetCopies.isCopy("stand-20260924-102005.wiederhergestellt.json"))
        #expect(!ResetCopies.isCopy("progress.json"))
    }

    @Test("Die jüngste zuerst, anderes bleibt außen vor")
    func reihenfolge() {
        let namen = ["stand-20260920-080000.json", "notiz.txt", "stand-20260924-102000.json",
                     "stand-20260922-090000.wiederhergestellt.json", "stand-20260921-120000.json"]
        #expect(ResetCopies.newestFirst(namen) == ["stand-20260924-102000.json", "stand-20260921-120000.json", "stand-20260920-080000.json"])
    }

    @Test("Eine Kopie nur, wenn es etwas zu verlieren gibt")
    func lohntSich() {
        #expect(!ResetCopies.worthKeeping(stand(versuche: 0, lektionen: 0)))
        #expect(ResetCopies.worthKeeping(stand(versuche: 1, lektionen: 0)))
        #expect(ResetCopies.worthKeeping(stand(versuche: 0, lektionen: 1)))
    }

    @Test("Nach dem Wiederherstellen umbenannt, nicht gelöscht")
    func umbenennen() {
        #expect(ResetCopies.restoredName("stand-20260924-102000.json") == "stand-20260924-102000.wiederhergestellt.json")
    }

    @Test("Beschreibung wie in den anderen Fassungen")
    func beschreibung() {
        let text = ResetCopies.summary(stand(versuche: 5, lektionen: 2), created: zeit("2026-09-24T08:20:00Z"),
                                       timeZone: TimeZone(identifier: "Europe/Berlin")!)
        #expect(text == "Vom 24.09.2026, 10:20 Uhr · 2 Lektionen bestanden · 3 Aufgaben")
        #expect(ResetCopies.summary(stand(versuche: 1, lektionen: 1), created: zeit("2026-09-24T08:20:00Z"),
                                    timeZone: TimeZone(identifier: "UTC")!)
                == "Vom 24.09.2026, 08:20 Uhr · 1 Lektion bestanden · 1 Aufgabe")
    }
}
