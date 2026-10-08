package app.javaquest.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.javaquest.core.ArenaAction
import app.javaquest.core.ArenaConcept
import app.javaquest.core.ArenaConceptUse
import app.javaquest.core.ArenaEngine
import app.javaquest.core.ArenaFrame
import app.javaquest.core.ArenaMission
import app.javaquest.core.ArenaPlayback
import app.javaquest.core.ArenaResult
import app.javaquest.core.ArenaTemplate
import app.javaquest.core.ArenaWorld
import app.javaquest.core.ArenaWorldRun
import app.javaquest.core.CodeInsertion
import app.javaquest.core.GridPoint
import app.javaquest.core.RobotCommand
import app.javaquest.core.interpreter.JavaVariable
import app.javaquest.data.ProgressStore
import app.javaquest.data.RewardGain

/** Darstellungszustand des Spielfelds. */
data class BoardState(val robot: GridPoint, val angle: Float, val coins: Set<GridPoint>, val collected: Int, val action: ArenaAction) {
    val isCrashed: Boolean get() = action.isCrash
}

/**
 * Steuert eine Arena-Mission: Code bearbeiten, ausführen, die Fahrt Bild für Bild abspielen und speichern
 * (wie ArenaMissionModel.swift). Die Wiedergabe treibt der Bildschirm – das Modell hält nur den Zustand.
 */
class ArenaMissionModel(val mission: ArenaMission, private val store: ProgressStore, val isPlayground: Boolean = false) {
    /** Dauer eines normalen Schritts in Sekunden. */
    enum class Speed(val title: String, val seconds: Double) { SLOW("Langsam", 0.7), NORMAL("Normal", 0.38), FAST("Schnell", 0.14) }

    var code by mutableStateOf(mission.starterCode)
        private set
    /** Wo im Editor zuletzt geschrieben wurde (UTF-16) – dort fügt die Befehlsleiste ein. */
    var cursor by mutableStateOf<Int?>(null)
    var isEditing by mutableStateOf(true)
    var speed by mutableStateOf(Speed.NORMAL)
    var result by mutableStateOf<ArenaResult?>(null)
        private set
    var isRunning by mutableStateOf(false)
        private set
    var selectedWorld by mutableIntStateOf(0)
        private set
    var frameIndex by mutableIntStateOf(0)
        private set
    var isPlaying by mutableStateOf(false)
        private set
    var crashCount by mutableIntStateOf(0)
        private set
    var runCount by mutableIntStateOf(0)
        private set
    var usedSolution by mutableStateOf(false)
        private set
    var rewardGain by mutableStateOf<RewardGain?>(null)
        private set
    var showsHint by mutableStateOf(false)

    private val lessonOrder = store.course.allLessons.map { it.id }
    private val lessonNumbers = lessonOrder.withIndex().associate { (index, id) -> id to index + 1 }

    /** Java-Bausteine der Mission für den Werkzeugkasten. */
    val conceptUses: List<ArenaConceptUse> = if (isPlayground) emptyList() else store.catalog.conceptUses(mission)
    /** Befehle, die Byte hier kann – nur die bis zu dieser Mission eingeführten. */
    val commands: List<RobotCommand> = if (isPlayground) RobotCommand.all else RobotCommand.all.filter { it.name in mission.commandNames }
    /** Vorlagen für die Befehlsleiste, die hier schon verständlich sind. */
    val templates: List<ArenaTemplate> = if (isPlayground) ArenaTemplate.all else store.catalog.templates(mission, lessonOrder)
    val knowsMethods: Boolean = isPlayground || store.catalog.knows("methode", mission, lessonOrder)

    /** „Lektion 4“ – wo der Kurs einen Baustein erklärt. */
    fun lessonLabel(concept: ArenaConcept): String? = concept.lessonId?.let { lessonNumbers[it] }?.let { "Lektion $it" }

    /** Steckt im Werkzeugkasten etwas, das hier zum ersten Mal vorkommt? */
    val hasNewTools: Boolean get() = mission.newCommands.isNotEmpty() || conceptUses.any { it.isNew }

    val worlds: List<ArenaWorld> get() = mission.worlds
    val world: ArenaWorld get() = worlds[selectedWorld.coerceAtMost(worlds.lastIndex)]
    val bestStars: Int get() = store.missionStars[mission.id] ?: 0
    val isDaily: Boolean get() = !isPlayground && store.dailyMission?.id == mission.id && !store.isDailyMissionDone

