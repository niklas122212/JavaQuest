# kotlinx.serialization bringt eigene Regeln mit; diese halten zusätzlich die generierten
# Serializer des Lernstands (ProgressData & Co.) – ohne sie ließe sich eine Sicherung
# nach dem Verkleinern durch R8 nicht mehr lesen.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers @kotlinx.serialization.Serializable class app.javaquest.** {
    *** Companion;
}
-keepclasseswithmembers class app.javaquest.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class app.javaquest.**$$serializer { *; }
