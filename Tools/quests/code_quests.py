#!/usr/bin/env python3
"""Code-Quests: das Abenteuer „Die Burg Javahall“ – Quelle für Resources/code_quests.json.

Jede Quest führt genau ein Java-Konzept ein, das der Kurs bis zu ihrer Lektion erklärt hat,
und prüft den Code mit versteckten Tests (wie JUnit). Die Musterlösungen und Tests prüft
Tools/verify_quests.py mit einem echten JDK, die Swift-Tests (QuestTests) mit dem eingebauten
Interpreter.

    python3 Tools/quests/code_quests.py   # schreibt Packages/…/Resources/code_quests.json
"""
import json
import os
import textwrap

HIER = os.path.dirname(os.path.abspath(__file__))
ZIEL = os.path.join(HIER, "..", "..", "Packages", "JavaQuestKit", "Sources", "JavaQuestKit", "Resources", "code_quests.json")


def code(text):
    """Code ohne die Einrückung des Python-Quelltexts."""
    return textwrap.dedent(text).strip("\n")


def test(name, hint, expression=None, setup="", visible=False, **expect):
    eintrag = {"name": name}
    if setup:
        eintrag["setup"] = code(setup)
    if expression is not None:
        eintrag["expression"] = expression
    eintrag["expect"] = expect
    if visible:
        eintrag["visible"] = True
    eintrag["hint"] = hint
    return eintrag


BUCH = {
    "title": "Die Burg Javahall",
    "intro": ("Die Burg Javahall ist erstarrt: Ihr Code-Zauber ist zerbrochen. Tore klemmen, Treppen schweigen, "
              "Golems stehen still. Mit echtem Java bringst du sie Raum für Raum wieder zum Laufen – jede Quest "
              "prüfen versteckte Tests, wie bei echten Programmierern."),
    "chapters": [
        {"id": "k1-tor", "title": "Das Burgtor", "symbol": "door.left.hand.closed",
         "story": "Vor dir ragt das Tor von Javahall auf. Ein steinerner Wächter versperrt den Weg – und er versteht nur Java."},
        {"id": "k2-gaenge", "title": "Die dunklen Gänge", "symbol": "signpost.right.and.left",
         "story": "Hinter dem Tor verzweigen sich Gänge, Treppen winden sich nach oben. Ohne Entscheidungen und Schleifen kommst du hier nicht weit."},
        {"id": "k3-bibliothek", "title": "Die Bibliothek", "symbol": "books.vertical",
         "story": "In der Bibliothek liegen verschlüsselte Bücher und Regale voller Zahlen. Wer Texte und Arrays lesen kann, findet den Weg."},
        {"id": "k4-werkstatt", "title": "Die Werkstatt der Golems", "symbol": "hammer",
         "story": "In der Werkstatt stehen Golems, Tränke und Zauberbücher. Hier baust du eigene Klassen – Baupläne für lebendige Objekte."},
        {"id": "k5-thronsaal", "title": "Der Thronsaal", "symbol": "crown",
         "story": "Zuletzt der Thronsaal: Schatzkammer, Heldenregister und Beute. Hier zählt robuster Code, der auch mit Fehlern umgehen kann."},
    ],
    "quests": [],
}

Q = BUCH["quests"]

# ---------------------------------------------------------------------------------------- Kapitel 1
Q.append({
    "id": "quest-torwaechter", "chapterId": "k1-tor", "title": "Der Torwächter",
    "lessonId": "l01-hello", "topicId": "syntax", "difficulty": 1,
    "story": "Der steinerne Wächter vor dem Tor öffnet ein Auge. „Wer bist du?“, grollt er. Er erwacht nur, wenn man ihn richtig grüßt.",
    "task": "Lass das Programm genau zwei Zeilen ausgeben: zuerst „Hallo, Wächter!“, dann „Ich bin der neue Lehrling.“",
    "concept": {"title": "Ausgeben mit println",
                "text": "System.out.println(…) schreibt einen Text in die Konsole und springt danach in die nächste Zeile. Texte stehen in Anführungszeichen, am Ende kommt ein Semikolon.",
                "code": 'System.out.println("Hallo!");'},
    "className": "Tor",
    "starterCode": code("""
        public class Tor {
            public static void main(String[] args) {
                // Gib hier die zwei Zeilen aus
            }
        }
    """),
    "solution": code("""
        public class Tor {
            public static void main(String[] args) {
                System.out.println("Hallo, Wächter!");
                System.out.println("Ich bin der neue Lehrling.");
            }
        }
    """),
    "tests": [
        test("Der Wächter hört genau zwei Zeilen", "Zwei Zeilen brauchen zwei println-Befehle – jeder schreibt eine Zeile.",
             output="Hallo, Wächter!\nIch bin der neue Lehrling.", visible=True),
    ],
    "success": "„Willkommen, Lehrling“, grollt der Wächter und tritt zur Seite. Das Tor knarrt – ein Spalt öffnet sich.",
    "reward": {"item": "Wächterabzeichen", "symbol": "shield.lefthalf.filled", "text": "Der Wächter erkennt dich jetzt."},
    "blueprint": {"title": "Programmrahmen", "text": "Jedes Java-Programm: eine Klasse mit main.",
                  "code": code("""
                      public class MeinProgramm {
                          public static void main(String[] args) {
                              System.out.println("Hallo!");
                          }
                      }
                  """)},
})

