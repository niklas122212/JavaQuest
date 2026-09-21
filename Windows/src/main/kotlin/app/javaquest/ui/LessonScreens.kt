package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.rounded.AllInclusive
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.automirrored.rounded.ManageSearch
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.Sell
import androidx.compose.material.icons.rounded.Summarize
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.isMetaPressed
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.EvaluationResult
import app.javaquest.core.Finding
import app.javaquest.core.FindingKind
import app.javaquest.core.JavaContext
import app.javaquest.core.LearningTask
import app.javaquest.core.LessonSession
import app.javaquest.core.TaskKind
import app.javaquest.core.TheoryCard
import kotlin.math.roundToInt

/** Lektion bzw. Übung: Kopfzeile mit Fortschritt, darunter Theorie, Aufgabe oder Auswertung. */
@Composable
fun LessonFlowScreen(model: LessonFlowModel, onClose: () -> Unit, onStartLesson: (String) -> Unit, onTrainAgain: () -> Unit = {}) {
    val surfaces = LocalSurfaces.current
    Column(
        Modifier
            .fillMaxSize()
            .background(surfaces.screen)
            .onPreviewKeyEvent { event ->
                // Strg/⌘ + Enter = Hauptaktion (Weiter, Prüfen …).
                if (event.type == KeyEventType.KeyDown && event.key == Key.Enter && (event.isCtrlPressed || event.isMetaPressed)) {
                    primaryAction(model)
                    true
                } else {
                    false
                }
            },
    ) {
        Row(
            Modifier.fillMaxWidth().background(surfaces.card).padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier.size(38.dp).clip(CircleShape).background(surfaces.field).clickableHand(onClick = onClose).testTag("close-lesson"),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Close, "Schließen", modifier = Modifier.size(20.dp)) }
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(model.title, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    model.taskPosition?.let { (index, count) ->
                        Text("Aufgabe $index von $count", color = secondaryText, fontSize = 14.sp)
                    }
                }
                Spacer(Modifier.height(8.dp))
                ProgressBar(model.progress)
            }
        }
        Box(Modifier.weight(1f)) {
            when (val phase = model.phase) {
                is LessonSession.Phase.Theory -> TheoryStep(model, phase.page)
                is LessonSession.Phase.Task -> TaskStep(model)
                LessonSession.Phase.Summary -> SummaryStep(model, onClose, onStartLesson, onTrainAgain)
            }
        }
    }
}

private fun primaryAction(model: LessonFlowModel) {
    when (model.phase) {
        is LessonSession.Phase.Theory -> model.advanceTheory()
        is LessonSession.Phase.Task -> if (model.isCurrentTaskFinished) model.next() else model.submit()
        LessonSession.Phase.Summary -> Unit
    }
}

/** Untere Leiste mit den Aktionen – immer sichtbar. */
@Composable
private fun ActionBar(content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) {
    val surfaces = LocalSurfaces.current
    Box(Modifier.fillMaxWidth().background(surfaces.card).padding(horizontal = 20.dp, vertical = 12.dp), contentAlignment = Alignment.Center) {
        Row(Modifier.widthIn(max = 760.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp), content = content)
    }
}

// ---------------------------------------------------------------- Theorie

@Composable
private fun TheoryStep(model: LessonFlowModel, page: Int) {
    val cards = model.theory
    Column(Modifier.fillMaxSize()) {
        // Neue Karte beginnt immer oben – der Scroll-Zustand gehört zur Seite.
        key(page) {
            Box(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(24.dp), contentAlignment = Alignment.TopCenter) {
                TheoryCardContent(cards[page], page, cards.size, model.store.course.glossary)
            }
        }
        ActionBar {
            if (page > 0) {
                SecondaryButton("Zurück", Icons.AutoMirrored.Rounded.KeyboardArrowLeft, Modifier.width(160.dp)) { model.goBackInTheory() }
            }
            val last = page + 1 >= cards.size
            PrimaryButton(
                if (last) "Zu den Aufgaben" else "Weiter",
                if (last) Icons.Rounded.Flag else Icons.AutoMirrored.Rounded.KeyboardArrowRight,
                Modifier.weight(1f).testTag("theory-next"),
            ) { model.advanceTheory() }
        }
    }
}

