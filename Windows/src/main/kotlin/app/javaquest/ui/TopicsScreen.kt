package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Numbers
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.toMutableStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.Difficulty
import app.javaquest.core.Topic
import app.javaquest.core.TrainingBuilder
import app.javaquest.data.TopicPractice
import kotlin.math.roundToInt

/**
 * Freies Lernen: alle Themen des Kurses, unabhängig vom Lernpfad.
 * Themen, Niveau und Anzahl wählen – daraus wird eine eigene Übungsrunde.
 */
@Composable
fun TopicsScreen(state: AppState) {
    val store = state.store
    val selectedTopics = remember { mutableSetOf<String>().toMutableStateList() }
    val selectedLevels = remember { mutableSetOf<Difficulty>().toMutableStateList() }
    var taskCount by remember { mutableIntStateOf(10) }

    val matching = TrainingBuilder.freePool(store.course, selectedTopics.toSet(), selectedLevels.toSet()).size

    ScreenScroll {
        Column {
            Text("Such dir aus, was du üben willst", fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Text(
                "Jedes Thema ist sofort übbar – auch wenn die Lektion im Lernpfad noch nicht dran war. " +
                    "Ohne Auswahl kommt alles gemischt.",
                color = secondaryText, fontSize = 16.sp,
            )
        }

        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SectionTitle("Niveau", "Ohne Auswahl: alle Niveaus", Icons.Rounded.BarChart)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Difficulty.entries.forEach { level ->
                        FilterChip("${level.level}", level in selectedLevels, Palette.difficulty(level)) {
                            if (level in selectedLevels) selectedLevels.remove(level) else selectedLevels.add(level)
                        }
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SectionTitle("Wie viele Aufgaben?", null, Icons.Rounded.Numbers)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(5, 10, 15, 25).forEach { count ->
                        FilterChip("$count", taskCount == count, Palette.indigo) { taskCount = count }
                    }
                }
            }
            if (selectedTopics.isNotEmpty()) {
                SecondaryButton("Auswahl zurücksetzen", Icons.Rounded.Refresh) { selectedTopics.clear() }
            }
        }

        BoxWithConstraints {
            val columns = if (maxWidth >= 1000.dp) 3 else if (maxWidth >= 680.dp) 2 else 1
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                store.course.practiceableTopics.chunked(columns).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        row.forEach { topic ->
                            TopicCard(
                                topic = topic,
                                practice = store.topicPractice(topic.id),
                                taskCount = store.course.tasksForTopic(topic.id).size,
                                selected = topic.id in selectedTopics,
                                modifier = Modifier.weight(1f),
                            ) {
                                if (topic.id in selectedTopics) selectedTopics.remove(topic.id) else selectedTopics.add(topic.id)
                            }
                        }
                        repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }

        Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                if (matching == 0) "Zu dieser Auswahl gibt es keine Aufgaben – nimm ein Niveau dazu."
                else "${minOf(taskCount, matching)} von $matching passenden Aufgaben · Niveau: " +
                    if (selectedLevels.isEmpty()) "alle" else selectedLevels.sortedBy { it.level }.joinToString(", ") { "${it.level}" },
                color = secondaryText, fontSize = 15.sp,
            )
            PrimaryButton(
                if (selectedTopics.isEmpty()) "Gemischt üben" else "${selectedTopics.size} Thema/Themen üben",
                Icons.Rounded.PlayArrow,
                Modifier.fillMaxWidth().testTag("start-free-training"),
                enabled = matching > 0,
            ) {
                state.startFreeTraining(selectedTopics.toSet(), selectedLevels.toSet(), taskCount)
            }
        }
    }
}

@Composable
private fun TopicCard(
    topic: Topic,
    practice: TopicPractice,
    taskCount: Int,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val tint = if (selected) Palette.orange else Palette.indigo
    Column(
        modifier
            .card(16.dp)
            .clickableHand(onClick = onClick),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconTile(symbolIcon(topic.symbol), tint, 36.dp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(topic.title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, maxLines = 1)
                Text("$taskCount Aufgaben", color = secondaryText, fontSize = 12.sp)
            }
            Icon(
                if (selected) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
                null,
                tint = if (selected) Palette.orange else secondaryText,
            )
        }
        Text(topic.summary, color = secondaryText, fontSize = 13.sp, maxLines = 2, lineHeight = 17.sp)
        if (practice.seen > 0) {
            ProgressBar(practice.successRate, height = 6.dp, brush = SolidColor(tint))
            Text(
                "${practice.correct} von ${practice.seen} richtig · ${(practice.successRate * 100).roundToInt()} %",
                color = secondaryText, fontSize = 12.sp,
            )
        } else {
            Text("Noch nicht geübt", color = secondaryText, fontSize = 12.sp)
        }
    }
}

@Composable
private fun FilterChip(text: String, selected: Boolean, tint: Color, onClick: () -> Unit) {
    Box(
        Modifier
            .clip(CircleShape)
            .background(if (selected) tint else LocalSurfaces.current.field)
            .clickableHand(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 9.dp),
    ) {
        Text(
            text,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) Color.White else LocalSurfaces.current.secondaryText,
        )
    }
}
