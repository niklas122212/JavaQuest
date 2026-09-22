"""Übungspool, Teil 9: Abwechslung bei den Aufgabentypen.

An 38 Stellen bestand eine Schwierigkeitsstufe eines Themas aus einem einzigen
Aufgabentyp – „Bedingungen Stufe 1“ etwa aus viermal Ankreuzen, „Arrays Stufe 2“ aus
fünfmal „Was gibt das aus?“. Wer dort übte, trainierte immer dieselbe Fähigkeit.

Ankreuzen prüft Wiedererkennen, eine Ausgabe vorherzusagen prüft Nachvollziehen,
ein Lückentext prüft Zielgenauigkeit und selbst schreiben prüft Können. Jede Stufe
bekommt deshalb hier mindestens einen zweiten Typ dazu.
"""
from authoring import code, fill, forbid, mc, out, req
from uml_content import PERSON, TIER_HUND

# ---------------------------------------------------------------- Grundlagen
GRUNDLAGEN = [
    out("y-syn-1", "syntax", 1, "Was gibt dieses Programm aus?",
        """
        public class Main {
            public static void main(String[] args) {
                System.out.println("Start");
            }
        }
        """,
        "Start",
        "Java sucht beim Start die Methode main und führt deren Zeilen von oben nach unten aus. "
        "Die Klasse drumherum ist nur die Hülle – sie tut von sich aus nichts.",
        ctx="file",
        group="t01-1"),
    fill("y-str-2", "strings", 2, "Ergänze die Methode, die das erste Zeichen liefert.",
         """
         String wort = "Kaffee";
         System.out.println(wort.{{0}}(0));
         """,
         [["charAt"]],
         "charAt holt ein einzelnes Zeichen – gezählt ab 0, genau wie beim Array. Zurück kommt ein char "
         "und kein String: Für ein einzelnes Zeichen nimmt Java den kleineren Typ.",
         hint="„Zeichen an“ – auf Englisch, mit der Position in Klammern.",
         verify={"output": "K"},
         group="t07-2"),
    fill("y-arr-2", "arrays", 2, "Ergänze den Index, damit die letzte Zahl ausgegeben wird.",
         """
         int[] zahlen = {4, 8, 15};
         System.out.println(zahlen[{{0}}]);
         """,
         [["2", "zahlen.length - 1"]],
         "Drei Fächer werden ab 0 gezählt, das letzte trägt also die Nummer 2. Allgemein ist es "
         "length - 1 – diese Schreibweise bleibt auch dann richtig, wenn sich die Zahl der Fächer ändert.",
         hint="Gezählt wird ab 0, nicht ab 1.",
         verify={"output": "15"},
         group="t07-1"),
    out("y-cond-1", "conditionals", 1, "Was wird ausgegeben?",
        """
        int punkte = 10;
        if (punkte > 5) {
            System.out.println("geschafft");
        }
        """,
        "geschafft",
        "Die Bedingung in den Klammern ergibt true, also läuft der Block. Wäre sie false, würde der Block "
        "einfach übersprungen – ein if ohne else ist eine Abzweigung, die man auch auslassen kann.",
        group="t04-1"),
    out("y-meth-1", "methods", 1, "Was gibt das Programm aus?",
        """
        static void gruessen() {
            System.out.println("Hallo");
        }

        public static void main(String[] args) {
            gruessen();
            gruessen();
        }
        """,
        """
        Hallo
        Hallo
        """,
        "Eine void-Methode liefert nichts zurück, tut aber sehr wohl etwas. Genau darin liegt ihr Sinn: "
        "Man schreibt die Anweisungen einmal auf und ruft sie beliebig oft auf.",
        ctx="members",
        group="t06-1"),
]