@Composable
fun TheoryCardContent(card: TheoryCard, page: Int, count: Int, glossary: Map<String, String>) {
    Column(Modifier.widthIn(max = 820.dp).fillMaxWidth().card(28.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Chip("Theorie-Happen ${page + 1}/$count", Icons.AutoMirrored.Rounded.MenuBook, Palette.indigo)
            Spacer(Modifier.weight(1f))
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                repeat(count) { index ->
                    Box(
                        Modifier.height(8.dp).width(if (index == page) 22.dp else 8.dp).clip(CircleShape)
                            .background(if (index <= page) Palette.accent else SolidColor(secondaryText.copy(alpha = 0.25f))),
                    )
                }
            }
        }
        Text(card.title, fontSize = 32.sp, fontWeight = FontWeight.Bold, lineHeight = 38.sp)
        Text(card.body, fontSize = 19.sp, lineHeight = 28.sp)
        card.example?.let { CodeExegesis(it.explained(glossary), caption = "Beispiel") }
        card.callout?.let { CalloutBox(it) }
    }
}

// ---------------------------------------------------------------- Aufgaben

@Composable
private fun TaskStep(model: LessonFlowModel) {
    val task = model.currentTask ?: return
    val feedbackRequester = remember { BringIntoViewRequester() }
    Column(Modifier.fillMaxSize()) {
        key(task.id) {
            val scroll = rememberScrollState()
            // Nach dem Prüfen die Rückmeldung zeigen.
            LaunchedEffect(model.attempts, model.isRevealed) {
                if (model.lastResult != null || model.isRevealed) feedbackRequester.bringIntoView()
            }
            BoxWithConstraints(Modifier.weight(1f).verticalScroll(scroll).padding(24.dp), contentAlignment = Alignment.TopCenter) {
                val wide = maxWidth >= 1000.dp
                val evaluation = TaskEvaluation(
                    isCorrect = model.lastResult?.isCorrect == true,
                    isRevealed = model.isRevealed,
                    hasResult = model.lastResult != null,
                    blankStates = model.blankStates(task),
                )
                val feedback: @Composable ColumnScope.() -> Unit = {
                    if (model.lastResult != null || model.isRevealed) {
                        Box(Modifier.bringIntoViewRequester(feedbackRequester)) {
                            FeedbackPanel(model.lastResult, model.isRevealed, model.attempts, model.remainingAttempts, task.hint, task.explanation, countsForScore = !model.isPractice)
                        }
                    }
                    val kind = task.kind
                    if (model.isCurrentTaskFinished && kind is TaskKind.Code) {
                        SolutionExegesis("Musterlösung Zeile für Zeile", kind.solution.explained(model.store.course.glossary))
                    }
                }
                if (wide) {
                    Row(Modifier.widthIn(max = 1280.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                        Column(Modifier.weight(1f).card(22.dp)) {
                            TaskQuestion(task, model.store.course, model.draft, evaluation, showsExplanations = true)
                        }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            Column(Modifier.card(22.dp)) { TaskAnswerInput(task, model.draft, { model.draft = it }, model.isCurrentTaskFinished, evaluation) }
                            feedback()
                        }
                    }
                } else {
                    Column(Modifier.widthIn(max = 860.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Column(Modifier.card(22.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                            TaskQuestion(task, model.store.course, model.draft, evaluation, showsExplanations = true)
                            TaskAnswerInput(task, model.draft, { model.draft = it }, model.isCurrentTaskFinished, evaluation)
                        }
                        feedback()
                    }
                }
            }
        }
        ActionBar {
            if (model.isCurrentTaskFinished) {
                val position = model.taskPosition
                val last = position != null && position.first == position.second
                PrimaryButton(
                    if (last) "Zur Auswertung" else "Weiter",
                    if (last) Icons.Rounded.Summarize else Icons.AutoMirrored.Rounded.ArrowForward,
                    Modifier.weight(1f).testTag("task-next"),
                    brush = Palette.successGradient,
                ) { model.next() }
            } else {
                if (model.lastResult != null) {
                    SecondaryButton("Lösung zeigen", Icons.Rounded.Visibility, Modifier.weight(1f).testTag("reveal")) { model.revealSolution() }
                }
                if (model.lastResult == null || model.canRetry) {
                    PrimaryButton(
                        if (model.lastResult == null) "Prüfen" else "Erneut prüfen",
                        Icons.Rounded.Verified,
                        Modifier.weight(1f).testTag("submit"),
                        enabled = model.canSubmit,
                    ) { model.submit() }
                }
            }
        }
    }
}

data class TaskEvaluation(
    val isCorrect: Boolean = false,
    val isRevealed: Boolean = false,
    val hasResult: Boolean = false,
    val blankStates: List<Boolean>? = null,
) {
    val isSolved: Boolean get() = isCorrect || isRevealed
}

/** Kopf mit Typ, Thema und Niveau, dazu Aufgabentext und Code mit Zeilen-Erklärungen. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TaskQuestion(
    task: LearningTask,
    course: app.javaquest.core.Course,
    draft: AnswerDraft,
    evaluation: TaskEvaluation,
    showsExplanations: Boolean,
) {
    val glossary = course.glossary
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            DifficultyBadge(task.difficulty)
            Chip(task.type.title, taskTypeIcon(task.type), Palette.indigo)
            course.topic(task.topicId)?.let { Chip(it.title, Icons.Rounded.Sell) }
        }
        Text(task.prompt, fontSize = 21.sp, fontWeight = FontWeight.SemiBold, lineHeight = 28.sp)

        when (val kind = task.kind) {
            is TaskKind.SingleChoice, is TaskKind.PredictOutput -> task.code?.let { snippet ->
                if (showsExplanations) {
                    CodeExegesis(snippet.explained(glossary), initialPresentation = if (evaluation.isSolved) Presentation.ALL else null)
                } else {
                    CodeBlock(highlighted(snippet.source))
                }
            }
            is TaskKind.FillBlank -> {
                val template = kind.template.lines
                if (showsExplanations) {
                    CodeExegesis(
                        lines = (if (evaluation.isSolved) kind.solvedSnippet else kind.template).explained(glossary),
                        initialPresentation = if (evaluation.isSolved) Presentation.ALL else null,
                        hiddenLines = if (evaluation.isSolved) emptySet() else kind.blankLineNumbers,
                        render = { line ->
                            fillBlankLine(template.getOrNull(line.number - 1)?.code ?: line.code, draft.blanks, evaluation.blankStates)
                        },
                    )
                } else {
                    CodeBlock(fillBlankLine(kind.template.source, draft.blanks, evaluation.blankStates))
                }
            }
            is TaskKind.Code -> {
                if (showsExplanations && !evaluation.isSolved) StarterExegesis(kind.starter.explained(glossary))
                if (task.javaContext != JavaContext.FILE) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Info, null, tint = secondaryText, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(task.javaContext.instruction, color = secondaryText, fontSize = 14.sp)
                    }
                }
                kind.expectedOutput?.let { expected ->
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Erwartete Ausgabe", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = secondaryText)
                        Text(
                            expected,
                            fontFamily = CodeFont,
                            fontSize = 14.sp,
                            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(LocalSurfaces.current.field).padding(12.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StarterExegesis(lines: List<app.javaquest.core.ExplainedLine>) {
    var expanded by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.fillMaxWidth().clickableHand { expanded = !expanded }, verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.AutoMirrored.Rounded.ManageSearch, null, tint = Palette.orange, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("Startcode Zeile für Zeile erklärt", color = Palette.orange, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, modifier = Modifier.weight(1f))
            Icon(if (expanded) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, null, tint = Palette.orange)
        }
        if (expanded) CodeExegesis(lines, caption = "Startcode", initialPresentation = Presentation.STEPS)
    }
}

@Composable
fun SolutionExegesis(title: String, lines: List<app.javaquest.core.ExplainedLine>) {
    Column(Modifier.fillMaxWidth().card(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.AutoMirrored.Rounded.ManageSearch, null, tint = Palette.orange)
            Spacer(Modifier.width(8.dp))
            Text(title, color = Palette.orange, fontWeight = FontWeight.Bold, fontSize = 17.sp)
        }
        CodeExegesis(lines, caption = "Musterlösung")
    }
}

/** Eingabebereich je nach Aufgabentyp. */
@Composable
fun TaskAnswerInput(task: LearningTask, draft: AnswerDraft, onChange: (AnswerDraft) -> Unit, isLocked: Boolean, evaluation: TaskEvaluation) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            when (task.kind) {
                is TaskKind.SingleChoice -> "WÄHLE EINE ANTWORT"
                is TaskKind.FillBlank -> "FÜLLE DIE LÜCKEN"
                is TaskKind.PredictOutput -> "KONSOLENAUSGABE"
                is TaskKind.Code -> "DEIN CODE"
            },
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = secondaryText, letterSpacing = 0.5.sp,
        )
        when (val kind = task.kind) {
            is TaskKind.SingleChoice -> ChoiceList(
                choices = kind.choices,
                selection = draft.choice,
                correctIndex = if (evaluation.isSolved) kind.correctIndex else null,
                showsWrongSelection = evaluation.hasResult && !evaluation.isCorrect,
                isLocked = isLocked,
            ) { onChange(draft.copy(choice = it)) }
            is TaskKind.FillBlank -> BlankFields(kind.blanks.size, draft.blanks, evaluation.blankStates, isLocked) { onChange(draft.copy(blanks = it)) }
            is TaskKind.PredictOutput -> CodeEditor(draft.text, "Ausgabe Zeile für Zeile eintippen …", 130.dp, isLocked, "output-editor") { onChange(draft.copy(text = it)) }
            is TaskKind.Code -> CodeEditor(draft.text, "// Dein Java-Code", 230.dp, isLocked, "code-editor") { onChange(draft.copy(text = it)) }
        }
    }
}

