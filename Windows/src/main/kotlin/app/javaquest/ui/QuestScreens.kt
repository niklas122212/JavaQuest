package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.LibraryBooks
import androidx.compose.material.icons.rounded.AccountBalance
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoFixHigh
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.Badge
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Contrast
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.DoorFront
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Extension
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Handyman
import androidx.compose.material.icons.rounded.HistoryEdu
import androidx.compose.material.icons.rounded.Hive
import androidx.compose.material.icons.rounded.HourglassEmpty
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Loop
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.QuestionMark
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Science
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.ShoppingBag
import androidx.compose.material.icons.rounded.Signpost
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material.icons.rounded.Toll
import androidx.compose.material.icons.rounded.TrackChanges
import androidx.compose.material.icons.rounded.ViewInAr
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.isMetaPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.CodeQuest
import app.javaquest.core.MentorHint
import app.javaquest.core.QuestChapter
import app.javaquest.core.QuestProgress
import app.javaquest.core.QuestResult
import app.javaquest.core.QuestTestResult
import app.javaquest.core.interpreter.JavaProblem
import kotlinx.coroutines.launch

/** SF-Symbole aus code_quests.json (für Apple) als Material-Symbole. */
fun questIcon(symbol: String): ImageVector = when (symbol) {
    "door.left.hand.closed" -> Icons.Rounded.DoorFront
    "signpost.right.and.left" -> Icons.Rounded.Signpost
    "books.vertical", "books.vertical.fill" -> Icons.AutoMirrored.Rounded.LibraryBooks
    "hammer" -> Icons.Rounded.Handyman
    "crown", "crown.fill" -> Icons.Rounded.WorkspacePremium
    "shield.lefthalf.filled" -> Icons.Rounded.Shield
    "person.text.rectangle" -> Icons.Rounded.Badge
    "seal.fill" -> Icons.Rounded.Toll
    "flame.fill" -> Icons.Rounded.LocalFireDepartment
    "map.fill" -> Icons.Rounded.Map
    "key.fill" -> Icons.Rounded.Key
    "circle.lefthalf.filled" -> Icons.Rounded.Contrast
    "scroll.fill" -> Icons.Rounded.HistoryEdu
    "cube.fill" -> Icons.Rounded.ViewInAr
    "drop.fill" -> Icons.Rounded.WaterDrop
    "flame.circle.fill" -> Icons.Rounded.Whatshot
    "book.closed.fill" -> Icons.Rounded.AutoStories
    "bag.fill" -> Icons.Rounded.ShoppingBag
    "circle.hexagongrid.fill" -> Icons.Rounded.Hive
    else -> Icons.Rounded.Star
}

// ---------------------------------------------------------------- Karte

/** Die Karte des Abenteuers: Kapitel mit ihren Quests, Inventar, Baupläne und die Werkstatt. */
@Composable
fun QuestHomeScreen(state: AppState) {
    val progress = state.store.questProgress
    val kompakt = LocalKompakt.current
    ScreenScroll {
        QuestHero(progress) { state.startQuest(it.id) }
        progress.book.chapters.forEachIndexed { index, chapter ->
            QuestChapterCard(index + 1, chapter, progress) { state.startQuest(it.id) }
        }
        if (kompakt) {
            WorkshopCard(progress) { state.openWorkshop() }
            InventoryCard(progress, Modifier)
            BlueprintCard(progress, Modifier)
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                InventoryCard(progress, Modifier.weight(1f))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    WorkshopCard(progress) { state.openWorkshop() }
                    BlueprintCard(progress, Modifier)
                }
            }
        }
    }
}

