import Foundation
import Testing
@testable import JavaQuestKit

/// Die Sicherung ist die einzige Absicherung gegen ein verlorenes Gerät. Wenn das
/// Einlesen etwas verschluckt, merkt es niemand – deshalb wird hier genau geprüft,
/// dass beim Zusammenführen nichts verschwindet.
@Suite("Sicherung des Lernstands")
struct ProgressBackupTests {
    let course: Course

    init() throws {
        course = try CourseLoader.loadBundled()
    }

    private func versuch(_ id: String, _ datum: String, credit: Double) -> ProgressBackup.Versuch {
        ProgressBackup.Versuch(taskId: id, topicId: "syntax", lessonId: nil, context: "practice",
                               difficulty: 1, credit: credit, solved: credit >= 1, tries: 1,
                               date: ISO8601DateFormatter().date(from: datum)!)
    }

    private func versuchGenau(_ id: String, _ zeit: TimeInterval, credit: Double) -> ProgressBackup.Versuch {
        ProgressBackup.Versuch(taskId: id, topicId: "syntax", lessonId: nil, context: "practice",
                               difficulty: 1, credit: credit, solved: credit >= 1, tries: 1,
                               date: Date(timeIntervalSince1970: zeit))
    }

    private func lektion(best: Double, gespielt: Int, fertig: Bool, zuletzt: String?) -> ProgressBackup.Lektion {
        ProgressBackup.Lektion(bestAccuracy: best, lastAccuracy: best, playCount: gespielt, isCompleted: fertig,
                               completedViaPlacement: false, firstCompletedAt: nil,
                               lastPlayedAt: zuletzt.flatMap { ISO8601DateFormatter().date(from: $0) })
    }

    private func stand(createdAt: String, streak: Int, rekord: Int, aktiv: String?,
                       lektionen: [String: ProgressBackup.Lektion],
                       versuche: [ProgressBackup.Versuch]) -> ProgressBackup.Stand {
        ProgressBackup.Stand(
            createdAt: ISO8601DateFormatter().date(from: createdAt)!,
            experienceLevel: ExperienceLevel.beginner.rawValue,
            placedLevel: nil, placementScore: nil, onboardingCompleted: true, masterScore: 0,
            currentStreak: streak, longestStreak: rekord,
            lastActiveDay: aktiv.flatMap { ISO8601DateFormatter().date(from: $0) },
            lessonRecords: lektionen, topicMasteries: [:], attempts: versuche, scoreHistory: []
        )
    }

    @Test("Einlesen führt zusammen und löscht nichts")
    func mergeKeepsEverything() {
        let lektionId = course.allLessons[0].id
        let zweite = course.allLessons[1].id

        let eigen = stand(
            createdAt: "2026-09-10T10:00:00Z", streak: 2, rekord: 4, aktiv: "2026-09-20T00:00:00Z",
            lektionen: [lektionId: lektion(best: 0.7, gespielt: 2, fertig: false, zuletzt: "2026-09-20T10:00:00Z")],
            versuche: [versuch("a", "2026-09-20T10:00:00Z", credit: 1), versuch("b", "2026-09-20T11:00:00Z", credit: 0)]
        )
        let fremd = stand(
            createdAt: "2026-09-01T10:00:00Z", streak: 5, rekord: 9, aktiv: "2026-09-12T00:00:00Z",
            lektionen: [
                lektionId: lektion(best: 0.9, gespielt: 5, fertig: true, zuletzt: "2026-09-12T10:00:00Z"),
                zweite: lektion(best: 1.0, gespielt: 1, fertig: true, zuletzt: "2026-09-12T11:00:00Z"),
            ],
            versuche: [versuch("b", "2026-09-11T10:00:00Z", credit: 1), versuch("c", "2026-09-11T11:00:00Z", credit: 1)]
        )

        let vereint = ProgressBackup.vereine(eigen, fremd, course: course)
        #expect(vereint.lessonRecords[lektionId]?.bestAccuracy == 0.9, "die bessere Wertung gewinnt")
        #expect(vereint.lessonRecords[lektionId]?.isCompleted == true, "einmal bestanden bleibt bestanden")
        #expect(vereint.lessonRecords[zweite] != nil, "fremde Lektion kommt dazu")
        #expect(vereint.attempts.count == 4, "alle vier Einträge bleiben, keiner doppelt")
        #expect(vereint.longestStreak == 9, "der höhere Rekord bleibt")
        #expect(vereint.currentStreak == 2, "die aktuelle Serie kommt vom jüngeren Stand")
        #expect(vereint.masterScore > 0, "der Score wird aus den Lektionen neu gerechnet")
    }

