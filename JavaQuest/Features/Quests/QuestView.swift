import SwiftUI
import JavaQuestKit

/// Rahmen einer Quest im Vollbild bzw. Sheet: Kopfzeile mit Schließen und Kapitel, darunter die Quest.
struct QuestSessionContainer: View {
    let questId: String
    @Environment(ProgressStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var model: QuestSessionModel?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Theme.fieldBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(Text("Schließen"))
                if let quest = model?.quest {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.questBook.chapter(id: quest.chapterId)?.title ?? store.questBook.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(quest.title).font(.subheadline.weight(.semibold))
                    }
                    .lineLimit(1)
                }
                Spacer()
                if let model, model.previousStars > 0 {
                    StarsView(count: max(model.previousStars, model.result?.stars ?? 0), size: 13)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            if let model {
                QuestView(model: model, onClose: { dismiss() })
            } else {
                ContentUnavailableView("Quest nicht gefunden", systemImage: "questionmark.circle")
            }
        }
        .background(Theme.screenBackground)
        .onAppear {
            guard model == nil, let quest = store.questBook.quest(id: questId) else { return }
            model = QuestSessionModel(quest: quest, store: store)
        }
    }
}

/// Eine Quest: Szene, Konzept und Auftrag links – Editor, Testlauf und Mentor rechts (auf dem iPhone untereinander).
struct QuestView: View {
    @Bindable var model: QuestSessionModel
    let onClose: () -> Void
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var store
    @State private var width: CGFloat = 400

    private var isWide: Bool { width >= 900 }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        briefing.padding(24)
                    }
                    .frame(width: min(max(width * 0.38, 360), 460))
                    .background(Theme.cardBackground.opacity(0.5))
                    Divider()
                    ScrollView {
                        workbench.padding(24)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        briefing
                        workbench
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .task {
            #if DEBUG
            if AppModel.debugAutoSolve { model.fillSolution() }
            if AppModel.debugAutoRun || AppModel.debugAutoSolve { await model.run() }
            #endif
        }
    }

    // MARK: Links: Szene, Auftrag, Konzept, Tests

    private var briefing: some View {
        VStack(alignment: .leading, spacing: 18) {
            QuestStoryCard(quest: model.quest, chapter: store.questBook.chapter(id: model.quest.chapterId))
            QuestTaskCard(quest: model.quest)
            QuestConceptCard(concept: model.quest.concept)
            QuestTestPreview(quest: model.quest)
        }
    }

    // MARK: Rechts: Editor, Lauf, Ergebnis

    private var workbench: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Label("\(model.quest.className).java", systemImage: "doc.text.fill")
                    .font(.subheadline.monospaced().weight(.semibold))
                Spacer()
                Button {
                    withAnimation(.smooth) { model.reset() }
                } label: {
                    Label("Startcode", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(model.code == model.quest.starterCode)
                .help("Den Code auf den Anfang zurücksetzen")
            }

            JavaCodeEditor(text: $model.code, runErrorLine: model.errorLine, controller: model.editor, minHeight: isWide ? 380 : 280)

            runBar

            if let result = model.result {
                if model.isStale {
                    Label("Code geändert – führe die Tests erneut aus.", systemImage: "pencil.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if result.solved {
                    QuestSuccessCard(model: model, result: result, onNext: model.nextQuest.map { next in { router.startQuest(next.id) } }, onClose: onClose)
                } else {
                    MentorCard(hint: result.mentor)
                }
                QuestTestResults(result: result, showsHidden: result.solved)
                if result.solved, result.stars < 3 {
                    QualityList(result: result)
                }
            }

            if !model.isSolved, model.failedRuns >= 3 {
                SolutionPeek(solution: model.quest.solution)
            }
        }
        .animation(.smooth, value: model.result?.passedCount)
    }

    private var runBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.run() }
            } label: {
                HStack(spacing: 8) {
                    if model.isRunning {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(model.isRunning ? "Tests laufen …" : "Tests ausführen")
                }
            }
            .buttonStyle(.primary)
            .disabled(model.isRunning)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Kompiliert den Code und führt alle Tests aus (⌘↩)")
        }
    }
}

// MARK: - Briefing

