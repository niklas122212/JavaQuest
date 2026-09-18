package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Coffee
import androidx.compose.material.icons.rounded.DeleteForever
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.LessonState
import app.javaquest.core.TopicStatus
import java.time.Duration
import java.time.Instant

// ---------------------------------------------------------------- Lernpfad

@Composable
fun PathScreen(state: AppState) {
    val store = state.store
    val states = store.lessonStates
    val results = store.lessonResults
    ScreenScroll {
        Text("Lernpfad", fontSize = 34.sp, fontWeight = FontWeight.Bold)
        Text("Eine Lektion wird frei, sobald die vorherige mit mindestens 90 % bestanden ist.", color = secondaryText, fontSize = 16.sp)
        for (progress in store.moduleProgress) {
            val module = progress.module
            val tint = Palette.tier(module.tier)
            Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconTile(symbolIcon(module.symbol), if (progress.isUnlocked) tint else secondaryText, 46.dp)
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text(module.title, fontSize = 21.sp, fontWeight = FontWeight.Bold)
                        Text(module.subtitle, color = secondaryText, fontSize = 14.sp)
                    }
                    Chip(module.tier.title, tint = tint)
                    Spacer(Modifier.width(10.dp))
                    Text("${progress.completedLessons}/${progress.totalLessons}", color = secondaryText, fontWeight = FontWeight.SemiBold)
                }
                ProgressBar(progress.fraction, height = 6.dp, brush = SolidColor(tint))
                module.lessons.forEachIndexed { index, lesson ->
                    val lessonState = states[lesson.id] ?: LessonState.Locked
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(if (lessonState == LessonState.Current) Palette.orange.copy(alpha = 0.08f) else Color.Transparent)
                            .then(if (lessonState.isPlayable) Modifier.clickableHand { state.startLesson(lesson.id) } else Modifier)
                            .padding(10.dp)
                            .testTag("path-${lesson.id}"),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        val circle = when (lessonState) {
                            is LessonState.Completed -> Palette.success
                            LessonState.Current -> Palette.orange
                            LessonState.Locked -> LocalSurfaces.current.field
                        }
                        Box(Modifier.size(38.dp).clip(CircleShape).background(circle), contentAlignment = Alignment.Center) {
                            when (lessonState) {
                                is LessonState.Completed -> Icon(Icons.Rounded.Check, null, tint = Color.White)
                                LessonState.Current -> Icon(Icons.Rounded.PlayArrow, null, tint = Color.White)
                                LessonState.Locked -> Icon(Icons.Rounded.Lock, null, tint = secondaryText, modifier = Modifier.size(18.dp))
                            }
                        }
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text("${index + 1}. ${lesson.title}", fontWeight = FontWeight.SemiBold, fontSize = 16.sp,
                                color = if (lessonState.isPlayable) Color.Unspecified else secondaryText)
                            val detail = when (lessonState) {
                                is LessonState.Completed -> if (lessonState.viaPlacement) "Per Einstufung angerechnet"
                                    else "Bestwert ${((results[lesson.id]?.bestAccuracy ?: 0.0) * 100).toInt()} %"
                                LessonState.Current -> "Als Nächstes · ${lesson.estimatedMinutes} Min"
                                LessonState.Locked -> "Noch gesperrt"
                            }
                            Text(detail, color = secondaryText, fontSize = 13.sp)
                        }
                        if (lessonState is LessonState.Completed && !lessonState.viaPlacement) StarRow(lessonState.stars, 18.dp)
                        if (lessonState is LessonState.Completed && lessonState.viaPlacement) Chip("Einstufung", Icons.Rounded.Verified, Palette.indigo)
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------- Analyse

@Composable
fun AnalysisScreen(state: AppState) {
    val store = state.store
    val report = store.knowledgeReport
    ScreenScroll {
        Text("Wissensanalyse", fontSize = 34.sp, fontWeight = FontWeight.Bold)
        Text("Automatisch aus allen Antworten: Stärken, Wissenslücken und Themen, die du noch nicht kennst.", color = secondaryText, fontSize = 16.sp)
        Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(96.dp), contentAlignment = Alignment.Center) {
                    ProgressRing(report.overallMastery ?: 0.0, Modifier.fillMaxSize(), 10.dp)
                    Text(report.overallMastery?.let { "${it.masteryPercent} %" } ?: "–", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                }
                Spacer(Modifier.width(18.dp))
                Column(Modifier.weight(1f)) {
                    Text("Durchschnittliche Beherrschung", fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
                    Text("über alle geübten Themen", color = secondaryText)
                }
            }
            DistributionBar(report)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (status in TopicStatus.entries) Chip("${report.topics(status).size} ${status.title}", statusIcon(status), Palette.status(status))
            }
        }
        val practiced = report.insights.filter { it.mastery != null }
        if (practiced.isNotEmpty()) {
            Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SectionTitle("Beherrschung je Thema", "Ab 75 % Stärke · unter 55 % Wissenslücke", Icons.Rounded.BarChart)
                MasteryBars(practiced, showStrengthLine = true)
            }
        }
        for (status in listOf(TopicStatus.GAP, TopicStatus.DEVELOPING, TopicStatus.STRENGTH, TopicStatus.UNKNOWN)) {
            val insights = if (status == TopicStatus.GAP) report.gaps else report.topics(status)
            if (insights.isEmpty()) continue
            Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionTitle(status.title, icon = statusIcon(status))
                for (insight in insights) {
                    val tint = Palette.status(insight.status)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconTile(symbolIcon(insight.topic.symbol), tint, 36.dp)
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(insight.topic.title, fontWeight = FontWeight.SemiBold)
                            Text(detailLine(insight.stats.attempts, insight.stats.lastPracticed, insight.topic.summary), color = secondaryText, fontSize = 13.sp,
                                maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                        insight.mastery?.let { Text("${it.masteryPercent} %", color = tint, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 10.dp)) }
                        if (status != TopicStatus.UNKNOWN && store.practiceTasks(insight.topic.id).isNotEmpty()) {
                            SecondaryButton("Üben", Icons.Rounded.GpsFixed, tint = tint) { state.startPractice(insight.topic.id) }
                        }
                    }
                }
            }
        }
    }
}

