package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.CodeEditing
import app.javaquest.core.CodeQuality
import app.javaquest.core.JavaHighlighter
import app.javaquest.core.JavaSource
import app.javaquest.core.QualityFinding
import app.javaquest.core.interpreter.JavaProblem
import app.javaquest.core.interpreter.JavaRunner
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/** Ein Stück Code, das der Editor an der Cursorstelle einfügen soll (Bauplan); [id] macht jede Bitte eindeutig. */
data class EditorInsertion(val id: Int, val snippet: String)

/**
 * Bildschirmtastatur für Code (Android): keine Autokorrektur, kein Großbuchstabe am Anfang –
 * sonst wird aus `int` ein „Int“ und aus `System.out` ein Vorschlag. Am Desktop ohne Wirkung.
 */
internal val CodeTastatur = KeyboardOptions(
    capitalization = KeyboardCapitalization.None,
    autoCorrectEnabled = false,
    keyboardType = KeyboardType.Ascii,
)

private class EditorMark(val line: Int, val isError: Boolean)

private class Lint(val problem: JavaProblem?, val hints: List<QualityFinding>)

/**
 * Der Code-Editor – wie in der Apple-App: Zeilennummern, Syntaxfarben beim Tippen, automatische Einrückung,
 * Klammerpaare, Tab als vier Leerzeichen und ein Compiler, der mitliest (Fehlerzeile rot, Namenshinweise gelb).
 * Auf Touch-Geräten steht unter dem Editor eine Leiste mit den Zeichen, die auf der Tastatur tief versteckt sind.
 *
 * Mit [isJava] = false bleibt es ein schlichtes Textfeld (für Ausgaben, die man vorhersagt).
 */
@Composable
fun CodeEditor(
    text: String,
    placeholder: String,
    minHeight: Dp,
    isLocked: Boolean,
    tag: String,
    /** Cursor nach einer Änderung von außen (z. B. Einfügen aus der Befehlsleiste); sonst ans Ende. */
    cursor: Int? = null,
    /** Meldet, wo geschrieben wird – auch wenn nur der Cursor wandert. */
    onCursor: ((Int) -> Unit)? = null,
    isJava: Boolean = true,
    /** Zeile, an der ein Lauf gescheitert ist (Absturz, Test). */
    errorLine: Int? = null,
    /** Unter dem Editor zeigen, was der Compiler beim Tippen findet. */
    showsLint: Boolean = false,
    insertion: EditorInsertion? = null,
    onChange: (String) -> Unit,
) {
    var value by remember { mutableStateOf(TextFieldValue(text, TextRange(text.length))) }
    var layout by remember { mutableStateOf<TextLayoutResult?>(null) }
    var lint by remember { mutableStateOf<Lint?>(null) }
    var focused by remember { mutableStateOf(false) }

    LaunchedEffect(text) {
        if (value.text != text) value = TextFieldValue(text, TextRange((cursor ?: text.length).coerceIn(0, text.length)))
    }

    fun apply(next: TextFieldValue) {
        val old = value
        value = next
        onCursor?.invoke(next.selection.max)
        if (next.text != old.text) onChange(next.text)
    }

    fun applyEdit(edit: CodeEditing.Edit) = apply(TextFieldValue(edit.applyTo(value.text), TextRange(edit.cursor)))

    /** Eingabe über die Regeln des Editors – für Tab und die Zeichenleiste. */
    fun type(input: String) {
        if (isLocked) return
        val edit = CodeEditing.edit(input, value.text, value.selection.min, value.selection.max)
            ?: CodeEditing.Edit(value.selection.min, value.selection.max, input, value.selection.min + input.length)
        applyEdit(edit)
    }

    LaunchedEffect(insertion?.id) {
        val request = insertion ?: return@LaunchedEffect
        applyEdit(CodeEditing.insertion(request.snippet, value.text, value.selection.min, value.selection.max))
    }

    if (isJava && showsLint) {
        LaunchedEffect(value.text) {
            // Der Compiler liest mit – kurz nach der letzten Taste, nicht bei jedem Buchstaben.
            delay(350)
            val source = JavaSource.normalizingTypography(value.text)
            lint = withContext(Dispatchers.Default) {
                val problem = JavaRunner.check(source)
                Lint(problem, if (problem == null) CodeQuality.naming(source) else emptyList())
            }
        }
    }

    val marks = buildList {
        lint?.problem?.line?.let { add(EditorMark(it, true)) }
        errorLine?.let { add(EditorMark(it, true)) }
        lint?.hints?.forEach { hint -> hint.line?.let { add(EditorMark(it, false)) } }
    }
    val errorLines = marks.filter { it.isError }.map { it.line }.toSet()
    val transformation = remember(isJava, marks.map { it.line to it.isError }) {
        if (isJava) JavaHighlighting(marks) else VisualTransformation.None
    }
    val style = TextStyle(fontFamily = CodeFont, fontSize = 15.sp, color = CodeColors.plain, lineHeight = 22.sp)
    val touch = LocalPlattform.current.touch

    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(InnerRadius)).background(CodeColors.background)) {
        BasicTextField(
            value = value,
            onValueChange = { new -> apply(if (isJava && !isLocked) smartEdit(value, new) ?: new else new) },
            readOnly = isLocked,
            keyboardOptions = CodeTastatur,
            textStyle = style,
            cursorBrush = SolidColor(Palette.orange),
            visualTransformation = transformation,
            onTextLayout = { layout = it },
            modifier = Modifier.fillMaxWidth().heightIn(min = minHeight).testTag(tag)
                .onFocusChanged { focused = it.isFocused }
                .onPreviewKeyEvent { event ->
                    if (!isLocked && event.type == KeyEventType.KeyDown && event.key == Key.Tab && !event.isShiftPressed) {
                        type("\t")
                        true
                    } else {
                        false
                    }
                },
            decorationBox = { inner ->
                Row(Modifier.padding(vertical = 12.dp)) {
                    if (isJava) LineNumbers(value.text, { layout }, errorLines)
                    Box(Modifier.weight(1f).padding(start = if (isJava) 8.dp else 14.dp, end = 14.dp)) {
                        if (value.text.isEmpty()) Text(placeholder, style = style.copy(color = CodeColors.plain.copy(alpha = 0.35f)))
                        inner()
                    }
                }
            },
        )
        if (isJava && touch && focused && !isLocked) SymbolBar(::type)
        if (isJava && showsLint && !isLocked) LintBar(lint)
    }
}

