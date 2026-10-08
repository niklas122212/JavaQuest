package app.javaquest.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.BugReport
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Code
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Extension
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.FormatListNumbered
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LooksOne
import androidx.compose.material.icons.rounded.MilitaryTech
import androidx.compose.material.icons.rounded.MonetizationOn
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.WavingHand
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.Achievement
import app.javaquest.core.AchievementIcon
import app.javaquest.core.ArenaAction
import app.javaquest.core.ArenaConceptUse
import app.javaquest.core.ArenaGoal
import app.javaquest.core.ArenaMission
import app.javaquest.core.ArenaResult
import app.javaquest.core.ArenaWorld
import app.javaquest.core.Experience
import app.javaquest.core.GridPoint
import app.javaquest.core.LevelProgress
import app.javaquest.core.MissionKind
import app.javaquest.core.RobotCommand
import app.javaquest.core.StarCriterion
import app.javaquest.core.interpreter.JavaProblem
import app.javaquest.data.RewardGain
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

private object ArenaColors {
    val board = Color(0xFF292B40)
    val wall = Color(0xFF3D405C)
    val wallTop = Color(0xFF4F5273)
    val floor = Color(0xFFEDEBF7)
    val floorAlt = Color(0xFFE3E0F2)
    val goal = Color(0x472EAD61)
    val coin = Color(0xFFFFC72E)
    val coinEdge = Color(0xFFDB8F0D)
    val star = Color(0xFFFFCC00)
}

// ---------------------------------------------------------------- Spielfeld

/**
 * Wände, Münzen, Ziel und Byte. Bewegung und Drehung werden animiert, ein Unfall lässt Byte wackeln
 * und markiert das Wandfeld. Eine Punktspur zeigt, wo Byte schon war.
 */
@Composable
fun ArenaBoard(
    world: ArenaWorld,
    state: BoardState,
    trail: List<GridPoint>,
    crashCount: Int,
    durationMillis: Int,
    modifier: Modifier = Modifier,
) {
    val x by animateFloatAsState(state.robot.x.toFloat(), tween(durationMillis))
    val y by animateFloatAsState(state.robot.y.toFloat(), tween(durationMillis))
    val angle by animateFloatAsState(state.angle, tween(durationMillis))
    val shake = remember { Animatable(0f) }
    LaunchedEffect(crashCount) {
        if (crashCount > 0) for (target in listOf(8f, -8f, 6f, -6f, 0f)) shake.animateTo(target, tween(50))
    }
    val crash = state.action as? ArenaAction.Crash
    Box(
        modifier.clip(RoundedCornerShape(InnerRadius)).background(ArenaColors.board).padding(10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.fillMaxWidth().aspectRatio(world.width.toFloat() / world.height.coerceAtLeast(1)).testTag("arena-board")) {
            val cell = minOf(size.width / world.width, size.height / world.height)
            for (row in 0 until world.height) for (col in 0 until world.width) {
                val p = GridPoint(col, row)
                val topLeft = Offset(col * cell, row * cell)
                if (world.isWall(p)) {
                    val hit = crash?.wall == p
                    drawRoundRect(if (hit) Palette.ember else ArenaColors.wall, topLeft + Offset(1f, 1f), Size(cell - 2, cell - 2), CornerRadius(cell * 0.16f))
                    drawRoundRect(if (hit) Palette.ember.copy(alpha = 0.7f) else ArenaColors.wallTop, topLeft + Offset(cell * 0.18f, cell * 0.18f), Size(cell * 0.64f, cell * 0.64f), CornerRadius(cell * 0.1f))
                } else {
                    val color = if (p == world.goal) ArenaColors.goal else if ((row + col) % 2 == 0) ArenaColors.floor else ArenaColors.floorAlt
                    drawRoundRect(color, topLeft + Offset(1.5f, 1.5f), Size(cell - 3, cell - 3), CornerRadius(cell * 0.14f))
                }
            }
            // Punktspur: die Felder, auf denen Byte schon stand.
            for (point in trail) {
                drawCircle(Palette.orange.copy(alpha = 0.45f), cell * 0.07f, Offset((point.x + 0.5f) * cell, (point.y + 0.5f) * cell))
            }
            world.goal?.let { g ->
                // Zielflagge: Mast und kariertes Fähnchen.
                val base = Offset(g.x * cell + cell * 0.38f, g.y * cell + cell * 0.22f)
                drawLine(Palette.success, base, base + Offset(0f, cell * 0.58f), strokeWidth = cell * 0.06f)
                for (i in 0 until 3) for (j in 0 until 2) {
                    drawRect(if ((i + j) % 2 == 0) Palette.success else Color.White, base + Offset(i * cell * 0.1f, j * cell * 0.1f), Size(cell * 0.1f, cell * 0.1f))
                }
            }
            for (coin in state.coins) {
                val center = Offset((coin.x + 0.5f) * cell, (coin.y + 0.5f) * cell)
                drawCircle(ArenaColors.coin, cell * 0.25f, center)
                drawCircle(ArenaColors.coinEdge, cell * 0.17f, center, style = Stroke(cell * 0.05f))
            }
            // Byte: runder Körper, Nase in Fahrtrichtung, Augen vorne.
            val center = Offset((x + 0.5f) * cell + shake.value, (y + 0.5f) * cell)
            val radius = cell * 0.36f
            val body = if (state.isCrashed) Palette.ember else Palette.orange
            rotate(angle, center) {
                val nose = Path().apply {
                    moveTo(center.x + radius * 1.35f, center.y)
                    lineTo(center.x + radius * 0.8f, center.y - radius * 0.35f)
                    lineTo(center.x + radius * 0.8f, center.y + radius * 0.35f)
                    close()
                }
                drawPath(nose, body)
                drawCircle(body, radius, center)
                drawCircle(Color.White, radius, center, style = Stroke(radius * 0.14f))
                for (dy in listOf(-0.32f, 0.32f)) {
                    val eye = center + Offset(radius * 0.35f, radius * dy)
                    drawCircle(Color.White, radius * 0.22f, eye)
                    drawCircle(if (state.isCrashed) Palette.ember else ArenaColors.board, radius * 0.11f, eye)
                }
            }
        }
        val action = state.action
        val bubble: Pair<String, Color>? = when {
            action is ArenaAction.Look -> {
                val label = RobotCommand.all.firstOrNull { it.name == action.question }?.summary ?: action.question
                "$label ${if (action.answer) "ja" else "nein"}" to (if (action.answer) Palette.success else Palette.indigo)
            }
            action is ArenaAction.Crash && action.wall == null -> "Hier liegt keine Münze!" to Palette.ember
            action is ArenaAction.Crash -> "Bumm – eine Wand!" to Palette.ember
            action == ArenaAction.PickCoin -> "+1" to ArenaColors.coinEdge
            else -> null
        }
        bubble?.let { (text, tint) ->
            Text(
                text, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.TopCenter).clip(CircleShape).background(tint).padding(horizontal = 10.dp, vertical = 4.dp).testTag("arena-bubble"),
            )
        }
        if (world.coins.isNotEmpty()) {
            Text(
                "● ${state.collected}/${world.coins.size}", color = ArenaColors.coin, fontWeight = FontWeight.Bold, fontSize = 13.sp,
                modifier = Modifier.align(Alignment.TopEnd).clip(CircleShape).background(Color.Black.copy(alpha = 0.35f)).padding(horizontal = 9.dp, vertical = 4.dp),
            )
        }
    }
}

