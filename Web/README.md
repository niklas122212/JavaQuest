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
| `styles.css` | Gestaltung, hell und dunkel |
| `sw.js` | Service Worker: legt alles ab, damit die App offline startet |
| `manifest.webmanifest` | Name, Symbol, Vollbild-Start |
| `java_course.json` | Kopie des Kurses (wird beim Bauen erneuert) |

## Erneuern und bauen

```bash
tools/build_web.sh        # kopiert den Kurs, prüft die Dateien, packt dist/JavaQuest-Web.zip
```

## Grenzen

Der Fortschritt liegt im Speicher des Browsers (`localStorage`) und damit nur auf dem
jeweiligen Gerät. Löscht man die Website-Daten, ist er weg. Code-Aufgaben werden wie in
den anderen Fassungen ohne Compiler geprüft – über Regeln auf dem Quelltext.
