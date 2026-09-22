"""Übungspool, Teil 2: Grundlagen (Modul 1–5).

Jede Aufgabe mit `group=` ist eine weitere Variante eines Lernziels aus einer Lektion.
Unterschiedlich sind dabei bewusst nicht nur die Zahlen, sondern Code, Kontext,
Fragestellung und der Denkweg zur Lösung.
"""
from authoring import code, fill, forbid, mc, out, req

# ---------------------------------------------------------------- Programmaufbau
SYNTAX = [
    mc("q-syn-1a", "syntax", 1, "Welche Methode sucht Java, um ein Programm zu starten?",
       ["public static void main(String[] args)", "public void start()", "static void run()", "public static begin()"],
       "Die JVM sucht genau diese eine Startseite: main mit String[] args. Fehlt sie, startet nichts.",
       group="t01-1"),
    mc("q-syn-1b", "syntax", 1, "Was macht System.out.print im Unterschied zu System.out.println?",
       ["print bleibt in der Zeile, println springt danach in eine neue",
        "print schreibt nur Zahlen, println nur Text",
        "print ist schneller, sonst gleich",
        "print schreibt in eine Datei, println auf den Bildschirm"],
       "Das ln in println steht für „line“: Es beendet die Zeile, wie ein Druck auf Enter.",
       group="t01-2"),
    out("q-syn-2a", "syntax", 2, "Was gibt dieses Programm aus?",
        """
        System.out.print("Java");
        System.out.print("Quest");
        System.out.println("!");
        """,
        "JavaQuest!",
        "print bleibt jeweils in derselben Zeile – alles landet hintereinander. Erst println beendet sie.",
        group="t01-4"),
    out("q-syn-2b", "syntax", 2, "Was gibt dieses Programm aus? Achte auf den Kommentar.",
        """
        System.out.println("oben");
        // System.out.println("mitte");
        System.out.println("unten");
        """,
        """
        oben
        unten
        """,
        "Alles hinter // ist ein Notizzettel für Menschen. Java überliest die Zeile komplett.",
        group="t01-4"),
    fill("q-syn-3a", "syntax", 2, "Ergänze die Zeile, damit „Guten Morgen“ ohne Zeilenumbruch danach ausgegeben wird.",
         """
         System.out.{{0}}("Guten Morgen");
         """,
         [["print"]],
         "print schreibt den Text und bleibt in der Zeile – println würde danach umbrechen.",
         verify={"output": "Guten Morgen"},
         group="t01-3"),
    code("q-syn-3b", "syntax", 3, "Gib zwei Zeilen aus: zuerst „Zeile 1“, dann „Zeile 2“.",
         "// Deine Anweisungen hier",
         """
         System.out.println("Zeile 1");
         System.out.println("Zeile 2");
         """,
         [req(r"System\.out\.println", "Nutze System.out.println(…)."),
          req(r'"Zeile 1"', "Gib „Zeile 1“ aus.", scope="raw"),
          req(r'"Zeile 2"', "Gib „Zeile 2“ aus.", scope="raw")],
         "Zwei println-Anweisungen, jede beendet ihre Zeile – deshalb steht der zweite Text darunter.",
         expected="Zeile 1\nZeile 2",
         group="t01-5"),
]

# ---------------------------------------------------------------- Variablen
VARIABLES = [
    out("q-var-1a", "variables", 1, "Was wird ausgegeben?",
        """
        String name = "Ada";
        System.out.println("Hallo, " + name + "!");
        """,
        "Hallo, Ada!",
        "Mit + werden Textstücke aneinandergeklebt: „Hallo, “ + Inhalt der Box + „!“.",
        group="t02-3"),
    out("q-var-1b", "variables", 2, "Was wird ausgegeben?",
        """
        int a = 5;
        int b = a;
        a = 9;
        System.out.println(b);
        """,
        "5",
        "b bekam eine Kopie des Werts, keine Verbindung zur Box a. Spätere Änderungen an a lassen b unberührt.",
        group="t02-5"),
    mc("q-var-2a", "variables", 2, "Was bedeutet var zahl = 42;?",
       ["Java erkennt den Typ selbst – hier int",
        "Die Variable kann jeden Typ annehmen",
        "Die Variable ist eine Konstante",
        "Die Variable hat noch keinen Typ"],
       "var ist kein eigener Typ: Java klebt das passende Etikett selbst drauf. Danach steht der Typ fest.",
       group="t02-1"),
    out("q-var-2b", "variables", 3, "Was wird ausgegeben?",
        """
        char zeichen = 'J';
        boolean lernt = true;
        System.out.println(zeichen + " " + lernt);
        """,
        "J true",
        "char hält genau ein Zeichen in einfachen Anführungszeichen, boolean nur true oder false.",
        group="t02-1"),
]