# ---------------------------------------------------------------- Objekte und Vererbung
OBJEKTE = [
    out("y-oop-1", "oop", 1, "Was gibt das Programm aus?",
        """
        class Hund {
            String name = "Bello";
        }

        public class Main {
            public static void main(String[] args) {
                Hund h = new Hund();
                System.out.println(h.name);
            }
        }
        """,
        "Bello",
        "new legt ein Objekt nach dem Bauplan der Klasse an und füllt dabei die Felder mit ihren "
        "Startwerten. Über den Punkt kommt man anschließend an jedes einzelne Feld heran.",
        ctx="file",
        group="t08-1"),
    fill("y-oop-2", "oop", 2, "Ergänze das Schlüsselwort, das ein neues Objekt erzeugt.",
         """
         class Katze {
             String laut = "Miau";
         }

         public class Main {
             public static void main(String[] args) {
                 Katze k = {{0}} Katze();
                 System.out.println(k.laut);
             }
         }
         """,
         [["new"]],
         "Ohne new wäre Katze() für Java ein Methodenaufruf – und eine Methode dieses Namens gibt es "
         "nicht. Erst new besorgt Platz im Speicher und ruft dann den Konstruktor auf.",
         hint="Englisch für „neu“.",
         ctx="file",
         verify={"context": "file", "output": "Miau"},
         group="t08-1"),
    fill("y-oop-5", "oop", 5, "Ergänze die Kapselung: Das Feld ist privat, der Setter weist Negatives ab.",
         """
         class Vorrat {
             {{0}} int menge;

             void setzeMenge(int neu) {
                 if (neu {{1}} 0) {
                     menge = neu;
                 }
             }

             int getMenge() {
                 return menge;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 Vorrat v = new Vorrat();
                 v.setzeMenge(7);
                 v.setzeMenge(-3);
                 System.out.println(v.getMenge());
             }
         }
         """,
         [["private"], [">=", ">"]],
         "Genau dafür sind private Felder da: Weil von außen niemand direkt schreiben kann, bestimmt die "
         "Klasse selbst, welche Werte erlaubt sind. Die -3 wird abgewiesen, die 7 bleibt stehen.",
         hint="Erst das Wort, das das Feld verschließt, dann der Vergleich, der Negatives aussortiert.",
         ctx="file",
         verify={"context": "file", "output": "7"},
         group="t08-5"),
    out("y-inh-2", "inheritance", 2, "Was gibt das Programm aus?",
        """
        class Fahrzeug {
            void fahren() {
                System.out.println("faehrt");
            }
        }

        class Auto extends Fahrzeug {
            void hupen() {
                System.out.println("hupt");
            }
        }

        public class Main {
            public static void main(String[] args) {
                Auto a = new Auto();
                a.fahren();
                a.hupen();
            }
        }
        """,
        """
        faehrt
        hupt
        """,
        "Auto hat fahren() nicht selbst geschrieben – es erbt die Methode von Fahrzeug. Genau das erspart "
        "Vererbung: Was schon einmal dasteht, muss die Kind-Klasse nicht wiederholen, sie ergänzt nur Neues.",
        ctx="file",
        group="t09-1"),
    fill("y-obj-5", "objectmethods", 5, "Ergänze toString und equals, damit beide Ausgaben stimmen.",
         """
         class Punkt {
             int x = 2;
             int y = 3;

             @Override
             public String {{0}}() {
                 return "(" + x + "|" + y + ")";
             }

             @Override
             public boolean equals(Object o) {
                 if (!(o {{1}} Punkt p)) {
                     return false;
                 }
                 return x == p.x && y == p.y;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Punkt());
                 System.out.println(new Punkt().equals(new Punkt()));
             }
         }
         """,
         [["toString"], ["instanceof"]],
         "println fragt jedes Objekt nach toString. equals bekommt dagegen ein Object und muss deshalb "
         "erst prüfen, womit es überhaupt verglichen wird – instanceof erledigt Prüfung und Umwandlung "
         "in einem Schritt und schützt so vor einem Absturz.",
         hint="Erst die Methode, die println aufruft, dann das Wort, das Typ prüft und zugleich umwandelt.",
         ctx="file",
         verify={"context": "file", "output": "(2|3)\ntrue"},
         group="t15-5"),
]