/** So liest man das Spielfeld – und wohin Byte am Anfang schaut. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BoardLegend(world: ArenaWorld) {
    @Composable
    fun item(text: String, icon: @Composable () -> Unit) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(18.dp), contentAlignment = Alignment.Center) { icon() }
            Spacer(Modifier.width(6.dp))
            Text(text, fontSize = 12.sp, color = secondaryText)
        }
    }
    FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        item("Byte – schaut am Anfang ${world.facing.direction}") { Box(Modifier.size(14.dp).clip(CircleShape).background(Palette.orange)) }
        if (world.goal != null) item("Ziel") { Icon(Icons.Rounded.Flag, null, tint = Palette.success, modifier = Modifier.size(18.dp)) }
        if (world.coins.isNotEmpty()) item("Münze") { Box(Modifier.size(13.dp).clip(CircleShape).background(ArenaColors.coin)) }
        item("Wand") { Box(Modifier.size(14.dp).clip(RoundedCornerShape(3.dp)).background(ArenaColors.wall)) }
    }
}

// ---------------------------------------------------------------- Mission

sealed interface ArenaContext {
    /** Abschluss einer Lektion: danach geht es zur Auswertung. */
    class Lesson(val onFinish: (ArenaResult?) -> Unit) : ArenaContext
    /** Aus der Arena-Übersicht oder als Tagesmission. */
    class Standalone(val onClose: () -> Unit) : ArenaContext
}

