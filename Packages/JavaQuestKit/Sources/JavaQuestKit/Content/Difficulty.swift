import Foundation

/// Schwierigkeitsgrad einer Aufgabe auf der Skala 1 bis 5.
public enum Difficulty: Int, Codable, CaseIterable, Comparable, Sendable, Identifiable {
    case veryEasy = 1
    case easy = 2
    case medium = 3
    case demanding = 4
    case hard = 5

    public static let scaleMaximum = 5

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .veryEasy: "Sehr leicht"
        case .easy: "Leicht"
        case .medium: "Mittel"
        case .demanding: "Anspruchsvoll"
        case .hard: "Schwer"
        }
    }

    /// Anzeige wie „Niveau: Leicht - 2/5“.
    public var badgeText: String { "Niveau: \(label) - \(rawValue)/\(Self.scaleMaximum)" }

    /// Gewicht in allen Scores: schwere Aufgaben zählen mehr als leichte.
    public var weight: Double { Double(rawValue) }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Liefert den nächstgelegenen gültigen Grad für beliebige Ganzzahlen.
    public static func clamped(_ value: Int) -> Difficulty {
        Difficulty(rawValue: min(max(value, 1), scaleMaximum)) ?? .medium
    }
}
