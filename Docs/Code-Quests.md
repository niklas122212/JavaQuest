# Code-Quests: „Die Burg Javahall“

Ein Abenteuer, das nur durch echten Java-Code vorankommt. Jede Quest erzählt eine Szene, führt **genau ein**
Java-Konzept ein und prüft den Code der Spielerin mit versteckten Tests, wie bei JUnit. Statt „Falsch“ gibt es
einen Mentor-Hinweis, der sagt, was zu tun ist. Sauberer Code bringt Sterne, Gegenstände und Baupläne, und
nach Kapitel 1 öffnet die Werkstatt für freies Bauen.

> Stand: Apple-App (iPhone, iPad, Mac). Windows, Android und Web kennen die Quests noch nicht, bewahren
> ihre Ergebnisse in Sicherungen aber auf (siehe [Plattformen](#plattformen)).

## 1. Ausgangslage und Ziel

Bisher gab es Lückentexte, Auswahlfragen und kurze Code-Aufgaben, die per Regeln und Ausgabevergleich
bewertet wurden, dazu die Arena mit dem Roboter Byte. Es fehlte ein Ort, an dem man **ganze Klassen und
Methoden** schreibt und wie in der Praxis gegen Tests entwickelt.

Leitlinien:

| Prinzip | Umsetzung |
|---|---|
| Ein Konzept pro Schritt | Jede Quest hat ein `concept` mit Mini-Beispiel. Die Reihenfolge folgt den Lektionen 1–11 (geprüft in `QuestTests`). |
| Erst verstehen, dann schreiben | Szene → Auftrag mit genauer Signatur → Konzept → sichtbare Tests als JUnit-Zeilen → Editor. |
| Tests als Spezifikation | Die ersten 1–2 Tests sind sichtbar (`assertEquals(true, Tuer.unlock(105));`), die übrigen prüfen Sonderfälle und bleiben bis zum Lösen geheim. |
| Fehler sind Lernanlässe | Jeder Test hat einen eigenen Hinweis. Compiler-, Laufzeit- und Endlosschleifenfehler übersetzt der Mentor in Alltagssprache. |
| Sauberer Code zählt | ★ alle Tests grün · ★ Java-Namenskonventionen · ★ saubere Einrückung. |
| Kein Abschreiben ohne Denken | Die Musterlösung erscheint erst nach drei vergeblichen Läufen, und nur zum Lesen. |

## 2. Architektur

```
 JavaCodeEditor (UITextView / NSTextView, TextKit 1)
   │  tippt ──▶ CodeEditing (Einrückung, Klammerpaare, Tab)            JavaQuestKit/Quests
   │  liest mit ──▶ JavaRunner.check + CodeQuality.naming (350 ms nach der letzten Taste)
   ▼
 QuestSessionModel ── „Tests ausführen“ ──▶ QuestRunner.run(code, quest)
                                              1. JavaParser.parse        → Compilerfehler?
                                              2. Klasse vorhanden?       → Groß-/Kleinschreibung
                                              3. je Test JavaRunner.test → Wert, Text, Ausgabe, Exception
                                              4. Pflicht-Bausteine       → CodeRule (require/forbid/anyOf)
                                              5. CodeQuality             → Namen, Einrückung
                                              6. Mentor.after            → der eine hilfreichste Hinweis
   ▼
 QuestResult (solved, stars, tests, mentor)
   ▼
 ProgressStore.recordQuest ──▶ Protokoll (Kontext „mission“, ID „quest-…“, credit = Sterne ÷ 3)
                                ──▶ LearnerFacts.questStars → XP, Abzeichen, QuestProgress
```

| Datei | Aufgabe |
|---|---|
| `JavaQuestKit/Quests/CodeQuest.swift` | Datenmodell: `QuestBook`, `QuestChapter`, `CodeQuest`, `QuestTest` (mit `assertion` als JUnit-Zeile), `QuestExpectation` |
| `JavaQuestKit/Quests/QuestRunner.swift` | Bewertung und `Mentor` |
| `JavaQuestKit/Interpreter/JavaTesting.swift` | `JavaRunner.test`: Klassen laden, ohne `main`, Vorbereitung ausführen, Ausdruck auswerten |
| `JavaQuestKit/Quests/CodeQuality.swift` | Namenskonventionen (über den Syntaxbaum) und Einrückung |
| `JavaQuestKit/Quests/CodeEditing.swift` | Editor-Regeln, plattformunabhängig und getestet |
| `JavaQuestKit/Quests/QuestProgress.swift` | Freischaltung, Inventar, Baupläne, Werkstatt |
| `JavaQuest/DesignSystem/JavaCodeEditor.swift` | Der Editor für iOS und macOS |
| `JavaQuest/Features/Quests/` | Karte (`QuestHomeView`), Quest (`QuestView`), Werkstatt (`WorkshopView`) |
| `Tools/quests/code_quests.py` | Quelle der Inhalte → `Resources/code_quests.json` |
| `Tools/verify_quests.py` | Prüft alle Quests mit einem echten JDK |

### Sandbox: Warum ein eigener Interpreter?

Der Code läuft im eingebauten Java-Interpreter auf dem Gerät, ohne Server und ohne JVM:

- **Offline und privat:** Kein Code verlässt das Gerät, die App braucht keine Netzwerk-Berechtigung (Mac-Sandbox).
- **Sicher:** Der Interpreter kennt kein Dateisystem, kein Netz und keine Prozesse. Ein Programm kann nur rechnen und ausgeben.
- **Endlosschleifen:** Höchstens 40 000 Schritte je Test (`QuestRunner.stepLimit`), danach meldet der Mentor eine vermutliche Endlosschleife.
- **Tiefe Rekursion:** Jeder Lauf hat einen eigenen Thread mit 64 MB Stack, ein `StackOverflowError` wird zur Meldung statt zum Absturz.
- **Treue zu Java:** Klassen, Vererbung, Interfaces, Exceptions, Listen, Maps, Enums und Records sind gegen JDK 25 geprüft (`Fixtures/java_differential_oop.json`). Was er nicht kennt (z. B. Lambdas, `float`, Text-Blöcke), meldet er als „kennt der eingebaute Interpreter nicht“, nicht als Fehler des Spielers.

Die Inhalte selbst prüft `Tools/verify_quests.py` mit `javac`/`java`. Jede Musterlösung muss alle Tests auf
dem echten JDK bestehen, jeder Startcode muss übersetzen und darf nicht schon alles bestehen. Die CI führt das
bei jedem Push aus.

## 3. Editor-UX

Der `JavaCodeEditor` ersetzt das schlichte Textfeld überall dort, wo Code geschrieben wird: in Quests, in der
Werkstatt, in Code-Aufgaben der Lektionen und in der Arena.

| Taste / Situation | Verhalten |
|---|---|
| Enter | Neue Zeile mit der Einrückung der aktuellen; nach `{` eine Ebene tiefer, nach `case …:` ebenso. |
| Enter nach `{`, wenn eine `}` fehlt | Die `}` erscheint auf eigener Zeile, der Cursor steht eingerückt dazwischen. |
| Enter zwischen `{` und `}` | Die Klammer klappt auf. |
| `}` am Zeilenanfang | Springt auf die Einrückung der passenden `{`. Steht die `}` schon da, springt der Cursor dahinter, statt eine zweite zu schreiben. |
| Tab | Leerzeichen bis zur nächsten Vierer-Spalte. |
| `(` `[` `"` | Paarweise, aber nur vor Leerraum oder schließenden Zeichen und nicht in Strings. Die schließende Klammer wird übertippt. |
| Tippen allgemein | Syntaxfarben sofort, Zeilennummern links (mit umbrochenen Zeilen), keine Autokorrektur, keine typografischen Anführungszeichen. |
| Kurz nach dem Tippen | Der Compiler liest mit: Fehlerzeile rot (Hintergrund und Zeilennummer), Meldung in der Leiste darunter. Namenshinweise erscheinen gelb gepunktet. |
| Nach einem Testlauf | Die Zeile eines Absturzes ist rot markiert. |
| iPhone/iPad | Symbolleiste über der Tastatur: ⇥ `{ } ( ) ; " = + - < > [ ] ! && \|\| . , * / % '`. Sie folgt denselben Regeln. |
| Mac | Rückgängig (⌘Z), Tests mit ⌘↩, Quests mit ⌘6. |

Deutsche Tottasten (`^`, `´`) bleiben nutzbar: Während einer zusammengesetzten Eingabe wird nicht umgefärbt.

## 4. Testformat

```json
{
  "id": "quest-tuer",
  "chapterId": "k2-gaenge",
  "title": "Die verschlossene Tür",
  "lessonId": "l06-methods",
  "topicId": "methods",
  "difficulty": 3,
  "story": "Die Tür oben im Turm ist verschlossen. …",
  "task": "Schreibe in der Klasse Tuer die Methode public static boolean unlock(int key). …",
  "concept": { "title": "Methoden mit Rückgabewert", "text": "…", "code": "public static boolean istGerade(int zahl) { … }" },
  "className": "Tuer",
  "starterCode": "public class Tuer {\n    // Schreibe hier die Methode unlock\n}",
  "solution": "…",
  "tests": [
    { "name": "Der Schlüssel 105 öffnet", "expression": "Tuer.unlock(105)", "expect": { "value": true }, "visible": true,
      "hint": "105 ist größer als 100 und 105 % 7 == 0." },
    { "name": "Der Schlüssel 110 öffnet nicht", "expression": "Tuer.unlock(110)", "expect": { "value": false },
      "hint": "110 ist größer als 100, aber 110 % 7 ist nicht 0." }
  ],
  "requirements": [],
  "success": "Mit einem Klicken springt das Schloss auf. …",
  "reward": { "item": "Messingschlüssel", "symbol": "key.fill", "text": "…" },
  "blueprint": { "title": "Methode mit boolean", "text": "…", "code": "…" }
}
```

Ein Test besteht aus:

- `setup`: Anweisungen davor, z. B. `Golem g = new Golem("Rolf");\ng.arbeiten();`
- `expression`: der geprüfte Ausdruck. Ohne Ausdruck läuft das ganze Programm mit `main`.
- `expect`, eine der vier Arten:
  - `value`: Wert mit Typ, wie `assertEquals`. `true` ist nicht `"true"`; eine ganze Zahl passt zu einer Kommazahl gleichen Werts.
  - `text`: was `println` zeigen würde. Für Objekte über `toString()`, Listen (`[Ada, Bo]`) und Maps.
  - `output`: die Konsolenausgabe.
  - `exception`: die erwartete Exception-Klasse. `Exception` oder `RuntimeException` akzeptieren jede.

**Technik:** Der Spielercode wird zuerst allein übersetzt, damit Fehler ihre echte Zeilennummer behalten.
Danach wird er mit einer Hilfsklasse übersetzt, die Vorbereitung und Ausdruck enthält, sodass der Test alle
Klassen des Spielers kennt. Scheitert der Testcode selbst (Methode fehlt, Konstruktor passt nicht), meldet
der Mentor den Aufruf des Tests („Der Test ruft „Tuer.unlock(105)“ auf – aber: …“). Eine Zeilennummer aus
dem unsichtbaren Testcode zeigt er nicht.

## 5. Der Mentor

`Mentor.after` wählt **einen** Hinweis, den hilfreichsten zuerst:

| Art | Auslöser | Beispiel |
|---|---|---|
| `compile` | Syntaxfehler | „Zeile 3: Du hast ein Semikolon vergessen. Jede Anweisung endet mit ; – wie ein Punkt am Satzende.“ |
| `missingClass` | Klasse fehlt oder heißt anders | „Deine Klasse heißt tuer – Java unterscheidet Groß- und Kleinschreibung …“ |
| `missingMember` | Methode/Konstruktor fehlt oder hat andere Parameter | „Der Test ruft „new Golem("Rolf").getEnergie()“ auf – aber: Golem hat keinen Konstruktor mit 1 Wert(en) …“ |
| `endless` | Schrittlimit erreicht | „Beim Test „…“ hört dein Code nicht auf. Prüfe, ob sich die Bedingung der Schleife irgendwann ändert …“ |
| `crash` | Exception im Code | „Dein Programm stürzt ab: …“ plus der Hinweis des Tests |
| `wrongValue` | Falscher Wert | „„Der Schlüssel 110 öffnet nicht“: Erwartet: false – dein Code liefert true. 110 ist größer als 100, aber 110 % 7 ist nicht 0.“ |
| `requirement` | Tests grün, Pflicht-Baustein fehlt | „Schreib die 100 nicht selbst hin – lass Java rechnen.“ |
| `quality` | Gelöst, aber nicht sauber | „Variablen und Parameter beginnen klein …: key statt Key.“ |
| `success` | Alles perfekt | Die Fortsetzung der Geschichte |

## 6. Gamification

- **Sterne:** ★ alle Tests und Pflicht-Bausteine · ★ Namen nach Konvention · ★ saubere Einrückung.
  Gespeichert wird nur ein neuer Bestwert.
- **XP:** 25 je Stern, wie bei Arena-Missionen. Lektionen und Aufgaben bringen weiterhin ihre eigenen XP.
- **Gegenstände:** Jede gelöste Quest legt einen Gegenstand ins Inventar (Messingschlüssel, Golemkern …).
- **Baupläne:** Freischaltbare Code-Bausteine, aber nur für sauberen Code mit allen 3 Sternen. In der
  Werkstatt fügt man sie an der Cursorstelle ein, eingerückt auf die Ebene der Zeile.
- **Werkstatt (Freies Bauen):** Öffnet nach Kapitel 1. Eigene Programme mit Konsole, Interpreter-Hinweisen
  (z. B. Strings mit `==`) und „Ausführen und zusehen“ Schritt für Schritt. Die Programme liegen lokal.
- **Abzeichen:** „Abenteurer“ (erste Quest), „Sauberer Code“ (5 Quests mit 3 Sternen), „Retter von
  Javahall“ (alle Quests). Die Arena-Abzeichen zählen nur noch Arena-Missionen.
- **Freischaltung:** Eine Quest öffnet sich, wenn ihre Lektion erreicht und die vorige Quest gelöst ist.
  Die Karte nennt den Grund („Ab Lektion 7: Arrays & Strings“).

### Speicherung

Quest-Ergebnisse stehen im vorhandenen Aufgaben-Protokoll, wie Arena-Missionen: Kontext `mission`,
`taskId` = Quest-ID (immer mit `quest-` am Anfang), `credit` = Sterne ÷ 3. Es gibt kein neues
Speicherschema, und Sicherungen nehmen die Ergebnisse mit. Entwürfe und Werkstatt-Programme liegen nur auf
dem Gerät (UserDefaults); mit `-inMemoryStore` (Tests, Screenshots) wird nichts gespeichert.

## 7. Eine Quest hinzufügen

1. In `Tools/quests/code_quests.py` eine Quest anhängen (Reihenfolge = Geschichte, Lektionen aufsteigend).
2. `python3 Tools/quests/code_quests.py` schreibt die JSON-Datei.
3. `python3 Tools/verify_quests.py` prüft sie mit dem echten JDK.
4. `swift test` (in `Packages/JavaQuestKit`) prüft dieselben Quests mit dem eingebauten Interpreter: 3 Sterne
   für die Musterlösung, Startcode übersetzt und löst nicht, Kurs-Reihenfolge, Abzeichen-Zahl (`Achievement.questCount`).

Faustregeln: Sichtbar sind nur die Tests, die die Signatur zeigen. Versteckte Tests decken Grenzfälle ab
(0, leer, negativ, Gleichstand). Jeder Hinweis nennt den Denkfehler, nicht die Lösung. Der Startcode
übersetzt immer.

## 8. Plattformen

| | Apple | Windows/Android | Web |
|---|---|---|---|
| Quests, Werkstatt, neuer Editor | ✓ | – | – |
| Quest-Ergebnisse in Sicherungen | ✓ | bleiben erhalten (Kontext `mission`) | bleiben erhalten (unbekannte IDs werden übernommen) |
| Interpreter mit Klassen, Vererbung, Exceptions, Sammlungen | ✓ | in Arbeit (Branch `kotlin-oop-wip`, es fehlt `JavaCollections.kt`) | – |

Nächste Schritte: den Kotlin-Interpreter fertig portieren, dann Quests und Editor für Windows/Android
(Compose) und Web (`java.js`) nachziehen. Die Quest-Datei und die Tests sind dafür bereits
plattformunabhängig.
