"""Erzeugt Packages/JavaQuestKit/Sources/JavaQuestKit/Resources/java_course.json.

Aufruf: Tools/course/build_course.sh
Die Zeilen-Erklärungen schreibt die Swift-Engine CodeExplainer (über annotate/main.swift);
handgeschriebene Erklärungen in line_notes.py haben Vorrang.
"""
import json
import os
import subprocess
import sys

from authoring import *
from content_advanced import ADVANCED_TOPICS, ADVANCED_MODULES
from task_pool import POOL
from pool_basics import POOL_BASICS
from pool_advanced import POOL_ADVANCED
from pool_deep import POOL_DEEP
from pool_practice import POOL_PRACTICE
from pool_extra import POOL_EXTRA
from pool_gaps import POOL_GAPS
from pool_level_a import POOL_LEVEL_A
from pool_level_b import POOL_LEVEL_B
from pool_level_c import POOL_LEVEL_C
from pool_variety import POOL_VARIETY
from pool_depth import POOL_DEPTH
from placement import PLACEMENT_POOL
from uml_content import UML_MODULE, UML_POOL, UML_TOPICS

topics = [
    ("syntax", "Programmaufbau", "curlybraces", "Klassen, main-Methode, Ausgabe und Kommentare"),
    ("variables", "Variablen & Datentypen", "shippingbox.fill", "Primitive Typen, String, final und var"),
    ("operators", "Operatoren", "plus.forwardslash.minus", "Rechnen, Vergleichen und logische Verknüpfung"),
    ("conditionals", "Bedingungen", "arrow.triangle.branch", "if, else if und switch"),
    ("loops", "Schleifen", "repeat", "for, while, do-while, break und continue"),
    ("methods", "Methoden", "function", "Parameter, Rückgabewerte und Überladen"),
    ("arrays", "Arrays", "square.grid.3x1.below.line.grid.1x2", "Feste Listen, Indizes und for-each"),
    ("strings", "Strings", "textformat", "Textmethoden und Vergleich mit equals"),
    ("oop", "Klassen & Objekte", "cube.fill", "Felder, Konstruktoren, this und Kapselung"),
    ("inheritance", "Vererbung & Interfaces", "rectangle.connected.to.line.below", "extends, Polymorphie, abstract und Interfaces"),
    ("exceptions", "Exceptions", "exclamationmark.triangle.fill", "try, catch, finally und throw"),
    ("collections", "Collections", "tray.full.fill", "ArrayList, HashMap und Co."),
    ("generics", "Generics", "chevron.left.forwardslash.chevron.right", "Typparameter und generische Methoden"),
    ("lambdas", "Lambdas & Streams", "wand.and.stars", "Funktionen als Werte und Stream-Pipelines"),
    ("modern", "Modernes Java", "sparkles", "Records, Optional, switch-Ausdrücke und Pattern Matching"),
]

# ---------------------------------------------------------------- Modul 1
l1 = lesson("l01-hello", "Hallo, Java!", "Wie ein Java-Programm aufgebaut ist und wie du Text ausgibst.",
            ["syntax"], 5, [
    card("Dein erstes Programm",
         "Java-Code steckt immer in einer Klasse. Die Ausführung beginnt in der Methode main – sie ist der Einstiegspunkt jedes Programms.",
         code="""
         public class Hallo {
             public static void main(String[] args) {
                 System.out.println("Hallo, Java!");
             }
         }
         """,
         tip="Die Datei muss so heißen wie die öffentliche Klasse: Hallo.java."),
    card("Ausgabe mit println",
         "System.out.println(…) gibt etwas aus und beginnt danach eine neue Zeile. System.out.print(…) bleibt in derselben Zeile. Text steht in doppelten Anführungszeichen, Zahlen ohne.",
         code="""
         System.out.print("Hallo ");
         System.out.println("Welt");
         System.out.println(3 + 4);
         // Ausgabe:
         // Hallo Welt
         // 7
         """),
    card("Semikolon & Kommentare",
         "Jede Anweisung endet mit einem Semikolon. Kommentare ignoriert der Compiler: // bis zum Zeilenende, /* … */ über mehrere Zeilen.",
         code="""
         // Das ist ein Kommentar
         System.out.println("Semikolon nicht vergessen!");
         """,
         warning="Java unterscheidet Groß- und Kleinschreibung: system.out.println funktioniert nicht."),
], [
    mc("t01-1", "syntax", 1, "Wo beginnt die Ausführung eines Java-Programms?",
       ["In der Methode main", "In der ersten Zeile der Datei", "In einer Methode namens start", "Im Konstruktor der Klasse"],
       "Die JVM sucht die Methode public static void main(String[] args) und startet dort."),
    mc("t01-2", "syntax", 1, "Womit endet in Java jede Anweisung?",
       ["Mit einem Semikolon ;", "Mit einem Punkt .", "Mit einem Doppelpunkt :", "Mit einem Zeilenumbruch"],
       "Das Semikolon schließt eine Anweisung ab. Zeilenumbrüche sind für den Compiler bedeutungslos."),
    fill("t01-3", "syntax", 2, "Ergänze die Zeile, damit „Hallo, Java!“ ausgegeben wird.",
         'System.out.{{0}}("Hallo, Java!");', [["println", "print"]],
         "System.out.println gibt den Text aus und beendet die Zeile.",
         hint="Die Methode heißt „print line“ – nur zusammengeschrieben und abgekürzt.",
         verify={"output": "Hallo, Java!"}),
    out("t01-4", "syntax", 2, "Was gibt dieses Programm aus?",
        """
        System.out.print("Java ");
        System.out.print("macht ");
        System.out.println("Spaß");
        System.out.println("!");
        """,
        """
        Java macht Spaß
        !
        """,
        "print bleibt in der Zeile, println bricht danach um. Deshalb landet das Ausrufezeichen in Zeile 2.",
        hint="Achte darauf, welche Aufrufe einen Zeilenumbruch erzeugen."),
    code("t01-5", "syntax", 3, "Schreibe eine Anweisung, die genau den Text „Ich lerne Java“ ausgibt.",
         "// Deine Anweisung hier",
         'System.out.println("Ich lerne Java");',
         [req(r"System\.out\.println\s*\(", "Nutze System.out.println(…)."),
          req(r'"Ich lerne Java"', "Gib genau den Text „Ich lerne Java“ aus.", scope="raw")],
         "Text gehört in doppelte Anführungszeichen, die Anweisung endet mit einem Semikolon.",
         expected="Ich lerne Java",
         hint="System.out.println(\"…\"); – und das Semikolon am Ende."),
])

l2 = lesson("l02-variables", "Variablen & Datentypen", "Werte speichern, verändern und den passenden Typ wählen.",
            ["variables"], 6, [
    card("Variablen speichern Werte",
         "Eine Variable hat einen Typ, einen Namen und einen Wert. Ganze Zahlen sind int, Kommazahlen double, Wahrheitswerte boolean, einzelne Zeichen char und Texte String.",
         code="""
         int alter = 25;
         double preis = 9.99;
         boolean aktiv = true;
         char note = 'A';
         String name = "Ada";
         """,
         tip="String wird großgeschrieben – es ist eine Klasse, kein primitiver Typ."),
    card("Werte ändern & Konstanten",
         "Eine Variable kann später einen neuen Wert bekommen. Mit final wird sie zur Konstanten. Mit var leitet Java den Typ lokaler Variablen selbst ab.",
         code="""
         alter = 26;              // neuer Wert
         final int MAX = 10;      // unveränderlich
         var stadt = "Berlin";    // Typ: String
         """,
         warning="int reicht nur bis etwa 2,1 Milliarden. Für größere Zahlen nutzt du long."),
], [
    mc("t02-1", "variables", 1, "Welcher Datentyp speichert eine ganze Zahl?",
       ["int", "String", "boolean", "double"],
       "int steht für integer, also ganze Zahlen ohne Nachkommastellen."),
    fill("t02-2", "variables", 2, "Deklariere eine Variable für einen Preis mit Nachkommastellen.",
         "{{0}} preis = 4.99;", [["double"]],
         "Kommazahlen speicherst du in double. float würde ein f am Ende verlangen (4.99f).",
         hint="Der Typ für Kommazahlen mit doppelter Genauigkeit."),
    out("t02-3", "variables", 3, "Was wird ausgegeben?",
        """
        int punkte = 10;
        punkte = punkte + 5;
        String name = "Ada";
        System.out.println(name + " hat " + punkte + " Punkte");
        """,
        "Ada hat 15 Punkte",
        "punkte wird auf 15 erhöht. Mit + werden Strings und Zahlen zu einem Text verbunden."),
    mc("t02-4", "variables", 4, "Welche Zeile lässt sich NICHT kompilieren?",
       ["final int max = 10; max = 20;", "double d = 5;", "long l = 100;", 'var text = "Hi";'],
       "Eine final-Variable darf nach der Initialisierung keinen neuen Wert bekommen. double d = 5 ist erlaubt, weil int automatisch zu double erweitert wird."),
    code("t02-5", "variables", 5, "Tausche die Werte von a und b mithilfe einer Hilfsvariablen tmp. Die Ausgabe soll danach 7 3 lauten.",
         """
         int a = 3;
         int b = 7;
         // Tausche hier die Werte

         System.out.println(a + " " + b);
         """,
         """
         int a = 3;
         int b = 7;
         int tmp = a;
         a = b;
         b = tmp;
         System.out.println(a + " " + b);
         """,
         [req(r"\b(int|var)\s+tmp\s*=\s*[ab]\s*;", "Merke dir einen der Werte in einer Hilfsvariablen tmp."),
          req(r"\b([ab])\s*=\s*(?!\1)[ab]\s*;", "Überschreibe eine Variable mit der anderen."),
          req(r"\b[ab]\s*=\s*tmp\s*;", "Hole den gemerkten Wert aus tmp zurück."),
          forbid(r"(?m)^\s*[ab]\s*=\s*[0-9]", "Bitte keine Zahlen eintragen – tausche über die Variablen.")],
         "Ohne tmp würde der erste Wert beim Überschreiben verloren gehen: tmp = a; a = b; b = tmp;",
         expected="7 3",
         hint="Drei Zuweisungen: sichern, überschreiben, zurückholen."),
])

