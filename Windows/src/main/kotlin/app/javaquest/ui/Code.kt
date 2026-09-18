package app.javaquest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.automirrored.rounded.ManageSearch
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.core.ExplainedLine
import app.javaquest.core.GlossaryEntry
import app.javaquest.core.JavaHighlighter
import kotlinx.coroutines.launch

/** Java-Code mit Syntaxfarben. */
fun highlighted(code: String): AnnotatedString = buildAnnotatedString {
    for (token in JavaHighlighter.tokenize(code)) {
        withStyle(SpanStyle(color = CodeColors.token(token.kind))) { append(token.text) }
    }
}

private val placeholderRegex = Regex("""\{\{(\d+)}}""")

/** Eine Zeile des Lückentexts mit den aktuellen Eingaben (grün/rot nach dem Prüfen). */
fun fillBlankLine(line: String, values: List<String>, states: List<Boolean>?): AnnotatedString = buildAnnotatedString {
    var last = 0
    for (match in placeholderRegex.findAll(line)) {
        append(highlighted(line.substring(last, match.range.first)))
        val index = match.groupValues[1].toInt()
        val value = values.getOrElse(index) { "" }.trim()
        val tint = when (states?.getOrNull(index)) {
            true -> Palette.success
            false -> Palette.ember
            null -> Palette.orange
        }
        withStyle(SpanStyle(color = if (value.isEmpty()) tint else Color.White, background = tint.copy(alpha = if (value.isEmpty()) 0.25f else 0.55f), fontWeight = FontWeight.SemiBold)) {
            append(if (value.isEmpty()) " ${index + 1} " else " $value ")
        }
        last = match.range.last + 1
    }
    append(highlighted(line.substring(last)))
}

/** Lesbare Vorschau einer Zeile: Platzhalter {{0}} werden zu [Lücke 1]. */
fun readableLine(code: String): String = placeholderRegex.replace(code.trim()) { "[Lücke ${it.groupValues[1].toInt() + 1}]" }

@Composable
private fun EditorChrome(caption: String, hint: Boolean, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(InnerRadius)).background(CodeColors.background)) {
        Row(
            Modifier.fillMaxWidth().background(CodeColors.chrome).padding(horizontal = 14.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            listOf(Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)).forEach {
                Box(Modifier.padding(end = 6.dp).size(10.dp).clip(CircleShape).background(it.copy(alpha = 0.85f)))
            }
            Spacer(Modifier.weight(1f))
            if (hint) {
                Icon(Icons.Rounded.TouchApp, null, tint = CodeColors.plain.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text("Zeile anklicken", color = CodeColors.plain.copy(alpha = 0.5f), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.width(10.dp))
            }
            Text(caption, color = CodeColors.plain.copy(alpha = 0.45f), fontSize = 11.sp, fontFamily = CodeFont, fontWeight = FontWeight.SemiBold)
        }
        content()
    }
}

/** Code ohne Erklärungen (Einstufungstest, Konsolenausgabe). */
@Composable
fun CodeBlock(text: AnnotatedString, caption: String = "Java") {
    EditorChrome(caption, hint = false) {
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            Text(
                text,
                fontFamily = CodeFont,
                fontSize = 14.sp,
                lineHeight = 22.sp,
                softWrap = false,
                modifier = Modifier.horizontalScroll(rememberScrollState()).widthIn(min = maxWidth).padding(14.dp),
            )
        }
    }
}

enum class Presentation(val title: String) { STEPS("Schritt für Schritt"), ALL("Alle Zeilen") }

/**
 * Code-Exegese: oben der Code mit nummerierten, anklickbaren Zeilen, darunter die Erklärung jeder
 * Zeile in Alltagssprache. Die gewählte Zeile ist im Code und in der Erklärung markiert.
 */