private struct QuestStoryCard: View {
    let quest: CodeQuest
    let chapter: QuestChapter?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(systemImage: chapter?.symbol ?? "map.fill", tint: Theme.violet, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text((chapter?.title ?? "Quest").uppercased())
                        .font(.caption.weight(.heavy)).tracking(1.1)
                        .foregroundStyle(Theme.violet)
                    Text(quest.title).font(.title2.weight(.bold))
                }
            }
            Text(quest.story)
                .font(.body)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Chip(text: "Schwierigkeit \(quest.difficulty)/5", systemImage: "gauge.with.dots.needle.33percent", tint: Theme.indigo)
                Chip(text: "\(quest.tests.count) Tests", systemImage: "checklist", tint: Theme.teal)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Theme.violet.opacity(0.16), Theme.indigo.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
    }
}

private struct QuestTaskCard: View {
    let quest: CodeQuest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Dein Auftrag", systemImage: "scope")
                .font(.headline)
                .foregroundStyle(Theme.orange)
            Text(quest.task)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if !quest.requirements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(quest.requirements, id: \.message) { rule in
                        Label(rule.message, systemImage: rule.rule == .forbid ? "nosign" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card(padding: 16)
    }
}

private struct QuestConceptCard: View {
    let concept: QuestConcept
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.smooth) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Neu: \(concept.title)", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.teal)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                Text(concept.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                CodeBlockView(code: concept.code, caption: "Beispiel")
            }
        }
        .card(padding: 16)
    }
}

/// Die sichtbaren Tests als JUnit-Zeilen – so sieht man, wie geprüft wird.
private struct QuestTestPreview: View {
    let quest: CodeQuest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("So wird geprüft", systemImage: "testtube.2")
                .font(.headline)
                .foregroundStyle(Theme.indigo)
            CodeBlockView(code: quest.visibleTests.map(\.assertion).joined(separator: "\n"), caption: "\(quest.className)Test.java")
            let hidden = quest.tests.count - quest.visibleTests.count
            if hidden > 0 {
                Label("\(hidden) weitere Tests bleiben geheim – wie bei echten Abgaben. Denk an Sonderfälle!", systemImage: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 16)
    }
}

// MARK: - Ergebnis

/// Byte, der Mentor: ein Hinweis, der weiterhilft – statt nur „Falsch“.
private struct MentorCard: View {
    let hint: MentorHint

