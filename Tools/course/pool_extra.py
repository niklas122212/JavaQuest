"""Übungspool, Teil 6: gleichmäßige Tiefe für alle Themen.

Hebt die verbliebenen dünnen Themen auf ein vergleichbares Niveau – Generics,
Datum, Testen, Werkzeuge, Vererbung, modernes Java, Enums, equals, Texte,
Rekursion, Sortieren und Pattern Matching.
"""
from authoring import code, fill, forbid, mc, out, req

GENERICS = [
    out("u-gen-1", "generics", 3, "Was wird ausgegeben?",
        """
        Map<String, List<String>> regale = new HashMap<>();
        regale.put("Obst", List.of("Apfel", "Birne"));
        System.out.println(regale.get("Obst").size());
        """,
        "2",
        "Auch verschachtelte Etiketten sind erlaubt: Zu jedem Schlüssel gehört hier eine ganze Liste.",
        group="t11-2"),
    mc("u-gen-2", "generics", 2, "Welche Schreibweise legt eine Liste nur für Zahlen an?",
       ["List<Integer> zahlen = new ArrayList<>();",
        "List<int> zahlen = new ArrayList<>();",
        "List zahlen = new ArrayList<int>();",
        "ArrayList<> zahlen = new List<Integer>();"],
       "In die spitzen Klammern dürfen nur Klassen – deshalb Integer statt int. Rechts reichen die leeren Klammern.",
       group="t11-2"),
    fill("u-gen-3", "generics", 3, "Ergänze das Etikett, damit nur Texte in die Liste dürfen.",
         """
         List<{{0}}> namen = new ArrayList<>();
         namen.add("Ada");
         System.out.println(namen.get(0));
         """,
         [["String"]],
         "Das Etikett in den spitzen Klammern legt fest, was hinein darf – hier Texte.",
         verify={"output": "Ada"},
         group="t11-2"),
    code("u-gen-4", "generics", 5, "Schreibe die generische Methode anzahl, die zählt, wie viele Elemente eine Liste hat.",
         "// Deine generische Methode hier",
         """
         static <T> int anzahl(List<T> liste) {
             return liste.size();
         }
         """,
         [req(r"<T>", "Nutze den Platzhalter <T>."),
          req(r"int\s+anzahl\s*\(\s*List<T>", "Die Methode heißt anzahl und nimmt eine List<T>."),
          req(r"\.size\(\)", "Nutze size().")],
         "Der Platzhalter macht die Methode für jede Sorte nutzbar – gezählt wird immer gleich.",
         ctx="members",
         verify={"context": "members", "main": 'System.out.println(anzahl(List.of("a", "b", "c")));', "output": "3"},
         group="t11-5"),
]

DATETIME = [
    mc("u-dat-1", "datetime", 2, "Was speichert ein LocalDate?",
       ["Ein Kalenderdatum ohne Uhrzeit", "Datum und Uhrzeit",
        "Nur die Uhrzeit", "Die Zeit seit 1970 in Millisekunden"],
       "LocalDate ist reiner Kalender: Jahr, Monat, Tag. Für die Uhrzeit gibt es LocalTime.",
       group="t17-2"),
    out("u-dat-2", "datetime", 3, "Was wird ausgegeben?",
        """
        LocalDate tag = LocalDate.of(2026, 2, 28);
        System.out.println(tag.plusDays(2));
        """,
        "2026-03-02",
        "2026 ist kein Schaltjahr: Auf den 28. Februar folgt direkt der 1. März, zwei Tage später also der 2.",
        group="t17-2"),
    fill("u-dat-3", "datetime", 3, "Ergänze die Methode, die 7 Tage dazuzählt.",
         """
         LocalDate heute = LocalDate.of(2026, 6, 1);
         System.out.println(heute.{{0}}(7));
         """,
         [["plusDays"]],
         "plusDays rechnet Tage dazu und kümmert sich selbst um Monats- und Jahreswechsel.",
         verify={"output": "2026-06-08"},
         group="t17-2"),
]

