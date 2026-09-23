"""Übungspool, Teil 3: Module 6–12 (Objekte vertieft bis Abschlussprojekte).

Deckt die Themen ab, die bisher nur Lektionsaufgaben hatten: equals/toString,
Texte und Dateien, Datum, Rekursion, Suchen und Sortieren, Mengen, Testen,
Werkzeuge, Nebenläufigkeit, Pattern Matching und die Projekte.
"""
from authoring import any_of, code, fill, forbid, mc, out, req

# ---------------------------------------------------------------- Enums & static
ENUMS = [
    out("q-enum-1a", "enums", 2, "Was wird ausgegeben?",
        """
        enum Groesse { KLEIN, MITTEL, GROSS }

        public class Main {
            public static void main(String[] args) {
                for (Groesse g : Groesse.values()) {
                    System.out.print(g + " ");
                }
            }
        }
        """,
        "KLEIN MITTEL GROSS ",
        "values() liefert alle erlaubten Werte als Eierkarton – in der Reihenfolge, in der sie aufgezählt wurden.",
        ctx="file",
        group="t14-5"),
    mc("q-enum-1b", "enums", 2, "Was liefert ordinal() bei einem enum-Wert?",
       ["Seine Position in der Aufzählung, gezählt ab 0",
        "Seinen Namen als Text",
        "Die Anzahl aller Werte",
        "Eine Zufallszahl"],
       "Die Aufzählung ist geordnet: Der erste Wert hat ordinal() 0, der zweite 1 und so weiter.",
       group="t14-2"),
    out("q-enum-2a", "enums", 4, "Was wird ausgegeben?",
        """
        class Ticket {
            static int ausgegeben = 0;
            int nummer;

            Ticket() {
                ausgegeben++;
                nummer = ausgegeben;
            }
        }

        public class Main {
            public static void main(String[] args) {
                new Ticket();
                Ticket zweites = new Ticket();
                System.out.println(zweites.nummer + " " + Ticket.ausgegeben);
            }
        }
        """,
        "2 2",
        "ausgegeben gehört der Kuchenform selbst (static) und zählt über alle Objekte hinweg. nummer hat jedes Ticket für sich.",
        ctx="file",
        group="t14-4"),
]

# ---------------------------------------------------------------- equals, toString, abstrakt
OBJECT_METHODS = [
    out("q-obj-1a", "objectmethods", 3, "Was wird ausgegeben?",
        """
        class Stadt {
            String name;

            Stadt(String name) {
                this.name = name;
            }

            @Override
            public String toString() {
                return "Stadt: " + name;
            }
        }

        public class Main {
            public static void main(String[] args) {
                System.out.println(new Stadt("Kiel"));
            }
        }
        """,
        "Stadt: Kiel",
        "println ruft automatisch toString() auf. Ohne eigene Methode stünde dort Klassenname@Nummer.",
        ctx="file",
        group="t15-1"),
    out("q-obj-1b", "objectmethods", 3, "Was wird ausgegeben?",
        """
        String a = new String("Java");
        String b = new String("Java");
        System.out.println(a == b);
        System.out.println(a.equals(b));
        """,
        """
        false
        true
        """,
        "new erzeugt jeweils ein eigenes Objekt: == fragt „derselbe Kuchen?“, equals fragt „dieselben Zutaten?“.",
        group="t15-2"),
    mc("q-obj-2a", "objectmethods", 3, "Warum muss man zu equals auch hashCode schreiben?",
       ["Sonst finden HashSet und HashMap gleiche Objekte nicht wieder",
        "Sonst lässt sich das Objekt nicht ausgeben",
        "Sonst kann man das Objekt nicht erzeugen",
        "Sonst ist equals immer false"],
       "Beide gehören zusammen: Gleiche Objekte brauchen dieselbe Kennnummer, sonst suchen die Sammlungen im falschen Fach.",
       group="t15-2"),
    mc("q-obj-2b", "objectmethods", 4, "Was gilt für eine abstrakte Klasse?",
       ["Aus ihr selbst kann man kein Objekt erzeugen",
        "Sie darf keine Felder haben",
        "Sie darf nur eine Methode enthalten",
        "Sie kann nicht vererbt werden"],
       "Sie ist eine halbfertige Kuchenform: Erst eine Kind-Klasse ergänzt die fehlenden Methoden und kann gebacken werden.",
       group="t15-4"),
]

