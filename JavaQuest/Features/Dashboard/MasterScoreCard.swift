import Charts
import SwiftUI
import JavaQuestKit

/// Prominente Anzeige des Java Master Scores (0–1000) mit Rang, Wochenzuwachs und Verlauf.
struct MasterScoreCard: View {
    let score: Int
    let rank: MasterRank
    let nextRank: MasterRank?
    let progressToNext: Double
    let weeklyDelta: Int
    let history: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    ProgressRing(
                        progress: Double(score) / Double(MasterScore.maximum),
                        lineWidth: 13,
                        track: .white.opacity(0.22),
                        fill: AnyShapeStyle(Color.white)
                    )
                    VStack(spacing: -2) {
                        Text("\(score)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(score)))
                            .minimumScaleFactor(0.6)
                        Text("von \(MasterScore.maximum)")
                            .font(.caption2.weight(.semibold))
                            .opacity(0.75)
                    }
                    .padding(.horizontal, 16)
                }
                .frame(width: 128, height: 128)

                VStack(alignment: .leading, spacing: 8) {
                    Text("JAVA MASTER SCORE")
                        .font(.caption.weight(.heavy))
                        .tracking(1.4)
                        .opacity(0.8)
                    Label(rank.title, systemImage: rank.symbolName)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if weeklyDelta > 0 {
                        Label("+\(weeklyDelta) in 7 Tagen", systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    if let nextRank {
                        Text("Nächster Rang: \(nextRank.title)")
                        Spacer()
                        Text("noch \(nextRank.minimumScore - score) Punkte").monospacedDigit()
                    } else {
                        Text("Höchster Rang erreicht – Respekt!")
                        Spacer()
                    }
                }
                .font(.footnote.weight(.semibold))
                ProgressBar(value: progressToNext, tint: AnyShapeStyle(Color.white), track: .white.opacity(0.22), height: 7)
            }

            if history.count >= 2 {
                ScoreSparkline(values: history)
                    .frame(height: 46)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.heroGradient)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(.white.opacity(0.08))
                        .rotationEffect(.degrees(-12))
                        .offset(x: 24, y: -18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .shadow(color: Theme.violet.opacity(0.35), radius: 22, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Java Master Score \(score) von \(MasterScore.maximum), Rang \(rank.title)"))
    }
}

private struct ScoreSparkline: View {
    let values: [Int]

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            AreaMark(x: .value("Schritt", index), y: .value("Score", value))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Schritt", index), y: .value("Score", value))
                .interpolationMethod(.monotone)
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
    }

    /// Unterkante knapp unter dem Minimum, damit der Anstieg sichtbar wird.
    private var yDomain: ClosedRange<Int> {
        let low = values.min() ?? 0
        let high = max(values.max() ?? 0, low + 20)
        return max(0, low - (high - low) / 2 - 10)...high
    }
}