TESTING = [
    fill("u-test-1", "testing", 3, "Ergänze die Prüfung: Erwartet wird 12, geliefert wird summe.",
         """
         static void pruefe(String name, int erwartet, int erhalten) {
             if (erwartet == erhalten) {
                 System.out.println("OK: " + name);
             } else {
                 System.out.println("FEHLER: " + name);
             }
         }

         public static void main(String[] args) {
             int summe = 5 + 7;
             pruefe("summe", {{0}}, summe);
         }
         """,
         [["12"]],
         "Erst der erwartete Wert, dann das tatsächliche Ergebnis – in dieser Reihenfolge liest sich die Meldung richtig.",
         ctx="members",
         verify={"context": "members", "output": "OK: summe"},
         group="t21-2"),
    mc("u-test-2", "testing", 3, "Warum testet man auch den Fall „leere Liste“?",
       ["Randfälle decken Fehler auf, die im Normalfall nicht auffallen",
        "Leere Listen kommen am häufigsten vor",
        "Damit der Test länger wird",
        "Weil Java das verlangt"],
       "Die meisten Fehler sitzen an den Rändern: leer, null, 0, negativ. Der Normalfall läuft oft schon.",
       group="t21-1"),
    code("u-test-3", "testing", 4, "Prüfe mit pruefe(…), dass die Methode laenge für „Java“ den Wert 4 liefert.",
         """
         static int laenge(String text) {
             return text.length();
         }

         static void pruefe(String name, int erwartet, int erhalten) {
             if (erwartet == erhalten) {
                 System.out.println("OK: " + name);
             } else {
                 System.out.println("FEHLER: " + name);
             }
         }

         public static void main(String[] args) {
             // Deine Prüfung hier
         }
         """,
         """
         static int laenge(String text) {
             return text.length();
         }

         static void pruefe(String name, int erwartet, int erhalten) {
             if (erwartet == erhalten) {
                 System.out.println("OK: " + name);
             } else {
                 System.out.println("FEHLER: " + name);
             }
         }

         public static void main(String[] args) {
             pruefe("laenge(Java)", 4, laenge("Java"));
         }
         """,
         [req(r"pruefe\s*\(", "Rufe pruefe(…) auf."),
          req(r"laenge\s*\(", "Rufe die zu prüfende Methode auf."),
          req(r"\b4\b", "Der erwartete Wert ist 4.")],
         "Ein Test vergleicht immer erwartet mit tatsächlich – hier 4 mit dem Ergebnis von laenge(\"Java\").",
         ctx="members",
         expected="OK: laenge(Java)",
         group="t21-5"),
]

TOOLING = [
    mc("u-tool-1", "tooling", 2, "Warum sieht ein Paketname oft aus wie eine umgedrehte Internetadresse?",
       ["Damit er weltweit eindeutig bleibt", "Weil Java das erzwingt",
        "Damit das Programm schneller lädt", "Damit man die Datei leichter findet"],
       "de.schule.mathe gehört zur Domain schule.de. So kollidieren Pakete verschiedener Anbieter nicht.",
       group="t22-1"),
    out("u-tool-2", "tooling", 3, "Was wird ausgegeben?",
        """
        List<String> liste = new ArrayList<>();
        try {
            System.out.println(liste.get(0));
        } catch (IndexOutOfBoundsException e) {
            System.out.println("Liste ist leer");
        }
        """,
        "Liste ist leer",
        "In der leeren Liste gibt es kein Fach 0. Der Alarm nennt genau das – das Netz fängt ihn auf.",
        group="t22-3"),
    out("u-tool-3", "tooling", 4, "Der Code soll jeden zweiten Buchstaben ausgeben, liefert aber zu viel. Was kommt heraus?",
        """
        String wort = "Java";
        for (int i = 0; i < wort.length(); i++) {
            System.out.print(wort.charAt(i));
        }
        """,
        "Java",
        "Der Schritt i++ geht jede Stelle durch. Für jeden zweiten Buchstaben müsste dort i += 2 stehen.",
        group="t22-5"),
]

