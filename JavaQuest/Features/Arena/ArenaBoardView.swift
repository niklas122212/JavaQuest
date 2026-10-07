import SwiftUI
import JavaQuestKit

/// Das Spielfeld der Arena: Wände, Münzen, Zielflagge und Byte, der Roboter.
/// Bewegungen und Drehungen werden animiert, ein Unfall lässt Byte wackeln.
struct ArenaBoardView: View {
    let world: ArenaWorldSpec
    let state: ArenaBoardState
    var crashCount = 0
    var animationDuration: Double = 0.3
    /// Höchstens so hoch wird das Feld (auf dem iPhone wichtig, damit der Code sichtbar bleibt).
    var maxHeight: CGFloat = 360

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let cell = cellSize(in: proxy.size)
            let width = cell * CGFloat(world.width)
            let height = cell * CGFloat(world.height)
            ZStack(alignment: .topLeading) {
                tiles(cell: cell)
                if let goal = world.goal {
                    GoalFlag(size: cell)
                        .position(center(goal, cell: cell))
                }
                ForEach(Array(state.coins).sorted(), id: \.self) { coin in
                    CoinView(size: cell * 0.5)
                        .position(center(coin, cell: cell))
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
                RobotView(size: cell * 0.78, isCrashed: state.isCrashed)
                    .rotationEffect(.degrees(state.angle))
                    .modifier(ShakeEffect(shakes: reduceMotion ? 0 : CGFloat(crashCount)))
                    .position(center(state.robot, cell: cell))
                    .animation(reduceMotion ? nil : .easeInOut(duration: animationDuration), value: state.robot)
                    .animation(reduceMotion ? nil : .easeInOut(duration: animationDuration), value: state.angle)
                    .animation(.easeInOut(duration: 0.4), value: crashCount)
                if case .look(let question, let answer) = state.action {
                    QuestionBubble(question: question, answer: answer)
                        .position(x: center(state.robot, cell: cell).x, y: max(center(state.robot, cell: cell).y - cell * 0.85, 14))
                        .transition(.opacity)
                }
            }
            .frame(width: width, height: height)
            .animation(.easeOut(duration: 0.25), value: state.coins)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(CGFloat(world.width) / CGFloat(max(world.height, 1)), contentMode: .fit)
        .frame(maxHeight: maxHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private func cellSize(in size: CGSize) -> CGFloat {
        min(size.width / CGFloat(max(world.width, 1)), size.height / CGFloat(max(world.height, 1)))
    }

    private func center(_ point: GridPoint, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(point.x) + 0.5) * cell, y: (CGFloat(point.y) + 0.5) * cell)
    }

    private func tiles(cell: CGFloat) -> some View {
        Canvas { context, _ in
            for y in 0..<world.height {
                for x in 0..<world.width {
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                    let point = GridPoint(x: x, y: y)
                    if world.isWall(point) {
                        let wall = Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: cell * 0.16)
                        context.fill(wall, with: .color(ArenaColors.wall))
                        let shine = Path(roundedRect: rect.insetBy(dx: cell * 0.18, dy: cell * 0.18), cornerRadius: cell * 0.1)
                        context.fill(shine, with: .color(ArenaColors.wallTop))
                    } else {
                        let floor = Path(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: cell * 0.14)
                        let isGoal = point == world.goal
                        context.fill(floor, with: .color(isGoal ? ArenaColors.goalFloor : ((x + y).isMultiple(of: 2) ? ArenaColors.floor : ArenaColors.floorAlt)))
                    }
                }
            }
        }
    }

    private var accessibilityText: String {
        let directions: [Heading: String] = [.north: "nach oben", .east: "nach rechts", .south: "nach unten", .west: "nach links"]
        let heading = Heading.allCases.first { abs((($0.degrees - state.angle).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)) < 1 } ?? .east
        var text = "Spielfeld \(world.width) mal \(world.height). Byte steht in Spalte \(state.robot.x + 1), Zeile \(state.robot.y + 1) und schaut \(directions[heading] ?? "")."
        text += state.coins.isEmpty ? " Keine Münzen mehr." : " Noch \(state.coins.count) Münzen."
        if let goal = world.goal { text += " Ziel in Spalte \(goal.x + 1), Zeile \(goal.y + 1)." }
        return text
    }
}

