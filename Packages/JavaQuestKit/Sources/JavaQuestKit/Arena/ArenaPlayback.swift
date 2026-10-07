import Foundation

/// Tempo der Wiedergabe: Wie lange jedes Standbild stehen bleibt.
///
/// Fragen an Byte („Ist vorne frei?“) bewegen ihn nicht und ziehen deshalb schneller vorbei als
/// Fahrten. Und eine lange Fahrt – im Labyrinth über 200 Bilder – wird schneller abgespielt, damit
/// niemand anderthalb Minuten zuschauen muss: Beim gewählten Tempo dauert keine Wiedergabe länger
/// als `maxSteps` normale Schritte.
public enum ArenaPlayback {
    /// Anteil einer normalen Schrittdauer, den eine Frage bekommt.
    public static let questionWeight = 0.4
    /// So viele normale Schritte lang darf eine Wiedergabe höchstens dauern.
    public static let maxSteps = 50.0
    /// Kürzer wird kein Bild – sonst sieht man die Bewegung nicht mehr.
    public static let minimumDelay = 0.05

    /// Wartezeit in Sekunden, bevor Bild `i` erscheint (`[0]` ist das Startbild und immer 0).
    /// `base` ist die Dauer eines normalen Schritts beim gewählten Tempo.
    public static func delays(for frames: [ArenaFrame], base: Double) -> [Double] {
        guard !frames.isEmpty else { return [] }
        let weights = frames.enumerated().map { index, frame in
            index == 0 ? 0 : weight(of: frame.action)
        }
        let total = weights.reduce(0, +)
        let scale = total > maxSteps ? maxSteps / total : 1
        return weights.enumerated().map { index, weight in
            index == 0 ? 0 : max(base * weight * scale, minimumDelay)
        }
    }

    static func weight(of action: ArenaAction) -> Double {
        if case .look = action { return questionWeight }
        return 1
    }
}