INHERITANCE = [
    out("u-inh-1", "inheritance", 3, "Was wird ausgegeben?",
        """
        interface Zahlbar {
            double betrag();
        }

        class Rechnung implements Zahlbar {
            public double betrag() {
                return 19.99;
            }
        }

        public class Main {
            public static void main(String[] args) {
                Zahlbar z = new Rechnung();
                System.out.println(z.betrag());
            }
        }
        """,
        "19.99",
        "Auf dem Etikett steht der Vertrag (Zahlbar), drin liegt eine Rechnung – aufgerufen wird ihre Methode.",
        ctx="file",
        group="t09-4"),
    mc("u-inh-2", "inheritance", 3, "Was passiert, wenn eine Klasse ein Interface umsetzt, aber eine Methode vergisst?",
       ["Der Compiler meldet einen Fehler",
        "Die Methode wird automatisch ergänzt",
        "Sie gibt beim Aufruf null zurück",
        "Das Programm startet, stürzt aber ab"],
       "Ein Vertrag gilt vollständig: Fehlt eine verlangte Methode, lässt Java die Klasse gar nicht erst übersetzen.",
       group="t09-4"),
    fill("u-inh-3", "inheritance", 4, "Ergänze den Aufruf des Eltern-Konstruktors.",
         """
         class Tier {
             String name;

             Tier(String name) {
                 this.name = name;
             }
         }

         class Hund extends Tier {
             Hund(String name) {
                 {{0}}(name);
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Hund("Rex").name);
             }
         }
         """,
         [["super"]],
         "super(…) reicht die Startwerte an die Eltern-Klasse weiter, bevor die Kind-Klasse weitermacht.",
         ctx="file",
         verify={"context": "file", "output": "Rex"},
         group="t09-5"),
]

MODERN = [
    out("u-mod-1", "modern", 3, "Was wird ausgegeben?",
        """
        record Person(String name, int alter) {}

        public class Main {
            public static void main(String[] args) {
                Person p = new Person("Ada", 36);
                System.out.println(p.name() + " ist " + p.alter());
            }
        }
        """,
        "Ada ist 36",
        "Der Record erzeugt zu jedem Feld eine Lesemethode – p.name() und p.alter().",
        ctx="file",
        group="t13-1"),
    out("u-mod-2", "modern", 4, "Was wird ausgegeben?",
        """
        Optional<String> leer = Optional.empty();
        System.out.println(leer.isPresent());
        System.out.println(leer.orElse("nichts da"));
        """,
        """
        false
        nichts da
        """,
        "isPresent fragt, ob etwas in der Schachtel liegt. orElse liefert den Ersatz, wenn sie leer ist.",
        group="t13-3"),
    mc("u-mod-3", "modern", 3, "Warum haben Records keine Setter?",
       ["Ein Record ist unveränderlich – die Werte stehen nach dem Erzeugen fest",
        "Setter sind in Java abgeschafft",
        "Records haben keine Felder",
        "Setter müsste man selbst schreiben, sie fehlen nur zufällig"],
       "Ein Record ist wie ein ausgefülltes Formular: Wer etwas ändern will, füllt ein neues aus.",
       group="t13-1"),
]

