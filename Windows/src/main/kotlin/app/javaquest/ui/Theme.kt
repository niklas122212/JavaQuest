package app.javaquest.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.CallSplit
import androidx.compose.material.icons.automirrored.rounded.ListAlt
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.AccountTree
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Calculate
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Code
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.DataArray
import androidx.compose.material.icons.rounded.DataObject
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material.icons.rounded.Functions
import androidx.compose.material.icons.automirrored.rounded.HelpOutline
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.Spa
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material.icons.rounded.ViewInAr
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.material.icons.rounded.AllInbox
import androidx.compose.material.icons.rounded.AllInclusive
import androidx.compose.material.icons.rounded.Balance
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Category
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Extension
import androidx.compose.material.icons.rounded.FormatListNumbered
import androidx.compose.material.icons.rounded.Handyman
import androidx.compose.material.icons.rounded.Hub
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.Storage
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.Loop
import androidx.compose.material.icons.rounded.Memory
import androidx.compose.material.icons.rounded.SportsScore
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.platform.SystemFont
import androidx.compose.ui.unit.dp
import app.javaquest.core.Difficulty
import app.javaquest.core.ExperienceLevel
import app.javaquest.core.JavaHighlighter
import app.javaquest.core.TaskType
import app.javaquest.core.TopicStatus

/** Farben, Verläufe und Maße – dieselbe Gestaltung wie in der iOS-App. */
object Palette {
    val orange = Color(0xFFF57321)
    val ember = Color(0xFFE8424D)
    val indigo = Color(0xFF544FE6)
    val violet = Color(0xFF8F57ED)
    val teal = Color(0xFF14A39E)
    val success = Color(0xFF2EAD61)
    val gray = Color(0xFF8E8E93)

    val hero = Brush.linearGradient(listOf(indigo, violet, orange))
    val accent = Brush.linearGradient(listOf(orange, ember))
    val successGradient = Brush.linearGradient(listOf(success, teal))
    val placement = Brush.linearGradient(listOf(indigo, violet))

    fun difficulty(d: Difficulty) = when (d) {
        Difficulty.VERY_EASY -> teal
        Difficulty.EASY -> success
        Difficulty.MEDIUM -> indigo
        Difficulty.DEMANDING -> orange
        Difficulty.HARD -> ember
    }

    fun status(s: TopicStatus) = when (s) {
        TopicStatus.STRENGTH -> success
        TopicStatus.DEVELOPING -> indigo
        TopicStatus.GAP -> orange
        TopicStatus.UNKNOWN -> gray
    }

    fun tier(level: ExperienceLevel) = when (level) {
        ExperienceLevel.BEGINNER -> success
        ExperienceLevel.INTERMEDIATE -> indigo
        ExperienceLevel.ADVANCED -> ember
    }
}

val CardRadius = 22.dp
val InnerRadius = 14.dp

/** Flächenfarben je Erscheinungsbild. */
@Immutable
data class Surfaces(val screen: Color, val card: Color, val field: Color, val divider: Color, val secondaryText: Color)

val LocalSurfaces = staticCompositionLocalOf {
    Surfaces(Color(0xFFF2F2F7), Color.White, Color(0x1F767680), Color(0x1F000000), Color(0xFF6C6C70))
}

/** Code wird immer auf dunklem Grund gezeigt – wie in einem Editor. */
object CodeColors {
    val background = Color(0xFF1C1F29)
    val chrome = Color(0xFF262936)
    val plain = Color(0xFFEBEBEB)

    fun token(kind: JavaHighlighter.Kind) = when (kind) {
        JavaHighlighter.Kind.PLAIN -> plain
        JavaHighlighter.Kind.KEYWORD -> Color(0xFFFF7AB3)
        JavaHighlighter.Kind.TYPE -> Color(0xFF5CD9DE)
        JavaHighlighter.Kind.STRING -> Color(0xFFFC876E)
        JavaHighlighter.Kind.NUMBER -> Color(0xFFD9C978)
        JavaHighlighter.Kind.COMMENT -> Color(0xFF808C9E)
        JavaHighlighter.Kind.ANNOTATION -> Color(0xFFFC9E4D)
    }
}

/** Monospace-Schrift: Consolas unter Windows, Menlo auf dem Mac. */
@OptIn(ExperimentalTextApi::class)
val CodeFont: FontFamily by lazy {
    val os = System.getProperty("os.name").lowercase()
    when {
        "win" in os -> FontFamily(SystemFont("Consolas"))
        "mac" in os -> FontFamily(SystemFont("Menlo"))
        else -> FontFamily.Monospace
    }
}

private val lightScheme: ColorScheme = lightColorScheme(
    primary = Palette.orange,
    onPrimary = Color.White,
    secondary = Palette.indigo,
    background = Color(0xFFF2F2F7),
    surface = Color.White,
    onSurface = Color(0xFF1C1C1E),
    onBackground = Color(0xFF1C1C1E),
    surfaceVariant = Color(0xFFE9E9EE),
    onSurfaceVariant = Color(0xFF6C6C70),
)

