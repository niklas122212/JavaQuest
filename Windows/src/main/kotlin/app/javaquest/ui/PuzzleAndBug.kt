package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BugReport
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.CodeSnippet
import app.javaquest.core.TaskKind

/** Code-Puzzle: Bausteine anklicken hängt sie an, Klick auf eine Programmzeile legt sie zurück. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PuzzleBoard(spec: TaskKind.Ordering, taskId: String, order: List<Int>, isLocked: Boolean, evaluation: TaskEvaluation, onChange: (List<Int>) -> Unit) {
    val pieces = spec.pieces
    val remaining = spec.shuffledOrder(taskId).filter { it !in order }
    val showsCorrectness = evaluation.hasResult || evaluation.isRevealed
    val lines = TaskKind.Ordering.assemble(order.map { pieces[it] }).split("\n")
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(Modifier.fillMaxWidth().heightIn(min = 80.dp).clip(RoundedCornerShape(InnerRadius)).background(CodeColors.background).padding(vertical = 6.dp)) {
            if (order.isEmpty()) {
                Text("Wähle unten die Zeilen in der richtigen Reihenfolge aus.", color = CodeColors.plain.copy(alpha = 0.4f), fontFamily = CodeFont, fontSize = 13.sp, modifier = Modifier.padding(14.dp))
            }
            order.forEachIndexed { position, pieceIndex ->
                val isRight = pieces.getOrNull(position) == pieces[pieceIndex]
                val tint = if (isRight) Palette.success else Palette.ember
                Row(
                    Modifier.fillMaxWidth()
                        .background(if (showsCorrectness) tint.copy(alpha = 0.15f) else Color.Transparent)
                        .clickableHand(enabled = !isLocked) { onChange(order.toMutableList().also { it.removeAt(position) }) }
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("${position + 1}", color = CodeColors.plain.copy(alpha = 0.35f), fontFamily = CodeFont, fontSize = 12.sp, modifier = Modifier.width(22.dp))
                    Text(highlighted(lines.getOrElse(position) { pieces[pieceIndex] }), fontFamily = CodeFont, fontSize = 14.sp, softWrap = false,
                        modifier = Modifier.weight(1f).horizontalScroll(rememberScrollState()))
                    if (showsCorrectness) Icon(if (isRight) Icons.Rounded.CheckCircle else Icons.Rounded.Cancel, null, tint = tint, modifier = Modifier.size(18.dp))
                }
            }
        }
        if (remaining.isNotEmpty() && !isLocked) {
            Text("BAUSTEINE – ANTIPPEN ODER ANKLICKEN ZUM EINFÜGEN", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = secondaryText)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                remaining.forEach { index ->
                    Text(
                        pieces[index], color = CodeColors.plain, fontFamily = CodeFont, fontSize = 13.sp,
                        modifier = Modifier.clip(RoundedCornerShape(9.dp)).background(CodeColors.chrome)
                            .border(1.dp, Palette.orange.copy(alpha = 0.5f), RoundedCornerShape(9.dp))
                            .clickableHand { onChange(order + index) }
                            .testTag("puzzle-piece-$index")
                            .padding(horizontal = 10.dp, vertical = 8.dp),
                    )
                }
            }
        }
        if (order.isNotEmpty() && !isLocked) {
            Text("Alle zurücklegen", color = Palette.orange, fontWeight = FontWeight.SemiBold, fontSize = 14.sp,
                modifier = Modifier.clickableHand { onChange(emptyList()) })
        }
    }
}

/** Bug-Jagd: Jede Zeile ist anklickbar, nach dem Lösen steht die Korrektur darunter. */
@Composable
fun BugLinePicker(snippet: CodeSnippet, spec: TaskKind.FindBug, selection: Int?, isLocked: Boolean, evaluation: TaskEvaluation, onSelect: (Int) -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(InnerRadius)).background(CodeColors.background).padding(vertical = 6.dp)) {
        snippet.lines.forEachIndexed { index, line ->
            val number = index + 1
            val isBug = evaluation.isSolved && number == spec.bugLine
            val wrongPick = number == selection && evaluation.hasResult && !evaluation.isCorrect
            val background = when {
                isBug -> Palette.ember.copy(alpha = 0.25f)
                wrongPick -> Palette.success.copy(alpha = 0.12f)
                number == selection -> Palette.orange.copy(alpha = 0.22f)
                else -> Color.Transparent
            }
            Row(
                Modifier.fillMaxWidth().background(background)
                    .clickableHand(enabled = !isLocked && line.code.isNotBlank()) { onSelect(number) }
                    .testTag("bug-line-$number")
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("$number", color = CodeColors.plain.copy(alpha = 0.35f), fontFamily = CodeFont, fontSize = 12.sp, modifier = Modifier.width(24.dp))
                Text(highlighted(line.code.ifEmpty { " " }), fontFamily = CodeFont, fontSize = 14.sp, softWrap = false,
                    textDecoration = if (isBug) TextDecoration.LineThrough else null,
                    modifier = Modifier.weight(1f).horizontalScroll(rememberScrollState()))
                when {
                    isBug -> Icon(Icons.Rounded.BugReport, null, tint = Palette.ember, modifier = Modifier.size(18.dp))
                    wrongPick -> Icon(Icons.Rounded.CheckCircle, "in Ordnung", tint = Palette.success, modifier = Modifier.size(18.dp))
                }
            }
            if (isBug) {
                Row(Modifier.fillMaxWidth().background(Palette.success.copy(alpha = 0.22f)).padding(horizontal = 10.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Build, null, tint = Palette.success, modifier = Modifier.size(16.dp).width(24.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(highlighted(line.code.takeWhile { it == ' ' } + spec.fix.code.trim()), fontFamily = CodeFont, fontSize = 14.sp, softWrap = false)
                }
            }
        }
    }
}
