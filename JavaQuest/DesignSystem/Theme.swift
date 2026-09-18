import SwiftUI
import JavaQuestKit

/// Farben, Verläufe und Maße der App. Warmes „Espresso-Orange“ als Akzent,
/// Indigo/Violett für Tiefe; Verläufe bleiben dezent, außer auf der Score-Karte.
enum Theme {
    static let orange = Color(red: 0.96, green: 0.45, blue: 0.13)
    static let ember = Color(red: 0.91, green: 0.26, blue: 0.30)
    static let indigo = Color(red: 0.33, green: 0.31, blue: 0.90)
    static let violet = Color(red: 0.56, green: 0.34, blue: 0.93)
    static let teal = Color(red: 0.08, green: 0.64, blue: 0.62)
    static let success = Color(red: 0.18, green: 0.68, blue: 0.38)

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [indigo, violet, orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [orange, ember], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var successGradient: LinearGradient {
        LinearGradient(colors: [success, teal], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var placementGradient: LinearGradient {
        LinearGradient(colors: [indigo, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let cornerRadius: CGFloat = 22
    static let innerRadius: CGFloat = 14

    #if os(iOS)
    static let screenBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let fieldBackground = Color(uiColor: .tertiarySystemFill)
    #else
    static let screenBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let fieldBackground = Color(nsColor: .quaternaryLabelColor).opacity(0.5)
    #endif

    static func color(for difficulty: Difficulty) -> Color {
        switch difficulty {
        case .veryEasy: teal
        case .easy: success
        case .medium: indigo
        case .demanding: orange
        case .hard: ember
        }
    }

    static func color(for status: TopicStatus) -> Color {
        switch status {
        case .strength: success
        case .developing: indigo
        case .gap: orange
        case .unknown: .gray
        }
    }

    static func color(for tier: ExperienceLevel) -> Color {
        switch tier {
        case .beginner: success
        case .intermediate: indigo
        case .advanced: ember
        }
    }

    static func gradient(for tier: ExperienceLevel) -> LinearGradient {
        let base = color(for: tier)
        return LinearGradient(colors: [base, base.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Farben für Java-Code: immer dunkler Hintergrund, unabhängig vom Erscheinungsbild.
enum CodeTheme {
    static let background = Color(red: 0.11, green: 0.12, blue: 0.16)
    static let chrome = Color(red: 0.15, green: 0.16, blue: 0.21)
    static let plain = Color(white: 0.92)

    static func color(for kind: JavaHighlighter.TokenKind) -> Color {
        switch kind {
        case .plain: plain
        case .keyword: Color(red: 1.00, green: 0.48, blue: 0.70)
        case .type: Color(red: 0.36, green: 0.85, blue: 0.87)
        case .string: Color(red: 0.99, green: 0.53, blue: 0.43)
        case .number: Color(red: 0.85, green: 0.79, blue: 0.47)
        case .comment: Color(red: 0.50, green: 0.55, blue: 0.62)
        case .annotation: Color(red: 0.99, green: 0.62, blue: 0.30)
        }
    }
}

extension Double {
    /// Beherrschung als ganze Prozentzahl. Abgerundet, damit z. B. 54,6 % nicht als
    /// „55 %“ erscheint, obwohl das Thema noch unter der Lückengrenze von 55 % liegt.
    var masteryPercent: Int { Int((self * 100).rounded(.down)) }
}
