package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.Update
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
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import app.javaquest.data.ProgressStore
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.LessonSession
import app.javaquest.core.LessonState
import app.javaquest.core.TopicStatus
import java.time.Duration
import java.time.Instant
import java.time.LocalDate

// ---------------------------------------------------------------- Lernpfad

@Composable
fun PathScreen(state: AppState) {
    val store = state.store
    val states = store.lessonStates
    val results = store.lessonResults
    ScreenScroll {
        Text("Lernpfad", fontSize = TitelGroesse, fontWeight = FontWeight.Bold)
        Text(
            "Eine Lektion wird frei, sobald die vorherige mit mindestens ${LessonSession.passPercent} % bestanden ist.",
            color = secondaryText, fontSize = 16.sp,
        )
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
                        if (LocalKompakt.current) {
                            Spacer(Modifier.height(6.dp))
                            Chip(module.tier.title, tint = tint)
                        }
                    }
                    if (!LocalKompakt.current) {
                        Chip(module.tier.title, tint = tint)
                        Spacer(Modifier.width(10.dp))
                    }
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
        Text("Wissensanalyse", fontSize = TitelGroesse, fontWeight = FontWeight.Bold)
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
            ChipZeile {
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
    var sicherungMeldung by remember { mutableStateOf<String?>(null) }
    val plattform = LocalPlattform.current
    ScreenScroll {
        Text("Profil", fontSize = TitelGroesse, fontWeight = FontWeight.Bold)
        Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ProfileRow("Start", store.experienceLevel.onboardingTitle)
            store.data?.placementScore?.let { ProfileRow("Einstufungsfrage", "$it %") }
            store.placedLevel?.let { ProfileRow("Einstieg", if (it == ExperienceLevel.BEGINNER) "Grundkurs" else store.course.entryModule(it)?.title ?: it.title) }
            ProfileRow("Java Master Score", "${store.masterScore} · ${store.rank.title}")
            ProfileRow("Serie", "${store.displayedStreak} ${if (store.displayedStreak == 1) "Tag" else "Tage"} (Rekord ${store.data?.longestStreak ?: 0})")
            ProfileRow("Bestanden ab", "${LessonSession.passPercent} % je Lektion")
        }
        Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionTitle("Privat & lokal", icon = Icons.Rounded.Shield)
            Text("Dein Lernstand liegt nur auf ${plattform.geraet} – kein Konto, keine Cloud, keine Datenübertragung.", fontSize = 15.sp)
            Text(plattform.lernstandOrt, fontFamily = CodeFont, fontSize = 12.sp, color = secondaryText)
        }
        Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionTitle(
                "Fortschritt sichern",
                "Eine Datei zum Mitnehmen. Beim Einlesen wird nichts gelöscht: Aus beiden " +
                    "Ständen wird jeweils das bessere Ergebnis übernommen. " +
                    "Die Datei passt in jede Fassung: Web-App, Mac, iPhone, Windows und Android.",
                Icons.Rounded.Inventory2,
            )
            ChipZeile(abstand = 10.dp) {
                SecondaryButton("Sicherung speichern", Icons.Rounded.Inventory2) {
                    sicherungSpeichern(plattform, store) { sicherungMeldung = it }
                }
                SecondaryButton("Sicherung einlesen", Icons.Rounded.Update) {
                    sicherungLaden(plattform, store) { sicherungMeldung = it }
                }
            }
            sicherungMeldung?.let { Text(it, fontSize = 14.sp, color = secondaryText) }
        }
        store.kopieVorZuruecksetzen()?.let { kopie ->
            Column(Modifier.fillMaxWidth().card(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionTitle(
                    "Stand vor dem Zurücksetzen",
                    "${kopieBeschreibung(kopie)}. Nichts wird gelöscht: Was du seitdem gelernt hast, bleibt – " +
                        "von beiden Ständen gilt jeweils das bessere Ergebnis.",
                    Icons.Rounded.Update,
                )
                SecondaryButton("Wiederherstellen", Icons.Rounded.Update) {
                    sicherungMeldung = if (store.vorZuruecksetzenWiederherstellen())
                        "Wiederhergestellt – dein Stand von vorher ist wieder da, und nichts von seitdem ging verloren."
                    else "Die Kopie ließ sich nicht lesen."
                }
            }
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
            text = { Text("Score, Lernpfad und Wissensanalyse werden zurückgesetzt. Eine Kopie bleibt liegen – im Profil und beim Neustart kannst du sie wiederherstellen.") },
            confirmButton = {
                TextButton(onClick = { confirmReset = false; state.closeFlow(); store.resetAllProgress() }) { Text("Löschen", color = Palette.ember) }
            },
            dismissButton = { TextButton(onClick = { confirmReset = false }) { Text("Abbrechen") } },
        )
    }
}

