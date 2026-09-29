// Ab AGP 9 bringt das Android-Plugin Kotlin selbst mit („built-in Kotlin“). Das eigene
// Plugin org.jetbrains.kotlin.android darf deshalb nicht mehr angewendet werden – es bricht
// den Build ab. Die Compiler-Plugins für Compose und Serialisierung braucht es weiterhin.
plugins {
    id("com.android.application") version "9.4.1" apply false
    kotlin("plugin.compose") version "2.4.20" apply false
    kotlin("plugin.serialization") version "2.4.20" apply false
}