# ---------------------------------------------------------------- Operatoren
OPERATORS = [
    out("q-op-1a", "operators", 2, "Was wird ausgegeben?",
        """
        int punkte = 20;
        punkte -= 5;
        punkte *= 2;
        System.out.println(punkte);
        """,
        "30",
        "-= 5 macht 15 daraus, *= 2 verdoppelt: 30. Die Kurzformen ändern den Inhalt der Box direkt.",
        group="t03-3"),
    mc("q-op-2a", "operators", 3, "Wann ist (alter >= 18 && hatAusweis) wahr?",
       ["Nur wenn beide Bedingungen wahr sind",
        "Wenn mindestens eine Bedingung wahr ist",
        "Wenn beide Bedingungen falsch sind",
        "Immer, wenn alter mindestens 18 ist"],
       "&& heißt „und“: Beide Seiten müssen ja sein. || wäre „oder“ – da reicht eine Seite.",
       group="t03-4"),
    out("q-op-2b", "operators", 3, "Was wird ausgegeben?",
        """
        int x = 7;
        boolean gross = x > 5;
        boolean gerade = x % 2 == 0;
        System.out.println(gross + " " + gerade);
        """,
        "true false",
        "7 > 5 ist wahr. 7 % 2 ergibt 1, also ist der Vergleich mit 0 falsch – 7 ist ungerade.",
        group="t03-4"),
    code("q-op-3a", "operators", 4, "Berechne aus 17 Minuten die vollen Stunden und die restlichen Minuten und gib beides aus – erst die Stunden, dann die Minuten.",
         """
         int minutenGesamt = 137;
         // Stunden und Rest berechnen und ausgeben
         """,
         """
         int minutenGesamt = 137;
         int stunden = minutenGesamt / 60;
         int rest = minutenGesamt % 60;
         System.out.println(stunden);
         System.out.println(rest);
         """,
         [req(r"/\s*60", "Teile durch 60 für die vollen Stunden."),
          req(r"%\s*60", "Nutze % 60 für die restlichen Minuten."),
          req(r"System\.out\.println", "Gib beide Werte aus.")],
         "Die Ganzzahldivision liefert die vollen Stunden (137 / 60 = 2), der Rest die Minuten (137 % 60 = 17).",
         expected="2\n17",
         group="t03-1"),
]

# ---------------------------------------------------------------- Bedingungen
CONDITIONALS = [
    out("q-if-1a", "conditionals", 2, "Was wird ausgegeben?",
        """
        String tier = "Katze";
        switch (tier) {
            case "Hund" -> System.out.println("Wau");
            case "Katze" -> System.out.println("Miau");
            default -> System.out.println("unbekannt");
        }
        """,
        "Miau",
        "Der Weichensteller switch vergleicht den Wert mit jedem case und nimmt den passenden Weg.",
        group="t04-5"),
    out("q-if-1b", "conditionals", 3, "Was wird ausgegeben?",
        """
        int monat = 7;
        switch (monat) {
            case 12, 1, 2 -> System.out.println("Winter");
            case 6, 7, 8 -> System.out.println("Sommer");
            default -> System.out.println("andere Jahreszeit");
        }
        """,
        "Sommer",
        "Ein case darf mehrere Werte zusammenfassen: 6, 7 und 8 führen alle zum selben Weg.",
        group="t04-5"),
    code("q-if-2a", "conditionals", 4, "Gib „positiv“, „negativ“ oder „null“ aus – passend zum Wert von zahl.",
         """
         int zahl = -4;
         // Deine Entscheidung hier
         """,
         """
         int zahl = -4;
         if (zahl > 0) {
             System.out.println("positiv");
         } else if (zahl < 0) {
             System.out.println("negativ");
         } else {
             System.out.println("null");
         }
         """,
         [req(r"\bif\b", "Stelle die erste Frage mit if."),
          req(r"else\s+if", "Die zweite Frage kommt mit else if."),
          req(r"\belse\b\s*\{", "Der Rest gehört in den else-Block.")],
         "Java prüft von oben nach unten und nimmt den ersten Weg, dessen Frage mit ja beantwortet wird.",
         expected="negativ",
         group="t04-4"),
]

