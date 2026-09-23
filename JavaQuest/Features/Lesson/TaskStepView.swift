import SwiftUI
import JavaQuestKit

/// Aufgabenbildschirm. Auf breiten Fenstern (iPad quer, Mac) stehen Aufgabe und
/// Antwort nebeneinander, auf dem iPhone untereinander.
struct TaskStepView: View {
    @Bindable var model: LessonFlowModel
    @State private var width: CGFloat = 400

    var body: some View {
        if let task = model.currentTask {
            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear.frame(height: 0).id(Self.topAnchor)
                    TaskLayout(
                        task: task,
                        topicTitle: model.course.topic(id: task.topicId)?.title,
                        draft: $model.draft,
                        isLocked: model.isAnswerLocked,
                        evaluation: evaluationState(for: task),
                        isWide: width >= 900
                    ) {
                        if model.session.lastResult != nil || model.session.isRevealed {
                            FeedbackPanel(
                                result: model.session.lastResult,
                                isRevealed: model.session.isRevealed,
                                attempts: model.session.attempts,
                                remainingAttempts: model.remainingAttempts,
                                hint: task.hint,
                                secondHint: model.secondHint,
                                explanation: task.explanation,
                                countsForScore: !model.isPractice,
                                wrongChoice: model.wrongChoice,
                                correctAnswer: model.correctAnswer
                            )
                            .id(Self.feedbackAnchor)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if model.session.isCurrentTaskFinished, case .code(let spec) = task.kind {
                            SolutionExegesis(title: "Musterlösung Zeile für Zeile", snippet: spec.solution)
                                .transition(.opacity)
                        }
                    }
                    .id(task.id)
                    .padding(20)
                    .frame(maxWidth: 1180)
                    .frame(maxWidth: .infinity)
                    .animation(.smooth, value: model.session.lastResult)
                }
                // Nach dem Prüfen die Rückmeldung zeigen, bei neuer Aufgabe nach oben springen.
                .onChange(of: feedbackKey) { _, _ in scroll(proxy, to: Self.feedbackAnchor, anchor: .bottom) }
                .onChange(of: task.id) { _, _ in proxy.scrollTo(Self.topAnchor, anchor: .top) }
            }
            .scrollDismissesKeyboard(.interactively)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .safeAreaInset(edge: .bottom) { TaskActionBar(model: model) }
            .sensoryFeedback(.success, trigger: model.successCount)
            .sensoryFeedback(.error, trigger: model.failureCount)
        }
    }

    private static let topAnchor = "task-top"
    private static let feedbackAnchor = "task-feedback"

    private var feedbackKey: String { "\(model.session.attempts)-\(model.session.isRevealed)" }

    private func scroll(_ proxy: ScrollViewProxy, to id: String, anchor: UnitPoint) {
        Task { @MainActor in
            // Kurz warten, bis Tastatur und Einblend-Animation fertig sind.
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.smooth) { proxy.scrollTo(id, anchor: anchor) }
        }
    }

    private func evaluationState(for task: LearningTask) -> TaskEvaluationState {
        TaskEvaluationState(
            isCorrect: model.session.lastResult?.isCorrect == true,
            isRevealed: model.session.isRevealed,
            hasResult: model.session.lastResult != nil,
            blankStates: model.blankStates(for: task)
        )
    }
}

struct TaskEvaluationState: Equatable {
    var isCorrect = false
    var isRevealed = false
    var hasResult = false
    var blankStates: [Bool]?
}

/// Anordnung von Aufgabenstellung, Antwortbereich und Rückmeldung.
struct TaskLayout<Feedback: View>: View {
    let task: LearningTask
    let topicTitle: String?
    @Binding var draft: AnswerDraft
    let isLocked: Bool
    let evaluation: TaskEvaluationState
    let isWide: Bool
    /// Im Einstufungstest gibt es keine Zeilen-Erklärungen – erst im Ergebnis.
    var showsExplanations = true
    @ViewBuilder var feedback: Feedback

    var body: some View {
        if isWide {
            HStack(alignment: .top, spacing: 20) {
                TaskQuestionView(task: task, topicTitle: topicTitle, draft: draft, evaluation: evaluation, showsExplanations: showsExplanations)
                    .card(padding: 22)
                VStack(spacing: 16) {
                    TaskAnswerView(task: task, draft: $draft, isLocked: isLocked, evaluation: evaluation)
                        .card(padding: 22)
                    feedback
                }
            }
        } else {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 20) {
                    TaskQuestionView(task: task, topicTitle: topicTitle, draft: draft, evaluation: evaluation, showsExplanations: showsExplanations)
                    TaskAnswerView(task: task, draft: $draft, isLocked: isLocked, evaluation: evaluation)
                }
                .card(padding: 18)
                feedback
            }
        }
    }
}