# ---------------------------------------------------------------- Robuster Code und Sammlungen
ROBUST = [
    out("y-exc-1", "exceptions", 1, "Was wird ausgegeben?",
        """
        try {
            System.out.println("Anfang");
            int x = 5 / 0;
            System.out.println("Mitte");
        } catch (ArithmeticException e) {
            System.out.println("Ende");
        }
        """,
        """
        Anfang
        Ende
        """,
        "Nach dem Fehler wird der Rest des try-Blocks übersprungen – „Mitte“ erscheint nie. Genau das "
        "ist der Sinn: Ab der Fehlerstelle ergäbe der restliche Ablauf ohnehin keinen Sinn mehr.",
        group="t10-1"),
    fill("y-exc-5", "exceptions", 5, "Ergänze: Bei leerem Namen wird ein Fehler ausgelöst und gleich wieder aufgefangen.",
         """
         static void pruefe(String name) {
             if (name.isEmpty()) {
                 {{0}} new IllegalArgumentException("Name fehlt");
             }
             System.out.println("ok: " + name);
         }

         public static void main(String[] args) {
             pruefe("Ada");
             try {
                 pruefe("");
             } {{1}} (IllegalArgumentException e) {
                 System.out.println("Fehler: " + e.getMessage());
             }
         }
         """,
         [["throw"], ["catch"]],
         "Auslösen und Auffangen sind zwei getrennte Rollen: throw meldet das Problem dort, wo es auffällt, "
         "catch entscheidet an ganz anderer Stelle, was damit geschehen soll. Dadurch muss die prüfende "
         "Methode nicht wissen, wie das Programm reagieren möchte.",
         hint="Erst das Wort fürs Werfen, dann der Block, der auffängt.",
         ctx="members",
         verify={"context": "members", "output": "ok: Ada\nFehler: Name fehlt"},
         group="t10-5"),
    out("y-col-1", "collections", 1, "Was gibt das Programm aus?",
        """
        List<String> namen = new ArrayList<>();
        namen.add("Ada");
        namen.add("Grace");
        System.out.println(namen.size());
        """,
        "2",
        "Eine Liste muss ihre Größe nicht vorher kennen: add hängt hinten an, und sie besorgt sich bei "
        "Bedarf selbst mehr Platz. Genau darin unterscheidet sie sich vom Array mit fester Länge.",
        group="t11-1"),
    out("y-gen-5", "generics", 5, "Was gibt das Programm aus?",
        """
        Map<String, List<String>> regale = new HashMap<>();
        regale.put("Obst", new ArrayList<>(List.of("Apfel")));
        regale.get("Obst").add("Birne");
        System.out.println(regale.get("Obst").size());
        System.out.println(regale);
        """,
        """
        2
        {Obst=[Apfel, Birne]}
        """,
        "Der Wert einer Map darf selbst wieder ein Typ mit spitzen Klammern sein. get liefert dabei die "
        "Liste selbst zurück, keine Kopie – wer darauf add aufruft, verändert den Eintrag in der Map. "
        "Nötig ist dafür eine veränderliche Liste: Bei List.of käme eine Fehlermeldung.",
        group="t11-2"),
    fill("y-ds-2", "datastructures", 2, "Ergänze die Sammlung, die jeden Wert nur einmal behält.",
         """
         {{0}}<String> farben = new HashSet<>();
         farben.add("rot");
         farben.add("rot");
         System.out.println(farben.size());
         """,
         [["Set"]],
         "Eine Menge kennt jeden Wert genau einmal – das zweite add verpufft wirkungslos. Deshalb "
         "beantwortet ein Set die Frage „wie viele verschiedene?“ ohne einen einzigen Vergleich.",
         hint="Das englische Wort für Menge.",
         verify={"output": "1"},
         group="t20-2"),
    out("y-ds-1", "datastructures", 1, "Was gibt das Programm aus?",
        """
        Deque<String> stapel = new ArrayDeque<>();
        stapel.push("unten");
        stapel.push("oben");
        System.out.println(stapel.pop());
        """,
        "oben",
        "Beim Stapel wird immer am selben Ende gearbeitet: push legt oben drauf, pop nimmt oben weg. "
        "Deshalb kommt zuerst herunter, was zuletzt drauflag – die Reihenfolge, die „Rückgängig“ braucht.",
        group="t20-1"),
    fill("y-ds-5", "datastructures", 5, "Ergänze beide Methoden: hinten anstellen, vorne abholen.",
         """
         Deque<String> schlange = new ArrayDeque<>();
         schlange.{{0}}("Ada");
         schlange.{{0}}("Grace");
         schlange.{{0}}("Linus");
         System.out.println(schlange.{{1}}());
         System.out.println(schlange.size());
         """,
         [["offer", "addLast"], ["poll", "pollFirst"]],
         "Eine ArrayDeque kann beides: Stapel und Warteschlange. Den Unterschied machen allein die "
         "Methoden – offer und poll arbeiten an entgegengesetzten Enden, push und pop am selben. "
         "Deshalb kommt hier Ada zuerst heraus, obwohl sie zuerst eingereiht wurde.",
         hint="Beides beginnt mit „o“ beziehungsweise „p“ – und arbeitet an verschiedenen Enden.",
         verify={"output": "Ada\n2"},
         group="t20-4"),
]

# ---------------------------------------------------------------- Modernes Java, Enums, Streams
MODERN = [
    fill("y-mod-2", "modern", 2, "Ergänze das Schlüsselwort für einen Datensatz mit festen Feldern.",
         """
         {{0}} Ort(String name, int plz) {}

         public class Main {
             public static void main(String[] args) {
                 Ort o = new Ort("Kiel", 24103);
                 System.out.println(o.name());
             }
         }
         """,
         [["record"]],
         "Aus dieser einen Zeile macht Java eine ganze Klasse: Konstruktor, Lesemethoden, equals, "
         "hashCode und toString. Setter fehlen mit Absicht – ein Record ist nach dem Erzeugen unveränderlich.",
         hint="Englisch für „Datensatz“.",
         ctx="file",
         verify={"context": "file", "output": "Kiel"},
         group="t13-1"),
    out("y-enum-5", "enums", 5, "Was gibt das Programm aus?",
        """
        enum Muenze {
            KLEIN(5), GROSS(50);

            private final int cent;

            Muenze(int cent) {
                this.cent = cent;
            }

            int getCent() {
                return cent;
            }

            static int gesamtwert() {
                int summe = 0;
                for (Muenze m : values()) {
                    summe += m.cent;
                }
                return summe;
            }
        }

        public class Main {
            public static void main(String[] args) {
                System.out.println(Muenze.GROSS.getCent());
                System.out.println(Muenze.gesamtwert());
            }
        }
        """,
        """
        50
        55
        """,
        "Jeder enum-Wert bringt sein eigenes Feld cent mit, die static-Methode gehört dagegen dem enum "
        "als Ganzem und kommt über values() an alle Werte heran. Achtung bei der Reihenfolge: Ein "
        "static-Feld darf der Konstruktor gar nicht anfassen – die Werte entstehen vor den statischen "
        "Feldern, deshalb lehnt der Compiler das ab.",
        ctx="file",
        group="t14-5"),
    out("y-lam-5", "lambdas", 5, "Was gibt das Programm aus?",
        """
        List<String> woerter = List.of("Java", "ist", "praezise");
        String satz = woerter.stream()
                             .filter(w -> w.length() > 3)
                             .map(String::toUpperCase)
                             .collect(Collectors.joining(", "));
        int buchstaben = woerter.stream().mapToInt(String::length).sum();
        System.out.println(satz);
        System.out.println(buchstaben);
        """,
        """
        JAVA, PRAEZISE
        15
        """,
        "Die Stationen arbeiten der Reihe nach: sieben, umformen, einsammeln. joining klebt die Ergebnisse "
        "mit dem angegebenen Trenner zusammen – ohne Trenner am Anfang oder Ende. Der zweite Strom läuft "
        "völlig getrennt und rechnet über alle Wörter, auch die aussortierten.",
        group="t12-5"),
    out("y-pat-5", "patterns", 5, "Was gibt das Programm aus?",
        """
        sealed interface Form permits Kreis, Rechteck {}

        record Kreis(double r) implements Form {}

        record Rechteck(double a, double b) implements Form {}

        public class Main {
            static String zeige(Form f) {
                return switch (f) {
                    case Rechteck(double a, double b) when a == b -> "Quadrat";
                    case Rechteck r -> "Rechteck";
                    case Kreis k -> "Kreis";
                };
            }

            public static void main(String[] args) {
                System.out.println(zeige(new Rechteck(3, 3)));
                System.out.println(zeige(new Rechteck(3, 4)));
                System.out.println(zeige(new Kreis(1)));
            }
        }
        """,
        """
        Quadrat
        Rechteck
        Kreis
        """,
        "Das Record-Muster packt die Felder aus und die when-Bedingung filtert zusätzlich. Die Reihenfolge "
        "entscheidet: Der engere Fall muss oben stehen, sonst fängt der allgemeinere ihn vorher ab. Weil "
        "Form sealed ist, prüft Java, dass kein Fall fehlt – ein default ist unnötig.",
        ctx="file",
        group="t25-5"),
]

