package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.SubdirectoryArrowRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.FastRewind
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.PlayCircle
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.ExplainedLine
import app.javaquest.core.interpreter.JavaRunner
import app.javaquest.core.interpreter.JavaTrace
import app.javaquest.core.interpreter.JavaTraceStep
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

/**
 * „Ausführen und zusehen“: Das Beispiel läuft wirklich – Zeile für Zeile, mit Erklärung, Variablen und Konsole.
 * Wie ein Debugger, nur zum Zuschauen. Der Knopf erscheint nur, wenn der eingebaute Interpreter das Programm versteht.
 */
@Composable
fun CodeRunPanel(source: String, lines: List<ExplainedLine>) {
    val trace by produceState<JavaTrace?>(null, source) { value = withContext(Dispatchers.Default) { JavaRunner.trace(source) } }
    val current = trace?.takeIf { it.isUseful } ?: return
    var isOpen by remember(source) { mutableStateOf(false) }
    var index by remember(source) { mutableIntStateOf(0) }
    var isPlaying by remember(source) { mutableStateOf(false) }
    val last = current.steps.lastIndex

    // Abspielen: alle 0,8 Sekunden ein Schritt – bis zum Ende.
    LaunchedEffect(isPlaying, index) {
        if (isPlaying) {
            if (index >= last) { isPlaying = false; return@LaunchedEffect }
            delay(800)
            index++
        }
    }

    if (!isOpen) {
        Row(
            Modifier.clip(RoundedCornerShape(10.dp)).clickableHand { index = 0; isOpen = true }.padding(vertical = 6.dp).testTag("run-open"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Rounded.PlayCircle, null, tint = Palette.teal, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(8.dp))
            Text("Ausführen und zusehen", color = Palette.teal, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        }
        return
    }

    val step = current.steps[index.coerceIn(0, last)]
    val isLast = index >= last
    val failed = isLast && current.problem != null
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(InnerRadius)).background(Palette.teal.copy(alpha = 0.08f)).padding(14.dp).testTag("run-panel"),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.PlayCircle, null, tint = Palette.teal, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("So läuft das Programm", color = Palette.teal, fontWeight = FontWeight.Bold, fontSize = 16.sp, modifier = Modifier.weight(1f))
            Icon(Icons.Rounded.Close, "Zusehen beenden", tint = secondaryText,
                modifier = Modifier.size(22.dp).clickableHand { isPlaying = false; isOpen = false }.testTag("run-close"))
        }

        RunCode(source, currentLine = if (failed) null else step.line, errorLine = if (failed) step.line else null)

        if (step.method != null && !isLast) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.SubdirectoryArrowRight, null, tint = Palette.violet, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text("in der Methode ${step.method}()", color = Palette.violet, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            }
        }
        Text(explanation(step, isLast, current, lines), fontSize = 15.sp, modifier = Modifier.testTag("run-explanation"))

        BoxWithConstraints {
            if (maxWidth >= 520.dp) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(Modifier.weight(1f)) { RunConsole(step) }
                    Column(Modifier.widthIn(max = 260.dp).weight(0.6f)) { RunVariables(step) }
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RunConsole(step)
                    RunVariables(step)
                }
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            RunControl(Icons.Rounded.SkipPrevious, "Zum Anfang", enabled = index > 0) { isPlaying = false; index = 0 }
            RunControl(Icons.Rounded.FastRewind, "Ein Schritt zurück", enabled = index > 0) { isPlaying = false; index-- }
            RunControl(if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, if (isPlaying) "Pause" else "Abspielen",
                enabled = !isLast, prominent = true, tag = "run-play") { isPlaying = !isPlaying }
            RunControl(Icons.Rounded.FastForward, "Ein Schritt weiter", enabled = !isLast, tag = "run-next") { isPlaying = false; index++ }
            RunControl(Icons.Rounded.SkipNext, "Zum Ende", enabled = !isLast, tag = "run-end") { isPlaying = false; index = last }
            Spacer(Modifier.weight(1f))
            Text("Schritt ${index + 1} von ${current.steps.size}${if (current.isTruncated) "+" else ""}",
                color = secondaryText, fontSize = 12.sp, modifier = Modifier.testTag("run-position"))
        }
    }
}

