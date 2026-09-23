"""Übungspool, Teil 4: Tiefe für die dünnen Themen.

Ziel ist Abwechslung im Denkweg, nicht nur andere Zahlen: Ausgabe vorhersagen,
Fehler finden, Begriff erklären, Code ergänzen, Java ↔ UML übersetzen.
"""
from authoring import any_of, code, fill, forbid, mc, out, req
from uml_content import BESTELLUNG, FORM_HIERARCHIE, HAUS, INTERFACE_DIAGRAM, KONTO, PERSON, SCHULE, TIER_HUND, box, diagram, m, rel

# ---------------------------------------------------------------- Generics
GENERICS = [
    out("r-gen-1a", "generics", 3, "Was wird ausgegeben?",
        """
        List<String> texte = new ArrayList<>();
        texte.add("eins");
        String erster = texte.get(0);
        System.out.println(erster.toUpperCase());
        """,
        "EINS",
        "Weil auf dem Etikett List<String> steht, weiß Java: Hier kommt ein Text heraus – toUpperCase ist erlaubt, ohne Umwandeln.",
        group="t11-2"),
    mc("r-gen-1b", "generics", 3, "Warum meldet der Compiler bei List<String> liste = …; liste.add(42); einen Fehler?",
       ["Das Etikett erlaubt nur Texte in der Liste",
        "Die Liste ist voll",
        "42 ist zu groß für eine Liste",
        "add funktioniert nur mit Objekten der Klasse Object"],
       "Die spitzen Klammern sind eine Zusage: Nur Texte. Java prüft das schon beim Übersetzen, nicht erst beim Ausführen.",
       group="t11-2"),
    code("r-gen-2a", "generics", 4, "Schreibe die generische Methode erstes, die das erste Element einer Liste zurückgibt.",
         "// Deine generische Methode hier",
         """
         static <T> T erstes(List<T> liste) {
             return liste.get(0);
         }
         """,
         [req(r"<T>", "Nutze den Platzhalter <T>."),
          req(r"erstes\s*\(\s*List<T>\s+\w+\s*\)", "Die Methode nimmt eine List<T> entgegen."),
          any_of([r"return\s+\w+\.get\s*\(\s*0\s*\)", r"\.get\s*\(\s*0\s*\)", r"\.getFirst\s*\(\s*\)"],
                 "Gib das Element aus Fach 0 zurück.")],
         "<T> ist ein Platzhalter-Etikett: Beim Aufruf setzt Java die echte Sorte ein – dieselbe Methode dient für jede Liste.",
         ctx="members",
         verify={"context": "members", "main": 'System.out.println(erstes(List.of("a", "b")));', "output": "a"},
         group="t11-5"),
]

# ---------------------------------------------------------------- Datum & Uhrzeit
DATETIME = [
    out("r-dat-1a", "datetime", 2, "Was wird ausgegeben?",
        """
        LocalDate tag = LocalDate.of(2026, 12, 31);
        System.out.println(tag.plusDays(1));
        """,
        "2027-01-01",
        "LocalDate rechnet über Monats- und Jahresgrenzen hinweg – aus Silvester wird Neujahr.",
        group="t17-2"),
    out("r-dat-1b", "datetime", 3, "Was wird ausgegeben?",
        """
        LocalDate tag = LocalDate.of(2026, 5, 9);
        System.out.println(tag.getDayOfMonth() + "." + tag.getMonthValue());
        """,
        "9.5",
        "getDayOfMonth() ist der Tag im Monat, getMonthValue() die Monatszahl – beide ohne führende Null.",
        group="t17-3"),
    code("r-dat-2a", "datetime", 4, "Gib aus, wie viele Jahre zwischen dem 1.1.2000 und dem 1.1.2026 liegen.",
         """
         LocalDate start = LocalDate.of(2000, 1, 1);
         LocalDate ende = LocalDate.of(2026, 1, 1);
         // Abstand in Jahren ausgeben
         """,
         """
         LocalDate start = LocalDate.of(2000, 1, 1);
         LocalDate ende = LocalDate.of(2026, 1, 1);
         System.out.println(Period.between(start, ende).getYears());
         """,
         [req(r"Period\.between", "Nutze Period.between."),
          req(r"getYears\(\)", "Hol dir die vollen Jahre mit getYears()."),
          forbid(r"println\(26\)", "Nicht die Antwort hinschreiben – lass Java rechnen.")],
         "Period.between misst den Abstand in Jahren, Monaten und Tagen; getYears() liefert davon die vollen Jahre.",
         expected="26",
         group="t17-3"),
]

