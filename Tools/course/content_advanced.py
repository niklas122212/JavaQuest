"""Aufbaukurs: Module 6–12 (Objekte vertieft bis Abschlussprojekte).

Alle Texte in Alltagssprache; die Zeilen-Erklärungen erzeugt der CodeExplainer.
Jedes Codebeispiel mit verify wird von Tools/verify_java_content.py mit einem echten JDK geprüft.
"""
from authoring import c, card, code, fill, forbid, lesson, mc, out, req

ADVANCED_TOPICS = [
    ("enums", "Enums & static", "list.number", "Feste Auswahlwerte, Klassenvariablen und Konstanten"),
    ("objectmethods", "equals, toString & abstrakt", "equal.circle", "Objekte vergleichen, als Text zeigen und abstrakte Klassen"),
    ("io", "Texte, Eingaben & Dateien", "doc.text", "StringBuilder, Scanner und Dateien lesen und schreiben"),
    ("datetime", "Datum & Uhrzeit", "calendar", "LocalDate, Period und Formatierung"),
    ("recursion", "Rekursion", "arrow.triangle.2.circlepath", "Methoden, die sich selbst aufrufen"),
    ("algorithms", "Suchen & Sortieren", "arrow.up.arrow.down", "Lineare und binäre Suche, Sortieren, Aufwand"),
    ("datastructures", "Set, Stack & Queue", "square.stack.3d.up", "Mengen, Stapel und Warteschlangen"),
    ("testing", "Testen", "checkmark.seal", "Unit-Tests mit JUnit und selbst gebaute Prüfungen"),
    ("tooling", "Pakete, Build & Fehlersuche", "hammer", "package, import, Maven/Gradle und Debugging"),
    ("concurrency", "Nebenläufigkeit", "cpu", "Threads, Executor und virtuelle Threads"),
    ("patterns", "sealed & Pattern Matching", "puzzlepiece", "Versiegelte Typen und Muster im switch"),
    ("projects", "Projekte", "flag.checkered", "Alles zusammen in kleinen Programmen"),
]

# ---------------------------------------------------------------- Modul 6: Objekte vertieft

l14 = lesson("l14-enums-static", "Enums & static", "Feste Auswahlwerte und Dinge, die der ganzen Klasse gehören.",
             ["enums"], 8, [
    card("Enums: eine feste Auswahl",
         "Manche Werte haben nur wenige erlaubte Möglichkeiten – etwa die Farben einer Ampel. Ein enum (Aufzählung) "
         "legt diese Auswahl fest. Java lässt dann nur genau diese Werte zu: Ein Tippfehler wie „GRÜHN“ fällt sofort auf.",
         code=r"""
         enum Ampel { ROT, GELB, GRUEN }

         Ampel jetzt = Ampel.ROT;
         System.out.println(jetzt);                      // ROT
         System.out.println(Ampel.values().length);      // 3
         """,
         verify={"output": "ROT\n3"}),
    card("switch mit enums",
         "Ein switch passt perfekt zu einem enum: Für jeden erlaubten Wert gibt es genau einen Weg.",
         code=r"""
         enum Ampel { ROT, GELB, GRUEN }

         Ampel jetzt = Ampel.GELB;
         String rat = switch (jetzt) {
             case ROT -> "Stehen bleiben";
             case GELB -> "Gleich geht es los";
             case GRUEN -> "Losgehen";
         };
         System.out.println(rat);
         """,
         tip="Ein switch über ein enum muss alle Werte abdecken – vergisst du einen, meldet Java das sofort.",
         verify={"output": "Gleich geht es los"}),
    card("static: gehört der Kuchenform",
         "Normale Felder hat jeder Kuchen (jedes Objekt) für sich. Ein static-Feld gibt es nur ein einziges Mal – es gehört "
         "der Kuchenform (der Klasse) selbst und wird von allen Objekten geteilt. static final macht daraus eine Konstante, "
         "die sich nie ändert; ihr Name wird üblicherweise GROSS geschrieben.",
         code=r"""
         class Zaehler {
             static int anzahl = 0;
             static final int MAXIMUM = 3;

             Zaehler() {
                 anzahl++;
             }
         }
         """,
         verify={"context": "file", "main": "new Zaehler();\nnew Zaehler();\nSystem.out.println(Zaehler.anzahl);", "output": "2"}),
], [
    mc("t14-1", "enums", 1, "Wofür eignet sich ein enum am besten?",
       ["Für eine feste Auswahl an Werten, z. B. die Wochentage", "Für beliebig viele Zahlen",
        "Für lange Texte", "Um Dateien zu speichern"],
       "Ein enum zählt alle erlaubten Werte auf – mehr gibt es nicht. Perfekt für Wochentage, Ampelfarben oder Spielfiguren."),
    out("t14-2", "enums", 2, "Was wird ausgegeben?",
        r"""
        enum Groesse { KLEIN, MITTEL, GROSS }

        Groesse g = Groesse.MITTEL;
        System.out.println(g);
        System.out.println(g.ordinal());
        """,
        "MITTEL\n1",
        "println zeigt den Namen des Werts. ordinal() ist seine Position – gezählt ab 0: KLEIN = 0, MITTEL = 1."),
    fill("t14-3", "enums", 3, "Heute regnet es. Ergänze den Wert und das Wort, das den passenden Tipp auswählt.",
         r"""
         enum Wetter { SONNE, REGEN, SCHNEE }

         Wetter heute = Wetter.{{0}};
         String tipp = {{1}} (heute) {
             case SONNE -> "Sonnenbrille";
             case REGEN -> "Schirm";
             case SCHNEE -> "Handschuhe";
         };
         System.out.println(tipp);
         """,
         [["REGEN"], ["switch"]],
         "Wetter.REGEN ist der Wert für Regen; der switch wählt dazu den Tipp „Schirm“.",
         verify={"output": "Schirm"}),
    out("t14-4", "enums", 4, "Alle Besucher teilen sich den Zähler gesamt. Was wird ausgegeben?",
        r"""
        class Besucher {
            static int gesamt = 0;
            int nummer;

            Besucher() {
                gesamt++;
                nummer = gesamt;
            }
        }

        public class Main {
            public static void main(String[] args) {
                Besucher a = new Besucher();
                Besucher b = new Besucher();
                Besucher c = new Besucher();
                System.out.println(a.nummer + " " + c.nummer);
                System.out.println(Besucher.gesamt);
            }
        }
        """,
        "1 3\n3",
        "gesamt gibt es nur einmal (static) und wächst mit jedem neuen Besucher. nummer hat jeder Besucher für sich: "
        "a bekam 1, c bekam 3.",
        ctx="file"),
    code("t14-5", "enums", 5,
         "Lege ein enum Jahreszeit mit FRUEHLING, SOMMER, HERBST und WINTER an und gib mit einer Schleife über "
         "Jahreszeit.values() alle Jahreszeiten untereinander aus.",
         r"""
         // enum Jahreszeit hier

         public static void main(String[] args) {
             // alle Jahreszeiten ausgeben
         }
         """,
         r"""
         enum Jahreszeit { FRUEHLING, SOMMER, HERBST, WINTER }

         public static void main(String[] args) {
             for (Jahreszeit j : Jahreszeit.values()) {
                 System.out.println(j);
             }
         }
         """,
         [req(r"\benum\s+Jahreszeit\b", "Lege das enum Jahreszeit an."),
          req(r"FRUEHLING\s*,\s*SOMMER\s*,\s*HERBST\s*,\s*WINTER", "Zähle FRUEHLING, SOMMER, HERBST, WINTER in dieser Reihenfolge auf."),
          req(r"\.values\s*\(\s*\)", "Hol dir alle Werte mit Jahreszeit.values()."),
          req(r"\bfor\s*\(", "Gib die Werte mit einer for-Schleife aus.")],
         "values() liefert alle Werte des enums als Eierkarton; die for-each-Schleife gibt sie der Reihe nach aus.",
         expected="FRUEHLING\nSOMMER\nHERBST\nWINTER",
         ctx="members",
         hint="for (Jahreszeit j : Jahreszeit.values()) { … }"),
])

l15 = lesson("l15-object-methods", "equals, toString & abstrakte Klassen",
             "Objekte vergleichen, als Text zeigen und halbfertige Kuchenformen.",
             ["objectmethods"], 9, [
    card("toString: das Objekt als Text",
         "Gibt man ein eigenes Objekt mit println aus, erscheint ohne Hilfe nur so etwas wie Punkt@1b6d3586 – der Name der "
         "Kuchenform und eine Nummer. Mit einer eigenen toString-Methode bestimmst du selbst, welcher Text erscheint. "
         "@Override sagt Java: Diese Methode ersetzt eine geerbte.",
         code=r"""
         class Punkt {
             int x;
             int y;

             Punkt(int x, int y) {
                 this.x = x;
                 this.y = y;
             }

             @Override
             public String toString() {
                 return "(" + x + ", " + y + ")";
             }
         }
         """,
         verify={"context": "file", "main": "System.out.println(new Punkt(2, 3));", "output": "(2, 3)"}),
    card("equals und hashCode: Wann sind zwei Objekte gleich?",
         "== fragt: Ist das derselbe Kuchen? equals fragt: Haben die beiden Kuchen dieselben Zutaten? Wer equals selbst "
         "schreibt, muss auch hashCode schreiben: Gleiche Objekte brauchen dieselbe Kennnummer (Hash-Wert), sonst finden "
         "HashSet und HashMap sie nicht wieder.",
         code=r"""
         @Override
         public boolean equals(Object o) {
             if (!(o instanceof Punkt p)) {
                 return false;
             }
             return x == p.x && y == p.y;
         }

         @Override
         public int hashCode() {
             return Objects.hash(x, y);
         }
         """,
         info="Records bekommen equals, hashCode und toString automatisch – bei normalen Klassen schreibst du sie selbst."),
    card("Abstrakte Klassen: eine halbfertige Kuchenform",
         "Eine abstrakte Klasse ist eine Kuchenform, bei der ein Teil der Anleitung noch fehlt. Aus ihr selbst kann man "
         "keinen Kuchen backen – erst eine Kind-Klasse ergänzt die fehlenden (abstrakten) Methoden. So schreibt man "
         "Gemeinsames nur einmal.",
         code=r"""
         abstract class Tier {
             abstract String laut();

             void vorstellen() {
                 System.out.println("Ich sage " + laut());
             }
         }

         class Katze extends Tier {
             @Override
             String laut() {
                 return "Miau";
             }
         }
         """,
         verify={"context": "file", "main": "new Katze().vorstellen();", "output": "Ich sage Miau"}),
], [
    mc("t15-1", "objectmethods", 1, "Welche Methode bestimmt, was println bei einem eigenen Objekt ausgibt?",
       ["toString()", "equals()", "hashCode()", "main()"],
       "println ruft toString() auf. Schreibst du sie selbst, erscheint dein Text statt Klassenname@Nummer."),
    mc("t15-2", "objectmethods", 2, "Was ist der Unterschied zwischen == und equals bei Objekten?",
       ["== fragt „dasselbe Objekt?“, equals fragt „inhaltlich gleich?“", "Es gibt keinen Unterschied",
        "equals vergleicht nur Zahlen", "== vergleicht nur Texte"],
       "Zwei Kuchen mit denselben Zutaten sind inhaltlich gleich (equals), aber trotzdem zwei verschiedene Kuchen (==)."),
    out("t15-3", "objectmethods", 3, "Records bringen equals und toString mit. Was wird ausgegeben?",
        r"""
        record Farbe(String name) {}

        public class Main {
            public static void main(String[] args) {
                Farbe a = new Farbe("Rot");
                Farbe b = new Farbe("Rot");
                System.out.println(a == b);
                System.out.println(a.equals(b));
                System.out.println(a);
            }
        }
        """,
        "false\ntrue\nFarbe[name=Rot]",
        "a und b sind zwei verschiedene Objekte (== ist false), aber inhaltlich gleich (equals ist true). "
        "Das automatische toString eines Records zeigt Name und Inhalt.",
        ctx="file"),
    fill("t15-4", "objectmethods", 4, "Ergänze: Form ist eine halbfertige Kuchenform, Quadrat erweitert sie.",
         r"""
         {{0}} class Form {
             abstract double flaeche();
         }

         class Quadrat {{1}} Form {
             double seite = 3;

             @Override
             double flaeche() {
                 return seite * seite;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 Form f = new Quadrat();
                 System.out.println(f.flaeche());
             }
         }
         """,
         [["abstract"], ["extends"]],
         "abstract macht Form zur halbfertigen Kuchenform, extends lässt Quadrat sie erweitern und die fehlende "
         "Methode ergänzen: 3 · 3 = 9.0.",
         ctx="file", verify={"output": "9.0"}),
    code("t15-5", "objectmethods", 5,
         "Ergänze in der Klasse Buch eine toString-Methode, die „Titel von Autor“ liefert – z. B. „Momo von Michael Ende“.",
         r"""
         class Buch {
             String titel;
             String autor;

             Buch(String titel, String autor) {
                 this.titel = titel;
                 this.autor = autor;
             }

             // toString hier
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Buch("Momo", "Michael Ende"));
             }
         }
         """,
         r"""
         class Buch {
             String titel;
             String autor;

             Buch(String titel, String autor) {
                 this.titel = titel;
                 this.autor = autor;
             }

             @Override
             public String toString() {
                 return titel + " von " + autor;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Buch("Momo", "Michael Ende"));
             }
         }
         """,
         [req(r"public\s+String\s+toString\s*\(\s*\)", "Schreibe die Methode public String toString()."),
          req(r"\breturn\b[^;]*titel[^;]*autor", "Gib titel und autor zurück – in dieser Reihenfolge."),
          req(r'" von "', "Setze „ von “ zwischen Titel und Autor.", scope="raw")],
         "println ruft toString() auf – und die liefert jetzt „Momo von Michael Ende“.",
         expected="Momo von Michael Ende",
         ctx="file",
         hint="return titel + \" von \" + autor;"),
])

