import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    kotlin("jvm") version "2.4.20"
    kotlin("plugin.serialization") version "2.4.20"
    kotlin("plugin.compose") version "2.4.20"
    id("org.jetbrains.compose") version "1.12.0"
}

group = "app.javaquest"

// Die Versionsnummer kommt aus dem Git-Tag (v1.0.1 → 1.0.1), nicht aus dem Code. Vorher
// stand „1.0.0“ an drei Stellen fest: Die Veröffentlichung v1.0.1 enthielt Dateien namens
// …-1.0.0 – und ein Windows-Installer ersetzt eine vorhandene Installation nur, wenn seine
// Nummer höher ist. Vorrang: JAVAQUEST_VERSION (setzt die CI aus dem Tag), sonst der
// jüngste Tag im Repo. Ohne Git-Verlauf (z. B. Quellen als ZIP) bleibt es bei 1.0.0.
val appVersion: String = run {
    val gesetzt = providers.environmentVariable("JAVAQUEST_VERSION").orNull?.takeIf { it.isNotBlank() }
    val roh = gesetzt ?: runCatching {
        providers.exec {
            commandLine("git", "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*")
            isIgnoreExitValue = true
        }.standardOutput.asText.get().trim()
    }.getOrDefault("")
    val nummer = roh.removePrefix("v")
    when {
        Regex("""\d+\.\d+\.\d+""").matches(nummer) -> nummer
        gesetzt != null -> throw GradleException("JAVAQUEST_VERSION=„$gesetzt“ ist keine Versionsnummer der Form 1.2.3")
        else -> "1.0.0".also { logger.warn("Kein Tag der Form v1.2.3 gefunden – baue als $it") }
    }
}
version = appVersion

// Für Tools/package_windows.sh: dieselbe Nummer, damit ZIP und Installer gleich heißen.
tasks.register("zeigeVersion") {
    val nummer = appVersion
    doLast { println(nummer) }
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_21) }
}

dependencies {
    implementation(compose.desktop.currentOs)
    // Windows-Bibliotheken immer mitliefern: Das portable Paket wird auf dem Mac gebaut, läuft aber unter Windows.
    implementation(compose.desktop.windows_x64)
    implementation("org.jetbrains.compose.material3:material3:1.9.0")
    implementation("org.jetbrains.compose.material:material-icons-extended:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")

    testImplementation(kotlin("test-junit"))
    testImplementation(compose.desktop.uiTestJUnit4)
}

// Der Kurs ist dieselbe Datei wie in der iOS-/Mac-App – mit allen Zeilen-Erklärungen.
val courseFile = rootProject.file("../Packages/JavaQuestKit/Sources/JavaQuestKit/Resources/java_course.json")
val copyCourse by tasks.registering(Copy::class) {
    from(courseFile)
    into(layout.buildDirectory.dir("generated/course"))
}
sourceSets.main { resources.srcDir(copyCourse) }

compose.desktop {
    application {
        mainClass = "app.javaquest.MainKt"
        nativeDistributions {
            // MSI/EXE lassen sich nur unter Windows bauen (jpackage); siehe README.
            targetFormats(TargetFormat.Msi, TargetFormat.Exe, TargetFormat.Dmg)
            packageName = "JavaQuest"
            packageVersion = appVersion
            description = "Java lernen, Level für Level – jede Codezeile erklärt"
            vendor = "JavaQuest"
            copyright = "© 2026 JavaQuest"
            windows {
                iconFile.set(project.file("icons/JavaQuest.ico"))
                menu = true
                menuGroup = "JavaQuest"
                shortcut = true
                perUserInstall = true
                dirChooser = true
                upgradeUuid = "8B6E2C31-4B8D-4E7A-9F51-2F6E4A9C1D37"
            }
            macOS {
                iconFile.set(project.file("icons/JavaQuest.icns"))
                bundleID = "app.javaquest.desktop"
            }
        }
    }
}