# ---------------------------------------------------------------- Texte, Eingaben, Dateien
IO = [
    out("q-io-1a", "io", 2, "Was wird ausgegeben?",
        """
        StringBuilder sb = new StringBuilder("Java");
        sb.append(" ist ");
        sb.append("toll");
        System.out.println(sb.toString());
        """,
        "Java ist toll",
        "Der Notizblock wächst mit jedem append. toString() macht daraus am Ende einen normalen Text.",
        group="t16-1"),
    out("q-io-1b", "io", 3, "Was wird ausgegeben?",
        """
        StringBuilder sb = new StringBuilder("stressed");
        System.out.println(sb.reverse());
        """,
        "desserts",
        "reverse() dreht die Reihenfolge aller Zeichen des Notizblocks um.",
        group="t16-2"),
    out("q-io-2a", "io", 3, "Der Scanner liest aus einem festen Text. Was wird ausgegeben?",
        """
        Scanner scanner = new Scanner("Ada Lovelace 1815");
        String vorname = scanner.next();
        String nachname = scanner.next();
        int jahr = scanner.nextInt();
        System.out.println(nachname + ", " + vorname + " (" + jahr + ")");
        """,
        "Lovelace, Ada (1815)",
        "next() liest immer bis zum nächsten Leerzeichen, nextInt() liest die nächste Zahl.",
        group="t16-4"),
    code("q-io-3a", "io", 4, "Baue mit einem StringBuilder aus den drei Wörtern den Text „rot-gelb-blau“ und gib ihn aus.",
         """
         String[] farben = {"rot", "gelb", "blau"};
         // StringBuilder nutzen
         """,
         """
         String[] farben = {"rot", "gelb", "blau"};
         StringBuilder sb = new StringBuilder(farben[0]);
         sb.append("-");
         sb.append(farben[1]);
         sb.append("-");
         sb.append(farben[2]);
         System.out.println(sb.toString());
         """,
         [req(r"new\s+StringBuilder", "Nutze einen StringBuilder."),
          req(r"\.append\(", "Hänge die Teile mit append an."),
          req(r"System\.out\.println", "Gib den fertigen Text aus.")],
         "Der Notizblock sammelt die Teile ein, ohne bei jedem Schritt einen neuen Text zu erzeugen.",
         expected="rot-gelb-blau",
         group="t16-5"),
]

DATETIME = [
    out("q-dat-1a", "datetime", 2, "Was wird ausgegeben?",
        """
        LocalDate tag = LocalDate.of(2026, 3, 15);
        System.out.println(tag.plusDays(20));
        """,
        "2026-04-04",
        "plusDays rechnet über das Monatsende hinweg: Vom 15. März sind 20 Tage der 4. April.",
        group="t17-2"),
    out("q-dat-1b", "datetime", 3, "Was wird ausgegeben?",
        """
        LocalDate start = LocalDate.of(2020, 1, 1);
        LocalDate ende = LocalDate.of(2026, 7, 1);
        System.out.println(Period.between(start, ende).getYears());
        """,
        "6",
        "Period.between misst den Abstand. getYears() liefert nur die vollen Jahre – die halben Monate zählen nicht mit.",
        group="t17-3"),
    fill("q-dat-2a", "datetime", 3, "Ergänze das Muster, damit das Datum als „15.03.2026“ erscheint.",
         """
         LocalDate tag = LocalDate.of(2026, 3, 15);
         DateTimeFormatter format = DateTimeFormatter.ofPattern("{{0}}");
         System.out.println(tag.format(format));
         """,
         [["dd.MM.yyyy"]],
         "dd = Tag zweistellig, MM = Monat zweistellig, yyyy = Jahr vierstellig. Die Punkte stehen so im Ergebnis.",
         verify={"output": "15.03.2026"},
         group="t17-5"),
]

