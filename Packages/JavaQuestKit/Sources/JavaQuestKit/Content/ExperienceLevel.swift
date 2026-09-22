import Foundation

/// Selbsteinschätzung beim App-Start. Jede Stufe hat ein Einstiegsmodul im Kurs.
public enum ExperienceLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    case beginner
    case intermediate
    case advanced

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .beginner: "Anfänger"
        case .intermediate: "Leicht fortgeschritten"
        case .advanced: "Erfahren"
        }
    }

    public var summary: String {
        switch self {
        case .beginner:
            "Keine Vorkenntnisse. Du startest direkt mit kurzer Theorie und sehr einfachen Aufgaben."
        case .intermediate:
            "Variablen, Bedingungen, Schleifen und Methoden kennst du schon."
        case .advanced:
            "Klassen, Vererbung, Exceptions und Collections sind dir vertraut."
        }
    }

    public var symbolName: String {
        switch self {
        case .beginner: "leaf.fill"
        case .intermediate: "flame.fill"
        case .advanced: "bolt.fill"
        }
    }

    /// Die beiden Wahlmöglichkeiten beim App-Start.
    public static let onboardingChoices: [ExperienceLevel] = [.beginner, .intermediate]

    /// Text der Auswahl beim App-Start.
    public var onboardingTitle: String {
        switch self {
        case .beginner: "Ich habe 0 Erfahrung"
        case .intermediate, .advanced: "Ich habe schon Vorkenntnisse"
        }
    }

    public var onboardingSummary: String {
        switch self {
        case .beginner:
            "Kein Problem! Du startest mit dem Grundkurs: kurze Theorie, jede Codezeile erklärt, sehr einfache Aufgaben."
        case .intermediate, .advanced:
            "Beantworte fünf kurze Fragen. Sie passen sich an: Nach einer richtigen Antwort wird es schwerer, nach einer falschen leichter. Ab 65 % überspringst du den Grundkurs, ab 85 % auch den Mittelteil."
        }
    }

    /// Nur mit Vorkenntnissen gibt es die Einstufungsfrage.
    public var requiresPlacement: Bool { self == .intermediate }

    /// Stufe, auf die bei nicht bestandenem Einstufungstest zurückgefallen wird.
    public var fallback: ExperienceLevel {
        switch self {
        case .beginner, .intermediate: .beginner
        case .advanced: .intermediate
        }
    }
}
