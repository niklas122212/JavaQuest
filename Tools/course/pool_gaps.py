"""Übungspool, Teil 7: eine zweite Variante für jedes verbliebene Lernziel.

Hier ging es nicht um mehr Aufgaben insgesamt, sondern gezielt um die 35 Lernziele,
die bisher nur eine einzige Aufgabe hatten. Genau dort hätte man nach einer falschen
Antwort beim Wiederholen wieder dieselbe Frage bekommen.
"""
from authoring import code, fill, forbid, mc, out, req
from uml_content import FORM_HIERARCHIE, INTERFACE_DIAGRAM, KONTO, PERSON, TIER_HUND, box, diagram, m, rel

# ---------------------------------------------------------------- Schleifen, Lambdas, modernes Java
BASICS = [
    out("v-loop-2", "loops", 2, "Was gibt die Schleife aus?",
        """
        for (int i = 5; i >= 1; i--) {
            System.out.print(i + ",");
        }
        """,
        "5,4,3,2,1,",
        "print bleibt in derselben Zeile – alle Zahlen stehen hintereinander, jeweils mit Komma.",
        group="t05-2"),
    out("v-lam-2", "lambdas", 2, "Was gibt forEach aus?",
        """
        List<String> farben = List.of("rot", "gruen");
        farben.forEach(f -> System.out.println(f.toUpperCase()));
        """,
        """
        ROT
        GRUEN
        """,
        "forEach ruft die Mini-Anweisung für jedes Element auf – in der Reihenfolge der Liste.",
        group="t12-2"),
    out("v-mod-2", "modern", 2, "Was gibt das Programm aus?",
        """
        record Ort(String name, int plz) {}

        public class Main {
            public static void main(String[] args) {
                Ort o = new Ort("Kiel", 24103);
                System.out.println(o.plz());
                System.out.println(o.equals(new Ort("Kiel", 24103)));
            }
        }
        """,
        """
        24103
        true
        """,
        "Der Record liefert zu jedem Feld eine Lesemethode und vergleicht mit equals die Werte, nicht die Objekte.",
        ctx="file",
        group="t13-2"),
    code("v-obj-5", "objectmethods", 5,
         "Ergänze in der Klasse Film eine toString-Methode, die „Titel (Jahr)“ liefert – z. B. „Matrix (1999)“.",
         """
         class Film {
             String titel = "Matrix";
             int jahr = 1999;

             // toString hier ergänzen
         }
         """,
         """
         class Film {
             String titel = "Matrix";
             int jahr = 1999;

             @Override
             public String toString() {
                 return titel + " (" + jahr + ")";
             }
         }
         """,
         [req(r"public\s+String\s+toString\s*\(\s*\)", "Schreibe die Methode toString()."),
          req(r"return\s+titel", "Baue den Text aus titel und jahr zusammen."),
          req(r'"\s*\("', "Setze das Jahr in runde Klammern.", scope="raw")],
         "println fragt jedes Objekt nach seiner toString-Methode – so bestimmst du selbst, was erscheint.",
         ctx="file",
         verify={"context": "file", "main": "System.out.println(new Film());", "output": "Matrix (1999)"},
         group="t15-5"),
]