/** Ein einzelnes getipptes Zeichen über die Regeln aus CodeEditing – Einfügen und Tastatur-Vorschläge bleiben, wie sie sind. */
private fun smartEdit(old: TextFieldValue, new: TextFieldValue): TextFieldValue? {
    if (old.composition != null || new.composition != null) return null
    val start = old.selection.min
    val end = old.selection.max
    if (new.text.length != old.text.length - (end - start) + 1 || !new.selection.collapsed || new.selection.start != start + 1) return null
    val inserted = new.text.substring(start, start + 1)
    if (new.text != old.text.substring(0, start) + inserted + old.text.substring(end)) return null
    val edit = CodeEditing.edit(inserted, old.text, start, end) ?: return null
    return TextFieldValue(edit.applyTo(old.text), TextRange(edit.cursor))
}

/**
 * Zeilennummern neben dem Text – auch bei umbrochenen Zeilen an der richtigen Stelle. Das Text-Layout wird erst
 * beim Platzieren gelesen: Dann ist es schon das dieses Frames, und die Nummern hinken dem Text nicht hinterher.
 */
@Composable
private fun LineNumbers(text: String, layout: () -> TextLayoutResult?, errorLines: Set<Int>) {
    val starts = remember(text) {
        buildList {
            add(0)
            text.forEachIndexed { index, c -> if (c == '\n') add(index + 1) }
        }
    }
    Box(Modifier.width(38.dp)) {
        starts.forEachIndexed { index, start ->
            val number = index + 1
            Text(
                "$number",
                fontFamily = CodeFont,
                fontSize = 12.sp,
                lineHeight = 22.sp,
                color = if (number in errorLines) Palette.ember else CodeColors.plain.copy(alpha = 0.32f),
                fontWeight = if (number in errorLines) FontWeight.Bold else FontWeight.Normal,
                modifier = Modifier.width(30.dp).offset {
                    val result = layout()?.takeIf { it.layoutInput.text.text == text }
                    val top = result?.let { it.getLineTop(it.getLineForOffset(start.coerceAtMost(it.layoutInput.text.length))) }
                        ?: (index * 22.sp.toPx())
                    IntOffset(0, top.roundToInt())
                },
                textAlign = androidx.compose.ui.text.style.TextAlign.End,
            )
        }
    }
}