l3 = lesson("l03-operators", "Rechnen & Operatoren", "Arithmetik, Kurzschreibweisen und logische Ausdrücke.",
            ["operators"], 6, [
    card("Rechnen mit Zahlen",
         "Java kennt + - * / und % (Rest). Achtung: Teilst du zwei ganze Zahlen, ist das Ergebnis wieder ganzzahlig – die Nachkommastellen fallen weg.",
         code="""
         System.out.println(7 / 2);    // 3
         System.out.println(7 % 2);    // 1
         System.out.println(7.0 / 2);  // 3.5
         """),
    card("Kurzschreibweisen",
         "x += 5 ist die Kurzform von x = x + 5. Mit ++ und -- erhöhst bzw. verringerst du um genau 1.",
         code="""
         int x = 10;
         x += 5;   // 15
         x *= 2;   // 30
         x++;      // 31
         """),
    card("Vergleichen & Verknüpfen",
         "Vergleiche (==, !=, <, >, <=, >=) liefern einen boolean. Mit && (und), || (oder) und ! (nicht) verknüpfst du Bedingungen. && bindet stärker als ||.",
         code="""
         int alter = 20;
         boolean erwachsen = alter >= 18;          // true
         boolean teen = alter > 12 && alter < 20;  // false
         """,
         warning="= weist einen Wert zu, == vergleicht zwei Werte."),
], [
    mc("t03-1", "operators", 1, "Was ergibt 7 % 3?",
       ["1", "2", "2.33", "0"],
       "% liefert den Rest der Division: 7 = 2 · 3 + 1."),
    out("t03-2", "operators", 2, "Was gibt dieses Programm aus?",
        """
        int a = 7;
        int b = 2;
        System.out.println(a / b);
        System.out.println(a % b);
        """,
        """
        3
        1
        """,
        "Ganzzahldivision schneidet ab: 7 / 2 = 3. Der Rest ist 1."),
    fill("t03-3", "operators", 3, "Erhöhe zaehler um genau 1 – mit dem kürzesten Operator.",
         """
         int zaehler = 5;
         zaehler{{0}};
         System.out.println(zaehler);
         """,
         [["++", "+=1"]],
         "zaehler++ erhöht den Wert um 1. zaehler += 1 wäre gleichwertig, nur länger.",
         verify={"output": "6"}),
    out("t03-4", "operators", 4, "Welche zwei Zeilen erscheinen?",
        """
        int x = 5;
        x += 3;
        x *= 2;
        boolean ok = x > 10 && x % 2 == 0;
        System.out.println(x);
        System.out.println(ok);
        """,
        """
        16
        true
        """,
        "x wird 8, dann 16. 16 > 10 und 16 ist gerade – beide Bedingungen sind wahr."),
    code("t03-5", "operators", 5,
         "Berechne den Durchschnitt der drei Noten als Kommazahl, speichere ihn in einer double-Variablen und gib ihn aus. Vorsicht vor der Ganzzahldivision!",
         """
         int n1 = 2;
         int n2 = 3;
         int n3 = 3;
         // Durchschnitt als double berechnen und ausgeben
         """,
         """
         int n1 = 2;
         int n2 = 3;
         int n3 = 3;
         double schnitt = (n1 + n2 + n3) / 3.0;
         System.out.println(schnitt);
         """,
         [req(r"\bdouble\s+\w+\s*=", "Speichere das Ergebnis in einer double-Variablen."),
          req(r"n1\s*\+\s*n2\s*\+\s*n3", "Addiere alle drei Noten."),
          req(r"\(double\)|/\s*3\.|/\s*3[dDfF]\b", "Verhindere die Ganzzahldivision, z. B. mit / 3.0 oder einem (double)-Cast."),
          req(r"System\.out\.print", "Gib den Durchschnitt aus."),
          forbid(r"2\.6", "Bitte das Ergebnis berechnen lassen, nicht eintippen.")],
         "(n1 + n2 + n3) / 3 wäre eine Ganzzahldivision und ergäbe 2. Mit 3.0 rechnet Java in double.",
         expected="2.6666666666666665",
         hint="Teile durch 3.0 statt durch 3."),
])

# ---------------------------------------------------------------- Modul 2
l4 = lesson("l04-conditionals", "Entscheidungen mit if & switch", "Programme verzweigen lassen – je nach Bedingung.",
            ["conditionals"], 7, [
    card("if und else",
         "Mit if führst du Code nur aus, wenn eine Bedingung wahr ist. Der else-Zweig läuft sonst.",
         code="""
         int temperatur = 28;
         if (temperatur > 25) {
             System.out.println("Ab ins Freibad!");
         } else {
             System.out.println("Lieber ins Kino.");
         }
         """),
    card("else if – mehrere Fälle",
         "Mit else if prüfst du weitere Bedingungen nacheinander. Nur der erste zutreffende Zweig wird ausgeführt – die Reihenfolge zählt.",
         code="""
         if (punkte >= 90) {
             System.out.println("sehr gut");
         } else if (punkte >= 70) {
             System.out.println("gut");
         } else {
             System.out.println("weiter üben");
         }
         """),
    card("switch",
         "switch wählt anhand eines Werts einen Fall. Mit der Pfeil-Syntax brauchst du kein break, und mehrere Werte lassen sich mit Komma zusammenfassen.",
         code="""
         String tag = "SA";
         switch (tag) {
             case "SA", "SO" -> System.out.println("Wochenende");
             default -> System.out.println("Arbeitstag");
         }
         """,
         tip="Die Pfeil-Syntax gibt es seit Java 14."),
], [
    mc("t04-1", "conditionals", 1, "Was gehört in die Klammern von if (…)?",
       ["Eine Bedingung vom Typ boolean", "Eine beliebige Zahl", "Ein String", "Der Name einer Methode"],
       "if erwartet einen booleschen Ausdruck, der true oder false ergibt."),
    out("t04-2", "conditionals", 2, "Was wird ausgegeben?",
        """
        int alter = 16;
        if (alter >= 18) {
            System.out.println("Volljährig");
        } else {
            System.out.println("Minderjährig");
        }
        """,
        "Minderjährig",
        "16 >= 18 ist false, deshalb läuft der else-Zweig."),
    fill("t04-3", "conditionals", 3, "Ergänze die Bedingung: Eine Zahl ist gerade, wenn der Rest bei Division durch 2 null ist.",
         """
         int zahl = 14;
         if (zahl {{0}} 2 == 0) {
             System.out.println("gerade");
         }
         """,
         [["%"]],
         "zahl % 2 liefert den Rest. Ist er 0, ist die Zahl gerade.",
         verify={"output": "gerade"}),
    out("t04-4", "conditionals", 4, "Was gibt die Kette aus?",
        """
        int punkte = 72;
        if (punkte >= 90) {
            System.out.println("sehr gut");
        } else if (punkte >= 70) {
            System.out.println("gut");
        } else if (punkte >= 50) {
            System.out.println("bestanden");
        } else {
            System.out.println("nicht bestanden");
        }
        """,
        "gut",
        "72 >= 90 ist falsch, 72 >= 70 ist wahr. Danach wird nichts mehr geprüft."),
    code("t04-5", "conditionals", 5,
         "Schreibe ein switch mit Pfeil-Syntax: Für monat 12, 1 und 2 soll „Winter“ ausgegeben werden, für alle anderen Werte „Kein Winter“.",
         """
         int monat = 1;
         // switch hier
         """,
         """
         int monat = 1;
         switch (monat) {
             case 12, 1, 2 -> System.out.println("Winter");
             default -> System.out.println("Kein Winter");
         }
         """,
         [req(r"switch\s*\(\s*monat\s*\)", "Nutze switch (monat)."),
          req(r"case\s+[^:>]*->", "Verwende die Pfeil-Syntax case … ->."),
          req(r"case[^-]*\b12\b", "Behandle den Dezember (12)."),
          req(r"default\s*->", "Denke an den default-Fall."),
          req(r'"Winter"', "Gib „Winter“ aus.", scope="raw"),
          req(r'"Kein Winter"', "Gib sonst „Kein Winter“ aus.", scope="raw")],
         "case 12, 1, 2 fasst drei Werte zusammen, default fängt alle übrigen ab.",
         expected="Winter",
         hint="case 12, 1, 2 -> …; default -> …;"),
])

