import java.util.Base64

plugins {
    id("com.android.application")
    kotlin("plugin.compose")
    kotlin("plugin.serialization")
}

/*
 * Die Android-App hat keine eigene Oberfläche und keine eigene Lernlogik: Sie kompiliert
 * dieselben Kotlin-Quellen wie die Windows-Fassung (Windows/src/main/kotlin – Kern, Speicher
 * und Compose-Oberfläche) und dieselbe Kursdatei wie iPhone, Mac und Web. Eigen ist nur,
 * was das Betriebssystem betrifft: Activity, Dateiauswahl, Kalender (src/main/kotlin hier).
 * Eine Korrektur am Kurs oder an der Oberfläche landet so ohne Abschreiben in beiden Apps.
 */
val gemeinsameQuellen = rootProject.file("../Windows/src/main/kotlin")
val kursOrdner = rootProject.file("../Packages/JavaQuestKit/Sources/JavaQuestKit/Resources")

// Versionsnummer wie bei Windows aus dem Git-Tag (v1.2.3 → 1.2.3); JAVAQUEST_VERSION hat Vorrang.
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

// 1.2.3 → 10203. Die Build-Nummer der CI kommt dazu, damit jede neue APK eine höhere Nummer
// trägt und Android sie als Aktualisierung annimmt statt als Rückschritt.
val appVersionCode: Int = run {
    val (major, minor, patch) = appVersion.split(".").map { it.toInt() }
    val lauf = providers.environmentVariable("GITHUB_RUN_NUMBER").orNull?.toIntOrNull() ?: 0
    (major * 10_000 + minor * 100 + patch) * 1_000 + lauf % 1_000
}

/*
 * Signatur: Mit den vier Umgebungsvariablen (in GitHub als Secrets hinterlegt) wird die
 * Release-APK mit dem eigenen Schlüssel signiert – nur dann lassen sich spätere Fassungen
 * über eine installierte drüberinstallieren. Ohne sie signiert Gradle mit dem Debug-
 * Schlüssel: installierbar, aber jede Maschine hat einen anderen.
 */
val keystoreBase64 = providers.environmentVariable("ANDROID_KEYSTORE_BASE64").orNull?.takeIf { it.isNotBlank() }
val keystoreDatei = keystoreBase64?.let { inhalt ->
    layout.buildDirectory.file("signatur/javaquest.jks").get().asFile.also {
        it.parentFile.mkdirs()
        it.writeBytes(Base64.getMimeDecoder().decode(inhalt))
    }
}

android {
    namespace = "app.javaquest.android"
    // Compose 1.12 verlangt mindestens SDK 37 zum Kompilieren; targetSdk bleibt davon unabhängig.
    compileSdk = 37

    defaultConfig {
        applicationId = "io.github.niklas122212.javaquest"
        minSdk = 26
        targetSdk = 36
        versionCode = appVersionCode
        versionName = appVersion
    }

    signingConfigs {
        if (keystoreDatei != null) {
            create("veroeffentlichung") {
                storeFile = keystoreDatei
                storePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").orNull
                keyAlias = providers.environmentVariable("ANDROID_KEY_ALIAS").orNull
                keyPassword = providers.environmentVariable("ANDROID_KEY_PASSWORD").orNull
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("veroeffentlichung") ?: signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    packaging {
        resources {
            excludes += setOf("/META-INF/{AL2.0,LGPL2.1}", "/META-INF/versions/9/previous-compilation-data.bin")
        }
    }

    lint {
        // Java-APIs über minSdk hinaus wären auf älteren Geräten ein Absturz beim Start.
        fatal += "NewApi"
        checkDependencies = false
    }
}

androidComponents {
    onVariants { variant ->
        variant.sources.kotlin?.addStaticSourceDirectory(gemeinsameQuellen.absolutePath)
        variant.sources.assets?.addStaticSourceDirectory(kursOrdner.absolutePath)
    }
}

dependencies {
    // Dieselben Compose-Multiplatform-Bibliotheken wie in Windows/build.gradle.kts – Gradle
    // wählt daraus die Android-Fassung. So bleibt die gemeinsame Oberfläche auf beiden
    // Plattformen gegen dieselbe API kompiliert.
    implementation("org.jetbrains.compose.runtime:runtime:1.12.0")
    implementation("org.jetbrains.compose.foundation:foundation:1.12.0")
    implementation("org.jetbrains.compose.ui:ui:1.12.0")
    implementation("org.jetbrains.compose.material3:material3:1.9.0")
    implementation("org.jetbrains.compose.material:material-icons-extended:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")
    implementation("androidx.activity:activity-compose:1.10.1")
}