@Composable
private fun ChoiceList(
    choices: List<String>,
    selection: Int?,
    correctIndex: Int?,
    showsWrongSelection: Boolean,
    isLocked: Boolean,
    onSelect: (Int) -> Unit,
) {
    val surfaces = LocalSurfaces.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        choices.forEachIndexed { index, choice ->
            val isSelected = selection == index
            val tint = when {
                correctIndex == index -> Palette.success
                showsWrongSelection && isSelected -> Palette.ember
                isSelected -> Palette.orange
                else -> null
            }
            val shape = RoundedCornerShape(14.dp)
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(shape)
                    .background(tint?.copy(alpha = 0.1f) ?: surfaces.field)
                    .border(if (tint != null) 2.dp else 1.dp, tint ?: surfaces.divider, shape)
                    .clickableHand(enabled = !isLocked) { onSelect(index) }
                    .padding(14.dp)
                    .testTag("choice-$index"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    Modifier.size(30.dp).clip(CircleShape).background(tint ?: secondaryText.copy(alpha = 0.18f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(('A' + index).toString(), fontWeight = FontWeight.Bold, color = if (tint != null) Color.White else secondaryText)
                }
                Spacer(Modifier.width(14.dp))
                Text(choice, fontSize = 17.sp, modifier = Modifier.weight(1f))
                when {
                    correctIndex == index -> Icon(Icons.Rounded.CheckCircle, null, tint = Palette.success)
                    showsWrongSelection && isSelected -> Icon(Icons.Rounded.Cancel, null, tint = Palette.ember)
                }
            }
        }
    }
}