# ---------------------------------------------------------------- Modul 7: Daten & Dateien

l16 = lesson("l16-text-input", "Texte bauen & Eingaben lesen", "StringBuilder und Scanner.",
             ["io"], 9, [
    card("StringBuilder: Text Stück für Stück bauen",
         "Ein String lässt sich nicht verändern – jedes + erzeugt einen ganz neuen Text. Wenn du viele Teile zusammensetzt, "
         "ist ein StringBuilder wie ein Notizblock, auf dem du immer weiterschreibst. append hängt etwas an, am Ende macht "
         "toString() einen normalen String daraus.",
         code=r"""
         StringBuilder sb = new StringBuilder();
         for (int i = 1; i <= 3; i++) {
             sb.append(i).append(" ");
         }
         sb.append("los!");
         System.out.println(sb.toString());   // 1 2 3 los!
         """,
         verify={"output": "1 2 3 los!"}),
    card("Scanner: Eingaben lesen",
         "Ein Scanner liest Text Stück für Stück – zum Beispiel das, was jemand eintippt. Zum Üben lesen wir hier aus einem "
         "fertigen Text. next() liest das nächste Wort, nextInt() die nächste Zahl, hasNextInt() fragt, ob noch eine Zahl kommt.",
         code=r"""
         Scanner sc = new Scanner("Ada 36");
         String name = sc.next();
         int alter = sc.nextInt();
         System.out.println(name + " ist " + alter);   // Ada ist 36
         """,
         info="Für echte Tastatureingaben schreibst du new Scanner(System.in) – das Programm wartet dann, bis jemand Enter drückt.",
         verify={"output": "Ada ist 36"}),
], [
    mc("t16-1", "io", 1, "Warum nimmt man einen StringBuilder, wenn man viele Textteile zusammensetzt?",
       ["Er schreibt auf demselben Notizblock weiter, statt jedes Mal einen neuen Text zu erzeugen",
        "Er macht Texte automatisch groß", "Er ist die einzige Art, Texte auszugeben", "Er übersetzt Texte"],
       "Jedes + erzeugt einen neuen String. Der StringBuilder verändert seinen Inhalt direkt – das spart Arbeit."),
    out("t16-2", "io", 2, "Was wird ausgegeben?",
        r"""
        StringBuilder sb = new StringBuilder("Java");
        sb.append("Quest");
        sb.reverse();
        System.out.println(sb);
        """,
        "tseuQavaJ",
        "Erst wird „Quest“ angehängt (JavaQuest), dann dreht reverse() die Reihenfolge aller Zeichen um."),
    out("t16-3", "io", 3, "Der Scanner liest Zahlen, solange es welche gibt. Was wird ausgegeben?",
        r"""
        Scanner sc = new Scanner("4 7 1");
        int summe = 0;
        while (sc.hasNextInt()) {
            summe += sc.nextInt();
        }
        System.out.println(summe);
        """,
        "12",
        "hasNextInt() fragt jede Runde, ob noch eine Zahl kommt; nextInt() liest sie. 4 + 7 + 1 = 12."),
    fill("t16-4", "io", 4, "Ergänze: Der Scanner liest Vor- und Nachnamen, der StringBuilder baut „Nachname, Vorname“.",
         r"""
         Scanner sc = new Scanner("Grace Hopper");
         String vorname = sc.{{0}}();
         String nachname = sc.next();
         StringBuilder sb = new StringBuilder();
         sb.{{1}}(nachname).append(", ").append(vorname);
         System.out.println(sb);
         """,
         [["next"], ["append"]],
         "next() liest das erste Wort (Grace), append hängt die Teile in der gewünschten Reihenfolge an.",
         verify={"output": "Hopper, Grace"}),
    code("t16-5", "io", 5,
         "Baue mit einem StringBuilder und einer Schleife den Text „*****“ (fünf Sterne) und gib ihn aus – "
         "ohne die fünf Sterne direkt hinzuschreiben.",
         r"""
         StringBuilder sb = new StringBuilder();
         // 5 Sterne anhängen
         System.out.println(sb);
         """,
         r"""
         StringBuilder sb = new StringBuilder();
         for (int i = 0; i < 5; i++) {
             sb.append("*");
         }
         System.out.println(sb);
         """,
         [req(r"\bfor\s*\(|\bwhile\s*\(", "Nutze eine Schleife."),
          req(r"\.append\s*\(", "Hänge die Sterne mit append an."),
          forbid(r'"\*\*\*\*\*"', "Lass die Schleife die Sterne anhängen.", scope="raw")],
         "Fünf Runden, in jeder hängt append einen Stern an.",
         expected="*****",
         hint="for (int i = 0; i < 5; i++) { sb.append(\"*\"); }"),
])

l17 = lesson("l17-files-time", "Dateien, Datum & Uhrzeit", "Texte speichern und mit Kalenderdaten rechnen.",
             ["io", "datetime"], 10, [
    card("Dateien schreiben und lesen",
         "Mit der Klasse Files kann ein Programm Text dauerhaft speichern. Ein Path ist die Adresse der Datei. writeString "
         "schreibt Text hinein, readAllLines liest ihn Zeile für Zeile wieder aus. Weil dabei etwas schiefgehen kann "
         "(Festplatte voll, keine Rechte), gehört alles in ein try mit catch (IOException e).",
         code=r"""
         try {
             Path datei = Files.createTempFile("notizen", ".txt");
             Files.writeString(datei, "Einkaufen\nJava lernen");
             List<String> zeilen = Files.readAllLines(datei);
             System.out.println(zeilen.size() + " Zeilen");   // 2 Zeilen
             Files.delete(datei);
         } catch (IOException e) {
             System.out.println("Fehler: " + e.getMessage());
         }
         """,
         tip="Im echten Programm nimmst du einen festen Namen, z. B. Path.of(\"notizen.txt\") – createTempFile legt hier nur eine Übungsdatei an.",
         verify={"output": "2 Zeilen"}),
    card("Datum und Uhrzeit mit java.time",
         "LocalDate ist ein Kalenderdatum ohne Uhrzeit. Man kann damit rechnen: plusDays zählt Tage dazu, getDayOfWeek "
         "verrät den Wochentag, Period.between misst den Abstand. Ein DateTimeFormatter bestimmt, wie das Datum als Text "
         "aussieht – etwa deutsch mit Punkten.",
         code=r"""
         LocalDate start = LocalDate.of(2026, 9, 19);
         LocalDate ende = start.plusDays(14);
         System.out.println(ende);                      // 2026-10-03
         DateTimeFormatter format = DateTimeFormatter.ofPattern("dd.MM.yyyy");
         System.out.println(ende.format(format));       // 03.10.2026
         """,
         info="LocalDate.now() liefert das heutige Datum – hier nehmen wir ein festes Datum, damit das Ergebnis immer gleich ist.",
         verify={"output": "2026-10-03\n03.10.2026"}),
], [
    mc("t17-1", "io", 1, "Warum steht der Dateizugriff in einem try-catch-Block?",
       ["Weil dabei Fehler passieren können und Java verlangt, dass man darauf reagiert",
        "Weil Dateien sonst langsamer sind", "Weil try Dateien automatisch speichert", "Das ist nur eine Stilfrage"],
       "Dateizugriffe können scheitern (fehlende Rechte, volle Platte). Java zwingt dich, das Sicherheitsnetz catch "
       "für die IOException aufzuspannen."),
    out("t17-2", "datetime", 2, "Was wird ausgegeben?",
        r"""
        LocalDate d = LocalDate.of(2026, 12, 24);
        System.out.println(d.getDayOfMonth());
        System.out.println(d.plusDays(8));
        """,
        "24\n2027-01-01",
        "getDayOfMonth() ist der Tag im Monat (24). Acht Tage später ist schon Neujahr – LocalDate rechnet über "
        "Monats- und Jahresgrenzen hinweg."),
    out("t17-3", "datetime", 3, "Wie alt ist die Person am Stichtag?",
        r"""
        LocalDate geburt = LocalDate.of(2010, 5, 1);
        LocalDate stichtag = LocalDate.of(2026, 9, 19);
        Period alter = Period.between(geburt, stichtag);
        System.out.println(alter.getYears() + " Jahre");
        """,
        "16 Jahre",
        "Period.between misst den Abstand in Jahren, Monaten und Tagen; getYears() liefert die vollen Jahre: 16."),
    fill("t17-4", "io", 4, "Ergänze: Text in die Datei schreiben, alle Zeilen lesen und Fehler auffangen.",
         r"""
         try {
             Path datei = Files.createTempFile("liste", ".txt");
             Files.{{0}}(datei, "Brot\nMilch\nKaese");
             List<String> zeilen = Files.{{1}}(datei);
             System.out.println(zeilen.get(1));
             Files.delete(datei);
         } catch ({{2}} e) {
             System.out.println("Fehler");
         }
         """,
         [["writeString"], ["readAllLines"], ["IOException", "Exception"]],
         "writeString schreibt, readAllLines liest alle Zeilen als Liste; get(1) ist die zweite Zeile: Milch.",
         verify={"output": "Milch"}),
    code("t17-5", "datetime", 5,
         "Gib das Datum 3. Oktober 2026 im deutschen Format „03.10.2026“ aus – mit einem DateTimeFormatter.",
         r"""
         LocalDate tag = LocalDate.of(2026, 10, 3);
         // Formatter anlegen und ausgeben
         """,
         r"""
         LocalDate tag = LocalDate.of(2026, 10, 3);
         DateTimeFormatter format = DateTimeFormatter.ofPattern("dd.MM.yyyy");
         System.out.println(tag.format(format));
         """,
         [req(r"DateTimeFormatter\.ofPattern\s*\(", "Lege das Muster mit DateTimeFormatter.ofPattern(…) fest."),
          req(r'"dd\.MM\.yyyy"', "Das Muster für Tag.Monat.Jahr lautet \"dd.MM.yyyy\".", scope="raw"),
          req(r"\.format\s*\(", "Wandle das Datum mit format(…) in Text um."),
          forbid(r'"03\.10\.2026"', "Lass den Formatter den Text bauen.", scope="raw")],
         "dd = Tag zweistellig, MM = Monat zweistellig, yyyy = Jahr – so entsteht 03.10.2026.",
         expected="03.10.2026"),
])