private fun detailLine(attempts: Int, last: Instant?, summary: String): String {
    if (attempts == 0) return summary
    val days = last?.let { Duration.between(it, Instant.now()).toDays() } ?: 0
    val whenText = when (days) { 0L -> "heute"; 1L -> "gestern"; else -> "vor $days Tagen" }
    return "$attempts ${if (attempts == 1) "Aufgabe" else "Aufgaben"} · zuletzt $whenText"
}

// ---------------------------------------------------------------- Profil

@Composable
fun ProfileScreen(state: AppState) {
    val store = state.store
    var confirmReset by remember { mutableStateOf(false) }
    ScreenScroll {
        Text("Profil", fontSize = 34.sp, fontWeight = FontWeight.Bold)
        Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ProfileRow("Start", store.experienceLevel.onboardingTitle)
            store.data?.placementScore?.let { ProfileRow("Einstufungsfrage", "$it %") }
            store.placedLevel?.let { ProfileRow("Einstieg", if (it == ExperienceLevel.BEGINNER) "Grundkurs" else store.course.entryModule(it)?.title ?: it.title) }
            ProfileRow("Java Master Score", "${store.masterScore} · ${store.rank.title}")
            ProfileRow("Serie", "${store.displayedStreak} ${if (store.displayedStreak == 1) "Tag" else "Tage"} (Rekord ${store.data?.longestStreak ?: 0})")
            ProfileRow("Bestanden ab", "90 % je Lektion")
        }
        Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionTitle("Privat & lokal", icon = Icons.Rounded.Shield)
            Text("Dein Lernstand liegt nur auf diesem Rechner – kein Konto, keine Cloud, keine Datenübertragung.", fontSize = 15.sp)
            Text(app.javaquest.data.ProgressFile.defaultLocation().path.toString(), fontFamily = CodeFont, fontSize = 12.sp, color = secondaryText)
        }
        Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionTitle("Neu anfangen", "Löscht alle Fortschritte und startet das Onboarding neu.", Icons.Rounded.Replay)
            SecondaryButton("Alle Fortschritte löschen", Icons.Rounded.DeleteForever, tint = Palette.ember) { confirmReset = true }
        }
        store.lastSaveError?.let { Text("Speichern fehlgeschlagen: $it", color = Palette.ember) }
    }
    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = { Text("Alle Fortschritte löschen?") },
            text = { Text("Score, Lernpfad und Wissensanalyse werden zurückgesetzt. Das lässt sich nicht rückgängig machen.") },
            confirmButton = {
                TextButton(onClick = { confirmReset = false; state.closeFlow(); store.resetAllProgress() }) { Text("Löschen", color = Palette.ember) }
            },
            dismissButton = { TextButton(onClick = { confirmReset = false }) { Text("Abbrechen") } },
        )
    }
}