Q.append({
    "id": "quest-namensschild", "chapterId": "k1-tor", "title": "Das Namensschild",
    "lessonId": "l02-variables", "topicId": "variables", "difficulty": 1,
    "story": "Neben dem Tor hängt ein leeres Namensschild. Der Wächter will wissen, wer hier ein und aus geht – und das Schild füllt sich nur aus Variablen.",
    "task": "Speichere den Namen „Ada“ in einer String-Variablen und das Alter 12 in einer int-Variablen. Gib dann „Lehrling Ada, 12 Jahre“ aus – zusammengesetzt aus deinen Variablen.",
    "concept": {"title": "Variablen",
                "text": "Eine Variable ist eine Box mit Etikett: Der Typ sagt, was hineinpasst (String für Text, int für ganze Zahlen). Mit + setzt du Text und Werte zusammen.",
                "code": 'String name = "Byte";\nint alter = 3;\nSystem.out.println(name + " ist " + alter);'},
    "className": "Schild",
    "starterCode": code("""
        public class Schild {
            public static void main(String[] args) {
                // Zwei Variablen: der Name und das Alter
            }
        }
    """),
    "solution": code("""
        public class Schild {
            public static void main(String[] args) {
                String name = "Ada";
                int alter = 12;
                System.out.println("Lehrling " + name + ", " + alter + " Jahre");
            }
        }
    """),
    "tests": [
        test("Das Schild zeigt Name und Alter", "Setze den Text aus Stücken zusammen: \"Lehrling \" + name + \", \" + alter + \" Jahre\".",
             output="Lehrling Ada, 12 Jahre", visible=True),
    ],
    "requirements": [
        {"rule": "require", "pattern": "\\bString\\s+\\w+\\s*=", "message": "Speichere den Namen in einer String-Variablen."},
        {"rule": "require", "pattern": "\\bint\\s+\\w+\\s*=", "message": "Speichere das Alter in einer int-Variablen."},
        {"rule": "forbid", "pattern": "Ada, 12", "scope": "raw", "message": "Schreib den Satz nicht fertig hin – setze ihn aus deinen Variablen zusammen."},
    ],
    "success": "Mit goldenen Buchstaben erscheint dein Name auf dem Schild. Der Wächter nickt zufrieden.",
    "reward": {"item": "Namensschild", "symbol": "person.text.rectangle", "text": "Javahall kennt jetzt deinen Namen."},
    "blueprint": {"title": "Text und Zahl", "text": "Variablen anlegen und zusammen ausgeben.",
                  "code": 'String held = "Ada";\nint punkte = 42;\nSystem.out.println(held + " hat " + punkte + " Punkte");'},
})

Q.append({
    "id": "quest-rechenrune", "chapterId": "k1-tor", "title": "Die Rechenrune",
    "lessonId": "l03-operators", "topicId": "operators", "difficulty": 2,
    "story": "In das Tor ist eine Rune geritzt: „Turmhöhe 17, Mauerdicke 25, Brücken 8. Addiere sie und verdopple die Summe.“ Nur die richtige Zahl öffnet das Schloss.",
    "task": "Lege die drei Zahlen in Variablen ab, lass Java (17 + 25 + 8) * 2 ausrechnen und gib „Runencode: “ mit dem Ergebnis aus. Schreib das Ergebnis nicht selbst hin.",
    "concept": {"title": "Rechnen mit Variablen",
                "text": "Java rechnet mit + - * / – Klammern zuerst, wie in Mathe. Das Ergebnis legst du in eine neue Variable.",
                "code": "int a = 3;\nint b = 4;\nint summe = (a + b) * 2;"},
    "className": "Rune",
    "starterCode": code("""
        public class Rune {
            public static void main(String[] args) {
                int turmhoehe = 17;
                // Mauerdicke 25, Brücken 8 – und dann rechnen
            }
        }
    """),
    "solution": code("""
        public class Rune {
            public static void main(String[] args) {
                int turmhoehe = 17;
                int mauerdicke = 25;
                int bruecken = 8;
                int code = (turmhoehe + mauerdicke + bruecken) * 2;
                System.out.println("Runencode: " + code);
            }
        }
    """),
    "tests": [
        test("Die Rune zeigt den Code", "Erst die Summe in Klammern, dann * 2: (turmhoehe + mauerdicke + bruecken) * 2.",
             output="Runencode: 100", visible=True),
    ],
    "requirements": [
        {"rule": "require", "pattern": "\\*\\s*2", "message": "Verdopple mit * 2."},
        {"rule": "forbid", "pattern": "\\b100\\b", "message": "Schreib die 100 nicht selbst hin – lass Java rechnen."},
    ],
    "success": "Die Rune glüht auf, das Schloss klickt. Das Burgtor schwingt auf – dahinter liegen die dunklen Gänge.",
    "reward": {"item": "Runenstein", "symbol": "seal.fill", "text": "Er leuchtet, wenn in der Nähe gerechnet wird."},
    "blueprint": {"title": "Rechnen", "text": "Werte zusammenrechnen und ausgeben.",
                  "code": "int gold = 120;\nint silber = 45;\nint gesamt = gold * 10 + silber;\nSystem.out.println(\"Gesamt: \" + gesamt);"},
})

# ---------------------------------------------------------------------------------------- Kapitel 2
Q.append({
    "id": "quest-weggabelung", "chapterId": "k2-gaenge", "title": "Die Weggabelung",
    "lessonId": "l04-conditionals", "topicId": "conditionals", "difficulty": 2,
    "story": "Der Gang teilt sich. Links ist es dunkel, rechts tropft Wasser. Byte rät: „Mit mindestens drei Fackeln gehen wir links, sonst lieber rechts.“",
    "task": "Vervollständige die Methode weg: Bei 3 oder mehr Fackeln gibt sie \"links\" zurück, sonst \"rechts\". Die Methode ist schon vorbereitet – du schreibst nur, was in ihr passiert.",
    "concept": {"title": "if und else",
                "text": "if prüft eine Bedingung: Ist sie wahr, läuft der erste Block, sonst der else-Block. Mit return gibt die Methode ihr Ergebnis zurück – was eine Methode genau ist, kommt in Lektion 6.",
                "code": 'if (gold >= 10) {\n    return "reich";\n} else {\n    return "arm";\n}'},
    "className": "Gabelung",
    "starterCode": code("""
        public class Gabelung {
            static String weg(int fackeln) {
                // Bei 3 oder mehr Fackeln "links", sonst "rechts"
                return "";
            }
        }
    """),
    "solution": code("""
        public class Gabelung {
            static String weg(int fackeln) {
                if (fackeln >= 3) {
                    return "links";
                } else {
                    return "rechts";
                }
            }
        }
    """),
    "tests": [
        test("Mit 5 Fackeln geht es links", "Bei 3 oder mehr Fackeln ist die Bedingung fackeln >= 3 wahr.", "Gabelung.weg(5)", value="links", visible=True),
        test("Mit 1 Fackel geht es rechts", "Ist die Bedingung falsch, läuft der else-Block.", "Gabelung.weg(1)", value="rechts", visible=True),
        test("Genau 3 Fackeln reichen für links", "„3 oder mehr“ schließt die 3 ein – nimm >= statt >.", "Gabelung.weg(3)", value="links"),
        test("Ohne Fackel geht es rechts", "Auch bei 0 Fackeln muss die Methode \"rechts\" liefern.", "Gabelung.weg(0)", value="rechts"),
    ],
    "success": "Der linke Gang wird heller, je weiter ihr geht. Byte summt zufrieden – die Entscheidung war richtig.",
    "reward": {"item": "Fackel", "symbol": "flame.fill", "text": "Sie leuchtet jeden Gang aus."},
    "blueprint": {"title": "Entscheidung", "text": "if und else mit Rückgabewert.",
                  "code": 'static String bewerte(int punkte) {\n    if (punkte >= 50) {\n        return "gut";\n    } else {\n        return "übe weiter";\n    }\n}'},
})