@Composable
fun ArenaMissionScreen(model: ArenaMissionModel, context: ArenaContext) {
    val scope = rememberCoroutineScope()
    // Wiedergabe: ein Bild nach dem anderen, Fragen kürzer, lange Fahrten gestaucht.
    LaunchedEffect(model.isPlaying, model.frameIndex, model.selectedWorld) {
        if (model.isPlaying) {
            delay(model.nextDelayMillis)
            model.advance()
        }
    }
    fun run() {
        model.startRun()
        scope.launch {
            val result = withContext(Dispatchers.Default) { model.compute() }
            model.finishRun(result)
        }
    }
    var confirmSolution by remember { mutableStateOf(false) }
    val kompakt = LocalKompakt.current

    Column(Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(if (kompakt) 12.dp else 24.dp), contentAlignment = Alignment.TopCenter) {
            val wide = maxWidth >= 880.dp
            if (wide) {
                Row(Modifier.widthIn(max = 1280.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        MissionBriefing(model, showsGuide = false)
                        BoardCard(model)
                        ConsoleCard(model)
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        CodeCard(model)
                        ResultSection(model)
                        Column(Modifier.fillMaxWidth().card(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { MissionGuide(model) }
                    }
                }
            } else {
                Column(Modifier.widthIn(max = 860.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    MissionBriefing(model, showsGuide = true)
                    BoardCard(model)
                    CodeCard(model)
                    ConsoleCard(model)
                    ResultSection(model)
                }
            }
        }
        val surfaces = LocalSurfaces.current
        Box(Modifier.fillMaxWidth().background(surfaces.card).padding(horizontal = if (kompakt) 12.dp else 20.dp, vertical = 12.dp), contentAlignment = Alignment.Center) {
            Row(Modifier.widthIn(max = 900.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(if (kompakt) 8.dp else 12.dp)) {
                if (!model.isPlayground) {
                    SecondaryButton(if (kompakt) "" else "Tipp", Icons.Rounded.Lightbulb, Modifier.testTag("arena-hint")) { model.showsHint = !model.showsHint }
                    SecondaryButton(if (kompakt) "" else "Startcode", Icons.AutoMirrored.Rounded.Undo, Modifier.testTag("arena-reset")) { model.resetCode() }
                    if (model.runCount > 0 && !model.usedSolution) {
                        SecondaryButton(if (kompakt) "" else "Lösung", Icons.Rounded.Visibility, Modifier.testTag("arena-solution"), tint = Palette.indigo) {
                            confirmSolution = true
                        }
                    }
                    if (context is ArenaContext.Lesson && model.result?.solved != true) {
                        SecondaryButton("Überspringen", null, Modifier.testTag("arena-skip"), tint = Palette.gray) { context.onFinish(null) }
                    }
                }
                val solved = model.result?.solved == true && !model.isPlaying
                if (solved) {
                    when (context) {
                        is ArenaContext.Lesson -> PrimaryButton("Weiter zur Auswertung", Icons.AutoMirrored.Rounded.ArrowForward, Modifier.weight(1f).testTag("arena-finish"), brush = Palette.successGradient) {
                            context.onFinish(model.result)
                        }
                        is ArenaContext.Standalone -> PrimaryButton("Fertig", Icons.Rounded.CheckCircle, Modifier.weight(1f).testTag("arena-finish"), brush = Palette.successGradient) {
                            context.onClose()
                        }
                    }
                } else {
                    PrimaryButton(
                        if (model.isRunning) "Läuft …" else if (model.runCount == 0) "Ausführen" else "Erneut ausführen",
                        Icons.Rounded.PlayArrow,
                        Modifier.weight(1f).testTag("arena-run"),
                        enabled = !model.isRunning && model.code.isNotBlank(),
                        brush = Palette.successGradient,
                    ) { run() }
                }
            }
        }
    }
    if (confirmSolution) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { confirmSolution = false },
            title = { Text("Lösung anzeigen?") },
            text = { Text("Mit der gezeigten Lösung gibt es keine Sterne und keine XP – aber du kannst nachlesen, wie sie funktioniert.") },
            confirmButton = { androidx.compose.material3.TextButton({ confirmSolution = false; model.revealSolution() }) { Text("Lösung in den Editor") } },
            dismissButton = { androidx.compose.material3.TextButton({ confirmSolution = false }) { Text("Abbrechen") } },
        )
    }
}

private fun kindStyle(mission: ArenaMission, playground: Boolean): Triple<String, ImageVector, Color> = when {
    playground -> Triple("Spielplatz", Icons.Rounded.AutoAwesome, Palette.teal)
    mission.kind == MissionKind.BOSS -> Triple("Boss-Level", Icons.Rounded.Shield, Palette.ember)
    mission.kind == MissionKind.TRAINING -> Triple("Training", Icons.Rounded.FitnessCenter, Palette.violet)
    else -> Triple("Mission", Icons.Rounded.SportsEsports, Palette.indigo)
}

@Composable
private fun MissionBriefing(model: ArenaMissionModel, showsGuide: Boolean) {
    val mission = model.mission
    Column(Modifier.fillMaxWidth().card(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            val (label, icon, tint) = kindStyle(mission, model.isPlayground)
            Chip(label, icon, tint)
            if (model.isDaily) { Spacer(Modifier.width(8.dp)); Chip("Tagesmission", Icons.Rounded.WbSunny, Palette.orange) }
            Spacer(Modifier.weight(1f))
            if (!model.isPlayground) StarRow(model.bestStars, 18.dp)
        }
        Text(mission.title, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text(mission.story, color = secondaryText, fontSize = 15.sp, lineHeight = 21.sp)
        if (!model.isPlayground) {
            BriefingSection("Dein Auftrag", Icons.Rounded.Flag) {
                Column(verticalArrangement = Arrangement.spacedBy(9.dp)) { mission.goals.forEach { GoalRow(it) } }
            }
        }
        if (showsGuide) MissionGuide(model)
    }
}

/** Der Weg zum Ziel: Schritte in Worten, Werkzeugkasten (Bausteine und Befehle) und Sterne. */
@Composable
private fun ColumnScope.MissionGuide(model: ArenaMissionModel) {
    var showsSteps by remember(model) { mutableStateOf(true) }
    // Aufgeklappt, wenn etwas Neues darin steckt – Bekanntes bleibt kompakt.
    var showsToolbox by remember(model) { mutableStateOf(model.isPlayground || model.hasNewTools) }
    val mission = model.mission
    if (!model.isPlayground && mission.steps.isNotEmpty()) {
        BriefingSection("So gehst du vor", Icons.Rounded.FormatListNumbered, expanded = showsSteps, onToggle = { showsSteps = !showsSteps }) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                mission.steps.forEachIndexed { index, step ->
                    Row(verticalAlignment = Alignment.Top) {
                        Box(Modifier.size(20.dp).clip(CircleShape).background(Palette.indigo), contentAlignment = Alignment.Center) {
                            Text("${index + 1}", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold)
                        }
                        Spacer(Modifier.width(10.dp))
                        Text(step, fontSize = 14.sp, lineHeight = 20.sp)
                    }
                }
            }
        }
    }
    val summary = (model.conceptUses.map { it.concept.title } + (if (model.commands.size == 1) "1 Befehl" else "${model.commands.size} Befehle")).joinToString(" · ")
    BriefingSection(
        if (model.isPlayground) "Das kann Byte" else "Dein Werkzeugkasten", Icons.Rounded.Build,
        expanded = showsToolbox, onToggle = { showsToolbox = !showsToolbox }, collapsedSummary = summary,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (model.conceptUses.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Caption("Java-Bausteine, die du brauchst")
                    model.conceptUses.forEach { ConceptRow(it, model.lessonLabel(it.concept)) }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Caption(if (model.isPlayground) "Alle Befehle" else "Befehle, die Byte hier kann")
                model.commands.forEach { command ->
                    val isNew = command.name in mission.newCommands
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(command.call + if (command.returnType == "void") ";" else "", fontFamily = CodeFont, fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold, color = if (isNew) Palette.orange else Palette.indigo)
                            if (isNew) { Spacer(Modifier.width(8.dp)); NewBadge() }
                        }
                        Text(command.detail, color = secondaryText, fontSize = 13.sp)
                    }
                }
            }
        }
    }
    if (!model.isPlayground) {
        BriefingSection("Sterne", Icons.Rounded.Star) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                StarGoal("Auftrag erfüllt")
                mission.bonus.forEach { StarGoal(it.title) }
            }
        }
    }
}

