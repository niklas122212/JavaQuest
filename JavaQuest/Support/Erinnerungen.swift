import Foundation
import UserNotifications
import JavaQuestKit

/// Meldet die Erinnerungen an fällige Wiederholungen beim System an.
///
/// Die Termine rechnet `ReviewReminder` im Kern; hier werden sie nur als Mitteilungen
/// eingetragen. Nach jeder Änderung am Lernstand wird neu geplant – wer übt, schiebt die
/// nächste Erinnerung damit automatisch nach hinten. Ausgeschaltet ist die Voreinstellung:
/// Mitteilungen gibt es erst, wenn man sie in den Einstellungen einschaltet.
@MainActor
enum Erinnerungen {
    static let anSchluessel = "erinnerung.an"
    static let minutenSchluessel = "erinnerung.minuten"
    private static let kennungen = (0..<ReviewReminder.maxCount).map { "javaquest.wiederholung.\($0)" }

    static var an: Bool { UserDefaults.standard.bool(forKey: anSchluessel) }

    /// Uhrzeit als Minuten seit Mitternacht, vorgeschlagen 18:00.
    static var minuten: Int {
        UserDefaults.standard.object(forKey: minutenSchluessel) as? Int ?? ReviewReminder.defaultMinutes
    }

    static func termine(for store: ProgressStore, now: Date = .now) -> [ReviewReminder.Slot] {
        ReviewReminder.plan(dueDates: store.goalHistory.values.map(\.dueDate), now: now,
                            hour: minuten / 60, minute: minuten % 60, calendar: .current)
    }

    /// Ersetzt die angemeldeten Erinnerungen durch die aktuell passenden – oder entfernt sie.
    static func planen(for store: ProgressStore) {
        let zentrale = UNUserNotificationCenter.current()
        zentrale.removePendingNotificationRequests(withIdentifiers: kennungen)
        guard an else { return }
        for (kennung, termin) in zip(kennungen, termine(for: store)) {
            let inhalt = UNMutableNotificationContent()
            inhalt.title = "JavaQuest"
            inhalt.body = ReviewReminder.message(count: termin.count)
            inhalt.sound = .default
            let teile = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: termin.date)
            let ausloeser = UNCalendarNotificationTrigger(dateMatching: teile, repeats: false)
            zentrale.add(UNNotificationRequest(identifier: kennung, content: inhalt, trigger: ausloeser))
        }
    }

    /// Fragt einmal nach der Erlaubnis. Wer ablehnt, bekommt keine Mitteilungen – die
    /// Einstellung springt dann zurück, statt still wirkungslos zu bleiben.
    static func erlaubnisHolen() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