# ---------------------------------------------------------------- Dateien und Werkzeuge
IO_TOOLS = [
    mc("v-io-1", "io", 2, "Warum verlangt Java bei Dateizugriffen ein try-catch?",
       ["Weil der Zugriff scheitern kann – IOException ist eine checked Exception",
        "Weil Dateien immer langsam sind",
        "Weil sonst die Datei gelöscht wird",
        "Weil try-catch die Datei öffnet"],
       "Festplatte voll, Datei weg, keine Rechte – all das kann passieren. Bei checked Exceptions besteht Java darauf, dass du dich kümmerst.",
       group="t17-1"),
    fill("v-io-4", "io", 4, "Ergänze: Zwei Zeilen schreiben, alle Zeilen lesen und die erste ausgeben.",
         """
         try {
             Path datei = Files.createTempFile("notiz", ".txt");
             Files.{{0}}(datei, "Hallo\\nWelt");
             List<String> zeilen = Files.{{1}}(datei);
             System.out.println(zeilen.get(0));
             Files.delete(datei);
         } catch ({{2}} e) {
             System.out.println("Fehler");
         }
         """,
         [["writeString"], ["readAllLines"], ["IOException", "Exception"]],
         "writeString legt den Text in die Datei, readAllLines holt ihn zeilenweise zurück – get(0) ist die erste Zeile.",
         verify={"output": "Hallo"},
         group="t17-4"),
    fill("v-tool-4", "tooling", 4, "Ergänze das Sicherheitsnetz, damit der Zugriff auf ein fehlendes Fach das Programm nicht abbricht.",
         """
         int[] zahlen = {1, 2};
         {{0}} {
             System.out.println(zahlen[3]);
         } {{1}} (ArrayIndexOutOfBoundsException e) {
             System.out.println("Fach gibt es nicht");
         }
         """,
         [["try"], ["catch"]],
         "Der riskante Zugriff steht im try, das catch fängt genau diesen Alarm auf – danach läuft das Programm weiter.",
         verify={"output": "Fach gibt es nicht"},
         group="t22-4"),
]

# ---------------------------------------------------------------- Nebenläufigkeit
CONCURRENCY = [
    out("v-con-3", "concurrency", 3, "Was wird ausgegeben?",
        """
        Thread arbeiter = new Thread(() -> System.out.println("im Thread"));
        System.out.println("vor start");
        arbeiter.start();
        arbeiter.join();
        System.out.println("nach join");
        """,
        """
        vor start
        im Thread
        nach join
        """,
        "„vor start“ läuft, bevor der Thread überhaupt existiert. join wartet auf sein Ende – erst danach kommt die letzte Zeile.",
        group="t23-3"),
    mc("v-con-1", "concurrency", 2, "Wofür steht ein Future?",
       ["Für einen Abholschein: Das Ergebnis kommt später",
        "Für einen Thread, der noch nicht gestartet ist",
        "Für eine Aufgabe, die fehlgeschlagen ist",
        "Für die Uhrzeit, zu der eine Aufgabe startet"],
       "submit liefert sofort den Schein zurück. Mit get() holst du das Ergebnis ab – notfalls wartet get, bis es fertig ist.",
       group="t24-1"),
    fill("v-con-4", "concurrency", 4, "Ergänze: Ein Team aus zwei Threads rechnet 4 · 5, das Ergebnis wird abgeholt.",
         """
         try (ExecutorService team = Executors.{{0}}(2)) {
             Future<Integer> produkt = team.{{1}}(() -> 4 * 5);
             System.out.println(produkt.{{2}}());
         }
         """,
         [["newFixedThreadPool"], ["submit"], ["get"]],
         "newFixedThreadPool(2) stellt ein Team aus zwei festen Arbeitern, submit reicht die Aufgabe ein, get holt die 20 ab.",
         verify={"output": "20"},
         group="t24-4"),
]