/** Überschrift eines Auftragsteils – aufklappbar, wenn [onToggle] gesetzt ist. */
@Composable
private fun BriefingSection(
    title: String,
    icon: ImageVector,
    expanded: Boolean = true,
    onToggle: (() -> Unit)? = null,
    collapsedSummary: String? = null,
    content: @Composable () -> Unit,
) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LocalSurfaces.current.field).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            Modifier.fillMaxWidth().then(if (onToggle != null) Modifier.clickableHand(onClick = onToggle) else Modifier),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(icon, null, tint = Palette.indigo, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(title, color = Palette.indigo, fontWeight = FontWeight.Bold, fontSize = 14.sp, modifier = Modifier.weight(1f))
            if (onToggle != null) Icon(if (expanded) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, null, tint = secondaryText)
        }
        if (expanded) content()
        else if (collapsedSummary != null) Text(collapsedSummary, color = secondaryText, fontSize = 13.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun Caption(text: String) {
    Text(text.uppercase(), fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = secondaryText)
}

@Composable
private fun NewBadge() {
    Text("NEU", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
        modifier = Modifier.clip(CircleShape).background(Palette.orange).padding(horizontal = 6.dp, vertical = 2.dp))
}

/** Ein Punkt im Auftrag – bei der Ausgabe mit dem genauen Text, der erscheinen muss. */
@Composable
private fun GoalRow(goal: ArenaGoal) {
    val (icon, tint) = when (goal.kind) {
        ArenaGoal.Kind.REACH_GOAL -> Icons.Rounded.Flag to Palette.success
        ArenaGoal.Kind.COLLECT_COINS -> Icons.Rounded.MonetizationOn to ArenaColors.coinEdge
        ArenaGoal.Kind.OUTPUT -> Icons.Rounded.ChatBubble to Palette.indigo
        ArenaGoal.Kind.RULE -> Icons.Rounded.Verified to Palette.violet
        ArenaGoal.Kind.ALL_WORLDS -> Icons.Rounded.Layers to Palette.teal
    }
    Row(verticalAlignment = Alignment.Top) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(goal.text, fontSize = 14.sp, lineHeight = 20.sp)
            goal.outputs.forEach { output ->
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    output.world?.let { Text("Welt $it", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = secondaryText) }
                    Text(output.text, fontFamily = CodeFont, fontSize = 13.sp, color = CodeColors.plain,
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(CodeColors.background).padding(horizontal = 10.dp, vertical = 6.dp))
                }
            }
        }
    }
}

/** Ein Java-Baustein mit Mini-Beispiel – „NEU“, wenn ihn hier zum ersten Mal jemand braucht. */
@Composable
private fun ConceptRow(use: ArenaConceptUse, lessonLabel: String?) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(use.concept.title, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Spacer(Modifier.width(8.dp))
            if (use.isNew) NewBadge() else if (lessonLabel != null) Text("aus $lessonLabel", fontSize = 12.sp, color = secondaryText)
        }
        Text(highlighted(use.concept.code), fontFamily = CodeFont, fontSize = 13.sp,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(CodeColors.background).padding(horizontal = 10.dp, vertical = 6.dp))
        Text(use.concept.text, color = secondaryText, fontSize = 13.sp, lineHeight = 18.sp)
    }
}

@Composable
private fun StarGoal(text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Rounded.Star, null, tint = ArenaColors.star, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(8.dp))
        Text(text, fontSize = 13.sp)
    }
}

