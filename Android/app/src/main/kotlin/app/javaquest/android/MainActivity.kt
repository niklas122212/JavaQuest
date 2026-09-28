package app.javaquest.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Coffee
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.javaquest.ui.AppShell
import app.javaquest.ui.JavaQuestTheme
import app.javaquest.ui.LocalPlattform
import app.javaquest.ui.LocalSurfaces
import app.javaquest.ui.Palette
import app.javaquest.ui.PrimaryButton
import app.javaquest.ui.secondaryText
import kotlinx.coroutines.launch

/** Einziger Bildschirm der App – alles Weitere zeichnet die gemeinsame Compose-Oberfläche. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Randlos: Die Oberfläche hält Status- und Gestenleiste selbst frei (safeDrawing in AppShell).
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val plattform = AndroidPlattform(this, Sitzung.lernstandDatei(this))
        setContent {
            JavaQuestTheme {
                CompositionLocalProvider(LocalPlattform provides plattform) {
                    val zustand = Sitzung.zustand
                    val fehler = Sitzung.fehler
                    LaunchedEffect(Unit) { Sitzung.laden(this@MainActivity) }
                    when {
                        zustand != null -> {
                            // Zurück: Lektion schließen, dann zur Übersicht – erst dort beendet es die App.
                            BackHandler(enabled = zustand.kannZurueck) { zustand.zurueck() }
                            AppShell(zustand)
                        }
                        fehler != null -> Ladefehler(fehler)
                        else -> Startbild()
                    }
                }
            }
        }
    }
}

@Composable
private fun Startbild() {
    Box(Modifier.fillMaxSize().background(LocalSurfaces.current.screen), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Box(
                Modifier.size(96.dp).clip(RoundedCornerShape(26.dp)).background(Palette.hero),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Coffee, null, tint = Color.White, modifier = Modifier.size(48.dp)) }
            CircularProgressIndicator(color = Palette.orange, strokeWidth = 3.dp, modifier = Modifier.size(28.dp))
        }
    }
}

@Composable
private fun Ladefehler(fehler: String) {
    val scope = rememberCoroutineScope()
    val context = androidx.compose.ui.platform.LocalContext.current
    Box(Modifier.fillMaxSize().background(LocalSurfaces.current.screen).padding(32.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("Der Kurs ließ sich nicht laden", fontSize = 22.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Text(fehler, color = secondaryText, textAlign = TextAlign.Center)
            PrimaryButton("Erneut versuchen", Icons.Rounded.Coffee) { scope.launch { Sitzung.laden(context) } }
        }
    }
}
