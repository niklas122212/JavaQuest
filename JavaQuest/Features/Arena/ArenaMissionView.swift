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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isWide: Bool { width >= 880 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if isWide {
                        // Links Auftrag und Spielfeld, rechts Code – der Weg in Schritten und der
                        // Werkzeugkasten stehen unter dem Code, wo man beim Schreiben nachschaut.
                        HStack(alignment: .top, spacing: 20) {
                            VStack(spacing: 16) {
                                MissionBriefing(model: model, showsGuide: false)
                                boardCard
                                ConsolePanel(model: model)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 16) {
                                codeCard
                                resultSection
                                MissionGuide(model: model).card(padding: 18)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 16) {
                            MissionBriefing(model: model, showsGuide: true)
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
                // Die Ergebnis-Karte erscheint im selben Moment – erst nach dem Einfügen findet
                // scrollTo sie. Ohne die kurze Pause blieb das Ergebnis unter dem Bildrand.
                // Gelöst: erst Byte jubeln lassen, dann zum Ergebnis.
                let pause = model.isCelebrating && !reduceMotion ? 1_100 : 120
                Task {
                    try? await Task.sleep(for: .milliseconds(pause))
                    withAnimation(.smooth) { proxy.scrollTo("result", anchor: .top) }
                }
            }
            .onChange(of: model.isRunning) { _, running in
                guard running, !isWide else { return }
                withAnimation(.smooth) { proxy.scrollTo("board", anchor: .top) }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Theme.screenBackground)
        .overlay {
            if !reduceMotion {
                ConfettiBurst(trigger: model.celebrationCount)
                    .ignoresSafeArea()
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .sensoryFeedback(.success, trigger: model.result?.solved == true && model.isAtEnd)
        .sensoryFeedback(.error, trigger: model.crashCount)
        .onDisappear { model.leave() }
        #if DEBUG
        .task {
            guard model.runCount == 0 else { return }
            if AppModel.debugAutoSolve {
                model.code = model.mission.solution.source
                model.run()
            } else if AppModel.debugAutoRun {
                model.run()
            }
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
                celebrationCount: model.celebrationCount,
                animationDuration: model.stepDuration,
                maxHeight: isWide ? 420 : 300
            )
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(ArenaColors.board, in: RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) { BoardBadges(model: model).padding(16) }
            BoardLegend(facing: model.world.facing, hasGoal: model.world.goal != nil, hasCoins: !model.world.coins.isEmpty)
            PlaybackControls(model: model)
        }
        .card(padding: 14)
        .id("board")
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Wie im echten Projekt: Die Datei heißt wie ihre Klasse.
                Label {
                    Text("\(model.mission.className).java").font(.system(.headline, design: .monospaced))
                } icon: {
                    Image(systemName: "doc.text.fill").foregroundStyle(Theme.orange)
                }
                .accessibilityLabel(Text("Datei \(model.mission.className).java"))
                Spacer()
                Text(model.lineCountLabel)
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
                ArenaCodeEditor(model: model, minHeight: isWide ? 260 : 200)
                CommandPalette(model: model)
            case .watching:
                TraceCodeView(code: model.code, currentLine: model.currentLine, errorLine: model.isAtEnd ? model.currentRun?.problem?.line : nil)
                    .onTapGesture { withAnimation(.smooth) { model.edit() } }
            }
            if model.knowsMethods {
                Text(model.isPlayground
                     ? "Eigene Methoden (static void …) gehören in die Klasse – über oder unter main, nicht hinein."
                     : "Tipp: Eigene Methoden (static void …) gehören in die Klasse – über oder unter main, nicht hinein.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        // Die Musterlösung erst nach der Fahrt – nicht schon, während Byte noch unterwegs ist.
        if model.usedSolution || (model.result?.solved == true && (model.isAtEnd || !model.isPlaying)), !model.isPlayground {
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
                    if showsFinish {
                        // Daneben stehen zwei Buttons – auf dem iPhone reicht dann das Symbol.
                        Label("Hilfe", systemImage: "questionmark.circle").labelStyle(.iconOnly)
                    } else {
                        Label("Hilfe", systemImage: "questionmark.circle")
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.secondary)
                .frame(maxWidth: showsFinish ? 64 : 160)
            }

            if showsFinish {
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

    private var showsFinish: Bool { model.result?.solved == true && (model.isAtEnd || !model.isPlaying) }

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
                // Auf dem iPhone ist für drei Buttons kein Platz – Schließen geht dort über das X oben.
                if width >= 600 {
                    Button("Fertig", systemImage: "checkmark", action: onClose)
                        .buttonStyle(.secondary)
                        .frame(maxWidth: 160)
                }
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

/// Was zu tun ist: Titel, Geschichte und Auftrag – auf schmalen Bildschirmen auch gleich der Weg dorthin.
private struct MissionBriefing: View {
    let model: ArenaMissionModel
    /// Schritte, Werkzeugkasten und Sterne mit anzeigen (sonst stehen sie neben dem Code).
    let showsGuide: Bool

    private var kindLabel: (String, String, Color) {
        if model.isPlayground { return ("Spielplatz", "sparkles", Theme.teal) }
        switch model.mission.kind {
        case .lesson: return ("Mission", "gamecontroller.fill", Theme.indigo)
        case .boss: return ("Boss-Level", "shield.lefthalf.filled", Theme.ember)
        case .training: return ("Training", "dumbbell.fill", Theme.violet)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                BriefingSection(title: "Dein Auftrag", systemImage: "flag.checkered") {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(model.mission.goals.enumerated()), id: \.offset) { _, goal in
                            GoalRow(goal: goal)
                        }
                    }
                }
            }
            if showsGuide {
                MissionGuide(model: model)
            }
        }
        .card(padding: 18)
    }
}

/// Der Weg zum Ziel: Schritte in Worten, Werkzeugkasten (Bausteine und Befehle) und Sterne.
private struct MissionGuide: View {
    let model: ArenaMissionModel
    @State private var showsSteps = true
    @State private var showsToolbox: Bool

    init(model: ArenaMissionModel) {
        self.model = model
        // Aufgeklappt, wenn etwas Neues darin steckt – Bekanntes bleibt kompakt.
        _showsToolbox = State(initialValue: model.isPlayground || model.hasNewTools)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !model.isPlayground {
                if !model.mission.steps.isEmpty {
                    BriefingSection(title: "So gehst du vor", systemImage: "list.number", isExpanded: $showsSteps) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(model.mission.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.heavy).monospacedDigit())
                                        .foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Theme.indigo, in: Circle())
                                    Text(step)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }

            BriefingSection(
                title: model.isPlayground ? "Das kann Byte" : "Dein Werkzeugkasten",
                systemImage: "wrench.and.screwdriver.fill",
                isExpanded: $showsToolbox,
                collapsedSummary: toolboxSummary
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    if !model.conceptUses.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionCaption(text: "Java-Bausteine, die du brauchst")
                            ForEach(model.conceptUses) { use in
                                ConceptRow(use: use, lessonLabel: model.lessonLabel(for: use.concept))
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SectionCaption(text: model.isPlayground ? "Alle Befehle" : "Befehle, die Byte hier kann")
                        ForEach(model.commands) { command in
                            CommandRow(command: command, isNew: model.mission.newCommands.contains(command.name))
                        }
                    }
                }
            }

            if !model.isPlayground {
                BriefingSection(title: "Sterne", systemImage: "star.fill") {
                    GoalList(mission: model.mission)
                }
            }
        }
    }

    private var toolboxSummary: String {
        let concepts = model.conceptUses.map(\.concept.title)
        let commands = model.commands.count == 1 ? "1 Befehl" : "\(model.commands.count) Befehle"
        return (concepts + [commands]).joined(separator: " · ")
    }
}