l5 = lesson("l05-loops", "Schleifen", "Code wiederholen – gezählt oder solange eine Bedingung gilt.",
            ["loops"], 7, [
    card("Die for-Schleife",
         "Eine for-Schleife hat drei Teile: Start, Bedingung und Schritt. Sie eignet sich, wenn du weißt, wie oft etwas passieren soll.",
         code="""
         for (int i = 1; i <= 3; i++) {
             System.out.println("Runde " + i);
         }
         """),
    card("while & do-while",
         "while wiederholt, solange die Bedingung wahr ist. do-while prüft erst am Ende und läuft deshalb mindestens einmal.",
         code="""
         int n = 3;
         while (n > 0) {
             System.out.println(n);
             n--;
         }
         """),
    card("break & continue",
         "break beendet die Schleife sofort. continue überspringt den Rest des aktuellen Durchlaufs.",
         code="""
         for (int i = 1; i <= 10; i++) {
             if (i % 2 == 0) continue; // gerade überspringen
             if (i > 5) break;         // ab 6 Schluss
             System.out.println(i);    // 1 3 5
         }
         """,
         warning="Wird die Bedingung nie falsch, entsteht eine Endlosschleife."),
], [
    mc("t05-1", "loops", 1, "Wie oft läuft for (int i = 0; i < 3; i++)?",
       ["3-mal", "2-mal", "4-mal", "Endlos"],
       "i nimmt die Werte 0, 1 und 2 an – bei 3 ist die Bedingung falsch."),
    out("t05-2", "loops", 2, "Was gibt die Schleife aus?",
        """
        for (int i = 1; i <= 3; i++) {
            System.out.print(i + " ");
        }
        """,
        "1 2 3",
        "print schreibt alles in eine Zeile, getrennt durch Leerzeichen."),
    fill("t05-3", "loops", 3, "Ergänze die while-Schleife so, dass sie von 5 bis 1 herunterzählt.",
         """
         int n = 5;
         while (n {{0}} 0) {
             System.out.println(n);
             n{{1}};
         }
         """,
         [[">", "!="], ["--", "-=1"]],
         "Die Schleife läuft, solange n größer als 0 ist, und verringert n in jedem Durchlauf.",
         verify={"output": "5\n4\n3\n2\n1"}),
    out("t05-4", "loops", 4, "Welchen Wert hat summe am Ende?",
        """
        int summe = 0;
        for (int i = 1; i <= 10; i++) {
            if (i % 2 == 0) {
                continue;
            }
            if (i > 7) {
                break;
            }
            summe += i;
        }
        System.out.println(summe);
        """,
        "16",
        "Gerade Zahlen werden übersprungen. Addiert werden 1, 3, 5 und 7; bei 9 greift break."),
    code("t05-5", "loops", 5, "Berechne mit einer Schleife die Summe der Zahlen von 1 bis 100 und gib sie aus.",
         """
         int summe = 0;
         // Schleife hier

         System.out.println(summe);
         """,
         """
         int summe = 0;
         for (int i = 1; i <= 100; i++) {
             summe += i;
         }
         System.out.println(summe);
         """,
         [req(r"\b(for|while)\s*\(", "Nutze eine for- oder while-Schleife."),
          req(r"summe\s*(\+=|=\s*summe\s*\+)", "Addiere in jedem Durchlauf zu summe."),
          req(r"\b100\b", "Die Schleife soll bis 100 laufen."),
          forbid(r"5050", "Nicht schummeln – lass Java rechnen.")],
         "Die Schleife addiert i = 1 bis 100 auf. Das Ergebnis ist 5050.",
         expected="5050",
         hint="for (int i = 1; i <= 100; i++) { summe += i; }"),
])

l6 = lesson("l06-methods", "Methoden", "Code in wiederverwendbare Bausteine verpacken.",
            ["methods"], 7, [
    card("Methoden bündeln Code",
         "Eine Methode hat einen Rückgabetyp, einen Namen und Parameter. Mit return gibt sie ein Ergebnis zurück.",
         code="""
         static int quadrat(int x) {
             return x * x;
         }

         // Aufruf: quadrat(4) liefert 16
         """),
    card("void und mehrere Parameter",
         "void bedeutet: Die Methode gibt nichts zurück. Parameter trennst du mit Komma, jeder hat seinen eigenen Typ.",
         code="""
         static void begruesse(String name, int mal) {
             for (int i = 0; i < mal; i++) {
                 System.out.println("Hallo " + name);
             }
         }
         """),
    card("Überladen",
         "Mehrere Methoden dürfen denselben Namen haben, wenn sich ihre Parameterlisten unterscheiden. Java wählt anhand der Argumente die passende Variante.",
         code="""
         static int summe(int a, int b) { return a + b; }
         static int summe(int a, int b, int c) { return a + b + c; }
         """,
         tip="static-Methoden kannst du direkt aus main aufrufen – ohne Objekt."),
], [
    mc("t06-1", "methods", 1, "Was bedeutet void als Rückgabetyp?",
       ["Die Methode gibt keinen Wert zurück", "Die Methode ist leer", "Die Methode ist privat", "Die Methode gibt 0 zurück"],
       "void heißt „nichts“ – ein return ohne Wert ist erlaubt, aber keiner mit Wert."),
    out("t06-2", "methods", 2, "Was gibt main aus?",
        """
        static int doppelt(int x) {
            return x * 2;
        }

        public static void main(String[] args) {
            System.out.println(doppelt(4) + doppelt(1));
        }
        """,
        "10",
        "doppelt(4) liefert 8, doppelt(1) liefert 2 – zusammen 10.",
        ctx="members"),
    fill("t06-3", "methods", 3, "Ergänze Rückgabetyp und Rückgabe der Methode maximum.",
         """
         static {{0}} maximum(int a, int b) {
             if (a > b) {
                 {{1}} a;
             }
             return b;
         }
         """,
         [["int"], ["return"]],
         "Die Methode liefert eine ganze Zahl (int) und gibt sie mit return zurück.",
         ctx="members",
         verify={"main": "System.out.println(maximum(3, 9));", "output": "9"}),
    mc("t06-4", "methods", 4, 'Welche Variante wird bei gruss("Ada", 3) aufgerufen?',
       ["Die Variante mit (String name, int mal)", "Die Variante mit (String name)", "Beide nacheinander", "Keine – der Code kompiliert nicht"],
       "Java wählt die Überladung, deren Parameterliste zu den Argumenten passt: String und int.",
       code="""
       static void gruss(String name) {
           System.out.println("Hallo " + name);
       }

       static void gruss(String name, int mal) {
           for (int i = 0; i < mal; i++) {
               System.out.println("Hi " + name);
           }
       }
       """,
       ctx="members"),
    code("t06-5", "methods", 5,
         "Vervollständige die Methode istGerade: Sie soll true zurückgeben, wenn zahl gerade ist, sonst false.",
         """
         static boolean istGerade(int zahl) {
             // dein Code
         }
         """,
         """
         static boolean istGerade(int zahl) {
             return zahl % 2 == 0;
         }
         """,
         [req(r"static\s+boolean\s+istGerade\s*\(\s*int\s+\w+\s*\)", "Die Signatur lautet static boolean istGerade(int zahl)."),
          req(r"\breturn\b", "Gib das Ergebnis mit return zurück."),
          req(r"%\s*2", "Prüfe den Rest bei Division durch 2.")],
         "Der Vergleich zahl % 2 == 0 ist selbst schon ein boolean und kann direkt zurückgegeben werden.",
         ctx="members",
         hint="return zahl % 2 == 0;",
         verify={"main": 'System.out.println(istGerade(4) + " " + istGerade(7));', "output": "true false"}),
])

# ---------------------------------------------------------------- Modul 3
l7 = lesson("l07-arrays-strings", "Arrays & Strings", "Mehrere Werte speichern und mit Text arbeiten.",
            ["arrays", "strings"], 8, [
    card("Arrays: feste Listen",
         "Ein Array speichert mehrere Werte gleichen Typs. Der Index beginnt bei 0, length liefert die Anzahl.",
         code="""
         int[] zahlen = {4, 8, 15};
         System.out.println(zahlen[0]);      // 4
         System.out.println(zahlen.length);  // 3
         int[] leer = new int[5];            // fünf Nullen
         """,
         warning="Der letzte gültige Index ist length - 1. Alles darüber wirft eine ArrayIndexOutOfBoundsException."),
    card("Durch Arrays laufen",
         "Mit der for-each-Schleife gehst du alle Elemente durch, ohne dich um Indizes zu kümmern.",
         code="""
         for (int z : zahlen) {
             System.out.println(z);
         }
         """),
    card("Strings",
         "Strings bringen viele Methoden mit: length(), charAt(i), toUpperCase(), substring(von, bis) und equals(…).",
         code="""
         String s = "Kaffee";
         s.length();          // 6
         s.charAt(0);         // 'K'
         s.substring(0, 3);   // "Kaf"
         """,
         warning="Vergleiche Strings mit equals, nicht mit ==. == prüft, ob es dasselbe Objekt ist."),
], [
    mc("t07-1", "arrays", 1, "Welchen Index hat das erste Element eines Arrays?",
       ["0", "1", "-1", "Das hängt von der Länge ab"],
       "Java zählt Indizes ab 0."),
    out("t07-2", "strings", 2, "Was wird ausgegeben?",
        """
        String wort = "Kaffee";
        System.out.println(wort.length());
        System.out.println(wort.charAt(1));
        System.out.println(wort.toUpperCase());
        """,
        """
        6
        a
        KAFFEE
        """,
        "Das Wort hat 6 Zeichen, Index 1 ist das zweite Zeichen 'a'."),
    fill("t07-3", "arrays", 3, "Ergänze die for-each-Schleife, die alle Werte summiert.",
         """
         int[] werte = {3, 5, 9};
         int summe = 0;
         for (int w {{0}} werte) {
             summe += w;
         }
         System.out.println(summe);
         """,
         [[":"]],
         "Die for-each-Schleife liest sich als „für jedes w in werte“ – geschrieben mit Doppelpunkt.",
         verify={"output": "17"}),
    out("t07-4", "strings", 4, "Welche drei Zeilen erscheinen?",
        """
        String a = "Java";
        String b = new String("Java");
        System.out.println(a == b);
        System.out.println(a.equals(b));
        System.out.println("Programmieren".substring(0, 7));
        """,
        """
        false
        true
        Program
        """,
        "new String erzeugt ein neues Objekt, deshalb liefert == false. equals vergleicht den Inhalt. substring(0, 7) liefert die Zeichen 0 bis 6."),
    code("t07-5", "arrays", 5, "Finde das größte Element im Array zahlen und gib es aus – ohne das Array zu sortieren.",
         """
         int[] zahlen = {12, 45, 7, 23, 38};
         int max = zahlen[0];
         // Schleife hier

         System.out.println(max);
         """,
         """
         int[] zahlen = {12, 45, 7, 23, 38};
         int max = zahlen[0];
         for (int z : zahlen) {
             if (z > max) {
                 max = z;
             }
         }
         System.out.println(max);
         """,
         [req(r"\b(for|while)\s*\(", "Durchlaufe das Array mit einer Schleife."),
          req(r">\s*max|max\s*<|Math\.max", "Vergleiche jedes Element mit max."),
          req(r"\bmax\s*=\s*(?!zahlen\s*\[\s*0\s*\])[A-Za-z_]", "Aktualisiere max, wenn du einen größeren Wert findest."),
          forbid(r"Arrays\.sort", "Bitte ohne Sortieren lösen."),
          forbid(r"println\s*\(\s*45\s*\)|max\s*=\s*45\b", "Nicht das Ergebnis eintragen – lass es suchen.")],
         "Du merkst dir den bisher größten Wert und ersetzt ihn, sobald ein größerer auftaucht.",
         expected="45",
         hint="for (int z : zahlen) { if (z > max) { max = z; } }"),
])