@Composable
private fun BlankFields(count: Int, values: List<String>, states: List<Boolean>?, isLocked: Boolean, onChange: (List<String>) -> Unit) {
    val focusManager = LocalFocusManager.current
    val surfaces = LocalSurfaces.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        repeat(count) { index ->
            val state = states?.getOrNull(index)
            val tint = when (state) { true -> Palette.success; false -> Palette.ember; null -> Palette.orange }
            val shape = RoundedCornerShape(14.dp)
            Row(
                Modifier.fillMaxWidth().clip(shape).background(surfaces.field)
                    .border(if (state == null) 1.dp else 2.dp, if (state == null) surfaces.divider else tint, shape)
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(30.dp).clip(CircleShape).background(tint), contentAlignment = Alignment.Center) {
                    Text("${index + 1}", color = Color.White, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.width(12.dp))
                Box(Modifier.weight(1f)) {
                    val value = values.getOrElse(index) { "" }
                    if (value.isEmpty()) Text("Lücke ${index + 1}", fontFamily = CodeFont, fontSize = 17.sp, color = secondaryText.copy(alpha = 0.6f))
                    BasicTextField(
                        value = value,
                        onValueChange = { text -> onChange(values.toMutableList().also { while (it.size <= index) it.add(""); it[index] = text }) },
                        readOnly = isLocked,
                        singleLine = true,
                        textStyle = TextStyle(fontFamily = CodeFont, fontSize = 17.sp, color = androidx.compose.material3.MaterialTheme.colorScheme.onSurface),
                        cursorBrush = SolidColor(Palette.orange),
                        modifier = Modifier.fillMaxWidth().testTag("blank-$index").onPreviewKeyEvent { event ->
                            // Enter oder Tab springt zur nächsten Lücke.
                            if (event.type == KeyEventType.KeyDown && !event.isCtrlPressed && !event.isMetaPressed &&
                                (event.key == Key.Enter || event.key == Key.Tab)
                            ) {
                                focusManager.moveFocus(if (event.isShiftPressed) FocusDirection.Previous else FocusDirection.Next)
                                true
                            } else {
                                false
                            }
                        },
                    )
                }
                when (state) {
                    true -> Icon(Icons.Rounded.CheckCircle, null, tint = Palette.success)
                    false -> Icon(Icons.Rounded.Cancel, null, tint = Palette.ember)
                    null -> Unit
                }
            }
        }
    }
}

