import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var track: Color = Color.primary.opacity(0.08)
    var fill: AnyShapeStyle = AnyShapeStyle(
        AngularGradient(colors: [Theme.orange, Theme.ember, Theme.violet, Theme.orange], center: .center)
    )

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.0001), 1))
                .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.spring(duration: 0.9), value: progress)
    }
}