# ---------------------------------------------------------------- Pattern Matching
PATTERNS = [
    code("v-pat-5", "patterns", 5,
         "Ergänze beschreibe mit einem switch über Getraenk: Tee → „Tee: <sorte>“, Saft → „Saft: <frucht>“. Ausgegeben wird der Saft.",
         """
         sealed interface Getraenk permits Tee, Saft {}
         record Tee(String sorte) implements Getraenk {}
         record Saft(String frucht) implements Getraenk {}

         public class Main {
             static String beschreibe(Getraenk g) {
                 // switch über die Sorte
                 return "";
             }

             public static void main(String[] args) {
                 System.out.println(beschreibe(new Saft("Apfel")));
             }
         }
         """,
         """
         sealed interface Getraenk permits Tee, Saft {}
         record Tee(String sorte) implements Getraenk {}
         record Saft(String frucht) implements Getraenk {}

         public class Main {
             static String beschreibe(Getraenk g) {
                 return switch (g) {
                     case Tee t -> "Tee: " + t.sorte();
                     case Saft s -> "Saft: " + s.frucht();
                 };
             }

             public static void main(String[] args) {
                 System.out.println(beschreibe(new Saft("Apfel")));
             }
         }
         """,
         [req(r"switch\s*\(", "Nutze einen switch über das Getränk."),
          req(r"case\s+Tee", "Behandle den Fall Tee."),
          req(r"case\s+Saft", "Behandle den Fall Saft.")],
         "Weil die Familie mit sealed geschlossen ist, kennt Java alle Fälle – ein default-Zweig ist nicht nötig.",
         ctx="file",
         expected="Saft: Apfel",
         group="t25-5"),
]

# ---------------------------------------------------------------- Streams für Profis
STREAMS = [
    mc("v-str-1", "lambdas", 2, "Was entsteht bei Collectors.groupingBy?",
       ["Ein Wörterbuch: Fach → was darin liegt",
        "Eine sortierte Liste", "Eine einzelne Zahl", "Ein Eierkarton fester Größe"],
       "groupingBy sortiert die Elemente in Fächer wie Post in Briefkästen. Heraus kommt eine Map.",
       group="t26-1"),
    out("v-str-2", "lambdas", 3, "Was wird ausgegeben?",
        """
        List<Integer> zahlen = List.of(5, 1, 3);
        int produkt = zahlen.stream()
                .sorted()
                .reduce(1, (a, b) -> a * b);
        System.out.println(produkt);
        """,
        "15",
        "sorted ordnet erst (1, 3, 5), reduce fasst dann alles zu einem Wert zusammen: 1 · 1 · 3 · 5 = 15.",
        group="t26-2"),
    out("v-str-3", "lambdas", 4, "Die Wörter werden nach ihrer Länge gruppiert. Was wird ausgegeben?",
        """
        List<String> woerter = List.of("Tee", "Saft", "Hut");
        Map<Integer, List<String>> nachLaenge = woerter.stream()
                .collect(Collectors.groupingBy(String::length, TreeMap::new, Collectors.toList()));
        System.out.println(nachLaenge);
        """,
        "{3=[Tee, Hut], 4=[Saft]}",
        "Jedes Wort landet im Fach seiner Länge. TreeMap hält die Fächer sortiert, innerhalb bleibt die Reihenfolge erhalten.",
        group="t26-3"),
    fill("v-str-4", "lambdas", 4, "Ergänze: Alle Zahlen aus beiden Listen in einer flachen, sortierten Liste.",
         """
         List<List<Integer>> kisten = List.of(List.of(4, 1), List.of(3));
         List<Integer> alle = kisten.stream()
                 .{{0}}(List::stream)
                 .{{1}}()
                 .toList();
         System.out.println(alle);
         """,
         [["flatMap"], ["sorted"]],
         "flatMap packt die Teillisten aus – aus vielen kleinen wird ein Band. sorted ordnet danach aufsteigend.",
         verify={"output": "[1, 3, 4]"},
         group="t26-4"),
    code("v-str-5", "lambdas", 5, "Finde mit einem Stream die kleinste Zahl in zahlen und gib sie aus – ohne Schleife.",
         """
         List<Integer> zahlen = List.of(8, 3, 11);
         // kleinste Zahl finden
         """,
         """
         List<Integer> zahlen = List.of(8, 3, 11);
         int kleinste = zahlen.stream()
                 .min(Comparator.naturalOrder())
                 .orElse(0);
         System.out.println(kleinste);
         """,
         [req(r"\.stream\s*\(\s*\)", "Starte mit zahlen.stream()."),
          req(r"\.min\s*\(|\.sorted\s*\(", "Suche das kleinste Element, z. B. mit min(…)."),
          forbid(r"\bfor\b|\bwhile\b", "Ohne Schleife – dafür ist das Fließband da.")],
         "min liefert eine Schachtel (Optional), weil die Liste leer sein könnte. orElse holt den Inhalt oder einen Ersatz.",
         expected="3",
         group="t26-5"),
]