# ---------------------------------------------------------------- Strings
STRINGS = [
    out("r-str-1a", "strings", 2, "Was wird ausgegeben?",
        """
        String satz = "Java macht Spass";
        System.out.println(satz.contains("macht"));
        """,
        "true",
        "contains fragt, ob der Teiltext irgendwo vorkommt – Groß- und Kleinschreibung zählen dabei mit.",
        group="t07-4"),
    out("r-str-1b", "strings", 3, "Was wird ausgegeben?",
        """
        String wort = "  Java  ";
        System.out.println("[" + wort.trim() + "]");
        """,
        "[Java]",
        "trim() schneidet Leerzeichen am Anfang und Ende weg. Die eckigen Klammern machen das sichtbar.",
        group="t07-2"),
    out("r-str-2a", "strings", 4, "Was wird ausgegeben?",
        """
        String satz = "rot,gelb,blau";
        String[] teile = satz.split(",");
        System.out.println(teile.length + " " + teile[2]);
        """,
        "3 blau",
        "split zerlegt den Text an jedem Komma in einen Eierkarton – Fach 2 ist der dritte Teil.",
        group="t07-2"),
    code("r-str-3a", "strings", 4, "Prüfe, ob das Wort mit „Ja“ beginnt, und gib true oder false aus.",
         """
         String wort = "JavaQuest";
         // Prüfen und ausgeben
         """,
         """
         String wort = "JavaQuest";
         System.out.println(wort.startsWith("Ja"));
         """,
         [req(r"startsWith", "Nutze startsWith."),
          forbid(r"println\(true\)", "Nicht die Antwort hinschreiben – lass Java prüfen.")],
         "startsWith liefert direkt true oder false – der Vergleich muss nicht selbst gebaut werden.",
         expected="true",
         group="t07-4"),
]

# ---------------------------------------------------------------- sealed & Pattern Matching
PATTERNS = [
    out("r-pat-1a", "patterns", 3, "Was wird ausgegeben?",
        """
        sealed interface Form permits Kreis, Quadrat {}
        record Kreis(double radius) implements Form {}
        record Quadrat(double seite) implements Form {}

        public class Main {
            static String beschreibe(Form f) {
                return switch (f) {
                    case Kreis k -> "Kreis mit Radius " + k.radius();
                    case Quadrat q -> "Quadrat mit Seite " + q.seite();
                };
            }

            public static void main(String[] args) {
                System.out.println(beschreibe(new Quadrat(3.0)));
            }
        }
        """,
        "Quadrat mit Seite 3.0",
        "Weil die Familie geschlossen ist, kennt Java alle Fälle – ein default-Zweig ist nicht nötig.",
        ctx="file",
        group="t25-4"),
    mc("r-pat-1b", "patterns", 3, "Was macht das Wort when in einem case?",
       ["Es fügt dem Fall eine zusätzliche Bedingung hinzu",
        "Es legt die Reihenfolge der Fälle fest",
        "Es wiederholt den Fall",
        "Es beendet den switch"],
       "case Auto a when a.ps() > 200 passt nur, wenn die Sorte stimmt UND die Bedingung wahr ist.",
       group="t25-3"),
    out("r-pat-2a", "patterns", 4, "Was wird ausgegeben?",
        """
        record Punkt(int x, int y) {}

        public class Main {
            public static void main(String[] args) {
                Object o = new Punkt(0, 7);
                String text = switch (o) {
                    case Punkt(int x, int y) when x == 0 -> "auf der Achse bei " + y;
                    case Punkt p -> "irgendwo";
                    default -> "kein Punkt";
                };
                System.out.println(text);
            }
        }
        """,
        "auf der Achse bei 7",
        "Das Record-Muster packt x und y aus, die when-Bedingung prüft x == 0 – beides trifft zu.",
        ctx="file",
        group="t25-2"),
]

# ---------------------------------------------------------------- UML
UML_EXTRA_DIAGRAM = diagram(
    [
        box("Bibliothek", fields=[m("-", "name", "String")], methods=[m("+", "anzahl()", "int")]),
        box("Buch", fields=[m("-", "titel", "String"), m("-", "jahr", "int")], methods=[m("+", "getTitel()", "String")]),
    ],
    [rel("Bibliothek", "Buch", "aggregation", mult="*")],
)

UML_SPIELER = diagram([
    box("Spieler",
        fields=[m("-", "name", "String"), m("#", "punkte", "int")],
        methods=[m("+", "getName()", "String"), m("+", "addiere()"), m("-", "pruefe()", "boolean")]),
])