# ---------------------------------------------------------------- Rekursion
RECURSION = [
    out("q-rec-1a", "recursion", 3, "Was wird ausgegeben?",
        """
        static int fakultaet(int n) {
            if (n <= 1) {
                return 1;
            }
            return n * fakultaet(n - 1);
        }

        public static void main(String[] args) {
            System.out.println(fakultaet(4));
        }
        """,
        "24",
        "4 · 3 · 2 · 1 = 24. Der Basisfall n <= 1 stoppt die Kette, sonst würde sie nie enden.",
        ctx="members",
        group="t18-2"),
    mc("q-rec-1b", "recursion", 2, "Was passiert ohne Basisfall in einer rekursiven Methode?",
       ["Die Methode ruft sich endlos selbst auf und das Programm stürzt ab",
        "Java ergänzt den Basisfall automatisch",
        "Die Methode gibt 0 zurück",
        "Der Compiler meldet einen Fehler"],
       "Ohne Abbruch ruft sich das Rezept immer weiter selbst auf, bis der Speicher voll ist (StackOverflowError).",
       group="t18-1"),
    code("q-rec-2a", "recursion", 4, "Schreibe zaehleRunter(int n) rekursiv: Sie gibt n, n-1, … bis 1 aus, jede Zahl in einer Zeile. Bei 0 hört sie auf.",
         "// Deine rekursive Methode hier",
         """
         static void zaehleRunter(int n) {
             if (n <= 0) {
                 return;
             }
             System.out.println(n);
             zaehleRunter(n - 1);
         }
         """,
         [req(r"void\s+zaehleRunter\s*\(\s*int\s+\w+\s*\)", "Die Methode heißt zaehleRunter und bekommt eine Zahl."),
          req(r"zaehleRunter\s*\(\s*\w+\s*-\s*1\s*\)", "Rufe dich selbst mit einer kleineren Zahl auf."),
          req(r"if\s*\(", "Ohne Basisfall hört die Kette nie auf.")],
         "Erst ausgeben, dann sich selbst mit einer kleineren Zahl aufrufen – bei 0 bricht der Basisfall ab.",
         ctx="members",
         verify={"context": "members", "main": "zaehleRunter(3);", "output": "3\n2\n1"},
         group="t18-5"),
]

# ---------------------------------------------------------------- Suchen & Sortieren
ALGORITHMS = [
    mc("q-alg-1a", "algorithms", 2, "Warum ist die binäre Suche schneller als die lineare?",
       ["Sie wirft mit jedem Blick die Hälfte der Einträge weg",
        "Sie schaut sich jeden Eintrag genauer an",
        "Sie sortiert die Liste vorher",
        "Sie braucht weniger Speicher"],
       "Wie im Telefonbuch: In die Mitte schauen, entscheiden, in welcher Hälfte es weitergeht. Das halbiert jedes Mal.",
       group="t19-2"),
    out("q-alg-1b", "algorithms", 3, "Was wird ausgegeben?",
        """
        String[] namen = {"Zoe", "Ada", "Mia"};
        Arrays.sort(namen);
        System.out.println(Arrays.toString(namen));
        """,
        "[Ada, Mia, Zoe]",
        "Arrays.sort sortiert Texte alphabetisch – in den Fächern liegen die Namen danach in neuer Reihenfolge.",
        group="t19-3"),
    out("q-alg-2a", "algorithms", 4, "Was wird ausgegeben?",
        """
        List<String> woerter = new ArrayList<>(List.of("Kiwi", "Banane", "Apfel"));
        woerter.sort(Comparator.comparing(String::length));
        System.out.println(woerter);
        """,
        "[Kiwi, Apfel, Banane]",
        "Sortiert wird nach der Länge: Kiwi (4), Apfel (5), Banane (6). Bei gleicher Länge bliebe die alte Reihenfolge.",
        group="t19-5"),
    code("q-alg-3a", "algorithms", 4, "Zähle mit einer Schleife, wie viele Zahlen größer als 10 sind, und gib die Anzahl aus.",
         """
         int[] zahlen = {4, 17, 9, 23, 11};
         // Zählen und ausgeben
         """,
         """
         int[] zahlen = {4, 17, 9, 23, 11};
         int anzahl = 0;
         for (int z : zahlen) {
             if (z > 10) {
                 anzahl++;
             }
         }
         System.out.println(anzahl);
         """,
         [req(r"\bfor\b", "Geh mit einer Schleife durch alle Fächer."),
          req(r">\s*10", "Vergleiche jeden Wert mit 10."),
          forbid(r"println\(3\)", "Nicht die Antwort hinschreiben – lass Java zählen.")],
         "Ein Zähler startet bei 0 und wächst bei jedem Treffer: 17, 23 und 11 sind größer als 10.",
         expected="3",
         group="t19-4"),
]