Q.append({
    "id": "quest-wendeltreppe", "chapterId": "k2-gaenge", "title": "Die Wendeltreppe",
    "lessonId": "l05-loops", "topicId": "loops", "difficulty": 3,
    "story": "Eine Wendeltreppe führt in den Turm. Das erste Stockwerk hat 1 Stufe, das zweite 2, das dritte 3 … Die Treppe hält nur, wenn jemand die Stufen richtig zählt.",
    "task": "Vervollständige stufen: Die Methode bekommt die Zahl der Stockwerke und gibt zurück, wie viele Stufen es insgesamt sind (1 + 2 + … + stockwerke). Nutze eine Schleife.",
    "concept": {"title": "Zählen mit einer Schleife",
                "text": "Eine for-Schleife wiederholt einen Block und zählt dabei mit. So addierst du Schritt für Schritt in eine Summen-Variable.",
                "code": "int summe = 0;\nfor (int i = 1; i <= 3; i++) {\n    summe = summe + i;\n}"},
    "className": "Treppe",
    "starterCode": code("""
        public class Treppe {
            static int stufen(int stockwerke) {
                int summe = 0;
                // Für jedes Stockwerk seine Stufen dazuzählen
                return summe;
            }
        }
    """),
    "solution": code("""
        public class Treppe {
            static int stufen(int stockwerke) {
                int summe = 0;
                for (int i = 1; i <= stockwerke; i++) {
                    summe = summe + i;
                }
                return summe;
            }
        }
    """),
    "tests": [
        test("4 Stockwerke haben 10 Stufen", "1 + 2 + 3 + 4 = 10: Zähle i von 1 bis stockwerke und addiere jedes i.", "Treppe.stufen(4)", value=10, visible=True),
        test("1 Stockwerk hat 1 Stufe", "Beginnt deine Schleife bei 1 und läuft bis einschließlich stockwerke (<=)?", "Treppe.stufen(1)", value=1),
        test("10 Stockwerke haben 55 Stufen", "Läuft die Schleife bis einschließlich 10? Nimm <= statt <.", "Treppe.stufen(10)", value=55),
        test("Ohne Stockwerk keine Stufe", "Bei 0 Stockwerken läuft die Schleife gar nicht – die Summe bleibt 0.", "Treppe.stufen(0)", value=0),
    ],
    "requirements": [
        {"rule": "anyOf", "pattern": "", "patterns": ["\\bfor\\s*\\(", "\\bwhile\\s*\\("], "message": "Zähle mit einer Schleife (for oder while)."},
    ],
    "success": "Stufe um Stufe leuchtet auf. Oben wartet eine schwere Tür mit einem seltsamen Schloss.",
    "reward": {"item": "Turmkarte", "symbol": "map.fill", "text": "Sie zeigt jede Treppe der Burg."},
    "blueprint": {"title": "Summe mit Schleife", "text": "Zahlen von 1 bis n zusammenzählen.",
                  "code": "int summe = 0;\nfor (int i = 1; i <= 10; i++) {\n    summe += i;\n}\nSystem.out.println(summe);"},
})

Q.append({
    "id": "quest-tuer", "chapterId": "k2-gaenge", "title": "Die verschlossene Tür",
    "lessonId": "l06-methods", "topicId": "methods", "difficulty": 3,
    "story": "Die Tür oben im Turm ist verschlossen. Auf dem Schloss steht: „Ich öffne mich für jeden Schlüssel über 100, der durch 7 teilbar ist.“",
    "task": "Schreibe in der Klasse Tuer die Methode public static boolean unlock(int key). Sie gibt true zurück, wenn key größer als 100 und durch 7 teilbar ist – sonst false.",
    "concept": {"title": "Methoden mit Rückgabewert",
                "text": "Eine Methode ist ein benannter Befehl. Der Typ vor dem Namen sagt, was sie zurückgibt (boolean = true oder false). key % 7 ist der Rest beim Teilen durch 7 – ist er 0, geht die Teilung glatt auf.",
                "code": "public static boolean istGerade(int zahl) {\n    return zahl % 2 == 0;\n}"},
    "className": "Tuer",
    "starterCode": code("""
        public class Tuer {
            // Schreibe hier die Methode unlock
        }
    """),
    "solution": code("""
        public class Tuer {
            public static boolean unlock(int key) {
                return key > 100 && key % 7 == 0;
            }
        }
    """),
    "tests": [
        test("Der Schlüssel 105 öffnet", "105 ist größer als 100 und 105 % 7 == 0.", "Tuer.unlock(105)", value=True, visible=True),
        test("Der Schlüssel 98 öffnet nicht", "98 ist zwar durch 7 teilbar, aber nicht größer als 100 – beide Bedingungen müssen stimmen (&&).", "Tuer.unlock(98)", value=False, visible=True),
        test("Der Schlüssel 110 öffnet nicht", "110 ist größer als 100, aber 110 % 7 ist nicht 0.", "Tuer.unlock(110)", value=False),
        test("Der Schlüssel 700 öffnet", "700 = 7 · 100 – größer als 100 und durch 7 teilbar.", "Tuer.unlock(700)", value=True),
        test("Der Schlüssel 101 öffnet nicht", "„Größer als 100“ heißt > 100 – aber 101 ist nicht durch 7 teilbar.", "Tuer.unlock(101)", value=False),
    ],
    "success": "Mit einem Klicken springt das Schloss auf. Dahinter: eine Bibliothek, deren Bücher vor sich hin flüstern.",
    "reward": {"item": "Messingschlüssel", "symbol": "key.fill", "text": "Er passt in jedes Schloss, das rechnen kann."},
    "blueprint": {"title": "Methode mit boolean", "text": "Eine Prüfung als eigene Methode.",
                  "code": "static boolean istGross(int zahl) {\n    return zahl > 100;\n}"},
})

