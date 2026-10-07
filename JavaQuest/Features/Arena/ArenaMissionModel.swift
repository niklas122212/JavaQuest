import Foundation
import Observation
import JavaQuestKit

/// Steuert eine Arena-Mission: Code bearbeiten, ausführen, die Fahrt des Roboters
/// Bild für Bild abspielen und das Ergebnis speichern.
@MainActor
@Observable
final class ArenaMissionModel {
    enum Speed: String, CaseIterable, Identifiable {
        case slow = "Langsam"
        case normal = "Normal"
        case fast = "Schnell"

        var id: String { rawValue }

        var frameDuration: Duration {
            switch self {
            case .slow: .milliseconds(700)
            case .normal: .milliseconds(380)
            case .fast: .milliseconds(140)
            }
        }
    }

    /// Bearbeiten (Editor) oder Zuschauen (Code mit markierter Zeile).
    enum CodePanel { case editing, watching }

    let mission: ArenaMission
    let isPlayground: Bool
    var code: String {
        didSet { if code != oldValue { codeChanged() } }
    }
    var codePanel: CodePanel = .editing
    var speed: Speed = .normal
    private(set) var result: ArenaResult?
    private(set) var isRunning = false
    private(set) var selectedWorld = 0
    private(set) var frameIndex = 0
    private(set) var isPlaying = false
    /// Zählt Unfälle – treibt die Wackel-Animation.
    private(set) var crashCount = 0
    private(set) var runCount = 0
    private(set) var usedSolution = false
    private(set) var rewardGain: RewardGain?
    /// Zählt, wie oft eine gelöste Mission zu Ende abgespielt wurde – löst Konfetti und Byte-Hüpfer aus.
    private(set) var celebrationCount = 0
    var showsHint = false

    /// Wo man im Editor gerade schreibt (UTF-16) – dort fügt die Befehlsleiste ein.
    /// Ab iOS 18/macOS 15 meldet der Editor die Stelle, sonst gilt die Stelle hinter dem zuletzt Eingefügten.
    var cursor: Int?
    /// Meldet der Editor den Cursor selbst? Dann bleibt er beim Tippen gültig.
    var editorTracksCursor = false
    /// Zählt Einfügungen – der Editor setzt dann seinen Cursor hinter das Eingefügte.
    private(set) var insertionCount = 0
    private var isInserting = false

    /// Bausteine für den Auftrag, mit Markierung, was hier neu ist.
    let conceptUses: [ArenaConceptUse]
    /// Befehle, die Byte hier kann – nur die bis zu dieser Mission eingeführten.
    let commands: [RobotCommand]
    /// Vorlagen für die Befehlsleiste – nur, was schon erklärt ist.
    let templates: [ArenaTemplate]
    /// Kennt man eigene Methoden schon? Erst dann steht der Methoden-Tipp unter dem Editor.
    let knowsMethods: Bool
    private let lessonNumbers: [String: Int]

    private let store: ProgressStore
    private var playTask: Task<Void, Never>?

    init(mission: ArenaMission, store: ProgressStore, isPlayground: Bool = false) {
        self.mission = mission
        self.store = store
        self.isPlayground = isPlayground
        self.code = mission.starterCode
        let lessonOrder = store.course.allLessons.map(\.id)
        lessonNumbers = Dictionary(lessonOrder.enumerated().map { ($1, $0 + 1) }, uniquingKeysWith: { first, _ in first })
        if isPlayground {
            conceptUses = []
            commands = RobotCommand.all
            templates = ArenaTemplate.all
            knowsMethods = true
        } else {
            conceptUses = store.catalog.conceptUses(for: mission)
            commands = RobotCommand.all.filter { mission.commandNames.contains($0.name) }
            templates = store.catalog.templates(for: mission, lessonOrder: lessonOrder)
            knowsMethods = store.catalog.knows("methode", in: mission, lessonOrder: lessonOrder)
        }
    }

    /// „Lektion 4“ – wo der Kurs einen Baustein erklärt.
    func lessonLabel(for concept: ArenaConcept) -> String? {
        concept.lessonId.flatMap { lessonNumbers[$0] }.map { "Lektion \($0)" }
    }