# ---------------------------------------------------------------- Set, Stack, Queue
DATASTRUCTURES = [
    out("q-ds-1a", "datastructures", 3, "Was wird ausgegeben?",
        """
        Set<String> menge = new TreeSet<>(List.of("Zebra", "Ameise", "Zebra"));
        System.out.println(menge);
        """,
        "[Ameise, Zebra]",
        "Das TreeSet nimmt jeden Eintrag nur einmal und sortiert alphabetisch – „Zebra“ zählt trotz zweimal nur einmal.",
        group="t20-2"),
    out("q-ds-1b", "datastructures", 3, "Was wird ausgegeben?",
        """
        Deque<String> schlange = new ArrayDeque<>();
        schlange.offer("Ada");
        schlange.offer("Linus");
        System.out.println(schlange.poll());
        System.out.println(schlange.peek());
        """,
        """
        Ada
        Linus
        """,
        "In der Warteschlange ist dran, wer zuerst kam: poll holt Ada ab, peek schaut nur, wer jetzt vorne steht.",
        group="t20-4"),
    mc("q-ds-2a", "datastructures", 3, "Welche Struktur passt zum Zurücknehmen der letzten Änderung?",
       ["Ein Stapel – zuletzt drauf, zuerst weg",
        "Eine Warteschlange – wer zuerst kommt, ist zuerst dran",
        "Ein Set – jeder Eintrag nur einmal",
        "Eine Map – Schlüssel und Wert"],
       "Rückgängig heißt: die jüngste Änderung zuerst. Genau das leistet der Tellerstapel mit push und pop.",
       group="t20-1"),
    code("q-ds-3a", "datastructures", 4, "Zähle mit einem Set, wie viele verschiedene Buchstaben in der Liste stehen, und gib die Zahl aus.",
         """
         List<String> zeichen = List.of("a", "b", "a", "c", "b");
         // Set nutzen und Anzahl ausgeben
         """,
         """
         List<String> zeichen = List.of("a", "b", "a", "c", "b");
         Set<String> verschieden = new HashSet<>(zeichen);
         System.out.println(verschieden.size());
         """,
         [req(r"new\s+HashSet", "Nutze ein HashSet."),
          req(r"\.size\(\)", "Gib die Anzahl mit size() aus.")],
         "Das Set wirft Doppelte weg: Übrig bleiben a, b und c – also 3.",
         expected="3",
         group="t20-5"),
]

# ---------------------------------------------------------------- Testen
TESTING = [
    out("q-test-1a", "testing", 3, "Alle drei Prüfungen sollen OK melden. Was wird ausgegeben?",
        """
        static int betrag(int n) {
            if (n < 0) {
                return -n;
            }
            return n;
        }

        static void pruefe(String name, int erwartet, int erhalten) {
            if (erwartet == erhalten) {
                System.out.println("OK: " + name);
            } else {
                System.out.println("FEHLER: " + name);
            }
        }

        public static void main(String[] args) {
            pruefe("betrag(5)", 5, betrag(5));
            pruefe("betrag(-3)", 3, betrag(-3));
            pruefe("betrag(0)", 0, betrag(0));
        }
        """,
        """
        OK: betrag(5)
        OK: betrag(-3)
        OK: betrag(0)
        """,
        "Jede Prüfung vergleicht erwartet mit erhalten. Alle drei stimmen – der Code besteht den Test.",
        ctx="members",
        group="t21-5"),
    mc("q-test-1b", "testing", 2, "Was prüft man in einem Test sinnvollerweise zuerst?",
       ["Den Normalfall und die Randfälle wie 0 oder negative Werte",
        "Nur besonders große Zahlen",
        "Nur Fälle, die sicher funktionieren",
        "Die Geschwindigkeit des Programms"],
       "Fehler verstecken sich meist an den Rändern: 0, negative Werte, leere Listen. Der Normalfall gehört trotzdem dazu.",
       group="t21-1"),
    mc("q-test-2a", "testing", 3, "Ein Test schlägt fehl, obwohl der Code stimmt. Was ist zu tun?",
       ["Den Test prüfen – auch Tests können falsch sein",
        "Den Code anpassen, bis der Test grün wird",
        "Den Test löschen",
        "Die Prüfung ignorieren"],
       "Ein Test ist auch nur Code. Erwartet er das Falsche, muss der Test korrigiert werden – nicht der richtige Code.",
       group="t21-3"),
    fill("q-test-3a", "testing", 3, "Ergänze den JUnit-Test: Er soll prüfen, dass 2 + 3 gleich 5 ist.",
         """
         class RechnerTest {
             @Test
             void addiert() {
                 {{0}}(5, 2 + 3);
             }
         }
         """,
         [["assertEquals"]],
         "assertEquals vergleicht – erwarteter Wert zuerst, dann das tatsächliche Ergebnis.",
         verify={"skip": True},
         group="t21-4"),
]