# ---------------------------------------------------------------- Projekt: Notenrechner
GRADES = [
    mc("v-grd-1", "projects", 2, "Warum reicht int für einen Notendurchschnitt nicht?",
       ["Weil der Durchschnitt fast immer Nachkommastellen hat",
        "Weil Noten negativ sein können",
        "Weil int zu klein für Noten ist",
        "Weil Java bei Noten immer double verlangt"],
       "2, 1 und 2 ergeben im Schnitt 1,67. Mit int würde daraus 1 – der Rest fiele weg.",
       group="t27-1"),
    out("v-grd-3", "projects", 3, "Bestanden ist bis Note 4. Wie viele haben bestanden?",
        """
        int[] noten = {1, 5, 3, 4, 6};
        int bestanden = 0;
        for (int n : noten) {
            if (n <= 4) {
                bestanden++;
            }
        }
        System.out.println(bestanden);
        """,
        "3",
        "Die Noten 1, 3 und 4 sind höchstens 4 – die 5 und die 6 zählen nicht mit.",
        group="t27-3"),
    fill("v-grd-4", "projects", 4, "Ergänze: Durchschnitt und schlechteste (größte) Note mit Streams.",
         """
         int[] noten = {2, 4, 1};
         double schnitt = Arrays.stream(noten).{{0}}().orElse(0);
         int schlechteste = Arrays.stream(noten).{{1}}().orElse(0);
         System.out.println(schnitt + " " + schlechteste);
         """,
         [["average"], ["max"]],
         "average bildet den Durchschnitt (7 / 3 ≈ 2,33), max sucht die größte Zahl – beide liefern eine Schachtel.",
         verify={"output": "2.3333333333333335 4"},
         group="t27-4"),
    code("v-grd-5", "projects", 5,
         "Schreibe zeugnis(int[] noten): Es gibt „Beste: X, Schlechteste: Y“ aus – für {2, 5, 3} also „Beste: 2, Schlechteste: 5“.",
         "// Deine Methode hier",
         """
         static void zeugnis(int[] noten) {
             int beste = noten[0];
             int schlechteste = noten[0];
             for (int n : noten) {
                 if (n < beste) {
                     beste = n;
                 }
                 if (n > schlechteste) {
                     schlechteste = n;
                 }
             }
             System.out.println("Beste: " + beste + ", Schlechteste: " + schlechteste);
         }
         """,
         [req(r"void\s+zeugnis\s*\(\s*int\[\]\s*\w+\s*\)", "Die Methode heißt zeugnis und bekommt ein int-Array."),
          req(r"\bfor\b|\.stream\(\)", "Geh alle Noten durch."),
          req(r'"Beste: "', "Gib den Text genau so aus.", scope="raw")],
         "Bei Noten ist die kleinste Zahl die beste. Man merkt sich beide Extremwerte und ersetzt sie bei Bedarf.",
         ctx="members",
         verify={"context": "members", "main": "zeugnis(new int[]{2, 5, 3});", "output": "Beste: 2, Schlechteste: 5"},
         group="t27-5"),
]