ENUMS = [
    fill("u-enum-1", "enums", 3, "Ergänze den switch über das enum.",
         """
         enum Wetter { SONNE, REGEN }

         public class Main {
             public static void main(String[] args) {
                 Wetter heute = Wetter.REGEN;
                 String tipp = {{0}} (heute) {
                     case SONNE -> "Sonnenbrille";
                     case REGEN -> "Schirm";
                 };
                 System.out.println(tipp);
             }
         }
         """,
         [["switch"]],
         "Beim enum kennt Java alle Fälle – deshalb braucht dieser switch keinen default-Zweig.",
         ctx="file",
         verify={"context": "file", "output": "Schirm"},
         group="t14-3"),
    out("u-enum-2", "enums", 3, "Was wird ausgegeben?",
        """
        enum Stufe { LEICHT, MITTEL, SCHWER }

        public class Main {
            public static void main(String[] args) {
                System.out.println(Stufe.values().length);
                System.out.println(Stufe.SCHWER.ordinal());
            }
        }
        """,
        """
        3
        2
        """,
        "values() liefert alle Werte – hier drei. ordinal() zählt ab 0, SCHWER steht an dritter Stelle.",
        ctx="file",
        group="t14-5"),
    mc("u-enum-3", "enums", 4, "Wann lohnt sich ein static-Feld?",
       ["Wenn sich alle Objekte denselben Wert teilen sollen",
        "Wenn jedes Objekt einen eigenen Wert braucht",
        "Wenn der Wert sich nie ändern darf",
        "Wenn das Feld privat sein soll"],
       "static gehört der Kuchenform selbst – etwa ein Zähler, der über alle Objekte hinweg mitläuft.",
       group="t14-4"),
]

OBJECT_METHODS = [
    out("u-obj-1", "objectmethods", 4, "Was wird ausgegeben?",
        """
        abstract class Form {
            abstract double flaeche();

            @Override
            public String toString() {
                return "Flaeche: " + flaeche();
            }
        }

        class Quadrat extends Form {
            private double seite = 4;

            @Override
            double flaeche() {
                return seite * seite;
            }
        }

        public class Main {
            public static void main(String[] args) {
                System.out.println(new Quadrat());
            }
        }
        """,
        "Flaeche: 16.0",
        "Die abstrakte Klasse liefert schon toString, die Kind-Klasse ergänzt nur die fehlende Rechnung.",
        ctx="file",
        group="t15-4"),
    mc("u-obj-2", "objectmethods", 3, "Was liefert == bei zwei Objekten mit gleichem Inhalt?",
       ["false, solange es zwei verschiedene Objekte sind",
        "Immer true", "Immer false", "Das hängt vom Typ ab"],
       "== fragt: derselbe Kuchen? Zwei getrennt gebackene Kuchen sind nie derselbe – dafür gibt es equals.",
       group="t15-2"),
]

IO = [
    out("u-io-1", "io", 3, "Was wird ausgegeben?",
        """
        StringBuilder sb = new StringBuilder();
        for (int i = 1; i <= 3; i++) {
            sb.append(i);
        }
        System.out.println(sb.toString());
        """,
        "123",
        "Der Notizblock sammelt in der Schleife alles ein – erst am Ende wird daraus ein Text.",
        group="t16-5"),
    fill("u-io-2", "io", 3, "Ergänze die Methode, die etwas an den Notizblock hängt.",
         """
         StringBuilder sb = new StringBuilder("Java");
         sb.{{0}}("Quest");
         System.out.println(sb);
         """,
         [["append"]],
         "append hängt hinten an, ohne jedes Mal einen neuen Text zu erzeugen – das ist der Vorteil gegenüber +.",
         verify={"output": "JavaQuest"},
         group="t16-1"),
    out("u-io-3", "io", 4, "Was wird ausgegeben?",
        """
        Scanner scanner = new Scanner("7 3");
        int a = scanner.nextInt();
        int b = scanner.nextInt();
        System.out.println(a - b);
        """,
        "4",
        "nextInt() liest die nächste Zahl im Text. Zwei Aufrufe holen 7 und 3 – die Differenz ist 4.",
        group="t16-3"),
]