@Composable
private fun ProfileRow(label: String, value: String) {
    Row {
        Text(label, color = secondaryText, modifier = Modifier.width(200.dp))
        Text(value, fontWeight = FontWeight.SemiBold)
    }
}

// ---------------------------------------------------------------- Fenster

/** Desktop-Aufbau: Seitenleiste links, Inhalt rechts; eine Lektion füllt den Inhaltsbereich. */
@Composable
fun AppShell(state: AppState) {
    val store = state.store
    if (store.needsOnboarding) {
        OnboardingScreen(store) { lessonId -> state.section = Section.DASHBOARD; lessonId?.let(state::startLesson) }
        return
    }
    val surfaces = LocalSurfaces.current
    Row(Modifier.fillMaxSize().background(surfaces.screen)) {
        Column(
            Modifier.width(250.dp).fillMaxHeight().background(surfaces.card).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 18.dp, top = 4.dp)) {
                Box(Modifier.size(38.dp).clip(RoundedCornerShape(11.dp)).background(Palette.hero), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Coffee, null, tint = Color.White, modifier = Modifier.size(22.dp))
                }
                Spacer(Modifier.width(10.dp))
                Text("JavaQuest", fontSize = 20.sp, fontWeight = FontWeight.Bold)
            }
            for (section in Section.entries) {
                val selected = state.flow == null && state.section == section
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (selected) Palette.orange.copy(alpha = 0.14f) else Color.Transparent)
                        .clickableHand { state.closeFlow(); state.section = section }
                        .padding(horizontal = 12.dp, vertical = 10.dp)
                        .testTag("nav-${section.name.lowercase()}"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(section.icon, null, tint = if (selected) Palette.orange else secondaryText, modifier = Modifier.size(22.dp))
                    Spacer(Modifier.width(12.dp))
                    Text(section.title, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal, color = if (selected) Palette.orange else Color.Unspecified)
                }
            }
            Spacer(Modifier.weight(1f))
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.hero).padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Eyebrow("Master Score", Color.White.copy(alpha = 0.85f))
                Text("${store.masterScore}", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Black)
                Text(store.rank.title, color = Color.White.copy(alpha = 0.9f), fontSize = 13.sp)
            }
        }
        Box(Modifier.width(1.dp).fillMaxHeight().background(surfaces.divider))
        Box(Modifier.weight(1f).fillMaxHeight()) {
            val flow = state.flow
            if (flow != null) {
                LessonFlowScreen(flow, onClose = state::closeFlow, onStartLesson = state::startLesson)
            } else {
                when (state.section) {
                    Section.DASHBOARD -> DashboardScreen(state)
                    Section.PATH -> PathScreen(state)
                    Section.ANALYSIS -> AnalysisScreen(state)
                    Section.PROFILE -> ProfileScreen(state)
                }
            }
        }
    }
}