# ---------------------------------------------------------------- Modul 8: Algorithmen

l18 = lesson("l18-recursion", "Rekursion", "Methoden, die eine kleinere Version ihrer Aufgabe an sich selbst weitergeben.",
             ["recursion"], 8, [
    card("Eine Methode, die sich selbst aufruft",
         "Rekursion heißt: Eine Methode löst eine Aufgabe, indem sie eine kleinere Version derselben Aufgabe an sich selbst "
         "weitergibt – wie russische Puppen, in denen immer eine kleinere steckt. Entscheidend ist die Abbruchbedingung "
         "(der Basisfall): Sie sagt, wann Schluss ist.",
         code=r"""
         static int fakultaet(int n) {
             if (n <= 1) {
                 return 1;
             }
             return n * fakultaet(n - 1);
         }
         """,
         verify={"context": "members", "main": "System.out.println(fakultaet(5));", "output": "120"}),
    card("Schritt für Schritt: So rechnet Java",
         "countdown(3) gibt 3 aus und ruft countdown(2) auf, das ruft countdown(1) auf und so weiter – bis n bei 0 ankommt. "
         "Dort greift der Basisfall: „Start!“ und Schluss.",
         code=r"""
         static void countdown(int n) {
             if (n == 0) {
                 System.out.println("Start!");
                 return;
             }
             System.out.println(n);
             countdown(n - 1);
         }
         """,
         warning="Fehlt der Basisfall, ruft sich die Methode endlos auf – bis Java mit einem StackOverflowError abbricht.",
         verify={"context": "members", "main": "countdown(3);", "output": "3\n2\n1\nStart!"}),
], [
    mc("t18-1", "recursion", 1, "Was braucht jede rekursive Methode unbedingt?",
       ["Eine Abbruchbedingung (Basisfall)", "Eine for-Schleife", "Einen Parameter vom Typ String", "Ein static-Feld"],
       "Ohne Basisfall würde sich die Methode endlos selbst aufrufen."),
    out("t18-2", "recursion", 2, "Was wird ausgegeben?",
        r"""
        static int summe(int n) {
            if (n == 0) {
                return 0;
            }
            return n + summe(n - 1);
        }

        public static void main(String[] args) {
            System.out.println(summe(4));
        }
        """,
        "10",
        "summe(4) = 4 + summe(3) = 4 + 3 + summe(2) = … = 4 + 3 + 2 + 1 + 0 = 10.",
        ctx="members"),
    out("t18-3", "recursion", 3, "Die Fibonacci-Folge beginnt 0, 1, 1, 2, 3, … Was wird ausgegeben?",
        r"""
        static int fib(int n) {
            if (n < 2) {
                return n;
            }
            return fib(n - 1) + fib(n - 2);
        }

        public static void main(String[] args) {
            System.out.println(fib(6));
        }
        """,
        "8",
        "Jede Zahl ist die Summe der beiden davor: 0, 1, 1, 2, 3, 5, 8 – an Position 6 steht die 8.",
        ctx="members"),
    fill("t18-4", "recursion", 4, "Ergänze den Basisfall und den rekursiven Aufruf: potenz(2, 5) soll 32 ergeben.",
         r"""
         static int potenz(int basis, int exponent) {
             if (exponent == {{0}}) {
                 return 1;
             }
             return basis * {{1}}(basis, exponent - 1);
         }

         public static void main(String[] args) {
             System.out.println(potenz(2, 5));
         }
         """,
         [["0"], ["potenz"]],
         "Hoch 0 ist immer 1 (Basisfall). Sonst: basis mal potenz mit einem kleineren Exponenten.",
         ctx="members", verify={"output": "32"}),
    code("t18-5", "recursion", 5,
         "Schreibe quersumme(int n) rekursiv – ohne Schleife. Beispiel: 472 → 4 + 7 + 2 = 13.",
         r"""
         static int quersumme(int n) {
             // rekursiv lösen
             return 0;
         }

         public static void main(String[] args) {
             System.out.println(quersumme(472));
         }
         """,
         r"""
         static int quersumme(int n) {
             if (n < 10) {
                 return n;
             }
             return n % 10 + quersumme(n / 10);
         }

         public static void main(String[] args) {
             System.out.println(quersumme(472));
         }
         """,
         [req(r"\bif\s*\(", "Lege einen Basisfall mit if an."),
          req(r"%\s*10", "Die letzte Ziffer bekommst du mit n % 10."),
          req(r"return[^;]*quersumme\s*\(", "Rufe quersumme in quersumme selbst auf."),
          forbid(r"\bfor\s*\(|\bwhile\s*\(", "Bitte ohne Schleife – rekursiv.")],
         "Letzte Ziffer (n % 10) plus die Quersumme vom Rest (n / 10). Eine einzelne Ziffer ist ihre eigene Quersumme.",
         expected="13",
         ctx="members",
         hint="return n % 10 + quersumme(n / 10);"),
])

l19 = lesson("l19-search-sort", "Suchen & Sortieren", "Schnell finden, geordnet ablegen – und wie viel Arbeit das kostet.",
             ["algorithms"], 9, [
    card("Suchen: Zettel für Zettel oder clever halbieren",
         "Die lineare Suche schaut sich jedes Element der Reihe nach an – bei 1000 Einträgen im schlimmsten Fall 1000 Blicke. "
         "Ist die Liste sortiert, geht es schneller: Die binäre Suche schaut in die Mitte und wirft die Hälfte weg, in der "
         "der Wert nicht sein kann – wie beim Suchen im Telefonbuch. Bei 1000 Einträgen reichen etwa 10 Blicke.",
         code=r"""
         static int binaereSuche(int[] zahlen, int ziel) {
             int links = 0;
             int rechts = zahlen.length - 1;
             while (links <= rechts) {
                 int mitte = (links + rechts) / 2;
                 if (zahlen[mitte] == ziel) {
                     return mitte;
                 } else if (zahlen[mitte] < ziel) {
                     links = mitte + 1;
                 } else {
                     rechts = mitte - 1;
                 }
             }
             return -1;
         }
         """,
         verify={"context": "members", "main": "System.out.println(binaereSuche(new int[]{1, 3, 5, 7, 9, 11}, 7));", "output": "3"}),
    card("Sortieren lassen",
         "Sortieren muss man selten selbst programmieren: Arrays.sort sortiert einen Eierkarton, sort mit einem Comparator "
         "sortiert eine Liste nach eigener Regel. Comparator.comparing(String::length) heißt: nach der Länge sortieren.",
         code=r"""
         int[] zahlen = {5, 2, 9, 1};
         Arrays.sort(zahlen);
         System.out.println(Arrays.toString(zahlen));   // [1, 2, 5, 9]

         List<String> namen = new ArrayList<>(List.of("Linus", "Ada", "Grace"));
         namen.sort(Comparator.comparing(String::length));
         System.out.println(namen);                     // [Ada, Linus, Grace]
         """,
         tip="Faustregel für den Aufwand: Die lineare Suche wächst mit der Anzahl der Elemente, die binäre Suche nur mit der Zahl der Halbierungen.",
         verify={"output": "[1, 2, 5, 9]\n[Ada, Linus, Grace]"}),
], [
    mc("t19-1", "algorithms", 1, "Was ist die Voraussetzung für die binäre Suche?",
       ["Die Daten müssen sortiert sein", "Die Daten müssen Texte sein",
        "Es dürfen höchstens 10 Elemente sein", "Man braucht eine HashMap"],
       "Nur in sortierten Daten weiß man nach einem Blick in die Mitte, in welcher Hälfte der Wert liegen muss."),
    mc("t19-2", "algorithms", 2,
       "Etwa wie viele Blicke braucht die binäre Suche höchstens bei 1 000 000 sortierten Einträgen?",
       ["Etwa 20", "Etwa 1 000", "Etwa 500 000", "Genau 1 000 000"],
       "Jeder Blick halbiert: nach 20 Halbierungen bleibt von einer Million nur noch ein Eintrag übrig (2^20 ≈ 1 Million)."),
    out("t19-3", "algorithms", 3, "Was wird ausgegeben?",
        r"""
        int[] punkte = {40, 15, 30, 25};
        Arrays.sort(punkte);
        System.out.println(punkte[0] + " " + punkte[3]);
        System.out.println(Arrays.toString(punkte));
        """,
        "15 40\n[15, 25, 30, 40]",
        "Nach dem Sortieren liegt die kleinste Zahl in Fach 0, die größte in Fach 3."),
    fill("t19-4", "algorithms", 4, "Ergänze die lineare Suche: Sie soll die Position von „Grace“ finden.",
         r"""
         static int finde(String[] namen, String gesucht) {
             for (int i = 0; i < namen.{{0}}; i++) {
                 if (namen[i].{{1}}(gesucht)) {
                     return i;
                 }
             }
             return -1;
         }

         public static void main(String[] args) {
             String[] team = {"Ada", "Linus", "Grace"};
             System.out.println(finde(team, "Grace"));
         }
         """,
         [["length"], ["equals"]],
         "Die Schleife läuft über alle Fächer (length); equals vergleicht die Texte. Grace liegt in Fach 2.",
         ctx="members", verify={"output": "2"}),
    code("t19-5", "algorithms", 5,
         "Sortiere woerter absteigend nach Länge (längstes Wort zuerst) und gib die Liste aus.",
         r"""
         List<String> woerter = new ArrayList<>(List.of("Kiwi", "Banane", "Apfel"));
         // sortieren
         System.out.println(woerter);
         """,
         r"""
         List<String> woerter = new ArrayList<>(List.of("Kiwi", "Banane", "Apfel"));
         woerter.sort(Comparator.comparing(String::length).reversed());
         System.out.println(woerter);
         """,
         [req(r"\.sort\s*\(|Collections\.sort\s*\(", "Sortiere die Liste mit sort."),
          req(r"length", "Sortiere nach der Länge."),
          req(r"reversed\s*\(|reverseOrder|b\.length\s*\(\s*\)\s*-\s*a\.length", "Absteigend: z. B. mit .reversed().")],
         "comparing(String::length) sortiert nach Länge, reversed() dreht die Reihenfolge um: Banane, Apfel, Kiwi.",
         expected="[Banane, Apfel, Kiwi]",
         hint="woerter.sort(Comparator.comparing(String::length).reversed());"),
])

