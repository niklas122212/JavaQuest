package app.javaquest.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.Callout
import app.javaquest.core.CalloutKind
import app.javaquest.core.Difficulty

val secondaryText: Color @Composable get() = LocalSurfaces.current.secondaryText

/** Karte mit weichem Schatten – das Grundelement aller Bildschirme. */
@Composable
fun Modifier.card(padding: Dp = 20.dp): Modifier {
    val surfaces = LocalSurfaces.current
    return this
        .shadow(6.dp, RoundedCornerShape(CardRadius), ambientColor = Color.Black.copy(alpha = 0.05f), spotColor = Color.Black.copy(alpha = 0.08f))
        .clip(RoundedCornerShape(CardRadius))
        .background(surfaces.card)
        .padding(padding)
}

/** Klickbar mit Hand-Cursor (Desktop). */
fun Modifier.clickableHand(enabled: Boolean = true, role: Role = Role.Button, onClick: () -> Unit): Modifier =
    this.pointerHoverIcon(if (enabled) PointerIcon.Hand else PointerIcon.Default)
        .clickable(enabled = enabled, role = role, onClick = onClick)

@Composable
fun PrimaryButton(
    text: String,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    brush: Brush = Palette.accent,
    onClick: () -> Unit,
) {
    Row(
        modifier = modifier
            .heightIn(min = 50.dp)
            .alpha(if (enabled) 1f else 0.45f)
            .clip(RoundedCornerShape(16.dp))
            .background(brush)
            .clickableHand(enabled, onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(text, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
fun SecondaryButton(
    text: String,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = Palette.orange,
    trailingIcon: Boolean = false,
    onClick: () -> Unit,
) {
    Row(
        modifier = modifier
            .heightIn(min = 46.dp)
            .alpha(if (enabled) 1f else 0.4f)
            .clip(RoundedCornerShape(14.dp))
            .background(tint.copy(alpha = 0.12f))
            .clickableHand(enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null && !trailingIcon) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
        }
        Text(text, color = tint, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        if (icon != null && trailingIcon) {
            Spacer(Modifier.width(6.dp))
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
fun Chip(text: String, icon: ImageVector? = null, tint: Color = secondaryText) {
    Row(
        Modifier.clip(CircleShape).background(tint.copy(alpha = 0.12f)).padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(5.dp))
        }
        Text(text, color = tint, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

/** „Niveau: Leicht - 2/5“ mit fünf Balken – gut sichtbar auf jeder Aufgabe. */
@Composable
fun DifficultyBadge(difficulty: Difficulty, compact: Boolean = false) {
    val tint = Palette.difficulty(difficulty)
    Row(
        Modifier
            .clip(CircleShape)
            .background(tint.copy(alpha = 0.12f))
            .border(1.dp, tint.copy(alpha = 0.35f), CircleShape)
            .padding(horizontal = if (compact) 8.dp else 12.dp, vertical = if (compact) 4.dp else 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            if (compact) "${difficulty.level}/5" else difficulty.badgeText,
            color = tint,
            fontWeight = FontWeight.Bold,
            fontSize = if (compact) 11.sp else 13.sp,
        )
        Spacer(Modifier.width(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.Bottom) {
            for (level in 1..Difficulty.SCALE_MAXIMUM) {
                Box(
                    Modifier
                        .width(4.dp)
                        .height((5 + level * 2.5f).dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(if (level <= difficulty.level) tint else tint.copy(alpha = 0.25f)),
                )
            }
        }
    }
}

@Composable
fun ProgressBar(value: Double, modifier: Modifier = Modifier, height: Dp = 8.dp, brush: Brush = Palette.accent) {
    val track = LocalSurfaces.current.field
    Box(modifier.fillMaxWidth().height(height).clip(CircleShape).background(track)) {
        Box(Modifier.fillMaxWidth(value.coerceIn(0.0, 1.0).toFloat()).height(height).clip(CircleShape).background(brush))
    }
}

@Composable
fun ProgressRing(progress: Double, modifier: Modifier = Modifier, lineWidth: Dp = 14.dp, brush: Brush = Palette.hero, track: Color? = null) {
    val trackColor = track ?: LocalSurfaces.current.field
    Canvas(modifier) {
        val stroke = lineWidth.toPx()
        val inset = stroke / 2
        val arcSize = Size(size.width - stroke, size.height - stroke)
        drawArc(trackColor, 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke))
        drawArc(brush, -90f, (360 * progress.coerceIn(0.0, 1.0)).toFloat(), false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
    }
}

@Composable
fun IconTile(icon: ImageVector, tint: Color, size: Dp = 40.dp) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(size * 0.28f)).background(Brush.linearGradient(listOf(tint, tint.copy(alpha = 0.72f)))),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = Color.White, modifier = Modifier.size(size * 0.52f))
    }
}

@Composable
fun SectionTitle(title: String, subtitle: String? = null, icon: ImageVector? = null, trailing: @Composable RowScope.() -> Unit = {}) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (icon != null) {
                    Icon(icon, null, tint = Palette.orange, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                }
                Text(title, fontSize = 19.sp, fontWeight = FontWeight.Bold)
            }
            if (subtitle != null) Text(subtitle, fontSize = 13.sp, color = secondaryText)
        }
        trailing()
    }
}

@Composable
fun CalloutBox(callout: Callout) {
    val (tint, icon, title) = when (callout.kind) {
        CalloutKind.TIP -> Triple(Palette.success, Icons.Rounded.Lightbulb, "Tipp")
        CalloutKind.WARNING -> Triple(Palette.orange, Icons.Rounded.Warning, "Achtung")
        CalloutKind.INFO -> Triple(Palette.indigo, Icons.Rounded.Info, "Gut zu wissen")
    }
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(InnerRadius))
            .background(tint.copy(alpha = 0.1f))
            .border(1.dp, tint.copy(alpha = 0.3f), RoundedCornerShape(InnerRadius))
            .padding(14.dp),
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(12.dp))
        Column {
            Text(title, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Text(callout.text, fontSize = 15.sp)
        }
    }
}

@Composable
fun StarRow(stars: Int, size: Dp = 34.dp) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (i in 1..3) {
            Icon(
                if (i <= stars) Icons.Rounded.Star else Icons.Rounded.StarBorder,
                contentDescription = null,
                tint = if (i <= stars) Color(0xFFFFCC00) else secondaryText.copy(alpha = 0.5f),
                modifier = Modifier.size(size),
            )
        }
    }
}

@Composable
fun Eyebrow(text: String, color: Color = Palette.orange) {
    Text(text.uppercase(), color = color, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 1.4.sp)
}

@Composable
fun StatTile(icon: ImageVector, tint: Color, value: String, label: String, modifier: Modifier = Modifier) {
    Column(modifier.card(16.dp)) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp))
        Spacer(Modifier.height(10.dp))
        Text(value, fontSize = 26.sp, fontWeight = FontWeight.Bold)
        Text(label, fontSize = 13.sp, color = secondaryText, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Kleiner Verlaufsgraph (Sparkline) für den Score-Verlauf. */
@Composable
fun Sparkline(values: List<Int>, modifier: Modifier = Modifier, color: Color = Color.White) {
    Canvas(modifier) {
        if (values.size < 2) return@Canvas
        val max = maxOf(values.max(), 1).toFloat()
        val step = size.width / (values.size - 1)
        var previous: Offset? = null
        values.forEachIndexed { i, v ->
            val point = Offset(i * step, size.height - (v / max) * size.height)
            previous?.let { drawLine(SolidColor(color), it, point, strokeWidth = 3f, cap = StrokeCap.Round) }
            previous = point
        }
    }
}