# ---------------------------------------------------------------- Aufbauthemen
AUFBAU = [
    out("y-rec-1", "recursion", 1, "Was gibt das Programm aus?",
        """
        static void runter(int n) {
            if (n == 0) {
                return;
            }
            System.out.print(n + " ");
            runter(n - 1);
        }

        public static void main(String[] args) {
            runter(3);
        }
        """,
        "3 2 1",
        "Der Basisfall n == 0 beendet die Kette – ohne ihn liefe sie endlos weiter, bis das Programm "
        "abstürzt. Das leere return heißt nur „hier ist Schluss“; einen Wert liefert die Methode nicht.",
        ctx="members",
        group="t18-1"),
    fill("y-rec-3", "recursion", 3, "Ergänze Basisfall und Aufruf, damit summe(3) die 6 ergibt.",
         """
         static int summe(int n) {
             if (n == {{0}}) {
                 return 0;
             }
             return n + {{1}}(n - 1);
         }

         public static void main(String[] args) {
             System.out.println(summe(3));
         }
         """,
         [["0"], ["summe"]],
         "Der rekursive Aufruf muss das Problem kleiner machen – n - 1 nähert sich dem Basisfall. Stünde "
         "dort n, näherte sich nichts und die Kette risse nie ab. Gerechnet wird erst auf dem Rückweg: "
         "0, dann 1, dann 3, dann 6.",
         hint="Bei welcher Zahl ist Schluss – und wie heißt die Methode, die sich selbst aufruft?",
         ctx="members",
         verify={"context": "members", "output": "6"},
         group="t18-2"),
    out("y-rec-5", "recursion", 5, "Was gibt das Programm aus?",
        """
        static int ggt(int a, int b) {
            if (b == 0) {
                return a;
            }
            return ggt(b, a % b);
        }

        public static void main(String[] args) {
            System.out.println(ggt(48, 18));
        }
        """,
        "6",
        "Der größte gemeinsame Teiler entsteht durch wiederholtes Restrechnen: 48 % 18 ergibt 12, "
        "18 % 12 ergibt 6, 12 % 6 ergibt 0 – dann steht die Antwort im ersten Parameter. Weil der Rest "
        "immer kleiner wird, ist sicher, dass der Basisfall irgendwann erreicht wird.",
        ctx="members",
        group="t18-5"),
    out("y-alg-1", "algorithms", 1, "Was gibt das Programm aus?",
        """
        int[] zahlen = {5, 2, 9};
        Arrays.sort(zahlen);
        System.out.println(zahlen[0]);
        """,
        "2",
        "Arrays.sort ordnet an Ort und Stelle – das alte Array ist danach verändert, ein neues entsteht "
        "nicht. Deshalb liegt in Fach 0 nun die kleinste Zahl. Wer die ursprüngliche Reihenfolge noch "
        "braucht, muss vorher eine Kopie anlegen.",
        group="t19-1"),
    fill("y-alg-3", "algorithms", 3, "Ergänze beide Schritte: erst ordnen, dann gezielt suchen.",
         """
         int[] zahlen = {40, 10, 30};
         Arrays.{{0}}(zahlen);
         System.out.println(Arrays.{{1}}(zahlen, 30));
         """,
         [["sort"], ["binarySearch"]],
         "Die Reihenfolge ist zwingend: Die binäre Suche halbiert bei jedem Schritt und setzt dafür "
         "sortierte Daten voraus. Auf unsortierten Daten liefert sie irgendein Ergebnis, ohne eine "
         "Fehlermeldung – ein Fehler, der lange unentdeckt bleiben kann.",
         hint="Erst das englische Wort fürs Sortieren, dann das für die halbierende Suche.",
         verify={"output": "1"},
         group="t19-3"),
    out("y-alg-5", "algorithms", 5, "Was gibt das Programm aus?",
        """
        List<String> woerter = new ArrayList<>(List.of("Birne", "Ei", "Apfel", "Kiwi"));
        woerter.sort(Comparator.comparingInt(String::length).thenComparing(Comparator.naturalOrder()));
        System.out.println(woerter);
        """,
        "[Ei, Kiwi, Apfel, Birne]",
        "comparingInt ordnet nach Länge, thenComparing entscheidet bei Gleichstand – hier alphabetisch. "
        "Apfel und Birne sind beide fünf Zeichen lang, deshalb kommt der zweite Vergleich zum Zug. Ohne "
        "ihn bliebe die Reihenfolge der gleich langen Wörter dem Zufall des Ausgangszustands überlassen.",
        group="t19-4"),
    out("y-test-2", "testing", 2, "Was gibt das Programm aus?",
        """
        static void pruefe(String name, boolean bedingung) {
            System.out.println(name + ": " + (bedingung ? "ok" : "FEHLER"));
        }

        public static void main(String[] args) {
            pruefe("leerer Text", "".isEmpty());
            pruefe("Laenge", "Java".length() == 5);
        }
        """,
        """
        leerer Text: ok
        Laenge: FEHLER
        """,
        "Mehr braucht ein Test im Kern nicht: eine Bedingung, die stimmen soll, und eine Meldung, wenn "
        "sie nicht stimmt. Der Name ist dabei kein Schmuck – ohne ihn wüsste man bei „FEHLER“ nicht, "
        "welche der Prüfungen danebenlag.",
        ctx="members",
        group="t21-1"),
    out("y-io-1", "io", 1, "Was gibt das Programm aus?",
        """
        try {
            String text = Files.readString(Path.of("gibt-es-nicht.txt"));
            System.out.println(text);
        } catch (IOException e) {
            System.out.println("Datei nicht gefunden");
        }
        """,
        "Datei nicht gefunden",
        "Ob eine Datei existiert, weiß man erst beim Zugriff – deshalb ist IOException eine checked "
        "Exception, die Java einzuplanen verlangt. Ohne catch oder throws ließe sich der Code gar nicht "
        "erst übersetzen. Das Programm stürzt hier nicht ab, sondern meldet das Problem und läuft weiter.",
        group="t17-1"),
    out("y-dat-5", "datetime", 5, "Was gibt das Programm aus?",
        """
        LocalDate start = LocalDate.of(2026, 1, 31);
        LocalDate ende = start.plusMonths(1);
        Period p = Period.between(start, ende);
        System.out.println(ende);
        System.out.println(p.getMonths() + " " + p.getDays());
        """,
        """
        2026-02-28
        0 28
        """,
        "Der 31. Februar existiert nicht – plusMonths rückt deshalb auf den letzten gültigen Tag des "
        "Zielmonats. Genau deshalb sind die beiden Daten anschließend keinen vollen Monat auseinander, "
        "sondern 28 Tage. Solche Randfälle sind der Grund, Datumsrechnungen nie selbst zu programmieren.",
        group="t17-3"),
    out("y-tool-2", "tooling", 2, "Was gibt das Programm aus?",
        """
        int[] werte = {10, 0};
        for (int w : werte) {
            try {
                System.out.println(100 / w);
            } catch (ArithmeticException e) {
                System.out.println("uebersprungen");
            }
        }
        """,
        """
        10
        uebersprungen
        """,
        "Entscheidend ist, dass try und catch innerhalb der Schleife stehen: So betrifft ein Fehler nur "
        "die eine Runde und die übrigen Werte werden noch verarbeitet. Stünde das try außen herum, wäre "
        "nach der 0 Schluss.",
        group="t22-4"),
    fill("y-tool-1", "tooling", 1, "Ergänze das Schlüsselwort, das eine Klasse aus einem anderen Paket holt.",
         """
         {{0}} java.util.List;

         public class Main {
             public static void main(String[] args) {
                 List<String> namen = List.of("Ada");
                 System.out.println(namen.size());
             }
         }
         """,
         [["import"]],
         "Klassen liegen in Paketen – List wohnt in java.util. Ohne diese Zeile müsste man überall "
         "java.util.List ausschreiben. Sie lädt nichts herunter, sondern macht den kurzen Namen bekannt.",
         hint="Englisch für „einführen“.",
         ctx="file",
         verify={"context": "file", "output": "1"},
         group="t22-1"),
]