    private var style: (symbol: String, tint: Color) {
        switch hint.kind {
        case .compile: ("hammer.fill", Theme.ember)
        case .unsupported: ("questionmark.circle.fill", Theme.indigo)
        case .missingClass: ("doc.badge.ellipsis", Theme.ember)
        case .missingMember: ("puzzlepiece.extension.fill", Theme.orange)
        case .endless: ("arrow.triangle.2.circlepath", Theme.orange)
        case .crash: ("bolt.trianglebadge.exclamationmark.fill", Theme.ember)
        case .wrongValue: ("xmark.circle.fill", Theme.orange)
        case .requirement: ("checklist", Theme.indigo)
        case .quality: ("wand.and.stars", Theme.violet)
        case .success: ("checkmark.seal.fill", Theme.success)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(systemImage: style.symbol, tint: style.tint, size: 38)
            VStack(alignment: .leading, spacing: 6) {
                Text("Byte, dein Mentor").font(.caption.weight(.heavy)).tracking(0.6).foregroundStyle(style.tint)
                Text(hint.title).font(.headline)
                Text(hint.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if let line = hint.line {
                    Chip(text: "Zeile \(line)", systemImage: "arrow.right.to.line", tint: style.tint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(style.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous).strokeBorder(style.tint.opacity(0.3))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct QuestTestResults: View {
    let result: QuestResult
    /// Nach dem Lösen zeigen auch die geheimen Tests ihren Code.
    let showsHidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if result.compileProblem == nil {
                HStack {
                    Text("\(result.passedCount) von \(result.tests.count) Tests bestanden")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                ProgressBar(value: Double(result.passedCount) / Double(max(result.tests.count, 1)),
                            tint: AnyShapeStyle(result.solved ? Theme.successGradient : Theme.accentGradient), height: 6)
                ForEach(result.tests) { test in
                    row(test)
                }
            } else {
                Label("Erst wenn der Code übersetzt, laufen die Tests.", systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 16)
    }

    private func row(_ test: QuestTestResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: test.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(test.passed ? Theme.success : Theme.ember)
                .font(.body)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(test.test.name).font(.subheadline.weight(.medium))
                    if !test.test.isVisible && !showsHidden {
                        Image(systemName: "eye.slash").font(.caption2).foregroundStyle(.secondary)
                            .accessibilityLabel(Text("geheimer Test"))
                    }
                }
                if !test.passed, let message = test.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if test.test.isVisible || showsHidden {
                    Text(test.test.assertion)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Was zum dritten Stern fehlt: Namen und Einrückung.
private struct QualityList: View {
    let result: QuestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Für den nächsten Stern", systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundStyle(Theme.violet)
            criterion("Alle Tests grün", met: true)
            criterion("Namen nach Java-Konvention", met: result.naming.isEmpty)
            ForEach(result.naming, id: \.self) { finding in
                Text("• " + finding.message).font(.caption).foregroundStyle(.secondary).padding(.leading, 26)
            }
            criterion("Sauber eingerückt (4 Leerzeichen je Ebene)", met: result.indentation.isEmpty)
            ForEach(result.indentation.prefix(4), id: \.self) { finding in
                Text("• " + finding.message).font(.caption).foregroundStyle(.secondary).padding(.leading, 26)
            }
        }
        .card(padding: 16)
    }

    private func criterion(_ title: String, met: Bool) -> some View {
        Label {
            Text(title).font(.subheadline)
        } icon: {
            Image(systemName: met ? "star.fill" : "star").foregroundStyle(met ? .yellow : .secondary)
        }
    }
}

private struct QuestSuccessCard: View {
    let model: QuestSessionModel
    let result: QuestResult
    let onNext: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        let quest = model.quest
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                StarsView(count: result.stars, size: 26)
                if result.stars > model.previousStars, model.previousStars > 0 {
                    Chip(text: "Neuer Bestwert", systemImage: "arrow.up", tint: Theme.success)
                }
                Spacer()
            }
            Text("Bestanden!").font(.title2.weight(.bold))
            Text(quest.success)
                .font(.body)
                .italic()
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                IconTile(systemImage: quest.reward.symbol, tint: Theme.orange, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ins Inventar: \(quest.reward.item)").font(.subheadline.weight(.bold))
                    Text(quest.reward.text).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let blueprint = quest.blueprint {
                HStack(spacing: 12) {
                    IconTile(systemImage: result.stars == 3 ? "scroll.fill" : "lock.fill", tint: result.stars == 3 ? Theme.teal : .gray, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.stars == 3 ? "Bauplan freigeschaltet: \(blueprint.title)" : "Bauplan „\(blueprint.title)“ gesperrt")
                            .font(.subheadline.weight(.bold))
                        Text(result.stars == 3 ? "Du findest ihn in der Werkstatt." : "Sauberer Code mit 3 Sternen schaltet ihn frei.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let gain = model.rewardGain {
                RewardBanner(gain: gain)
            }
            HStack(spacing: 12) {
                if let onNext {
                    Button(action: onNext) {
                        Label("Nächste Quest", systemImage: "arrow.right")
                    }
                    .buttonStyle(.primary)
                }
                Button(action: onClose) {
                    Label("Zur Karte", systemImage: "map")
                }
                .buttonStyle(.secondary)
            }
        }
        .padding(18)
        .background(Theme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(Theme.success.opacity(0.35))
        }
    }
}

/// Nach drei vergeblichen Läufen: die Musterlösung zum Nachlesen – abschreiben bleibt Handarbeit.
private struct SolutionPeek: View {
    let solution: String
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.smooth) { isOpen.toggle() }
            } label: {
                Label(isOpen ? "Musterlösung ausblenden" : "Festgefahren? Musterlösung ansehen", systemImage: isOpen ? "eye.slash" : "eye")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.indigo)
            if isOpen {
                CodeBlockView(code: solution, caption: "Musterlösung")
                Text("Lies sie Zeile für Zeile und schreib sie dann in deinen eigenen Worten – so bleibt es hängen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