# ---------------------------------------------------------------------------------------- Kapitel 3
Q.append({
    "id": "quest-spiegelschrift", "chapterId": "k3-bibliothek", "title": "Die Spiegelschrift",
    "lessonId": "l07-arrays-strings", "topicId": "strings", "difficulty": 3,
    "story": "Das erste Buch ist in Spiegelschrift geschrieben: „ollaH“ steht da. Wer es rückwärts liest, versteht es.",
    "task": "Schreibe static String entschluesseln(String text): Die Methode gibt den Text rückwärts zurück – aus \"ollaH\" wird \"Hallo\".",
    "concept": {"title": "Texte Zeichen für Zeichen",
                "text": "text.length() ist die Länge, text.charAt(i) das Zeichen an Stelle i (gezählt ab 0). Eine Schleife, die von hinten nach vorn zählt, liest den Text rückwärts.",
                "code": 'String wort = "Byte";\nfor (int i = wort.length() - 1; i >= 0; i--) {\n    System.out.print(wort.charAt(i));\n}'},
    "className": "Spiegel",
    "starterCode": code("""
        public class Spiegel {
            static String entschluesseln(String text) {
                String ergebnis = "";
                // Von hinten nach vorn durch den Text laufen
                return ergebnis;
            }
        }
    """),
    "solution": code("""
        public class Spiegel {
            static String entschluesseln(String text) {
                String ergebnis = "";
                for (int i = text.length() - 1; i >= 0; i--) {
                    ergebnis = ergebnis + text.charAt(i);
                }
                return ergebnis;
            }
        }
    """),
    "tests": [
        test("„ollaH“ wird zu „Hallo“", "Beginne beim letzten Zeichen (text.length() - 1) und hänge jedes Zeichen hinten an.", "Spiegel.entschluesseln(\"ollaH\")", value="Hallo", visible=True),
        test("Ein einzelnes Zeichen bleibt", "Bei einem Zeichen läuft die Schleife genau einmal.", "Spiegel.entschluesseln(\"a\")", value="a"),
        test("Ein leerer Text bleibt leer", "Bei \"\" ist length() 0 – die Schleife läuft gar nicht.", "Spiegel.entschluesseln(\"\")", value=""),
        test("Auch Satzzeichen werden gespiegelt", "Jedes Zeichen zählt – auch ! und Leerzeichen.", "Spiegel.entschluesseln(\"!reiv\")", value="vier!"),
    ],
    "success": "Die Buchstaben ordnen sich, das Buch flüstert: „Im Regal liegt die größte Zahl der Burg.“",
    "reward": {"item": "Spiegelglas", "symbol": "circle.lefthalf.filled", "text": "Es liest jede Schrift rückwärts."},
    "blueprint": {"title": "Text rückwärts", "text": "Einen Text von hinten nach vorn durchlaufen.",
                  "code": 'String text = "Javahall";\nString rueckwaerts = "";\nfor (int i = text.length() - 1; i >= 0; i--) {\n    rueckwaerts += text.charAt(i);\n}'},
})

Q.append({
    "id": "quest-zahlenregal", "chapterId": "k3-bibliothek", "title": "Das Zahlenregal",
    "lessonId": "l07-arrays-strings", "topicId": "arrays", "difficulty": 3,
    "story": "Ein Regal voller Zahlenbücher. Das Buch mit der größten Zahl öffnet das Geheimfach – aber die Regale sind jedes Mal anders bestückt.",
    "task": "Schreibe static int groesstes(int[] zahlen): Die Methode gibt die größte Zahl im Array zurück. Das Array hat immer mindestens ein Element.",
    "concept": {"title": "Arrays durchsuchen",
                "text": "Ein Array speichert mehrere Werte unter einem Namen. Mit einer Schleife besuchst du jeden Platz und merkst dir den bisher größten Wert.",
                "code": "int[] zahlen = {4, 8, 1};\nint bisher = zahlen[0];\nfor (int zahl : zahlen) {\n    // zahl mit bisher vergleichen\n}"},
    "className": "Regal",
    "starterCode": code("""
        public class Regal {
            static int groesstes(int[] zahlen) {
                int bisher = zahlen[0];
                // Jede Zahl mit bisher vergleichen
                return bisher;
            }
        }
    """),
    "solution": code("""
        public class Regal {
            static int groesstes(int[] zahlen) {
                int bisher = zahlen[0];
                for (int zahl : zahlen) {
                    if (zahl > bisher) {
                        bisher = zahl;
                    }
                }
                return bisher;
            }
        }
    """),
    "tests": [
        test("In {3, 9, 2} ist 9 am größten", "Vergleiche jede Zahl mit bisher und merke dir die größere.", "Regal.groesstes(new int[] {3, 9, 2})", value=9, visible=True),
        test("Auch negative Zahlen klappen", "Starte mit zahlen[0], nicht mit 0 – sonst gewinnt bei lauter negativen Zahlen die 0.", "Regal.groesstes(new int[] {-5, -2, -9})", value=-2),
        test("Ein einziges Buch ist das größte", "Bei einem Element ist zahlen[0] schon das Ergebnis.", "Regal.groesstes(new int[] {7})", value=7),
        test("Die größte Zahl steht ganz hinten", "Läuft deine Schleife bis zum letzten Platz?", "Regal.groesstes(new int[] {1, 2, 3, 40})", value=40),
    ],
    "success": "Das Buch mit der 40 springt aus dem Regal. Im Geheimfach liegt ein Zettel in einer seltsamen Geheimsprache.",
    "reward": {"item": "Regalschlüssel", "symbol": "books.vertical.fill", "text": "Er öffnet jedes Geheimfach."},
    "blueprint": {"title": "Maximum suchen", "text": "Den größten Wert in einem Array finden.",
                  "code": "int[] werte = {12, 7, 30, 4};\nint max = werte[0];\nfor (int wert : werte) {\n    if (wert > max) {\n        max = wert;\n    }\n}"},
})

