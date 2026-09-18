package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Checklist
import androidx.compose.material.icons.rounded.Coffee
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.automirrored.rounded.ManageSearch
import androidx.compose.material.icons.rounded.Percent
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.AnswerEvaluator
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.FindingKind
import app.javaquest.core.PlacementAnswer
import app.javaquest.core.PlacementTest
import app.javaquest.core.TaskKind
import app.javaquest.data.ProgressStore

private enum class Step { WELCOME, EXPERIENCE, PLACEMENT_INTRO, PLACEMENT, RESULT }

/** App-Start: Begrüßung → Erfahrung (2 Optionen) → (Einstufungsfrage → Ergebnis). */
@Composable
fun OnboardingScreen(store: ProgressStore, onFinished: (startLessonId: String?) -> Unit) {
    var step by remember { mutableStateOf(Step.WELCOME) }
    var level by remember { mutableStateOf<ExperienceLevel?>(null) }
    var placement by remember { mutableStateOf<PlacementTest?>(null) }

    fun finish(startLesson: Boolean) {
        val chosen = level ?: ExperienceLevel.BEGINNER
        store.completeOnboarding(chosen, if (chosen.requiresPlacement) placement else null)
        onFinished(if (startLesson) store.nextLesson?.id else null)
    }

    Box(Modifier.fillMaxSize().background(LocalSurfaces.current.screen)) {
        // Weiche Farbflächen im Hintergrund.
        Box(Modifier.size(900.dp).offset((-450).dp, (-450).dp).background(Brush.radialGradient(listOf(Palette.violet.copy(alpha = 0.22f), Color.Transparent))))
        Box(Modifier.align(Alignment.BottomEnd).size(900.dp).offset(450.dp, 450.dp).background(Brush.radialGradient(listOf(Palette.orange.copy(alpha = 0.18f), Color.Transparent))))

        if (step == Step.PLACEMENT && placement != null) {
            PlacementQuestionScreen(placement!!, store) { step = Step.RESULT }
        } else {
            Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(32.dp), contentAlignment = Alignment.TopCenter) {
                Column(Modifier.widthIn(max = 640.dp).fillMaxWidth()) {
                    when (step) {
                        Step.WELCOME -> WelcomeStep { step = Step.EXPERIENCE }
                        Step.EXPERIENCE -> ExperienceStep(level, { level = it }) {
                            if (level?.requiresPlacement == true) step = Step.PLACEMENT_INTRO else finish(startLesson = true)
                        }
                        Step.PLACEMENT_INTRO -> PlacementIntroStep(store, onBack = { step = Step.EXPERIENCE }) {
                            placement = PlacementTest.create(store.course, level ?: ExperienceLevel.INTERMEDIATE)
                            step = if (placement == null) Step.EXPERIENCE else Step.PLACEMENT
                        }
                        Step.RESULT -> placement?.let { test ->
                            PlacementResultStep(test, store, onStart = { finish(startLesson = true) }, onDashboard = { finish(startLesson = false) })
                        }
                        Step.PLACEMENT -> Unit
                    }
                }
            }
        }
    }
}

@Composable
private fun WelcomeStep(onContinue: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp)) {
        Box(
            Modifier.size(108.dp).shadow(20.dp, RoundedCornerShape(30.dp), spotColor = Palette.violet).clip(RoundedCornerShape(30.dp)).background(Palette.hero),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Rounded.Coffee, null, tint = Color.White, modifier = Modifier.size(54.dp)) }
        Text("Lerne Java.\nLevel für Level.", fontSize = 40.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center, lineHeight = 46.sp)
        Text(
            "Kurze Theorie-Happen, Aufgaben mit steigendem Niveau und eine Auswertung, die deine Wissenslücken findet – komplett offline.",
            fontSize = 17.sp, color = secondaryText, textAlign = TextAlign.Center,
        )
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            FeatureRow(Icons.AutoMirrored.Rounded.ManageSearch, Palette.indigo, "Jede Codezeile erklärt", "Klicke eine Zeile an – sie wird in Alltagssprache erklärt.")
            FeatureRow(Icons.AutoMirrored.Rounded.TrendingUp, Palette.orange, "Niveau 1 bis 5", "Aufgaben werden Schritt für Schritt anspruchsvoller.")
            FeatureRow(Icons.Rounded.Psychology, Palette.success, "Automatische Analyse", "Stärken, Lücken und neue Themen auf einen Blick.")
            FeatureRow(Icons.Rounded.Shield, Palette.violet, "Privat & lokal", "Kein Konto, keine Cloud, kein API-Key.")
        }
        PrimaryButton("Los geht’s", Icons.AutoMirrored.Rounded.ArrowForward, Modifier.fillMaxWidth().testTag("welcome-start"), onClick = onContinue)
    }
}

@Composable
private fun FeatureRow(icon: ImageVector, tint: Color, title: String, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconTile(icon, tint, 40.dp)
        Spacer(Modifier.width(14.dp))
        Column {
            Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            Text(text, color = secondaryText, fontSize = 14.sp)
        }
    }
}