# ---------------------------------------------------------------- Schleifen
LOOPS = [
    out("q-loop-1a", "loops", 2, "Was gibt die Schleife aus?",
        """
        for (int i = 2; i <= 10; i += 2) {
            System.out.print(i + " ");
        }
        """,
        "2 4 6 8 10 ",
        "Der Zähler springt in Zweierschritten: i += 2 statt i++.",
        group="t05-1"),
    out("q-loop-1b", "loops", 3, "Was wird ausgegeben?",
        """
        int zahl = 1;
        do {
            System.out.print(zahl + " ");
            zahl = zahl * 2;
        } while (zahl < 20);
        """,
        "1 2 4 8 16 ",
        "Die do-while-Schleife läuft mindestens einmal und prüft erst am Ende. Bei 32 ist Schluss.",
        group="t05-3"),
    out("q-loop-2a", "loops", 4, "Was wird ausgegeben?",
        """
        for (int i = 1; i <= 10; i++) {
            if (i == 4) {
                break;
            }
            System.out.print(i + " ");
        }
        """,
        "1 2 3 ",
        "break verlässt die Schleife sofort – ab der 4 läuft keine Runde mehr.",
        group="t05-4"),
    out("q-loop-2b", "loops", 4, "Zwei Schleifen ineinander. Was wird ausgegeben?",
        """
        for (int zeile = 1; zeile <= 2; zeile++) {
            for (int spalte = 1; spalte <= 3; spalte++) {
                System.out.print(zeile * spalte + " ");
            }
            System.out.println();
        }
        """,
        """
        1 2 3
        2 4 6
        """,
        "Die innere Schleife läuft für jede Runde der äußeren komplett durch – wie eine kleine Einmaleins-Tabelle.",
        group="t05-5"),
]

# ---------------------------------------------------------------- Methoden
METHODS = [
    out("q-meth-1a", "methods", 3, "Was wird ausgegeben?",
        """
        static int groesser(int a, int b) {
            if (a > b) {
                return a;
            }
            return b;
        }

        public static void main(String[] args) {
            System.out.println(groesser(3, 8));
        }
        """,
        "8",
        "Nach dem ersten return ist das Rezept fertig. Da 3 > 8 falsch ist, wird die Zeile darunter erreicht.",
        ctx="members",
        group="t06-3"),
    out("q-meth-1b", "methods", 3, "Zwei Methoden heißen gleich. Was wird ausgegeben?",
        """
        static int flaeche(int seite) {
            return seite * seite;
        }

        static int flaeche(int breite, int hoehe) {
            return breite * hoehe;
        }

        public static void main(String[] args) {
            System.out.println(flaeche(4));
            System.out.println(flaeche(2, 5));
        }
        """,
        """
        16
        10
        """,
        "Java wählt die Variante, deren Zutatenliste passt: eine Zahl → Quadrat, zwei Zahlen → Rechteck.",
        ctx="members",
        group="t06-4"),
    code("q-meth-2a", "methods", 4, "Schreibe die Methode begruesse(String name), die „Hallo, <name>!“ ausgibt und nichts zurückgibt.",
         "// Deine Methode hier",
         """
         static void begruesse(String name) {
             System.out.println("Hallo, " + name + "!");
         }
         """,
         [req(r"void\s+begruesse\s*\(\s*String\s+\w+\s*\)", "Die Methode heißt begruesse und liefert nichts (void)."),
          req(r"System\.out\.println", "Gib den Gruß mit println aus.")],
         "void heißt: Das Rezept erledigt etwas, gibt aber nichts zurück. Deshalb steht dort kein return mit Wert.",
         ctx="members",
         verify={"context": "members", "main": 'begruesse("Ada");', "output": "Hallo, Ada!"},
         group="t06-1"),
]