/// Überschrift eines Auftragsteils – mit Aufklappen, wenn `isExpanded` gesetzt ist.
private struct BriefingSection<Content: View>: View {
    let title: String
    let systemImage: String
    var isExpanded: Binding<Bool>?
    var collapsedSummary: String?
    @ViewBuilder let content: Content

    init(title: String, systemImage: String, isExpanded: Binding<Bool>? = nil, collapsedSummary: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.isExpanded = isExpanded
        self.collapsedSummary = collapsedSummary
        self.content = content()
    }

    private var expanded: Bool { isExpanded?.wrappedValue ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let isExpanded {
                Button {
                    withAnimation(.smooth) { isExpanded.wrappedValue.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        header
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(expanded ? 0 : -90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(Text(expanded ? "aufgeklappt" : "zugeklappt"))
                .accessibilityHint(Text(expanded ? "Tippen zum Zuklappen" : "Tippen zum Aufklappen"))
            } else {
                header
            }
            if expanded {
                content
                    .transition(.opacity)
            } else if let collapsedSummary {
                Text(collapsedSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.fieldBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.indigo)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.secondary)
    }
}

private struct NewBadge: View {
    var body: some View {
        Text("NEU")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.orange, in: Capsule())
            .accessibilityLabel(Text("neu"))
    }
}

/// Ein Punkt im Auftrag – bei der Ausgabe mit dem genauen Text, der erscheinen muss.
private struct GoalRow: View {
    let goal: ArenaGoal

    private var symbol: (String, Color) {
        switch goal.kind {
        case .reachGoal: ("flag.checkered", Theme.success)
        case .collectCoins: ("circle.circle.fill", ArenaColors.coinEdge)
        case .output: ("text.bubble.fill", Theme.indigo)
        case .rule: ("checkmark.seal.fill", Theme.violet)
        case .allWorlds: ("square.stack.3d.up.fill", Theme.teal)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol.0)
                .foregroundStyle(symbol.1)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 6) {
                Text(goal.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(goal.outputs.enumerated()), id: \.offset) { _, output in
                    VStack(alignment: .leading, spacing: 3) {
                        if let world = output.world {
                            Text("Welt \(world)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text(output.text)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(CodeTheme.plain)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .accessibilityLabel(Text("Ausgabe: \(output.text)"))
                    }
                }
            }
        }
    }
}

/// Ein Java-Baustein mit Mini-Beispiel – „NEU“, wenn ihn hier zum ersten Mal jemand braucht.
private struct ConceptRow: View {
    let use: ArenaConceptUse
    let lessonLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(use.concept.title).font(.subheadline.weight(.semibold))
                if use.isNew {
                    NewBadge()
                } else if let lessonLabel {
                    Text("aus \(lessonLabel)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(CodeBlockView.highlighted(use.concept.code))
                .font(.system(.footnote, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CodeTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .environment(\.colorScheme, .dark)
            Text(use.concept.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Ein Roboter-Befehl mit genauer Beschreibung.
private struct CommandRow: View {
    let command: RobotCommand
    let isNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(command.call + (command.returnType == "void" ? ";" : ""))
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .foregroundStyle(isNew ? Theme.orange : Theme.indigo)
                if isNew { NewBadge() }
            }
            Text(command.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Was für die Sterne nötig ist.
private struct GoalList: View {
    let mission: ArenaMission

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("star.fill", "Auftrag erfüllt")
            ForEach(Array(mission.bonus.enumerated()), id: \.offset) { _, criterion in
                row(criterion.symbolName, criterion.title)
            }
        }
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.yellow).frame(width: 18)
            Text(text).font(.footnote)
        }
    }
}

/// So liest man das Spielfeld – und wohin Byte am Anfang schaut.
private struct BoardLegend: View {
    let facing: Heading
    let hasGoal: Bool
    let hasCoins: Bool

    var body: some View {
        FlowLayout(spacing: 12) {
            item {
                RobotView(size: 16).rotationEffect(.degrees(facing.degrees))
            } text: { "Byte – schaut am Anfang \(facing.direction)" }
            if hasGoal {
                item { GoalFlag(size: 22) } text: { "Ziel" }
            }
            if hasCoins {
                item { CoinView(size: 14) } text: { "Münze" }
            }
            item {
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(ArenaColors.wall).frame(width: 14, height: 14)
            } text: { "Wand" }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func item<Icon: View>(@ViewBuilder icon: () -> Icon, text: () -> String) -> some View {
        HStack(spacing: 6) {
            icon().frame(width: 22, height: 22)
            Text(text()).font(.caption).foregroundStyle(.secondary)
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
    /// Mindesthöhe – in der Arena fest, beim Zusehen so hoch wie der Code.
    var minHeight: CGFloat = 160

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
            .frame(minHeight: minHeight, maxHeight: 340)
            .onChange(of: currentLine) { _, line in
                guard let line else { return }
                // Nur senkrecht zur Zeile – waagerecht bleibt der Zeilenanfang sichtbar
                // (mit .center stand da „ile (!robot…“ statt „while“).
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(line, anchor: UnitPoint(x: 0, y: 0.5)) }
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
/// Angeboten wird nur, was Byte hier kann und was schon erklärt ist.
private struct CommandPalette: View {
    let model: ArenaMissionModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.commands) { command in
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
                if !model.templates.isEmpty {
                    Divider().frame(height: 22)
                }
                ForEach(model.templates) { template in
                    Button { model.insert(template.code) } label: {
                        Label(template.name, systemImage: "plus")
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
                        VStack(alignment: .leading, spacing: 4) {
                            // Der Befehl, mit dem man das Programm im Terminal starten würde.
                            Text("> java \(model.mission.className)")
                                .foregroundStyle(CodeTheme.plain.opacity(0.45))
                            Text(model.displayedOutput.isEmpty ? "(noch keine Ausgabe)" : model.displayedOutput)
                                .foregroundStyle(model.displayedOutput.isEmpty ? CodeTheme.plain.opacity(0.4) : CodeTheme.plain)
                        }
                        .font(.system(.footnote, design: .monospaced))
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
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            StarReveal(count: result.stars, size: 22)
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
                criterionRow(met: item.met, title: item.criterion.title, progress: item.progress)
            }
        }
    }

    /// Ein Stern mit Messwert – „Höchstens 7 Roboter-Aktionen · du: 9“ sagt genau, was noch fehlt.
    private func criterionRow(met: Bool, title: String, progress: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: met ? "star.fill" : "star")
                .foregroundStyle(met ? Color.yellow : Color.secondary)
            Text(title).font(.subheadline)
            if let progress {
                Text(progress)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(met ? Theme.success : Theme.ember)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background((met ? Theme.success : Theme.ember).opacity(0.12), in: Capsule())
            }
        }
    }

    @ViewBuilder private var failures: some View {
        let messages = result.missingRequirements + worldFailures
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

    /// Fehler je Welt – was in jeder Welt gleich schiefging, steht nur einmal da.
    private var worldFailures: [String] {
        let runs = result.runs
        guard model.worlds.count > 1 else { return runs.flatMap(\.failures) }
        var messages: [String] = []
        for (index, run) in runs.enumerated() {
            // Ein Syntaxfehler steht im Code, nicht in einer Welt (geprüft wird nur die erste).
            if run.problem?.kind == .syntax || run.problem?.kind == .unsupported {
                messages += run.failures.filter { !messages.contains($0) }
                continue
            }
            for failure in run.failures {
                let everywhere = runs.count == model.worlds.count && runs.allSatisfy { $0.failures.contains(failure) }
                let message = everywhere ? "In allen Welten: \(failure)" : "Welt \(index + 1): \(failure)"
                if !messages.contains(message) { messages.append(message) }
            }
        }
        return messages
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

/// Sterne, die nacheinander aufploppen – mit leichtem Tippen auf dem iPhone.
private struct StarReveal: View {
    let count: Int
    let size: CGFloat
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < shown ? "star.fill" : "star")
                    .foregroundStyle(index < shown ? Color.yellow : Color.secondary.opacity(0.5))
                    .scaleEffect(index < shown ? 1 : 0.85)
            }
        }
        .font(.system(size: size, weight: .bold))
        .sensoryFeedback(.impact(weight: .light), trigger: shown) { _, new in new > 0 }
        .task(id: count) {
            guard !reduceMotion else { shown = count; return }
            shown = 0
            for star in stride(from: 1, through: count, by: 1) {
                try? await Task.sleep(for: .milliseconds(star == 1 ? 200 : 300))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { shown = star }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(count) von 3 Sternen"))
    }
}

/// Der Code-Editor der Arena. Ab iOS 18 / macOS 15 merkt er sich, wo man schreibt – dort fügt die
/// Befehlsleiste ein, und danach steht der Cursor hinter dem Eingefügten.
private struct ArenaCodeEditor: View {
    @Bindable var model: ArenaMissionModel
    let minHeight: CGFloat
    private let placeholder = "// Befehle für Byte, z. B. robot.move();"

    var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            CursorTrackingEditor(model: model, placeholder: placeholder, minHeight: minHeight)
        } else {
            CodeEditorView(text: $model.code, placeholder: placeholder, minHeight: minHeight, isLocked: false)
        }
    }
}

@available(iOS 18.0, macOS 15.0, *)
private struct CursorTrackingEditor: View {
    @Bindable var model: ArenaMissionModel
    let placeholder: String
    let minHeight: CGFloat
    @State private var selection: TextSelection?

    var body: some View {
        SelectableCodeEditorView(text: $model.code, selection: $selection, placeholder: placeholder, minHeight: minHeight, isLocked: false)
            .onAppear { model.editorTracksCursor = true }
            .onChange(of: selection) { _, selection in
                guard let index = Self.end(of: selection) else { return }
                model.cursor = min(index.utf16Offset(in: model.code), model.code.utf16.count)
            }
            .onChange(of: model.insertionCount) { _, _ in
                // Cursor hinter das Eingefügte setzen.
                guard let cursor = model.cursor else { return }
                let code = model.code
                let offset = min(cursor, code.utf16.count)
                selection = TextSelection(insertionPoint: String.Index(utf16Offset: offset, in: code))
            }
    }

    private static func end(of selection: TextSelection?) -> String.Index? {
        switch selection?.indices {
        case .selection(let range): range.upperBound
        case .multiSelection(let ranges): ranges.ranges.last?.upperBound
        case nil: nil
        @unknown default: nil
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