/** Mehrzeiliger Editor auf dunklem Grund; Tab rückt um vier Leerzeichen ein. */
@Composable
fun CodeEditor(text: String, placeholder: String, minHeight: androidx.compose.ui.unit.Dp, isLocked: Boolean, tag: String, onChange: (String) -> Unit) {
    var value by remember { mutableStateOf(TextFieldValue(text, TextRange(text.length))) }
    LaunchedEffect(text) { if (value.text != text) value = TextFieldValue(text, TextRange(text.length)) }
    Box(
        Modifier.fillMaxWidth().heightIn(min = minHeight).clip(RoundedCornerShape(InnerRadius)).background(CodeColors.background).padding(14.dp),
    ) {
        if (value.text.isEmpty()) Text(placeholder, fontFamily = CodeFont, fontSize = 15.sp, color = CodeColors.plain.copy(alpha = 0.35f))
        BasicTextField(
            value = value,
            onValueChange = { value = it; onChange(it.text) },
            readOnly = isLocked,
            textStyle = TextStyle(fontFamily = CodeFont, fontSize = 15.sp, color = CodeColors.plain, lineHeight = 22.sp),
            cursorBrush = SolidColor(Palette.orange),
            modifier = Modifier.fillMaxWidth().heightIn(min = minHeight - 28.dp).testTag(tag).onPreviewKeyEvent { event ->
                if (!isLocked && event.type == KeyEventType.KeyDown && event.key == Key.Tab && !event.isShiftPressed) {
                    val inserted = value.text.replaceRange(value.selection.min, value.selection.max, "    ")
                    value = TextFieldValue(inserted, TextRange(value.selection.min + 4))
                    onChange(inserted)
                    true
                } else {
                    false
                }
            },
        )
    }
}