l8 = lesson("l08-classes", "Klassen & Objekte", "Eigene Typen mit Zustand und Verhalten bauen.",
            ["oop"], 8, [
    card("Klassen sind Baupläne",
         "Eine Klasse beschreibt Felder (Zustand) und Methoden (Verhalten). Mit new erzeugst du daraus Objekte.",
         code="""
         class Hund {
             String name;

             void bellen() {
                 System.out.println(name + " sagt Wuff!");
             }
         }

         Hund bello = new Hund();
         bello.name = "Bello";
         bello.bellen();
         """),
    card("Konstruktoren & this",
         "Ein Konstruktor heißt wie die Klasse und hat keinen Rückgabetyp. this verweist auf das aktuelle Objekt – praktisch, wenn Parameter und Feld gleich heißen.",
         code="""
         class Hund {
             private String name;

             Hund(String name) {
                 this.name = name;
             }
         }
         """),
    card("Kapselung",
         "Felder werden meist private gemacht. Zugriff gibt es über Methoden wie getName(). So kontrolliert die Klasse selbst, welche Werte gültig sind.",
         code="""
         String getName() {
             return name;
         }
         """,
         tip="Faustregel: Felder private, Methoden nur so öffentlich wie nötig."),
], [
    mc("t08-1", "oop", 1, "Womit erzeugst du ein neues Objekt der Klasse Auto?",
       ["new Auto()", "Auto.create()", "Auto()", "make Auto"],
       "Das Schlüsselwort new ruft den Konstruktor auf und legt ein neues Objekt an."),
    mc("t08-2", "oop", 2, "Wozu dient this.name = name; im Konstruktor?",
       ["Es weist den Parameter name dem gleichnamigen Feld des Objekts zu", "Es vergleicht zwei Namen",
        "Es erzeugt eine neue lokale Variable", "Es ruft einen anderen Konstruktor auf"],
       "this.name ist das Feld, name allein der Parameter. Ohne this würde der Parameter sich selbst zugewiesen."),
    out("t08-3", "oop", 3, "Jedes Objekt hat seinen eigenen Zustand. Was wird ausgegeben?",
        """
        class Zaehler {
            private int stand = 0;

            void klick() {
                stand++;
            }

            int getStand() {
                return stand;
            }
        }

        public class Main {
            public static void main(String[] args) {
                Zaehler a = new Zaehler();
                Zaehler b = new Zaehler();
                a.klick();
                a.klick();
                b.klick();
                System.out.println(a.getStand() + " " + b.getStand());
            }
        }
        """,
        "2 1",
        "a und b sind zwei unabhängige Objekte. a wurde zweimal geklickt, b einmal.",
        ctx="file"),
    fill("t08-4", "oop", 4, "Ergänze den Konstruktor und den Getter der Klasse Konto.",
         """
         class Konto {
             private double saldo;

             {{0}}(double startwert) {
                 this.saldo = startwert;
             }

             double getSaldo() {
                 {{1}} saldo;
             }
         }
         """,
         [["Konto"], ["return"]],
         "Der Konstruktor trägt den Namen der Klasse. Der Getter gibt das Feld mit return zurück.",
         ctx="file",
         verify={"main": "System.out.println(new Konto(12.5).getSaldo());", "output": "12.5"}),
    code("t08-5", "oop", 5,
         "Schreibe die Klasse Rechteck mit privaten double-Feldern breite und hoehe, einem Konstruktor für beide Werte und einer Methode flaeche(), die breite * hoehe zurückgibt.",
         """
         class Rechteck {
             // Felder, Konstruktor, flaeche()
         }
         """,
         """
         class Rechteck {
             private double breite;
             private double hoehe;

             Rechteck(double breite, double hoehe) {
                 this.breite = breite;
                 this.hoehe = hoehe;
             }

             double flaeche() {
                 return breite * hoehe;
             }
         }
         """,
         [req(r"\bclass\s+Rechteck\b", "Die Klasse heißt Rechteck."),
          req(r"private\s+double\s+[^;]*\bbreite\b", "Lege ein privates Feld double breite an."),
          req(r"private\s+double\s+[^;]*\bhoehe\b", "Lege ein privates Feld double hoehe an."),
          req(r"Rechteck\s*\(\s*double\s+\w+\s*,\s*double\s+\w+\s*\)", "Schreibe den Konstruktor Rechteck(double …, double …)."),
          req(r"double\s+flaeche\s*\(\s*\)", "Schreibe die Methode double flaeche()."),
          req(r"return\s+(this\.)?(breite\s*\*\s*(this\.)?hoehe|hoehe\s*\*\s*(this\.)?breite)", "flaeche() gibt breite * hoehe zurück.")],
         "Felder private, Konstruktor setzt sie mit this, die Methode berechnet aus dem Zustand die Fläche.",
         ctx="file",
         hint="Denke an this.breite = breite; im Konstruktor.",
         verify={"main": "System.out.println(new Rechteck(3, 4).flaeche());", "output": "12.0"}),
])

l9 = lesson("l09-inheritance", "Vererbung & Interfaces", "Gemeinsames Verhalten teilen und Typen austauschbar machen.",
            ["inheritance"], 9, [
    card("extends: Verhalten erben",
         "Eine Unterklasse übernimmt Felder und Methoden der Oberklasse und kann Methoden überschreiben. @Override lässt den Compiler prüfen, dass du wirklich überschreibst.",
         code="""
         class Tier {
             String laut() { return "..."; }
         }

         class Katze extends Tier {
             @Override
             String laut() { return "Miau"; }
         }
         """),
    card("Polymorphie",
         "Eine Variable vom Typ Tier kann eine Katze enthalten. Aufgerufen wird immer die Methode des tatsächlichen Objekts. Mit super greifst du auf die Oberklasse zu.",
         code="""
         Tier t = new Katze();
         System.out.println(t.laut()); // Miau
         """),
    card("Interfaces & abstrakte Klassen",
         "Ein Interface legt fest, welche Methoden eine Klasse anbieten muss. Eine Klasse kann viele Interfaces implementieren, aber nur eine Klasse erweitern.",
         code="""
         interface Form {
             double flaeche();
         }

         class Quadrat implements Form {
             public double flaeche() { return 4.0; }
         }
         """,
         tip="Abstrakte Klassen (abstract class) liegen dazwischen: Sie dürfen Code enthalten, aber nicht direkt instanziiert werden."),
], [
    mc("t09-1", "inheritance", 1, "Mit welchem Schlüsselwort erbt eine Klasse von einer anderen?",
       ["extends", "implements", "inherits", "super"],
       "extends erweitert eine Klasse. implements nutzt man für Interfaces."),
    mc("t09-2", "inheritance", 2, "Wie viele Klassen kann eine Java-Klasse direkt erweitern?",
       ["Genau eine", "Beliebig viele", "Zwei", "Keine – nur Interfaces"],
       "Java erlaubt nur einfache Vererbung bei Klassen. Mehrfachvererbung von Typen geht über Interfaces."),
    out("t09-3", "inheritance", 3, "Was gibt die Schleife aus?",
        """
        class Tier {
            String laut() {
                return "...";
            }
        }

        class Hund extends Tier {
            @Override
            String laut() {
                return "Wuff";
            }
        }

        class Katze extends Tier {
            @Override
            String laut() {
                return "Miau";
            }
        }

        public class Main {
            public static void main(String[] args) {
                Tier[] tiere = { new Hund(), new Katze(), new Tier() };
                for (Tier t : tiere) {
                    System.out.println(t.laut());
                }
            }
        }
        """,
        """
        Wuff
        Miau
        ...
        """,
        "Obwohl das Array den Typ Tier hat, wird jeweils die überschriebene Methode des echten Objekts aufgerufen.",
        ctx="file"),
    fill("t09-4", "inheritance", 4, "Ergänze: Kreis soll das Interface Form umsetzen, und flaeche() soll als Überschreibung markiert sein.",
         """
         interface Form {
             double flaeche();
         }

         class Kreis {{0}} Form {
             private final double r;

             Kreis(double r) {
                 this.r = r;
             }

             {{1}}
             public double flaeche() {
                 return Math.PI * r * r;
             }
         }
         """,
         [["implements"], ["@Override"]],
         "Interfaces werden mit implements umgesetzt. @Override dokumentiert die Überschreibung und wird vom Compiler geprüft.",
         ctx="file",
         verify={"main": "System.out.println(new Kreis(1).flaeche());", "output": "3.141592653589793"}),
    code("t09-5", "inheritance", 5,
         "Schreibe unter Rechteck die Klasse Quadrat, die von Rechteck erbt. Ihr Konstruktor Quadrat(double seite) ruft super(seite, seite) auf.",
         """
         class Rechteck {
             protected double breite;
             protected double hoehe;

             Rechteck(double breite, double hoehe) {
                 this.breite = breite;
                 this.hoehe = hoehe;
             }

             double flaeche() {
                 return breite * hoehe;
             }
         }

         // Schreibe hier die Klasse Quadrat
         """,
         """
         class Rechteck {
             protected double breite;
             protected double hoehe;

             Rechteck(double breite, double hoehe) {
                 this.breite = breite;
                 this.hoehe = hoehe;
             }

             double flaeche() {
                 return breite * hoehe;
             }
         }

         class Quadrat extends Rechteck {
             Quadrat(double seite) {
                 super(seite, seite);
             }
         }
         """,
         [req(r"class\s+Quadrat\s+extends\s+Rechteck\b", "Quadrat erbt mit extends von Rechteck."),
          req(r"Quadrat\s*\(\s*double\s+\w+\s*\)", "Schreibe den Konstruktor Quadrat(double seite)."),
          req(r"super\s*\(\s*(\w+)\s*,\s*\1\s*\)", "Rufe super(seite, seite) auf.")],
         "Ein Quadrat ist ein Rechteck mit gleichen Seiten. super(…) ruft den Konstruktor der Eltern-Klasse auf, flaeche() wird geerbt.",
         ctx="file",
         hint="class Quadrat extends Rechteck { Quadrat(double seite) { super(seite, seite); } }",
         verify={"main": "System.out.println(new Quadrat(5).flaeche());", "output": "25.0"}),
])