/* Die Dateiauswahl selbst gehört der Plattform (FileDialog auf dem Desktop, Systemdialog
   auf Android); hier steht nur, was mit dem Inhalt passiert und was gemeldet wird. */
private fun sicherungSpeichern(plattform: Plattform, store: ProgressStore, meldung: (String) -> Unit) {
    val text = try {
        store.sicherungText()
    } catch (e: Exception) {
        meldung("Speichern fehlgeschlagen: ${e.message}")
        return
    }
    plattform.sicherungSpeichern("javaquest-" + LocalDate.now() + ".json", text, meldung)
}

private fun sicherungLaden(plattform: Plattform, store: ProgressStore, meldung: (String) -> Unit) {
    plattform.sicherungWaehlen { ergebnis ->
        meldung(
            when {
                ergebnis == null -> "Abgebrochen."
                ergebnis.isFailure -> "Einlesen fehlgeschlagen: ${ergebnis.exceptionOrNull()?.message}"
                else -> try {
                    val dazu = store.sicherungEinlesen(ergebnis.getOrThrow())
                    if (dazu == null) "Das sieht nicht nach einer JavaQuest-Sicherung aus."
                    else "Eingelesen: $dazu Aufgabe(n) dazugekommen, nichts gelöscht."
                } catch (e: Exception) {
                    "Einlesen fehlgeschlagen: ${e.message}"
                }
            },
        )
    }
}

/** „Vom 24.09.2026, 10:20 · 8 Lektionen bestanden · 102 Aufgaben“ – in Ortszeit. */
fun kopieBeschreibung(kopie: app.javaquest.data.KopieVorZuruecksetzen): String {
    val wann = kopie.erstellt?.let {
        runCatching {
            java.time.format.DateTimeFormatter.ofPattern("dd.MM.yyyy, HH:mm")
                .format(java.time.Instant.parse(it).atZone(java.time.ZoneId.systemDefault())) + " Uhr"
        }.getOrNull()
    }
    val lektionen = kopie.stand.lessonRecords.values.count { it.isCompleted }
    val aufgaben = kopie.stand.attempts.map { it.taskId }.toSet().size
    return listOfNotNull(
        wann?.let { "Vom $it" },
        "$lektionen ${if (lektionen == 1) "Lektion" else "Lektionen"} bestanden",
        "$aufgaben ${if (aufgaben == 1) "Aufgabe" else "Aufgaben"}",
    ).joinToString(" · ")
}

@Composable
private fun ProfileRow(label: String, value: String) {
    if (LocalKompakt.current) {
        Column {
            Text(label, color = secondaryText, fontSize = 13.sp)
            Text(value, fontWeight = FontWeight.SemiBold)
        }
    } else {
        Row {
            Text(label, color = secondaryText, modifier = Modifier.width(200.dp))
            Text(value, fontWeight = FontWeight.SemiBold)
        }
    }
}