@Composable
private fun BoardCard(model: ArenaMissionModel) {
    Column(Modifier.fillMaxWidth().card(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (model.worlds.size > 1) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                model.worlds.indices.forEach { index ->
                    val run = model.result?.runs?.getOrNull(index)
                    val selected = index == model.selectedWorld
                    Row(
                        Modifier.clip(CircleShape).background(if (selected) Palette.indigo.copy(alpha = 0.16f) else LocalSurfaces.current.field)
                            .border(1.5.dp, if (selected) Palette.indigo else Color.Transparent, CircleShape)
                            .clickableHand { model.selectWorld(index) }.padding(horizontal = 12.dp, vertical = 6.dp)
                            .testTag("arena-world-$index"),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        if (run != null) {
                            Icon(if (run.succeeded) Icons.Rounded.CheckCircle else Icons.Rounded.Cancel, null,
                                tint = if (run.succeeded) Palette.success else Palette.ember, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(5.dp))
                        }
                        Text("Welt ${index + 1}", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    }
                }
            }
        }
        // Punktspur: bis zum aktuellen Bild, am Ende die ganze Fahrt; gleiche Felder hintereinander nur einmal.
        val frames = model.frames
        val upTo = if (model.isAtEnd) frames.size else model.frameIndex
        val trail = frames.take(upTo).map { it.robot }.fold(mutableListOf<GridPoint>()) { acc, p -> if (acc.lastOrNull() != p) acc += p; acc }
        val duration = (model.nextDelayMillis * 0.85).roundToInt().coerceIn(40, 500)
        ArenaBoard(model.world, model.board, trail, model.crashCount, duration, Modifier.fillMaxWidth().heightIn(max = 440.dp))
        BoardLegend(model.world)
        Row(Modifier.horizontalScroll(rememberScrollState()), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            val noFrames = frames.isEmpty()
            ControlButton(Icons.Rounded.SkipPrevious, "Zum Anfang", !noFrames) { model.rewind() }
            ControlButton(if (model.isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, "Abspielen", !noFrames, prominent = true) {
                if (model.isPlaying) model.pause() else model.play()
            }
            ControlButton(Icons.AutoMirrored.Rounded.ArrowForward, "Ein Schritt", !noFrames && !model.isAtEnd) { model.step() }
            ControlButton(Icons.Rounded.SkipNext, "Zum Ende", !noFrames && !model.isAtEnd) { model.skipToEnd() }
            if (!noFrames) Text("${model.frameIndex + 1}/${frames.size}", color = secondaryText, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 6.dp))
            ArenaMissionModel.Speed.entries.forEach { speed ->
                val selected = model.speed == speed
                Text(
                    speed.title, fontSize = 13.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                    color = if (selected) Palette.orange else secondaryText,
                    modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickableHand { model.speed = speed }.padding(horizontal = 6.dp, vertical = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun ControlButton(icon: ImageVector, label: String, enabled: Boolean, prominent: Boolean = false, onClick: () -> Unit) {
    Box(
        Modifier.size(width = if (prominent) 46.dp else 38.dp, height = 38.dp).alpha(if (enabled) 1f else 0.4f).clip(RoundedCornerShape(10.dp))
            .background(if (prominent) Palette.indigo else Palette.indigo.copy(alpha = 0.12f))
            .clickableHand(enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, label, tint = if (prominent) Color.White else Palette.indigo, modifier = Modifier.size(20.dp)) }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CodeCard(model: ArenaMissionModel) {
    Column(Modifier.fillMaxWidth().card(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Code, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("Dein Java-Code", fontWeight = FontWeight.Bold, fontSize = 17.sp, modifier = Modifier.weight(1f))
            Text(if (model.lineCount == 1) "1 Zeile" else "${model.lineCount} Zeilen", color = secondaryText, fontSize = 13.sp)
            if (!model.isEditing) {
                Spacer(Modifier.width(12.dp))
                SecondaryButton("Bearbeiten", Icons.Rounded.Edit, Modifier.testTag("arena-edit")) { model.isEditing = true; model.pause() }
            }
        }
        if (model.isEditing) {
            CodeEditor(
                model.code, "// Befehle für Byte, z. B. robot.move();", 240.dp, false, "arena-editor",
                cursor = model.cursor, onCursor = { model.cursor = it },
            ) { model.updateCode(it) }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                model.commands.forEach { command ->
                    val isNew = command.name in model.mission.newCommands
                    Text(
                        command.call, fontFamily = CodeFont, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        color = if (isNew) Color.White else Palette.indigo,
                        modifier = Modifier.clip(CircleShape).background(if (isNew) Palette.orange else Palette.indigo.copy(alpha = 0.12f))
                            .clickableHand { model.insert(if (command.returnType == "void") "${command.call};" else command.call) }
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                            .testTag("arena-command-${command.name}"),
                    )
                }
                model.templates.forEach { template ->
                    Text(
                        "+ ${template.name}", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.violet,
                        modifier = Modifier.clip(CircleShape).background(Palette.violet.copy(alpha = 0.12f)).clickableHand { model.insert(template.code) }
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
            }
        } else {
            TraceCode(model.code, model.currentLine, if (model.isAtEnd) model.currentRun?.problem?.line else null) {
                model.isEditing = true
                model.pause()
            }
        }
        if (model.knowsMethods) {
            Text(
                (if (model.isPlayground) "" else "Tipp: ") + "Eigene Methoden (static void …) darfst du über oder unter deine Befehle schreiben.",
                color = secondaryText, fontSize = 12.sp,
            )
        }
    }
}

/** Code beim Zuschauen: die laufende Zeile leuchtet, eine Fehlerzeile wird rot. Ein Klick öffnet den Editor. */
@Composable
private fun TraceCode(code: String, currentLine: Int?, errorLine: Int?, onEdit: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().heightIn(min = 160.dp).clip(RoundedCornerShape(InnerRadius)).background(CodeColors.background)
            .clickableHand(onClick = onEdit).padding(vertical = 8.dp).testTag("arena-trace"),
    ) {
        code.split("\n").forEachIndexed { index, line ->
            val number = index + 1
            val background = when (number) {
                errorLine -> Palette.ember.copy(alpha = 0.3f)
                currentLine -> Palette.orange.copy(alpha = 0.22f)
                else -> Color.Transparent
            }
            Row(Modifier.fillMaxWidth().background(background).padding(horizontal = 10.dp, vertical = 3.dp)) {
                Text("$number", color = CodeColors.plain.copy(alpha = 0.35f), fontFamily = CodeFont, fontSize = 12.sp, modifier = Modifier.width(26.dp))
                Text(highlighted(line.ifEmpty { " " }), fontFamily = CodeFont, fontSize = 14.sp, softWrap = false, modifier = Modifier.horizontalScroll(rememberScrollState()))
            }
        }
    }
}

@Composable
private fun ConsoleCard(model: ArenaMissionModel) {
    if (model.result == null) return
    BoxWithConstraints(Modifier.fillMaxWidth().card(14.dp)) {
        val side = maxWidth >= 480.dp
        val console: @Composable (Modifier) -> Unit = { modifier ->
            Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Terminal, null, tint = secondaryText, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Konsole", color = secondaryText, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
                val output = model.displayedOutput
                Text(
                    output.ifEmpty { "(noch keine Ausgabe)" }, fontFamily = CodeFont, fontSize = 13.sp,
                    color = if (output.isEmpty()) CodeColors.plain.copy(alpha = 0.4f) else CodeColors.plain,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).background(CodeColors.background).padding(10.dp).testTag("arena-console"),
                )
            }
        }
        val variables: @Composable (Modifier) -> Unit = { modifier ->
            Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Variablen", color = secondaryText, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Palette.indigo.copy(alpha = 0.08f)).padding(10.dp)) {
                    model.variables.forEach { variable ->
                        Text("${variable.name} = ${variable.value}", fontFamily = CodeFont, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
        if (side) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                console(Modifier.weight(1f))
                if (model.variables.isNotEmpty()) variables(Modifier.width(220.dp))
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                console(Modifier.fillMaxWidth())
                if (model.variables.isNotEmpty()) variables(Modifier.fillMaxWidth())
            }
        }
    }
}

@Composable
private fun ResultSection(model: ArenaMissionModel) {
    if (model.showsHint) {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(InnerRadius)).background(Palette.orange.copy(alpha = 0.1f)).padding(14.dp).testTag("arena-hint-text")) {
            Icon(Icons.Rounded.Lightbulb, null, tint = Palette.orange, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(model.mission.hint, fontSize = 15.sp)
        }
    }
    val result = model.result
    if (result != null && !model.isPlaying) MissionResultPanel(model, result)
    // Die Musterlösung erst nach dem Ende der Wiedergabe – sonst verrät sie zu früh, was gefehlt hat.
    if (!model.isPlayground && !model.isPlaying && (model.usedSolution || result?.solved == true)) {
        Column(Modifier.fillMaxWidth().card(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Eyebrow("Musterlösung", Palette.orange)
            CodeBlock(highlighted(model.mission.solution.source), caption = "Java")
        }
    }
}

/** Fehlermeldungen je Welt – derselbe Fehler überall steht nur einmal da. */
private fun failureMessages(model: ArenaMissionModel, result: ArenaResult): List<String> {
    val runs = result.runs
    // Ein Syntaxfehler ist in jeder Welt derselbe und hat keinen Welt-Bezug.
    val syntax = runs.firstOrNull()?.problem?.takeIf { it.kind == JavaProblem.Kind.SYNTAX || it.kind == JavaProblem.Kind.UNSUPPORTED }
    if (syntax != null) return result.missingRequirements + syntax.description
    val perWorld = runs.map { it.failures }
    val messages = mutableListOf<String>()
    messages += result.missingRequirements
    if (model.worlds.size > 1 && runs.size == model.worlds.size && perWorld.toSet().size == 1 && perWorld.first().isNotEmpty()) {
        messages += perWorld.first().map { "In allen Welten: $it" }
    } else {
        perWorld.forEachIndexed { index, failures ->
            messages += failures.map { if (model.worlds.size > 1) "Welt ${index + 1}: $it" else it }
        }
    }
    return messages
}

@Composable
private fun MissionResultPanel(model: ArenaMissionModel, result: ArenaResult) {
    val tint = if (model.isPlayground) Palette.teal else if (result.solved) Palette.success else Palette.orange
    val shape = RoundedCornerShape(CardRadius)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(tint.copy(alpha = 0.1f)).border(1.dp, tint.copy(alpha = 0.3f), shape).padding(18.dp).testTag("arena-result"),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (model.isPlayground) {
            val run = result.runs.firstOrNull()
            Text(if (run?.problem == null) "Programm fertig ausgeführt" else "Programm angehalten", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = tint)
            run?.problem?.let { Text(it.description, fontSize = 15.sp) }
            Text("Byte hat ${run?.actions ?: 0} Aktionen gemacht und ${(run?.world?.coins?.size ?: 0) - (run?.coinsLeft ?: 0)} Münzen eingesammelt.", color = secondaryText, fontSize = 14.sp)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(if (result.solved) Icons.Rounded.CheckCircle else Icons.Rounded.Repeat, null, tint = tint, modifier = Modifier.size(30.dp))
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(if (!result.solved) "Noch nicht ganz" else if (result.stars == 3) "Perfekt gelöst!" else "Mission geschafft!", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text(
                        when {
                            model.usedSolution -> "Mit der gezeigten Lösung gibt es keine Sterne."
                            result.solved && result.stars == 3 -> "Alle drei Sterne – stark!"
                            result.solved -> "Schaffst du auch die übrigen Sterne?"
                            else -> "Schau dir an, wo Byte hängen bleibt – und passe den Code an."
                        },
                        color = secondaryText, fontSize = 14.sp,
                    )
                }
                StarRow(result.stars, 24.dp)
            }
            CriterionRow(result.solved, "Auftrag erfüllt", null)
            result.criteria.forEach { CriterionRow(it.met, it.criterion.title, it.progress) }
            failureMessages(model, result).take(5).forEach { message ->
                Row {
                    Icon(Icons.Rounded.Cancel, null, tint = Palette.ember, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(message, fontSize = 14.sp)
                }
            }
        }
        result.warnings.forEach { Text("Zeile ${it.line}: ${it.message}", color = Palette.orange, fontSize = 13.sp) }
        model.rewardGain?.takeIf { !it.isEmpty }?.let { RewardBanner(it) }
    }
}

@Composable
private fun CriterionRow(met: Boolean, title: String, progress: String?) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(if (met) Icons.Rounded.Star else Icons.Rounded.StarBorder, null, tint = if (met) ArenaColors.star else secondaryText, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, fontSize = 14.sp, modifier = Modifier.weight(1f, fill = false))
        progress?.let {
            Spacer(Modifier.width(8.dp))
            Text(it, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (met) Palette.success else Palette.orange,
                modifier = Modifier.clip(CircleShape).background((if (met) Palette.success else Palette.orange).copy(alpha = 0.12f)).padding(horizontal = 8.dp, vertical = 2.dp))
        }
    }
}

/** „+75 XP“, Levelaufstieg und neue Abzeichen. */
@Composable
fun RewardBanner(gain: RewardGain) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Palette.violet.copy(alpha = 0.08f)).padding(12.dp).testTag("reward"),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (gain.xp > 0) Text("+${gain.xp} XP", color = Palette.violet, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            gain.levelUp?.let { Spacer(Modifier.width(14.dp)); Text("Level $it!", color = Palette.orange, fontWeight = FontWeight.Bold, fontSize = 17.sp) }
        }
        gain.newAchievements.forEach { achievement ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconTile(achievementIcon(achievement), Palette.orange, 34.dp)
                Spacer(Modifier.width(10.dp))
                Column {
                    Text("Neues Abzeichen: ${achievement.title}", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Text(achievement.detail, color = secondaryText, fontSize = 12.sp)
                }
            }
        }
    }
}

