import SwiftUI
import JavaQuestKit

/// Adaptiver Einstufungstest. Pro Frage gibt es genau eine Abgabe, ohne Rückmeldung –
/// das Ergebnis zeigt erst die Auswertung.
struct PlacementTestView: View {
    @Binding var test: PlacementTest
    let course: Course
    let onFinished: () -> Void
    @State private var draft = AnswerDraft()
    @State private var width: CGFloat = 400
    private let evaluator = AnswerEvaluator()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(test.questionCount == 1 ? "Einstufungsfrage" : "Einstufungstest").font(.headline)
                            Spacer()
                            if test.questionCount > 1 {
                                Text("Frage \(min(test.answers.count + 1, test.questionCount)) von \(test.questionCount)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ProgressBar(value: test.progress, height: 8)
                    }
                    .id("placement-top")

                    if let task = test.currentTask {
                        TaskLayout(
                            task: task,
                            topicTitle: course.topic(id: task.topicId)?.title,
                            draft: $draft,
                            isLocked: false,
                            evaluation: TaskEvaluationState(),
                            isWide: width >= 900,
                            showsExplanations: false
                        ) { EmptyView() }
                        .id(task.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    }
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: test.answers.count) { _, _ in proxy.scrollTo("placement-top", anchor: .top) }
        }
        .safeAreaInset(edge: .bottom) {
            if let task = test.currentTask {
                Button(action: submit) {
                    Label(test.answers.count + 1 == test.questionCount ? "Antwort abgeben & auswerten" : "Antwort abgeben", systemImage: "arrow.right")
                }
                .buttonStyle(.primary)
                .disabled(draft.answer(for: task) == nil)
                .keyboardShortcut(.return, modifiers: .command)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onAppear { draft = AnswerDraft(task: test.currentTask) }
    }

    private func submit() {
        guard let task = test.currentTask, let answer = draft.answer(for: task) else { return }
        dismissKeyboard()
        withAnimation(.smooth) {
            test.submit(evaluator.evaluate(answer, for: task))
            draft = AnswerDraft(task: test.currentTask)
        }
        if test.isFinished { onFinished() }
    }
}

struct PlacementResultView: View {
    let test: PlacementTest
    let course: Course
    let onStart: () -> Void
    let onDashboard: () -> Void

    private var outcome: PlacementOutcome { test.outcome(in: course) }
    private var entryModule: CourseModule? { course.modules.first { $0.id == outcome.entryModuleId } }

    /// Drei Ausgänge statt zwei: ganz vorn anfangen, bei den Objekten einsteigen oder weiter springen.
    private func headline(for outcome: PlacementOutcome) -> String {
        switch outcome.placedLevel {
        case .advanced: "Das saß – großer Sprung!"
        case .intermediate: "Stark eingestuft!"
        case .beginner: "Guter Startpunkt gefunden"
        }
    }

    private func explanation(for outcome: PlacementOutcome, entryModule: CourseModule) -> String {
        switch outcome.placedLevel {
        case .advanced:
            "Auch die schweren Fragen saßen. Du startest direkt in „\(entryModule.title)“ – alles davor wird dir angerechnet."
        case .intermediate:
            "Du startest direkt in „\(entryModule.title)“. Die Lektionen davor werden dir angerechnet."
        case .beginner:
            "Für den Einstieg bei den Objekten reicht es noch nicht ganz. Du startest mit „\(entryModule.title)“ – dort ist jede Codezeile erklärt."
        }
    }

    var body: some View {
        let outcome = outcome
        VStack(spacing: 22) {
            ZStack {
                ProgressRing(progress: Double(outcome.scorePercent) / 100, lineWidth: 16)
                VStack(spacing: 0) {
                    Text("\(outcome.scorePercent) %")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("Bestanden ab \(test.passThreshold) %")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 190, height: 190)

            VStack(spacing: 8) {
                Text(headline(for: outcome))
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                if let entryModule {
                    Text(explanation(for: outcome, entryModule: entryModule))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            ForEach(Array(test.answers.enumerated()), id: \.offset) { index, answer in
                PlacementAnswerReview(
                    number: test.answers.count > 1 ? index + 1 : nil,
                    answer: answer,
                    topicTitle: course.topic(id: answer.task.topicId)?.title
                )
            }

            VStack(spacing: 10) {
                Button(action: onStart) {
                    Label(entryModule.map { "Mit „\($0.title)“ loslegen" } ?? "Loslegen", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
                Button("Erst zur Übersicht", action: onDashboard)
                    .buttonStyle(.secondary)
            }
        }
    }
}

/// Auswertung einer Einstufungsfrage: jede Lücke mit richtig/falsch und der richtigen
/// Antwort, darunter die Lösung Zeile für Zeile erklärt.
private struct PlacementAnswerReview: View {
    let number: Int?
    let answer: PlacementTest.Answer
    let topicTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: answer.result.isCorrect ? "checkmark.circle.fill" : "list.bullet.clipboard")
                    .font(.title3)
                    .foregroundStyle(answer.result.isCorrect ? Theme.success : Theme.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(number.map { "Frage \($0)" } ?? "Deine Antwort")
                        .font(.headline)
                    Text([answer.task.type.title, topicTitle].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(answer.result.percent) %")
                    .font(.headline.monospacedDigit())
            }

            if case .fillBlank(let spec) = answer.task.kind {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(spec.blanks.enumerated()), id: \.offset) { index, blank in
                        let finding = index < answer.result.findings.count ? answer.result.findings[index] : nil
                        let isRight = finding?.kind == .passed
                        HStack(spacing: 10) {
                            Image(systemName: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isRight ? Theme.success : Theme.ember)
                            Text("Lücke \(index + 1)").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(isRight ? "richtig:" : "richtig wäre:").font(.caption).foregroundStyle(.secondary)
                            Text(blank.accepted.first ?? "")
                                .font(.subheadline.monospaced().weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.fieldBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                    }
                }
                Divider()
                Label("Die Lösung Zeile für Zeile", systemImage: "text.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(Theme.orange)
                CodeExegesisView(lines: spec.solvedSnippet.explained(), caption: "Lösung")
            } else if let snippet = answer.task.codeSnippet {
                CodeExegesisView(lines: snippet.explained())
            }
        }
        .card()
    }
}