l20 = lesson("l20-sets-queues", "Set, Stack & Queue", "Mengen ohne Doppelte, Stapel und Warteschlangen.",
             ["datastructures"], 9, [
    card("Set: jede Sache nur einmal",
         "Ein Set ist wie ein Stempelheft: Jeder Stempel kommt höchstens einmal hinein. Ein zweites add mit demselben "
         "Eintrag ändert nichts. HashSet merkt sich keine Reihenfolge, TreeSet hält alles automatisch sortiert.",
         code=r"""
         Set<String> besucht = new TreeSet<>();
         besucht.add("Rom");
         besucht.add("Paris");
         besucht.add("Rom");
         System.out.println(besucht);          // [Paris, Rom]
         System.out.println(besucht.size());   // 2
         """,
         verify={"output": "[Paris, Rom]\n2"}),
    card("Stapel und Warteschlange",
         "Ein Stapel (Stack) funktioniert wie ein Tellerstapel: Was zuletzt oben draufkommt, nimmt man zuerst wieder weg – "
         "push legt drauf, pop nimmt oben weg. Eine Warteschlange (Queue) ist wie die Schlange an der Kasse: Wer zuerst "
         "kommt, ist zuerst dran – offer stellt hinten an, poll holt vorne ab. ArrayDeque kann beides.",
         code=r"""
         Deque<String> stapel = new ArrayDeque<>();
         stapel.push("Teller 1");
         stapel.push("Teller 2");
         System.out.println(stapel.pop());      // Teller 2

         Queue<String> schlange = new ArrayDeque<>();
         schlange.offer("Ada");
         schlange.offer("Linus");
         System.out.println(schlange.poll());   // Ada
         """,
         verify={"output": "Teller 2\nAda"}),
], [
    mc("t20-1", "datastructures", 1,
       "Welche Datenstruktur passt für „Rückgängig“ in einem Textprogramm – die letzte Änderung wird zuerst zurückgenommen?",
       ["Ein Stapel (Stack)", "Eine Warteschlange (Queue)", "Ein Set", "Ein Array fester Länge"],
       "Was zuletzt passiert ist, wird zuerst zurückgenommen – genau wie beim Tellerstapel."),
    out("t20-2", "datastructures", 2, "Was wird ausgegeben?",
        r"""
        Set<Integer> zahlen = new TreeSet<>(List.of(5, 3, 5, 1, 3));
        System.out.println(zahlen);
        System.out.println(zahlen.contains(4));
        """,
        "[1, 3, 5]\nfalse",
        "Das TreeSet behält jede Zahl nur einmal und sortiert sie. Die 4 war nie dabei."),
    out("t20-3", "datastructures", 3, "Was wird ausgegeben?",
        r"""
        Deque<Integer> stapel = new ArrayDeque<>();
        stapel.push(1);
        stapel.push(2);
        stapel.push(3);
        stapel.pop();
        System.out.println(stapel.peek());
        System.out.println(stapel.size());
        """,
        "2\n2",
        "pop nimmt die 3 (zuletzt draufgelegt) weg. peek schaut nur nach, was jetzt oben liegt: die 2. Übrig sind 2 Teller."),
    fill("t20-4", "datastructures", 4, "Ergänze die Warteschlange an der Kasse: hinten anstellen, vorne abholen.",
         r"""
         Queue<String> kasse = new ArrayDeque<>();
         kasse.{{0}}("Ada");
         kasse.offer("Grace");
         kasse.offer("Linus");
         String zuerst = kasse.{{1}}();
         System.out.println(zuerst + " ist dran, " + kasse.size() + " warten");
         """,
         [["offer", "add"], ["poll", "remove"]],
         "offer stellt hinten an, poll holt die Person von vorne ab – Ada war zuerst da.",
         verify={"output": "Ada ist dran, 2 warten"}),
    code("t20-5", "datastructures", 5,
         "Zähle mit einem Set, wie viele verschiedene Wörter in woerter stehen, und gib die Zahl aus.",
         r"""
         List<String> woerter = List.of("ja", "nein", "ja", "vielleicht", "nein");
         // verschiedene Wörter zählen
         """,
         r"""
         List<String> woerter = List.of("ja", "nein", "ja", "vielleicht", "nein");
         Set<String> verschieden = new HashSet<>(woerter);
         System.out.println(verschieden.size());
         """,
         [req(r"\bSet\s*<|HashSet|TreeSet", "Nutze ein Set."),
          req(r"\.size\s*\(\s*\)", "Zähle mit size()."),
          forbid(r"println\s*\(\s*3\s*\)", "Lass das Set zählen.")],
         "Das Set behält ja, nein und vielleicht je einmal – size() ist 3.",
         expected="3"),
])

# ---------------------------------------------------------------- Modul 9: Profi-Werkzeuge

l21 = lesson("l21-testing", "Testen", "Prüfen, ob der Code das Richtige tut – automatisch.",
             ["testing"], 9, [
    card("Warum Tests?",
         "Ein Test ist ein kleines Programm, das deinen Code prüft: Es ruft eine Methode mit bekannten Zutaten auf und "
         "vergleicht das Ergebnis mit dem erwarteten. Läuft der Test nach jeder Änderung, merkst du sofort, wenn etwas "
         "kaputtgeht – wie ein Rauchmelder für Fehler.",
         code=r"""
         static int doppelt(int x) {
             return x * 2;
         }

         static void pruefe(String name, int erwartet, int erhalten) {
             if (erwartet == erhalten) {
                 System.out.println("OK: " + name);
             } else {
                 System.out.println("FEHLER: " + name);
             }
         }
         """,
         verify={"context": "members", "main": "pruefe(\"doppelt(4)\", 8, doppelt(4));", "output": "OK: doppelt(4)"}),
    card("JUnit: das Test-Werkzeug der Profis",
         "In echten Projekten schreibt man Tests mit JUnit. Jede Methode mit @Test ist ein Test. assertEquals vergleicht – "
         "zuerst kommt immer der erwartete Wert, dann das tatsächliche Ergebnis. Die Entwicklungsumgebung zeigt danach grün "
         "für bestanden und rot für fehlgeschlagen.",
         code=r"""
         import static org.junit.jupiter.api.Assertions.assertEquals;

         import org.junit.jupiter.api.Test;

         class Rechner {
             int addiere(int a, int b) {
                 return a + b;
             }
         }

         class RechnerTest {
             @Test
             void addiertZweiZahlen() {
                 Rechner rechner = new Rechner();
                 assertEquals(5, rechner.addiere(2, 3));
             }
         }
         """,
         info="JUnit gehört nicht zu Java selbst – es kommt über ein Build-Werkzeug wie Maven oder Gradle ins Projekt."),
], [
    mc("t21-1", "testing", 1, "Was macht ein Unit-Test?",
       ["Er ruft Code mit bekannten Werten auf und prüft, ob das erwartete Ergebnis herauskommt",
        "Er macht das Programm schneller", "Er übersetzt Java in eine andere Sprache", "Er löscht fehlerhaften Code"],
       "Ein Test vergleicht „erwartet“ mit „tatsächlich“ – so fallen Fehler auf, bevor jemand anderes sie findet."),
    mc("t21-2", "testing", 2, "In welcher Reihenfolge stehen die Werte bei assertEquals?",
       ["Erst der erwartete Wert (8), dann das tatsächliche Ergebnis", "Erst das Ergebnis, dann der erwartete Wert",
        "Es muss immer 0 zuerst stehen", "Die Werte stehen in zwei getrennten Zeilen"],
       "assertEquals(erwartet, tatsächlich) – so steht in der Fehlermeldung später richtig herum, was herauskommen sollte.",
       code=r"""
       assertEquals(8, rechner.addiere(3, 5));
       """,
       verify={"skip": True}),
    out("t21-3", "testing", 3, "Ein Test ist hier selbst falsch. Was wird ausgegeben?",
        r"""
        static boolean istGerade(int n) {
            return n % 2 == 0;
        }

        static void pruefe(String name, boolean erwartet, boolean erhalten) {
            if (erwartet == erhalten) {
                System.out.println("OK: " + name);
            } else {
                System.out.println("FEHLER: " + name);
            }
        }

        public static void main(String[] args) {
            pruefe("4 ist gerade", true, istGerade(4));
            pruefe("7 ist gerade", true, istGerade(7));
            pruefe("0 ist gerade", true, istGerade(0));
        }
        """,
        "OK: 4 ist gerade\nFEHLER: 7 ist gerade\nOK: 0 ist gerade",
        "istGerade(7) liefert false, der Test erwartet aber true. Der Code ist richtig – der Test hat einen Fehler. "
        "Auch Tests müssen stimmen!",
        ctx="members"),
    fill("t21-4", "testing", 4, "Ergänze den JUnit-Test: Er soll prüfen, dass „java“ in Großbuchstaben „JAVA“ ergibt.",
         r"""
         class TextTest {
             {{0}}
             void grossbuchstaben() {
                 {{1}}("JAVA", "java".toUpperCase());
             }
         }
         """,
         [["@Test"], ["assertEquals"]],
         "@Test markiert die Methode als Test, assertEquals vergleicht den erwarteten Text mit dem Ergebnis.",
         verify={"skip": True}),
    code("t21-5", "testing", 5,
         "Schreibe drei Prüfungen für verdopple mit pruefe(…): für 0, 5 und -2. Alle drei sollen „OK“ ausgeben.",
         r"""
         static int verdopple(int x) {
             return x * 2;
         }

         static void pruefe(String name, int erwartet, int erhalten) {
             if (erwartet == erhalten) {
                 System.out.println("OK: " + name);
             } else {
                 System.out.println("FEHLER: " + name);
             }
         }

         public static void main(String[] args) {
             // drei Prüfungen
         }
         """,
         r"""
         static int verdopple(int x) {
             return x * 2;
         }

         static void pruefe(String name, int erwartet, int erhalten) {
             if (erwartet == erhalten) {
                 System.out.println("OK: " + name);
             } else {
                 System.out.println("FEHLER: " + name);
             }
         }

         public static void main(String[] args) {
             pruefe("verdopple(0)", 0, verdopple(0));
             pruefe("verdopple(5)", 10, verdopple(5));
             pruefe("verdopple(-2)", -4, verdopple(-2));
         }
         """,
         [req(r"pruefe\s*\([^;]*\b0\s*,\s*verdopple\s*\(\s*0\s*\)", "Prüfe verdopple(0) mit dem erwarteten Wert 0."),
          req(r"pruefe\s*\([^;]*\b10\s*,\s*verdopple\s*\(\s*5\s*\)", "Prüfe verdopple(5) mit dem erwarteten Wert 10."),
          req(r"pruefe\s*\([^;]*-\s*4\s*,\s*verdopple\s*\(\s*-\s*2\s*\)", "Prüfe verdopple(-2) mit dem erwarteten Wert -4.")],
         "Jede Prüfung nennt den erwarteten Wert und ruft die Methode auf: 0 → 0, 5 → 10, -2 → -4.",
         expected="OK: verdopple(0)\nOK: verdopple(5)\nOK: verdopple(-2)",
         ctx="members",
         hint="pruefe(\"verdopple(5)\", 10, verdopple(5));"),
])