@Composable
private fun QuestHero(progress: QuestProgress, onStart: (CodeQuest) -> Unit) {
    val total = progress.book.quests.size
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(CardRadius)).background(Palette.hero).padding(22.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.AccountBalance, null, tint = Color.White, modifier = Modifier.size(30.dp))
            Spacer(Modifier.width(12.dp))
            Column {
                Eyebrow("Abenteuer", Color.White.copy(alpha = 0.85f))
                Text(progress.book.title, color = Color.White, fontSize = TitelGroesse, fontWeight = FontWeight.Black)
            }
        }
        Text(progress.book.intro, color = Color.White.copy(alpha = 0.92f), fontSize = 15.sp)
        ChipZeile(16.dp) {
            Text("⚑ ${progress.solvedCount}/$total Quests", color = Color.White, fontWeight = FontWeight.SemiBold)
            Text("★ ${progress.totalStars}/${progress.maxStars}", color = Color.White, fontWeight = FontWeight.SemiBold)
            Text("${progress.inventory.size} Gegenstände", color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        Box(Modifier.fillMaxWidth().height(7.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.25f))) {
            Box(Modifier.fillMaxWidth(progress.solvedCount.toFloat() / maxOf(total, 1)).height(7.dp).clip(CircleShape).background(Color.White))
        }
        val next = progress.nextQuest
        when {
            next != null -> PrimaryButton(
                if (progress.solvedCount == 0) "Abenteuer beginnen: ${next.title}" else "Weiter: ${next.title}",
                Icons.Rounded.PlayArrow, Modifier.fillMaxWidth().testTag("quest-weiter"),
                brush = SolidColor(Color.White.copy(alpha = 0.22f)),
            ) { onStart(next) }
            progress.solvedCount == total -> Text("Javahall ist gerettet – alle Quests gelöst!", color = Color.White, fontWeight = FontWeight.Bold)
            else -> {
                val locked = progress.book.quests.firstOrNull { progress.stars[it.id] == null }
                val reason = (locked?.let(progress::state) as? QuestProgress.State.Locked)?.reason
                if (locked != null && reason != null) {
                    Text("Nächste Quest „${locked.title}“ · $reason", color = Color.White, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun QuestChapterCard(number: Int, chapter: QuestChapter, progress: QuestProgress, onStart: (CodeQuest) -> Unit) {
    val quests = progress.book.quests(chapter)
    val solved = progress.solvedCount(chapter)
    val isOpen = quests.any { progress.state(it).isPlayable }
    Column(Modifier.card(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconTile(if (isOpen) questIcon(chapter.symbol) else Icons.Rounded.Lock,
                if (solved == quests.size) Palette.success else if (isOpen) Palette.violet else Palette.gray, 44.dp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text("Kapitel $number", fontSize = 12.sp, color = secondaryText, fontWeight = FontWeight.SemiBold)
                Text(chapter.title, fontSize = 19.sp, fontWeight = FontWeight.Bold)
            }
            Text("$solved/${quests.size}", fontWeight = FontWeight.Bold, color = if (solved == quests.size) Palette.success else secondaryText)
        }
        Text(chapter.story, color = secondaryText, fontSize = 14.sp)
        for (quest in quests) QuestRow(quest, progress.state(quest)) { onStart(quest) }
    }
}

@Composable
private fun QuestRow(quest: CodeQuest, state: QuestProgress.State, onStart: () -> Unit) {
    val surfaces = LocalSurfaces.current
    val shape = RoundedCornerShape(InnerRadius)
    val isOpen = state == QuestProgress.State.Open
    Row(
        Modifier.fillMaxWidth().clip(shape)
            .background(if (isOpen) Palette.orange.copy(alpha = 0.1f) else surfaces.field)
            .then(if (isOpen) Modifier.border(1.5.dp, Palette.orange.copy(alpha = 0.5f), shape) else Modifier)
            .clickableHand(state.isPlayable, onClick = onStart)
            .padding(12.dp)
            .testTag("quest-${quest.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when (state) {
            is QuestProgress.State.Solved -> IconTile(questIcon(quest.reward.symbol), Palette.success, 34.dp)
            QuestProgress.State.Open -> IconTile(Icons.Rounded.PlayArrow, Palette.orange, 34.dp)
            is QuestProgress.State.Locked -> IconTile(Icons.Rounded.Lock, Palette.gray, 34.dp)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(quest.title, fontWeight = FontWeight.SemiBold)
            Text(if (state is QuestProgress.State.Locked) state.reason else "Neu: ${quest.concept.title}", fontSize = 13.sp, color = secondaryText)
        }
        when (state) {
            is QuestProgress.State.Solved -> StarRow(state.stars, 16.dp)
            QuestProgress.State.Open -> Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, tint = Palette.orange)
            is QuestProgress.State.Locked -> Unit
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun InventoryCard(progress: QuestProgress, modifier: Modifier) {
    val surfaces = LocalSurfaces.current
    Column(modifier.card(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle("Inventar", "Für jede gelöste Quest ein Gegenstand", Icons.Rounded.ShoppingBag)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            for (quest in progress.book.quests) {
                val owned = progress.stars[quest.id] != null
                Column(
                    Modifier.width(104.dp).clip(RoundedCornerShape(12.dp)).background(surfaces.field).padding(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    IconTile(if (owned) questIcon(quest.reward.symbol) else Icons.Rounded.QuestionMark, if (owned) Palette.orange else Palette.gray.copy(alpha = 0.6f), 40.dp)
                    Text(if (owned) quest.reward.item else "???", fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                        color = if (owned) Color.Unspecified else secondaryText, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun WorkshopCard(progress: QuestProgress, onOpen: () -> Unit) {
    Column(Modifier.card(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconTile(if (progress.isWorkshopUnlocked) Icons.Rounded.Handyman else Icons.Rounded.Lock, if (progress.isWorkshopUnlocked) Palette.teal else Palette.gray)
            Spacer(Modifier.width(10.dp))
            Column {
                Eyebrow("Werkstatt", Palette.teal)
                Text("Freies Bauen – eigene Java-Programme", fontSize = 13.sp, color = secondaryText)
            }
        }
        Text("Schreib, was du willst: eigene Klassen, Schleifen, Spiele. Mit Konsole, Zusehen Schritt für Schritt und deinen Bauplänen zum Einfügen.",
            color = secondaryText, fontSize = 14.sp)
        if (progress.isWorkshopUnlocked) {
            SecondaryButton("Werkstatt öffnen", Icons.Rounded.Build, Modifier.fillMaxWidth().testTag("werkstatt-oeffnen"), tint = Palette.teal, onClick = onOpen)
        } else {
            Text("Öffnet sich nach Kapitel 1 „${progress.book.chapters.firstOrNull()?.title ?: ""}“", fontWeight = FontWeight.SemiBold, color = secondaryText)
        }
    }
}

@Composable
private fun BlueprintCard(progress: QuestProgress, modifier: Modifier) {
    Column(modifier.card(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionTitle("Baupläne", "Code-Bausteine für sauberen Code – mit 3 Sternen", Icons.Rounded.HistoryEdu)
        for (quest in progress.book.quests) {
            val blueprint = quest.blueprint ?: continue
            val unlocked = progress.isBlueprintUnlocked(quest)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(if (unlocked) Icons.Rounded.HistoryEdu else Icons.Rounded.Lock, null, tint = if (unlocked) Palette.teal else secondaryText, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(10.dp))
                Column {
                    Text(blueprint.title, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = if (unlocked) Color.Unspecified else secondaryText)
                    Text(if (unlocked) blueprint.text else "3 Sterne in „${quest.title}“", fontSize = 12.sp, color = secondaryText)
                }
            }
        }
    }
}

/** Kurzer Einstieg auf der Übersicht – auf dem Handy auch der Weg zur Questkarte. */
@Composable
fun QuestDashboardCard(state: AppState, modifier: Modifier = Modifier) {
    val progress = state.store.questProgress
    if (progress.book.quests.isEmpty()) return
    Column(modifier.card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconTile(Icons.Rounded.Map, Palette.violet)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Eyebrow("Code-Quests", Palette.violet)
                Text("${progress.book.title} · ${progress.solvedCount}/${progress.book.quests.size}", fontSize = 13.sp, color = secondaryText)
            }
            Text("Karte", color = Palette.indigo, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickableHand { state.section = Section.QUESTS }.padding(6.dp).testTag("quests-karte"))
        }
        val next = progress.nextQuest
        when {
            next != null -> {
                Text(next.title, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text(next.story, color = secondaryText, fontSize = 14.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
                PrimaryButton("Quest starten", Icons.Rounded.PlayArrow, Modifier.fillMaxWidth().testTag("quest-starten"),
                    brush = Brush.linearGradient(listOf(Palette.violet, Palette.indigo))) { state.startQuest(next.id) }
            }
            progress.solvedCount == progress.book.quests.size ->
                Text("Alle Quests gelöst – baue frei in der Werkstatt weiter.", color = Palette.success, fontWeight = FontWeight.SemiBold)
            else -> Text("Die nächste Quest öffnet sich mit der nächsten Lektion.", color = secondaryText)
        }
    }
}

// ---------------------------------------------------------------- Quest

/** Eine Quest: Szene, Konzept und Auftrag links – Editor, Testlauf und Mentor rechts (auf dem Handy untereinander). */
@Composable
fun QuestSessionScreen(model: QuestSessionModel, state: AppState) {
    val surfaces = LocalSurfaces.current
    val chapter = state.store.questBook.chapter(model.quest.chapterId)
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize().background(surfaces.screen).onPreviewKeyEvent { event ->
        screenShortcut(event, run = { scope.launch { model.run() } }, close = state::closeQuest)
    }) {
        Row(Modifier.fillMaxWidth().background(surfaces.card).padding(horizontal = 20.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(38.dp).clip(CircleShape).background(surfaces.field).clickableHand(onClick = state::closeQuest).testTag("close-quest"), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Close, "Schließen", modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(chapter?.title ?: state.store.questBook.title, fontSize = 12.sp, color = secondaryText)
                Text(model.quest.title, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            val best = maxOf(model.previousStars, model.result?.stars ?: 0)
            if (best > 0) StarRow(best, 16.dp)
        }
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val wide = maxWidth >= 900.dp
            val briefingWidth = (maxWidth * 0.38f).coerceIn(360.dp, 460.dp)
            if (wide) {
                Row(Modifier.fillMaxSize()) {
                    Column(
                        Modifier.width(briefingWidth).fillMaxHeight().background(surfaces.card.copy(alpha = 0.5f))
                            .verticalScroll(rememberScrollState()).padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(18.dp),
                    ) { QuestBriefing(model.quest, chapter) }
                    Box(Modifier.width(1.dp).fillMaxHeight().background(surfaces.divider))
                    Column(
                        Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()).padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) { QuestWorkbench(model, state, wide = true) }
                }
            } else {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    QuestBriefing(model.quest, chapter)
                    QuestWorkbench(model, state, wide = false)
                }
            }
        }
    }
}

/** Strg/⌘ + Enter führt aus (Tests bzw. Programm), Esc schließt – wie in den Lektionen. Der Entwurf bleibt gemerkt. */
private fun screenShortcut(event: KeyEvent, run: () -> Unit, close: () -> Unit): Boolean = when {
    event.type != KeyEventType.KeyDown -> false
    event.key == Key.Enter && (event.isCtrlPressed || event.isMetaPressed) -> { run(); true }
    event.key == Key.Escape -> { close(); true }
    else -> false
}

@Composable
private fun QuestBriefing(quest: CodeQuest, chapter: QuestChapter?) {
    // Szene
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(CardRadius))
            .background(Brush.linearGradient(listOf(Palette.violet.copy(alpha = 0.16f), Palette.indigo.copy(alpha = 0.06f)))).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconTile(questIcon(chapter?.symbol ?: "map.fill"), Palette.violet, 38.dp)
            Spacer(Modifier.width(10.dp))
            Column {
                Eyebrow(chapter?.title ?: "Quest", Palette.violet)
                Text(quest.title, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            }
        }
        Text(quest.story, fontStyle = FontStyle.Italic, fontSize = 16.sp)
        ChipZeile {
            Chip("Schwierigkeit ${quest.difficulty}/5", tint = Palette.indigo)
            Chip("${quest.tests.size} Tests", tint = Palette.teal)
        }
    }
    // Auftrag
    Column(Modifier.card(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.TrackChanges, null, tint = Palette.orange)
            Spacer(Modifier.width(8.dp))
            Text("Dein Auftrag", fontWeight = FontWeight.Bold, color = Palette.orange, fontSize = 17.sp)
        }
        Text(quest.task, fontSize = 15.sp)
        for (rule in quest.requirements) Text("• ${rule.message}", fontSize = 13.sp, color = secondaryText)
    }
    // Konzept
    var expanded by remember { mutableStateOf(true) }
    Column(Modifier.card(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.fillMaxWidth().clickableHand { expanded = !expanded }, verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Lightbulb, null, tint = Palette.teal)
            Spacer(Modifier.width(8.dp))
            Text("Neu: ${quest.concept.title}", fontWeight = FontWeight.Bold, color = Palette.teal, fontSize = 17.sp, modifier = Modifier.weight(1f))
            Icon(if (expanded) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, null, tint = secondaryText)
        }
        if (expanded) {
            Text(quest.concept.text, fontSize = 14.sp)
            CodeBlock(highlighted(quest.concept.code), "Beispiel")
        }
    }
    // Sichtbare Tests
    Column(Modifier.card(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Science, null, tint = Palette.indigo)
            Spacer(Modifier.width(8.dp))
            Text("So wird geprüft", fontWeight = FontWeight.Bold, color = Palette.indigo, fontSize = 17.sp)
        }
        CodeBlock(highlighted(quest.visibleTests.joinToString("\n") { it.assertion }), "${quest.className}Test.java")
        val hidden = quest.tests.size - quest.visibleTests.size
        if (hidden > 0) Text("$hidden weitere Tests bleiben geheim – wie bei echten Abgaben. Denk an Sonderfälle!", fontSize = 13.sp, color = secondaryText)
    }
}

@Composable
private fun QuestWorkbench(model: QuestSessionModel, state: AppState, wide: Boolean) {
    val scope = rememberCoroutineScope()
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Rounded.Description, null, tint = Palette.orange, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text("${model.quest.className}.java", fontFamily = CodeFont, fontWeight = FontWeight.Bold, fontSize = 17.sp, modifier = Modifier.weight(1f))
        var confirmsReset by remember { mutableStateOf(false) }
        SecondaryButton("Startcode", Icons.Rounded.Refresh, enabled = model.code != model.quest.starterCode, tint = Palette.gray) { confirmsReset = true }
        if (confirmsReset) {
            AlertDialog(
                onDismissRequest = { confirmsReset = false },
                title = { Text("Code auf den Startcode zurücksetzen?") },
                text = { Text("Dein Code wird durch den Startcode ersetzt.") },
                confirmButton = { TextButton({ confirmsReset = false; model.reset() }, Modifier.testTag("startcode-ja")) { Text("Zurücksetzen", color = Palette.ember) } },
                dismissButton = { TextButton({ confirmsReset = false }) { Text("Abbrechen") } },
            )
        }
    }
    CodeEditor(
        model.code, "// Dein Java-Code", if (wide) 380.dp else 280.dp, false, "quest-editor",
        errorLine = model.errorLine, showsLint = true,
    ) { model.updateCode(it) }
    PrimaryButton(
        if (model.isRunning) "Tests laufen …" else "Tests ausführen", Icons.Rounded.PlayArrow,
        Modifier.fillMaxWidth().testTag("quest-run"), enabled = !model.isRunning,
    ) { scope.launch { model.run() } }

    val result = model.result
    if (result != null) {
        if (model.isStale) Text("Code geändert – führe die Tests erneut aus.", fontSize = 13.sp, color = secondaryText, fontWeight = FontWeight.SemiBold)
        if (result.solved) QuestSuccess(model, result, state) else MentorCard(result.mentor)
        QuestTestList(result, showsHidden = result.solved)
        if (result.solved && result.stars < 3) QualityList(result)
    }
    if (!model.isSolved && model.failedRuns >= 3) SolutionPeek(model.quest.solution)
}

/** Byte, der Mentor: ein Hinweis, der weiterhilft – statt nur „Falsch“. */
@Composable
private fun MentorCard(hint: MentorHint) {
    val (icon, tint) = when (hint.kind) {
        MentorHint.Kind.COMPILE -> Icons.Rounded.Build to Palette.ember
        MentorHint.Kind.UNSUPPORTED -> Icons.Rounded.QuestionMark to Palette.indigo
        MentorHint.Kind.MISSING_CLASS -> Icons.Rounded.Description to Palette.ember
        MentorHint.Kind.MISSING_MEMBER -> Icons.Rounded.Extension to Palette.orange
        MentorHint.Kind.ENDLESS -> Icons.Rounded.Loop to Palette.orange
        MentorHint.Kind.CRASH -> Icons.Rounded.Cancel to Palette.ember
        MentorHint.Kind.WRONG_VALUE -> Icons.Rounded.Cancel to Palette.orange
        MentorHint.Kind.REQUIREMENT -> Icons.Rounded.Flag to Palette.indigo
        MentorHint.Kind.QUALITY -> Icons.Rounded.AutoFixHigh to Palette.violet
        MentorHint.Kind.SUCCESS -> Icons.Rounded.CheckCircle to Palette.success
    }
    val shape = RoundedCornerShape(InnerRadius)
    Row(Modifier.fillMaxWidth().clip(shape).background(tint.copy(alpha = 0.1f)).border(1.dp, tint.copy(alpha = 0.3f), shape).padding(16.dp).testTag("mentor")) {
        IconTile(icon, tint, 38.dp)
        Spacer(Modifier.width(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Eyebrow("Byte, dein Mentor", tint)
            Text(hint.title, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Text(hint.text, fontSize = 15.sp)
            hint.line?.let { Chip("Zeile $it", tint = tint) }
        }
    }
}

@Composable
private fun QuestTestList(result: QuestResult, showsHidden: Boolean) {
    Column(Modifier.card(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (result.compileProblem != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.HourglassEmpty, null, tint = secondaryText)
                Spacer(Modifier.width(8.dp))
                Text("Erst wenn der Code übersetzt, laufen die Tests.", color = secondaryText)
            }
            return@Column
        }
        Text("${result.passedCount} von ${result.tests.size} Tests bestanden", fontWeight = FontWeight.SemiBold, modifier = Modifier.testTag("quest-bestanden"))
        ProgressBar(result.passedCount.toDouble() / maxOf(result.tests.size, 1), height = 6.dp,
            brush = if (result.solved) Palette.successGradient else Palette.accent)
        for (test in result.tests) TestRow(test, showsHidden)
    }
}

@Composable
private fun TestRow(test: QuestTestResult, showsHidden: Boolean) {
    Row(verticalAlignment = Alignment.Top) {
        Icon(if (test.passed) Icons.Rounded.CheckCircle else Icons.Rounded.Cancel, null, tint = if (test.passed) Palette.success else Palette.ember)
        Spacer(Modifier.width(10.dp))
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(test.test.name, fontWeight = FontWeight.Medium, fontSize = 15.sp)
                if (!test.test.isVisible && !showsHidden) {
                    Spacer(Modifier.width(6.dp))
                    Icon(Icons.Rounded.VisibilityOff, "geheimer Test", tint = secondaryText, modifier = Modifier.size(14.dp))
                }
            }
            if (!test.passed) test.message?.let { Text(it, fontSize = 13.sp, color = secondaryText) }
            if (test.test.isVisible || showsHidden) Text(test.test.assertion, fontFamily = CodeFont, fontSize = 11.sp, color = secondaryText, maxLines = 4)
        }
    }
}

@Composable
private fun QualityList(result: QuestResult) {
    Column(Modifier.card(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.AutoFixHigh, null, tint = Palette.violet)
            Spacer(Modifier.width(8.dp))
            Text("Für den nächsten Stern", fontWeight = FontWeight.Bold, color = Palette.violet, fontSize = 17.sp)
        }
        Criterion("Alle Tests grün", true)
        Criterion("Namen nach Java-Konvention", result.naming.isEmpty())
        for (finding in result.naming) Text("• ${finding.message}", fontSize = 13.sp, color = secondaryText, modifier = Modifier.padding(start = 28.dp))
        Criterion("Sauber eingerückt (4 Leerzeichen je Ebene)", result.indentation.isEmpty())
        for (finding in result.indentation.take(4)) Text("• ${finding.message}", fontSize = 13.sp, color = secondaryText, modifier = Modifier.padding(start = 28.dp))
    }
}

@Composable
private fun Criterion(title: String, met: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(if (met) Icons.Rounded.Star else Icons.Rounded.StarBorder, null, tint = if (met) Color(0xFFFFCC00) else secondaryText, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, fontSize = 15.sp)
    }
}

@Composable
private fun QuestSuccess(model: QuestSessionModel, result: QuestResult, state: AppState) {
    val quest = model.quest
    val shape = RoundedCornerShape(CardRadius)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(Palette.success.copy(alpha = 0.1f)).border(1.dp, Palette.success.copy(alpha = 0.35f), shape).padding(18.dp)
            .testTag("quest-geschafft"),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            StarRow(result.stars, 28.dp)
            if (result.stars > model.previousStars && model.previousStars > 0) {
                Spacer(Modifier.width(12.dp))
                Chip("Neuer Bestwert", tint = Palette.success)
            }
        }
        Text("Bestanden!", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(quest.success, fontStyle = FontStyle.Italic, fontSize = 15.sp)
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconTile(questIcon(quest.reward.symbol), Palette.orange, 44.dp)
            Spacer(Modifier.width(12.dp))
            Column {
                Text("Ins Inventar: ${quest.reward.item}", fontWeight = FontWeight.Bold)
                Text(quest.reward.text, fontSize = 13.sp, color = secondaryText)
            }
        }
        quest.blueprint?.let { blueprint ->
            val unlocked = result.stars == 3
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconTile(if (unlocked) Icons.Rounded.HistoryEdu else Icons.Rounded.Lock, if (unlocked) Palette.teal else Palette.gray, 44.dp)
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(if (unlocked) "Bauplan freigeschaltet: ${blueprint.title}" else "Bauplan „${blueprint.title}“ gesperrt", fontWeight = FontWeight.Bold)
                    Text(if (unlocked) "Du findest ihn in der Werkstatt." else "Sauberer Code mit 3 Sternen schaltet ihn frei.", fontSize = 13.sp, color = secondaryText)
                }
            }
        }
        model.rewardGain?.let { RewardBanner(it) }
        ChipZeile(12.dp) {
            model.nextQuest?.let { next ->
                PrimaryButton("Nächste Quest", Icons.AutoMirrored.Rounded.ArrowForward, Modifier.testTag("quest-naechste")) { state.startQuest(next.id) }
            }
            SecondaryButton("Zur Karte", Icons.Rounded.Map) { state.closeQuest(); state.section = Section.QUESTS }
        }
    }
}