    val currentRun: ArenaWorldRun? get() = result?.runs?.getOrNull(selectedWorld)
    val frames: List<ArenaFrame> get() = currentRun?.frames ?: emptyList()
    val currentFrame: ArenaFrame? get() = frames.getOrNull(frameIndex.coerceAtMost(frames.lastIndex))
    val isAtEnd: Boolean get() = frames.isEmpty() || frameIndex >= frames.lastIndex
    val lineCount: Int get() = ArenaEngine.codeLineCount(code)

    /** Wartezeiten der Wiedergabe in Sekunden – Fragen kürzer, lange Fahrten gestaucht. */
    val delays: List<Double> get() = ArenaPlayback.delays(frames, speed.seconds)

    /** Wie lange das nächste Bild auf sich warten lässt (Millisekunden). */
    val nextDelayMillis: Long get() = ((delays.getOrNull(frameIndex + 1) ?: speed.seconds) * 1000).toLong()

    val board: BoardState
        get() {
            val frame = currentFrame ?: return BoardState(world.start ?: GridPoint(0, 0), world.facing.degrees, world.coins, 0, ArenaAction.Start)
            // Fortlaufender Winkel, damit eine Drehung von 270° auf 0° nicht rückwärts animiert.
            var angle = world.facing.degrees
            for (f in frames.take(frameIndex + 1)) {
                if (f.action == ArenaAction.TurnLeft) angle -= 90f
                if (f.action == ArenaAction.TurnRight) angle += 90f
            }
            return BoardState(frame.robot, angle, frame.coins, frame.collected, frame.action)
        }

    val currentLine: Int? get() = currentFrame?.line
    val variables: List<JavaVariable> get() = currentFrame?.variables ?: emptyList()

    /** Am Ende der Wiedergabe: die vollständige Ausgabe (auch Text nach der letzten Roboter-Aktion). */
    val displayedOutput: String get() = if (isAtEnd) currentRun?.output ?: "" else currentFrame?.output ?: ""

    fun updateCode(text: String, newCursor: Int? = cursor) {
        cursor = newCursor
        if (text == code) return
        code = text
        // Neuer Code: altes Ergebnis passt nicht mehr.
        result = null
        rewardGain = null
        frameIndex = 0
        isPlaying = false
    }

    /** Läuft im Hintergrund (Aufrufer: Dispatchers.Default). */
    fun compute(): ArenaResult = ArenaEngine.run(code, mission)

    fun startRun() {
        isRunning = true
        isPlaying = false
        isEditing = false
    }

    fun finishRun(result: ArenaResult) {
        this.result = result
        runCount++
        isRunning = false
        selectedWorld = result.firstFailingWorld ?: 0
        frameIndex = 0
        if (result.solved && !isPlayground && !usedSolution) {
            val before = store.rewardSnapshot()
            store.recordMission(mission, result)
            rewardGain = store.rewardSnapshot().gains(before)
        }
        play()
    }

    fun play() {
        if (frames.isEmpty()) return
        if (isAtEnd) frameIndex = 0
        isPlaying = true
    }

    fun pause() { isPlaying = false }

    /** Ein Bild weiter – von der Wiedergabe oder per Knopf. */
    fun advance() {
        if (isAtEnd) { isPlaying = false; return }
        frameIndex++
        if (currentFrame?.action?.isCrash == true) crashCount++
        if (isAtEnd) isPlaying = false
    }

    fun step() { pause(); advance() }
    fun rewind() { pause(); frameIndex = 0 }
    fun skipToEnd() {
        pause()
        frameIndex = maxOf(frames.lastIndex, 0)
        if (currentFrame?.action?.isCrash == true) crashCount++
    }

    fun selectWorld(index: Int) {
        if (index !in worlds.indices || index == selectedWorld) return
        selectedWorld = index
        frameIndex = 0
        isPlaying = currentRun != null
    }

    /** Befehl oder Vorlage an der Stelle einfügen, an der man gerade schreibt. */
    fun insert(snippet: String) {
        isEditing = true
        val (text, after) = CodeInsertion.insert(snippet, code, cursor)
        updateCode(text, after)
    }

    fun resetCode() { updateCode(mission.starterCode, null); isEditing = true }

    /** Lösung in den Editor: gibt danach keine Sterne. */
    fun revealSolution() {
        usedSolution = true
        updateCode(mission.solution.source, null)
        isEditing = true
    }
}