l22 = lesson("l22-tools-debugging", "Pakete, Build & Fehlersuche", "Ordnung in großen Projekten und Fehler systematisch finden.",
             ["tooling"], 9, [
    card("Pakete: Ordner für Klassen",
         "Große Programme haben Hunderte Klassen. Pakete sortieren sie wie Ordner: package steht ganz oben in der Datei und "
         "sagt, in welchem Ordner die Klasse liegt. Mit import holst du Klassen aus anderen Paketen, etwa List aus java.util. "
         "Der Paketname ist meist eine umgedrehte Internetadresse, damit er weltweit eindeutig ist.",
         code=r"""
         package de.meinprojekt.spiel;

         import java.util.List;

         public class Spieler {
             private final String name;

             public Spieler(String name) {
                 this.name = name;
             }
         }
         """),
    card("Build-Werkzeuge: Maven und Gradle",
         "Maven und Gradle sind wie ein Küchenhelfer für dein Projekt: Sie holen fremde Bibliotheken (z. B. JUnit) aus dem "
         "Internet, übersetzen den Code, starten alle Tests und packen am Ende ein fertiges Programm. Welche Bibliotheken ein "
         "Projekt braucht, steht in einer Datei – pom.xml bei Maven, build.gradle.kts bei Gradle. Ein Befehl wie "
         "„gradle test“ erledigt dann alles automatisch.",
         tip="Die Windows-Version dieser App wird übrigens selbst mit Gradle gebaut und getestet."),
    card("Fehlersuche: Stacktrace und Haltepunkt",
         "Stürzt ein Programm ab, zeigt Java einen Stacktrace: oben die Art des Fehlers und die Meldung, darunter die Kette "
         "der Aufrufe mit Zeilennummern. Die oberste Zeile aus deinem eigenen Code ist der beste Startpunkt. In der "
         "Entwicklungsumgebung hilft ein Haltepunkt (Breakpoint): Das Programm hält dort an, und du schaust in jede Box.",
         code=r"""
         String[] namen = {"Ada", "Linus"};
         try {
             System.out.println(namen[2]);
         } catch (ArrayIndexOutOfBoundsException e) {
             System.out.println("Fehler: " + e.getMessage());
         }
         """,
         verify={"output": "Fehler: Index 2 out of bounds for length 2"}),
], [
    mc("t22-1", "tooling", 1, "Was bewirkt die Zeile package de.schule.mathe; ganz oben in einer Datei?",
       ["Sie legt fest, in welchem Paket (Ordner) die Klasse liegt", "Sie lädt eine Bibliothek aus dem Internet",
        "Sie startet das Programm", "Sie macht die Klasse unsichtbar"],
       "package ordnet die Klasse in einen Ordner ein – hier de/schule/mathe."),
    mc("t22-2", "tooling", 2, "Wozu dient ein Build-Werkzeug wie Maven oder Gradle?",
       ["Es holt Bibliotheken, übersetzt den Code, startet Tests und packt das Programm", "Es ersetzt die main-Methode",
        "Es ist ein Texteditor", "Es macht Java-Code kürzer"],
       "Build-Werkzeuge erledigen alle wiederkehrenden Schritte mit einem einzigen Befehl."),
    out("t22-3", "tooling", 3, "Was wird ausgegeben?",
        r"""
        String text = null;
        try {
            System.out.println(text.length());
        } catch (NullPointerException e) {
            System.out.println("Box ist leer");
        }
        System.out.println("weiter");
        """,
        "Box ist leer\nweiter",
        "text ist leer (null) – length() löst eine NullPointerException aus. Das Sicherheitsnetz fängt sie auf, danach "
        "läuft das Programm normal weiter."),
    fill("t22-4", "tooling", 4, "Ergänze das Sicherheitsnetz, damit die Division durch 0 das Programm nicht abbrechen lässt.",
         r"""
         int[] werte = {3, 0, 4};
         for (int i = 0; i < werte.length; i++) {
             try {
                 System.out.println(12 / werte[i]);
             } {{0}} ({{1}} e) {
                 System.out.println("Division durch 0 bei Index " + i);
             }
         }
         """,
         [["catch"], ["ArithmeticException", "RuntimeException", "Exception"]],
         "Beim Index 1 steht eine 0 – 12 / 0 löst eine ArithmeticException aus, catch fängt sie auf, die Schleife läuft weiter.",
         verify={"output": "4\nDivision durch 0 bei Index 1\n3"}),
    code("t22-5", "tooling", 5,
         "Fehlersuche: Der Code soll die Summe von 1 bis 5 ausgeben (15), liefert aber 10. Finde den Fehler und behebe ihn.",
         r"""
         int summe = 0;
         for (int i = 1; i < 5; i++) {
             summe += i;
         }
         System.out.println(summe);
         """,
         r"""
         int summe = 0;
         for (int i = 1; i <= 5; i++) {
             summe += i;
         }
         System.out.println(summe);
         """,
         [req(r"i\s*<=\s*5|i\s*<\s*6", "Die Schleife muss auch die 5 noch mitnehmen."),
          req(r"summe\s*\+=\s*i|summe\s*=\s*summe\s*\+\s*i", "Zähle i in jeder Runde zu summe dazu."),
          forbid(r"println\s*\(\s*15\s*\)", "Repariere die Schleife, statt 15 hinzuschreiben.")],
         "i < 5 hört bei 4 auf (1 + 2 + 3 + 4 = 10). Mit i <= 5 kommt die 5 dazu: 15. Ein klassischer „Einer-daneben“-Fehler.",
         expected="15",
         hint="Wie oft läuft die Schleife? Schreib dir i in jeder Runde auf."),
])

# ---------------------------------------------------------------- Modul 10: Nebenläufigkeit

l23 = lesson("l23-threads", "Threads", "Mehrere Arbeitsstränge gleichzeitig – und worauf man achten muss.",
             ["concurrency"], 10, [
    card("Mehrere Dinge gleichzeitig",
         "Ein Thread ist ein eigener Arbeitsstrang – wie ein zweiter Koch in der Küche. start() lässt ihn loslaufen, join() "
         "wartet, bis er fertig ist. Was zwei Köche gleichzeitig tun, passiert in unvorhersehbarer Reihenfolge – deshalb "
         "wartet man mit join, bevor man das Ergebnis benutzt.",
         code=r"""
         Thread helfer = new Thread(() -> System.out.println("Helfer: Gemüse geschnitten"));
         helfer.start();
         helfer.join();
         System.out.println("Chef: Jetzt wird gekocht");
         """,
         warning="join() kann unterbrochen werden – deshalb braucht main dann den Zusatz throws InterruptedException.",
         verify={"output": "Helfer: Gemüse geschnitten\nChef: Jetzt wird gekocht"}),
    card("Wenn zwei gleichzeitig zählen",
         "Erhöhen zwei Threads dieselbe Box gleichzeitig, können Schritte verloren gehen: Beide lesen 5, beide schreiben 6. "
         "Das heißt Race Condition (Wettlauf). Abhilfe: Ein AtomicInteger zählt sicher, oder synchronized lässt immer nur "
         "einen Thread hinein – wie ein Schlüssel für die Küchentür.",
         code=r"""
         AtomicInteger zaehler = new AtomicInteger();
         Runnable arbeit = () -> {
             for (int i = 0; i < 1000; i++) {
                 zaehler.incrementAndGet();
             }
         };
         Thread a = new Thread(arbeit);
         Thread b = new Thread(arbeit);
         a.start();
         b.start();
         a.join();
         b.join();
         System.out.println(zaehler.get());   // 2000
         """,
         verify={"output": "2000"}),
], [
    mc("t23-1", "concurrency", 1, "Was macht join() bei einem Thread?",
       ["Es wartet, bis der Thread fertig ist", "Es startet den Thread", "Es beendet das Programm sofort",
        "Es verbindet zwei Threads zu einem"],
       "start() lässt den Thread loslaufen, join() wartet auf sein Ende."),
    mc("t23-2", "concurrency", 2,
       "Zwei Threads geben gleichzeitig „A“ und „B“ aus – ohne join und ohne Absprache. Was lässt sich über die Reihenfolge sagen?",
       ["Sie ist nicht vorhersehbar – mal A zuerst, mal B", "Immer A zuerst", "Immer B zuerst", "Es erscheint nur A"],
       "Threads laufen unabhängig. Welcher zuerst drankommt, entscheidet das Betriebssystem – jedes Mal neu."),
    out("t23-3", "concurrency", 3, "Was wird ausgegeben?",
        r"""
        Thread t = new Thread(() -> System.out.println("im Thread"));
        System.out.println("vor start");
        t.start();
        t.join();
        System.out.println("nach join");
        """,
        "vor start\nim Thread\nnach join",
        "„vor start“ kommt, bevor der Thread überhaupt läuft. join wartet, bis „im Thread“ ausgegeben ist – erst dann geht es weiter."),
    fill("t23-4", "concurrency", 4, "Ergänze: Den Spieler-Thread loslaufen lassen und auf ihn warten.",
         r"""
         AtomicInteger punkte = new AtomicInteger();
         Thread spieler = new Thread(() -> punkte.addAndGet(10));
         spieler.{{0}}();
         spieler.{{1}}();
         System.out.println(punkte.get());
         """,
         [["start"], ["join"]],
         "start() lässt den Thread die 10 Punkte gutschreiben, join() wartet darauf – dann stimmt die Ausgabe sicher.",
         verify={"output": "10"}),
    code("t23-5", "concurrency", 5,
         "Starte zwei Threads, die jeweils 500-mal den AtomicInteger zaehler erhöhen. Warte auf beide und gib den "
         "Zählerstand aus (1000).",
         r"""
         AtomicInteger zaehler = new AtomicInteger();
         // zwei Threads starten, auf beide warten
         System.out.println(zaehler.get());
         """,
         r"""
         AtomicInteger zaehler = new AtomicInteger();
         Runnable arbeit = () -> {
             for (int i = 0; i < 500; i++) {
                 zaehler.incrementAndGet();
             }
         };
         Thread a = new Thread(arbeit);
         Thread b = new Thread(arbeit);
         a.start();
         b.start();
         a.join();
         b.join();
         System.out.println(zaehler.get());
         """,
         [req(r"new\s+Thread\s*\(", "Lege Threads mit new Thread(…) an."),
          req(r"\.start\s*\(\s*\)", "Starte die Threads mit start()."),
          req(r"\.join\s*\(\s*\)[\s\S]*\.join\s*\(\s*\)", "Warte mit join() auf beide Threads."),
          req(r"incrementAndGet|getAndIncrement|addAndGet", "Erhöhe den Zähler, z. B. mit incrementAndGet()."),
          req(r"\b500\b", "Jeder Thread zählt 500-mal."),
          forbid(r"println\s*\(\s*1000\s*\)", "Lass die Threads zählen.")],
         "Beide Threads zählen je 500-mal; der AtomicInteger verliert keinen Schritt – nach beiden join steht er sicher bei 1000.",
         expected="1000",
         hint="Runnable arbeit = () -> { for (…) { zaehler.incrementAndGet(); } };"),
])