# ---------------------------------------------------------------- Werkzeuge & Fehlersuche
TOOLING = [
    mc("q-tool-1a", "tooling", 2, "Wozu dient import java.util.List;?",
       ["Es holt die Klasse List aus einem anderen Paket herein",
        "Es lädt eine Datei von der Festplatte",
        "Es startet das Programm",
        "Es erzeugt eine neue Liste"],
       "import sagt Java, wo eine Klasse wohnt. Ohne die Zeile müsste man überall java.util.List ausschreiben.",
       group="t22-1"),
    out("q-tool-1b", "tooling", 3, "Was wird ausgegeben?",
        """
        String text = null;
        try {
            System.out.println(text.length());
        } catch (NullPointerException e) {
            System.out.println("nichts drin");
        }
        System.out.println("weiter");
        """,
        """
        nichts drin
        weiter
        """,
        "In der Box liegt null – also nichts. length() darauf löst den Alarm aus, das Netz fängt ihn auf.",
        group="t22-3"),
    out("q-tool-2a", "tooling", 4, "Der Code soll 1 bis 4 aufaddieren (10). Was kommt wirklich heraus?",
        """
        int summe = 0;
        for (int i = 1; i < 4; i++) {
            summe += i;
        }
        System.out.println(summe);
        """,
        "6",
        "i < 4 hört bei 3 auf: 1 + 2 + 3 = 6. Mit i <= 4 käme die 4 dazu – der klassische „Einer-daneben“-Fehler.",
        group="t22-5"),
    mc("q-tool-2b", "tooling", 3, "Was steht in der obersten Zeile eines Stacktrace?",
       ["Die Art des Fehlers und die Meldung",
        "Der Name des Programmierers",
        "Die letzte erfolgreiche Zeile",
        "Die Uhrzeit des Absturzes"],
       "Ganz oben steht, was passiert ist. Darunter die Kette der Aufrufe – die erste Zeile aus eigenem Code ist der beste Startpunkt.",
       group="t22-2"),
]

# ---------------------------------------------------------------- Nebenläufigkeit
CONCURRENCY = [
    mc("q-con-1a", "concurrency", 2, "Was macht start() bei einem Thread?",
       ["Es lässt den Thread parallel zum Hauptprogramm loslaufen",
        "Es wartet, bis der Thread fertig ist",
        "Es führt die Aufgabe sofort im Hauptprogramm aus",
        "Es beendet den Thread"],
       "start() gibt den zweiten Arbeitsstrang frei. Warten muss man getrennt mit join().",
       group="t23-1"),
    out("q-con-1b", "concurrency", 3, "Was wird ausgegeben?",
        """
        AtomicInteger zaehler = new AtomicInteger();
        Thread a = new Thread(() -> {
            for (int i = 0; i < 100; i++) {
                zaehler.incrementAndGet();
            }
        });
        a.start();
        a.join();
        System.out.println(zaehler.get());
        """,
        "100",
        "Der sichere Zähler verliert keinen Schritt. join() wartet, bis der Thread fertig ist – erst dann stimmt die Zahl.",
        group="t23-5"),
    mc("q-con-2a", "concurrency", 3, "Warum kann ein normaler int-Zähler bei zwei Threads falsch zählen?",
       ["Beide lesen denselben Wert und schreiben dieselbe Zahl zurück",
        "int ist zu klein für große Zahlen",
        "Threads dürfen keine Zahlen ändern",
        "Der Zähler wird automatisch zurückgesetzt"],
       "Beide lesen 5, beide schreiben 6 – ein Schritt geht verloren. Das nennt man Wettlauf (Race Condition).",
       group="t23-2"),
    out("q-con-2b", "concurrency", 4, "Was wird ausgegeben?",
        """
        try (ExecutorService team = Executors.newFixedThreadPool(2)) {
            Future<Integer> a = team.submit(() -> 3 * 3);
            Future<Integer> b = team.submit(() -> 100 / 4);
            System.out.println(a.get() + b.get());
        }
        """,
        "34",
        "Beide Aufgaben laufen im Team. get() wartet auf das jeweilige Ergebnis: 9 + 25 = 34.",
        group="t24-3"),
    mc("q-con-3a", "concurrency", 3, "Was ist der Vorteil virtueller Threads?",
       ["Sie sind so leicht, dass Tausende gleichzeitig warten können",
        "Sie rechnen schneller als normale Threads",
        "Sie brauchen kein join()",
        "Sie laufen ohne Executor"],
       "Virtuelle Threads kosten fast nichts. Ideal, wenn viele Aufgaben nur auf Antworten warten – etwa aus dem Netz.",
       group="t24-2"),
]

