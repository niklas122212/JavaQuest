import Foundation

/// Kopien vom Zurücksetzen des Lernstands.
///
/// „Fortschritt zurücksetzen“ löschte sofort und endgültig – in allen drei Fassungen. Jetzt
/// bleibt vorher eine Kopie liegen, im Aufbau der Sicherungsdatei, und lässt sich
/// wiederherstellen. Hier stehen die Regeln dafür, damit sie ohne Dateisystem prüfbar sind;
/// dieselben gelten unter Windows (ProgressStore.kt) und im Web (app.js):
///
/// * eine Kopie nur, wenn es etwas zu verlieren gibt – sonst würde ein zweites Zurücksetzen
///   die wertvolle erste Kopie mit einem leeren Stand verdrängen,
/// * die fünf jüngsten bleiben,
/// * nach dem Wiederherstellen wird die Kopie umbenannt, nicht gelöscht.
public enum ResetCopies {
    public static let maxCount = 5

    public static func fileName(for date: Date) -> String {
        "stand-\(stamp.string(from: date)).json"
    }

    public static func isCopy(_ fileName: String) -> Bool {
        fileName.range(of: #"^stand-\d{8}-\d{6}\.json$"#, options: .regularExpression) != nil
    }

    /// Nur die Kopien, die jüngste zuerst – der Zeitstempel im Namen sortiert von selbst.
    public static func newestFirst(_ fileNames: [String]) -> [String] {
        fileNames.filter(isCopy).sorted(by: >)
    }

    public static func restoredName(_ fileName: String) -> String {
        fileName.replacingOccurrences(of: ".json", with: ".wiederhergestellt.json")
    }

    public static func worthKeeping(_ stand: ProgressBackup.Stand) -> Bool {
        !stand.attempts.isEmpty || !stand.lessonRecords.isEmpty
    }

    /// „Vom 24.09.2026, 10:20 Uhr · 8 Lektionen bestanden · 102 Aufgaben“ – wie in den anderen Fassungen.
    public static func summary(_ stand: ProgressBackup.Stand, created: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        let lessons = stand.lessonRecords.values.filter(\.isCompleted).count
        let tasks = Set(stand.attempts.map(\.taskId)).count
        return "Vom \(formatter.string(from: created)) Uhr · "
            + "\(lessons) \(lessons == 1 ? "Lektion" : "Lektionen") bestanden · "
            + "\(tasks) \(tasks == 1 ? "Aufgabe" : "Aufgaben")"
    }

    private static var stamp: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