l24 = lesson("l24-executors", "Executor & virtuelle Threads", "Aufgaben an ein Team verteilen – und Tausende leichte Threads.",
             ["concurrency"], 9, [
    card("Ein Team statt einzelner Helfer",
         "Threads einzeln zu verwalten ist mühsam. Ein ExecutorService ist wie eine Küchenleitung mit festem Team: Du reichst "
         "Aufgaben mit submit ein, das Team arbeitet sie ab. Für jede Aufgabe bekommst du ein Future – einen Abholschein, "
         "mit dem du später per get() das Ergebnis abholst. try (…) schließt die Küche am Ende automatisch.",
         code=r"""
         try (ExecutorService team = Executors.newFixedThreadPool(2)) {
             Future<Integer> a = team.submit(() -> 6 * 7);
             Future<Integer> b = team.submit(() -> 10 + 5);
             System.out.println(a.get() + b.get());   // 57
         }
         """,
         verify={"output": "57"}),
    card("Virtuelle Threads: Tausende Helfer ganz leicht",
         "Seit Java 21 gibt es virtuelle Threads. Sie sind so leicht, dass man für jede Aufgabe einen eigenen nehmen kann – "
         "auch für zehntausend Aufgaben, die gleichzeitig auf Antworten aus dem Internet warten. Der Code sieht fast genauso "
         "aus; nur der Executor ist ein anderer.",
         code=r"""
         try (ExecutorService pro = Executors.newVirtualThreadPerTaskExecutor()) {
             List<Future<Integer>> ergebnisse = new ArrayList<>();
             for (int i = 1; i <= 3; i++) {
                 int zahl = i;
                 ergebnisse.add(pro.submit(() -> zahl * zahl));
             }
             for (Future<Integer> f : ergebnisse) {
                 System.out.println(f.get());
             }
         }
         """,
         tip="Einen einzelnen virtuellen Thread startest du mit Thread.ofVirtual().start(…).",
         verify={"output": "1\n4\n9"}),
], [
    mc("t24-1", "concurrency", 1, "Was ist ein Future?",
       ["Ein Abholschein für ein Ergebnis, das erst später fertig wird", "Ein Thread, der nie endet",
        "Eine Liste aller Threads", "Ein Fehler, der erst später auftritt"],
       "submit liefert sofort ein Future zurück; get() holt das Ergebnis ab, sobald es fertig ist."),
    mc("t24-2", "concurrency", 2, "Wofür eignen sich virtuelle Threads besonders?",
       ["Für sehr viele Aufgaben, die oft warten – z. B. auf Antworten aus dem Netzwerk", "Nur für Grafik",
        "Für genau eine Aufgabe pro Programm", "Um den Arbeitsspeicher zu löschen"],
       "Virtuelle Threads kosten fast nichts – ideal, wenn Tausende Aufgaben gleichzeitig warten."),
    out("t24-3", "concurrency", 3, "Was wird ausgegeben?",
        r"""
        try (ExecutorService team = Executors.newFixedThreadPool(2)) {
            Future<String> gruss = team.submit(() -> "Hallo");
            Future<Integer> zahl = team.submit(() -> 2 * 21);
            System.out.println(gruss.get() + " " + zahl.get());
        }
        """,
        "Hallo 42",
        "Beide Aufgaben laufen im Team; get() wartet jeweils, bis das Ergebnis fertig ist."),
    fill("t24-4", "concurrency", 4,
         "Ergänze: Ein Executor mit virtuellen Threads rechnet 1 + 2 + 3, das Ergebnis wird mit dem Abholschein abgeholt.",
         r"""
         try (ExecutorService pro = Executors.{{0}}()) {
             Future<Integer> summe = pro.{{1}}(() -> 1 + 2 + 3);
             System.out.println(summe.{{2}}());
         }
         """,
         [["newVirtualThreadPerTaskExecutor"], ["submit"], ["get"]],
         "newVirtualThreadPerTaskExecutor gibt jeder Aufgabe einen virtuellen Thread, submit reicht sie ein, get holt 6 ab.",
         verify={"output": "6"}),
    code("t24-5", "concurrency", 5,
         "Reiche drei Aufgaben ein, die 10, 20 und 30 liefern, und gib die Summe aller Ergebnisse aus (60).",
         r"""
         try (ExecutorService team = Executors.newFixedThreadPool(3)) {
             // drei Aufgaben einreichen, Ergebnisse addieren
         }
         """,
         r"""
         try (ExecutorService team = Executors.newFixedThreadPool(3)) {
             Future<Integer> a = team.submit(() -> 10);
             Future<Integer> b = team.submit(() -> 20);
             Future<Integer> c = team.submit(() -> 30);
             System.out.println(a.get() + b.get() + c.get());
         }
         """,
         [req(r"(\.submit\s*\([\s\S]*){3}", "Reiche drei Aufgaben mit submit ein."),
          req(r"\.get\s*\(\s*\)", "Hol die Ergebnisse mit get() ab."),
          forbid(r"println\s*\(\s*60\s*\)", "Lass das Team rechnen.")],
         "Drei Abholscheine, drei get() – 10 + 20 + 30 = 60.",
         expected="60",
         hint="Future<Integer> a = team.submit(() -> 10);"),
])

# ---------------------------------------------------------------- Modul 11: Modernes Java vertieft

l25 = lesson("l25-sealed-patterns", "sealed & Pattern Matching", "Geschlossene Familien von Typen und Muster im switch.",
             ["patterns"], 10, [
    card("sealed: eine geschlossene Familie",
         "Mit sealed legst du fest, welche Klassen eine Kuchenform erweitern dürfen – eine geschlossene Familie. permits zählt "
         "die erlaubten Mitglieder auf. Dafür weiß Java genau, welche Möglichkeiten es gibt, und prüft, ob ein switch alle abdeckt.",
         code=r"""
         sealed interface Form permits Kreis, Rechteck {}

         record Kreis(double radius) implements Form {}

         record Rechteck(double breite, double hoehe) implements Form {}
         """,
         verify={"context": "file", "main": "System.out.println(new Kreis(1));", "output": "Kreis[radius=1.0]"}),
    card("Muster im switch",
         "Ein switch kann nicht nur Werte, sondern Sorten erkennen: case Kreis k passt, wenn es ein Kreis ist, und klebt das "
         "Namensschild k darauf. Mit einem Record-Muster packst du die Zutaten gleich aus: case Rechteck(double b, double h). "
         "when ergänzt eine zusätzliche Bedingung.",
         code=r"""
         static String beschreibe(Form f) {
             return switch (f) {
                 case Kreis k -> "Kreis mit Radius " + k.radius();
                 case Rechteck(double b, double h) when b == h -> "Quadrat mit Seite " + b;
                 case Rechteck(double b, double h) -> "Rechteck " + b + " x " + h;
             };
         }
         """,
         tip="Weil Form versiegelt ist, braucht dieser switch kein default – Java weiß, dass es keine weiteren Formen gibt."),
], [
    mc("t25-1", "patterns", 1, "Was bedeutet sealed interface Tier permits Hund, Katze?",
       ["Nur Hund und Katze dürfen Tier umsetzen", "Tier kann nicht benutzt werden", "Hund und Katze sind privat",
        "Tier darf beliebig viele Umsetzungen haben"],
       "sealed schließt die Familie; permits zählt alle erlaubten Mitglieder auf."),
    out("t25-2", "patterns", 2, "Was wird ausgegeben?",
        r"""
        record Punkt(int x, int y) {}

        public class Main {
            public static void main(String[] args) {
                Object o = new Punkt(3, 4);
                if (o instanceof Punkt(int x, int y)) {
                    System.out.println(x + y);
                }
            }
        }
        """,
        "7",
        "Das Record-Muster prüft, ob o ein Punkt ist, und packt x und y gleich in eigene Boxen aus: 3 + 4 = 7.",
        ctx="file"),
    out("t25-3", "patterns", 3, "Was wird ausgegeben?",
        r"""
        sealed interface Fahrzeug permits Auto, Fahrrad {}
        record Auto(int ps) implements Fahrzeug {}
        record Fahrrad(int gaenge) implements Fahrzeug {}

        public class Main {
            static String info(Fahrzeug f) {
                return switch (f) {
                    case Auto a when a.ps() > 200 -> "schnelles Auto";
                    case Auto a -> "Auto";
                    case Fahrrad r -> "Fahrrad mit " + r.gaenge() + " Gängen";
                };
            }

            public static void main(String[] args) {
                System.out.println(info(new Auto(300)));
                System.out.println(info(new Fahrrad(21)));
            }
        }
        """,
        "schnelles Auto\nFahrrad mit 21 Gängen",
        "Das Auto hat 300 PS – der Fall mit when passt zuerst. Das Fahrrad passt zum dritten Fall.",
        ctx="file"),
    fill("t25-4", "patterns", 4, "Ergänze: Getraenk ist eine geschlossene Familie, der switch erkennt die Sorte.",
         r"""
         {{0}} interface Getraenk permits Kaffee, Tee {}
         record Kaffee(boolean mitMilch) implements Getraenk {}
         record Tee(String sorte) implements Getraenk {}

         public class Main {
             static String bestellung(Getraenk g) {
                 return {{1}} (g) {
                     case Kaffee k -> "Kaffee";
                     case Tee(String sorte) -> sorte + "-Tee";
                 };
             }

             public static void main(String[] args) {
                 System.out.println(bestellung(new Tee("Pfefferminz")));
             }
         }
         """,
         [["sealed"], ["switch"]],
         "sealed schließt die Familie, der switch erkennt den Tee und packt seine Sorte aus: Pfefferminz-Tee.",
         ctx="file", verify={"output": "Pfefferminz-Tee"}),
    code("t25-5", "patterns", 5,
         "Ergänze flaeche mit einem switch über die Form: Kreis → π · r · r, Quadrat → seite · seite. Ausgegeben wird die "
         "Fläche des Quadrats mit Seite 3.",
         r"""
         sealed interface Form permits Kreis, Quadrat {}
         record Kreis(double r) implements Form {}
         record Quadrat(double seite) implements Form {}

         public class Main {
             static double flaeche(Form f) {
                 // switch über f
                 return 0;
             }

             public static void main(String[] args) {
                 System.out.println(flaeche(new Quadrat(3)));
             }
         }
         """,
         r"""
         sealed interface Form permits Kreis, Quadrat {}
         record Kreis(double r) implements Form {}
         record Quadrat(double seite) implements Form {}

         public class Main {
             static double flaeche(Form f) {
                 return switch (f) {
                     case Kreis k -> Math.PI * k.r() * k.r();
                     case Quadrat q -> q.seite() * q.seite();
                 };
             }

             public static void main(String[] args) {
                 System.out.println(flaeche(new Quadrat(3)));
             }
         }
         """,
         [req(r"switch\s*\(\s*f\s*\)", "Nutze einen switch über f."),
          req(r"case\s+Kreis\b", "Behandle den Kreis."),
          req(r"case\s+Quadrat\b", "Behandle das Quadrat."),
          req(r"Math\.PI", "Für den Kreis brauchst du Math.PI.")],
         "Der switch erkennt die Sorte und rechnet passend: Quadrat mit Seite 3 → 9.0.",
         expected="9.0",
         ctx="file",
         hint="return switch (f) { case Kreis k -> …; case Quadrat q -> …; };"),
])

