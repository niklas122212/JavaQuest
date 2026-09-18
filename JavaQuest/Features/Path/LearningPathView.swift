import SwiftUI
import JavaQuestKit

/// Lernpfad als geschwungener Weg: Module als Etappen, Lektionen als Stationen.
struct LearningPathView: View {
    var focusModuleId: String?
    @Environment(ProgressStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var lockedHint: String?

    private var title: String {
        focusModuleId.flatMap { id in store.course.modules.first { $0.id == id }?.title } ?? "Lernpfad"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LearningPathContent(focusModuleId: focusModuleId) { lesson, state in
                    if state.isPlayable {
                        router.startLesson(lesson.id)
                    } else {
                        let previous = store.course.allLessons.last { store.lessonStates[$0.id] == .current }
                        lockedHint = previous.map { "Schließe zuerst „\($0.title)“ ab, dann geht es hier weiter." }
                            ?? "Diese Lektion ist noch gesperrt."
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                if let current = store.nextLesson?.id, focusModuleId == nil {
                    proxy.scrollTo(current, anchor: .center)
                }
            }
        }
        .background(Theme.screenBackground)
        .navigationTitle(title)
        .alert("Noch gesperrt", isPresented: Binding(get: { lockedHint != nil }, set: { if !$0 { lockedHint = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockedHint ?? "")
        }
    }
}

struct LearningPathContent: View {
    var focusModuleId: String?
    let onSelect: (Lesson, LessonState) -> Void
    @Environment(ProgressStore.self) private var store

    var body: some View {
        let states = store.lessonStates
        let progress = store.moduleProgress
        VStack(spacing: 18) {
            ForEach(Array(progress.enumerated()), id: \.element.id) { index, module in
                if focusModuleId == nil || focusModuleId == module.id {
                    ModuleHeaderCard(number: index + 1, progress: module)
                    WindingLessonPath(lessons: module.module.lessons, states: states, tint: Theme.color(for: module.module.tier), onSelect: onSelect)
                }
            }
        }
    }
}

private struct ModuleHeaderCard: View {
    let number: Int
    let progress: ModuleProgress

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: progress.isUnlocked ? progress.module.symbol : "lock.fill",
                     tint: progress.isUnlocked ? Theme.color(for: progress.module.tier) : .gray,
                     size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("MODUL \(number) · \(progress.module.tier.title.uppercased())")
                    .font(.caption.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(Theme.color(for: progress.module.tier))
                Text(progress.module.title).font(.title3.weight(.bold))
                Text(progress.module.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            ZStack {
                ProgressRing(progress: progress.fraction, lineWidth: 5, fill: AnyShapeStyle(Theme.color(for: progress.module.tier)))
                Text("\(progress.completedLessons)/\(progress.totalLessons)")
                    .font(.caption.weight(.bold).monospacedDigit())
            }
            .frame(width: 50, height: 50)
        }
        .card(padding: 16)
        .opacity(progress.isUnlocked ? 1 : 0.6)
        .accessibilityElement(children: .combine)
    }
}

/// Stationen abwechselnd links und rechts, verbunden durch eine geschwungene Linie.
/// Bereits erreichte Abschnitte sind farbig, der Rest gestrichelt.
struct WindingLessonPath: View {
    let lessons: [Lesson]
    let states: [String: LessonState]
    let tint: Color
    let onSelect: (Lesson, LessonState) -> Void

    private let rowHeight: CGFloat = 118
    private let swing: CGFloat = 62

    var body: some View {
        GeometryReader { proxy in
            let points = nodePositions(width: proxy.size.width)
            let labelWidth = min(210, proxy.size.width / 2 + swing - 56)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for index in points.indices.dropFirst() {
                        let start = points[index - 1]
                        let end = points[index]
                        var path = Path()
                        path.move(to: start)
                        path.addCurve(to: end,
                                      control1: CGPoint(x: start.x, y: start.y + rowHeight * 0.55),
                                      control2: CGPoint(x: end.x, y: end.y - rowHeight * 0.55))
                        let reached = states[lessons[index].id]?.isPlayable == true
                        context.stroke(path,
                                       with: .color(reached ? tint : Color.secondary.opacity(0.3)),
                                       style: StrokeStyle(lineWidth: reached ? 6 : 4, lineCap: .round, dash: reached ? [] : [2, 10]))
                    }
                }

                ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                    let state = states[lesson.id] ?? .locked
                    let point = points[index]
                    let labelOnRight = index.isMultiple(of: 2)
                    Button { onSelect(lesson, state) } label: {
                        LessonNode(state: state, number: index + 1, tint: tint)
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .id(lesson.id)
                    .accessibilityLabel(Text("\(lesson.title), \(accessibilityState(state))"))

                    LessonNodeLabel(lesson: lesson, state: state, alignment: labelOnRight ? .leading : .trailing)
                        .frame(width: labelWidth, alignment: labelOnRight ? .leading : .trailing)
                        .position(x: labelOnRight ? point.x + 46 + labelWidth / 2 : point.x - 46 - labelWidth / 2, y: point.y)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: rowHeight * CGFloat(lessons.count))
    }

    private func nodePositions(width: CGFloat) -> [CGPoint] {
        lessons.indices.map { index in
            CGPoint(x: width / 2 + (index.isMultiple(of: 2) ? -swing : swing),
                    y: rowHeight * (CGFloat(index) + 0.5))
        }
    }

    private func accessibilityState(_ state: LessonState) -> String {
        switch state {
        case .locked: "gesperrt"
        case .current: "als Nächstes dran"
        case .completed(let stars, let viaPlacement): viaPlacement ? "durch Einstufung freigeschaltet" : "abgeschlossen mit \(stars) Sternen"
        }
    }
}

private struct LessonNode: View {
    let state: LessonState
    let number: Int
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if state == .current {
                Circle()
                    .fill(Theme.orange.opacity(0.25))
                    .frame(width: 86, height: 86)
                    .phaseAnimator([false, true]) { halo, expanded in
                        halo.scaleEffect(reduceMotion ? 1 : (expanded ? 1.1 : 0.9))
                            .opacity(reduceMotion ? 1 : (expanded ? 0.5 : 1))
                    } animation: { _ in .easeInOut(duration: 1.3) }
            }
            Circle()
                .fill(fill)
                .frame(width: 66, height: 66)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 2))
                .shadow(color: shadowColor.opacity(0.4), radius: 10, y: 5)
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(state == .locked ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Color.white))
        }
        .frame(width: 90, height: 90)
        .contentShape(Circle())
    }

    private var symbol: String {
        switch state {
        case .locked: "lock.fill"
        case .current: "play.fill"
        case .completed(_, let viaPlacement): viaPlacement ? "checkmark.seal.fill" : "checkmark"
        }
    }

    private var fill: AnyShapeStyle {
        switch state {
        case .locked: AnyShapeStyle(Color.secondary.opacity(0.16))
        case .current: AnyShapeStyle(Theme.accentGradient)
        case .completed(_, let viaPlacement):
            viaPlacement ? AnyShapeStyle(Theme.placementGradient)
                : AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var shadowColor: Color {
        switch state {
        case .locked: .clear
        case .current: Theme.orange
        case .completed: tint
        }
    }
}

private struct LessonNodeLabel: View {
    let lesson: Lesson
    let state: LessonState
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(lesson.title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(2)
                .foregroundStyle(state == .locked ? .secondary : .primary)
            switch state {
            case .completed(let stars, let viaPlacement):
                if viaPlacement {
                    Chip(text: "Eingestuft", systemImage: "checkmark.seal", tint: Theme.indigo)
                } else {
                    StarsView(count: stars, size: 12)
                }
            case .current:
                Chip(text: "Jetzt dran · \(lesson.estimatedMinutes) Min", systemImage: "sparkles", tint: Theme.orange)
            case .locked:
                Text("\(lesson.tasks.count) Aufgaben").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Lernpfad") {
    NavigationStack { LearningPathView() }
        .environment(PreviewSupport.makeStore())
        .environment(AppRouter())
}
