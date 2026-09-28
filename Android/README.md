# JavaQuest für Android

Dieselbe App wie unter Windows, auf dem Handy und Tablet: gleiche Kursdatei, gleiche Regeln,
gleiche Oberfläche. Läuft vollständig offline, ohne Konto und **ohne eine einzige Berechtigung**.

## Installieren

1. Auf GitHub unter **Actions → Android-App** den jüngsten grünen Lauf öffnen und das Artefakt
   **JavaQuest-Android** herunterladen (bei einer Veröffentlichung `v…` liegt die APK auch unter
   *Releases*).
2. Die ZIP entpacken und `JavaQuest-Android-<Version>.apk` aufs Handy bringen (Kabel, Cloud, E-Mail).
3. Antippen. Android fragt einmalig, ob die App, aus der du die Datei öffnest (z. B. „Dateien“ oder
   Chrome), Apps installieren darf – zulassen, installieren.

Voraussetzung: Android 8.0 oder neuer.

**Lernstand mitnehmen:** Im Profil *Sicherung speichern* – die Datei passt in jede Fassung (Web,
iPhone, Mac, Windows, Android). Beim *Sicherung einlesen* wird nichts gelöscht; von beiden Ständen
gilt jeweils das bessere Ergebnis.

## Aufbau

```
Android/
├── app/build.gradle.kts        kompiliert ../Windows/src/main/kotlin und die Kursdatei mit
├── app/src/main/kotlin/…/android/
│   ├── MainActivity.kt         Einstieg, Zurück-Taste, Startbild während der Kurs lädt
│   ├── Sitzung.kt              Kurs (3 MB) einmal im Hintergrund laden, Lernstand in filesDir
│   └── AndroidPlattform.kt     Dateiauswahl des Systems, Kalender-Eintrag
└── tools/emulator_durchlauf.py Klick-Durchlauf auf dem Emulator (CI)
```

Die Android-App hat **keine eigene Oberfläche und keine eigene Lernlogik**. Sie übersetzt
dieselben Quellen wie die Windows-Fassung (`Windows/src/main/kotlin`: Kern, Speicher,
Compose-Oberfläche) und dieselbe `java_course.json` wie iPhone, Mac und Web. Was sich je
System unterscheidet, steht hinter der Schnittstelle `ui/Plattform.kt`:

| | Windows / Mac (`Windows/src/desktop`) | Android (`Android/app`) |
|---|---|---|
| Sicherung speichern/einlesen | AWT-Dateidialog | Dateiauswahl des Systems (SAF) – ohne Speicher-Berechtigung |
| Erinnerung an Wiederholungen | `.ics`-Datei, öffnet den Standard-Kalender | Eintragen-Dialog der Kalender-App |
| Lernstand | `%APPDATA%\JavaQuest\progress.json` bzw. `~/Library/Application Support/JavaQuest` | privater App-Speicher (`filesDir/progress.json`) |
| Code-Schrift | Consolas / Menlo | Monospace des Systems |

Die Oberfläche richtet sich nach der Breite: Unter 720 dp (Handy hochkant) stehen die Bereiche
in einer Leiste unten, darüber (Tablet, Handy quer, Desktop) in der Seitenleiste. Status-,
Gesten- und Tastaturbereich hält sie frei. Die Zurück-Taste schließt erst eine laufende
Lektion, dann geht es zur Übersicht, erst von dort verlässt sie die App.

Für Code-Eingaben ist die Autokorrektur aus und die Großschreibung am Satzanfang auch – sonst
würde aus `int` ein „Int“.

Keine Cloud-Sicherung: `allowBackup` ist aus und die Cloud in den Extraktionsregeln
ausgeschlossen. Beim Umzug auf ein neues Gerät per Kabel/WLAN darf der Lernstand mit.

## Bauen

Gebaut wird in GitHub Actions (`.github/workflows/android.yml`) bei jeder Änderung an
`Android/`, `Windows/src/` oder der Kursdatei:

1. Release-APK bauen (R8 verkleinert), Lint mit `NewApi` als Fehler – eine Java-API über
   Android 8 hinaus wäre sonst ein Absturz auf älteren Geräten.
2. Auf einem Pixel-6-Emulator (Android 14) durchspielen: Onboarding, erste Lektion bis zur
   Aufgabe, Zurück-Taste, alle Bereiche der unteren Leiste, Querformat mit Seitenleiste,
   Neustart mit erhaltenem Lernstand. Die Bildschirmfotos hängen als Artefakt am Lauf.
3. Bei einem Tag `v…` die APK an die Veröffentlichung hängen.

Lokal (Android Studio oder JDK 17+ mit Android-SDK 36):

```bash
cd Android
./gradlew assembleRelease     # → app/build/outputs/apk/release/app-release.apk
./gradlew installDebug        # auf ein angeschlossenes Gerät
```

### Signatur

Ohne weitere Einstellung signiert Gradle mit dem Debug-Schlüssel des jeweiligen Rechners. Die
APK ist damit installierbar, aber jeder CI-Lauf hat einen anderen Schlüssel – eine neue Fassung
lässt sich dann nicht über die alte installieren (vorher Lernstand sichern, alte App
deinstallieren, neue installieren, Sicherung einlesen).

Für dauerhafte Aktualisierungen einmal einen eigenen Schlüssel anlegen und in GitHub unter
*Settings → Secrets and variables → Actions* hinterlegen:

```bash
keytool -genkeypair -v -keystore javaquest.jks -alias javaquest -keyalg RSA -keysize 4096 -validity 10000
base64 -i javaquest.jks | pbcopy     # → Secret ANDROID_KEYSTORE_BASE64
```

Dazu die Secrets `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`javaquest`) und
`ANDROID_KEY_PASSWORD`. Die Datei `javaquest.jks` gut aufheben und **nicht** ins Repository legen –
wer sie hat, kann Aktualisierungen der App signieren.

Die Versionsnummer kommt wie unter Windows aus dem Git-Tag (`v1.2.3` → `1.2.3`); der
`versionCode` enthält zusätzlich die Laufnummer der CI, damit jede neue APK höher zählt.