@Composable
private fun ExperienceStep(selection: ExperienceLevel?, onSelect: (ExperienceLevel) -> Unit, onContinue: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Eyebrow("Schritt 1 von 2")
            Text("Wie viel Java kannst du schon?", fontSize = 34.sp, fontWeight = FontWeight.Bold)
            Text("Wähle, was auf dich zutrifft. Mit Vorkenntnissen zeigt eine einzige Frage, wo du einsteigst.", fontSize = 17.sp, color = secondaryText)
        }
        for (level in ExperienceLevel.onboardingChoices) {
            val isSelected = selection == level
            val tint = Palette.tier(level)
            val shape = RoundedCornerShape(CardRadius)
            Row(
                Modifier
                    .fillMaxWidth()
                    .shadow(if (isSelected) 12.dp else 4.dp, shape, spotColor = if (isSelected) tint else Color.Black.copy(alpha = 0.1f))
                    .clip(shape)
                    .background(LocalSurfaces.current.card)
                    .border(if (isSelected) 2.5.dp else 1.dp, if (isSelected) tint else LocalSurfaces.current.divider, shape)
                    .clickableHand { onSelect(level) }
                    .padding(18.dp)
                    .testTag("level-${level.raw}"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconTile(levelIcon(level), tint, 54.dp)
                Spacer(Modifier.width(16.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(level.onboardingTitle, fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
                    Text(level.onboardingSummary, color = secondaryText, fontSize = 15.sp)
                    if (level.requiresPlacement) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Rounded.Checklist, null, tint = tint, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Mit einer Einstufungsfrage", color = tint, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
                Icon(if (isSelected) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked, null,
                    tint = if (isSelected) tint else secondaryText.copy(alpha = 0.4f), modifier = Modifier.size(28.dp))
            }
        }
        PrimaryButton(
            if (selection?.requiresPlacement == true) "Weiter zur Einstufungsfrage" else "Mit dem Grundkurs starten",
            Icons.AutoMirrored.Rounded.ArrowForward,
            Modifier.fillMaxWidth().testTag("experience-continue"),
            enabled = selection != null,
            onClick = onContinue,
        )
    }
}

@Composable
private fun PlacementIntroStep(store: ProgressStore, onBack: () -> Unit, onStart: () -> Unit) {
    val config = store.course.placement
    Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Eyebrow("Schritt 2 von 2")
            Text("Eine Einstufungsfrage", fontSize = 34.sp, fontWeight = FontWeight.Bold)
            Text(ExperienceLevel.INTERMEDIATE.onboardingTitle, fontSize = 19.sp, color = secondaryText)
        }
        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            InfoLine(Icons.Rounded.EditNote, if (config.questionsPerTest == 1) "Eine Frage: Du ergänzt ein kleines Programm mit mehreren Lücken – etwa 2 Minuten." else "${config.questionsPerTest} Fragen, etwa 3–5 Minuten.")
            InfoLine(Icons.Rounded.Percent, "Jede richtige Lücke bringt Punkte. Bewertet wird von 0 bis 100 %.")
            InfoLine(Icons.Rounded.Flag, "Ab ${config.passThreshold} % überspringst du den Grundkurs und startest bei den Objekten. Sonst beginnst du ganz entspannt mit dem Grundkurs.")
            InfoLine(Icons.AutoMirrored.Rounded.ManageSearch, "Hilfen gibt es während der Frage nicht – danach siehst du die Lösung Zeile für Zeile erklärt.")
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            SecondaryButton("Zurück", Icons.AutoMirrored.Rounded.KeyboardArrowLeft, Modifier.width(170.dp), onClick = onBack)
            PrimaryButton("Frage starten", Icons.Rounded.PlayArrow, Modifier.weight(1f).testTag("placement-start"), onClick = onStart)
        }
    }
}

@Composable
private fun InfoLine(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.Top) {
        Icon(icon, null, tint = Palette.orange, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(12.dp))
        Text(text, fontSize = 16.sp)
    }
}

/** Die Einstufungsfrage – ohne Erklärungen und ohne Rückmeldung bis zur Auswertung. */
@Composable
private fun PlacementQuestionScreen(test: PlacementTest, store: ProgressStore, onFinished: () -> Unit) {
    val task = test.currentTask ?: return
    var draft by remember(task.id) { mutableStateOf(AnswerDraft.forTask(task)) }
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(24.dp), contentAlignment = Alignment.TopCenter) {
            Column(Modifier.widthIn(max = 860.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row {
                        Text(if (test.questionCount == 1) "Einstufungsfrage" else "Einstufungstest", fontWeight = FontWeight.SemiBold, fontSize = 18.sp, modifier = Modifier.weight(1f))
                        if (test.questionCount > 1) Text("Frage ${minOf(test.answers.size + 1, test.questionCount)} von ${test.questionCount}", color = secondaryText)
                    }
                    ProgressBar(test.progress, brush = Palette.placement)
                }
                Column(Modifier.card(22.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    TaskQuestion(task, store.course, draft, TaskEvaluation(), showsExplanations = false)
                    TaskAnswerInput(task, draft, { draft = it }, isLocked = false, evaluation = TaskEvaluation())
                }
            }
        }
        Box(Modifier.fillMaxWidth().background(LocalSurfaces.current.card).padding(horizontal = 20.dp, vertical = 12.dp), contentAlignment = Alignment.Center) {
            PrimaryButton(
                if (test.answers.size + 1 == test.questionCount) "Antwort abgeben & auswerten" else "Antwort abgeben",
                Icons.AutoMirrored.Rounded.ArrowForward,
                Modifier.widthIn(max = 760.dp).fillMaxWidth().testTag("placement-submit"),
                enabled = draft.answer(task) != null,
            ) {
                val answer = draft.answer(task) ?: return@PrimaryButton
                test.submit(AnswerEvaluator.evaluate(answer, task))
                draft = AnswerDraft.forTask(test.currentTask)
                if (test.isFinished) onFinished()
            }
        }
    }
}