# ---------------------------------------------------------------- Arrays & Strings
ARRAYS = [
    out("q-arr-1a", "arrays", 2, "Was wird ausgegeben?",
        """
        int[] zahlen = new int[3];
        zahlen[1] = 7;
        System.out.println(zahlen[0] + " " + zahlen[1]);
        """,
        "0 7",
        "Ein neuer int-Eierkarton startet überall mit 0. Nur Fach 1 wurde gefüllt.",
        group="t07-1"),
    out("q-arr-1b", "arrays", 3, "Was wird ausgegeben?",
        """
        int[] werte = {3, 8, 1};
        int summe = 0;
        for (int w : werte) {
            summe += w;
        }
        System.out.println(summe);
        """,
        "12",
        "Die for-each-Schleife holt jedes Fach einmal ab: 3 + 8 + 1 = 12.",
        group="t07-3"),
    code("q-arr-2a", "arrays", 4, "Finde den kleinsten Wert im Eierkarton und gib ihn aus.",
         """
         int[] zahlen = {12, 4, 9, 7};
         // Kleinsten Wert finden und ausgeben
         """,
         """
         int[] zahlen = {12, 4, 9, 7};
         int kleinster = zahlen[0];
         for (int z : zahlen) {
             if (z < kleinster) {
                 kleinster = z;
             }
         }
         System.out.println(kleinster);
         """,
         [req(r"\bfor\b", "Geh mit einer Schleife durch alle Fächer."),
          req(r"<", "Vergleiche, ob ein Wert kleiner ist."),
          forbid(r"println\(4\)", "Nicht die Antwort hinschreiben – lass Java suchen.")],
         "Man merkt sich den bisher kleinsten Wert und ersetzt ihn, sobald ein kleinerer auftaucht.",
         expected="4",
         group="t07-5"),
]

STRINGS = [
    out("q-str-1a", "strings", 2, "Was wird ausgegeben?",
        """
        String wort = "Java";
        System.out.println(wort.toUpperCase());
        """,
        "JAVA",
        "toUpperCase liefert einen neuen Text in Großbuchstaben – der ursprüngliche Text bleibt unverändert.",
        group="t07-2"),
    out("q-str-1b", "strings", 3, "Was wird ausgegeben?",
        """
        String a = "Hallo";
        String b = "Hallo";
        System.out.println(a.equals(b));
        System.out.println(a.length());
        """,
        """
        true
        5
        """,
        "equals vergleicht den Inhalt – der ist gleich. length() zählt die Zeichen: H-a-l-l-o.",
        group="t07-4"),
    fill("q-str-2a", "strings", 3, "Ergänze: Der Text soll auf sein erstes Zeichen geprüft werden.",
         """
         String wort = "Banane";
         System.out.println(wort.{{0}}(0));
         """,
         [["charAt"]],
         "charAt(0) holt das Zeichen aus Fach 0 – Java zählt auch bei Text ab 0.",
         verify={"output": "B"},
         group="t07-2"),
]

# ---------------------------------------------------------------- Klassen & Objekte
OOP = [
    out("q-oop-1a", "oop", 3, "Was wird ausgegeben?",
        """
        class Auto {
            String marke;

            Auto(String marke) {
                this.marke = marke;
            }
        }

        public class Main {
            public static void main(String[] args) {
                Auto a = new Auto("VW");
                System.out.println(a.marke);
            }
        }
        """,
        "VW",
        "Der Konstruktor legt den Startwert ins Fach. this.marke ist das Fach des Objekts, marke die mitgegebene Zutat.",
        ctx="file",
        group="t08-2"),
    mc("q-oop-1b", "oop", 2, "Wofür steht das Schlüsselwort this in einem Konstruktor?",
       ["Für das Objekt, das gerade gebaut wird",
        "Für die Klasse selbst",
        "Für den zuletzt gespeicherten Wert",
        "Für das Elternobjekt"],
       "this heißt „dieser Kuchen hier“ – damit unterscheidet man das Fach des Objekts von der gleichnamigen Zutat.",
       group="t08-2"),
    code("q-oop-2a", "oop", 4, "Schreibe die Klasse Punkt mit privaten Feldern x und y (int), einem Konstruktor und der Methode getX().",
         "// Deine Klasse hier",
         """
         class Punkt {
             private int x;
             private int y;

             Punkt(int x, int y) {
                 this.x = x;
                 this.y = y;
             }

             int getX() {
                 return x;
             }
         }
         """,
         [req(r"class\s+Punkt", "Schreibe die Klasse Punkt."),
          req(r"private\s+int\s+x", "Das Feld x soll privat sein."),
          req(r"Punkt\s*\(\s*int\s+\w+\s*,\s*int\s+\w+\s*\)", "Der Konstruktor bekommt zwei Zahlen."),
          req(r"int\s+getX\s*\(\s*\)", "Ergänze die Methode getX().")],
         "Felder privat, der Konstruktor füllt sie mit this, und ein Getter gibt den Wert nach außen.",
         ctx="file",
         verify={"context": "file", "main": "System.out.println(new Punkt(3, 4).getX());", "output": "3"},
         group="t08-4"),
]