/** Färbt Java-Code ein und markiert Fehlerzeilen (rot) und Hinweiszeilen (gelb unterstrichen). */
private class JavaHighlighting(private val marks: List<EditorMark>) : VisualTransformation {
    override fun filter(text: AnnotatedString): TransformedText {
        val raw = text.text
        val lineStarts = buildList { add(0); raw.forEachIndexed { i, c -> if (c == '\n') add(i + 1) } }
        val colored = buildAnnotatedString {
            for (token in JavaHighlighter.tokenize(raw)) {
                withStyle(SpanStyle(color = CodeColors.token(token.kind))) { append(token.text) }
            }
            for (mark in marks) {
                val start = lineStarts.getOrNull(mark.line - 1) ?: continue
                val end = lineStarts.getOrNull(mark.line)?.minus(1) ?: raw.length
                if (end <= start) continue
                addStyle(
                    if (mark.isError) SpanStyle(background = Palette.ember.copy(alpha = 0.3f))
                    else SpanStyle(textDecoration = TextDecoration.Underline, color = Color(0xFFFFE08A)),
                    start, end,
                )
            }
        }
        return TransformedText(colored, OffsetMapping.Identity)
    }

    override fun equals(other: Any?) = other is JavaHighlighting && other.marks.map { it.line to it.isError } == marks.map { it.line to it.isError }
    override fun hashCode() = marks.map { it.line to it.isError }.hashCode()
}

/** Die Zeichen, die auf der Handy-Tastatur tief versteckt sind. Tippen nimmt dem Editor den Fokus nicht. */
@Composable
private fun SymbolBar(type: (String) -> Unit) {
    val symbols = listOf("⇥", "{", "}", "(", ")", ";", "\"", "=", "+", "-", "<", ">", "[", "]", "!", "&&", "||", ".", ",", "*", "/", "%", "'")
    Row(
        Modifier.fillMaxWidth().background(CodeColors.chrome).horizontalScroll(rememberScrollState()).padding(horizontal = 8.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        for (symbol in symbols) {
            Box(
                Modifier.clip(RoundedCornerShape(8.dp)).background(Color.White.copy(alpha = 0.12f))
                    .focusProperties { canFocus = false }
                    .clickableHand { type(if (symbol == "⇥") "\t" else symbol) }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
                    .testTag("symbol-$symbol"),
                contentAlignment = Alignment.Center,
            ) {
                Text(symbol, fontFamily = CodeFont, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
            }
        }
    }
}

/** Was der Compiler beim Tippen findet – oder dass alles übersetzt. */
@Composable
private fun LintBar(lint: Lint?) {
    val problem = lint?.problem
    val hint = lint?.hints?.firstOrNull()
    val (icon, tint, message) = when {
        problem != null -> Triple(Icons.Rounded.Cancel, Palette.ember, (problem.line?.let { "Zeile $it: " } ?: "") + problem.message)
        hint != null -> Triple(Icons.Rounded.Lightbulb, Color(0xFFFFD54F), hint.message)
        else -> Triple(Icons.Rounded.CheckCircle, Palette.success, if (lint == null) "Der Compiler liest mit …" else "Übersetzt ohne Fehler")
    }
    Row(
        Modifier.fillMaxWidth().background(CodeColors.chrome).padding(horizontal = 12.dp, vertical = 8.dp).testTag("lint"),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp).padding(top = 2.dp))
        Spacer(Modifier.width(8.dp))
        Text(message, fontFamily = CodeFont, fontSize = 12.sp, color = if (problem == null && hint == null) CodeColors.plain.copy(alpha = 0.55f) else CodeColors.plain)
    }
}