# ---------------------------------------------------------------- Modul 4
l10 = lesson("l10-exceptions", "Exceptions", "Fehler abfangen, statt abzustürzen.",
             ["exceptions"], 8, [
    card("Wenn etwas schiefgeht",
         "Eine Exception unterbricht den normalen Ablauf. Mit try/catch fängst du sie ab und reagierst gezielt.",
         code="""
         try {
             int x = 10 / 0;
         } catch (ArithmeticException e) {
             System.out.println("Division durch 0!");
         }
         """),
    card("finally & mehrere catch",
         "Du kannst mehrere catch-Blöcke für verschiedene Exception-Typen schreiben. Der finally-Block läuft immer – mit oder ohne Fehler.",
         code="""
         try {
             // riskanter Code
         } catch (NumberFormatException e) {
             // falsches Zahlenformat
         } finally {
             System.out.println("Aufräumen");
         }
         """),
    card("Checked vs. unchecked",
         "Checked Exceptions (z. B. IOException) musst du fangen oder mit throws deklarieren. Unchecked Exceptions (Unterklassen von RuntimeException) nicht. Selbst werfen geht mit throw.",
         code="""
         if (alter < 0) {
             throw new IllegalArgumentException("Alter negativ");
         }
         """,
         warning="Leere catch-Blöcke verschlucken Fehler. Reagiere immer sinnvoll oder gib die Exception weiter."),
], [
    mc("t10-1", "exceptions", 1, "Welcher Block fängt eine Exception ab?",
       ["catch", "try", "throw", "final"],
       "Im try-Block steht der riskante Code, catch fängt die Exception ab."),
    out("t10-2", "exceptions", 2, "In welcher Reihenfolge erscheinen die Buchstaben?",
        """
        try {
            System.out.println("A");
            int x = 5 / 0;
            System.out.println("B");
        } catch (ArithmeticException e) {
            System.out.println("C");
        } finally {
            System.out.println("D");
        }
        """,
        """
        A
        C
        D
        """,
        "Nach A tritt die Exception auf, B wird übersprungen. catch gibt C aus, finally läuft immer und gibt D aus."),
    mc("t10-3", "exceptions", 3, "Welche Exception ist eine Checked Exception, die gefangen oder mit throws deklariert werden muss?",
       ["IOException", "NullPointerException", "ArithmeticException", "ArrayIndexOutOfBoundsException"],
       "IOException erbt nicht von RuntimeException und ist daher checked. Die anderen sind unchecked."),
    fill("t10-4", "exceptions", 4, "Ergänze: Bei negativem Alter soll eine IllegalArgumentException geworfen werden.",
         """
         static void setzeAlter(int alter) {
             if (alter < 0) {
                 {{0}} new IllegalArgumentException("Alter darf nicht negativ sein");
             }
             System.out.println("Alter: " + alter);
         }
         """,
         [["throw"]],
         "throw wirft eine Exception. throws (mit s) steht dagegen in der Methodensignatur.",
         ctx="members",
         verify={"main": """
         setzeAlter(30);
         try {
             setzeAlter(-1);
         } catch (IllegalArgumentException e) {
             System.out.println(e.getMessage());
         }
         """, "output": "Alter: 30\nAlter darf nicht negativ sein"}),
    code("t10-5", "exceptions", 5,
         "Wandle eingabe mit Integer.parseInt in eine Zahl um und gib das Doppelte aus. Fange die NumberFormatException ab und gib dann „Ungültige Eingabe“ aus.",
         """
         String eingabe = "12a";
         // try/catch hier
         """,
         """
         String eingabe = "12a";
         try {
             int zahl = Integer.parseInt(eingabe);
             System.out.println(zahl * 2);
         } catch (NumberFormatException e) {
             System.out.println("Ungültige Eingabe");
         }
         """,
         [req(r"\btry\s*\{", "Umschließe die Umwandlung mit try { … }."),
          req(r"Integer\.parseInt\s*\(\s*eingabe\s*\)", "Nutze Integer.parseInt(eingabe)."),
          req(r"catch\s*\(\s*(NumberFormatException|IllegalArgumentException)\s+\w+\s*\)", "Fange die NumberFormatException ab."),
          req(r'"Ungültige Eingabe"', "Gib „Ungültige Eingabe“ aus.", scope="raw"),
          forbid(r"catch\s*\(\s*(Exception|Throwable|RuntimeException)\s", "Fange gezielt die NumberFormatException, nicht pauschal jede Exception.")],
         "Gezielte catch-Blöcke machen klar, welchen Fehler du erwartest, und verstecken keine anderen Probleme.",
         expected="Ungültige Eingabe",
         hint="catch (NumberFormatException e) { … }"),
])

l11 = lesson("l11-collections", "Collections & Generics", "Flexible Datenstrukturen mit Typsicherheit.",
             ["collections", "generics"], 9, [
    card("ArrayList – wachsende Listen",
         "Anders als Arrays wachsen Listen dynamisch. Die wichtigsten Methoden sind add, get, remove und size.",
         code="""
         List<String> namen = new ArrayList<>();
         namen.add("Ada");
         namen.add("Linus");
         System.out.println(namen.get(0));  // Ada
         System.out.println(namen.size());  // 2
         """),
    card("HashMap – Schlüssel & Werte",
         "Eine Map ordnet Schlüsseln Werte zu. put legt ab, get liest, getOrDefault liefert einen Ersatzwert, wenn der Schlüssel fehlt.",
         code="""
         Map<String, Integer> alter = new HashMap<>();
         alter.put("Ada", 36);
         alter.get("Ada");               // 36
         alter.getOrDefault("Bob", 0);   // 0
         """),
    card("Generics",
         "In spitzen Klammern steht der Typparameter. So weiß der Compiler, was in einer Collection liegt. Primitive Typen sind nicht erlaubt – dafür gibt es Wrapper wie Integer.",
         code="""
         static <T> T erstes(List<T> liste) {
             return liste.get(0);
         }
         """,
         info="Autoboxing wandelt int und Integer automatisch ineinander um."),
], [
    mc("t11-1", "collections", 1, "Welche Methode fügt ein Element zu einer ArrayList hinzu?",
       ["add", "put", "push", "insert"],
       "Listen nutzen add. put gehört zu Maps."),
    mc("t11-2", "generics", 2, "Warum ist List<int> in Java nicht erlaubt?",
       ["Generics funktionieren nur mit Referenztypen – man nutzt List<Integer>", "Weil int zu klein ist",
        "List<int> ist erlaubt", "Weil Listen nur Strings speichern"],
       "Typparameter müssen Klassen sein. Integer ist die Wrapper-Klasse zu int."),
    out("t11-3", "collections", 3, "Was wird ausgegeben?",
        """
        List<String> liste = new ArrayList<>();
        liste.add("Kaffee");
        liste.add("Tee");
        liste.add("Kakao");
        liste.remove("Tee");
        System.out.println(liste.size());
        System.out.println(liste.get(1));
        System.out.println(liste);
        """,
        """
        2
        Kakao
        [Kaffee, Kakao]
        """,
        "Nach dem Entfernen rückt Kakao auf Index 1. Die toString-Ausgabe einer Liste steht in eckigen Klammern."),
    fill("t11-4", "collections", 4, "Zähle mit einer HashMap, wie oft jedes Wort vorkommt.",
         """
         String[] woerter = {"java", "code", "java"};
         Map<String, Integer> anzahl = new HashMap<>();
         for (String w : woerter) {
             anzahl.{{0}}(w, anzahl.getOrDefault(w, 0) + 1);
         }
         System.out.println(anzahl.get("java"));
         """,
         [["put"]],
         "put überschreibt den alten Zählerstand mit dem erhöhten Wert.",
         verify={"output": "2"}),
    code("t11-5", "generics", 5,
         "Schreibe eine generische Methode letztes, die das letzte Element einer List<T> zurückgibt.",
         """
         // static <T> … letztes(List<T> liste)
         """,
         """
         static <T> T letztes(List<T> liste) {
             return liste.get(liste.size() - 1);
         }
         """,
         [req(r"static\s+<\s*(\w+)\s*>\s+\1\s+letztes\s*\(\s*List\s*<\s*\1\s*>\s+\w+\s*\)", "Signatur: static <T> T letztes(List<T> liste)."),
          req(r"\.get\s*\(\s*\w+\.size\s*\(\s*\)\s*-\s*1\s*\)|\.getLast\s*\(\s*\)", "Greife auf den Index size() - 1 zu (oder nutze getLast())."),
          req(r"\breturn\b", "Gib das Element mit return zurück.")],
         "Der Typparameter <T> steht vor dem Rückgabetyp. So passt die Methode für Listen jedes Typs.",
         ctx="members",
         hint="return liste.get(liste.size() - 1);",
         verify={"main": 'System.out.println(letztes(List.of("a", "b", "c")));', "output": "c"}),
])