RECURSION = [
    out("u-rec-1", "recursion", 4, "Was wird ausgegeben?",
        """
        static int fib(int n) {
            if (n <= 1) {
                return n;
            }
            return fib(n - 1) + fib(n - 2);
        }

        public static void main(String[] args) {
            System.out.println(fib(7));
        }
        """,
        "13",
        "Die Folge lautet 0, 1, 1, 2, 3, 5, 8, 13 – an Position 7 steht die 13.",
        ctx="members",
        group="t18-3"),
    fill("u-rec-2", "recursion", 4, "Ergänze den rekursiven Aufruf für die Potenz.",
         """
         static int potenz(int basis, int exponent) {
             if (exponent == 0) {
                 return 1;
             }
             return basis * {{0}}(basis, exponent - 1);
         }

         public static void main(String[] args) {
             System.out.println(potenz(2, 5));
         }
         """,
         [["potenz"]],
         "Die Methode ruft sich selbst mit einem kleineren Exponenten auf: 2⁵ = 32.",
         ctx="members",
         verify={"context": "members", "output": "32"},
         group="t18-4"),
]

ALGORITHMS = [
    out("u-alg-1", "algorithms", 4, "Was wird ausgegeben?",
        """
        int[] zahlen = {1, 4, 7, 9};
        int ziel = 7;
        int links = 0;
        int rechts = zahlen.length - 1;
        int schritte = 0;
        while (links <= rechts) {
            int mitte = (links + rechts) / 2;
            schritte++;
            if (zahlen[mitte] == ziel) {
                break;
            } else if (zahlen[mitte] < ziel) {
                links = mitte + 1;
            } else {
                rechts = mitte - 1;
            }
        }
        System.out.println(schritte);
        """,
        "2",
        "Erster Blick in die Mitte (Fach 1, Wert 4) – zu klein. Zweiter Blick trifft die 7. Zwei Schritte genügen.",
        group="t19-1"),
    code("u-alg-2", "algorithms", 4, "Sortiere die Namen alphabetisch und gib die Liste aus.",
         """
         List<String> namen = new ArrayList<>(List.of("Mia", "Ada", "Zoe"));
         // Sortieren und ausgeben
         """,
         """
         List<String> namen = new ArrayList<>(List.of("Mia", "Ada", "Zoe"));
         namen.sort(Comparator.naturalOrder());
         System.out.println(namen);
         """,
         [req(r"\.sort\(", "Nutze sort."),
          req(r"System\.out\.println", "Gib die Liste aus.")],
         "naturalOrder sortiert Texte alphabetisch. Für eigene Regeln nimmt man Comparator.comparing.",
         expected="[Ada, Mia, Zoe]",
         group="t19-5"),
]

PATTERNS = [
    fill("u-pat-1", "patterns", 4, "Ergänze die Schlüsselwörter für die geschlossene Familie.",
         """
         {{0}} interface Getraenk {{1}} Tee, Saft {}
         record Tee(String sorte) implements Getraenk {}
         record Saft(String frucht) implements Getraenk {}

         public class Main {
             public static void main(String[] args) {
                 Getraenk g = new Tee("Pfefferminz");
                 String text = switch (g) {
                     case Tee t -> t.sorte() + "-Tee";
                     case Saft s -> s.frucht() + "-Saft";
                 };
                 System.out.println(text);
             }
         }
         """,
         [["sealed"], ["permits"]],
         "sealed schließt die Familie, permits zählt die erlaubten Mitglieder auf – dadurch deckt der switch alles ab.",
         ctx="file",
         verify={"context": "file", "output": "Pfefferminz-Tee"},
         group="t25-4"),
    out("u-pat-2", "patterns", 4, "Was wird ausgegeben?",
        """
        Object o = 7;
        String text = switch (o) {
            case Integer i when i > 10 -> "grosse Zahl";
            case Integer i -> "kleine Zahl " + i;
            default -> "keine Zahl";
        };
        System.out.println(text);
        """,
        "kleine Zahl 7",
        "Der erste Fall verlangt zusätzlich i > 10. Für die 7 greift deshalb der zweite Fall.",
        group="t25-3"),
]

POOL_EXTRA = (
    GENERICS + DATETIME + TESTING + TOOLING + INHERITANCE + MODERN
    + ENUMS + OBJECT_METHODS + IO + RECURSION + ALGORITHMS + PATTERNS
)