Q.append({
    "id": "quest-geheimsprache", "chapterId": "k3-bibliothek", "title": "Die Geheimsprache",
    "lessonId": "l07-arrays-strings", "topicId": "strings", "difficulty": 3,
    "story": "Auf dem Zettel steht: „Zähle die Vokale im Namen der Burg.“ Die Zahl ist das Losungswort für den Ausgang der Bibliothek.",
    "task": "Schreibe static int vokale(String wort): Die Methode zählt, wie viele Vokale (a, e, i, o, u) im Wort stehen – egal ob groß oder klein geschrieben.",
    "concept": {"title": "Text-Methoden",
                "text": "toLowerCase() macht alle Buchstaben klein – dann musst du nur noch kleine Vokale prüfen. Mit \"aeiou\".indexOf(zeichen) >= 0 fragst du, ob ein Zeichen ein Vokal ist.",
                "code": 'String klein = "Hallo".toLowerCase();\nchar zeichen = klein.charAt(1);\nboolean istVokal = "aeiou".indexOf(zeichen) >= 0;'},
    "className": "Geheimsprache",
    "starterCode": code("""
        public class Geheimsprache {
            static int vokale(String wort) {
                int anzahl = 0;
                // Jedes Zeichen prüfen
                return anzahl;
            }
        }
    """),
    "solution": code("""
        public class Geheimsprache {
            static int vokale(String wort) {
                int anzahl = 0;
                String klein = wort.toLowerCase();
                for (int i = 0; i < klein.length(); i++) {
                    if ("aeiou".indexOf(klein.charAt(i)) >= 0) {
                        anzahl++;
                    }
                }
                return anzahl;
            }
        }
    """),
    "tests": [
        test("„Javahall“ hat 3 Vokale", "a, a und a – zähle jedes Zeichen, das in \"aeiou\" vorkommt.", "Geheimsprache.vokale(\"Javahall\")", value=3, visible=True),
        test("„Burg“ hat 1 Vokal", "Nur das u ist ein Vokal.", "Geheimsprache.vokale(\"Burg\")", value=1),
        test("Großbuchstaben zählen mit", "Mach das Wort vorher mit toLowerCase() klein – dann zählt auch das große A.", "Geheimsprache.vokale(\"AEIOU\")", value=5),
        test("Ohne Vokale kommt 0 heraus", "Bei „xyz“ findet die Schleife nichts – die Zählung bleibt 0.", "Geheimsprache.vokale(\"xyz\")", value=0),
    ],
    "success": "„Drei!“, rufst du – und das Tor zur Werkstatt der Golems öffnet sich mit einem tiefen Brummen.",
    "reward": {"item": "Losungsrolle", "symbol": "scroll.fill", "text": "Sie kennt jedes Losungswort der Burg."},
    "blueprint": {"title": "Zeichen zählen", "text": "Bestimmte Zeichen in einem Text zählen.",
                  "code": 'String satz = "Java macht Spass";\nint leerzeichen = 0;\nfor (int i = 0; i < satz.length(); i++) {\n    if (satz.charAt(i) == \' \') {\n        leerzeichen++;\n    }\n}'},
})

# ---------------------------------------------------------------------------------------- Kapitel 4
Q.append({
    "id": "quest-golem", "chapterId": "k4-werkstatt", "title": "Der Golem erwacht",
    "lessonId": "l08-classes", "topicId": "oop", "difficulty": 3,
    "story": "In der Werkstatt steht ein Golem aus Lehm, starr und stumm. Meisterin Ada hat einen Bauplan hinterlassen: Jeder Golem hat einen Namen und 100 Energie. Arbeit kostet 30 Energie – aber nie unter 0.",
    "task": "Schreibe die Klasse Golem: ein Konstruktor Golem(String name), die Methoden getName() und getEnergie() und die Methode arbeiten(), die 30 Energie abzieht – aber nie unter 0.",
    "concept": {"title": "Klassen und Objekte",
                "text": "Eine Klasse ist ein Bauplan, mit new entsteht daraus ein Objekt. Felder speichern, was jedes Objekt hat; der Konstruktor setzt die Startwerte; Methoden beschreiben, was es kann.",
                "code": 'public class Hund {\n    private String name;\n\n    public Hund(String name) {\n        this.name = name;\n    }\n\n    public String getName() {\n        return name;\n    }\n}'},
    "className": "Golem",
    "starterCode": code("""
        public class Golem {
            private String name;
            private int energie = 100;

            // Konstruktor, getName, getEnergie und arbeiten
        }
    """),
    "solution": code("""
        public class Golem {
            private String name;
            private int energie = 100;

            public Golem(String name) {
                this.name = name;
            }

            public String getName() {
                return name;
            }

            public int getEnergie() {
                return energie;
            }

            public void arbeiten() {
                energie = energie - 30;
                if (energie < 0) {
                    energie = 0;
                }
            }
        }
    """),
    "tests": [
        test("Ein neuer Golem hat 100 Energie", "Das Feld energie startet mit 100 – getEnergie() gibt es zurück.", "new Golem(\"Rolf\").getEnergie()", value=100, visible=True),
        test("Der Golem kennt seinen Namen", "Der Konstruktor speichert den Namen: this.name = name;", "new Golem(\"Rolf\").getName()", value="Rolf", visible=True),
        test("Arbeit kostet 30 Energie", "arbeiten() zieht 30 von energie ab.", "g.getEnergie()", setup='Golem g = new Golem("Rolf");\ng.arbeiten();', value=70),
        test("Energie fällt nie unter 0", "Nach 4-mal Arbeiten wären es -20 – setze energie dann auf 0 zurück.",
             "g.getEnergie()", setup='Golem g = new Golem("Tok");\ng.arbeiten();\ng.arbeiten();\ng.arbeiten();\ng.arbeiten();', value=0),
    ],
    "success": "Die Augen des Golems glimmen auf. Er hebt einen Hammer – und wartet auf Befehle. Am Werktisch liegen Tränke, die niemand sortiert hat.",
    "reward": {"item": "Golemkern", "symbol": "cube.fill", "text": "Das Herz eines lebendigen Objekts."},
    "blueprint": {"title": "Klasse mit Konstruktor", "text": "Ein Bauplan für eigene Objekte.",
                  "code": 'class Held {\n    private String name;\n    private int leben = 3;\n\n    Held(String name) {\n        this.name = name;\n    }\n\n    int getLeben() {\n        return leben;\n    }\n}'},
})