# ---------------------------------------------------------------- Modul 5
l12 = lesson("l12-lambdas", "Lambdas & Streams", "Funktional programmieren mit Pipelines.",
             ["lambdas"], 9, [
    card("Lambdas: Funktionen als Werte",
         "Ein Lambda ist eine kompakte, namenlose Funktion: Parameter, Pfeil, Ausdruck. Es passt überall dort, wo ein funktionales Interface erwartet wird. Methodenreferenzen wie String::length sind eine noch kürzere Form.",
         code="""
         Comparator<String> nachLaenge = (a, b) -> a.length() - b.length();
         Function<String, Integer> laenge = String::length;
         """),
    card("Streams: Daten in Pipelines",
         "Ein Stream verarbeitet Elemente Schritt für Schritt: filter wählt aus, map wandelt um, eine Terminal-Operation sammelt das Ergebnis ein.",
         code="""
         List<Integer> zahlen = List.of(1, 2, 3, 4, 5, 6);
         List<Integer> quadrate = zahlen.stream()
                 .filter(n -> n % 2 == 0)
                 .map(n -> n * n)
                 .toList();          // [4, 16, 36]
         """),
    card("Terminal-Operationen",
         "Erst die Terminal-Operation startet die Verarbeitung: toList(), count(), sum() nach mapToInt, oder collect(Collectors.joining(\", \")).",
         code="""
         long anzahl = zahlen.stream().filter(n -> n > 3).count();   // 3
         int summe = zahlen.stream().mapToInt(n -> n).sum();         // 21
         """,
         tip="Streams sind lazy: Ohne Terminal-Operation passiert gar nichts."),
], [
    mc("t12-1", "lambdas", 1, "Welche Schreibweise ist ein gültiger Lambda-Ausdruck in Java?",
       ["x -> x * 2", "x => x * 2", "function(x) { x * 2 }", "lambda x: x * 2"],
       "Java nutzt den Pfeil ->. => kennst du aus JavaScript, lambda x: aus Python."),
    out("t12-2", "lambdas", 2, "Was gibt forEach aus?",
        """
        List<String> namen = List.of("Ada", "Linus", "Grace");
        namen.forEach(n -> System.out.println(n.toUpperCase()));
        """,
        """
        ADA
        LINUS
        GRACE
        """,
        "forEach ruft das Lambda für jedes Element in Listenreihenfolge auf."),
    out("t12-3", "lambdas", 3, "Welche Liste entsteht?",
        """
        List<Integer> zahlen = List.of(1, 2, 3, 4, 5, 6);
        List<Integer> ergebnis = zahlen.stream()
                .filter(n -> n % 2 == 0)
                .map(n -> n * 10)
                .toList();
        System.out.println(ergebnis);
        """,
        "[20, 40, 60]",
        "Nur 2, 4 und 6 passieren den Filter, danach wird jede Zahl mit 10 multipliziert."),
    fill("t12-4", "lambdas", 4, "Ergänze die Pipeline: nur Wörter mit mehr als 3 Buchstaben, in Großbuchstaben, kommagetrennt.",
         """
         List<String> woerter = List.of("Java", "ist", "super", "cool");
         String text = woerter.stream()
                 .{{0}}(w -> w.length() > 3)
                 .map(String::{{1}})
                 .collect(Collectors.joining(", "));
         System.out.println(text);
         """,
         [["filter"], ["toUpperCase"]],
         "filter behält passende Elemente, map(String::toUpperCase) wandelt jedes Wort um.",
         verify={"output": "JAVA, SUPER, COOL"}),
    code("t12-5", "lambdas", 5,
         "Berechne mit einem Stream die Summe der Quadrate aller ungeraden Zahlen in zahlen und gib sie aus – ohne Schleife.",
         """
         List<Integer> zahlen = List.of(1, 2, 3, 4, 5);
         // Stream-Pipeline hier
         """,
         """
         List<Integer> zahlen = List.of(1, 2, 3, 4, 5);
         int summe = zahlen.stream()
                 .filter(n -> n % 2 != 0)
                 .mapToInt(n -> n * n)
                 .sum();
         System.out.println(summe);
         """,
         [req(r"\.stream\s*\(\s*\)", "Starte mit zahlen.stream()."),
          req(r"\.filter\s*\(", "Filtere die ungeraden Zahlen mit filter."),
          req(r"\.(map|mapToInt)\s*\(", "Quadriere mit map bzw. mapToInt."),
          req(r"\.sum\s*\(\s*\)|\.reduce\s*\(|Collectors\.summingInt", "Summiere am Ende, z. B. mit sum()."),
          forbid(r"\bfor\s*\(|\bwhile\s*\(", "Bitte ohne Schleife – nur mit Stream-Operationen."),
          forbid(r"println\s*\(\s*35\s*\)", "Lass den Stream rechnen.")],
         "filter → mapToInt → sum: 1 + 9 + 25 = 35.",
         expected="35",
         hint="zahlen.stream().filter(…).mapToInt(n -> n * n).sum()"),
])

l13 = lesson("l13-modern", "Records, Optional & switch-Ausdrücke", "Kompakter, sicherer Code mit modernen Sprachfeatures.",
             ["modern"], 9, [
    card("Records – Datenklassen in einer Zeile",
         "Ein record erzeugt automatisch Konstruktor, Zugriffsmethoden, equals, hashCode und toString. Ideal für unveränderliche Daten.",
         code="""
         record Punkt(int x, int y) {}

         Punkt p = new Punkt(1, 2);
         p.x();                    // 1
         System.out.println(p);    // Punkt[x=1, y=2]
         """),
    card("Optional statt null",
         "Optional macht sichtbar, dass ein Wert fehlen kann. Mit orElse, map und isPresent arbeitest du sicher damit – ohne NullPointerException.",
         code="""
         Optional<String> name = Optional.ofNullable(eingabe);
         String anzeige = name.orElse("Gast");
         """),
    card("switch-Ausdrücke & Pattern Matching",
         "switch kann direkt einen Wert liefern. Mit instanceof und Variablenbindung prüfst und castest du in einem Schritt.",
         code="""
         String art = switch (tag) {
             case 6, 7 -> "Wochenende";
             default -> "Werktag";
         };

         if (obj instanceof String s) {
             System.out.println(s.length());
         }
         """,
         info="Records gibt es seit Java 16, Pattern Matching für switch seit Java 21."),
], [
    mc("t13-1", "modern", 1, "Was erzeugt record Punkt(int x, int y) {} automatisch?",
       ["Konstruktor, x(), y(), equals, hashCode und toString", "Nur einen leeren Konstruktor",
        "Setter-Methoden für x und y", "Nichts – Records müssen alles selbst definieren"],
       "Records sind unveränderlich: Es gibt Lesemethoden (x(), y()), aber keine Setter."),
    out("t13-2", "modern", 2, "Was gibt das Programm aus?",
        """
        record Punkt(int x, int y) {}

        public class Main {
            public static void main(String[] args) {
                Punkt p = new Punkt(3, 4);
                System.out.println(p.x() + p.y());
                System.out.println(p);
                System.out.println(p.equals(new Punkt(3, 4)));
            }
        }
        """,
        """
        7
        Punkt[x=3, y=4]
        true
        """,
        "Die Lesemethoden liefern 3 und 4. toString und equals sind automatisch implementiert und vergleichen die Werte.",
        ctx="file"),
    out("t13-3", "modern", 3, "Was wird ausgegeben?",
        """
        Optional<String> leer = Optional.empty();
        Optional<String> voll = Optional.of("Java");
        System.out.println(leer.orElse("unbekannt"));
        System.out.println(voll.map(String::length).orElse(0));
        System.out.println(leer.isPresent());
        """,
        """
        unbekannt
        4
        false
        """,
        "orElse greift nur beim leeren Optional. map wendet length auf „Java“ an."),
    fill("t13-4", "modern", 4, "Ergänze den switch-Ausdruck, der für jede Note einen Text liefert.",
         """
         int note = 2;
         String text = {{0}} (note) {
             case 1 -> "sehr gut";
             case 2 -> "gut";
             case 3 -> "befriedigend";
             {{1}} -> "ausreichend oder schlechter";
         };
         System.out.println(text);
         """,
         [["switch"], ["default"]],
         "Ein switch-Ausdruck muss alle Fälle abdecken – default fängt den Rest ab.",
         verify={"output": "gut"}),
    code("t13-5", "modern", 5,
         'Schreibe die Methode beschreibe(Object o) mit Pattern Matching: Für einen String liefert sie "Text mit N Zeichen", für einen Integer "Zahl N", sonst "Unbekannt".',
         """
         static String beschreibe(Object o) {
             // Pattern Matching hier
         }
         """,
         """
         static String beschreibe(Object o) {
             if (o instanceof String s) {
                 return "Text mit " + s.length() + " Zeichen";
             } else if (o instanceof Integer i) {
                 return "Zahl " + i;
             }
             return "Unbekannt";
         }
         """,
         [req(r"static\s+String\s+beschreibe\s*\(\s*Object\s+\w+\s*\)", "Signatur: static String beschreibe(Object o)."),
          req(r"instanceof\s+String\s+\w+|case\s+String\s+\w+", "Prüfe mit instanceof String s (oder case String s) und binde eine Variable."),
          req(r"instanceof\s+Integer\s+\w+|case\s+Integer\s+\w+", "Behandle auch den Fall Integer."),
          req(r"\.length\s*\(\s*\)", "Nutze length() für die Anzahl der Zeichen."),
          req(r'"Unbekannt"', "Gib für alles andere „Unbekannt“ zurück.", scope="raw")],
         "Mit instanceof String s ist s direkt als String nutzbar – kein Cast nötig. Ein switch mit case String s ginge genauso.",
         ctx="members",
         hint="if (o instanceof String s) { return \"Text mit \" + s.length() + \" Zeichen\"; }",
         verify={"main": """
         System.out.println(beschreibe("Kaffee"));
         System.out.println(beschreibe(42));
         System.out.println(beschreibe(3.5));
         """, "output": "Text mit 6 Zeichen\nZahl 42\nUnbekannt"}),
])