/** Rückmeldung: Urteil, Teilpunkte, Befunde, Tipp und Erklärung. */
@Composable
fun FeedbackPanel(
    result: EvaluationResult?,
    isRevealed: Boolean,
    attempts: Int,
    remainingAttempts: Int,
    hint: String?,
    explanation: String,
    // In Übung und Training zählt die Antwort für die Wissensanalyse, nicht für den Score.
    countsForScore: Boolean = true,
) {
    val isCorrect = result?.isCorrect == true
    val tint = when { isCorrect -> Palette.success; isRevealed -> Palette.indigo; else -> Palette.orange }
    val headline = when {
        isCorrect -> if (attempts == 1) "Richtig – volle Punktzahl!" else "Richtig – im $attempts. Anlauf."
        isRevealed -> "Lösung aufgedeckt"
        else -> "Noch nicht ganz"
    }
    val subline = when {
        isCorrect -> {
            val target = if (countsForScore) "deinen Score" else "deine Wissensanalyse"
            if (attempts == 1) "Das zählt voll für $target." else "Das zählt zur Hälfte für $target."
        }
        isRevealed -> "Schau dir die Lösung in Ruhe an – beim nächsten Mal klappt’s."
        remainingAttempts > 0 -> "Du hast noch $remainingAttempts ${if (remainingAttempts == 1) "Versuch" else "Versuche"}."
        else -> "Keine Versuche mehr – deck die Lösung auf."
    }
    val shape = RoundedCornerShape(CardRadius)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(tint.copy(alpha = 0.1f)).border(1.dp, tint.copy(alpha = 0.3f), shape).padding(18.dp).testTag("feedback"),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Icon(
                when { isCorrect -> Icons.Rounded.CheckCircle; isRevealed -> Icons.Rounded.Lightbulb; else -> Icons.Rounded.Error },
                null, tint = tint, modifier = Modifier.size(32.dp),
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(headline, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(subline, color = secondaryText, fontSize = 15.sp)
            }
            if (result != null && !isCorrect && !isRevealed) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${result.percent} %", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text("erfüllt", color = secondaryText, fontSize = 11.sp)
                }
            }
        }
        // Nach dem Aufdecken steht die Lösung im Eingabefeld – alte Befunde würden nur verwirren.
        val findings = result?.findings.orEmpty()
        if (!isRevealed && findings.isNotEmpty() && (!isCorrect || findings.size > 1)) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) { findings.forEach { FindingRow(it) } }
        }
        if (!isCorrect && !isRevealed && hint != null) {
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Palette.orange.copy(alpha = 0.08f)).padding(12.dp)) {
                Icon(Icons.Rounded.Lightbulb, null, tint = Palette.orange, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text(hint, fontSize = 15.sp)
            }
        }
        if (isCorrect || isRevealed) {
            Column {
                Text("Erklärung", color = tint, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                Text(explanation, fontSize = 15.sp, lineHeight = 21.sp)
            }
        }
    }
}

@Composable
fun FindingRow(finding: Finding) {
    val (icon, tint) = when (finding.kind) {
        FindingKind.PASSED -> Icons.Rounded.CheckCircle to Palette.success
        FindingKind.FAILED -> Icons.Rounded.Cancel to Palette.ember
        FindingKind.HINT -> Icons.Rounded.Lightbulb to Palette.orange
    }
    Row(verticalAlignment = Alignment.Top) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp).padding(top = 1.dp))
        Spacer(Modifier.width(8.dp))
        Text(finding.message, fontSize = 15.sp)
    }
}

// ---------------------------------------------------------------- Auswertung