/** Nach drei vergeblichen Läufen: die Musterlösung zum Nachlesen – abschreiben bleibt Handarbeit. */
@Composable
private fun SolutionPeek(solution: String) {
    var open by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.clickableHand { open = !open }.padding(4.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(if (open) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility, null, tint = Palette.indigo)
            Spacer(Modifier.width(8.dp))
            Text(if (open) "Musterlösung ausblenden" else "Festgefahren? Musterlösung ansehen", color = Palette.indigo, fontWeight = FontWeight.SemiBold)
        }
        if (open) {
            CodeBlock(highlighted(solution), "Musterlösung")
            Text("Lies sie Zeile für Zeile und schreib sie dann in deinen eigenen Worten – so bleibt es hängen.", fontSize = 13.sp, color = secondaryText)
        }
    }
}

// ---------------------------------------------------------------- Werkstatt

/** Freies Bauen: eigene Programme schreiben, ausführen, zusehen – mit den Bauplänen aus den Quests. */
@Composable
fun WorkshopScreen(model: WorkshopModel, state: AppState) {
    val surfaces = LocalSurfaces.current
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize().background(surfaces.screen).onPreviewKeyEvent { event ->
        screenShortcut(event, run = { scope.launch { model.run() } }, close = state::closeWorkshop)
    }) {
        Row(Modifier.fillMaxWidth().background(surfaces.card).padding(horizontal = 20.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(38.dp).clip(CircleShape).background(surfaces.field).clickableHand(onClick = state::closeWorkshop).testTag("close-werkstatt"), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Close, "Schließen", modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(16.dp))
            Icon(Icons.Rounded.Handyman, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("Werkstatt", fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
        }
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            if (maxWidth >= 900.dp) {
                Row(Modifier.fillMaxSize()) {
                    Column(Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        WorkshopMain(model, wide = true)
                    }
                    Box(Modifier.width(1.dp).fillMaxHeight().background(surfaces.divider))
                    Column(Modifier.width(320.dp).fillMaxHeight().background(surfaces.card.copy(alpha = 0.5f)).verticalScroll(rememberScrollState()).padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        WorkshopSidebar(model, state)
                    }
                }
            } else {
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    WorkshopMain(model, wide = false)
                    WorkshopSidebar(model, state)
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun WorkshopMain(model: WorkshopModel, wide: Boolean) {
    val scope = rememberCoroutineScope()
    val surfaces = LocalSurfaces.current
    var renaming by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }
    var confirmsDelete by remember { mutableStateOf(false) }
    if (confirmsDelete) {
        AlertDialog(
            onDismissRequest = { confirmsDelete = false },
            title = { Text("„${model.selected?.name ?: "Programm"}“ löschen?") },
            text = { Text("Das Programm und sein Code sind danach weg.") },
            confirmButton = { TextButton({ confirmsDelete = false; model.deleteSelected() }) { Text("Löschen", color = Palette.ember) } },
            dismissButton = { TextButton({ confirmsDelete = false }) { Text("Abbrechen") } },
        )
    }
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (project in model.projects) {
            val selected = project.id == model.selectedId
            Text(
                project.name, fontWeight = FontWeight.SemiBold, fontSize = 14.sp,
                color = if (selected) Color.White else Palette.orange,
                modifier = Modifier.clip(CircleShape).background(if (selected) Palette.orange else Palette.orange.copy(alpha = 0.12f))
                    .clickableHand { model.select(project.id) }.padding(horizontal = 12.dp, vertical = 7.dp),
            )
        }
        SecondaryButton("Neu", Icons.Rounded.Add, tint = Palette.teal) { model.newProject() }
        SecondaryButton("Umbenennen", Icons.Rounded.Edit, tint = Palette.gray) { newName = model.selected?.name ?: ""; renaming = !renaming }
        SecondaryButton("Löschen", Icons.Rounded.Delete, tint = Palette.ember) { confirmsDelete = true }
    }
    if (renaming) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BasicTextField(
                newName, { newName = it }, singleLine = true,
                textStyle = TextStyle(fontSize = 16.sp, color = androidx.compose.material3.MaterialTheme.colorScheme.onSurface),
                modifier = Modifier.weight(1f).clip(RoundedCornerShape(10.dp)).background(surfaces.field).padding(10.dp),
            )
            Spacer(Modifier.width(8.dp))
            PrimaryButton("Speichern") { model.rename(newName); renaming = false }
        }
    }
    CodeEditor(
        model.code, "// Dein Programm", if (wide) 420.dp else 300.dp, false, "werkstatt-editor",
        errorLine = model.problem?.line, showsLint = true, insertion = model.insertion,
    ) { model.updateCode(it) }
    PrimaryButton(if (model.isRunning) "Läuft …" else "Ausführen", Icons.Rounded.PlayArrow, Modifier.fillMaxWidth().testTag("werkstatt-run"),
        enabled = !model.isRunning, brush = Palette.successGradient) { scope.launch { model.run() } }
    // Konsole
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Terminal, null, tint = secondaryText, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Konsole", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = secondaryText)
        }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(CodeColors.background).padding(12.dp).testTag("werkstatt-konsole"),
            verticalArrangement = Arrangement.spacedBy(4.dp)) {
            val className = Regex("""(?:public\s+)?class\s+(\w+)""").find(model.code)?.groupValues?.get(1) ?: "Programm"
            Text("> java $className", fontFamily = CodeFont, fontSize = 13.sp, color = CodeColors.plain.copy(alpha = 0.45f))
            when {
                model.ranCode == null -> Text("Drück auf „Ausführen“ – hier erscheint, was dein Programm ausgibt.", fontFamily = CodeFont, fontSize = 13.sp, color = CodeColors.plain.copy(alpha = 0.4f))
                model.output.isNotEmpty() -> Text(model.output.trimEnd('\n'), fontFamily = CodeFont, fontSize = 13.sp, color = CodeColors.plain)
                model.problem == null -> Text("(keine Ausgabe)", fontFamily = CodeFont, fontSize = 13.sp, color = CodeColors.plain.copy(alpha = 0.4f))
            }
            model.problem?.let { problem ->
                Text(
                    if (problem.kind == JavaProblem.Kind.STEP_LIMIT) "Dein Programm hört nicht auf – vermutlich eine Endlosschleife." else problem.description,
                    fontFamily = CodeFont, fontSize = 13.sp, color = Color(0xFFFF8C8C),
                )
            }
            for (warning in model.warnings) Text(warning, fontFamily = CodeFont, fontSize = 13.sp, color = Color(0xFFFFD54F))
        }
    }
    val ran = model.ranCode
    if (ran != null && model.problem?.kind != JavaProblem.Kind.SYNTAX) {
        androidx.compose.runtime.key(ran) { CodeRunPanel(ran, emptyList()) }
    }
}

