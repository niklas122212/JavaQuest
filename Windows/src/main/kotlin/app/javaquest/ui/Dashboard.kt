package app.javaquest.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Code
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Route
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Style
import androidx.compose.material.icons.automirrored.rounded.ListAlt
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.KnowledgeAnalyzer
import app.javaquest.core.KnowledgeReport
import app.javaquest.core.TopicInsight
import app.javaquest.core.TopicStatus
import app.javaquest.data.ProgressStore
import java.time.LocalTime
import kotlin.math.roundToInt

@Composable
fun DashboardScreen(state: AppState) {
    val store = state.store
    ScreenScroll {
        val hour = LocalTime.now().hour
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    when (hour) { in 5..10 -> "Guten Morgen!"; in 11..17 -> "Hallo!"; else -> "Guten Abend!" },
                    fontSize = 34.sp, fontWeight = FontWeight.Bold,
                )
                Text("Ein Theorie-Happen, ein paar Aufgaben – Schritt für Schritt zum Java Master.", color = secondaryText, fontSize = 16.sp)
            }
            if (store.displayedStreak > 0) {
                Chip("${store.displayedStreak}", Icons.Rounded.LocalFireDepartment, Palette.orange)
            }
        }
        BoxWithConstraints {
            if (maxWidth >= 900.dp) {
                Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                        MasterScoreCard(store)
                        ContinueCard(state)
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                        KnowledgeSnapshotCard(state)
                    }
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    MasterScoreCard(store)
                    ContinueCard(state)
                    KnowledgeSnapshotCard(state)
                }
            }
        }
        PathSummaryCard(state)
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            StatTile(Icons.Rounded.CheckCircle, Palette.success, "${store.completedLessonCount}/${store.course.allLessons.size}", "Lektionen abgeschlossen", Modifier.weight(1f))
            StatTile(Icons.Rounded.Code, Palette.indigo, "${store.solvedTaskCount}", "Aufgaben gelöst", Modifier.weight(1f))
            StatTile(Icons.Rounded.GpsFixed, Palette.violet, store.firstTryRate?.let { "${(it * 100).roundToInt()} %" } ?: "–", "Beim ersten Versuch", Modifier.weight(1f))
            StatTile(Icons.Rounded.LocalFireDepartment, Palette.orange, "${store.displayedStreak}", if (store.displayedStreak == 1) "Tag in Folge" else "Tage in Folge", Modifier.weight(1f))
        }
    }
}

/** Scrollbarer Bildschirm mit begrenzter Breite. */
@Composable
fun ScreenScroll(content: @Composable ColumnScope.() -> Unit) {
    Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(28.dp), contentAlignment = Alignment.TopCenter) {
        Column(Modifier.widthIn(max = 1180.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(20.dp), content = content)
    }
}

@Composable
fun MasterScoreCard(store: ProgressStore) {
    val score = store.masterScore
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(CardRadius)).background(Palette.hero).padding(24.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(130.dp), contentAlignment = Alignment.Center) {
                ProgressRing(score / 1000.0, Modifier.fillMaxSize(), 14.dp, brush = androidx.compose.ui.graphics.SolidColor(Color.White), track = Color.White.copy(alpha = 0.25f))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("$score", color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.Black, modifier = Modifier.testTag("master-score"))
                    Text("von 1.000", color = Color.White.copy(alpha = 0.8f), fontSize = 12.sp)
                }
            }
            Spacer(Modifier.width(22.dp))
            Column(Modifier.weight(1f)) {
                Eyebrow("Java Master Score", Color.White.copy(alpha = 0.9f))
                Text(store.rank.title, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                if (store.scoreHistory.size >= 2) {
                    Spacer(Modifier.height(8.dp))
                    Sparkline(store.scoreHistory, Modifier.fillMaxWidth().height(36.dp))
                }
            }
        }
        val next = store.nextRank
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row {
                Text(next?.let { "Nächster Rang: ${it.title}" } ?: "Höchster Rang erreicht", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                next?.let { Text("noch ${it.minimumScore - score} Punkte", color = Color.White, fontWeight = FontWeight.SemiBold) }
            }
            ProgressBar(store.progressToNextRank, height = 8.dp, brush = androidx.compose.ui.graphics.SolidColor(Color.White))
        }
    }
}