# ---------------------------------------------------------------- sealed & Pattern Matching
PATTERNS = [
    mc("q-pat-1a", "patterns", 2, "Wozu dient permits bei einem sealed interface?",
       ["Es zählt auf, welche Klassen dazugehören dürfen",
        "Es erlaubt jedem, das Interface umzusetzen",
        "Es verbietet jede Vererbung",
        "Es legt die Reihenfolge im switch fest"],
       "Die Familie ist geschlossen. Dadurch weiß Java genau, welche Sorten es gibt, und prüft, ob ein switch alle abdeckt.",
       group="t25-1"),
    out("q-pat-1b", "patterns", 3, "Was wird ausgegeben?",
        """
        record Punkt(int x, int y) {}

        public class Main {
            public static void main(String[] args) {
                Object o = new Punkt(2, 5);
                if (o instanceof Punkt(int x, int y)) {
                    System.out.println(x * y);
                }
            }
        }
        """,
        "10",
        "Das Record-Muster prüft die Sorte und packt x und y gleich in eigene Boxen aus: 2 · 5 = 10.",
        ctx="file",
        group="t25-2"),
    out("q-pat-2a", "patterns", 4, "Was wird ausgegeben?",
        """
        Object wert = "Hallo";
        String antwort = switch (wert) {
            case String s when s.length() > 10 -> "langer Text";
            case String s -> "kurzer Text mit " + s.length() + " Zeichen";
            default -> "kein Text";
        };
        System.out.println(antwort);
        """,
        "kurzer Text mit 5 Zeichen",
        "Der erste Fall passt nur mit der Zusatzbedingung nach when. „Hallo“ hat 5 Zeichen, deshalb greift der zweite.",
        group="t25-3"),
]

# ---------------------------------------------------------------- Projekte
PROJECTS = [
    out("q-proj-1a", "projects", 3, "Was wird ausgegeben?",
        """
        int[] noten = {2, 1, 3, 2};
        int summe = 0;
        for (int n : noten) {
            summe += n;
        }
        double schnitt = (double) summe / noten.length;
        System.out.println(schnitt);
        """,
        "2.0",
        "Ohne (double) wäre es eine Ganzzahldivision: 8 / 4 geht hier zwar auf, aber der Cast macht es zuverlässig.",
        group="t27-2"),
    out("q-proj-1b", "projects", 3, "Was wird ausgegeben?",
        """
        record Aufgabe(String titel, boolean erledigt) {}

        public class Main {
            public static void main(String[] args) {
                List<Aufgabe> liste = List.of(new Aufgabe("Einkaufen", true), new Aufgabe("Lernen", false));
                liste.stream()
                        .filter(a -> !a.erledigt())
                        .forEach(a -> System.out.println(a.titel()));
            }
        }
        """,
        "Lernen",
        "Der Filter lässt nur offene Aufgaben durch – das Ausrufezeichen dreht die Antwort von erledigt() um.",
        ctx="file",
        group="t28-3"),
    out("q-proj-2a", "projects", 4, "Was wird ausgegeben?",
        """
        enum Raum { FLUR, KUECHE }

        public class Main {
            public static void main(String[] args) {
                Map<String, Raum> tueren = Map.of("norden", Raum.KUECHE);
                Raum ziel = tueren.getOrDefault("sueden", Raum.FLUR);
                System.out.println(ziel);
            }
        }
        """,
        "FLUR",
        "Nach Süden gibt es keine Tür – getOrDefault liefert dann den Ersatzwert statt null.",
        ctx="file",
        group="t29-2"),
]

POOL_ADVANCED = (
    ENUMS + OBJECT_METHODS + IO + DATETIME + RECURSION + ALGORITHMS
    + DATASTRUCTURES + TESTING + TOOLING + CONCURRENCY + PATTERNS + PROJECTS
)