@Composable
private fun WorkshopSidebar(model: WorkshopModel, state: AppState) {
    val progress = state.store.questProgress
    val blueprints = progress.blueprints
    val locked = progress.book.quests.count { it.blueprint != null } - blueprints.size
    SectionTitle("Baupläne", "Tippe zum Einfügen an der Cursorstelle", Icons.Rounded.HistoryEdu)
    if (blueprints.isEmpty()) Text("Noch keine Baupläne. Löse Quests mit 3 Sternen – sauberer Code schaltet sie frei.", color = secondaryText, fontSize = 14.sp)
    for ((quest, blueprint) in blueprints) {
        var expanded by remember(quest.id) { mutableStateOf(false) }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Palette.teal.copy(alpha = 0.08f)).padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.HistoryEdu, null, tint = Palette.teal)
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Text(blueprint.title, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    Text(blueprint.text, fontSize = 12.sp, color = secondaryText)
                }
                Icon(if (expanded) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility, "Code zeigen", tint = secondaryText,
                    modifier = Modifier.size(22.dp).clickableHand { expanded = !expanded })
                Spacer(Modifier.width(8.dp))
                Icon(Icons.Rounded.Add, "${blueprint.title} einfügen", tint = Palette.teal,
                    modifier = Modifier.size(26.dp).clickableHand { model.insert(blueprint.code) }.testTag("bauplan-${quest.id}"))
            }
            if (expanded) CodeBlock(highlighted(blueprint.code), blueprint.title)
        }
    }
    if (locked > 0) Text("$locked weitere Baupläne warten in den Quests", fontSize = 12.sp, color = secondaryText)
    Box(Modifier.fillMaxWidth().height(1.dp).background(LocalSurfaces.current.divider))
    Text("So funktioniert die Werkstatt", fontWeight = FontWeight.SemiBold)
    Text(
        "Deine Programme laufen in einem geschützten Übungs-Interpreter auf diesem Gerät – ohne Internet, ohne Risiko. " +
            "Er versteht Klassen, Vererbung, Interfaces, Exceptions, Listen und Maps.",
        fontSize = 12.sp, color = secondaryText,
    )
}