# ---------------------------------------------------------------- Einstufung
intermediate_pool = [
    mc("p-i01", "variables", 1, "Welcher Datentyp speichert true oder false?",
       ["boolean", "int", "String", "char"], "boolean kennt genau zwei Werte: true und false."),
    mc("p-i02", "syntax", 1, "Wie gibst du in Java einen Text mit anschließendem Zeilenumbruch aus?",
       ['System.out.println("Text");', 'print("Text")', 'console.log("Text");', 'echo "Text";'],
       "System.out.println schreibt auf die Konsole und bricht danach um."),
    out("p-i03", "operators", 2, "Was wird ausgegeben?",
        """
        System.out.println(17 / 5);
        System.out.println(17 % 5);
        """,
        """
        3
        2
        """,
        "Ganzzahldivision: 17 / 5 = 3 Rest 2."),
    mc("p-i04", "conditionals", 2, "Mit welchem Operator prüfst du zwei int-Werte auf Gleichheit?",
       ["==", "=", "===", "equals"], "== vergleicht primitive Werte. = ist eine Zuweisung."),
    out("p-i05", "loops", 3, "Welcher Wert wird ausgegeben?",
        """
        int x = 1;
        while (x < 20) {
            x *= 3;
        }
        System.out.println(x);
        """,
        "27",
        "x wird 3, 9 und 27. Bei 27 ist die Bedingung x < 20 falsch."),
    fill("p-i06", "methods", 3, "Ergänze den Rückgabetyp.",
         """
         static {{0}} halbiere(double wert) {
             return wert / 2;
         }
         """,
         [["double"]],
         "wert / 2 ist bei einem double-Parameter wieder ein double.",
         ctx="members",
         verify={"main": "System.out.println(halbiere(5));", "output": "2.5"}),
    out("p-i07", "conditionals", 4, "Was wird ausgegeben? Achte auf den Vorrang der Operatoren.",
        """
        int a = 4;
        int b = 9;
        if (a > 5 || b > 5 && a % 2 == 0) {
            System.out.println("X");
        } else {
            System.out.println("Y");
        }
        """,
        "X",
        "&& bindet stärker als ||: a > 5 ist falsch, aber (b > 5 && a % 2 == 0) ist wahr."),
    mc("p-i08", "loops", 4, "Welche Ausgabe erzeugt diese Schleife?",
       ["024", "0246", "01234", "135"],
       "i nimmt 0, 2 und 4 an. Bei 6 ist i < 5 falsch.",
       code="""
       for (int i = 0; i < 5; i += 2) {
           System.out.print(i);
       }
       """,
       verify={"output": "024"}),
    code("p-i09", "methods", 5, "Schreibe die Methode fakultaet(int n), die n! mit einer Schleife berechnet und als long zurückgibt.",
         """
         static long fakultaet(int n) {
             // Schleife hier
         }
         """,
         """
         static long fakultaet(int n) {
             long ergebnis = 1;
             for (int i = 2; i <= n; i++) {
                 ergebnis *= i;
             }
             return ergebnis;
         }
         """,
         [req(r"static\s+long\s+fakultaet\s*\(\s*int\s+\w+\s*\)", "Signatur: static long fakultaet(int n)."),
          req(r"\b(for|while)\s*\(", "Nutze eine Schleife."),
          req(r"\*=|=\s*\w+\s*\*", "Multipliziere schrittweise auf."),
          req(r"\breturn\b", "Gib das Ergebnis zurück.")],
         "Startwert 1, dann mit 2, 3, … n multiplizieren. long verhindert einen Überlauf bis 20!.",
         ctx="members",
         verify={"main": 'System.out.println(fakultaet(5) + " " + fakultaet(20));', "output": "120 2432902008176640000"}),
    out("p-i10", "loops", 5, "Welchen Wert hat summe am Ende?",
        """
        int summe = 0;
        for (int i = 1; i <= 4; i++) {
            for (int j = 1; j <= i; j++) {
                summe += j;
            }
        }
        System.out.println(summe);
        """,
        "20",
        "Die innere Schleife addiert 1, dann 1+2, 1+2+3 und 1+2+3+4: 1 + 3 + 6 + 10 = 20."),
]

advanced_pool = [
    mc("p-a01", "oop", 1, "Was ist ein Konstruktor?",
       ["Eine spezielle Methode, die beim Erzeugen eines Objekts aufgerufen wird", "Eine statische Variable",
        "Ein anderes Wort für Klasse", "Eine Methode, die Objekte löscht"],
       "Der Konstruktor initialisiert ein neues Objekt und heißt wie die Klasse."),
    mc("p-a02", "collections", 1, "Welche Collection speichert Schlüssel-Wert-Paare?",
       ["HashMap", "ArrayList", "HashSet", "LinkedList"], "Maps ordnen Schlüsseln Werte zu."),
    mc("p-a03", "strings", 2, "Wie vergleichst du den Inhalt zweier Strings korrekt?",
       ["a.equals(b)", "a == b", "a = b", "a.compare(b) == true"],
       "equals vergleicht den Inhalt, == nur die Referenz."),
    out("p-a04", "arrays", 2, "Was wird ausgegeben?",
        """
        int[] z = new int[3];
        z[1] = 5;
        System.out.println(z[0] + z[1] + z.length);
        """,
        "8",
        "Neue int-Arrays sind mit 0 gefüllt: 0 + 5 + 3 = 8."),
    out("p-a05", "inheritance", 3, "Was gibt das Programm aus?",
        """
        class A {
            String name() {
                return "A";
            }

            String gruss() {
                return "Hallo " + name();
            }
        }

        class B extends A {
            @Override
            String name() {
                return "B";
            }
        }

        public class Main {
            public static void main(String[] args) {
                A obj = new B();
                System.out.println(obj.gruss());
            }
        }
        """,
        "Hallo B",
        "gruss() stammt aus A, ruft aber name() dynamisch auf – und das ist die überschriebene Version aus B.",
        ctx="file"),
    mc("p-a06", "exceptions", 3, "Was passiert mit finally, wenn im try-Block eine Exception auftritt und gefangen wird?",
       ["finally wird trotzdem ausgeführt", "finally wird übersprungen", "finally läuft nur ohne Exception", "Das Programm stürzt ab"],
       "finally läuft immer – auch nach return oder einer gefangenen Exception."),
    out("p-a07", "collections", 4, "Was wird ausgegeben? Hinweis: Eine TreeMap sortiert nach Schlüssel.",
        """
        Map<String, Integer> lager = new TreeMap<>();
        lager.put("Tee", 3);
        lager.put("Kaffee", 5);
        lager.put("Tee", lager.get("Tee") + 2);
        System.out.println(lager);
        """,
        "{Kaffee=5, Tee=5}",
        "put mit vorhandenem Schlüssel überschreibt den Wert. Die TreeMap gibt die Schlüssel alphabetisch aus."),
    fill("p-a08", "generics", 4, "Ergänze die Typparameter-Deklaration so, dass T mit compareTo vergleichbar sein muss.",
         """
         static {{0}} T groesstes(List<T> liste) {
             T max = liste.get(0);
             for (T x : liste) {
                 if (x.compareTo(max) > 0) {
                     max = x;
                 }
             }
             return max;
         }
         """,
         [["<T extends Comparable<T>>", "<T extends Comparable<? super T>>"]],
         "Mit einer oberen Schranke (T extends Comparable<T>) darf die Methode compareTo auf T aufrufen.",
         ctx="members",
         verify={"main": "System.out.println(groesstes(List.of(3, 9, 4)));", "output": "9"}),
    out("p-a09", "exceptions", 5, "Was gibt main aus? Achte auf finally und return.",
        """
        static int teste(int n) {
            try {
                if (n < 0) {
                    throw new IllegalArgumentException();
                }
                return n;
            } catch (IllegalArgumentException e) {
                return -1;
            } finally {
                System.out.println("finally " + n);
            }
        }

        public static void main(String[] args) {
            System.out.println(teste(-5));
            System.out.println(teste(2));
        }
        """,
        """
        finally -5
        -1
        finally 2
        2
        """,
        "finally läuft, bevor der Rückgabewert beim Aufrufer ankommt. Deshalb erscheint „finally …“ jeweils vor dem Ergebnis.",
        ctx="members"),
    code("p-a10", "strings", 5,
         "Schreibe die Methode istPalindrom(String s), die true liefert, wenn s vorwärts und rückwärts gleich ist. Groß-/Kleinschreibung wird ignoriert.",
         """
         static boolean istPalindrom(String s) {
             // dein Code
         }
         """,
         """
         static boolean istPalindrom(String s) {
             String klein = s.toLowerCase();
             String umgedreht = new StringBuilder(klein).reverse().toString();
             return klein.equals(umgedreht);
         }
         """,
         [req(r"static\s+boolean\s+istPalindrom\s*\(\s*String\s+\w+\s*\)", "Signatur: static boolean istPalindrom(String s)."),
          req(r"toLowerCase|toUpperCase|equalsIgnoreCase", "Ignoriere Groß- und Kleinschreibung."),
          req(r"reverse\s*\(|charAt\s*\(", "Vergleiche vorwärts mit rückwärts, z. B. über reverse() oder charAt()."),
          req(r"\breturn\b", "Gib das Ergebnis zurück.")],
         "StringBuilder.reverse() dreht den Text um, equals vergleicht den Inhalt.",
         ctx="members",
         verify={"main": 'System.out.println(istPalindrom("Rentner") + " " + istPalindrom("Java"));', "output": "true false"}),
]