INHERITANCE = [
    out("q-inh-1a", "inheritance", 3, "Was wird ausgegeben?",
        """
        class Fahrzeug {
            String beschreibung() {
                return "Fahrzeug";
            }
        }

        class Fahrrad extends Fahrzeug {
            @Override
            String beschreibung() {
                return "Fahrrad mit " + super.beschreibung();
            }
        }

        public class Main {
            public static void main(String[] args) {
                System.out.println(new Fahrrad().beschreibung());
            }
        }
        """,
        "Fahrrad mit Fahrzeug",
        "super.beschreibung() ruft die Methode der Eltern-Klasse auf – so baut die Kind-Klasse darauf auf.",
        ctx="file",
        group="t09-5"),
    mc("q-inh-1b", "inheritance", 2, "Wie viele Interfaces darf eine Java-Klasse umsetzen?",
       ["Beliebig viele", "Genau eines", "Höchstens zwei", "Keines, wenn sie schon erbt"],
       "Verträge darf eine Klasse viele unterschreiben – aber nur eine Eltern-Klasse haben.",
       group="t09-2"),
]

EXCEPTIONS = [
    out("q-exc-1a", "exceptions", 3, "Was wird ausgegeben?",
        """
        int[] zahlen = {1, 2};
        try {
            System.out.println(zahlen[5]);
        } catch (ArrayIndexOutOfBoundsException e) {
            System.out.println("Fach gibt es nicht");
        } finally {
            System.out.println("fertig");
        }
        """,
        """
        Fach gibt es nicht
        fertig
        """,
        "Fach 5 gibt es im Eierkarton nicht – der Alarm landet im passenden catch. finally läuft immer zum Schluss.",
        group="t10-2"),
    mc("q-exc-1b", "exceptions", 3, "Was ist der Unterschied zwischen throw und throws?",
       ["throw löst einen Alarm aus, throws kündigt ihn in der Methode an",
        "throw kündigt an, throws löst aus",
        "Beide bedeuten dasselbe",
        "throws fängt den Alarm ab"],
       "throw new … wirft jetzt. throws steht im Kopf der Methode und warnt: Hier kann so ein Alarm herauskommen.",
       group="t10-4"),
    code("q-exc-2a", "exceptions", 4, "Wandle den Text in eine Zahl um und gib sie aus. Fange eine NumberFormatException ab und gib dann „keine Zahl“ aus.",
         """
         String eingabe = "abc";
         // try/catch hier
         """,
         """
         String eingabe = "abc";
         try {
             int zahl = Integer.parseInt(eingabe);
             System.out.println(zahl);
         } catch (NumberFormatException e) {
             System.out.println("keine Zahl");
         }
         """,
         [req(r"\btry\b", "Der riskante Code gehört in einen try-Block."),
          req(r"catch\s*\(\s*NumberFormatException", "Fange gezielt die NumberFormatException."),
          req(r"Integer\.parseInt", "Nutze Integer.parseInt.")],
         "„abc“ lässt sich nicht in eine Zahl verwandeln – das Sicherheitsnetz fängt den Alarm auf, statt abzustürzen.",
         expected="keine Zahl",
         group="t10-5"),
]