Q.append({
    "id": "quest-traenke", "chapterId": "k4-werkstatt", "title": "Die Tränke",
    "lessonId": "l08-classes", "topicId": "oop", "difficulty": 3,
    "story": "Auf dem Werktisch stehen Tränke mit Namen und Stärke. Der Golem soll sie vergleichen – und jedes Etikett soll verraten, was drin ist.",
    "task": "Schreibe die Klasse Trank mit Konstruktor Trank(String name, int staerke), der Methode boolean istStaerkerAls(Trank anderer) und toString(), die zum Beispiel \"Heiltrank (Stärke 5)\" liefert.",
    "concept": {"title": "Objekte vergleichen und beschreiben",
                "text": "Eine Methode kann ein anderes Objekt derselben Klasse bekommen und mit ihm vergleichen. toString() legt fest, wie ein Objekt als Text aussieht – println nutzt sie automatisch.",
                "code": 'public String toString() {\n    return name + " (" + level + ")";\n}'},
    "className": "Trank",
    "starterCode": code("""
        public class Trank {
            private String name;
            private int staerke;

            // Konstruktor, istStaerkerAls und toString
        }
    """),
    "solution": code("""
        public class Trank {
            private String name;
            private int staerke;

            public Trank(String name, int staerke) {
                this.name = name;
                this.staerke = staerke;
            }

            public boolean istStaerkerAls(Trank anderer) {
                return staerke > anderer.staerke;
            }

            public String toString() {
                return name + " (Stärke " + staerke + ")";
            }
        }
    """),
    "tests": [
        test("Das Etikett nennt Name und Stärke", "toString() setzt zusammen: name + \" (Stärke \" + staerke + \")\".", "new Trank(\"Heiltrank\", 5)", text="Heiltrank (Stärke 5)", visible=True),
        test("Stärke 8 ist stärker als 5", "Vergleiche die eigene staerke mit anderer.staerke.", "new Trank(\"Feuertrank\", 8).istStaerkerAls(new Trank(\"Heiltrank\", 5))", value=True, visible=True),
        test("Stärke 2 ist nicht stärker als 5", "Ist die eigene Stärke kleiner, kommt false heraus.", "new Trank(\"Wasser\", 2).istStaerkerAls(new Trank(\"Heiltrank\", 5))", value=False),
        test("Gleich stark ist nicht stärker", "„Stärker“ heißt echt größer: > statt >=.", "new Trank(\"A\", 5).istStaerkerAls(new Trank(\"B\", 5))", value=False),
    ],
    "success": "Der Golem stellt die Tränke der Stärke nach auf. Hinter dem Regal öffnet sich ein Zwinger – drinnen schnauben seltsame Wesen.",
    "reward": {"item": "Heiltrank", "symbol": "drop.fill", "text": "Stärke 5 – für Notfälle."},
    "blueprint": {"title": "toString", "text": "Wie ein Objekt als Text aussieht.",
                  "code": 'class Punkt {\n    int x;\n    int y;\n\n    Punkt(int x, int y) {\n        this.x = x;\n        this.y = y;\n    }\n\n    public String toString() {\n        return "(" + x + ", " + y + ")";\n    }\n}'},
})

Q.append({
    "id": "quest-wesen", "chapterId": "k4-werkstatt", "title": "Die Wesen im Zwinger",
    "lessonId": "l09-inheritance", "topicId": "inheritance", "difficulty": 4,
    "story": "Im Zwinger leben Wesen aller Art. Jedes stellt sich gleich vor – „Glut sagt …“ –, aber jedes macht einen anderen Laut. Meisterin Ada hat die Klasse Wesen schon geschrieben.",
    "task": "Schreibe die Klassen Drache und Katze, beide erben von Wesen (extends). Ein Drache sagt \"Fauch!\", eine Katze \"Miau\" – überschreibe dafür laut(). Der Konstruktor gibt den Namen mit super(name) weiter.",
    "concept": {"title": "Vererbung",
                "text": "Mit extends übernimmt eine Klasse alles von ihrer Oberklasse. super(name) ruft deren Konstruktor auf, und mit @Override ersetzt du eine Methode durch eine eigene Fassung.",
                "code": 'class Hund extends Tier {\n    Hund(String name) {\n        super(name);\n    }\n\n    @Override\n    String laut() {\n        return "Wuff";\n    }\n}'},
    "className": "Zwinger",
    "starterCode": code("""
        public class Zwinger {
        }

        class Wesen {
            protected String name;

            Wesen(String name) {
                this.name = name;
            }

            String laut() {
                return "...";
            }

            String vorstellen() {
                return name + " sagt " + laut();
            }
        }

        // Drache und Katze erben von Wesen
    """),
    "solution": code("""
        public class Zwinger {
        }

        class Wesen {
            protected String name;

            Wesen(String name) {
                this.name = name;
            }

            String laut() {
                return "...";
            }

            String vorstellen() {
                return name + " sagt " + laut();
            }
        }

        class Drache extends Wesen {
            Drache(String name) {
                super(name);
            }

            @Override
            String laut() {
                return "Fauch!";
            }
        }

        class Katze extends Wesen {
            Katze(String name) {
                super(name);
            }

            @Override
            String laut() {
                return "Miau";
            }
        }
    """),
    "tests": [
        test("Der Drache stellt sich vor", "vorstellen() kommt von Wesen – sie ruft dein laut() auf.", "new Drache(\"Glut\").vorstellen()", value="Glut sagt Fauch!", visible=True),
        test("Die Katze miaut", "Überschreibe laut() in Katze mit return \"Miau\";", "new Katze(\"Mimi\").laut()", value="Miau"),
        test("Auch als Wesen bleibt der Drache ein Drache", "Wesen w = new Drache(…) ruft trotzdem das laut() des Drachen auf – das ist Polymorphie.",
             "w.laut()", setup='Wesen w = new Drache("Ember");', value="Fauch!"),
        test("Ein gewöhnliches Wesen bleibt still", "Ändere Wesen nicht – nur Drache und Katze bekommen eigene Laute.", "new Wesen(\"Geist\").laut()", value="..."),
    ],
    "success": "Der Drache faucht, die Katze miaut, beide gehorchen. Im Regal dahinter glimmt ein Zauberbuch.",
    "reward": {"item": "Drachenschuppe", "symbol": "flame.circle.fill", "text": "Warm und unzerbrechlich."},
    "blueprint": {"title": "Unterklasse", "text": "Eine Klasse erbt und überschreibt.",
                  "code": 'class Tier {\n    String laut() {\n        return "...";\n    }\n}\n\nclass Eule extends Tier {\n    @Override\n    String laut() {\n        return "Huhu";\n    }\n}'},
})

