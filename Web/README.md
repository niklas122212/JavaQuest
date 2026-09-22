# JavaQuest als Web-App

**Live: <https://niklas122212.github.io/JavaQuest/>**

Dieselben Inhalte wie die iPhone-, Mac- und Windows-Fassung, nur im Browser:
dieselbe Kursdatei, dieselbe Bestehensgrenze (69 %), dieselbe Varianten-Auswahl.

**Zum Verschicken gedacht:** Wer den Link in Safari öffnet und „Zum Home-Bildschirm“
wählt, bekommt ein eigenes Symbol. Danach startet JavaQuest ohne Browser-Leiste und
läuft offline – ohne App Store und ohne Entwickler-Konto.

## Aufbau

| Datei | Inhalt |
|---|---|
| `index.html` | Gerüst und die Angaben, die Safari für den Home-Bildschirm braucht |
| `app.js` | Kurs laden, Aufgaben, Auswertung, Fortschritt, UML-Zeichner |
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
