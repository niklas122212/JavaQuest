import Foundation

/// Wann an fällige Wiederholungen erinnert wird.
///
/// Das verteilte Wiederholen (siehe `SpacedRepetition`) wirkt nur, wenn man im richtigen
/// Abstand zurückkommt – und daran hat lange nichts erinnert. Die Termine hier sind bewusst
/// sparsam: nur an Tagen, an denen zur gewählten Uhrzeit wirklich etwas fällig ist, und
/// höchstens `maxCount` Tage hintereinander, falls niemand reinschaut. Wer übt, bekommt
/// neue Termine; wer nicht übt, wird nicht endlos angemahnt.
///
/// Dieselbe Rechnung steht in der Web-App (`erinnerungsTermine` in Web/app.js).
public enum ReviewReminder {
    /// Höchstens so viele Erinnerungen in Folge, wenn niemand übt.
    public static let maxCount = 3
    /// Vorgeschlagene Uhrzeit: nach Schule oder Arbeit, vor dem Abend.
    public static let defaultMinutes = 18 * 60

    public struct Slot: Hashable, Sendable {
        public let date: Date
        /// So viele Lernziele sind zu diesem Zeitpunkt fällig.
        public let count: Int

        public init(date: Date, count: Int) {
            self.date = date
            self.count = count
        }
    }

    /// Die nächsten Erinnerungen zur Uhrzeit `hour:minute` – leer, wenn nichts ansteht.
    public static func plan(dueDates: [Date], now: Date, hour: Int, minute: Int,
                            calendar: Calendar, maxCount: Int = maxCount) -> [Slot] {
        guard let earliest = dueDates.min() else { return [] }
        var day = calendar.startOfDay(for: max(now, earliest))
        var slots: [Slot] = []
        // Spätestens einen Tag nach dem frühesten Termin ist etwas fällig; die Schranke
        // verhindert trotzdem jede Endlosschleife bei einem kaputten Kalender.
        for _ in 0..<(maxCount + 2) where slots.count < maxCount {
            if let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day), time > now {
                let count = dueDates.filter { $0 <= time }.count
                if count > 0 { slots.append(Slot(date: time, count: count)) }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return slots
    }

    /// Der Text der Mitteilung.
    public static func message(count: Int) -> String {
        count == 1
            ? "1 Lernziel wartet auf die Wiederholung – kurz reinschauen, bevor es verblasst."
            : "\(count) Lernziele warten auf die Wiederholung – kurz reinschauen, bevor es verblasst."
    }
}