@Composable
private fun ContinueCard(state: AppState) {
    val store = state.store
    val lesson = store.nextLesson
    Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        if (lesson == null) {
            SectionTitle("Alles geschafft!", "Du hast jede Lektion abgeschlossen. Wiederhole Lektionen für bessere Bestwerte.", Icons.Rounded.CheckCircle)
            return@Column
        }
        val module = store.course.moduleContaining(lesson.id)
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconTile(symbolIcon(module?.symbol ?: ""), Palette.tier(module?.tier ?: app.javaquest.core.ExperienceLevel.BEGINNER), 50.dp)
            Spacer(Modifier.width(14.dp))
            Column {
                Eyebrow("Weiter lernen")
                Text(module?.title ?: "", color = secondaryText, fontSize = 15.sp)
            }
        }
        Text(lesson.title, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text(lesson.summary, color = secondaryText, fontSize = 16.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Chip("${lesson.estimatedMinutes} Min", Icons.Rounded.Schedule)
            Chip("${lesson.theory.size} Karten", Icons.Rounded.Style)
            Chip("${lesson.tasks.size} Aufgaben", Icons.AutoMirrored.Rounded.ListAlt)
        }
        PrimaryButton("Lektion starten", Icons.Rounded.PlayArrow, Modifier.fillMaxWidth().testTag("start-next-lesson")) { state.startLesson(lesson.id) }
    }
}

@Composable
private fun KnowledgeSnapshotCard(state: AppState) {
    val store = state.store
    val report = store.knowledgeReport
    Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        SectionTitle("Wissenslücken-Analyse", "Automatisch aus deinen Antworten", Icons.Rounded.Psychology) {
            Text("Details", color = Palette.orange, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickableHand { state.section = Section.ANALYSIS })
        }
        DistributionBar(report)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            for (status in TopicStatus.entries) StatusCounter(status, report.topics(status).size, Modifier.weight(1f))
        }
        val practiced = report.insights.filter { it.mastery != null }.sortedBy { it.mastery }
        if (practiced.isNotEmpty()) {
            Text("SCHWÄCHSTE THEMEN", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = secondaryText)
            MasteryBars(practiced.take(4))
        }
        val focus = report.focusTopic
        if (focus != null) {
            val tint = Palette.status(focus.status)
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(InnerRadius)).background(tint.copy(alpha = 0.08f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconTile(symbolIcon(focus.topic.symbol), tint, 34.dp)
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text("Dein Fokus", fontSize = 12.sp, color = secondaryText, fontWeight = FontWeight.SemiBold)
                        Text(focus.topic.title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                    }
                    Text("${(focus.mastery ?: 0.0).masteryPercent} %", color = tint, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                }
                ProgressBar(focus.mastery ?: 0.0, brush = androidx.compose.ui.graphics.SolidColor(tint))
                if (store.practiceTasks(focus.topic.id).isNotEmpty()) {
                    SecondaryButton("Lücke gezielt schließen", Icons.Rounded.GpsFixed, Modifier.fillMaxWidth(), tint = tint) { state.startPractice(focus.topic.id) }
                }
            }
        } else if (practiced.isNotEmpty()) {
            Text("Keine Wissenslücke gefunden – weiter so! Neue Themen warten im Lernpfad.", color = secondaryText, fontSize = 15.sp)
        } else {
            Text("Löse ein paar Aufgaben – danach erkennt die App deine Stärken und Wissenslücken.", color = secondaryText, fontSize = 15.sp)
        }
    }
}