# ---------------------------------------------------------------- Projekt: Aufgabenliste
TODO = [
    mc("v-todo-1", "projects", 2, "Was spricht für einen Record als Aufgabe?",
       ["Er bringt Konstruktor, Lesemethoden, equals und toString fertig mit",
        "Er ist schneller als eine Klasse",
        "Er erlaubt das nachträgliche Ändern der Felder",
        "Er braucht keine Feldnamen"],
       "Ein Record ist ein fertiges Formular für Daten: Java erledigt den ganzen Rumpf, du schreibst nur die Felder hin.",
       group="t28-1"),
    out("v-todo-2", "projects", 2, "Was wird ausgegeben?",
        """
        record Aufgabe(String titel, boolean erledigt) {}

        public class Main {
            public static void main(String[] args) {
                Aufgabe a = new Aufgabe("Lernen", false);
                System.out.println(a.erledigt());
                System.out.println(a);
            }
        }
        """,
        """
        false
        Aufgabe[titel=Lernen, erledigt=false]
        """,
        "erledigt() liest das Feld. Das automatische toString zeigt alle Felder mit Namen und Wert.",
        ctx="file",
        group="t28-2"),
    fill("v-todo-4", "projects", 4, "Ergänze: Aufgabe anhängen und danach die erste durch eine erledigte ersetzen.",
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 List<Aufgabe> liste = new ArrayList<>();
                 liste.{{0}}(new Aufgabe("Einkaufen", false));
                 liste.{{1}}(0, new Aufgabe("Einkaufen", true));
                 System.out.println(liste.get(0).erledigt());
             }
         }
         """,
         [["add"], ["set"]],
         "add hängt hinten an, set ersetzt den Eintrag an einer Stelle. Ein Record lässt sich nicht ändern – man legt einen neuen an.",
         ctx="file",
         verify={"context": "file", "output": "true"},
         group="t28-4"),
    code("v-todo-5", "projects", 5,
         "Gib jede Aufgabe mit Häkchen aus: „[x] Einkaufen“ für erledigte, „[ ] Lernen“ für offene.",
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 List<Aufgabe> liste = List.of(new Aufgabe("Einkaufen", true), new Aufgabe("Lernen", false));
                 // Liste ausgeben
             }
         }
         """,
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 List<Aufgabe> liste = List.of(new Aufgabe("Einkaufen", true), new Aufgabe("Lernen", false));
                 for (Aufgabe a : liste) {
                     String haken = a.erledigt() ? "[x] " : "[ ] ";
                     System.out.println(haken + a.titel());
                 }
             }
         }
         """,
         [req(r"\bfor\b|forEach", "Geh die Liste durch."),
          req(r"erledigt\(\)", "Frag mit erledigt() nach dem Zustand."),
          req(r"\[x\]", "Nutze [x] für erledigte Aufgaben.", scope="raw")],
         "Der Fragezeichen-Operator wählt zwischen zwei Werten: Bedingung ? dann : sonst.",
         ctx="file",
         expected="[x] Einkaufen\n[ ] Lernen",
         group="t28-5"),
]

# ---------------------------------------------------------------- Projekt: Textabenteuer
ADVENTURE = [
    mc("v-adv-1", "projects", 2, "Warum sind die Räume ein enum statt einfacher Texte?",
       ["Java lässt dann nur die aufgezählten Räume zu – Tippfehler fallen sofort auf",
        "Ein enum braucht weniger Speicher",
        "Texte kann man nicht vergleichen",
        "Ein enum lässt sich schneller ausgeben"],
       "Bei Texten wäre „Kueche “ mit Leerzeichen ein anderer Raum. Beim enum gibt es nur genau die aufgezählten Werte.",
       group="t29-1"),
    out("v-adv-3", "projects", 3, "Was wird ausgegeben?",
        """
        enum Raum { FLUR, KELLER }

        public class Main {
            static String beschreibung(Raum r) {
                return switch (r) {
                    case FLUR -> "Ein enger Gang.";
                    case KELLER -> "Es ist dunkel.";
                };
            }

            public static void main(String[] args) {
                System.out.println(beschreibung(Raum.KELLER));
                System.out.println(beschreibung(Raum.FLUR));
            }
        }
        """,
        """
        Es ist dunkel.
        Ein enger Gang.
        """,
        "Der switch liefert zu jedem Raum seine Beschreibung – aufgerufen in der Reihenfolge der beiden Zeilen.",
        ctx="file",
        group="t29-3"),
    fill("v-adv-4", "projects", 4, "Ergänze: Jeden Befehl durchgehen und bei unbekannter Richtung im Raum bleiben.",
         """
         enum Raum { FLUR, GARTEN }

         public class Main {
             public static void main(String[] args) {
                 Map<String, Raum> tueren = Map.of("osten", Raum.GARTEN);
                 Raum aktuell = Raum.FLUR;
                 String[] befehle = {"westen", "osten"};
                 {{0}} (String befehl : befehle) {
                     aktuell = tueren.{{1}}(befehl, aktuell);
                 }
                 System.out.println(aktuell);
             }
         }
         """,
         [["for"], ["getOrDefault"]],
         "getOrDefault liefert den Ersatzwert, wenn es die Tür nicht gibt – „westen“ lässt einen also stehen, „osten“ führt in den Garten.",
         ctx="file",
         verify={"context": "file", "output": "GARTEN"},
         group="t29-4"),
    code("v-adv-5", "projects", 5,
         "Geh alle Befehle durch: Bei einer bekannten Tür wechselst du den Raum, sonst bleibst du. Gib am Ende den Raum aus.",
         """
         enum Raum { FLUR, KUECHE }

         public class Main {
             public static void main(String[] args) {
                 Map<String, Raum> tueren = Map.of("norden", Raum.KUECHE);
                 Raum aktuell = Raum.FLUR;
                 String[] befehle = {"sueden", "norden"};
                 // Befehle abarbeiten und Raum ausgeben
             }
         }
         """,
         """
         enum Raum { FLUR, KUECHE }

         public class Main {
             public static void main(String[] args) {
                 Map<String, Raum> tueren = Map.of("norden", Raum.KUECHE);
                 Raum aktuell = Raum.FLUR;
                 String[] befehle = {"sueden", "norden"};
                 for (String befehl : befehle) {
                     aktuell = tueren.getOrDefault(befehl, aktuell);
                 }
                 System.out.println(aktuell);
             }
         }
         """,
         [req(r"\bfor\b", "Geh alle Befehle mit einer Schleife durch."),
          req(r"getOrDefault|containsKey", "Unbekannte Richtungen dürfen den Raum nicht ändern."),
          req(r"System\.out\.println", "Gib am Ende den Raum aus.")],
         "„sueden“ steht nicht im Wörterbuch – getOrDefault gibt dann den aktuellen Raum zurück. „norden“ führt in die Küche.",
         ctx="file",
         expected="KUECHE",
         group="t29-5"),
]

# ---------------------------------------------------------------- UML
UML_KONTO2 = diagram([
    box("Lampe",
        fields=[m("-", "an", "boolean")],
        methods=[m("+", "schalte()"), m("+", "istAn()", "boolean")]),
])

UML = [
    code("v-uml-30-5", "umlbasics", 3,
         "Setze den Kasten in Java um: Die Klasse Lampe hat ein privates Feld an (boolean) und die öffentliche Methode istAn(), die an zurückgibt.",
         "class Lampe {\n    // Feld und Methode hier\n}",
         """
         class Lampe {
             private boolean an;

             public boolean istAn() {
                 return an;
             }
         }
         """,
         [req(r"class\s+Lampe", "Schreibe die Klasse Lampe."),
          req(r"private\s+boolean\s+an", "Das Minus im Diagramm bedeutet private."),
          req(r"public\s+boolean\s+istAn\s*\(\s*\)", "istAn() ist öffentlich und liefert boolean."),
          req(r"return\s+an", "Gib das Feld an zurück.")],
         "Jede Zeile des Kastens wird zu einer Zeile Java: „- an: boolean“ wird private boolean an.",
         ctx="file",
         diagram=UML_KONTO2,
         verify={"context": "file", "main": "System.out.println(new Lampe().istAn());", "output": "false"},
         group="t30-5"),
    mc("v-uml-31-1", "umlrelations", 2, "Wohin zeigt die leere Dreiecksspitze immer?",
       ["Zur Eltern-Klasse beziehungsweise zum Interface",
        "Zur Kind-Klasse", "Zum größeren Kasten", "Zur Klasse mit den meisten Methoden"],
       "Die Spitze zeigt dorthin, wo geerbt wird – also nach oben zur Eltern-Klasse. In Java steht dort extends.",
       diagram=TIER_HUND,
       group="t31-1"),
    mc("v-uml-31-5", "umlrelations", 4, "Eine Klasse legt die andere nur kurz in einer Methode an. Welche Linie passt?",
       ["Abhängigkeit – gestrichelter Pfeil",
        "Komposition – gefüllte Raute",
        "Aggregation – leere Raute",
        "Vererbung – Dreiecksspitze"],
       "Wird die Klasse nur vorübergehend gebraucht (Parameter, lokale Variable), ist das eine Abhängigkeit.",
       group="t31-5"),
    mc("v-uml-32-1", "umlrelations", 1, "Welcher Java-Code passt zur gestrichelten Linie auf das «interface»?",
       ["class Auto implements Fahrbar { }",
        "class Auto extends Fahrbar { }",
        "class Fahrbar implements Auto { }",
        "interface Auto extends Fahrbar { }"],
       "Gestrichelt plus Dreiecksspitze auf ein Interface heißt implements – die Klasse erfüllt den Vertrag.",
       diagram=INTERFACE_DIAGRAM,
       group="t32-1"),
    mc("v-uml-32-2", "umlbasics", 2, "Welche UML-Zeile passt zu „private double stand;“?",
       ["- stand: double", "+ stand: double", "# stand: double", "- double: stand"],
       "private wird zum Minus, hinter dem Doppelpunkt steht der Typ – umgekehrt zur Schreibweise in Java.",
       diagram=KONTO,
       group="t32-2"),
    fill("v-uml-32-4", "umlrelations", 3, "Ergänze den Code zum Diagramm: Hund erbt von Tier.",
         """
         class Tier {
             public String laut() {
                 return "...";
             }
         }

         class Hund {{0}} Tier {
             @Override
             public String laut() {
                 return "Wau";
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Hund().laut());
             }
         }
         """,
         [["extends"]],
         "Der Pfeil mit leerer Dreiecksspitze auf eine Klasse heißt extends – bei einem Interface wäre es implements.",
         ctx="file",
         diagram=TIER_HUND,
         verify={"context": "file", "output": "Wau"},
         group="t32-4"),
    code("v-uml-32-5", "umlrelations", 4,
         "Setze das Diagramm um: Auto setzt Fahrbar um und gibt bei fahren() den Text „faehrt“ aus.",
         """
         interface Fahrbar {
             void fahren();
         }

         // Klasse Auto hier
         """,
         """
         interface Fahrbar {
             void fahren();
         }

         class Auto implements Fahrbar {
             public void fahren() {
                 System.out.println("faehrt");
             }
         }
         """,
         [req(r"class\s+Auto\s+implements\s+Fahrbar", "Die gestrichelte Linie bedeutet implements."),
          req(r"public\s+void\s+fahren\s*\(\s*\)", "Setze die Methode fahren() um."),
          req(r'"faehrt"', "Gib „faehrt“ aus.", scope="raw")],
         "Wer einen Vertrag unterschreibt, muss alle verlangten Methoden liefern – sonst übersetzt Java die Klasse gar nicht erst.",
         ctx="file",
         diagram=INTERFACE_DIAGRAM,
         verify={"context": "file", "main": "new Auto().fahren();", "output": "faehrt"},
         group="t32-5"),
]

POOL_GAPS = BASICS + IO_TOOLS + CONCURRENCY + PATTERNS + STREAMS + GRADES + TODO + ADVENTURE + UML