enum ArenaColors {
    static let wall = Color(red: 0.24, green: 0.25, blue: 0.36)
    static let wallTop = Color(red: 0.31, green: 0.32, blue: 0.45)
    static let floor = Color(red: 0.93, green: 0.92, blue: 0.97)
    static let floorAlt = Color(red: 0.89, green: 0.88, blue: 0.95)
    static let goalFloor = Theme.success.opacity(0.28)
    static let coin = Color(red: 1.0, green: 0.78, blue: 0.18)
    static let coinEdge = Color(red: 0.86, green: 0.56, blue: 0.05)
    static let board = Color(red: 0.16, green: 0.17, blue: 0.25)
}

/// Byte: ein runder Roboter mit Augen und Antenne. Die Augen zeigen in Blickrichtung (rechts = 0°).
struct RobotView: View {
    let size: CGFloat
    var isCrashed = false

    var body: some View {
        ZStack {
            // Nase zeigt die Fahrtrichtung
            Triangle()
                .fill(isCrashed ? Theme.ember : Theme.orange)
                .frame(width: size * 0.26, height: size * 0.32)
                .offset(x: size * 0.48)
            Circle()
                .fill(LinearGradient(colors: isCrashed ? [Theme.ember, Theme.ember.opacity(0.75)] : [Theme.orange, Theme.ember],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: max(size * 0.06, 1.5)))
            // Augen
            HStack(spacing: size * 0.14) {
                Eye(size: size * 0.2, isCrashed: isCrashed)
                Eye(size: size * 0.2, isCrashed: isCrashed)
            }
            .rotationEffect(.degrees(90))
            .offset(x: size * 0.16)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.3), radius: size * 0.08, y: size * 0.05)
    }

    private struct Eye: View {
        let size: CGFloat
        let isCrashed: Bool

        var body: some View {
            if isCrashed {
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.9, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(.white)
                    .overlay(Circle().fill(ArenaColors.board).padding(size * 0.25))
                    .frame(width: size, height: size)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CoinView: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [ArenaColors.coin, ArenaColors.coinEdge], center: .topLeading, startRadius: 0, endRadius: size))
            .overlay(Circle().strokeBorder(ArenaColors.coinEdge, lineWidth: max(size * 0.1, 1)).padding(size * 0.14))
            .overlay(Text("€").font(.system(size: size * 0.48, weight: .heavy, design: .rounded)).foregroundStyle(ArenaColors.coinEdge))
            .frame(width: size, height: size)
            .shadow(color: ArenaColors.coinEdge.opacity(0.4), radius: size * 0.1, y: size * 0.05)
    }
}

struct GoalFlag: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "flag.checkered")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(Theme.success)
            .frame(width: size, height: size)
    }
}

/// Sprechblase, wenn Byte etwas gefragt wird – z. B. „vorne frei? ja“.
private struct QuestionBubble: View {
    let question: String
    let answer: String

    private var text: String {
        let label = RobotCommand.all.first { $0.name == question }?.summary ?? question
        return "\(label) \(answer == "true" ? "ja" : "nein")"
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(answer == "true" ? Theme.success : Theme.indigo, in: Capsule())
            .shadow(radius: 2)
    }
}

/// Kurzes Wackeln – jede Erhöhung von `shakes` löst eine Wackelbewegung aus.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(shakes * .pi * 6) * 6, y: 0))
    }
}

#if DEBUG
#Preview("Spielfeld") {
    let world = ArenaWorldSpec(map: ["#######", "####.G#", "###.o##", "##..###", "#.o####", "#R#####", "#######"])
    ArenaBoardView(
        world: world,
        state: ArenaBoardState(robot: GridPoint(x: 1, y: 5), angle: 0, coins: world.coins, collected: 0, action: .look(question: "frontIsClear", answer: "false"), isCrashed: false)
    )
    .padding()
    .background(ArenaColors.board)
}
#endif