# ---------------------------------------------------------------- Projekte und UML
PROJEKTE_UML = [
    out("y-proj-1", "projects", 1, "Was gibt das Programm aus?",
        """
        int[] noten = {2, 1, 3};
        int summe = 0;
        for (int n : noten) {
            summe += n;
        }
        System.out.println(summe);
        """,
        "6",
        "Die Summe ist der erste Schritt zu jedem Durchschnitt. Wichtig ist der Zähler außerhalb der "
        "Schleife – innerhalb angelegt, begänne er in jeder Runde wieder bei 0.",
        group="t27-1"),
    fill("y-proj-3", "projects", 3, "Ergänze die Rechnung, damit der Schnitt 2.0 lautet.",
         """
         int[] noten = {1, 2, 3};
         int summe = 0;
         for (int n : noten) {
             summe += n;
         }
         double schnitt = {{0}} / noten.{{1}};
         System.out.println(schnitt);
         """,
         [["summe", "(double) summe"], ["length"]],
         "Hier lauert eine Falle: summe und length sind beide ganze Zahlen, also rechnet Java auch "
         "ganzzahlig – nur weil 6 / 3 glatt aufgeht, stimmt das Ergebnis. Bei 7 / 3 käme 2.0 statt 2.33 "
         "heraus. Sicher wird es erst mit (double) summe / noten.length.",
         hint="Was aufsummiert wurde, geteilt durch die Anzahl der Fächer.",
         verify={"output": "2.0"},
         group="t27-2"),
    fill("y-proj-5", "projects", 5, "Ergänze die Stationen: Durchschnitt und beste (kleinste) Note.",
         """
         int[] noten = {3, 1, 2};
         double schnitt = Arrays.stream(noten).{{0}}().orElse(0);
         int beste = Arrays.stream(noten).{{1}}().orElse(0);
         System.out.println(schnitt + " " + beste);
         """,
         [["average"], ["min"]],
         "Ein IntStream bringt beide Auswertungen schon mit – von Hand bräuchte es zwei Schleifen. Beide "
         "liefern ein Optional, weil es bei einem leeren Array kein Ergebnis gäbe; orElse legt für diesen "
         "Fall einen Ersatzwert fest.",
         hint="Das englische Wort für Durchschnitt – und das für das Minimum.",
         verify={"output": "2.0 1"},
         group="t27-4"),
    out("y-uml-31-1", "umlrelations", 1, "Was gibt der Code zum Diagramm aus?",
        """
        class Tier {
            String laut() {
                return "...";
            }
        }

        class Hund extends Tier {
            @Override
            String laut() {
                return "Wau";
            }

            void apportieren() {
                System.out.println("holt den Stock");
            }
        }

        public class Main {
            public static void main(String[] args) {
                Hund h = new Hund();
                System.out.println(h.laut());
                h.apportieren();
            }
        }
        """,
        """
        Wau
        holt den Stock
        """,
        "Der Pfeil mit der leeren Dreiecksspitze bedeutet extends: Hund ist ein Tier. Die Kind-Klasse "
        "darf geerbte Methoden ersetzen – deshalb kommt „Wau“ statt „...“ – und eigene ergänzen, die es "
        "bei der Eltern-Klasse gar nicht gibt.",
        ctx="file",
        diagram=TIER_HUND,
        group="t31-1"),
    fill("y-uml-30-3", "umlbasics", 2, "Ergänze den Methodenkopf passend zum Kasten.",
         """
         class Person {
             private String name = "Ada";
             private int alter = 36;

             public {{0}} getName() {
                 return name;
             }

             public void hatGeburtstag() {
                 alter{{1}};
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Person().getName());
             }
         }
         """,
         [["String"], ["++"]],
         "Im Kasten steht der Rückgabetyp hinter dem Doppelpunkt: „+ getName(): String“. In Java wandert "
         "er nach vorn. Bei hatGeburtstag() fehlt der Doppelpunkt ganz – die Methode gibt nichts zurück, "
         "sondern verändert nur den Zustand des Objekts.",
         hint="Was getName() laut Diagramm liefert – und der kürzeste Weg, das Alter um eins zu erhöhen.",
         ctx="file",
         diagram=PERSON,
         verify={"context": "file", "output": "Ada"},
         group="t30-3"),
    out("y-con-2", "concurrency", 2, "Was gibt das Programm aus?",
        """
        Thread arbeiter = new Thread(() -> System.out.println("fertig"));
        arbeiter.start();
        arbeiter.join();
        System.out.println("danach");
        """,
        """
        fertig
        danach
        """,
        "Ohne join wäre die Reihenfolge offen – das Hauptprogramm liefe weiter, während der Thread noch "
        "arbeitet. join hält an, bis er fertig ist, und macht die Ausgabe damit vorhersagbar. Genau "
        "deshalb braucht man es, bevor man ein Ergebnis weiterverwendet.",
        group="t23-1"),
]