/** Was in der markierten Zeile gleich passiert – aus der Zeilen-Erklärung. */
private fun explanation(step: JavaTraceStep, isLast: Boolean, trace: JavaTrace, lines: List<ExplainedLine>): String {
    trace.problem?.takeIf { isLast }?.let { return "Hier bleibt das Programm stehen: ${it.message}" }
    if (isLast) return if (trace.isTruncated) "Hier endet die Aufzeichnung – das Programm liefe noch weiter." else "Das Programm ist fertig."
    val line = step.line ?: return ""
    return "Als Nächstes Zeile $line: ${lines.firstOrNull { it.number == line }?.explanation.orEmpty()}"
}

@Composable
private fun RunCode(code: String, currentLine: Int?, errorLine: Int?) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(CodeColors.background).padding(vertical = 8.dp)) {
        code.split("\n").forEachIndexed { index, line ->
            val number = index + 1
            val background = when (number) {
                errorLine -> Palette.ember.copy(alpha = 0.3f)
                currentLine -> Palette.orange.copy(alpha = 0.22f)
                else -> Color.Transparent
            }
            Row(Modifier.fillMaxWidth().background(background).padding(horizontal = 10.dp, vertical = 3.dp)) {
                Text("$number", color = CodeColors.plain.copy(alpha = 0.35f), fontFamily = CodeFont, fontSize = 12.sp, modifier = Modifier.width(26.dp))
                Text(highlighted(line.ifEmpty { " " }), fontFamily = CodeFont, fontSize = 14.sp, softWrap = false,
                    modifier = Modifier.horizontalScroll(rememberScrollState()))
            }
        }
    }
}

@Composable
private fun RunConsole(step: JavaTraceStep) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        RunCaption(Icons.Rounded.Terminal, "Konsole")
        val output = step.output.trimEnd('\n')
        Text(
            output.ifEmpty { "(noch keine Ausgabe)" }, fontFamily = CodeFont, fontSize = 13.sp,
            color = if (output.isEmpty()) CodeColors.plain.copy(alpha = 0.4f) else CodeColors.plain,
            modifier = Modifier.fillMaxWidth().heightIn(min = 36.dp).clip(RoundedCornerShape(10.dp)).background(CodeColors.background).padding(10.dp).testTag("run-console"),
        )
    }
}

@Composable
private fun RunVariables(step: JavaTraceStep) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        RunCaption(Icons.Rounded.Inventory2, "Variablen")
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Palette.indigo.copy(alpha = 0.08f)).padding(10.dp).testTag("run-variables"),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            if (step.variables.isEmpty()) Text("keine", color = secondaryText, fontFamily = CodeFont, fontSize = 13.sp)
            for (variable in step.variables) {
                Text(
                    "${variable.type} ${variable.name} = ${variable.value}", fontFamily = CodeFont, fontSize = 13.sp,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun RunCaption(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = secondaryText, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, color = secondaryText, fontWeight = FontWeight.Bold, fontSize = 13.sp)
    }
}

@Composable
private fun RunControl(icon: ImageVector, label: String, enabled: Boolean, prominent: Boolean = false, tag: String? = null, onClick: () -> Unit) {
    androidx.compose.foundation.layout.Box(
        Modifier.size(width = if (prominent) 44.dp else 36.dp, height = 36.dp).clip(RoundedCornerShape(10.dp))
            .background(if (prominent) Palette.teal else Palette.teal.copy(alpha = 0.14f))
            .clickableHand(enabled = enabled, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, label, tint = (if (prominent) Color.White else Palette.teal).copy(alpha = if (enabled) 1f else 0.4f), modifier = Modifier.size(20.dp))
    }
}