    @Test("Die Reihenfolge der beiden Stände ändert nichts")
    func mergeIsSymmetric() {
        let lektionId = course.allLessons[0].id
        let a = stand(createdAt: "2026-09-10T10:00:00Z", streak: 2, rekord: 4, aktiv: "2026-09-20T00:00:00Z",
                      lektionen: [lektionId: lektion(best: 0.7, gespielt: 2, fertig: false, zuletzt: "2026-09-20T10:00:00Z")],
                      versuche: [versuch("a", "2026-09-20T10:00:00Z", credit: 1)])
        let b = stand(createdAt: "2026-09-01T10:00:00Z", streak: 5, rekord: 9, aktiv: "2026-09-12T00:00:00Z",
                      lektionen: [lektionId: lektion(best: 0.9, gespielt: 5, fertig: true, zuletzt: "2026-09-12T10:00:00Z")],
                      versuche: [versuch("c", "2026-09-11T11:00:00Z", credit: 1)])

        let hin = ProgressBackup.vereine(a, b, course: course)
        let zurueck = ProgressBackup.vereine(b, a, course: course)
        #expect(hin.attempts.count == zurueck.attempts.count)
        #expect(hin.lessonRecords[lektionId]?.bestAccuracy == zurueck.lessonRecords[lektionId]?.bestAccuracy)
        #expect(hin.masterScore == zurueck.masterScore)
        #expect(hin.longestStreak == zurueck.longestStreak)
        #expect(hin.createdAt == zurueck.createdAt)
    }

    @Test("Die eigene Sicherung wieder einzulesen ändert nichts")
    func reimportingOwnBackupIsANoOp() throws {
        // Der Weg über die Datei ist entscheidend: Beim Schreiben verliert ein Datum seine
        // Sekundenbruchteile. Wird danach nicht mehr erkannt, dass es derselbe Eintrag ist,
        // legt die eigene Sicherung jeden Versuch ein zweites Mal an.
        let lektionId = course.allLessons[0].id
        let eigen = stand(
            createdAt: "2026-09-10T10:00:00Z", streak: 3, rekord: 5, aktiv: "2026-09-20T00:00:00Z",
            lektionen: [lektionId: lektion(best: 0.8, gespielt: 2, fertig: true, zuletzt: "2026-09-20T10:00:00Z")],
            versuche: [
                // Mit Sekundenbruchteilen, wie sie Date.now im Betrieb liefert. Ein
                // glattes Datum würde den Fehler nicht zeigen: Er entsteht erst dadurch,
                // dass die Datei die Bruchteile wegschneidet.
                versuchGenau("a", 1_790_000_000.472, credit: 1),
                versuchGenau("b", 1_790_003_600.918, credit: 0),
                versuchGenau("c", 1_790_007_200.005, credit: 1),
            ]
        )
        let daten = try ProgressBackup.coder.0.encode(ProgressBackup(erstellt: .now, stand: eigen))
        let zurueck = try #require(ProgressBackup.lesen(daten))

        let vereint = ProgressBackup.vereine(eigen, zurueck, course: course)
        #expect(vereint.attempts.count == eigen.attempts.count, "die eigene Sicherung legt Einträge doppelt an")
        #expect(vereint.lessonRecords.count == eigen.lessonRecords.count)
        #expect(vereint.longestStreak == eigen.longestStreak)
    }

    @Test("Eine fremde Datei wird abgelehnt, die eigene wieder gelesen")
    func onlyOwnBackupsAreAccepted() throws {
        let eigen = stand(createdAt: "2026-09-10T10:00:00Z", streak: 1, rekord: 1, aktiv: nil,
                          lektionen: [:], versuche: [versuch("a", "2026-09-20T10:00:00Z", credit: 1)])
        let daten = try ProgressBackup.coder.0.encode(ProgressBackup(erstellt: .now, stand: eigen))
        let gelesen = ProgressBackup.lesen(daten)
        #expect(gelesen?.attempts.count == 1, "eigene Sicherung nicht wieder lesbar")

        #expect(ProgressBackup.lesen(Data("kein JSON".utf8)) == nil)
        #expect(ProgressBackup.lesen(Data(#"{"app":"etwas anderes"}"#.utf8)) == nil)
    }
}