@Composable
private fun SummaryStep(model: LessonFlowModel, onClose: () -> Unit, onStartLesson: (String) -> Unit, onTrainAgain: () -> Unit) {
    val summary = model.summary
    val passed = summary.passed
    val next = model.nextLessonAfterCurrent
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(24.dp), contentAlignment = Alignment.TopCenter) {
            Column(Modifier.widthIn(max = 720.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
                Icon(
                    if (passed || model.isPractice) Icons.Rounded.EmojiEvents else Icons.Rounded.Refresh,
                    null, tint = if (passed || model.isPractice) Palette.orange else Palette.indigo, modifier = Modifier.size(64.dp),
                )
                Text(
                    when { model.isTraining -> "Runde geschafft"; model.isPractice -> "Übung abgeschlossen"; passed -> "Lektion gemeistert!"; else -> "Fast geschafft!" },
                    fontSize = 34.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center,
                )
                Text(
                    when {
                        model.isTraining -> "Was noch hakt, kommt in den nächsten Runden öfter dran – so lange, bis es sitzt."
                        model.isPractice -> "Deine Antworten sind in die Wissensanalyse eingeflossen."
                        passed -> if ((model.scoreChange?.delta ?: 0) > 0) "Stark! Dein Java Master Score ist gestiegen." else "Stark! Es zählt immer dein Bestwert."
                        else -> "Ab ${LessonSession.passPercent} % gilt eine Lektion als bestanden. Wiederhole sie – es zählt immer dein Bestwert."
                    },
                    fontSize = 17.sp, color = secondaryText, textAlign = TextAlign.Center,
                )
                if (!model.isPractice) StarRow(summary.stars, 40.dp)
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    StatTile(Icons.Rounded.GpsFixed, Palette.orange, "${(summary.accuracy * 100).roundToInt()} %", "Trefferquote (gewichtet)", Modifier.weight(1f))
                    StatTile(Icons.Rounded.Bolt, Palette.violet, "${summary.firstTryCount}/${model.tasks.size}", "Beim ersten Versuch", Modifier.weight(1f))
                }
                model.scoreChange?.let { ScoreChangeCard(it.before, it.after, passed) }
                if (model.scoreChange == null && !model.isPractice) ScoreChangeCard(model.store.masterScore, model.store.masterScore, passed)
                TaskResultsCard(model)
            }
        }
        ActionBar {
            if (model.isTraining) {
                SecondaryButton("Zur Übersicht", null, Modifier.weight(1f)) { onClose() }
                PrimaryButton("Nächste Runde", Icons.Rounded.AllInclusive, Modifier.weight(2f).testTag("next-round")) { onTrainAgain() }
            } else if (model.isPractice) {
                PrimaryButton("Fertig", Icons.Rounded.CheckCircle, Modifier.weight(1f)) { onClose() }
            } else if (passed && next != null) {
                SecondaryButton("Zur Übersicht", null, Modifier.weight(1f)) { onClose() }
                PrimaryButton("Nächste Lektion: ${next.title}", Icons.AutoMirrored.Rounded.ArrowForward, Modifier.weight(2f).testTag("next-lesson")) { onStartLesson(next.id) }
            } else {
                SecondaryButton("Zur Übersicht", null, Modifier.weight(1f)) { onClose() }
                if (!passed) PrimaryButton("Lektion wiederholen", Icons.Rounded.Replay, Modifier.weight(1f).testTag("repeat-lesson")) { model.lessonId?.let(onStartLesson) }
            }
        }
    }
}

@Composable
private fun ScoreChangeCard(before: Int, after: Int, passed: Boolean) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(CardRadius)).background(Palette.hero).padding(22.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Eyebrow("Java Master Score", Color.White.copy(alpha = 0.9f))
            Spacer(Modifier.weight(1f))
            if (after > before) {
                Text("+${after - before}", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp,
                    modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).padding(horizontal = 12.dp, vertical = 4.dp))
            }
        }
        Row(verticalAlignment = Alignment.Bottom) {
            Text("$before", color = Color.White.copy(alpha = 0.7f), fontSize = 26.sp, fontWeight = FontWeight.Bold)
            Text("  →  ", color = Color.White.copy(alpha = 0.7f), fontSize = 20.sp)
            Text("$after", color = Color.White, fontSize = 48.sp, fontWeight = FontWeight.Black)
        }
        if (!passed) Text("Punkte gibt es, sobald du die Lektion mit mindestens ${LessonSession.passPercent} % bestehst.", color = Color.White.copy(alpha = 0.9f), fontSize = 15.sp)
    }
}

@Composable
private fun TaskResultsCard(model: LessonFlowModel) {
    val outcomes = model.summary.outcomes.associateBy { it.taskId }
    Column(Modifier.fillMaxWidth().card(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle("Auswertung je Aufgabe", icon = Icons.Rounded.Summarize)
        for (task in model.tasks) {
            val outcome = outcomes[task.id]
            val (icon, tint, label) = when {
                outcome == null -> Triple(Icons.Rounded.Info, secondaryText, "Nicht bearbeitet")
                outcome.solvedOnFirstTry -> Triple(Icons.Rounded.CheckCircle, Palette.success, "Beim ersten Versuch")
                outcome.solved -> Triple(Icons.Rounded.Replay, Palette.orange, "Im ${outcome.attempts}. Versuch")
                else -> Triple(Icons.Rounded.Visibility, Palette.indigo, "Lösung angesehen")
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(task.prompt, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("${task.type.title} · $label", fontSize = 13.sp, color = secondaryText)
                }
                DifficultyBadge(task.difficulty, compact = true)
            }
        }
    }
}
