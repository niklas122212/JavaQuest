import SwiftUI
import JavaQuestKit

/// Erzeugt das Modell genau einmal pro Sitzung.
struct LessonFlowContainer: View {
    let request: SessionRequest
    @Environment(ProgressStore.self) private var store
    @State private var model: LessonFlowModel?

    var body: some View {
        Group {
            if let model {
                LessonFlowView(model: model)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil { model = LessonFlowModel(request: request, store: store) }
        }
    }
}

/// Lern-Loop: Theorie-Happen → Aufgaben mit steigendem Niveau → Auswertung.
struct LessonFlowView: View {
    @Bindable var model: LessonFlowModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            LessonTopBar(
                title: model.session.title,
                progress: model.session.progress,
                position: model.taskPosition,
                onClose: { dismiss() }
            )
            Group {
                switch model.session.phase {
                case .theory(let page):
                    TheoryStepView(cards: model.session.theory, page: page,
                                   onNext: { withAnimation(.smooth) { model.advanceTheory() } },
                                   onBack: { withAnimation(.smooth) { model.goBackInTheory() } })
                case .task:
                    TaskStepView(model: model)
                case .summary:
                    LessonSummaryView(model: model, onClose: { dismiss() }, onStartLesson: { id in router.startLesson(id) })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.screenBackground)
    }
}

private struct LessonTopBar: View {
    let title: String
    let progress: Double
    let position: (index: Int, count: Int)?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.fieldBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(Text("Lektion schließen"))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer()
                    if let position {
                        Text("Aufgabe \(position.index) von \(position.count)")
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressBar(value: progress, height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Lektion") {
    let store = PreviewSupport.makeStore()
    LessonFlowContainer(request: SessionRequest(kind: .lesson("l09-inheritance")))
        .environment(store)
        .environment(AppRouter())
}
#endif