UML = [
    mc("r-uml-1a", "umlbasics", 2, "Welche Methode im Kasten ist nur innerhalb der Klasse nutzbar?",
       ["pruefe()", "getName()", "addiere()", "keine davon"],
       "Das Minus vor pruefe() heißt privat. getName() und addiere() sind mit + öffentlich.",
       diagram=UML_SPIELER, group="t30-2"),
    mc("r-uml-1b", "umlbasics", 2, "Wie viele Attribute hat die Klasse Spieler laut Diagramm?",
       ["2", "3", "5", "1"],
       "Im mittleren Fach stehen die Attribute: name und punkte. Die drei Einträge darunter sind Methoden.",
       diagram=UML_SPIELER, group="t30-3"),
    mc("r-uml-2a", "umlbasics", 3, "Welche UML-Zeile passt zu „protected int punkte;“?",
       ["# punkte: int", "- punkte: int", "+ punkte: int", "punkte: protected int"],
       "protected wird in UML zum Doppelkreuz #. Der Typ steht hinter dem Doppelpunkt.",
       diagram=UML_SPIELER, group="t30-4"),
    mc("r-uml-2b", "umlrelations", 3, "Was bedeutet die Vielfachheit * an der Linie zur Klasse Buch?",
       ["Eine Bibliothek kann beliebig viele Bücher haben",
        "Eine Bibliothek hat genau ein Buch",
        "Jedes Buch gehört zu beliebig vielen Bibliotheken",
        "Es gibt keine Bücher"],
       "Der Stern steht für „beliebig viele“ – auch keines. Wollte man mindestens eines, stünde dort 1..*.",
       diagram=UML_EXTRA_DIAGRAM, group="t31-4"),
    mc("r-uml-3a", "umlrelations", 4, "Die Bücher bleiben erhalten, wenn die Bibliothek schließt. Welche Linie ist richtig?",
       ["Aggregation – leere Raute an der Bibliothek",
        "Komposition – gefüllte Raute an der Bibliothek",
        "Vererbung – Dreiecksspitze zur Bibliothek",
        "Abhängigkeit – gestrichelter Pfeil"],
       "Leben die Teile ohne das Ganze weiter, ist es eine Aggregation (leere Raute). Bei Komposition wären sie mit weg.",
       diagram=UML_EXTRA_DIAGRAM, group="t31-3"),
    out("r-uml-3b", "umlrelations", 4, "Das Diagramm zeigt Form mit Kreis und Quadrat. Was gibt dieser Code aus?",
        """
        abstract class Form {
            abstract double flaeche();
        }

        class Kreis extends Form {
            private double radius;

            Kreis(double radius) {
                this.radius = radius;
            }

            @Override
            double flaeche() {
                return 3.0 * radius * radius;
            }
        }

        public class Main {
            public static void main(String[] args) {
                Form f = new Kreis(2);
                System.out.println(f.flaeche());
            }
        }
        """,
        "12.0",
        "Die Dreiecksspitze im Diagramm ist im Code das extends. Gerechnet wird mit der Methode des echten Objekts: 3 · 2 · 2.",
        ctx="file",
        diagram=FORM_HIERARCHIE,
        group="t32-3"),
]