/** Alle Themen als ein gestapelter Balken: Stärken, im Aufbau, Lücken, unbekannt. */
@Composable
fun DistributionBar(report: KnowledgeReport) {
    val total = maxOf(report.insights.size, 1)
    Row(Modifier.fillMaxWidth().height(16.dp).clip(CircleShape).testTag("distribution-bar")) {
        for (status in TopicStatus.entries) {
            val count = report.topics(status).size
            if (count > 0) Box(Modifier.weight(count.toFloat() / total).fillMaxSize().background(Palette.status(status)))
        }
    }
}

@Composable
private fun StatusCounter(status: TopicStatus, count: Int, modifier: Modifier) {
    val tint = Palette.status(status)
    Column(
        modifier.clip(RoundedCornerShape(14.dp)).background(tint.copy(alpha = 0.1f)).padding(vertical = 12.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(statusIcon(status), null, tint = tint, modifier = Modifier.size(22.dp))
        Text("$count", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(status.title, fontSize = 12.sp, color = secondaryText, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Beherrschung je Thema als Balken, mit gestrichelten Grenzen für Lücke (55 %) und Stärke (75 %). */
@Composable
fun MasteryBars(insights: List<TopicInsight>, showStrengthLine: Boolean = false) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (insight in insights) {
            val mastery = insight.mastery ?: 0.0
            val tint = Palette.status(insight.status)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(insight.topic.title, fontSize = 14.sp, modifier = Modifier.width(170.dp), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Box(Modifier.weight(1f).height(18.dp)) {
                    Box(Modifier.fillMaxWidth().height(18.dp).clip(RoundedCornerShape(6.dp)).background(LocalSurfaces.current.field))
                    Box(Modifier.fillMaxWidth(mastery.toFloat()).height(18.dp).clip(RoundedCornerShape(6.dp)).background(tint))
                    Canvas(Modifier.fillMaxSize()) {
                        val dash = PathEffect.dashPathEffect(floatArrayOf(6f, 6f))
                        val gapX = size.width * KnowledgeAnalyzer.GAP_THRESHOLD.toFloat()
                        drawLine(Palette.orange, Offset(gapX, -4f), Offset(gapX, size.height + 4f), strokeWidth = 2f, pathEffect = dash)
                        if (showStrengthLine) {
                            val strongX = size.width * KnowledgeAnalyzer.STRENGTH_THRESHOLD.toFloat()
                            drawLine(Palette.success, Offset(strongX, -4f), Offset(strongX, size.height + 4f), strokeWidth = 2f, pathEffect = dash)
                        }
                    }
                }
                Text("${mastery.masteryPercent} %", fontSize = 13.sp, color = secondaryText, fontWeight = FontWeight.SemiBold, modifier = Modifier.width(52.dp).padding(start = 8.dp))
            }
        }
    }
}

@Composable
private fun PathSummaryCard(state: AppState) {
    val store = state.store
    val modules = store.moduleProgress
    Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionTitle("Lernpfad", "${modules.count { it.isCompleted }} von ${modules.size} Modulen gemeistert", Icons.Rounded.Route) {
            Text("Öffnen", color = Palette.orange, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickableHand { state.section = Section.PATH })
        }
        for (progress in modules) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (progress.isUnlocked) IconTile(symbolIcon(progress.module.symbol), Palette.tier(progress.module.tier), 36.dp)
                else Box(Modifier.size(36.dp).clip(CircleShape).background(LocalSurfaces.current.field), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Lock, null, tint = secondaryText, modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row {
                        Text(progress.module.title, fontWeight = FontWeight.SemiBold, color = if (progress.isUnlocked) Color.Unspecified else secondaryText, modifier = Modifier.weight(1f))
                        Text("${progress.completedLessons}/${progress.totalLessons}", color = secondaryText, fontSize = 13.sp)
                    }
                    ProgressBar(progress.fraction, height = 6.dp, brush = androidx.compose.ui.graphics.SolidColor(Palette.tier(progress.module.tier)))
                }
            }
        }
    }
}