placement_question = fill(
    "p-check", "methods", 3,
    "Eine Frage, sechs Lücken: Ergänze das Programm. Es soll die Zahlen von 1 bis 5 addieren und – falls die Summe größer als 10 ist – das Doppelte davon ausgeben.",
    """
    static {{0}} verdoppeln(int x) {
        return x * 2;
    }

    public static void main(String[] args) {
        {{1}} summe = 0;
        {{2}} (int i = 1; i <= 5; i{{3}}) {
            summe += i;
        }
        {{4}} (summe > 10) {
            System.out.{{5}}("Summe: " + verdoppeln(summe));
        }
    }
    """,
    [["int"], ["int", "var"], ["for"], ["++", "+=1"], ["if"], ["println", "print"]],
    "verdoppeln liefert eine ganze Zahl (int). summe ist eine int-Box, for zählt i von 1 bis 5 hoch (i++), if prüft die Summe und println schreibt das Ergebnis: 15 → „Summe: 30“.",
    ctx="members",
    verify={"output": "Summe: 30"})

course = {
    "schemaVersion": 1,
    "id": "java-core-de",
    "title": "Java – vom ersten Befehl zum Profi",
    "topics": [{"id": i, "title": t, "symbol": s, "summary": d} for i, t, s, d in topics + ADVANCED_TOPICS + UML_TOPICS],
    "modules": [
        {"id": "m1-first-steps", "title": "Erste Schritte", "subtitle": "Programmaufbau, Variablen und Operatoren",
         "tier": "beginner", "symbol": "leaf.fill", "lessons": [l1, l2, l3]},
        {"id": "m2-control-flow", "title": "Kontrollfluss", "subtitle": "Bedingungen, Schleifen und Methoden",
         "tier": "beginner", "symbol": "arrow.triangle.branch", "lessons": [l4, l5, l6]},
        {"id": "m3-objects", "title": "Daten & Objekte", "subtitle": "Arrays, Strings, Klassen und Vererbung",
         "tier": "intermediate", "symbol": "cube.fill", "lessons": [l7, l8, l9]},
        {"id": "m4-robust", "title": "Robuster Code", "subtitle": "Exceptions, Collections und Generics",
         "tier": "intermediate", "symbol": "shield.lefthalf.filled", "lessons": [l10, l11]},
        {"id": "m5-modern", "title": "Modernes Java", "subtitle": "Lambdas, Streams, Records und Pattern Matching",
         "tier": "advanced", "symbol": "sparkles", "lessons": [l12, l13]},
    ] + ADVANCED_MODULES + [UML_MODULE],
    "taskPool": POOL + POOL_BASICS + POOL_ADVANCED + POOL_DEEP + POOL_PRACTICE + POOL_EXTRA + POOL_GAPS + POOL_LEVEL_A + POOL_LEVEL_B + POOL_LEVEL_C + POOL_VARIETY + POOL_DEPTH + UML_POOL,
    "placement": {
        "passThreshold": 65,
        # Ab hier wird nicht nur der Grundkurs übersprungen, sondern auch der Mittelteil.
        "advancedThreshold": 85,
        "questionsPerTest": 5,
        "startDifficulty": 3,
        "pools": {"intermediate": PLACEMENT_POOL + [placement_question]},
    },
}

# ---------------------------------------------------------------- Didaktik
from theory_texts import THEORY, TASK_EXPLANATIONS
from why_wrong import WHY_WRONG
from why_wrong_more import WHY_WRONG_MORE

# Beide Sammlungen gelten gleichrangig; doppelte IDs wären ein Autorenfehler.
_doppelt = set(WHY_WRONG) & set(WHY_WRONG_MORE)
assert not _doppelt, f"Begründungen doppelt definiert: {sorted(_doppelt)}"
WHY_WRONG = {**WHY_WRONG, **WHY_WRONG_MORE}
from explanations import BETTER_EXPLANATIONS, MINDESTLAENGE
from line_notes import NOTES
import subprocess, os

lessons_by_id = {l["id"]: l for m in course["modules"] for l in m["lessons"]}
for (lesson_id, index), (title, body, kind, text) in THEORY.items():
    card_ = lessons_by_id[lesson_id]["theory"][index]
    card_["title"], card_["body"] = title, body
    card_.pop("callout", None)
    if kind:
        card_["callout"] = {"kind": kind, "text": text}
all_tasks = ([t for m in course["modules"] for l in m["lessons"] for t in l["tasks"]]
             + course["taskPool"] + course["placement"]["pools"]["intermediate"])
bekannte_ids = {t["id"] for t in all_tasks}
unbekannt = set(BETTER_EXPLANATIONS) - bekannte_ids
assert not unbekannt, f"Erklärung für nicht vorhandene Aufgabe(n): {sorted(unbekannt)}"

for task in all_tasks:
    if task["id"] in TASK_EXPLANATIONS:
        task["explanation"] = TASK_EXPLANATIONS[task["id"]]
    # Ausgeführte Fassung: sagt zusätzlich, WARUM es so ist.
    if task["id"] in BETTER_EXPLANATIONS:
        besser = BETTER_EXPLANATIONS[task["id"]]
        assert len(besser) >= MINDESTLAENGE, f"{task['id']}: Erklärung zu knapp ({len(besser)} Zeichen)"
        assert len(besser) > len(task["explanation"]), f"{task['id']}: neue Erklärung ist nicht ausführlicher"
        task["explanation"] = besser
    # Begründungen zu den falschen Antworten – zugeordnet über den Antworttext,
    # weil die Antworten beim Erzeugen gedreht werden.
    if task["id"] in WHY_WRONG:
        gruende = WHY_WRONG[task["id"]]
        offen = set(gruende) - set(task["choices"])
        assert not offen, f"{task['id']}: Begründung passt zu keiner Antwort mehr: {offen}"
        task["whyWrong"] = [
            None if i == task["correctIndex"] else gruende.get(antwort)
            for i, antwort in enumerate(task["choices"])
        ]
        fehlend = [a for i, a in enumerate(task["choices"]) if i != task["correctIndex"] and not task["whyWrong"][i]]
        assert not fehlend, f"{task['id']}: keine Begründung für {fehlend}"

def fill_first(task):
    text = task["template"]
    for i, blank in enumerate(task["blanks"]):
        text = text.replace("{{%d}}" % i, blank["accepted"][0])
    return text

# Alle Schnipsel sammeln: (Objekt, Feld, anzuzeigender Code, zu erklärender Code)
slots = []
for l in lessons_by_id.values():
    for card_ in l["theory"]:
        if "code" in card_: slots.append((card_, "code", card_["code"], card_["code"]))
for task in all_tasks:
    if "code" in task: slots.append((task, "code", task["code"], task["code"]))
    if task["type"] == "fillBlank": slots.append((task, "template", task["template"], fill_first(task)))
    if task["type"] == "code":
        slots.append((task, "starterCode", task["starterCode"], task["starterCode"]))
        slots.append((task, "sampleSolution", task["sampleSolution"], task["sampleSolution"]))

tool = os.environ.get("ANNOTATE_TOOL") or os.path.join(os.path.dirname(os.path.abspath(__file__)), ".build", "annotate")
jobs = [{"explain": x[3], "show": x[2]} for x in slots]
out = subprocess.run([tool], input=json.dumps(jobs).encode(), capture_output=True, check=True)
annotated = json.loads(out.stdout)
review = []
for (obj, field, shown, _), result in zip(slots, annotated):
    lines = []
    for code_line, text, terms in zip(shown.split("\n"), result["explain"], result["terms"]):
        entry = {"code": code_line}
        stripped = code_line.strip()
        if stripped:
            text = NOTES.get(stripped) or NOTES.get(stripped.split("//")[0].strip()) or text
            entry["explain"] = text
            if terms:
                entry["terms"] = terms
            review.append((obj.get("id", obj.get("title")), field, stripped, text))
        lines.append(entry)
    obj[field] = {"lines": lines}
# Befehlslexikon für Apps ohne eigene Erklär-Engine (Windows): Begriff → Bedeutung.
course["glossary"] = json.loads(subprocess.run([tool, "--glossary"], capture_output=True, check=True).stdout)

os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".build"), exist_ok=True)
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".build", "explanations_review.txt"), "w", encoding="utf-8") as f:
    for owner, field, code_line, text in review:
        f.write(f"[{owner} · {field}] {code_line}\n    → {text}\n")
fallbacks = [r for r in review if r[3].startswith("FALLBACK")]
print(f"{len(review)} erklärte Zeilen, {len(fallbacks)} ohne Regel")
for owner, field, code_line, text in fallbacks:
    print(f"  OHNE REGEL [{owner} · {field}] {code_line}")

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(course, f, ensure_ascii=False, indent=2)
    f.write("\n")

tasks = sum(len(l["tasks"]) for m in course["modules"] for l in m["lessons"])
groups = len({t.get("variantGroup", t["id"]) for t in course["taskPool"]})
print(f"{len(course['modules'])} Module, {sum(len(m['lessons']) for m in course['modules'])} Lektionen, "
      f"{tasks} Lektionsaufgaben, {len(course['taskPool'])} Übungsaufgaben im Pool "
      f"({groups} Lernziele), {len(course['placement']['pools']['intermediate'])} Einstufungsfragen")
if fallbacks:
    sys.exit(1)
