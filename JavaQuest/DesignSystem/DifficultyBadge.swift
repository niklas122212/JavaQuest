import SwiftUI
import JavaQuestKit

/// Gut sichtbare Niveau-Anzeige neben jeder Aufgabe: „Niveau: Leicht - 2/5“ plus
/// fünf ansteigende Balken. Die Farbe wandert von Türkis (1) bis Rot (5).
struct DifficultyBadge: View {
    let difficulty: Difficulty
    var compact = false

    private var tint: Color { Theme.color(for: difficulty) }

    var body: some View {
        HStack(spacing: 8) {
            if !compact {
                Text(difficulty.badgeText)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            } else {
                Text("\(difficulty.rawValue)/\(Difficulty.scaleMaximum)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            }
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(1...Difficulty.scaleMaximum, id: \.self) { level in
                    Capsule()
                        .fill(level <= difficulty.rawValue ? tint : tint.opacity(0.22))
                        .frame(width: 4, height: 5 + CGFloat(level) * 2)
                }
            }
        }
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 4 : 6)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.3)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(difficulty.badgeText))
    }
}