Q.append({
    "id": "quest-zauberbuch", "chapterId": "k4-werkstatt", "title": "Das Zauberbuch",
    "lessonId": "l09-inheritance", "topicId": "inheritance", "difficulty": 4,
    "story": "Das Zauberbuch verlangt einen Vertrag: Jeder Zauber muss sagen, was er kostet. Erst wenn das Buch die Kosten aller Zauber zusammenzählen kann, gibt es den Weg frei.",
    "task": "Das Interface Zauber verlangt int kosten(). Schreibe die Klassen Feuerball (kostet 5) und Heilung (kostet 3), die es implementieren, und die Methode static int gesamtkosten(Zauber[] zauber) in Zauberbuch.",
    "concept": {"title": "Interfaces",
                "text": "Ein Interface ist ein Vertrag: Es sagt, welche Methoden eine Klasse haben muss. Mit implements unterschreibt sie ihn. Ein Array vom Typ Zauber[] kann dann alle Arten von Zaubern halten.",
                "code": 'interface Form {\n    double flaeche();\n}\n\nclass Quadrat implements Form {\n    public double flaeche() {\n        return 4.0;\n    }\n}'},
    "className": "Zauberbuch",
    "starterCode": code("""
        public class Zauberbuch {
            static int gesamtkosten(Zauber[] zauber) {
                int summe = 0;
                // Die Kosten aller Zauber zusammenzählen
                return summe;
            }
        }

        interface Zauber {
            int kosten();
        }

        // Feuerball und Heilung implementieren Zauber
    """),
    "solution": code("""
        public class Zauberbuch {
            static int gesamtkosten(Zauber[] zauber) {
                int summe = 0;
                for (Zauber z : zauber) {
                    summe = summe + z.kosten();
                }
                return summe;
            }
        }

        interface Zauber {
            int kosten();
        }

        class Feuerball implements Zauber {
            public int kosten() {
                return 5;
            }
        }

        class Heilung implements Zauber {
            public int kosten() {
                return 3;
            }
        }
    """),
    "tests": [
        test("Ein Feuerball kostet 5", "Feuerball implements Zauber – und kosten() gibt 5 zurück. Die Methode muss public sein.", "new Feuerball().kosten()", value=5, visible=True),
        test("Eine Heilung kostet 3", "Heilung implementiert Zauber genauso – mit 3.", "new Heilung().kosten()", value=3),
        test("Das Buch zählt alle Zauber zusammen", "Laufe durch das Array und addiere z.kosten() – egal, welcher Zauber es ist.",
             "Zauberbuch.gesamtkosten(new Zauber[] {new Feuerball(), new Heilung(), new Feuerball()})", value=13),
        test("Ein leeres Buch kostet nichts", "Ohne Zauber bleibt die Summe 0.", "Zauberbuch.gesamtkosten(new Zauber[0])", value=0),
    ],
    "success": "Das Buch klappt auf, die Seiten leuchten. Eine Wendeltreppe aus Licht führt hinauf zum Thronsaal.",
    "reward": {"item": "Zauberbuch", "symbol": "book.closed.fill", "text": "Es kennt jeden Vertrag."},
    "blueprint": {"title": "Interface", "text": "Ein Vertrag für mehrere Klassen.",
                  "code": 'interface Gegenstand {\n    int wert();\n}\n\nclass Edelstein implements Gegenstand {\n    public int wert() {\n        return 50;\n    }\n}'},
})

# ---------------------------------------------------------------------------------------- Kapitel 5
Q.append({
    "id": "quest-schatzkammer", "chapterId": "k5-thronsaal", "title": "Die Schatzkammer",
    "lessonId": "l10-exceptions", "topicId": "exceptions", "difficulty": 4,
    "story": "Die Schatzkammer verwaltet das Gold der Burg. Wer zu viel abheben will – oder gar nichts –, soll einen deutlichen Fehler bekommen statt eines leeren Beutels.",
    "task": "Schreibe in Schatzkammer die Methode int abheben(int menge). Sie zieht menge vom Gold ab und gibt das restliche Gold zurück. Ist menge kleiner als 1 oder größer als das vorhandene Gold, wirft sie eine IllegalArgumentException.",
    "concept": {"title": "Exceptions werfen",
                "text": "Mit throw new IllegalArgumentException(\"…\") meldest du einen Fehler: Die Methode bricht sofort ab, und wer sie aufgerufen hat, erfährt, was schiefging.",
                "code": 'if (alter < 0) {\n    throw new IllegalArgumentException("Alter kann nicht negativ sein");\n}'},
    "className": "Schatzkammer",
    "starterCode": code("""
        public class Schatzkammer {
            private int gold;

            public Schatzkammer(int gold) {
                this.gold = gold;
            }

            public int abheben(int menge) {
                // Erst prüfen, dann abziehen
                return gold;
            }
        }
    """),
    "solution": code("""
        public class Schatzkammer {
            private int gold;

            public Schatzkammer(int gold) {
                this.gold = gold;
            }

            public int abheben(int menge) {
                if (menge < 1 || menge > gold) {
                    throw new IllegalArgumentException("Ungültige Menge: " + menge);
                }
                gold = gold - menge;
                return gold;
            }
        }
    """),
    "tests": [
        test("Abheben verringert das Gold", "Ziehe menge von gold ab und gib den Rest zurück.", "new Schatzkammer(100).abheben(30)", value=70, visible=True),
        test("Zu viel abheben ist ein Fehler", "Ist menge größer als gold: throw new IllegalArgumentException(…);", "new Schatzkammer(100).abheben(500)", exception="IllegalArgumentException", visible=True),
        test("Negatives Abheben ist ein Fehler", "Auch menge < 1 ist ungültig – prüfe beide Fälle mit ||.", "new Schatzkammer(100).abheben(-5)", exception="IllegalArgumentException"),
        test("Zweimal abheben rechnet weiter", "Speichere den neuen Stand in gold – sonst beginnt das zweite Abheben wieder bei 100.",
             "k.abheben(30)", setup="Schatzkammer k = new Schatzkammer(100);\nk.abheben(50);", value=20),
        test("Alles abheben ist erlaubt", "Genau so viel wie vorhanden ist erlaubt: > gold, nicht >= gold.", "new Schatzkammer(40).abheben(40)", value=0),
    ],
    "success": "Die Kammer klickt zufrieden. Die Goldmünzen bleiben, wo sie hingehören – Zeit, die Helden der Burg einzutragen.",
    "reward": {"item": "Goldbeutel", "symbol": "bag.fill", "text": "Er reißt nie – dank sauberer Prüfungen."},
    "blueprint": {"title": "Fehler melden", "text": "Ungültige Werte mit einer Exception ablehnen.",
                  "code": 'static int teilen(int a, int b) {\n    if (b == 0) {\n        throw new IllegalArgumentException("Teilen durch 0");\n    }\n    return a / b;\n}'},
})