# ---------------------------------------------------------------- Collections & Generics
COLLECTIONS = [
    out("q-col-1a", "collections", 3, "Was wird ausgegeben?",
        """
        List<String> liste = new ArrayList<>(List.of("a", "b", "c"));
        System.out.println(liste.get(1));
        System.out.println(liste.contains("z"));
        """,
        """
        b
        false
        """,
        "get(1) holt den zweiten Eintrag – gezählt ab 0. contains fragt nur nach, ob etwas enthalten ist.",
        group="t11-3"),
    out("q-col-1b", "collections", 4, "Was wird ausgegeben?",
        """
        Map<String, Integer> lager = new HashMap<>();
        lager.put("Apfel", 3);
        lager.put("Birne", 5);
        lager.put("Apfel", lager.get("Apfel") + 2);
        System.out.println(lager.get("Apfel") + " " + lager.size());
        """,
        "5 2",
        "Der alte Wert wird gelesen, erhöht und wieder eingetragen. Ein Schlüssel kommt im Wörterbuch nur einmal vor.",
        group="t11-4"),
    mc("q-gen-1a", "generics", 3, "Was bringt <T> bei einer Methode?",
       ["Die Methode funktioniert mit jeder Sorte von Inhalt",
        "Die Methode wird schneller",
        "Die Methode darf nur Text verarbeiten",
        "Die Methode kann keine Zahlen verarbeiten"],
       "<T> ist ein Platzhalter-Etikett: Beim Aufruf setzt Java die echte Sorte ein – einmal schreiben, überall nutzen.",
       group="t11-5"),
    out("q-gen-1b", "generics", 3, "Was wird ausgegeben?",
        """
        List<Integer> zahlen = new ArrayList<>();
        zahlen.add(4);
        zahlen.add(9);
        int summe = zahlen.get(0) + zahlen.get(1);
        System.out.println(summe);
        """,
        "13",
        "In spitzen Klammern stehen Klassen, deshalb Integer statt int. Java rechnet damit wie mit ganzen Zahlen.",
        group="t11-2"),
]

# ---------------------------------------------------------------- Lambdas, Streams, modernes Java
LAMBDAS = [
    out("q-lam-1a", "lambdas", 3, "Was wird ausgegeben?",
        """
        List<String> namen = List.of("Ada", "Linus", "Grace");
        long lange = namen.stream()
                .filter(n -> n.length() > 3)
                .count();
        System.out.println(lange);
        """,
        "2",
        "Nur „Linus“ und „Grace“ haben mehr als drei Zeichen – count zählt, was am Ende des Bandes übrig bleibt.",
        group="t12-3"),
    out("q-lam-1b", "lambdas", 4, "Was wird ausgegeben?",
        """
        List<Integer> zahlen = List.of(5, 2, 8);
        List<Integer> verdoppelt = zahlen.stream()
                .map(z -> z * 2)
                .sorted()
                .toList();
        System.out.println(verdoppelt);
        """,
        "[4, 10, 16]",
        "map verdoppelt jede Zahl, sorted ordnet sie aufsteigend – erst danach entsteht die neue Liste.",
        group="t12-4"),
    mc("q-lam-2a", "lambdas", 3, "Was macht ein Lambda wie z -> z * 2?",
       ["Es beschreibt eine kleine Rechnung, die später ausgeführt wird",
        "Es rechnet sofort z mal 2",
        "Es legt eine neue Variable z an",
        "Es sortiert die Liste"],
       "Ein Lambda ist eine Mini-Anweisung ohne Namen. Sie läuft erst, wenn jemand sie aufruft – etwa eine Station im Fließband.",
       group="t12-1"),
]

MODERN = [
    out("q-mod-1a", "modern", 3, "Was wird ausgegeben?",
        """
        Optional<String> name = Optional.of("Ada");
        System.out.println(name.orElse("unbekannt"));
        """,
        "Ada",
        "Die Schachtel ist gefüllt, deshalb kommt ihr Inhalt heraus. Der Ersatzwert greift nur bei einer leeren Schachtel.",
        group="t13-3"),
    out("q-mod-1b", "modern", 4, "Was wird ausgegeben?",
        """
        Object wert = 42;
        String text = switch (wert) {
            case Integer i -> "Zahl " + i;
            case String s -> "Text " + s;
            default -> "unbekannt";
        };
        System.out.println(text);
        """,
        "Zahl 42",
        "Der switch prüft die Sorte und gibt dem Wert gleich ein Namensschild: i steht für die erkannte Zahl.",
        group="t13-5"),
    mc("q-mod-2a", "modern", 3, "Was liefert ein switch-Ausdruck mit Pfeil (->)?",
       ["Einen Wert, den man in eine Box legen kann",
        "Immer nur eine Ausgabe auf dem Bildschirm",
        "Eine Liste aller Fälle",
        "Nichts – er ist nur eine Abkürzung"],
       "Im Unterschied zur alten Form liefert der switch-Ausdruck ein Ergebnis zurück, das man direkt zuweisen kann.",
       group="t13-4"),
]

POOL_BASICS = (
    SYNTAX + VARIABLES + OPERATORS + CONDITIONALS + LOOPS + METHODS
    + ARRAYS + STRINGS + OOP + INHERITANCE + EXCEPTIONS + COLLECTIONS + LAMBDAS + MODERN
)
