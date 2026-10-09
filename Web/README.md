# JavaQuest als Web-App

**Live: <https://niklas122212.github.io/JavaQuest/>**

Dieselbe App, nur im Browser. Nicht nur dieselben Inhalte, sondern auch dieselben
Bildschirme und dieselben Rechenregeln:

| | |
|---|---|
| **Einstieg** | Zwei Optionen, bei Vorkenntnissen fünf adaptive Einstufungsfragen mit drei Ausgängen |
| **Übersicht** | Master Score mit Rang, Tagesserie, nächste Lektion, fällige Wiederholungen, Schwächen |
| **Lernpfad** | Module mit Fortschritt, Lektionen mit Sternen und Bestwert, Freischaltung der Reihe nach |
| **Themen** | Alle Themen frei übbar, Niveau-Chips 1–5, Rundengröße 5/10/15/25, Trefferquote je Schwierigkeitsstufe |
| **Analyse** | Gesamte Beherrschung, Stärken, Im Aufbau, Wissenslücken – mit denselben Schwellen (75 % / 55 %) |
| **Profil** | Lernprofil, Score und Rang, Serien, Datenschutz, Zurücksetzen |
| **Lern-Loop** | Theorie mit Code-Exegese, vier Aufgabentypen, Begründung falscher Antworten, Sterne und Score-Zuwachs |
| **Ohne Maus** | Sprungmarke zum Inhalt, sichtbarer Fokus überall, Tasten 1–4 für Antworten, Strg/⌘ + Enter zum Prüfen, Esc zum Abbrechen, Alt + 1–5 für die Bereiche |
| **Sprachausgabe** | Antworten als Auswahlgruppe mit Zustand, Rückmeldung wird automatisch vorgelesen, Fortschrittsbalken und UML-Diagramme sind beschriftet |
| **Arena** | Den Roboter Byte mit echtem Java steuern: 13 Missionen (Lektion 1–7 enden mit einer, dazu Training und 3 Boss-Level), Tagesmission, Spielplatz – Spielfeld mit Punktspur, Wiedergabe mit Tempo, Befehlsleiste, Konsole, Variablen, bis zu 3 Sterne mit Messwert |
| **Code-Aufgaben** | Wie in den Apps: Aufbau (Klammern, Semikolons), Regeln und echtes Ausführen mit dem eingebauten Interpreter; dazu ein Testlauf, der keinen Versuch kostet |
| **Bonus-Aufgaben** | Code-Puzzle und Bug-Jagd in Lektion 1–13 – bringen XP, zählen nicht für Trefferquote und Score |
| **Motivation** | XP und Level, Combos, 19 Abzeichen, Missionssterne im Lernpfad – abgeleitet aus dem Protokoll, kein neues Speicherformat |

Gleich sind auch die Zahlen dahinter: Bestehensgrenze 69 %, Stufenfaktor 1,0 / 1,25 / 1,5
im Master Score, Sterne ab 69 % / 84,5 % / 100 %, Ränge ab 0 / 150 / 350 / 600 / 850,
Varianten-Auswahl je Lernziel und die Wiedervorlage mit Pausen von 0, 1, 3, 7, 16 und 35 Tagen.

**Zum Verschicken gedacht:** Wer den Link in Safari öffnet und „Zum Home-Bildschirm“
wählt, bekommt ein eigenes Symbol. Danach startet JavaQuest ohne Browser-Leiste und
läuft offline – ohne App Store und ohne Entwickler-Konto.

## Aufbau

| Datei | Inhalt |
|---|---|
| `index.html` | Gerüst und die Angaben, die Safari für den Home-Bildschirm braucht |
| `app.js` | Kurs laden, Einstufung, alle Bildschirme, Auswertung, Fortschritt, UML-Zeichner |
| `java.js` | Der eingebaute Java-Interpreter – Übertragung der Swift-Fassung, gegen dieselben JDK-Fälle geprüft |
| `arena.js` | Arena-Logik: Missionen, Welten, Sterne, Tempo der Wiedergabe, Einfügen aus der Befehlsleiste |
| `spiel.js` | XP, Level, Abzeichen und Tagesmission – dieselben Regeln wie Gamification.swift |
| `arena-seiten.js` | Arena-Bildschirme: Übersicht, Mission mit Spielfeld, Abzeichen |
| `arena_missions.json`, `bonus_aufgaben.json` | Kopien aus der Apple-App (werden beim Bauen erneuert, die CI vergleicht sie) |
| `styles.css` | Gestaltung, hell und dunkel |
| `sw.js` | Service Worker: legt alles ab, damit die App offline startet. Seine Versionsnummer ist eine Prüfsumme über alle ausgelieferten Dateien |
| `manifest.webmanifest` | Name, Symbol, Vollbild-Start |
| `java_course.json` | Kopie des Kurses (wird beim Bauen erneuert) |

## Erneuern und bauen

```bash
Tools/build_web.sh        # kopiert den Kurs, prüft die Dateien, trägt die Versionsnummer ein, packt dist/JavaQuest-Web.zip
```

Die Versionsnummer in `sw.js` und `index.html` wird nicht von Hand gepflegt, sondern von
`Tools/web_fassung.mjs` aus dem Inhalt berechnet. Der Service Worker lädt nur dann etwas
nach, wenn sich diese Nummer ändert – eine Kursänderung ohne neue Nummer erreichte früher
niemanden, der die Seite schon kannte. Die CI lehnt eine unpassende Nummer ab; dann einfach
`Tools/build_web.sh` ausführen.

## Grenzen

Der Fortschritt liegt im Speicher des Browsers (`localStorage`) und damit nur auf dem
jeweiligen Gerät. Löscht man die Website-Daten, ist er weg. Code-Aufgaben werden wie in
den anderen Fassungen ohne Compiler geprüft – über Regeln auf dem Quelltext und, wo der
eingebaute Interpreter das Programm versteht, durch echtes Ausführen. Klassen, Lambdas,
Collections und try/catch kennt er nicht; dort bleibt es bei den Regeln.