l26 = lesson("l26-streams-pro", "Streams für Profis", "Gruppieren, zusammenfassen und verschachtelte Listen flach machen.",
             ["lambdas"], 10, [
    card("Gruppieren und zählen",
         "Collectors.groupingBy sortiert Elemente in Fächer – wie Post in Briefkästen. Heraus kommt ein Wörterbuch (Map): "
         "Schlüssel ist das Fach, Wert das, was darin liegt. Mit Collectors.counting() zählst du nur, wie viele in jedem "
         "Fach liegen; TreeMap::new hält die Fächer sortiert.",
         code=r"""
         List<String> woerter = List.of("Hut", "Bus", "Apfel", "Zug", "Birne");
         Map<Integer, Long> nachLaenge = woerter.stream()
                 .collect(Collectors.groupingBy(String::length, TreeMap::new, Collectors.counting()));
         System.out.println(nachLaenge);   // {3=3, 5=2}
         """,
         verify={"output": "{3=3, 5=2}"}),
    card("Sortieren, zusammenfassen, flach machen",
         "sorted bringt die Elemente in Reihenfolge. reduce fasst alles zu einem einzigen Wert zusammen – wie ein Trichter. "
         "flatMap macht aus einer Liste von Listen eine einzige flache Liste.",
         code=r"""
         List<List<Integer>> kisten = List.of(List.of(3, 1), List.of(2), List.of(5, 4));
         List<Integer> alle = kisten.stream()
                 .flatMap(List::stream)
                 .sorted()
                 .toList();
         System.out.println(alle);      // [1, 2, 3, 4, 5]
         int produkt = alle.stream().reduce(1, (a, b) -> a * b);
         System.out.println(produkt);   // 120
         """,
         verify={"output": "[1, 2, 3, 4, 5]\n120"}),
], [
    mc("t26-1", "lambdas", 1, "Was liefert Collectors.groupingBy?",
       ["Ein Wörterbuch (Map): zu jedem Schlüssel die passenden Elemente", "Eine einzelne Zahl",
        "Einen sortierten Text", "Nichts – es gibt nur aus"],
       "groupingBy sortiert in Fächer – das Ergebnis ist eine Map von Fach zu Inhalt."),
    out("t26-2", "lambdas", 2, "Was wird ausgegeben?",
        r"""
        List<Integer> zahlen = List.of(4, 1, 3);
        System.out.println(zahlen.stream().sorted().toList());
        System.out.println(zahlen.stream().reduce(0, (a, b) -> a + b));
        """,
        "[1, 3, 4]\n8",
        "sorted ordnet aufsteigend; reduce startet bei 0 und zählt alles zusammen: 4 + 1 + 3 = 8."),
    out("t26-3", "lambdas", 3, "Die Tiere werden nach dem ersten Buchstaben gruppiert. Was wird ausgegeben?",
        r"""
        List<String> tiere = List.of("Hund", "Hai", "Katze", "Kuh");
        Map<Character, List<String>> gruppen = tiere.stream()
                .collect(Collectors.groupingBy(t -> t.charAt(0), TreeMap::new, Collectors.toList()));
        System.out.println(gruppen);
        """,
        "{H=[Hund, Hai], K=[Katze, Kuh]}",
        "Jedes Tier landet im Fach seines Anfangsbuchstabens; die Reihenfolge innerhalb eines Fachs bleibt erhalten."),
    fill("t26-4", "lambdas", 4, "Ergänze: Alle Namen aus beiden Klassen in einer flachen, sortierten Liste.",
         r"""
         List<List<String>> klassen = List.of(List.of("Linus", "Ada"), List.of("Grace"));
         List<String> alle = klassen.stream()
                 .{{0}}(List::stream)
                 .{{1}}()
                 .toList();
         System.out.println(alle);
         """,
         [["flatMap"], ["sorted"]],
         "flatMap macht aus zwei Listen eine, sorted ordnet alphabetisch.",
         verify={"output": "[Ada, Grace, Linus]"}),
    code("t26-5", "lambdas", 5,
         "Finde mit einem Stream das längste Wort in woerter und gib es aus – ohne Schleife.",
         r"""
         List<String> woerter = List.of("Tee", "Kakao", "Saft");
         // längstes Wort finden
         """,
         r"""
         List<String> woerter = List.of("Tee", "Kakao", "Saft");
         String laengstes = woerter.stream()
                 .max(Comparator.comparing(String::length))
                 .orElse("");
         System.out.println(laengstes);
         """,
         [req(r"\.stream\s*\(\s*\)", "Starte mit woerter.stream()."),
          req(r"\.max\s*\(|\.sorted\s*\(|\.reduce\s*\(", "Suche das größte Element, z. B. mit max(…)."),
          req(r"length", "Vergleiche nach der Länge."),
          forbid(r"\bfor\s*\(|\bwhile\s*\(", "Bitte ohne Schleife."),
          forbid(r'println\s*\(\s*"Kakao"', "Lass den Stream suchen.", scope="raw")],
         "max mit Comparator.comparing(String::length) findet das längste Wort; orElse gibt einen Ersatz, falls die Liste leer wäre.",
         expected="Kakao",
         hint=".max(Comparator.comparing(String::length)).orElse(\"\")"),
])

# ---------------------------------------------------------------- Modul 12: Abschlussprojekte

l27 = lesson("l27-project-grades", "Projekt: Notenrechner", "Durchschnitt, beste Note und ein Bericht in Worten.",
             ["projects"], 10, [
    card("Das Projekt",
         "Wir bauen Schritt für Schritt einen Notenrechner: Er nimmt die Noten einer Klassenarbeit, berechnet den "
         "Durchschnitt, findet die beste Note und schreibt einen kleinen Bericht. Dabei kommen Arrays, Methoden, Streams "
         "und switch zusammen – alles, was du schon kennst.",
         code=r"""
         int[] noten = {2, 1, 3, 2, 4};
         double schnitt = Arrays.stream(noten).average().orElse(0);
         int beste = Arrays.stream(noten).min().orElse(0);
         System.out.println("Durchschnitt: " + schnitt);   // Durchschnitt: 2.4
         System.out.println("Beste Note: " + beste);       // Beste Note: 1
         """,
         verify={"output": "Durchschnitt: 2.4\nBeste Note: 1"}),
    card("Die Note in Worte fassen",
         "Ein switch-Ausdruck übersetzt die Zahl in ein Wort. So wird aus dem Rechner ein Bericht, den jeder versteht.",
         code=r"""
         static String inWorten(int note) {
             return switch (note) {
                 case 1 -> "sehr gut";
                 case 2 -> "gut";
                 case 3 -> "befriedigend";
                 case 4 -> "ausreichend";
                 default -> "nicht bestanden";
             };
         }
         """,
         verify={"context": "members", "main": "System.out.println(inWorten(2));", "output": "gut"}),
], [
    mc("t27-1", "projects", 1, "Welcher Datentyp passt für den Durchschnitt der Noten 2, 1 und 2?",
       ["double – der Schnitt hat Nachkommastellen (1,67)", "int", "boolean", "char"],
       "Ein Durchschnitt ist selten eine ganze Zahl – dafür braucht es eine Kommazahl (double)."),
    out("t27-2", "projects", 2, "Was wird ausgegeben?",
        r"""
        int[] noten = {1, 2, 2, 3};
        int summe = 0;
        for (int n : noten) {
            summe += n;
        }
        System.out.println(summe);
        System.out.println((double) summe / noten.length);
        """,
        "8\n2.0",
        "Die Summe ist 8. (double) macht aus der ganzen Zahl eine Kommazahl, bevor geteilt wird: 8 / 4 = 2.0."),
    out("t27-3", "projects", 3, "Bestanden ist bis Note 4. Was wird ausgegeben?",
        r"""
        static int anzahlBestanden(int[] noten) {
            int anzahl = 0;
            for (int n : noten) {
                if (n <= 4) {
                    anzahl++;
                }
            }
            return anzahl;
        }

        public static void main(String[] args) {
            int[] noten = {2, 5, 4, 6, 1};
            System.out.println(anzahlBestanden(noten) + " von " + noten.length + " bestanden");
        }
        """,
        "3 von 5 bestanden",
        "Die Noten 2, 4 und 1 sind höchstens 4 – das sind 3 von 5.",
        ctx="members"),
    fill("t27-4", "projects", 4, "Ergänze: Durchschnitt und beste (kleinste) Note mit Streams.",
         r"""
         int[] noten = {3, 1, 2, 2};
         double schnitt = Arrays.stream(noten).{{0}}().orElse(0);
         int beste = Arrays.stream(noten).{{1}}().orElse(0);
         System.out.println(schnitt + " / " + beste);
         """,
         [["average"], ["min"]],
         "average bildet den Durchschnitt (8 / 4 = 2.0), min findet die kleinste Zahl – die beste Note 1.",
         verify={"output": "2.0 / 1"}),
    code("t27-5", "projects", 5,
         "Schreibe bericht(int[] noten): Er gibt „Schnitt: …, beste Note: …“ aus. Aufgerufen wird er mit {2, 3, 1, 2}.",
         r"""
         static void bericht(int[] noten) {
             // Schnitt und beste Note berechnen und ausgeben
         }

         public static void main(String[] args) {
             bericht(new int[]{2, 3, 1, 2});
         }
         """,
         r"""
         static void bericht(int[] noten) {
             double schnitt = Arrays.stream(noten).average().orElse(0);
             int beste = Arrays.stream(noten).min().orElse(0);
             System.out.println("Schnitt: " + schnitt + ", beste Note: " + beste);
         }

         public static void main(String[] args) {
             bericht(new int[]{2, 3, 1, 2});
         }
         """,
         [req(r"average\s*\(|/\s*noten\.length", "Berechne den Durchschnitt, z. B. mit average()."),
          req(r"\bmin\s*\(|Math\.min", "Finde die beste (kleinste) Note, z. B. mit min()."),
          req(r'"Schnitt: ', "Beginne die Ausgabe mit „Schnitt: “.", scope="raw"),
          req(r"beste Note", "Nenne auch die beste Note.", scope="raw"),
          forbid(r'"Schnitt: 2\.0', "Lass den Rechner rechnen.", scope="raw")],
         "Durchschnitt (8 / 4 = 2.0) und kleinste Note (1) – fertig ist der Bericht.",
         expected="Schnitt: 2.0, beste Note: 1",
         ctx="members",
         hint="double schnitt = Arrays.stream(noten).average().orElse(0);"),
])