# ---------------------------------------------------------------- Arrays, Collections, Enums, equals
MIXED = [
    out("r-arr-1a", "arrays", 3, "Was wird ausgegeben?",
        """
        String[][] feld = {{"a", "b"}, {"c", "d"}};
        System.out.println(feld[1][0]);
        """,
        "c",
        "Ein Eierkarton im Eierkarton: feld[1] ist die zweite Reihe, davon Fach 0.",
        group="t07-1"),
    out("r-arr-1b", "arrays", 4, "Was wird ausgegeben?",
        """
        int[] zahlen = {5, 3, 8};
        int summe = 0;
        for (int i = 0; i < zahlen.length; i++) {
            if (i % 2 == 0) {
                summe += zahlen[i];
            }
        }
        System.out.println(summe);
        """,
        "13",
        "Nur die Fächer mit geradem Index zählen: Fach 0 (5) und Fach 2 (8) ergeben 13.",
        group="t07-5"),
    out("r-col-1a", "collections", 3, "Was wird ausgegeben?",
        """
        List<Integer> zahlen = new ArrayList<>(List.of(4, 7, 2));
        zahlen.remove(Integer.valueOf(7));
        System.out.println(zahlen);
        """,
        "[4, 2]",
        "remove mit einem Integer entfernt den Wert 7. Mit remove(1) wäre stattdessen Fach 1 gemeint gewesen.",
        group="t11-3"),
    out("r-col-1b", "collections", 4, "Was wird ausgegeben?",
        """
        Map<String, Integer> punkte = new HashMap<>();
        punkte.put("Ada", 10);
        for (String name : punkte.keySet()) {
            System.out.println(name + ": " + punkte.get(name));
        }
        """,
        "Ada: 10",
        "keySet() liefert alle Schlüssel des Wörterbuchs – dazu holt get den passenden Wert.",
        group="t11-4"),
    out("r-enum-1a", "enums", 3, "Was wird ausgegeben?",
        """
        enum Ampel { ROT, GELB, GRUEN }

        public class Main {
            static String tipp(Ampel a) {
                return switch (a) {
                    case ROT -> "warten";
                    case GELB -> "achtung";
                    case GRUEN -> "fahren";
                };
            }

            public static void main(String[] args) {
                System.out.println(tipp(Ampel.GRUEN));
            }
        }
        """,
        "fahren",
        "Bei einem enum kennt Java alle Fälle – der switch braucht deshalb keinen default-Zweig.",
        ctx="file",
        group="t14-3"),
    out("r-obj-1a", "objectmethods", 4, "Was wird ausgegeben?",
        """
        record Punkt(int x, int y) {}

        public class Main {
            public static void main(String[] args) {
                Punkt a = new Punkt(1, 2);
                Punkt b = new Punkt(1, 2);
                System.out.println(a.equals(b));
                System.out.println(a);
            }
        }
        """,
        """
        true
        Punkt[x=1, y=2]
        """,
        "Ein Record bringt equals und toString fertig mit: gleiche Werte gelten als gleich, die Ausgabe zeigt alle Felder.",
        ctx="file",
        group="t15-3"),
    out("r-test-1a", "testing", 4, "Zwei Prüfungen, eine schlägt fehl. Was wird ausgegeben?",
        """
        static int maximum(int a, int b) {
            if (a > b) {
                return a;
            }
            return b;
        }

        static void pruefe(String name, int erwartet, int erhalten) {
            if (erwartet == erhalten) {
                System.out.println("OK: " + name);
            } else {
                System.out.println("FEHLER: " + name);
            }
        }

        public static void main(String[] args) {
            pruefe("maximum(2, 9)", 9, maximum(2, 9));
            pruefe("maximum(4, 4)", 8, maximum(4, 4));
        }
        """,
        """
        OK: maximum(2, 9)
        FEHLER: maximum(4, 4)
        """,
        "Bei zwei gleichen Werten liefert maximum 4 – der Test erwartet 8 und ist damit selbst falsch.",
        ctx="members",
        group="t21-3"),
    out("r-tool-1a", "tooling", 4, "Die Schleife soll alle Werte ausgeben, bricht aber ab. Was wird ausgegeben?",
        """
        int[] werte = {1, 2, 3};
        try {
            for (int i = 0; i <= werte.length; i++) {
                System.out.println(werte[i]);
            }
        } catch (ArrayIndexOutOfBoundsException e) {
            System.out.println("Index zu gross");
        }
        """,
        """
        1
        2
        3
        Index zu gross
        """,
        "i <= length läuft ein Fach zu weit: Bei i = 3 gibt es kein Fach mehr – ein „Einer-daneben“-Fehler.",
        group="t22-5"),
    out("r-rec-1a", "recursion", 4, "Was wird ausgegeben?",
        """
        static int zaehleZiffern(int n) {
            if (n < 10) {
                return 1;
            }
            return 1 + zaehleZiffern(n / 10);
        }

        public static void main(String[] args) {
            System.out.println(zaehleZiffern(4072));
        }
        """,
        "4",
        "Jede Runde schneidet eine Ziffer ab (n / 10) und zählt 1 dazu. Bei einer einzelnen Ziffer stoppt der Basisfall.",
        ctx="members",
        group="t18-5"),
    out("r-ds-1a", "datastructures", 4, "Was wird ausgegeben?",
        """
        Deque<Integer> stapel = new ArrayDeque<>();
        for (int i = 1; i <= 3; i++) {
            stapel.push(i);
        }
        System.out.println(stapel.pop() + " " + stapel.pop() + " " + stapel.size());
        """,
        "3 2 1",
        "push legt oben drauf, pop nimmt oben weg: erst die 3, dann die 2. Übrig bleibt ein Teller.",
        group="t20-3"),
    out("r-con-1a", "concurrency", 4, "Was wird ausgegeben?",
        """
        try (ExecutorService team = Executors.newVirtualThreadPerTaskExecutor()) {
            List<Future<Integer>> ergebnisse = new ArrayList<>();
            for (int i = 1; i <= 3; i++) {
                int zahl = i;
                ergebnisse.add(team.submit(() -> zahl * 10));
            }
            int summe = 0;
            for (Future<Integer> f : ergebnisse) {
                summe += f.get();
            }
            System.out.println(summe);
        }
        """,
        "60",
        "Drei Aufgaben laufen gleichzeitig, jede liefert ihr Zehnfaches: 10 + 20 + 30 = 60.",
        group="t24-5"),
]

POOL_DEEP = GENERICS + DATETIME + STRINGS + PATTERNS + UML + MIXED