@Composable
private fun PlacementResultStep(test: PlacementTest, store: ProgressStore, onStart: () -> Unit, onDashboard: () -> Unit) {
    val outcome = test.outcome(store.course)
    val entryModule = store.course.modules.firstOrNull { it.id == outcome.entryModuleId }
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp)) {
        Box(Modifier.size(190.dp), contentAlignment = Alignment.Center) {
            ProgressRing(outcome.scorePercent / 100.0, Modifier.fillMaxSize(), 16.dp)
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("${outcome.scorePercent} %", fontSize = 40.sp, fontWeight = FontWeight.Black, modifier = Modifier.testTag("placement-score"))
                Text("Bestanden ab ${test.passThreshold} %", fontSize = 12.sp, color = secondaryText, fontWeight = FontWeight.SemiBold)
            }
        }
        Text(if (outcome.passed) "Stark eingestuft!" else "Guter Startpunkt gefunden", fontSize = 34.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        entryModule?.let {
            Text(
                if (outcome.passed) "Du startest direkt in „${it.title}“. Die Lektionen davor werden dir angerechnet."
                else "Für den Einstieg bei den Objekten reicht es noch nicht ganz. Du startest mit „${it.title}“ – dort ist jede Codezeile erklärt.",
                fontSize = 17.sp, color = secondaryText, textAlign = TextAlign.Center,
            )
        }
        test.answers.forEachIndexed { index, answer ->
            PlacementAnswerReview(if (test.answers.size > 1) index + 1 else null, answer, store)
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            PrimaryButton(entryModule?.let { "Mit „${it.title}“ loslegen" } ?: "Loslegen", Icons.Rounded.PlayArrow, Modifier.fillMaxWidth().testTag("placement-go"), onClick = onStart)
            SecondaryButton("Erst zur Übersicht", null, Modifier.fillMaxWidth(), onClick = onDashboard)
        }
        Spacer(Modifier.height(8.dp))
    }
}

/** Jede Lücke mit richtig/falsch und der richtigen Antwort, darunter die Lösung Zeile für Zeile. */
@Composable
private fun PlacementAnswerReview(number: Int?, answer: PlacementAnswer, store: ProgressStore) {
    Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(if (answer.result.isCorrect) Icons.Rounded.CheckCircle else Icons.Rounded.Checklist, null,
                tint = if (answer.result.isCorrect) Palette.success else Palette.orange, modifier = Modifier.size(26.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(number?.let { "Frage $it" } ?: "Deine Antwort", fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                Text(listOfNotNull(answer.task.type.title, store.course.topic(answer.task.topicId)?.title).joinToString(" · "), fontSize = 13.sp, color = secondaryText)
            }
            Text("${answer.result.percent} %", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        when (val kind = answer.task.kind) {
            is TaskKind.FillBlank -> {
                kind.blanks.forEachIndexed { index, blank ->
                    val isRight = answer.result.findings.getOrNull(index)?.kind == FindingKind.PASSED
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(if (isRight) Icons.Rounded.CheckCircle else Icons.Rounded.Cancel, null, tint = if (isRight) Palette.success else Palette.ember, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(10.dp))
                        Text("Lücke ${index + 1}", fontWeight = FontWeight.SemiBold, fontSize = 15.sp, modifier = Modifier.weight(1f))
                        Text(if (isRight) "richtig:" else "richtig wäre:", fontSize = 13.sp, color = secondaryText)
                        Spacer(Modifier.width(8.dp))
                        Text(blank.accepted.firstOrNull() ?: "", fontFamily = CodeFont, fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                            modifier = Modifier.clip(RoundedCornerShape(7.dp)).background(LocalSurfaces.current.field).padding(horizontal = 8.dp, vertical = 3.dp))
                    }
                }
                Box(Modifier.fillMaxWidth().height(1.dp).background(LocalSurfaces.current.divider))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.AutoMirrored.Rounded.ManageSearch, null, tint = Palette.orange)
                    Spacer(Modifier.width(8.dp))
                    Text("Die Lösung Zeile für Zeile", color = Palette.orange, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                }
                CodeExegesis(kind.solvedSnippet.explained(store.course.glossary), caption = "Lösung")
            }
            else -> answer.task.code?.let { CodeExegesis(it.explained(store.course.glossary)) }
        }
    }
}