# ---------------------------------------------------------------- Ausgleich: weniger „Was gibt das aus?“
# Sieben Themen bestanden zu über der Hälfte aus Ausgabe-Vorhersagen. Diese Aufgaben
# gleichen das aus – bewusst alle von einem anderen Typ.
AUSGLEICH = [
    fill("y-loop-1b", "loops", 1, "Ergänze die drei Teile, damit 1, 2, 3 erscheinen.",
         """
         for (int i = {{0}}; i {{1}} 3; i{{2}}) {
             System.out.println(i);
         }
         """,
         [["1"], ["<="], ["++"]],
         "Die drei Teile beantworten drei Fragen: Wo fängt es an, wie lange läuft es, was passiert nach "
         "jeder Runde. Mit < 3 wäre bei 2 Schluss, mit i-- liefe die Schleife endlos rückwärts.",
         hint="Startwert, Vergleich, Schritt – getrennt durch Semikolons.",
         verify={"output": "1\n2\n3"},
         group="t05-1"),
    fill("y-str-1b", "strings", 1, "Ergänze die Methode, die prüft, ob der Text gar keine Zeichen hat.",
         """
         String leer = "";
         System.out.println(leer.{{0}}());
         """,
         [["isEmpty"]],
         "isEmpty fragt, ob der Text null Zeichen lang ist. Für Texte, die nur aus Leerzeichen bestehen, "
         "gibt es isBlank – das liefert dort true, isEmpty dagegen false. Der Unterschied fällt erst auf, "
         "wenn jemand ein Eingabefeld mit einem Leerzeichen abschickt.",
         hint="„ist leer“ – auf Englisch, in einem Wort.",
         verify={"output": "true"},
         group="t07-2"),
    code("y-str-2b", "strings", 2,
         "Gib „Hallo Welt“ in Großbuchstaben aus.",
         """
         String satz = "Hallo Welt";
         // in Großbuchstaben ausgeben
         """,
         """
         String satz = "Hallo Welt";
         System.out.println(satz.toUpperCase());
         """,
         [req(r"toUpperCase\s*\(\s*\)", "Großbuchstaben liefert toUpperCase()."),
          req(r"System\.out\.println", "Gib das Ergebnis aus.")],
         "toUpperCase liefert einen neuen Text zurück und lässt satz unverändert – ein String ist in "
         "Java nicht veränderbar. Wer das Ergebnis behalten will, muss es auffangen oder direkt ausgeben.",
         expected="HALLO WELT",
         group="t07-2"),
    fill("y-str-5b", "strings", 5, "Ergänze die Prüfung, ob der Text mit „Java“ beginnt und auf „t“ endet.",
         """
         String wort = "JavaQuest";
         System.out.println(wort.{{0}}("Java") && wort.{{1}}("t"));
         """,
         [["startsWith"], ["endsWith"]],
         "Beide Methoden liefern true oder false und lassen sich deshalb direkt mit && verknüpfen. "
         "Praktisch nebenbei: Ist die linke Seite schon false, prüft Java die rechte gar nicht mehr.",
         hint="„beginnt mit“ und „endet mit“ – jeweils auf Englisch.",
         verify={"output": "true"},
         group="t07-4"),
    mc("y-col-1b", "collections", 1, "Was passiert bei liste.get(5), wenn die Liste nur drei Einträge hat?",
       ["Das Programm bricht mit einer IndexOutOfBoundsException ab",
        "Es kommt null zurück",
        "Die Liste wächst automatisch auf sechs Einträge",
        "Es kommt der letzte Eintrag zurück"],
       "Ein Zugriff daneben ist ein Fehler, kein Sonderfall – Java meldet ihn sofort, statt still etwas "
       "Falsches zu liefern. Das ist Absicht: Ein stilles null würde den eigentlichen Fehler nur "
       "verschleppen und später an ganz anderer Stelle auffallen.",
       why=[None,
            "null käme bei einer Map für einen unbekannten Schlüssel. Eine Liste kennt nur Positionen, "
            "und die 5 gibt es nicht.",
            "Wachsen tut eine Liste nur durch add – und dann hinten, nicht an beliebiger Stelle.",
            "Java rät nicht. Ein Index außerhalb ist ein Fehler, kein Näherungswert."],
       group="t11-1"),
    fill("y-col-2b", "collections", 2, "Ergänze die Methode, die prüft, ob ein Eintrag vorkommt.",
         """
         List<String> namen = new ArrayList<>(List.of("Ada", "Linus"));
         System.out.println(namen.{{0}}("Ada"));
         """,
         [["contains"]],
         "contains geht die Liste durch und vergleicht mit equals – bei Texten also den Inhalt. Bei "
         "eigenen Klassen funktioniert es nur richtig, wenn diese equals selbst sinnvoll umgesetzt haben.",
         hint="Englisch für „enthält“.",
         verify={"output": "true"},
         group="t11-3"),
    fill("y-col-5b", "collections", 5, "Ergänze das Zählen: Beim ersten Vorkommen steht noch nichts in der Map.",
         """
         int[] wuerfe = {3, 1, 3};
         Map<Integer, Integer> zaehler = new HashMap<>();
         for (int w : wuerfe) {
             zaehler.put(w, zaehler.{{0}}(w, {{1}}) + 1);
         }
         System.out.println(zaehler);
         """,
         [["getOrDefault"], ["0"]],
         "getOrDefault löst die heikle erste Runde: Für eine Zahl, die noch nicht in der Map steht, "
         "liefert es den Ersatzwert 0 – damit lässt sich sofort rechnen. Mit get käme null heraus und "
         "null + 1 würde abstürzen.",
         hint="Die Methode mit Ersatzwert – und als Ersatz die Zahl, bei der ein Zähler beginnt.",
         verify={"output": "{1=1, 3=2}"},
         group="t11-4"),
    fill("y-mod-1b", "modern", 1, "Ergänze das Schlüsselwort, mit dem Java den Typ selbst erkennt.",
         """
         {{0}} zahl = 42;
         System.out.println(zahl * 2);
         """,
         [["var"]],
         "var spart nur das Hinschreiben – den Typ liest Java aus dem Wert rechts ab und legt ihn "
         "endgültig fest. Die Box ist danach ein int und nimmt keinen Text mehr an. Ohne Startwert "
         "ginge es nicht: Dann hätte Java nichts, woraus es schließen könnte.",
         hint="Drei Buchstaben, kurz für „variabel“.",
         verify={"output": "84"},
         group="t13-1"),
    mc("y-mod-2b", "modern", 2, "Was ist der Unterschied zwischen switch als Anweisung und als Ausdruck?",
       ["Der Ausdruck liefert einen Wert, die Anweisung führt nur etwas aus",
        "Der Ausdruck ist nur kürzer, sonst gleich",
        "Die Anweisung kann kein default haben",
        "Der Ausdruck funktioniert nur mit Zahlen"],
       "Ein switch-Ausdruck steht rechts vom Gleichheitszeichen und muss deshalb für jeden Fall eine "
       "Antwort liefern – sonst wüsste Java nicht, was in die Variable soll. Genau deshalb prüft der "
       "Compiler dort die Vollständigkeit, bei der Anweisung nicht.",
       why=[None,
            "Der Unterschied ist grundlegend: Nur der Ausdruck lässt sich einer Variablen zuweisen.",
            "default darf in beiden stehen. Beim Ausdruck ist es sogar meist Pflicht.",
            "Beide arbeiten auch mit Text, enum-Werten und – beim Ausdruck – mit Typmustern."],
       group="t13-2"),
    fill("y-mod-5b", "modern", 5, "Ergänze das Pattern Matching: Text → Länge, Liste → Anzahl, sonst -1.",
         """
         static int laenge(Object o) {
             if (o {{0}} String s) {
                 return s.length();
             }
             if (o instanceof List<{{1}}> l) {
                 return l.size();
             }
             return -1;
         }

         public static void main(String[] args) {
             System.out.println(laenge("Hallo"));
             System.out.println(laenge(List.of(1, 2)));
             System.out.println(laenge(3.5));
         }
         """,
         [["instanceof"], ["?"]],
         "instanceof prüft den Typ und liefert in einem Zug die passend umgewandelte Variable – früher "
         "brauchte es dafür zwei Schritte. Das Fragezeichen heißt „Liste von irgendetwas“: Der "
         "Inhaltstyp ist hier egal, weil nur gezählt wird.",
         hint="Erst das Wort für die Typprüfung, dann das Zeichen für „irgendein Typ“.",
         ctx="members",
         verify={"context": "members", "output": "5\n2\n-1"},
         group="t13-5"),
    fill("y-enum-1b", "enums", 1, "Ergänze das Schlüsselwort für eine feste Auswahl an Werten.",
         """
         {{0}} Ampel { ROT, GELB, GRUEN }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(Ampel.ROT);
             }
         }
         """,
         [["enum"]],
         "Ein enum zählt alle erlaubten Werte einmal auf – danach kann nichts anderes hineingeraten. "
         "Mit Text als Ampelfarbe fiele ein Tippfehler wie „Rott“ erst beim Laufen auf, hier schon "
         "beim Übersetzen.",
         hint="Kurzform von „Enumeration“, also Aufzählung.",
         ctx="file",
         verify={"context": "file", "output": "ROT"},
         group="t14-1"),
    code("y-dat-4b", "datetime", 4,
         "Gib den 24. Dezember 2026 im Format „24.12.2026“ aus.",
         """
         // Datum anlegen und formatiert ausgeben
         """,
         """
         LocalDate weihnachten = LocalDate.of(2026, 12, 24);
         System.out.println(weihnachten.format(DateTimeFormatter.ofPattern("dd.MM.yyyy")));
         """,
         [req(r"LocalDate\.of\s*\(\s*2026\s*,\s*12\s*,\s*24\s*\)", "Lege das Datum mit LocalDate.of an."),
          req(r"ofPattern", "Für das deutsche Format brauchst du eine Vorlage mit ofPattern."),
          req(r'"dd\.MM\.yyyy"', "Das Muster lautet dd.MM.yyyy.", scope="raw"),
          req(r"\.format\s*\(", "Angewendet wird die Vorlage mit format.")],
         "Das Datum speichert nur Jahr, Monat und Tag – von deutscher Schreibweise weiß es nichts. Erst "
         "die Vorlage bestimmt die Darstellung. Groß und klein ist dabei entscheidend: MM sind Monate, "
         "mm wären Minuten.",
         expected="24.12.2026",
         group="t17-5"),
    fill("y-pat-1b", "patterns", 1, "Ergänze die beiden Wörter, die die Familie schließen.",
         """
         {{0}} interface Tier {{1}} Hund {}

         record Hund(String name) implements Tier {}

         public class Main {
             public static void main(String[] args) {
                 Tier t = new Hund("Bello");
                 System.out.println(t);
             }
         }
         """,
         [["sealed"], ["permits"]],
         "sealed schließt die Familie, permits zählt auf, wer dazugehören darf. Der Gewinn zeigt sich "
         "beim switch: Weil Java alle Möglichkeiten kennt, meldet es, wenn ein Fall fehlt. Bei einem "
         "offenen Interface könnte jederzeit irgendwo ein neuer Typ auftauchen.",
         hint="Erst das Wort fürs Versiegeln, dann das fürs Erlauben.",
         ctx="file",
         verify={"context": "file", "output": "Hund[name=Bello]"},
         group="t25-1"),
]

POOL_VARIETY = GRUNDLAGEN + OBJEKTE + ROBUST + MODERN + AUFBAU + PROJEKTE_UML + AUSGLEICH