    /// Steckt im Werkzeugkasten etwas, das hier zum ersten Mal vorkommt?
    var hasNewTools: Bool { !mission.newCommands.isEmpty || conceptUses.contains(where: \.isNew) }

    var worlds: [ArenaWorldSpec] { mission.worlds }
    var lineCountLabel: String { lineCount == 1 ? "1 Zeile" : "\(lineCount) Zeilen" }
    var world: ArenaWorldSpec { worlds[min(selectedWorld, worlds.count - 1)] }
    var bestStars: Int { store.missionStars[mission.id] ?? 0 }
    var isDaily: Bool { !isPlayground && store.dailyMission?.id == mission.id && !store.isDailyMissionDone }

    var currentRun: ArenaWorldRun? {
        guard let result, selectedWorld < result.runs.count else { return nil }
        return result.runs[selectedWorld]
    }

    var frames: [ArenaFrame] { currentRun?.frames ?? [] }
    var currentFrame: ArenaFrame? { frames.isEmpty ? nil : frames[min(frameIndex, frames.count - 1)] }
    var isAtEnd: Bool { frames.isEmpty || frameIndex >= frames.count - 1 }

    /// Was das Spielfeld gerade zeigen soll – Startzustand oder aktuelles Standbild.
    var board: ArenaBoardState {
        if let frame = currentFrame {
            return ArenaBoardState(
                robot: frame.robot, angle: angles[min(frameIndex, angles.count - 1)], coins: frame.coins,
                collected: frame.collected, action: frame.action, isCrashed: frame.action.isCrash,
                step: frameIndex, trail: trail
            )
        }
        return ArenaBoardState(
            robot: world.start ?? GridPoint(x: 0, y: 0), angle: world.facing.degrees, coins: world.coins,
            collected: 0, action: .start, isCrashed: false, step: 0, trail: []
        )
    }

    /// Der Weg, den Byte schon gefahren ist – bis zum Feld, das er gerade verlassen hat.
    /// Am Ende der ganze Weg, damit man ihn in Ruhe ansehen kann.
    private var trail: [GridPoint] {
        let visited = frames.prefix(isAtEnd ? frames.count : frameIndex).map(\.robot)
        return visited.reduce(into: []) { path, point in
            if path.last != point { path.append(point) }
        }
    }

    /// Wartezeiten der Wiedergabe: Fragen kürzer, lange Fahrten gestaucht.
    private var delays: [Double] { ArenaPlayback.delays(for: frames, base: speed.frameDuration.seconds) }

    /// So lange dauert die Bewegung zum aktuellen Bild – das Spielfeld animiert entsprechend.
    var stepDuration: Double {
        let delays = delays
        let delay = frameIndex < delays.count && frameIndex > 0 ? delays[frameIndex] : speed.frameDuration.seconds
        return min(delay * 0.85, 0.5)
    }

    /// Gelöst und zu Ende abgespielt: Zeit zu feiern.
    var isCelebrating: Bool { result?.solved == true && !isPlayground && !usedSolution && isAtEnd }

    /// Fortlaufender Drehwinkel je Bild, damit eine Drehung von 270° auf 0° nicht rückwärts animiert.
    private var angles: [Double] {
        var angle = world.facing.degrees
        return frames.map { frame in
            switch frame.action {
            case .turnLeft: angle -= 90
            case .turnRight: angle += 90
            default: break
            }
            return angle
        }
    }

    var currentLine: Int? { currentFrame?.line }
    var output: String { currentFrame?.output ?? "" }
    var variables: [JavaVariable] { currentFrame?.variables ?? [] }

    /// Am Ende der Wiedergabe: endgültige Konsolenausgabe (auch Text nach der letzten Roboter-Aktion).
    var displayedOutput: String { isAtEnd ? (currentRun?.output ?? output) : output }

    var lineCount: Int { ArenaEngine.codeLineCount(code) }

    // MARK: Ausführen