private val darkScheme: ColorScheme = darkColorScheme(
    primary = Palette.orange,
    onPrimary = Color.White,
    secondary = Color(0xFF8C88FF),
    background = Color(0xFF000000),
    surface = Color(0xFF1C1C1E),
    onSurface = Color(0xFFF2F2F7),
    onBackground = Color(0xFFF2F2F7),
    surfaceVariant = Color(0xFF2C2C2E),
    onSurfaceVariant = Color(0xFFAEAEB2),
)

@Composable
fun JavaQuestTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val surfaces = if (dark) {
        Surfaces(Color(0xFF000000), Color(0xFF1C1C1E), Color(0x3D767680), Color(0x33FFFFFF), Color(0xFFAEAEB2))
    } else {
        Surfaces(Color(0xFFF2F2F7), Color.White, Color(0x1F767680), Color(0x1F000000), Color(0xFF6C6C70))
    }
    androidx.compose.runtime.CompositionLocalProvider(LocalSurfaces provides surfaces) {
        MaterialTheme(colorScheme = if (dark) darkScheme else lightScheme, content = content)
    }
}

/** SF-Symbol-Namen aus dem Kurs → passende Material-Symbole. */
fun symbolIcon(symbol: String): ImageVector = when (symbol) {
    "curlybraces" -> Icons.Rounded.DataObject
    "shippingbox.fill" -> Icons.Rounded.Inventory2
    "plus.forwardslash.minus" -> Icons.Rounded.Calculate
    "arrow.triangle.branch" -> Icons.AutoMirrored.Rounded.CallSplit
    "repeat" -> Icons.Rounded.Repeat
    "function" -> Icons.Rounded.Functions
    "square.grid.3x1.below.line.grid.1x2" -> Icons.Rounded.DataArray
    "textformat" -> Icons.Rounded.TextFields
    "cube.fill" -> Icons.Rounded.ViewInAr
    "rectangle.connected.to.line.below" -> Icons.Rounded.AccountTree
    "exclamationmark.triangle.fill" -> Icons.Rounded.Warning
    "tray.full.fill" -> Icons.Rounded.AllInbox
    "chevron.left.forwardslash.chevron.right" -> Icons.Rounded.Code
    "wand.and.stars", "sparkles" -> Icons.Rounded.AutoAwesome
    "leaf.fill" -> Icons.Rounded.Spa
    "shield.lefthalf.filled" -> Icons.Rounded.Shield
    "list.number" -> Icons.Rounded.FormatListNumbered
    "equal.circle" -> Icons.Rounded.Balance
    "doc.text" -> Icons.Rounded.Description
    "calendar" -> Icons.Rounded.CalendarMonth
    "arrow.triangle.2.circlepath" -> Icons.Rounded.Loop
    "arrow.up.arrow.down" -> Icons.Rounded.SwapVert
    "square.stack.3d.up" -> Icons.Rounded.Layers
    "checkmark.seal" -> Icons.Rounded.Verified
    "hammer", "hammer.fill" -> Icons.Rounded.Handyman
    "cpu" -> Icons.Rounded.Memory
    "puzzlepiece" -> Icons.Rounded.Extension
    "flag.checkered" -> Icons.Rounded.SportsScore
    "cube.transparent" -> Icons.Rounded.Category
    "infinity" -> Icons.Rounded.AllInclusive
    "square.on.square" -> Icons.Rounded.Dashboard
    "arrow.triangle.pull" -> Icons.Rounded.AccountTree
    "network" -> Icons.Rounded.Hub
    "curlybraces.square" -> Icons.Rounded.DataObject
    "globe" -> Icons.Rounded.Public
    "cylinder.split.1x2" -> Icons.Rounded.Storage
    else -> Icons.Rounded.Widgets
}

fun taskTypeIcon(type: TaskType): ImageVector = when (type) {
    TaskType.SINGLE_CHOICE -> Icons.AutoMirrored.Rounded.ListAlt
    TaskType.FILL_BLANK -> Icons.Rounded.EditNote
    TaskType.PREDICT_OUTPUT -> Icons.Rounded.Terminal
    TaskType.CODE -> Icons.Rounded.Code
}

fun statusIcon(status: TopicStatus): ImageVector = when (status) {
    TopicStatus.STRENGTH -> Icons.Rounded.CheckCircle
    TopicStatus.DEVELOPING -> Icons.AutoMirrored.Rounded.TrendingUp
    TopicStatus.GAP -> Icons.Rounded.Warning
    TopicStatus.UNKNOWN -> Icons.AutoMirrored.Rounded.HelpOutline
}

fun levelIcon(level: ExperienceLevel): ImageVector = when (level) {
    ExperienceLevel.BEGINNER -> Icons.Rounded.Spa
    ExperienceLevel.INTERMEDIATE -> Icons.Rounded.Whatshot
    ExperienceLevel.ADVANCED -> Icons.Rounded.AutoAwesome
}

/** Beherrschung als ganze Prozentzahl – abgerundet, damit 54,6 % nicht als „55 %“ erscheint. */
val Double.masteryPercent: Int get() = kotlin.math.floor(this * 100).toInt()
