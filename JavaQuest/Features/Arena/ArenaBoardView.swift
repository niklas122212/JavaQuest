import SwiftUI
import JavaQuestKit

/// Das Spielfeld der Arena: Wände, Münzen, Zielflagge und Byte, der Roboter.
/// Bewegungen und Drehungen werden animiert, ein Unfall lässt Byte wackeln. Eine Punktspur zeigt,
/// wo er schon war; „+1“ steigt beim Aufheben auf, und bei einer gelösten Mission hüpft Byte.
struct ArenaBoardView: View {
    let world: ArenaWorldSpec
    let state: ArenaBoardState
    var crashCount = 0
    /// Erhöht sich, wenn eine gelöste Mission zu Ende abgespielt ist – Byte hüpft, die Flagge wippt.
    var celebrationCount = 0
    var animationDuration: Double = 0.3
    /// Höchstens so hoch wird das Feld (auf dem iPhone wichtig, damit der Code sichtbar bleibt).
    var maxHeight: CGFloat = 360

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var availableWidth: CGFloat = 0

    private var ratio: CGFloat { CGFloat(max(world.width, 1)) / CGFloat(max(world.height, 1)) }

    /// Höhe aus der verfügbaren Breite: Ein flaches Feld bekommt keinen leeren Rand oben und unten.
    private var boardHeight: CGFloat {
        availableWidth > 0 ? min(maxHeight, availableWidth / ratio) : min(maxHeight, 200)
    }

    var body: some View {
        GeometryReader { proxy in
            let cell = cellSize(in: proxy.size)
            let width = cell * CGFloat(world.width)
            let height = cell * CGFloat(world.height)
            // Außerhalb des Animations-Closures auslesen (das läuft nicht auf dem Main Actor).
            let hopHeight = reduceMotion ? 0 : cell
            ZStack(alignment: .topLeading) {
                tiles(cell: cell)
                TrailShape(points: state.trail.map { center($0, cell: cell) })
                    .stroke(Theme.orange.opacity(0.55), style: StrokeStyle(lineWidth: max(cell * 0.11, 2.5), lineCap: .round, lineJoin: .round, dash: [0.1, cell * 0.24]))
                if let goal = world.goal {
                    GoalFlag(size: cell)
                        .keyframeAnimator(initialValue: 1.0, trigger: celebrationCount) { flag, scale in
                            flag.scaleEffect(scale)
                        } keyframes: { _ in
                            SpringKeyframe(1.35, duration: 0.25)
                            SpringKeyframe(1.0, duration: 0.35)
                        }
                        .position(center(goal, cell: cell))
                }
                ForEach(Array(state.coins).sorted(), id: \.self) { coin in
                    CoinView(size: cell * 0.5)
                        .position(center(coin, cell: cell))
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
                if case .crash(let wall?) = state.action {
                    ImpactMark(size: cell)
                        .id(state.step)
                        .position(center(wall, cell: cell))
                }
                RobotView(size: cell * 0.78, isCrashed: state.isCrashed)
                    .rotationEffect(.degrees(state.angle))
                    .modifier(ShakeEffect(shakes: reduceMotion ? 0 : CGFloat(crashCount)))
                    .keyframeAnimator(initialValue: 0.0, trigger: celebrationCount) { robot, hop in
                        robot.offset(y: hop * hopHeight)
                    } keyframes: { _ in
                        SpringKeyframe(-0.3, duration: 0.18)
                        SpringKeyframe(0, duration: 0.2)
                        SpringKeyframe(-0.18, duration: 0.15)
                        SpringKeyframe(0, duration: 0.2)
                    }
                    .position(center(state.robot, cell: cell))
                    .animation(reduceMotion ? nil : .easeInOut(duration: animationDuration), value: state.robot)
                    .animation(reduceMotion ? nil : .easeInOut(duration: animationDuration), value: state.angle)
                    .animation(.easeInOut(duration: 0.4), value: crashCount)
                if case .pickCoin = state.action, !reduceMotion {
                    PickupPop(size: cell)
                        .id(state.step)
                        .position(center(state.robot, cell: cell))
                }
                if let bubble = bubble {
                    SpeechBubble(text: bubble.text, tint: bubble.tint)
                        .position(x: clampedX(center(state.robot, cell: cell).x, text: bubble.text, width: width),
                                  y: max(center(state.robot, cell: cell).y - cell * 0.85, 14))
                        .transition(.opacity)
                }
            }
            .frame(width: width, height: height)
            .animation(.easeOut(duration: 0.25), value: state.coins)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: boardHeight)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    /// Sprechblase über Byte: eine Frage mit Antwort – oder ein Griff ins Leere.
    private var bubble: (text: String, tint: Color)? {
        switch state.action {
        case .look(let question, let answer):
            let label = RobotCommand.all.first { $0.name == question }?.summary ?? question
            return ("\(label) \(answer == "true" ? "ja" : "nein")", answer == "true" ? Theme.success : Theme.indigo)
        case .crash(wall: nil):
            return ("Hier liegt keine Münze!", Theme.ember)
        default:
            return nil
        }
    }

    /// Hält die Sprechblase innerhalb des Spielfelds – am Rand ragte sie sonst hinaus.
    private func clampedX(_ x: CGFloat, text: String, width: CGFloat) -> CGFloat {
        let half = min(CGFloat(text.count) * 3.4 + 12, width / 2)
        return min(max(x, half), width - half)
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

/// Sprechblase über Byte – z. B. „Ist vorne frei? ja“.
private struct SpeechBubble: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(tint, in: Capsule())
            .shadow(radius: 2)
    }
}

/// Der Weg, den Byte gefahren ist – als Linie durch die Feldmitten (gestrichelt zu Punkten).
private struct TrailShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first, points.count > 1 else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }
}