    func run() {
        stop()
        let code = code
        let mission = mission
        isRunning = true
        codePanel = .watching
        dismissKeyboard()
        Task {
            // Die Ausführung läuft im Hintergrund – die Oberfläche bleibt flüssig.
            let result = await Task.detached(priority: .userInitiated) { ArenaEngine.run(code, mission: mission) }.value
            self.finishRun(result)
        }
    }

    private func finishRun(_ result: ArenaResult) {
        self.result = result
        runCount += 1
        isRunning = false
        selectedWorld = result.firstFailingWorld ?? 0
        frameIndex = 0
        if result.solved, !isPlayground, !usedSolution {
            let before = store.rewardSnapshot()
            store.recordMission(mission, result: result)
            rewardGain = store.rewardSnapshot().gains(since: before)
        }
        play()
    }

    func play() {
        guard !frames.isEmpty else { return }
        if isAtEnd { frameIndex = 0 }
        playTask?.cancel()
        isPlaying = true
        playTask = Task { [weak self] in
            while let self, !Task.isCancelled, !self.isAtEnd {
                let delays = self.delays
                let next = self.frameIndex + 1
                try? await Task.sleep(for: .seconds(next < delays.count ? delays[next] : self.speed.frameDuration.seconds))
                guard !Task.isCancelled else { return }
                self.advance()
            }
            self?.isPlaying = false
        }
    }

    func pause() {
        playTask?.cancel()
        isPlaying = false
    }

    func step() {
        pause()
        advance()
    }

    func skipToEnd() {
        pause()
        frameIndex = max(frames.count - 1, 0)
        reachedFrame()
    }

    func rewind() {
        pause()
        frameIndex = 0
    }

    private func advance() {
        guard !isAtEnd else { return }
        frameIndex += 1
        reachedFrame()
    }

    private func reachedFrame() {
        if currentFrame?.action.isCrash == true { crashCount += 1 }
        if isCelebrating { celebrationCount += 1 }
    }

    private func stop() {
        playTask?.cancel()
        isPlaying = false
    }

    func selectWorld(_ index: Int) {
        guard worlds.indices.contains(index), index != selectedWorld else { return }
        stop()
        selectedWorld = index
        frameIndex = 0
        if currentRun != nil { play() }
    }

    func edit() {
        stop()
        codePanel = .editing
    }

    private func codeChanged() {
        // Neuer Code: altes Ergebnis passt nicht mehr – zurück zum Startbild.
        stop()
        result = nil
        rewardGain = nil
        frameIndex = 0
        // Ohne Meldung vom Editor ist nach dem Tippen unklar, wo man steht.
        if !isInserting, !editorTracksCursor { cursor = nil }
    }

    // MARK: Hilfen

    /// Fügt einen Befehl oder eine Vorlage dort ein, wo man schreibt – als eigene, eingerückte Zeile.
    func insert(_ snippet: String) {
        codePanel = .editing
        let inserted = CodeInsertion.insert(snippet, into: code, cursor: cursor)
        isInserting = true
        code = inserted.code
        isInserting = false
        cursor = inserted.cursor
        insertionCount += 1
    }

    func resetCode() {
        code = mission.starterCode
        cursor = nil
        codePanel = .editing
    }

    /// Lösung aufdecken: Sie steht danach im Editor, bringt aber keine Sterne.
    func revealSolution() {
        usedSolution = true
        code = mission.solution.source
        cursor = nil
        codePanel = .editing
    }

    /// Beim Verlassen des Bildschirms die Wiedergabe stoppen.
    func leave() {
        stop()
    }
}

/// Darstellungszustand des Spielfelds.
struct ArenaBoardState: Equatable {
    let robot: GridPoint
    let angle: Double
    let coins: Set<GridPoint>
    let collected: Int
    let action: ArenaAction
    let isCrashed: Bool
    /// Nummer des Bildes – damit „+1“ und Unfall bei jedem Bild neu aufpoppen.
    var step = 0
    /// Bisher gefahrener Weg.
    var trail: [GridPoint] = []
}
