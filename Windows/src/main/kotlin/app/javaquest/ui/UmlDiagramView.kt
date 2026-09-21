package app.javaquest.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.UmlBox
import app.javaquest.core.UmlBoxKind
import app.javaquest.core.UmlDiagram
import app.javaquest.core.UmlLayout
import app.javaquest.core.UmlMember
import app.javaquest.core.UmlRelation
import app.javaquest.core.UmlRelationKind
import app.javaquest.core.UmlVisibility

/**
 * Zeichnet ein UML-Klassendiagramm: Kästen mit Namen, Attributen und Methoden,
 * dazu die Linien (Dreiecksspitze, Raute, gestrichelt). Die Anordnung kommt aus
 * `UmlLayout` – dieselbe wie in der Apple-Version.
 */
@Composable
fun UmlDiagramView(diagram: UmlDiagram, modifier: Modifier = Modifier) {
    val layout = UmlLayout.compute(diagram)
    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(CardRadius)).background(LocalSurfaces.current.field).padding(16.dp),
    ) {
        Box(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())) {
            Box(Modifier.width(layout.width.dp + 8.dp).height(layout.height.dp + 8.dp)) {
                Canvas(Modifier.fillMaxSize()) {
                    diagram.relations.forEach { relation ->
                        val from = layout.placed(relation.from)
                        val to = layout.placed(relation.to)
                        if (from != null && to != null) drawRelation(relation, from, to)
                    }
                }
                layout.boxes.forEach { placed ->
                    UmlBoxView(
                        placed.box,
                        Modifier
                            .offset(placed.x.dp, placed.y.dp)
                            .width(placed.width.dp)
                            .height(placed.height.dp),
                    )
                }
            }
        }

        if (diagram.relations.isNotEmpty()) {
            Spacer(Modifier.height(14.dp))
            Eyebrow("Linien im Diagramm", secondaryText)
            Spacer(Modifier.height(6.dp))
            diagram.relations.forEach { relation ->
                RelationLegendRow(relation)
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun UmlBoxView(box: UmlBox, modifier: Modifier) {
    val shape = RoundedCornerShape(8.dp)
    Column(
        modifier
            .clip(shape)
            .background(LocalSurfaces.current.card)
            .border(1.5.dp, Palette.indigo.copy(alpha = 0.45f), shape),
    ) {
        Column(
            Modifier.fillMaxWidth().height(UmlLayout.HEADER_HEIGHT.dp).background(Palette.indigo.copy(alpha = 0.12f)),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            box.kind.stereotype?.let {
                Text(it, fontSize = 11.sp, color = Palette.indigo, fontWeight = FontWeight.Medium)
            }
            Text(
                box.name,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                fontStyle = if (box.kind == UmlBoxKind.ABSTRACT) FontStyle.Italic else FontStyle.Normal,
            )
        }
        DividerLine()
        MemberSection(box.fields)
        DividerLine()
        MemberSection(box.methods)
    }
}

@Composable
private fun DividerLine() {
    Box(Modifier.fillMaxWidth().height(1.dp).background(LocalSurfaces.current.divider))
}

@Composable
private fun MemberSection(members: List<UmlMember>) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = UmlLayout.SECTION_PADDING.dp)) {
        if (members.isEmpty()) {
            Spacer(Modifier.height(UmlLayout.ROW_HEIGHT.dp))
        } else {
            members.forEach { member ->
                Row(Modifier.height(UmlLayout.ROW_HEIGHT.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        member.visibility.symbol,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = visibilityColor(member.visibility),
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        member.type?.let { "${member.name}: $it" } ?: member.name,
                        fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

private fun visibilityColor(visibility: UmlVisibility) = when (visibility) {
    UmlVisibility.PUBLIC -> Palette.success
    UmlVisibility.PRIVATE -> Palette.ember
    UmlVisibility.PROTECTED -> Palette.orange
}

/** Erklärt jede Linie in Alltagssprache – kein Symbol bleibt unerklärt. */
@Composable
private fun RelationLegendRow(relation: UmlRelation) {
    Row(verticalAlignment = Alignment.Top) {
        Canvas(Modifier.size(34.dp, 16.dp).padding(top = 4.dp)) { drawRelationGlyph(relation.kind) }
        Spacer(Modifier.width(8.dp))
        Column {
            Text(
                "${relation.from} → ${relation.to}: ${relation.kind.title}",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(relation.kind.meaning, fontSize = 13.sp, color = secondaryText, lineHeight = 18.sp)
            relation.multiplicity?.let {
                Text(
                    "Vielfachheit $it: ${UmlRelationKind.meaningOfMultiplicity(it)}",
                    fontSize = 13.sp,
                    color = Palette.indigo,
                )
            }
        }
    }
}

// ---------------------------------------------------------------- Zeichnen

private fun DrawScope.drawRelation(relation: UmlRelation, from: UmlLayout.Placed, to: UmlLayout.Placed) {
    val scale = density
    val sameRow = kotlin.math.abs(from.y - to.y) < 1
    val start = if (sameRow) {
        Offset(((from.x + from.width) * scale).toFloat(), ((from.y + from.height / 2) * scale).toFloat())
    } else {
        Offset((from.centerX * scale).toFloat(), (from.y * scale).toFloat())
    }
    val end = if (sameRow) {
        Offset((to.x * scale).toFloat(), ((to.y + to.height / 2) * scale).toFloat())
    } else {
        Offset((to.centerX * scale).toFloat(), (to.bottom * scale).toFloat())
    }

    val path = Path().apply {
        moveTo(start.x, start.y)
        if (sameRow) {
            lineTo(end.x, end.y)
        } else {
            val midY = (start.y + end.y) / 2
            lineTo(start.x, midY)
            lineTo(end.x, midY)
            lineTo(end.x, end.y)
        }
    }
    val effect = if (relation.kind.isDashed) PathEffect.dashPathEffect(floatArrayOf(6f * scale, 4f * scale)) else null
    drawPath(path, Palette.indigo, style = Stroke(width = 1.8f * scale, pathEffect = effect))

    val upwards = !sameRow
    when (relation.kind) {
        UmlRelationKind.EXTENDS, UmlRelationKind.IMPLEMENTS -> drawTriangleHead(end, upwards, scale)
        UmlRelationKind.AGGREGATION, UmlRelationKind.COMPOSITION ->
            drawDiamondHead(end, upwards, relation.kind == UmlRelationKind.COMPOSITION, scale)
        UmlRelationKind.ASSOCIATION, UmlRelationKind.DEPENDENCY -> drawArrowHead(end, upwards, scale)
    }
}

private fun DrawScope.drawTriangleHead(point: Offset, upwards: Boolean, scale: Float) {
    val size = 11f * scale
    val path = Path().apply {
        moveTo(point.x, point.y)
        if (upwards) {
            lineTo(point.x - size * 0.7f, point.y + size)
            lineTo(point.x + size * 0.7f, point.y + size)
        } else {
            lineTo(point.x - size, point.y - size * 0.7f)
            lineTo(point.x - size, point.y + size * 0.7f)
        }
        close()
    }
    drawPath(path, Color.White)
    drawPath(path, Palette.indigo, style = Stroke(width = 1.8f * scale))
}

private fun DrawScope.drawDiamondHead(point: Offset, upwards: Boolean, filled: Boolean, scale: Float) {
    val length = 16f * scale
    val width = 9f * scale
    val path = Path().apply {
        moveTo(point.x, point.y)
        if (upwards) {
            lineTo(point.x - width / 2, point.y + length / 2)
            lineTo(point.x, point.y + length)
            lineTo(point.x + width / 2, point.y + length / 2)
        } else {
            lineTo(point.x - length / 2, point.y - width / 2)
            lineTo(point.x - length, point.y)
            lineTo(point.x - length / 2, point.y + width / 2)
        }
        close()
    }
    drawPath(path, if (filled) Palette.indigo else Color.White)
    drawPath(path, Palette.indigo, style = Stroke(width = 1.8f * scale))
}

private fun DrawScope.drawArrowHead(point: Offset, upwards: Boolean, scale: Float) {
    val size = 9f * scale
    val path = Path().apply {
        if (upwards) {
            moveTo(point.x - size * 0.6f, point.y + size)
            lineTo(point.x, point.y)
            lineTo(point.x + size * 0.6f, point.y + size)
        } else {
            moveTo(point.x - size, point.y - size * 0.6f)
            lineTo(point.x, point.y)
            lineTo(point.x - size, point.y + size * 0.6f)
        }
    }
    drawPath(path, Palette.indigo, style = Stroke(width = 1.8f * scale))
}

/** Kleines Vorschaubild der Linienart für die Legende. */
private fun DrawScope.drawRelationGlyph(kind: UmlRelationKind) {
    val y = size.height / 2
    val effect = if (kind.isDashed) PathEffect.dashPathEffect(floatArrayOf(4f, 3f)) else null
    drawLine(Palette.indigo, Offset(0f, y), Offset(size.width - 10f, y), strokeWidth = 1.6f, pathEffect = effect)

    when (kind) {
        UmlRelationKind.EXTENDS, UmlRelationKind.IMPLEMENTS -> {
            val head = Path().apply {
                moveTo(size.width, y); lineTo(size.width - 10f, y - 5f); lineTo(size.width - 10f, y + 5f); close()
            }
            drawPath(head, Color.White)
            drawPath(head, Palette.indigo, style = Stroke(width = 1.6f))
        }
        UmlRelationKind.AGGREGATION, UmlRelationKind.COMPOSITION -> {
            val head = Path().apply {
                moveTo(size.width, y); lineTo(size.width - 6f, y - 4f)
                lineTo(size.width - 12f, y); lineTo(size.width - 6f, y + 4f); close()
            }
            drawPath(head, if (kind == UmlRelationKind.COMPOSITION) Palette.indigo else Color.White)
            drawPath(head, Palette.indigo, style = Stroke(width = 1.6f))
        }
        UmlRelationKind.ASSOCIATION, UmlRelationKind.DEPENDENCY -> {
            val head = Path().apply {
                moveTo(size.width - 8f, y - 4f); lineTo(size.width, y); lineTo(size.width - 8f, y + 4f)
            }
            drawPath(head, Palette.indigo, style = Stroke(width = 1.6f))
        }
    }
}