/// „+1“ steigt auf, wenn Byte eine Münze aufhebt.
private struct PickupPop: View {
    let size: CGFloat
    @State private var risen = false

    var body: some View {
        Text("+1")
            .font(.system(size: max(size * 0.32, 11), weight: .heavy, design: .rounded))
            .foregroundStyle(ArenaColors.coin)
            .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
            .offset(y: risen ? -size * 0.75 : -size * 0.2)
            .opacity(risen ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.55)) { risen = true } }
            .allowsHitTesting(false)
    }
}

/// Aufprall an der Wand, gegen die Byte gefahren ist.
private struct ImpactMark: View {
    let size: CGFloat
    @State private var shown = false

    var body: some View {
        Image(systemName: "burst.fill")
            .font(.system(size: size * 0.62, weight: .bold))
            .foregroundStyle(Theme.ember)
            .shadow(color: Theme.ember.opacity(0.6), radius: size * 0.12)
            .scaleEffect(shown ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { shown = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Konfetti über dem ganzen Bildschirm, wenn eine Mission gelöst ist. Jede Erhöhung von `trigger` löst eine Ladung aus.
struct ConfettiBurst: View {
    let trigger: Int
    @State private var start: Date?
    @State private var pieces: [Piece] = []

    private static let lifetime = 2.4
    private static let colors: [Color] = [Theme.orange, ArenaColors.coin, Theme.success, Theme.indigo, Theme.violet, Theme.teal, .white]

    struct Piece {
        let x: Double, drift: Double, speed: Double, spin: Double, delay: Double
        let width: Double, height: Double
        let color: Color
    }

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let fade = max(0, 1 - t / (Self.lifetime - piece.delay))
                    let x = (piece.x + piece.drift * t + sin(t * 4 + piece.spin) * 0.02) * size.width
                    let y = (-0.08 + piece.speed * t + 0.22 * t * t) * size.height
                    var layer = context
                    layer.opacity = fade
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(piece.spin * t * 3))
                    layer.fill(Path(CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in
            pieces = (0..<110).map { _ in
                Piece(x: .random(in: 0.05...0.95), drift: .random(in: -0.12...0.12), speed: .random(in: 0.15...0.45),
                      spin: .random(in: -3...3), delay: .random(in: 0...0.35),
                      width: .random(in: 5...9), height: .random(in: 3...6), color: Self.colors.randomElement()!)
            }
            let begin = Date.now
            start = begin
            Task {
                try? await Task.sleep(for: .seconds(Self.lifetime))
                // Eine neuere Ladung läuft weiter.
                if start == begin { start = nil }
            }
        }
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
        state: ArenaBoardState(robot: GridPoint(x: 1, y: 5), angle: 0, coins: world.coins, collected: 0, action: .look(question: "frontIsClear", answer: "false"), isCrashed: false,
                               step: 3, trail: [GridPoint(x: 1, y: 4), GridPoint(x: 2, y: 4), GridPoint(x: 2, y: 3)])
    )
    .padding()
    .background(ArenaColors.board)
}
#endif