fun achievementIcon(achievement: Achievement): ImageVector = when (achievement.icon) {
    AchievementIcon.WAVE -> Icons.Rounded.WavingHand
    AchievementIcon.FLAG -> Icons.Rounded.Flag
    AchievementIcon.STAR -> Icons.Rounded.Star
    AchievementIcon.BOLT -> Icons.Rounded.Bolt
    AchievementIcon.FLAME -> Icons.Rounded.LocalFireDepartment
    AchievementIcon.CODE -> Icons.Rounded.Code
    AchievementIcon.BUG -> Icons.Rounded.BugReport
    AchievementIcon.PUZZLE -> Icons.Rounded.Extension
    AchievementIcon.GAME -> Icons.Rounded.SportsEsports
    AchievementIcon.SPARKLES -> Icons.Rounded.AutoAwesome
    AchievementIcon.SHIELD -> Icons.Rounded.Shield
    AchievementIcon.CROWN -> Icons.Rounded.WorkspacePremium
    AchievementIcon.SUN -> Icons.Rounded.WbSunny
    AchievementIcon.REPEAT -> Icons.Rounded.Repeat
    AchievementIcon.ONE -> Icons.Rounded.LooksOne
    AchievementIcon.UP -> Icons.AutoMirrored.Rounded.TrendingUp
    AchievementIcon.TROPHY -> Icons.Rounded.EmojiEvents
}