Q.append({
    "id": "quest-heldenregister", "chapterId": "k5-thronsaal", "title": "Das Heldenregister",
    "lessonId": "l11-collections", "topicId": "collections", "difficulty": 4,
    "story": "Im Thronsaal liegt das Heldenregister. Jeder Held darf sich eintragen – aber nur einmal, sonst gibt es Streit um den Thron.",
    "task": "Schreibe die Klasse Gilde mit einer ArrayList<String> der Mitglieder: boolean aufnehmen(String name) trägt einen Namen ein und gibt true zurück – steht er schon drin, nicht noch einmal (dann false). Dazu int anzahl() und List<String> getMitglieder().",
    "concept": {"title": "Listen",
                "text": "Eine ArrayList wächst mit: add hängt an, contains fragt, ob etwas schon drin ist, size zählt die Einträge.",
                "code": 'List<String> namen = new ArrayList<>();\nnamen.add("Ada");\nboolean drin = namen.contains("Ada");\nint anzahl = namen.size();'},
    "className": "Gilde",
    "starterCode": code("""
        import java.util.ArrayList;
        import java.util.List;

        public class Gilde {
            private List<String> mitglieder = new ArrayList<>();

            // aufnehmen, anzahl und getMitglieder
        }
    """),
    "solution": code("""
        import java.util.ArrayList;
        import java.util.List;

        public class Gilde {
            private List<String> mitglieder = new ArrayList<>();

            public boolean aufnehmen(String name) {
                if (mitglieder.contains(name)) {
                    return false;
                }
                mitglieder.add(name);
                return true;
            }

            public int anzahl() {
                return mitglieder.size();
            }

            public List<String> getMitglieder() {
                return mitglieder;
            }
        }
    """),
    "tests": [
        test("Ein neuer Held wird aufgenommen", "aufnehmen fügt mit add hinzu und gibt true zurück.", "new Gilde().aufnehmen(\"Ada\")", value=True, visible=True),
        test("Niemand steht doppelt im Register", "Prüfe vorher mit contains, ob der Name schon drin ist – dann false.",
             "g.aufnehmen(\"Ada\")", setup='Gilde g = new Gilde();\ng.aufnehmen("Ada");', value=False, visible=True),
        test("Das Register zählt richtig", "anzahl() gibt mitglieder.size() zurück – doppelte Namen zählen nicht.",
             "g.anzahl()", setup='Gilde g = new Gilde();\ng.aufnehmen("Ada");\ng.aufnehmen("Bo");\ng.aufnehmen("Ada");', value=2),
        test("Die Reihenfolge bleibt erhalten", "getMitglieder() gibt die Liste zurück, in der Reihenfolge des Eintragens.",
             "g.getMitglieder()", setup='Gilde g = new Gilde();\ng.aufnehmen("Ada");\ng.aufnehmen("Bo");', text="[Ada, Bo]"),
    ],
    "success": "Die Namen leuchten im Register auf, keiner doppelt. Fehlt nur noch die Beute der Helden.",
    "reward": {"item": "Gildenring", "symbol": "circle.hexagongrid.fill", "text": "Jeder Held trägt ihn nur einmal."},
    "blueprint": {"title": "Liste ohne Doppelte", "text": "Nur aufnehmen, was noch nicht drin ist.",
                  "code": 'List<String> gaeste = new ArrayList<>();\nString neu = "Ada";\nif (!gaeste.contains(neu)) {\n    gaeste.add(neu);\n}'},
})

Q.append({
    "id": "quest-beute", "chapterId": "k5-thronsaal", "title": "Die Beute",
    "lessonId": "l11-collections", "topicId": "collections", "difficulty": 5,
    "story": "Zum Schluss bringen die Helden ihre Beute: Gold, Rubine, Gold, Kristalle … Der Thron erwacht erst, wenn jede Sorte richtig gezählt ist.",
    "task": "Schreibe static Map<String, Integer> zaehlen(List<String> beute): Die Methode zählt, wie oft jede Sorte vorkommt – zum Beispiel Gold → 2, Rubin → 1.",
    "concept": {"title": "Maps",
                "text": "Eine Map ordnet jedem Schlüssel einen Wert zu. getOrDefault(schluessel, 0) liefert den bisherigen Zählerstand oder 0, put speichert den neuen.",
                "code": 'Map<String, Integer> zaehler = new HashMap<>();\nzaehler.put("Gold", zaehler.getOrDefault("Gold", 0) + 1);'},
    "className": "Beute",
    "starterCode": code("""
        import java.util.HashMap;
        import java.util.List;
        import java.util.Map;

        public class Beute {
            static Map<String, Integer> zaehlen(List<String> beute) {
                Map<String, Integer> anzahl = new HashMap<>();
                // Für jede Sorte den Zähler um 1 erhöhen
                return anzahl;
            }
        }
    """),
    "solution": code("""
        import java.util.HashMap;
        import java.util.List;
        import java.util.Map;

        public class Beute {
            static Map<String, Integer> zaehlen(List<String> beute) {
                Map<String, Integer> anzahl = new HashMap<>();
                for (String sorte : beute) {
                    anzahl.put(sorte, anzahl.getOrDefault(sorte, 0) + 1);
                }
                return anzahl;
            }
        }
    """),
    "tests": [
        test("Zweimal Gold zählt 2", "Für jede Sorte: anzahl.put(sorte, anzahl.getOrDefault(sorte, 0) + 1);",
             "Beute.zaehlen(List.of(\"Gold\", \"Gold\", \"Rubin\")).get(\"Gold\")", value=2, visible=True),
        test("Einmal Rubin zählt 1", "Eine Sorte, die nur einmal vorkommt, hat den Zähler 1.",
             "Beute.zaehlen(List.of(\"Gold\", \"Gold\", \"Rubin\")).get(\"Rubin\")", value=1),
        test("Es gibt genau so viele Einträge wie Sorten", "Jede Sorte steht nur einmal als Schlüssel in der Map.",
             "Beute.zaehlen(List.of(\"Gold\", \"Kristall\", \"Gold\", \"Rubin\", \"Kristall\")).size()", value=3),
        test("Keine Beute, keine Einträge", "Bei einer leeren Liste bleibt die Map leer.", "Beute.zaehlen(List.of()).size()", value=0),
    ],
    "success": "Der Thron erwacht, die Burg leuchtet in allen Fenstern. Javahall läuft wieder – dank deines Codes. Meisterin Ada wäre stolz.",
    "reward": {"item": "Krone von Javahall", "symbol": "crown.fill", "text": "Für alle, die die Burg mit Code geweckt haben."},
    "blueprint": {"title": "Zählen mit Map", "text": "Wie oft kommt was vor?",
                  "code": 'Map<String, Integer> zaehler = new HashMap<>();\nfor (String wort : List.of("a", "b", "a")) {\n    zaehler.put(wort, zaehler.getOrDefault(wort, 0) + 1);\n}'},
})


def main():
    with open(ZIEL, "w", encoding="utf-8") as f:
        json.dump(BUCH, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"code_quests.json: {len(BUCH['chapters'])} Kapitel, {len(Q)} Quests, {sum(len(q['tests']) for q in Q)} Tests")


if __name__ == "__main__":
    main()