@Composable
fun CodeExegesis(
    lines: List<ExplainedLine>,
    caption: String = "Java",
    initialPresentation: Presentation? = Presentation.ALL,
    hiddenLines: Set<Int> = emptySet(),
    render: ((ExplainedLine) -> AnnotatedString)? = null,
) {
    val codeLines = remember(lines) { lines.filter { it.code.isNotBlank() } }
    var selected by remember { mutableStateOf(if (initialPresentation != null) codeLines.firstOrNull()?.number else null) }
    var presentation by remember { mutableStateOf(initialPresentation) }
    val requesters = remember(lines) { codeLines.associate { it.number to BringIntoViewRequester() } }
    val scope = rememberCoroutineScope()

    // Nach dem Lösen klappt die komplette Zerlegung auf.
    LaunchedEffect(initialPresentation) {
        if (initialPresentation != null) {
            presentation = initialPresentation
            if (selected == null) selected = codeLines.firstOrNull()?.number
        }
    }

    fun select(number: Int, scroll: Boolean) {
        selected = number
        if (presentation == null) presentation = Presentation.STEPS
        if (scroll && presentation == Presentation.ALL) scope.launch { requesters[number]?.bringIntoView() }
    }

    // Alle Zeilen inklusive Leerzeilen, die der Erklärer überspringt.
    val byNumber = lines.associateBy { it.number }
    val displayLines = (1..(lines.maxOfOrNull { it.number } ?: 0)).map { byNumber[it] ?: ExplainedLine(it, "", "", emptyList()) }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        EditorChrome(caption, hint = true) {
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                Column(
                    Modifier
                        .horizontalScroll(rememberScrollState())
                        .widthIn(min = maxWidth)
                        .width(IntrinsicSize.Max)
                        .padding(vertical = 8.dp),
                ) {
                    for (line in displayLines) {
                        val isEmpty = line.code.isBlank()
                        val isSelected = line.number == selected
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .background(if (isSelected) Palette.orange.copy(alpha = 0.24f) else Color.Transparent)
                                .then(if (isEmpty) Modifier else Modifier.clickableHand { select(line.number, scroll = true) })
                                .testTag("code-line-${line.number}")
                                .semantics { contentDescription = "Zeile ${line.number}: ${line.code.trim()}" },
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(Modifier.width(3.dp).height(24.dp).background(if (isSelected) Palette.orange else Color.Transparent))
                            Text(
                                "${line.number}",
                                color = if (isSelected) Palette.orange else CodeColors.plain.copy(alpha = 0.35f),
                                fontFamily = CodeFont,
                                fontSize = 12.sp,
                                modifier = Modifier.width(34.dp).padding(end = 10.dp),
                                textAlign = androidx.compose.ui.text.style.TextAlign.End,
                            )
                            Text(
                                render?.invoke(line) ?: highlighted(line.code.ifEmpty { " " }),
                                fontFamily = CodeFont,
                                fontSize = 14.sp,
                                softWrap = false,
                                modifier = Modifier.padding(vertical = 2.dp).padding(end = 16.dp),
                            )
                        }
                    }
                }
            }
        }

        val current = presentation
        if (current == null) {
            SecondaryButton("Code Zeile für Zeile erklären", Icons.AutoMirrored.Rounded.ManageSearch, Modifier.fillMaxWidth()) {
                presentation = Presentation.STEPS
                selected = codeLines.firstOrNull()?.number
            }
        } else {
            SegmentedControl(Presentation.entries, current, { it.title }) { presentation = it }
            when (current) {
                Presentation.STEPS -> {
                    val index = codeLines.indexOfFirst { it.number == selected }
                    if (index >= 0) {
                        val line = codeLines[index]
                        ExplanationRow(line, isSelected = true, isHidden = line.number in hiddenLines, showsTerms = true)
                        if (codeLines.size > 1) {
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                                SecondaryButton("Vorige", Icons.AutoMirrored.Rounded.KeyboardArrowLeft, Modifier.weight(1f), enabled = index > 0) {
                                    select(codeLines[index - 1].number, scroll = false)
                                }
                                Text("${index + 1} / ${codeLines.size}", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = secondaryText)
                                SecondaryButton(
                                    "Nächste", Icons.AutoMirrored.Rounded.KeyboardArrowRight, Modifier.weight(1f),
                                    enabled = index + 1 < codeLines.size, trailingIcon = true,
                                ) { select(codeLines[index + 1].number, scroll = false) }
                            }
                        }
                    }
                }
                Presentation.ALL -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (line in codeLines) {
                        Box(Modifier.bringIntoViewRequester(requesters.getValue(line.number))) {
                            ExplanationRow(
                                line,
                                isSelected = line.number == selected,
                                isHidden = line.number in hiddenLines,
                                showsTerms = line.number == selected,
                                onClick = { select(line.number, scroll = false) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun <T> SegmentedControl(options: List<T>, selected: T, label: (T) -> String, onSelect: (T) -> Unit) {
    val surfaces = LocalSurfaces.current
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(surfaces.field).padding(3.dp)) {
        for (option in options) {
            val isSelected = option == selected
            Box(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isSelected) surfaces.card else Color.Transparent)
                    .clickableHand { onSelect(option) }
                    .padding(vertical = 7.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(label(option), fontSize = 14.sp, fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal)
            }
        }
    }
}

/** Eine erklärte Zeile: Nummer, Code, Erklärung, bei der markierten Zeile die Befehle. */
@Composable
fun ExplanationRow(line: ExplainedLine, isSelected: Boolean, isHidden: Boolean, showsTerms: Boolean, onClick: (() -> Unit)? = null) {
    val surfaces = LocalSurfaces.current
    val shape = RoundedCornerShape(12.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(if (isSelected) Palette.orange.copy(alpha = 0.1f) else surfaces.field)
            .border(1.5.dp, if (isSelected) Palette.orange.copy(alpha = 0.8f) else Color.Transparent, shape)
            .then(if (onClick != null) Modifier.clickableHand(onClick = onClick) else Modifier)
            .padding(12.dp)
            .testTag("explanation-${line.number}"),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(24.dp).clip(CircleShape).background(if (isSelected) Palette.orange else secondaryText.copy(alpha = 0.55f)),
                contentAlignment = Alignment.Center,
            ) {
                Text("${line.number}", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.width(8.dp))
            Text(readableLine(line.code), fontFamily = CodeFont, fontSize = 13.sp, color = secondaryText, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (isHidden) {
            Row(verticalAlignment = Alignment.Top) {
                Icon(Icons.Rounded.Lock, null, tint = secondaryText, modifier = Modifier.size(16.dp).padding(top = 2.dp))
                Spacer(Modifier.width(6.dp))
                Text("Hier steckt eine Lücke – die ganze Erklärung erscheint, sobald du die Aufgabe gelöst hast.", color = secondaryText, fontSize = 15.sp)
            }
            // Die übrigen Befehle der Zeile verraten die Lösung nicht.
            if (showsTerms && line.terms.isNotEmpty()) TermList(line.terms)
        } else {
            Text(line.explanation, fontSize = 16.sp, lineHeight = 23.sp)
            if (showsTerms && line.terms.isNotEmpty()) TermList(line.terms)
        }
    }
}

@Composable
fun TermList(terms: List<GlossaryEntry>) {
    val surfaces = LocalSurfaces.current
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(surfaces.card).padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text("BEFEHLE IN DIESER ZEILE", color = Palette.orange, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.6.sp)
        for (term in terms) {
            Row(verticalAlignment = Alignment.Top) {
                Text(
                    term.term,
                    fontFamily = CodeFont,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    color = Palette.indigo,
                    modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(Palette.indigo.copy(alpha = 0.1f)).padding(horizontal = 6.dp, vertical = 2.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(term.meaning, fontSize = 13.sp, color = secondaryText)
            }
        }
    }
}