// ---------------------------------------------------------------- Sitzung, Übersicht, Karten

/** Mission oder Spielplatz außerhalb einer Lektion – mit Kopfzeile zum Schließen. */
@Composable
fun ArenaSessionScreen(model: ArenaMissionModel, onClose: () -> Unit) {
    val surfaces = LocalSurfaces.current
    Column(Modifier.fillMaxSize().background(surfaces.screen)) {
        Row(Modifier.fillMaxWidth().background(surfaces.card).padding(horizontal = 20.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(38.dp).clip(CircleShape).background(surfaces.field).clickableHand(onClick = onClose).testTag("close-arena"), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Close, "Schließen", modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(16.dp))
            Text(model.mission.title, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Box(Modifier.weight(1f)) { ArenaMissionScreen(model, ArenaContext.Standalone(onClose)) }
    }
}

@Composable
fun ArenaHomeScreen(state: AppState) {
    val store = state.store
    val stars = store.missionStars
    val kompakt = LocalKompakt.current
    ScreenScroll {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(CardRadius))
                .background(Brush.linearGradient(listOf(ArenaColors.board, Palette.indigo))).padding(if (kompakt) 16.dp else 22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (!kompakt) {
                Box(Modifier.size(76.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.SportsEsports, null, tint = Palette.orange, modifier = Modifier.size(44.dp))
                }
                Spacer(Modifier.width(18.dp))
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Die Arena", color = Color.White, fontSize = if (kompakt) 26.sp else 30.sp, fontWeight = FontWeight.Black)
                Text("Steuere Byte mit echtem Java-Code: Jede Zeile, die du schreibst, wird wirklich ausgeführt – und du siehst sofort, was sie bewirkt.",
                    color = Color.White.copy(alpha = 0.9f), fontSize = 15.sp)
                Text("★ ${stars.values.sum()} von ${store.catalog.missions.size * 3} Sternen", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            }
        }
        val playground: @Composable (Modifier) -> Unit = { modifier ->
            Column(modifier.card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Eyebrow("Spielplatz", Palette.teal)
                Text("Freies Ausprobieren", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("Eine offene Welt mit Münzen und Mauern: Teste Schleifen, Methoden und Ideen, ganz ohne Druck.", color = secondaryText, fontSize = 14.sp)
                SecondaryButton("Spielplatz öffnen", Icons.Rounded.PlayArrow, Modifier.fillMaxWidth().testTag("open-playground"), tint = Palette.teal) { state.openPlayground() }
            }
        }
        KachelRaster(listOf({ m -> DailyMissionCard(state, m) }, playground), 16.dp)
        for (module in store.course.modules) {
            val lessonIds = module.lessons.map { it.id }
            val missions = store.catalog.missions
                .filter { if (it.kind == MissionKind.BOSS) it.moduleId == module.id else it.lessonId in lessonIds }
                .sortedWith(compareBy({ if (it.kind == MissionKind.BOSS) 1 else 0 }, { lessonIds.indexOf(it.lessonId) }, { it.kind.ordinal }))
            if (missions.isEmpty()) continue
            SectionTitle(module.title, module.subtitle)
            KachelRaster(missions.map { mission -> { m: Modifier -> MissionTile(state, mission, stars[mission.id] ?: 0, m) } }, 12.dp, maxJeZeile = 4)
        }
    }
}

@Composable
private fun MissionTile(state: AppState, mission: ArenaMission, stars: Int, modifier: Modifier) {
    val unlocked = state.store.isUnlocked(mission)
    val (label, icon, tint) = kindStyle(mission, false)
    Row(
        modifier.alpha(if (unlocked) 1f else 0.55f).card(14.dp)
            .then(if (unlocked) Modifier.clickableHand { state.startMission(mission.id) } else Modifier)
            .testTag("mission-${mission.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconTile(if (unlocked) icon else Icons.Rounded.Lock, if (unlocked) tint else Palette.gray, 42.dp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(label.uppercase() + if (mission.worlds.size > 1) " · ${mission.worlds.size} Welten" else "", color = tint, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold)
            Text(mission.title, fontWeight = FontWeight.Bold, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (unlocked) StarRow(stars, 14.dp)
            else Text(
                when (mission.kind) {
                    MissionKind.LESSON -> "Erreiche die passende Lektion"
                    MissionKind.TRAINING -> "Schließe die Lektion ab"
                    MissionKind.BOSS -> "Schließe das ganze Modul ab"
                }, color = secondaryText, fontSize = 12.sp,
            )
        }
    }
}

/** Die Mission des Tages – auf der Übersicht (mit Weg in die Arena) und in der Arena. */
@Composable
fun DailyMissionCard(state: AppState, modifier: Modifier = Modifier, showsArenaLink: Boolean = false) {
    val store = state.store
    Column(modifier.card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconTile(Icons.Rounded.WbSunny, Palette.orange, 40.dp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Eyebrow("Tagesmission")
                Text("+${Experience.PER_DAILY} XP Bonus · hält deine Serie am Leben", color = secondaryText, fontSize = 12.sp)
            }
            if (store.isDailyMissionDone) Icon(Icons.Rounded.CheckCircle, null, tint = Palette.success, modifier = Modifier.size(28.dp))
        }
        val mission = store.dailyMission
        if (mission == null) {
            Text("Starte die erste Lektion – danach wartet hier jeden Tag eine Mission auf dich.", color = secondaryText, fontSize = 14.sp)
        } else {
            Text(mission.title, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(mission.story, color = secondaryText, fontSize = 14.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
            if (store.isDailyMissionDone) {
                Text("Für heute geschafft – morgen wartet eine neue Mission.", color = Palette.success, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            } else {
                PrimaryButton("Mission starten", Icons.Rounded.SportsEsports, Modifier.fillMaxWidth().testTag("daily-start")) { state.startMission(mission.id) }
            }
        }
        if (showsArenaLink) {
            SecondaryButton("Zur Arena", Icons.AutoMirrored.Rounded.ArrowForward, Modifier.fillMaxWidth().testTag("open-arena"), tint = Palette.indigo, trailingIcon = true) {
                state.section = Section.ARENA
            }
        }
    }
}

/** XP-Fortschritt bis zum nächsten Level. */
@Composable
fun LevelCard(progress: LevelProgress, unlocked: Int, modifier: Modifier = Modifier, onOpen: (() -> Unit)? = null) {
    Column(modifier.card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(62.dp), contentAlignment = Alignment.Center) {
                ProgressRing(progress.fraction, Modifier.fillMaxSize(), 6.dp, brush = Palette.accent)
                Text("${progress.level}", fontSize = 22.sp, fontWeight = FontWeight.Black)
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text("Level ${progress.level}", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Text("${progress.xp} XP · noch ${progress.remaining} bis Level ${progress.level + 1}", color = secondaryText, fontSize = 14.sp)
                Text("$unlocked von ${Achievement.all.size} Abzeichen", color = Palette.orange, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            }
        }
        ProgressBar(progress.fraction, height = 8.dp)
        Text("XP gibt es für jede gelöste Aufgabe (beim ersten Versuch doppelt), für Sterne in der Arena, abgeschlossene Lektionen und die Tagesmission.",
            color = secondaryText, fontSize = 12.sp)
        onOpen?.let { SecondaryButton("Alle Abzeichen", Icons.Rounded.MilitaryTech, Modifier.fillMaxWidth().testTag("open-achievements"), onClick = it) }
    }
}

@Composable
fun AchievementsScreen(state: AppState) {
    val store = state.store
    val facts = store.facts
    val unlocked = store.unlockedAchievements
    ScreenScroll {
        Text("Abzeichen", fontSize = TitelGroesse, fontWeight = FontWeight.Bold)
        LevelCard(store.levelProgress, unlocked.size)
        Text("${unlocked.size} von ${Achievement.all.size} freigeschaltet", color = secondaryText, fontSize = 16.sp)
        val sorted = Achievement.all.sortedWith(compareBy({ it.id !in unlocked }, { -it.current(facts).toDouble() / it.target }))
        KachelRaster(sorted.map { achievement -> { m: Modifier -> AchievementTile(achievement, achievement.id in unlocked, achievement.current(facts), m) } }, 12.dp, maxJeZeile = 4)
    }
}

@Composable
private fun AchievementTile(achievement: Achievement, isUnlocked: Boolean, current: Int, modifier: Modifier) {
    Column(modifier.heightIn(min = 170.dp).card(14.dp).testTag("achievement-${achievement.id}"), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box {
            IconTile(achievementIcon(achievement), if (isUnlocked) Palette.orange else Palette.gray, 48.dp)
            if (!isUnlocked) {
                Icon(Icons.Rounded.Lock, null, tint = Color.White,
                    modifier = Modifier.offset { IntOffset(36, 36) }.size(18.dp).clip(CircleShape).background(Palette.gray).padding(3.dp))
            }
        }
        Text(achievement.title, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        Text(achievement.detail, color = secondaryText, fontSize = 13.sp)
        Spacer(Modifier.height(4.dp))
        if (isUnlocked) Text("✓ Freigeschaltet", color = Palette.success, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        else {
            ProgressBar(current.toDouble() / achievement.target, height = 5.dp)
            Text("$current / ${achievement.target}", color = secondaryText, fontSize = 12.sp)
        }
    }
}

/** Zeigt einen Stern-Typ als kurze Beschriftung – für die Sterne im Lernpfad. */
fun starCriterionLabel(criterion: StarCriterion): String = criterion.title