/** Chips oder Knöpfe nebeneinander, die auf schmalen Bildschirmen in die nächste Zeile rutschen. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ChipZeile(abstand: androidx.compose.ui.unit.Dp = 8.dp, content: @Composable () -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(abstand), verticalArrangement = Arrangement.spacedBy(abstand)) { content() }
}

// ---------------------------------------------------------------- Fenster

/** Unter dieser Breite (Handy, schmales Fenster) wandert die Navigation nach unten. */
val KOMPAKT_UNTER = 720.dp

/**
 * Aufbau je nach Breite: Seitenleiste links und Inhalt rechts (Desktop, Tablet, Handy quer),
 * auf dem Handy hochkant Inhalt oben und die Bereiche als Leiste unten. Eine Lektion füllt
 * jeweils den ganzen Inhaltsbereich.
 *
 * Die Ränder des Systems (Statusleiste, Kamera-Aussparung, Gestenleiste, Tastatur) hält
 * `safeDrawing` frei; auf dem Desktop sind sie null.
 */
@Composable
fun AppShell(state: AppState) {
    val surfaces = LocalSurfaces.current
    BoxWithConstraints(Modifier.fillMaxSize().background(surfaces.screen)) {
        val kompakt = maxWidth < KOMPAKT_UNTER
        CompositionLocalProvider(LocalKompakt provides kompakt) {
            when {
                state.store.needsOnboarding -> Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
                    OnboardingScreen(state) { lessonId -> state.section = Section.DASHBOARD; lessonId?.let(state::startLesson) }
                }
                kompakt -> KompakterAufbau(state)
                else -> BreiterAufbau(state)
            }
        }
    }
}

@Composable
private fun Inhalt(state: AppState) {
    val flow = state.flow
    if (flow != null) {
        LessonFlowScreen(flow, onClose = state::closeFlow, onStartLesson = state::startLesson, onTrainAgain = state::startTraining)
    } else {
        when (state.section) {
            Section.DASHBOARD -> DashboardScreen(state)
            Section.PATH -> PathScreen(state)
            Section.TOPICS -> TopicsScreen(state)
            Section.ANALYSIS -> AnalysisScreen(state)
            Section.PROFILE -> ProfileScreen(state)
        }
    }
}

/** Handy: Inhalt oben, Bereiche unten. Während einer Lektion verschwindet die Leiste. */
@Composable
private fun KompakterAufbau(state: AppState) {
    val surfaces = LocalSurfaces.current
    val mitLeiste = state.flow == null
    Column(Modifier.fillMaxSize()) {
        val raender = if (mitLeiste) WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal)
            else WindowInsets.safeDrawing
        Box(Modifier.weight(1f).fillMaxWidth().windowInsetsPadding(raender)) { Inhalt(state) }
        if (mitLeiste) {
            Box(Modifier.fillMaxWidth().height(1.dp).background(surfaces.divider))
            NavigationBar(containerColor = surfaces.card, tonalElevation = 0.dp) {
                for (section in Section.entries) {
                    NavigationBarItem(
                        selected = state.section == section,
                        onClick = { state.section = section },
                        icon = { Icon(section.icon, contentDescription = null) },
                        label = { Text(section.kurz, fontSize = 11.sp, maxLines = 1) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Palette.orange,
                            selectedTextColor = Palette.orange,
                            indicatorColor = Palette.orange.copy(alpha = 0.14f),
                            unselectedIconColor = secondaryText,
                            unselectedTextColor = secondaryText,
                        ),
                        modifier = Modifier.testTag("nav-${section.name.lowercase()}"),
                    )
                }
            }
        }
    }
}

/** Desktop und Tablet: Seitenleiste links, Inhalt rechts. */
@Composable
private fun BreiterAufbau(state: AppState) {
    val store = state.store
    val surfaces = LocalSurfaces.current
    Row(Modifier.fillMaxSize().background(surfaces.screen).windowInsetsPadding(WindowInsets.safeDrawing)) {
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
        Box(Modifier.weight(1f).fillMaxHeight()) { Inhalt(state) }
    }
}