/// Kopf mit Typ, Thema und – gut sichtbar – dem Niveau, dazu Aufgabentext und Code.
struct TaskQuestionView: View {
    let task: LearningTask
    let topicTitle: String?
    let draft: AnswerDraft
    let evaluation: TaskEvaluationState
    var showsExplanations = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    chips
                    Spacer(minLength: 8)
                    DifficultyBadge(difficulty: task.difficulty)
                }
                VStack(alignment: .leading, spacing: 8) {
                    DifficultyBadge(difficulty: task.difficulty)
                    HStack(spacing: 8) { chips }
                }
                // Sehr schmal (z. B. Einstufungstest mit mehr Rand): Chips untereinander statt abgeschnitten.
                VStack(alignment: .leading, spacing: 8) {
                    DifficultyBadge(difficulty: task.difficulty)
                    chips
                }
            }

            Text(task.prompt)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let diagram = task.diagram {
                UMLDiagramView(diagram: diagram)
            }

            switch task.kind {
            case .singleChoice where !showsExplanations, .predictOutput where !showsExplanations:
                if let code = task.code { CodeBlockView(code: code) }
            case .fillBlank(let spec) where !showsExplanations:
                CodeBlockView(attributed: CodeBlockView.fillBlank(spec, values: draft.blanks, states: evaluation.blankStates))
            case .singleChoice, .predictOutput:
                if let snippet = task.codeSnippet {
                    CodeExegesisView(lines: snippet.explained(), initialPresentation: isSolved ? .all : nil)
                }
            case .fillBlank(let spec):
                let template = spec.templateSnippet.lines
                CodeExegesisView(
                    lines: isSolved ? spec.solvedSnippet.explained() : spec.templateSnippet.explained(),
                    initialPresentation: isSolved ? .all : nil,
                    hiddenLines: isSolved ? [] : spec.blankLineNumbers
                ) { line in
                    let code = line.number <= template.count ? template[line.number - 1].code : line.code
                    return CodeBlockView.fillBlankLine(code, values: draft.blanks, states: evaluation.blankStates)
                }
            case .code(let spec):
                if !isSolved && showsExplanations {
                    StarterExegesis(snippet: spec.starter)
                }
                if task.javaContext != .file {
                    Label(task.javaContext.instruction, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let expected = spec.expectedOutput {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Erwartete Ausgabe").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(expected)
                            .font(.system(.footnote, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private var isSolved: Bool { evaluation.isCorrect || evaluation.isRevealed }

    @ViewBuilder private var chips: some View {
        Chip(text: task.type.title, systemImage: task.type.symbolName, tint: Theme.indigo)
        if let topicTitle {
            Chip(text: topicTitle, systemImage: "tag.fill")
        }
    }
}

/// Eingabebereich je nach Aufgabentyp.
struct TaskAnswerView: View {
    let task: LearningTask
    @Binding var draft: AnswerDraft
    let isLocked: Bool
    let evaluation: TaskEvaluationState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            switch task.kind {
            case .singleChoice(let spec):
                ChoiceListView(
                    choices: spec.choices,
                    selection: $draft.choice,
                    correctIndex: evaluation.isCorrect || evaluation.isRevealed ? spec.correctIndex : nil,
                    showsWrongSelection: evaluation.hasResult && !evaluation.isCorrect,
                    isLocked: isLocked
                )
            case .fillBlank(let spec):
                BlankFieldsView(count: spec.blanks.count, values: $draft.blanks, states: evaluation.blankStates, isLocked: isLocked)
            case .predictOutput:
                CodeEditorView(text: $draft.text, placeholder: "Ausgabe Zeile für Zeile eintippen …", minHeight: 120, isLocked: isLocked)
            case .code:
                CodeEditorView(text: $draft.text, placeholder: "// Dein Java-Code", minHeight: 220, isLocked: isLocked)
            }
        }
    }

    private var label: String {
        switch task.kind {
        case .singleChoice: "WÄHLE EINE ANTWORT"
        case .fillBlank: "FÜLLE DIE LÜCKEN"
        case .predictOutput: "KONSOLENAUSGABE"
        case .code: "DEIN CODE"
        }
    }
}

/// Startcode einer Programmieraufgabe, auf Wunsch Zeile für Zeile erklärt.
struct StarterExegesis: View {
    let snippet: CodeSnippet
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            CodeExegesisView(lines: snippet.explained(), caption: "Startcode", initialPresentation: .steps)
                .padding(.top, 8)
        } label: {
            Label("Startcode Zeile für Zeile erklärt", systemImage: "text.magnifyingglass")
                .font(.subheadline.weight(.semibold))
        }
        .tint(Theme.orange)
    }
}

/// Lösung einer Aufgabe mit kompletter Zeilen-Zerlegung – nach dem Lösen oder Aufdecken.
struct SolutionExegesis: View {
    let title: String
    let snippet: CodeSnippet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "text.magnifyingglass")
                .font(.headline)
                .foregroundStyle(Theme.orange)
            CodeExegesisView(lines: snippet.explained(), caption: "Musterlösung")
        }
        .card(padding: 18)
    }
}
