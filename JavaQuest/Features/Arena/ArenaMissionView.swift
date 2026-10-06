import SwiftUI
import JavaQuestKit

/// Wo eine Mission gespielt wird – davon hängen die Buttons am Ende ab.
enum ArenaContext {
    /// Abschluss einer Lektion: danach geht es zur Auswertung.
    case lesson(onFinish: (ArenaResult?) -> Void)
    /// Aus der Arena-Übersicht oder als Tagesmission. `onNext` startet die nächste offene Mission.
    case standalone(onClose: () -> Void, onNext: (() -> Void)?)
}

/// Eine Arena-Mission: Auftrag, Spielfeld, Code und Ergebnis.
/// Breit (iPad quer, Mac): Spielfeld links, Code rechts. Schmal (iPhone): untereinander.
struct ArenaMissionView: View {
    @Bindable var model: ArenaMissionModel
    let context: ArenaContext
    @State private var width: CGFloat = 400
    @State private var confirmSolution = false

    private var isWide: Bool { width >= 880 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 20) {
                            VStack(spacing: 16) {
                                MissionBriefing(model: model)
                                boardCard
                                ConsolePanel(model: model)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 16) {
                                codeCard
                                resultSection
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 16) {
                            MissionBriefing(model: model)
                            boardCard
                            codeCard
                            ConsolePanel(model: model)
                            resultSection
                        }
                    }
                }
                .padding(isWide ? 24 : 16)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.isAtEnd && model.result != nil) { _, finished in
                guard finished, !isWide else { return }
                withAnimation(.smooth) { proxy.scrollTo("result", anchor: .top) }
            }
            .onChange(of: model.isRunning) { _, running in
                guard running, !isWide else { return }
                withAnimation(.smooth) { proxy.scrollTo("board", anchor: .top) }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Theme.screenBackground)
        .safeAreaInset(edge: .bottom) { actionBar }
        .sensoryFeedback(.success, trigger: model.result?.solved == true && model.isAtEnd)
        .sensoryFeedback(.error, trigger: model.crashCount)
        .onDisappear { model.leave() }
        #if DEBUG
        .task {
            if AppModel.debugAutoRun, model.runCount == 0 { model.run() }
        }
        #endif
        .confirmationDialog("Lösung anzeigen?", isPresented: $confirmSolution, titleVisibility: .visible) {
            Button("Lösung in den Editor schreiben") { withAnimation(.smooth) { model.revealSolution() } }
        } message: {
            Text("Mit der gezeigten Lösung gibt es keine Sterne und keine XP – aber du kannst Zeile für Zeile nachlesen, wie sie funktioniert.")
        }
    }

    // MARK: Bausteine

    private var boardCard: some View {
        VStack(spacing: 12) {
            if model.worlds.count > 1 { WorldPicker(model: model) }
            ArenaBoardView(
                world: model.world,
                state: model.board,
                crashCount: model.crashCount,
                animationDuration: min(model.speed.frameDuration.seconds * 0.85, 0.5),
                maxHeight: isWide ? 420 : 300
            )
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(ArenaColors.board, in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) { BoardBadges(model: model).padding(16) }
            PlaybackControls(model: model)
        }
        .card(padding: 14)
        .id("board")
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Dein Java-Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
                Spacer()
                Text("\(model.lineCount) Zeilen")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if model.codePanel == .watching {
                    Button("Bearbeiten", systemImage: "pencil") { withAnimation(.smooth) { model.edit() } }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.orange)
                }
            }
            switch model.codePanel {
            case .editing:
                CodeEditorView(text: $model.code, placeholder: "// Befehle für Byte, z. B. robot.move();", minHeight: isWide ? 260 : 200, isLocked: false)
                CommandPalette(model: model)
            case .watching:
                TraceCodeView(code: model.code, currentLine: model.currentLine, errorLine: model.isAtEnd ? model.currentRun?.problem?.line : nil)
                    .onTapGesture { withAnimation(.smooth) { model.edit() } }
            }
            Text(model.isPlayground
                 ? "Eigene Methoden (static void …) darfst du über oder unter deine Befehle schreiben."
                 : "Tipp: Eigene Methoden (static void …) darfst du über oder unter deine Befehle schreiben.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card(padding: 16)
    }

    @ViewBuilder private var resultSection: some View {
        if model.showsHint {
            Label {
                Text(model.mission.hint).font(.subheadline)
            } icon: {
                Image(systemName: "lightbulb.fill").foregroundStyle(Theme.orange)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
            .transition(.opacity)
        }
        if let result = model.result, model.isAtEnd || !model.isPlaying {
            MissionResultPanel(model: model, result: result)
                .id("result")
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        if model.usedSolution || model.result?.solved == true, !model.isPlayground {
            SolutionExegesis(title: "Musterlösung Zeile für Zeile", snippet: model.mission.solution)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if !model.isPlayground {
                Menu {
                    Button("Tipp anzeigen", systemImage: "lightbulb") { withAnimation(.smooth) { model.showsHint.toggle() } }
                    Button("Startcode wiederherstellen", systemImage: "arrow.uturn.backward") { model.resetCode() }
                    if model.runCount > 0 {
                        Button("Lösung zeigen", systemImage: "eye") { confirmSolution = true }
                    }
                    if case .lesson(let onFinish) = context, model.result?.solved != true {
                        Divider()
                        Button("Mission überspringen", systemImage: "forward") { onFinish(nil) }
                    }
                } label: {
                    Label("Hilfe", systemImage: "questionmark.circle")
                }
                .menuStyle(.button)
                .buttonStyle(.secondary)
                .frame(maxWidth: 160)
            }

            if model.result?.solved == true, model.isAtEnd || !model.isPlaying {
                finishButton
            } else {
                Button(action: { withAnimation(.smooth) { model.run() } }) {
                    if model.isRunning {
                        ProgressView().tint(.white)
                    } else {
                        Label(model.runCount == 0 ? "Ausführen" : "Erneut ausführen", systemImage: "play.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(fill: Theme.successGradient))
                .disabled(model.isRunning || model.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    @ViewBuilder private var finishButton: some View {
        switch context {
        case .lesson(let onFinish):
            Button { onFinish(model.result) } label: {
                Label("Weiter zur Auswertung", systemImage: "chart.bar.doc.horizontal")
            }
            .buttonStyle(PrimaryButtonStyle(fill: Theme.successGradient))
            .keyboardShortcut(.return, modifiers: .command)
        case .standalone(let onClose, let onNext):
            if let onNext {
                Button("Fertig", systemImage: "checkmark", action: onClose)
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 160)
                Button(action: onNext) {
                    Label("Nächste Mission", systemImage: "arrow.right")
                }
                .buttonStyle(PrimaryButtonStyle(fill: Theme.successGradient))
                .keyboardShortcut(.return, modifiers: .command)
            } else {
                Button(action: onClose) {
                    Label("Fertig", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle(fill: Theme.successGradient))
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}

// MARK: - Auftrag

private struct MissionBriefing: View {
    let model: ArenaMissionModel

    private var kindLabel: (String, String, Color) {
        if model.isPlayground { return ("Spielplatz", "sparkles", Theme.teal) }
        switch model.mission.kind {
        case .lesson: return ("Mission", "gamecontroller.fill", Theme.indigo)
        case .boss: return ("Boss-Level", "shield.lefthalf.filled", Theme.ember)
        case .training: return ("Training", "dumbbell.fill", Theme.violet)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Chip(text: kindLabel.0, systemImage: kindLabel.1, tint: kindLabel.2)
                if model.isDaily { Chip(text: "Tagesmission", systemImage: "sun.max.fill", tint: Theme.orange) }
                Spacer(minLength: 8)
                if !model.isPlayground {
                    StarsView(count: model.bestStars, size: 16)
                }
            }
            Text(model.mission.title).font(.title2.weight(.bold))
            Text(model.mission.story)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.isPlayground {
                GoalList(mission: model.mission)
            }
            if !model.mission.newCommands.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEUE BEFEHLE").font(.caption2.weight(.heavy)).foregroundStyle(Theme.orange)
                    ForEach(model.mission.newCommands, id: \.self) { name in
                        if let command = RobotCommand.all.first(where: { $0.name == name }) {
                            HStack(spacing: 8) {
                                Text(command.call).font(.system(.footnote, design: .monospaced).weight(.semibold))
                                Text("– \(command.summary)").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .card(padding: 18)
    }
}

/// Was für die Sterne nötig ist.
private struct GoalList: View {
    let mission: ArenaMission

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("star.fill", missionGoal)
            ForEach(Array(mission.bonus.enumerated()), id: \.offset) { _, criterion in
                row(criterion.symbolName, criterion.title)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.fieldBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var missionGoal: String {
        var parts: [String] = []
        if mission.reachGoal { parts.append("Ziel erreichen") }
        if mission.collectAllCoins { parts.append("alle Münzen einsammeln") }
        if mission.worlds.contains(where: { $0.expectedOutput != nil }) { parts.append("richtige Ausgabe") }
        let text = parts.joined(separator: ", ")
        let worlds = mission.worlds.count > 1 ? " – in allen \(mission.worlds.count) Welten" : ""
        return (text.prefix(1).uppercased() + text.dropFirst()) + worlds
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.yellow).frame(width: 18)
            Text(text).font(.footnote)
        }
    }
}

// MARK: - Spielfeld-Steuerung

private struct WorldPicker: View {
    let model: ArenaMissionModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(model.worlds.indices, id: \.self) { index in
                Button { model.selectWorld(index) } label: {
                    HStack(spacing: 5) {
                        if let run = model.result?.runs[safe: index] {
                            Image(systemName: run.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(run.succeeded ? Theme.success : Theme.ember)
                        }
                        Text("Welt \(index + 1)")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(index == model.selectedWorld ? Theme.indigo.opacity(0.16) : Theme.fieldBackground.opacity(0.6), in: Capsule())
                    .overlay(Capsule().strokeBorder(index == model.selectedWorld ? Theme.indigo : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct BoardBadges: View {
    let model: ArenaMissionModel

    var body: some View {
        let total = model.world.coins.count
        if total > 0 {
            HStack(spacing: 5) {
                CoinView(size: 16)
                Text("\(model.board.collected)/\(total)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(model.board.collected)))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(.black.opacity(0.35), in: Capsule())
            .animation(.smooth, value: model.board.collected)
        }
    }
}

private struct PlaybackControls: View {
    @Bindable var model: ArenaMissionModel

    var body: some View {
        HStack(spacing: 6) {
            control("backward.end.fill", "Zum Anfang", disabled: model.frames.isEmpty) { model.rewind() }
            control(model.isPlaying ? "pause.fill" : "play.fill", model.isPlaying ? "Pause" : "Abspielen", disabled: model.frames.isEmpty, prominent: true) {
                model.isPlaying ? model.pause() : model.play()
            }
            control("forward.frame.fill", "Ein Schritt", disabled: model.frames.isEmpty || model.isAtEnd) { model.step() }
            control("forward.end.fill", "Zum Ende", disabled: model.frames.isEmpty || model.isAtEnd) { model.skipToEnd() }
            Spacer(minLength: 4)
            if !model.frames.isEmpty {
                Text("\(model.frameIndex + 1)/\(model.frames.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Picker("Tempo", selection: $model.speed) {
                ForEach(ArenaMissionModel.Speed.allCases) { speed in Text(speed.rawValue).tag(speed) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }

    private func control(_ symbol: String, _ label: LocalizedStringKey, disabled: Bool, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .frame(width: prominent ? 44 : 36, height: 36)
                .foregroundStyle(prominent ? .white : Theme.indigo)
                .background(prominent ? AnyShapeStyle(Theme.indigo) : AnyShapeStyle(Theme.indigo.opacity(0.12)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(Text(label))
    }
}

// MARK: - Code

/// Code beim Zuschauen: Die gerade laufende Zeile leuchtet, eine Fehlerzeile wird rot.
struct TraceCodeView: View {
    let code: String
    let currentLine: Int?
    var errorLine: Int?

    var body: some View {
        let lines = code.components(separatedBy: "\n")
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal], showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        let number = index + 1
                        HStack(spacing: 10) {
                            Text("\(number)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(CodeTheme.plain.opacity(0.35))
                                .frame(width: 24, alignment: .trailing)
                            Text(CodeBlockView.highlighted(line.isEmpty ? " " : line))
                                .font(.system(.callout, design: .monospaced))
                                .fixedSize()
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(background(for: number))
                        .overlay(alignment: .leading) {
                            if number == currentLine || number == errorLine {
                                Rectangle().fill(number == errorLine ? Theme.ember : Theme.orange).frame(width: 3)
                            }
                        }
                        .id(number)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minHeight: 160, maxHeight: 340)
            .onChange(of: currentLine) { _, line in
                guard let line else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(line, anchor: .center) }
            }
        }
        .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
        .animation(.easeOut(duration: 0.15), value: currentLine)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Tippen zum Bearbeiten"))
    }

    private func background(for number: Int) -> Color {
        if number == errorLine { return Theme.ember.opacity(0.3) }
        if number == currentLine { return Theme.orange.opacity(0.22) }
        return .clear
    }
}

/// Befehle zum Antippen – sie werden unten an den Code angehängt.
private struct CommandPalette: View {
    let model: ArenaMissionModel

    private let templates: [(String, String)] = [
        ("if", "if (robot.onCoin()) {\n    robot.pickCoin();\n}"),
        ("while", "while (!robot.atGoal()) {\n    robot.move();\n}"),
        ("for", "for (int i = 0; i < 3; i++) {\n    robot.move();\n}"),
        ("Methode", "static void schritt() {\n    robot.move();\n}"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RobotCommand.all) { command in
                    let isNew = model.mission.newCommands.contains(command.name)
                    Button { model.insert(command.returnType == "void" ? "\(command.call);" : command.call) } label: {
                        Text(command.call)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .foregroundStyle(isNew ? .white : Theme.indigo)
                            .background(isNew ? AnyShapeStyle(Theme.orange) : AnyShapeStyle(Theme.indigo.opacity(0.12)), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(command.summary)
                    .accessibilityHint(Text(command.summary))
                }
                Divider().frame(height: 22)
                ForEach(templates, id: \.0) { name, snippet in
                    Button { model.insert(snippet) } label: {
                        Label(name, systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .foregroundStyle(Theme.violet)
                            .background(Theme.violet.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Konsole & Variablen

private struct ConsolePanel: View {
    let model: ArenaMissionModel

    var body: some View {
        if model.result != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Konsole", systemImage: "terminal.fill").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text(model.displayedOutput.isEmpty ? "(noch keine Ausgabe)" : model.displayedOutput)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(model.displayedOutput.isEmpty ? CodeTheme.plain.opacity(0.4) : CodeTheme.plain)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                            .padding(10)
                            .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    if !model.variables.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Variablen", systemImage: "shippingbox.fill").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(model.variables, id: \.name) { variable in
                                    HStack(spacing: 4) {
                                        Text(variable.name).fontWeight(.semibold)
                                        Text("=").foregroundStyle(.secondary)
                                        Text(variable.value).foregroundStyle(Theme.indigo)
                                            .contentTransition(.numericText())
                                    }
                                    .font(.system(.footnote, design: .monospaced))
                                    .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Theme.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .animation(.smooth, value: model.variables)
                        }
                        .frame(maxWidth: 220)
                    }
                }
            }
            .card(padding: 14)
        }
    }
}

// MARK: - Ergebnis

private struct MissionResultPanel: View {
    let model: ArenaMissionModel
    let result: ArenaResult

    private var tint: Color {
        if model.isPlayground { return Theme.teal }
        return result.solved ? Theme.success : Theme.orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.isPlayground {
                playgroundSummary
            } else {
                header
                criteria
                failures
            }
            ForEach(result.warnings, id: \.self) { warning in
                Label("Zeile \(warning.line): \(warning.message)", systemImage: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.orange)
            }
            if let gain = model.rewardGain, !gain.isEmpty {
                RewardBanner(gain: gain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(tint.opacity(0.3)))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: result.solved ? "checkmark.seal.fill" : "arrow.triangle.2.circlepath")
                .font(.title)
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: result.solved)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.solved ? (result.stars == 3 ? "Perfekt gelöst!" : "Mission geschafft!") : "Noch nicht ganz").font(.headline)
                Text(subline).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            StarsView(count: result.stars, size: 22)
        }
    }

    private var subline: String {
        if model.usedSolution { return "Mit der gezeigten Lösung gibt es keine Sterne." }
        if result.solved {
            return result.stars == 3 ? "Alle drei Sterne – stark!" : "Schaffst du auch die übrigen Sterne?"
        }
        return "Schau dir an, wo Byte hängen bleibt – und passe den Code an."
    }

    private var criteria: some View {
        VStack(alignment: .leading, spacing: 7) {
            criterionRow(met: result.solved, title: "Mission erfüllt")
            ForEach(result.criteria) { item in
                criterionRow(met: item.met, title: item.criterion.title)
            }
        }
    }

    private func criterionRow(met: Bool, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "star.fill" : "star")
                .foregroundStyle(met ? Color.yellow : Color.secondary)
            Text(title).font(.subheadline)
        }
    }

    @ViewBuilder private var failures: some View {
        let messages = result.missingRequirements + result.runs.enumerated().flatMap { index, run in
            run.failures.map { model.worlds.count > 1 ? "Welt \(index + 1): \($0)" : $0 }
        }
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(messages.prefix(5).enumerated()), id: \.offset) { _, message in
                    Label(message, systemImage: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .labelStyle(ColoredIconLabelStyle(tint: Theme.ember))
                }
            }
        }
    }

    private var playgroundSummary: some View {
        let run = result.runs.first
        return VStack(alignment: .leading, spacing: 6) {
            Label(run?.problem == nil ? "Programm fertig ausgeführt" : "Programm angehalten", systemImage: run?.problem == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(run?.problem == nil ? Theme.success : Theme.orange)
            if let problem = run?.problem {
                Text(problem.description).font(.subheadline)
            }
            Text("Byte hat \(run?.actions ?? 0) Aktionen gemacht und \((run?.world.coins.count ?? 0) - (run?.coinsLeft ?? 0)) Münzen eingesammelt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ColoredIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.foregroundStyle(tint)
            configuration.title.fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// „+75 XP“, Levelaufstieg und neue Abzeichen.
struct RewardBanner: View {
    let gain: RewardGain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if gain.xp > 0 {
                    Label("+\(gain.xp) XP", systemImage: "sparkles")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.violet)
                }
                if let level = gain.levelUp {
                    Label("Level \(level)!", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.orange)
                }
            }
            ForEach(gain.newAchievements) { achievement in
                HStack(spacing: 10) {
                    IconTile(systemImage: achievement.symbolName, tint: Theme.orange, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Neues Abzeichen: \(achievement.title)").font(.subheadline.weight(.bold))
                        Text(achievement.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
