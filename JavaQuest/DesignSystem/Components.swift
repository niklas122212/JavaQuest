import SwiftUI
import JavaQuestKit

// MARK: - Karte

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            }
            .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View { modifier(CardModifier(padding: padding)) }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fill: LinearGradient = Theme.accentGradient
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.orange
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(tint.opacity(configuration.isPressed ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Kleine Bausteine

struct Chip: View {
    let text: String
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(Theme.orange)
                }
                Text(title).font(.title3.weight(.bold))
            }
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Symbol in einem abgerundeten, farbigen Quadrat (wie in den Systemeinstellungen).
struct IconTile: View {
    let systemImage: String
    var tint: Color = Theme.orange
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
    }
}

struct ProgressBar: View {
    var value: Double
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.accentGradient)
    var track: Color = Color.primary.opacity(0.08)
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, proxy.size.width * min(max(value, 0), 1)))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.6), value: value)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((value * 100).rounded())) Prozent"))
    }
}

struct StarsView: View {
    let count: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .foregroundStyle(index < count ? Color.yellow : Color.secondary.opacity(0.5))
            }
        }
        .font(.system(size: size, weight: .bold))
        .accessibilityElement()
        .accessibilityLabel(Text("\(count) von 3 Sternen"))
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    let systemImage: String
    var tint: Color = Theme.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .card(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

/// Hinweisbox für Theorie-Karten (Tipp, Achtung, Info).
struct CalloutView: View {
    let callout: TheoryCard.Callout

    private var style: (symbol: String, tint: Color, title: String) {
        switch callout.kind {
        case .tip: ("lightbulb.fill", Theme.success, "Tipp")
        case .warning: ("exclamationmark.triangle.fill", Theme.orange, "Achtung")
        case .info: ("info.circle.fill", Theme.indigo, "Gut zu wissen")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: style.symbol)
                .font(.title3)
                .foregroundStyle(style.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(style.title).font(.subheadline.weight(.bold))
                Text(callout.text).font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(style.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous)
                .strokeBorder(style.tint.opacity(0.25))
        }
    }
}