l28 = lesson("l28-project-todo", "Projekt: Aufgabenliste", "Eine To-do-Liste mit Records, Listen und Streams.",
             ["projects"], 10, [
    card("Das Projekt",
         "Jetzt entsteht eine kleine Aufgabenliste (To-do-Liste). Jede Aufgabe ist ein Record mit Titel und Häkchen "
         "(erledigt ja/nein). Die Liste wächst mit add, ein Stream zählt die offenen Aufgaben.",
         code=r"""
         record Aufgabe(String titel, boolean erledigt) {}

         List<Aufgabe> liste = new ArrayList<>();
         liste.add(new Aufgabe("Einkaufen", false));
         liste.add(new Aufgabe("Java lernen", true));
         long offen = liste.stream().filter(a -> !a.erledigt()).count();
         System.out.println(offen + " offen");   // 1 offen
         """,
         verify={"output": "1 offen"}),
    card("Abhaken und anzeigen",
         "Records lassen sich nicht verändern. Zum Abhaken ersetzt du die alte Aufgabe durch eine neue mit Häkchen – set "
         "tauscht den Eintrag an einer Stelle aus. Das Fragezeichen ist eine Kurzform von if-else: Bedingung ? wenn ja : wenn nein.",
         code=r"""
         record Aufgabe(String titel, boolean erledigt) {}

         List<Aufgabe> liste = new ArrayList<>();
         liste.add(new Aufgabe("Einkaufen", false));
         Aufgabe alt = liste.get(0);
         liste.set(0, new Aufgabe(alt.titel(), true));
         String haken = liste.get(0).erledigt() ? "[x]" : "[ ]";
         System.out.println(haken + " " + liste.get(0).titel());   // [x] Einkaufen
         """,
         verify={"output": "[x] Einkaufen"}),
], [
    mc("t28-1", "projects", 1, "Warum passt ein Record gut für eine Aufgabe?",
       ["Er bündelt Titel und Häkchen und bringt equals und toString gleich mit", "Er kann sich selbst abhaken",
        "Er speichert Daten automatisch in einer Datei", "Er ist schneller als jede Liste"],
       "Ein Record ist ein fertiges Formular für Daten – mit allem, was man zum Vergleichen und Anzeigen braucht."),
    out("t28-2", "projects", 2, "Was wird ausgegeben?",
        r"""
        record Aufgabe(String titel, boolean erledigt) {}

        Aufgabe a = new Aufgabe("Sport", false);
        System.out.println(a.titel());
        System.out.println(a);
        """,
        "Sport\nAufgabe[titel=Sport, erledigt=false]",
        "titel() liest das Feld; das automatische toString zeigt alle Felder mit Namen."),
    out("t28-3", "projects", 3, "Welche Aufgaben sind noch offen?",
        r"""
        record Aufgabe(String titel, boolean erledigt) {}

        List<Aufgabe> liste = new ArrayList<>();
        liste.add(new Aufgabe("Lesen", true));
        liste.add(new Aufgabe("Kochen", false));
        liste.add(new Aufgabe("Laufen", false));
        liste.stream()
                .filter(a -> !a.erledigt())
                .map(Aufgabe::titel)
                .forEach(System.out::println);
        """,
        "Kochen\nLaufen",
        "Der Filter lässt nur nicht erledigte Aufgaben durch, map holt die Titel, forEach gibt sie aus."),
    fill("t28-4", "projects", 4, "Ergänze: Aufgabe hinzufügen und dann abhaken (durch eine neue Version ersetzen).",
         r"""
         record Aufgabe(String titel, boolean erledigt) {}

         List<Aufgabe> liste = new ArrayList<>();
         liste.{{0}}(new Aufgabe("Putzen", false));
         Aufgabe alt = liste.get(0);
         liste.{{1}}(0, new Aufgabe(alt.titel(), {{2}}));
         System.out.println(liste.get(0).erledigt());
         """,
         [["add"], ["set"], ["true"]],
         "add hängt die Aufgabe an, set ersetzt sie an Position 0 durch eine abgehakte Version.",
         verify={"output": "true"}),
    code("t28-5", "projects", 5,
         "Gib die Liste nummeriert aus: „1. [ ] Einkaufen“ und „2. [x] Java lernen“ – [x] für erledigte Aufgaben.",
         r"""
         record Aufgabe(String titel, boolean erledigt) {}

         List<Aufgabe> liste = List.of(new Aufgabe("Einkaufen", false), new Aufgabe("Java lernen", true));
         // nummeriert ausgeben
         """,
         r"""
         record Aufgabe(String titel, boolean erledigt) {}

         List<Aufgabe> liste = List.of(new Aufgabe("Einkaufen", false), new Aufgabe("Java lernen", true));
         for (int i = 0; i < liste.size(); i++) {
             Aufgabe a = liste.get(i);
             String haken = a.erledigt() ? "[x]" : "[ ]";
             System.out.println((i + 1) + ". " + haken + " " + a.titel());
         }
         """,
         [req(r"\bfor\s*\(|\.forEach\s*\(|IntStream", "Gehe die Liste mit einer Schleife durch."),
          req(r"erledigt\s*\(\s*\)", "Frage mit erledigt() nach dem Häkchen."),
          req(r'"\[x\]"', "Zeige erledigte Aufgaben mit [x].", scope="raw"),
          req(r"titel\s*\(\s*\)", "Gib den Titel mit titel() aus."),
          forbid(r'"1\. \[ \] Einkaufen"', "Lass die Schleife die Zeilen bauen.", scope="raw")],
         "Die Nummer ist i + 1, das Häkchen kommt aus erledigt(), der Titel aus titel().",
         expected="1. [ ] Einkaufen\n2. [x] Java lernen",
         hint="String haken = a.erledigt() ? \"[x]\" : \"[ ]\";"),
])

l29 = lesson("l29-project-adventure", "Projekt: Textabenteuer", "Räume, Türen und eine Spielschleife.",
             ["projects"], 12, [
    card("Das Projekt",
         "Zum Abschluss ein kleines Textabenteuer: Du läufst durch ein Haus. Die Räume sind ein enum, ein Wörterbuch (Map) "
         "merkt sich, wohin jede Tür führt, und eine Schleife verarbeitet die Befehle. Das ist der Kern vieler Spiele.",
         code=r"""
         enum Raum { FLUR, KUECHE, GARTEN }

         Map<String, Raum> tuerenImFlur = Map.of("norden", Raum.KUECHE, "osten", Raum.GARTEN);
         Raum hier = Raum.FLUR;
         hier = tuerenImFlur.get("osten");
         System.out.println("Du stehst jetzt hier: " + hier);   // Du stehst jetzt hier: GARTEN
         """,
         verify={"output": "Du stehst jetzt hier: GARTEN"}),
    card("Die Spielschleife",
         "Die Schleife nimmt einen Befehl nach dem anderen, schaut im Wörterbuch nach, ob es dorthin einen Weg gibt, und "
         "bewegt die Spielfigur. getOrDefault liefert den alten Raum, wenn es in diese Richtung nicht weitergeht.",
         code=r"""
         enum Raum { FLUR, KUECHE, GARTEN }

         Map<Raum, Map<String, Raum>> wege = new HashMap<>();
         wege.put(Raum.FLUR, Map.of("norden", Raum.KUECHE));
         wege.put(Raum.KUECHE, Map.of("osten", Raum.GARTEN));
         wege.put(Raum.GARTEN, Map.of());

         Raum hier = Raum.FLUR;
         for (String befehl : List.of("norden", "westen", "osten")) {
             hier = wege.get(hier).getOrDefault(befehl, hier);
             System.out.println(befehl + " -> " + hier);
         }
         """,
         verify={"output": "norden -> KUECHE\nwesten -> KUECHE\nosten -> GARTEN"}),
], [
    mc("t29-1", "projects", 1, "Warum sind die Räume ein enum und kein String?",
       ["Es gibt nur eine feste Auswahl an Räumen – Tippfehler fallen sofort auf", "Strings können keine Räume speichern",
        "Ein enum ist ein Wörterbuch", "Damit das Spiel schneller lädt"],
       "Mit einem enum kann es keinen Raum „Kueche “ mit Leerzeichen geben – Java kennt nur die aufgezählten Räume."),
    out("t29-2", "projects", 2, "Was wird ausgegeben?",
        r"""
        enum Raum { FLUR, KUECHE, GARTEN }

        Map<String, Raum> tueren = Map.of("norden", Raum.KUECHE);
        System.out.println(tueren.get("norden"));
        System.out.println(tueren.getOrDefault("sueden", Raum.FLUR));
        """,
        "KUECHE\nFLUR",
        "Nach Norden gibt es eine Tür zur Küche. Nach Süden nicht – getOrDefault liefert den Ersatz FLUR."),
    out("t29-3", "projects", 3, "Was wird ausgegeben?",
        r"""
        enum Raum { FLUR, KUECHE, GARTEN }

        static String beschreibung(Raum r) {
            return switch (r) {
                case FLUR -> "Ein langer, dunkler Flur.";
                case KUECHE -> "Es riecht nach Kuchen.";
                case GARTEN -> "Die Sonne scheint.";
            };
        }

        public static void main(String[] args) {
            Raum hier = Raum.KUECHE;
            System.out.println(beschreibung(hier));
            hier = Raum.GARTEN;
            System.out.println(beschreibung(hier));
        }
        """,
        "Es riecht nach Kuchen.\nDie Sonne scheint.",
        "Der switch liefert zu jedem Raum seine Beschreibung – erst Küche, dann Garten.",
        ctx="members"),
    fill("t29-4", "projects", 4, "Ergänze die Spielschleife: jeden Befehl durchgehen und über die Karte laufen.",
         r"""
         enum Raum { FLUR, KUECHE, GARTEN }

         Map<Raum, Map<String, Raum>> wege = new HashMap<>();
         wege.put(Raum.FLUR, Map.of("norden", Raum.KUECHE));
         wege.put(Raum.KUECHE, Map.of("osten", Raum.GARTEN));
         Raum hier = Raum.FLUR;
         {{0}} (String befehl : List.of("norden", "osten")) {
             hier = wege.get(hier).{{1}}(befehl, hier);
         }
         System.out.println(hier);
         """,
         [["for"], ["getOrDefault"]],
         "Norden führt in die Küche, von dort Osten in den Garten.",
         verify={"output": "GARTEN"}),
    code("t29-5", "projects", 5,
         "Ergänze die Spielschleife: Geh alle Befehle durch, bewege dich über wege und gib am Ende den Raum aus. "
         "Unbekannte Richtungen lassen dich stehen bleiben.",
         r"""
         enum Raum { FLUR, KUECHE, GARTEN }

         Map<Raum, Map<String, Raum>> wege = new HashMap<>();
         wege.put(Raum.FLUR, Map.of("norden", Raum.KUECHE, "osten", Raum.GARTEN));
         wege.put(Raum.KUECHE, Map.of("sueden", Raum.FLUR));
         wege.put(Raum.GARTEN, Map.of("westen", Raum.FLUR));
         List<String> befehle = List.of("norden", "sueden", "springen", "osten");
         Raum hier = Raum.FLUR;
         // Spielschleife
         System.out.println(hier);
         """,
         r"""
         enum Raum { FLUR, KUECHE, GARTEN }

         Map<Raum, Map<String, Raum>> wege = new HashMap<>();
         wege.put(Raum.FLUR, Map.of("norden", Raum.KUECHE, "osten", Raum.GARTEN));
         wege.put(Raum.KUECHE, Map.of("sueden", Raum.FLUR));
         wege.put(Raum.GARTEN, Map.of("westen", Raum.FLUR));
         List<String> befehle = List.of("norden", "sueden", "springen", "osten");
         Raum hier = Raum.FLUR;
         for (String befehl : befehle) {
             hier = wege.get(hier).getOrDefault(befehl, hier);
         }
         System.out.println(hier);
         """,
         [req(r"\bfor\s*\(|\.forEach\s*\(|\bwhile\s*\(", "Geh die Befehle mit einer Schleife durch."),
          req(r"getOrDefault\s*\(|containsKey\s*\(", "Bleib bei unbekannten Richtungen stehen, z. B. mit getOrDefault."),
          req(r"wege\.get\s*\(\s*hier\s*\)", "Schau in der Karte beim aktuellen Raum nach: wege.get(hier)."),
          forbid(r"println\s*\(\s*Raum\.GARTEN", "Lass die Spielschleife laufen.")],
         "norden → Küche, sueden → Flur, springen → bleibt im Flur, osten → Garten.",
         expected="GARTEN",
         hint="for (String befehl : befehle) { hier = wege.get(hier).getOrDefault(befehl, hier); }"),
])

ADVANCED_MODULES = [
    {"id": "m6-objects-deep", "title": "Objekte vertieft", "subtitle": "Enums, static, equals & abstrakte Klassen",
     "tier": "intermediate", "symbol": "cube.transparent", "lessons": [l14, l15]},
    {"id": "m7-data-files", "title": "Daten & Dateien", "subtitle": "StringBuilder, Scanner, Dateien, Datum & Uhrzeit",
     "tier": "intermediate", "symbol": "doc.text", "lessons": [l16, l17]},
    {"id": "m8-algorithms", "title": "Algorithmen", "subtitle": "Rekursion, Suchen & Sortieren, Set, Stack & Queue",
     "tier": "advanced", "symbol": "arrow.up.arrow.down", "lessons": [l18, l19, l20]},
    {"id": "m9-tools", "title": "Profi-Werkzeuge", "subtitle": "Tests, Pakete, Build-Werkzeuge & Fehlersuche",
     "tier": "advanced", "symbol": "hammer.fill", "lessons": [l21, l22]},
    {"id": "m10-concurrency", "title": "Nebenläufigkeit", "subtitle": "Threads, Executor & virtuelle Threads",
     "tier": "advanced", "symbol": "cpu", "lessons": [l23, l24]},
    {"id": "m11-modern-deep", "title": "Modernes Java vertieft", "subtitle": "sealed, Pattern Matching & Streams für Profis",
     "tier": "advanced", "symbol": "wand.and.stars", "lessons": [l25, l26]},
    {"id": "m12-projects", "title": "Abschlussprojekte", "subtitle": "Notenrechner, Aufgabenliste & Textabenteuer",
     "tier": "advanced", "symbol": "flag.checkered", "lessons": [l27, l28, l29]},
]
