"""Übungspool, Teil 8c: mehr Aufgaben je Thema – Aufbauthemen und UML.

Der letzte Teil der Auffüllaktion: Texte und Dateien, Datum & Uhrzeit, Rekursion,
Suchen & Sortieren, Set/Stack/Queue, Testen, Werkzeuge, sealed & Pattern Matching
sowie die beiden UML-Themen. Am auffälligsten war „UML-Klassendiagramme“: Dort gab
es bis Stufe 3 viel, darüber gar nichts – ausgerechnet beim Umsetzen eines Diagramms
in Java, also dem Teil, der in Klausuren zählt.
"""
from authoring import any_of, code, fill, forbid, mc, out, req
from uml_content import (BESTELLUNG, DRUCKER, FORM_HIERARCHIE, HAUS, INTERFACE_DIAGRAM, KONTO,
                         PERSON, SCHULE, TIER_HUND, box, diagram, m, rel)

# ---------------------------------------------------------------- Texte, Eingaben & Dateien
IO = [
    mc("x-io-1a", "io", 1, "Wozu dient die Klasse Scanner?",
       ["Sie liest Eingaben ein – zum Beispiel das, was jemand tippt",
        "Sie durchsucht einen Text nach bestimmten Wörtern",
        "Sie prüft den Quelltext auf Fehler",
        "Sie schreibt Text in eine Datei"],
       "Ein Scanner liest eine Quelle Stück für Stück aus – meistens die Tastatur (System.in), manchmal "
       "eine Datei oder einen Text. Mit nextInt() holt man eine Zahl heraus, mit nextLine() eine ganze Zeile.",
       why=[None,
            "Zum Durchsuchen eines Textes hat String selbst Methoden wie contains oder indexOf.",
            "Den Quelltext prüft der Compiler, bevor das Programm überhaupt läuft.",
            "Zum Schreiben nimmt man Files.writeString oder einen Writer. Der Scanner liest nur."],
       group="t16-3"),
    out("x-io-2a", "io", 2, "Was gibt das Programm aus?",
        """
        StringBuilder sb = new StringBuilder();
        sb.append("Java");
        sb.append("-");
        sb.append(21);
        System.out.println(sb);
        System.out.println(sb.length());
        """,
        """
        Java-21
        7
        """,
        "append hängt hinten an und liefert den Bauplatz selbst zurück – auch eine Zahl wird dabei "
        "automatisch zu Text. Am Ende stehen sieben Zeichen darin: J-a-v-a, Bindestrich, 2, 1.",
        group="t16-2"),
    out("x-io-3a", "io", 3, "Was gibt das Programm aus?",
        """
        StringBuilder sb = new StringBuilder("Quest");
        sb.insert(0, "Java");
        sb.append("!");
        System.out.println(sb);
        System.out.println(sb.reverse());
        """,
        """
        JavaQuest!
        !tseuQavaJ
        """,
        "insert(0, …) schiebt etwas an den Anfang, append hängt hinten an. reverse dreht den Bauplatz um – "
        "und zwar wirklich: Der StringBuilder selbst ist danach verändert, anders als bei einem String, "
        "der immer unberührt bleibt.",
        group="t16-2"),
    code("x-io-5a", "io", 5,
         "Baue mit einem StringBuilder und einer Schleife aus den Zahlen 1 bis 5 den Text „1-2-3-4-5“ und gib ihn aus.",
         """
         // StringBuilder anlegen, in einer Schleife füllen, ausgeben
         """,
         """
         StringBuilder sb = new StringBuilder();
         for (int i = 1; i <= 5; i++) {
             if (i > 1) {
                 sb.append("-");
             }
             sb.append(i);
         }
         System.out.println(sb);
         """,
         [req(r"new\s+StringBuilder", "Lege einen StringBuilder als Bauplatz an."),
          req(r"for\s*\(|while\s*\(", "Die Zahlen kommen aus einer Schleife, nicht einzeln hingeschrieben."),
          req(r"\.append\s*\(", "Angehängt wird mit append."),
          req(r'"-"', "Zwischen den Zahlen steht ein Bindestrich.", scope="raw"),
          req(r"System\.out\.println", "Am Ende wird der fertige Text ausgegeben.")],
         "Der Bindestrich soll zwischen die Zahlen, nicht vor die erste – deshalb die Abfrage i > 1. "
         "Ein StringBuilder lohnt sich hier, weil bei jedem + auf einem String ein komplett neuer Text "
         "entstünde; der Bauplatz wird dagegen nur erweitert.",
         expected="1-2-3-4-5",
         group="t16-5"),
]

# ---------------------------------------------------------------- Datum & Uhrzeit
DATETIME = [
    mc("x-dt-1a", "datetime", 1, "Welche Klasse speichert ein Datum ohne Uhrzeit?",
       ["LocalDate", "LocalTime", "Date", "Calendar"],
       "LocalDate steht für einen Tag im Kalender – Jahr, Monat, Tag, sonst nichts. Für die Uhrzeit gibt es "
       "LocalTime, für beides zusammen LocalDateTime.",
       why=[None,
            "LocalTime speichert nur die Uhrzeit, also Stunde und Minute – ohne Tag.",
            "Date stammt aus der Zeit vor Java 8, mischt Datum und Uhrzeit und gilt heute als überholt.",
            "Calendar gehört ebenfalls zur alten, längst abgelösten Fassung der Datums-Klassen."],
       group="t17-2"),
    mc("x-dt-1b", "datetime", 1, "Wie kommst du an das heutige Datum?",
       ["LocalDate.now()", "new LocalDate()", "LocalDate.today()", "LocalDate.get()"],
       "now() fragt die Uhr des Rechners und liefert daraus ein LocalDate. Der Aufruf steht direkt an der "
       "Klasse, weil dafür noch kein Objekt nötig ist.",
       why=[None,
            "Einen öffentlichen Konstruktor hat LocalDate nicht. Objekte entstehen über Methoden wie now() oder of().",
            "today() heißt die Methode in anderen Sprachen. In Java lautet der Name now().",
            "get() liest einzelne Bestandteile aus einem Datum heraus, das schon existiert."],
       group="t17-2"),
    out("x-dt-2a", "datetime", 2, "Was gibt das Programm aus?",
        """
        LocalDate d = LocalDate.of(2026, 3, 14);
        System.out.println(d);
        System.out.println(d.getDayOfMonth());
        System.out.println(d.plusDays(20));
        """,
        """
        2026-03-14
        14
        2026-04-03
        """,
        "Ausgegeben wird ein Datum in der internationalen Schreibweise Jahr-Monat-Tag. plusDays rechnet über "
        "das Monatsende hinweg richtig weiter – und verändert d nicht, sondern liefert ein neues Datum zurück.",
        group="t17-2"),
    out("x-dt-3a", "datetime", 3, "Was gibt das Programm aus?",
        """
        LocalDate start = LocalDate.of(2026, 1, 1);
        LocalDate ende = LocalDate.of(2026, 3, 15);
        Period p = Period.between(start, ende);
        System.out.println(p.getMonths());
        System.out.println(p.getDays());
        System.out.println(start.isBefore(ende));
        """,
        """
        2
        14
        true
        """,
        "Period zerlegt den Abstand in Jahre, Monate und Tage – hier 2 Monate und 14 Tage. Wichtig: "
        "getDays() liefert nur den Rest nach den vollen Monaten, nicht die Gesamtzahl der Tage.",
        group="t17-3"),
    out("x-dt-4a", "datetime", 4, "Was gibt das Programm aus?",
        """
        LocalDateTime t = LocalDateTime.of(2026, 5, 2, 9, 30);
        System.out.println(t.getHour());
        System.out.println(t.plusHours(20));
        System.out.println(t.toLocalDate());
        """,
        """
        9
        2026-05-03T05:30
        2026-05-02
        """,
        "LocalDateTime hält Tag und Uhrzeit zusammen; das T in der Ausgabe trennt beides. plusHours(20) "
        "läuft über Mitternacht hinaus und schaltet dabei den Tag weiter. toLocalDate schneidet die Uhrzeit "
        "wieder weg – t selbst bleibt dabei unverändert.",
        group="t17-3"),
    fill("x-dt-4b", "datetime", 4, "Ergänze die Methode, die aus dem Muster eine Formatvorlage macht.",
         """
         LocalDate d = LocalDate.of(2026, 10, 3);
         DateTimeFormatter f = DateTimeFormatter.{{0}}("dd.MM.yyyy");
         System.out.println(d.format(f));
         """,
         [["ofPattern"]],
         "ofPattern baut aus dem Muster eine Vorlage: dd sind zwei Stellen für den Tag, MM zwei für den "
         "Monat, yyyy vier für das Jahr. Achtung auf die Groß- und Kleinschreibung – mm wären Minuten.",
         hint="„of“ plus das englische Wort für Muster.",
         verify={"output": "03.10.2026"},
         group="t17-5"),
    code("x-dt-5a", "datetime", 5,
         "Gib für den 1. Januar 2027 zuerst den Wochentag aus (so, wie Java ihn liefert) und darunter das Datum im Format „01.01.2027“.",
         """
         // Datum anlegen, Wochentag und formatiertes Datum ausgeben
         """,
         """
         LocalDate d = LocalDate.of(2027, 1, 1);
         System.out.println(d.getDayOfWeek());
         System.out.println(d.format(DateTimeFormatter.ofPattern("dd.MM.yyyy")));
         """,
         [req(r"LocalDate\.of\s*\(\s*2027\s*,\s*1\s*,\s*1\s*\)", "Lege das Datum mit LocalDate.of(2027, 1, 1) an."),
          req(r"getDayOfWeek\s*\(\s*\)", "Den Wochentag liefert getDayOfWeek()."),
          req(r"ofPattern", "Für das deutsche Format brauchst du eine Vorlage mit ofPattern."),
          req(r'"dd\.MM\.yyyy"', "Das Muster lautet dd.MM.yyyy.", scope="raw")],
         "getDayOfWeek liefert einen enum-Wert, deshalb erscheint der Name in Großbuchstaben und auf "
         "Englisch. Das Datum selbst weiß nichts von deutscher Schreibweise – die kommt erst durch die "
         "Formatvorlage dazu.",
         expected="""
         FRIDAY
         01.01.2027
         """,
         group="t17-5"),
    code("x-dt-5b", "datetime", 5,
         "Berechne, wie viele Tage zwischen dem 1. März 2026 und dem 24. Dezember 2026 liegen, und gib die Zahl aus.",
         """
         LocalDate start = LocalDate.of(2026, 3, 1);
         LocalDate ende = LocalDate.of(2026, 12, 24);
         // Abstand in Tagen ausgeben
         """,
         """
         LocalDate start = LocalDate.of(2026, 3, 1);
         LocalDate ende = LocalDate.of(2026, 12, 24);
         System.out.println(ende.toEpochDay() - start.toEpochDay());
         """,
         [req(r"toEpochDay\s*\(\s*\)", "toEpochDay macht aus jedem Datum eine fortlaufende Tagesnummer."),
          req(r"-", "Die Differenz der beiden Tagesnummern ist der Abstand."),
          req(r"System\.out\.println", "Gib die Zahl aus.")],
         "toEpochDay zählt die Tage seit dem 1. Januar 1970 – aus zwei Daten werden damit zwei schlichte "
         "Zahlen, deren Differenz der Abstand ist. Schaltjahre und unterschiedlich lange Monate sind darin "
         "schon berücksichtigt, man muss nichts selbst nachrechnen.",
         expected="298",
         group="t17-3"),
]

# ---------------------------------------------------------------- Rekursion
RECURSION = [
    mc("x-rec-1a", "recursion", 1, "Was bedeutet Rekursion?",
       ["Eine Methode ruft sich selbst wieder auf",
        "Eine Schleife mit zwei Zählern",
        "Eine Methode ohne Rückgabewert",
        "Ein Fehler, der sich immer wiederholt"],
       "Bei der Rekursion löst eine Methode ein großes Problem, indem sie sich selbst mit einem kleineren "
       "Teil davon aufruft – so lange, bis der Teil so klein ist, dass die Antwort feststeht.",
       why=[None,
            "Das wäre eine verschachtelte Schleife. Die Wiederholung entsteht dort durch den Zähler, nicht "
            "durch einen Aufruf.",
            "Ob etwas zurückkommt, hat mit Rekursion nichts zu tun – rekursive Methoden geben meist sogar "
            "etwas zurück.",
            "Ein sich wiederholender Fehler wäre höchstens die Folge einer fehlenden Abbruchbedingung."],
       group="t18-1"),
    mc("x-rec-1b", "recursion", 1, "Was passiert, wenn der Basisfall fehlt?",
       ["Die Methode ruft sich endlos auf, bis das Programm mit einem StackOverflowError abbricht",
        "Java ergänzt selbst eine sinnvolle Abbruchbedingung",
        "Die Methode läuft genau einmal und ist dann fertig",
        "Der Compiler lehnt den Code schon beim Übersetzen ab"],
       "Jeder Aufruf belegt Platz auf dem Aufruf-Stapel. Ohne Abbruchbedingung wächst dieser Stapel endlos, "
       "bis der Platz aufgebraucht ist – dann bricht das Programm mit StackOverflowError ab.",
       why=[None,
            "Wann Schluss ist, kann nur der Mensch wissen. Java ergänzt nichts.",
            "Genau einmal liefe sie nur, wenn sie sich gar nicht selbst aufruft.",
            "Der Compiler merkt das nicht – syntaktisch ist der Code in Ordnung. Auffallen tut es erst beim Laufen."],
       group="t18-1"),
    out("x-rec-2a", "recursion", 2, "Was gibt das Programm aus?",
        """
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
        "summe(4) wartet auf summe(3), das auf summe(2) und so weiter bis summe(0), das 0 liefert. "
        "Danach lösen sich die wartenden Aufrufe von innen nach außen auf: 0, 1, 3, 6, 10.",
        ctx="members",
        group="t18-2"),
    out("x-rec-3a", "recursion", 3, "In welcher Reihenfolge erscheinen die Zeilen?",
        """
        static void runter(int n) {
            if (n == 0) {
                return;
            }
            System.out.println(n);
            runter(n - 1);
            System.out.println("zurueck " + n);
        }

        public static void main(String[] args) {
            runter(2);
        }
        """,
        """
        2
        1
        zurueck 1
        zurueck 2
        """,
        "Die Zeilen vor dem Aufruf laufen auf dem Hinweg, die danach auf dem Rückweg – und zwar in "
        "umgekehrter Reihenfolge. Genau dieses Nacharbeiten beim Zurückkommen ist der Unterschied zu "
        "einer Schleife.",
        ctx="members",
        group="t18-2"),
    out("x-rec-3b", "recursion", 3, "Was gibt das Programm aus?",
        """
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
        "Die Folge lautet 0, 1, 1, 2, 3, 5, 8 – an Position 6 steht die 8. Zu beachten: Jeder Aufruf "
        "verzweigt sich in zwei neue, deshalb wächst der Aufwand rasant. Für größere n rechnet eine "
        "Schleife deutlich schneller.",
        ctx="members",
        group="t18-3"),
    code("x-rec-5a", "recursion", 5,
         "Schreibe fakultaet(int n) rekursiv – ohne Schleife. Beispiel: 5 ergibt 120, weil 1 · 2 · 3 · 4 · 5 = 120.",
         """
         static int fakultaet(int n) {
             // Basisfall und rekursiver Aufruf
         }
         """,
         """
         static int fakultaet(int n) {
             if (n <= 1) {
                 return 1;
             }
             return n * fakultaet(n - 1);
         }
         """,
         [req(r"return\s+1", "Der Basisfall liefert 1 – damit hört die Kette auf."),
          req(r"fakultaet\s*\(\s*n\s*-\s*1\s*\)", "Der rekursive Aufruf macht die Zahl um eins kleiner."),
          any_of([r"n\s*\*", r"\*\s*n\b"], "Das Ergebnis des kleineren Aufrufs wird mit n multipliziert."),
          forbid(r"for\s*\(|while\s*\(", "Ohne Schleife – die Wiederholung übernimmt der Aufruf selbst.")],
         "Der Basisfall muss vor dem Aufruf stehen, sonst wird er nie erreicht. n <= 1 statt n == 1 fängt "
         "außerdem die 0 mit ab, deren Fakultät ebenfalls 1 ist.",
         ctx="members",
         verify={"context": "members", "main": "System.out.println(fakultaet(5));", "output": "120"},
         group="t18-5"),
    code("x-rec-5b", "recursion", 5,
         "Schreibe rueckwaerts(String text) rekursiv: „Java“ soll „avaJ“ ergeben – ohne Schleife und ohne StringBuilder.",
         """
         static String rueckwaerts(String text) {
             // Basisfall und rekursiver Aufruf
         }
         """,
         """
         static String rueckwaerts(String text) {
             if (text.isEmpty()) {
                 return text;
             }
             return rueckwaerts(text.substring(1)) + text.charAt(0);
         }
         """,
         [req(r"isEmpty\s*\(\s*\)|length\s*\(\s*\)\s*==\s*0", "Der Basisfall ist der leere Text – dort ist nichts mehr umzudrehen."),
          req(r"substring\s*\(\s*1\s*\)", "Der kleinere Teil ist der Text ohne sein erstes Zeichen."),
          req(r"charAt\s*\(\s*0\s*\)", "Das erste Zeichen wird hinten wieder angehängt."),
          forbid(r"for\s*\(|while\s*\(", "Ohne Schleife – die Wiederholung übernimmt der Aufruf selbst."),
          forbid(r"StringBuilder", "Diesmal ohne StringBuilder: Es geht um den rekursiven Gedanken.")],
         "Der Trick: Das erste Zeichen gehört ans Ende, der Rest wird nach derselben Regel behandelt. "
         "Weil das Anhängen erst nach dem Aufruf passiert, entsteht der umgedrehte Text auf dem Rückweg "
         "aus der Rekursion.",
         ctx="members",
         verify={"context": "members", "main": 'System.out.println(rueckwaerts("Java"));', "output": "avaJ"},
         group="t18-5"),
]

# ---------------------------------------------------------------- Suchen & Sortieren
ALGORITHMS = [
    mc("x-alg-1a", "algorithms", 1, "Was macht eine lineare Suche?",
       ["Sie schaut jedes Element der Reihe nach an, bis sie das gesuchte findet",
        "Sie halbiert bei jedem Schritt den Bereich, in dem gesucht wird",
        "Sie sortiert die Liste zuerst und greift dann direkt zu",
        "Sie springt sofort an die richtige Stelle"],
       "Die lineare Suche ist die einfachste Art zu suchen: von vorn anfangen und vergleichen, bis es "
       "passt. Dafür muss nichts sortiert sein – im schlimmsten Fall schaut sie aber alles an.",
       why=[None,
            "Das Halbieren ist die binäre Suche. Die setzt allerdings voraus, dass sortiert ist.",
            "Sortieren gehört nicht dazu und wäre meist aufwendiger als die Suche selbst.",
            "Direkt zugreifen kann man nur, wenn man die Position schon kennt – die sucht man ja gerade."],
       group="t19-1"),
    mc("x-alg-1b", "algorithms", 1, "Warum ist die binäre Suche schneller als die lineare?",
       ["Weil sie bei jedem Schritt die Hälfte aller Möglichkeiten ausschließt",
        "Weil sie mehrere Prozessorkerne gleichzeitig nutzt",
        "Weil sie sich frühere Ergebnisse merkt",
        "Weil sie nur die ersten zehn Elemente prüft"],
       "Jeder Blick in die Mitte halbiert den verbleibenden Bereich. Aus einer Million werden so nach einem "
       "Schritt 500 000, nach zwei 250 000 – nach etwa 20 Schritten ist nur noch einer übrig.",
       why=[None,
            "Von mehreren Kernen weiß die binäre Suche nichts. Sie läuft ganz gewöhnlich nacheinander ab.",
            "Gemerkt wird nichts. Der Vorteil kommt allein daraus, dass die Daten sortiert sind.",
            "Sie prüft beliebig weit – nur eben immer im halbierten Bereich."],
       group="t19-1"),
    out("x-alg-2a", "algorithms", 2, "Was gibt das Programm aus?",
        """
        int[] zahlen = {5, 2, 9, 1};
        Arrays.sort(zahlen);
        System.out.println(Arrays.toString(zahlen));
        System.out.println(Arrays.binarySearch(zahlen, 9));
        """,
        """
        [1, 2, 5, 9]
        3
        """,
        "Arrays.sort ordnet das Array an Ort und Stelle – es entsteht kein neues. Danach steht die 9 an "
        "Position 3, und genau die meldet binarySearch. Ohne das vorherige Sortieren wäre das Ergebnis "
        "unbrauchbar.",
        group="t19-3"),
    mc("x-alg-2b", "algorithms", 2, "Etwa wie viele Blicke braucht die binäre Suche bei 1 000 sortierten Einträgen höchstens?",
       ["ungefähr 10", "ungefähr 100", "ungefähr 500", "ungefähr 1 000"],
       "Bei jedem Schritt bleibt die Hälfte übrig: 1000, 500, 250, 125, 63, 32, 16, 8, 4, 2, 1 – das sind "
       "rund zehn Blicke. Die Zahl wächst nur sehr langsam mit: Bei einer Million sind es etwa zwanzig.",
       why=[None,
            "100 wäre ein Zehntel der Einträge. So viele braucht die binäre Suche bei Weitem nicht.",
            "Die Hälfte anzuschauen wäre der Durchschnitt der linearen Suche – nicht der binären.",
            "Alle 1 000 anzusehen wäre der schlimmste Fall der linearen Suche."],
       group="t19-2"),
    out("x-alg-3a", "algorithms", 3, "Was gibt das Programm aus?",
        """
        List<String> woerter = new ArrayList<>(List.of("Birne", "Ei", "Apfel"));
        Collections.sort(woerter);
        System.out.println(woerter);
        woerter.sort(Comparator.comparing(String::length));
        System.out.println(woerter);
        """,
        """
        [Apfel, Birne, Ei]
        [Ei, Apfel, Birne]
        """,
        "Ohne Angabe sortiert Java Texte alphabetisch. Mit Comparator.comparing legt man ein anderes "
        "Merkmal fest – hier die Länge. Apfel und Birne sind gleich lang; ihre Reihenfolge aus dem Schritt "
        "davor bleibt erhalten, weil Javas Sortierung stabil ist.",
        group="t19-5"),
    fill("x-alg-4a", "algorithms", 4, "Ergänze die lineare Suche: Sie soll die Position von „Linus“ finden.",
         """
         String[] namen = {"Ada", "Grace", "Linus"};
         int pos = -1;
         for (int i = 0; i < namen.length; i++) {
             if (namen[i].{{0}}("Linus")) {
                 pos = i;
                 {{1}};
             }
         }
         System.out.println(pos);
         """,
         [["equals"], ["break"]],
         "Texte vergleicht man mit equals, nicht mit ==. Das break verlässt die Schleife beim ersten "
         "Treffer – ohne es liefe sie sinnlos bis zum Ende weiter. Der Startwert -1 steht für „nicht "
         "gefunden“, denn eine echte Position ist nie negativ.",
         hint="Erst der Vergleich für Texte, dann das Wort, das eine Schleife sofort verlässt.",
         verify={"output": "2"},
         group="t19-4"),
    code("x-alg-5a", "algorithms", 5,
         "Sortiere die Zahlen absteigend – die größte zuerst – und gib die Liste aus.",
         """
         List<Integer> zahlen = new ArrayList<>(List.of(3, 9, 1, 7));
         // absteigend sortieren und ausgeben
         """,
         """
         List<Integer> zahlen = new ArrayList<>(List.of(3, 9, 1, 7));
         zahlen.sort(Comparator.reverseOrder());
         System.out.println(zahlen);
         """,
         [req(r"\.sort\s*\(|Collections\.sort", "Sortiert wird mit sort."),
          req(r"reverseOrder|reversed\s*\(\s*\)", "Für die umgekehrte Reihenfolge gibt es Comparator.reverseOrder()."),
          req(r"System\.out\.println", "Am Ende wird die Liste ausgegeben.")],
         "Ein Comparator ist die Antwort auf die Frage „welches kommt zuerst?“. reverseOrder() dreht die "
         "natürliche Reihenfolge einfach um – man muss nicht selbst vergleichen. Sortiert wird die Liste "
         "dabei an Ort und Stelle.",
         expected="[9, 7, 3, 1]",
         group="t19-5"),
]

# ---------------------------------------------------------------- Set, Stack & Queue
DATASTRUCTURES = [
    mc("x-ds-1a", "datastructures", 1, "Was unterscheidet ein Set von einer Liste?",
       ["Ein Set lässt keine doppelten Werte zu",
        "Ein Set kann nur Zahlen speichern",
        "Ein Set hat eine feste Größe",
        "Ein Set ist immer sortiert"],
       "Ein Set ist eine Menge: Jeder Wert kommt höchstens einmal vor. Fügt man etwas ein zweites Mal "
       "hinzu, passiert schlicht nichts – praktisch, wenn man „welche verschiedenen …“ wissen will.",
       why=[None,
            "Ein Set nimmt jede Sorte auf, genau wie eine Liste.",
            "Ein Set wächst und schrumpft nach Bedarf. Fest ist nur die Größe eines Arrays.",
            "Sortiert ist nur ein TreeSet. Ein HashSet hat gar keine verlässliche Reihenfolge."],
       group="t20-1"),
    mc("x-ds-1b", "datastructures", 1, "Nach welchem Prinzip arbeitet eine Queue, also eine Warteschlange?",
       ["Wer zuerst kommt, wird zuerst bedient",
        "Wer zuletzt kommt, wird zuerst bedient",
        "Die Reihenfolge ist zufällig",
        "Bedient wird in alphabetischer Reihenfolge"],
       "Eine Queue ist die Schlange an der Kasse: hinten anstellen, vorne herauskommen. Der Fachbegriff "
       "dafür ist FIFO – first in, first out.",
       why=[None,
            "Das ist ein Stapel (Stack): oben drauflegen, oben herunternehmen. Dafür nimmt man in Java eine Deque.",
            "Zufall gibt es hier nicht. Die Reihenfolge ist genau festgelegt.",
            "Alphabetisch sortiert würde ein TreeSet oder eine PriorityQueue mit Comparator – die "
            "gewöhnliche Warteschlange nicht."],
       group="t20-1"),
    out("x-ds-2a", "datastructures", 2, "Was gibt das Programm aus?",
        """
        Set<String> farben = new HashSet<>();
        farben.add("rot");
        farben.add("blau");
        farben.add("rot");
        System.out.println(farben.size());
        System.out.println(farben.contains("blau"));
        """,
        """
        2
        true
        """,
        "„rot“ ein zweites Mal hinzuzufügen ändert nichts – ein Set kennt jeden Wert nur einmal. add "
        "meldet das übrigens zurück: Beim zweiten Mal liefert es false.",
        group="t20-2"),
    out("x-ds-2b", "datastructures", 2, "Was gibt das Programm aus?",
        """
        Deque<String> stapel = new ArrayDeque<>();
        stapel.push("A");
        stapel.push("B");
        System.out.println(stapel.pop());
        System.out.println(stapel.peek());
        """,
        """
        B
        A
        """,
        "push legt oben auf den Stapel, pop nimmt von oben weg – zuletzt hineingelegt, zuerst wieder "
        "heraus. peek schaut nur nach, was oben liegt, ohne es wegzunehmen; deshalb bleibt „A“ im Stapel.",
        group="t20-3"),
    out("x-ds-4a", "datastructures", 4, "Was gibt das Programm aus?",
        """
        TreeSet<String> namen = new TreeSet<>(List.of("Linus", "Ada", "Grace"));
        System.out.println(namen);
        System.out.println(namen.first());
        System.out.println(namen.last());
        """,
        """
        [Ada, Grace, Linus]
        Ada
        Linus
        """,
        "Ein TreeSet hält seinen Inhalt immer sortiert – ganz gleich, in welcher Reihenfolge eingefügt "
        "wurde. Deshalb kann es first() und last() sofort beantworten, wofür man sonst alles durchsuchen müsste.",
        group="t20-3"),
    code("x-ds-5a", "datastructures", 5,
         "Gib sortiert aus, welche Wörter in beiden Listen vorkommen.",
         """
         List<String> a = List.of("rot", "gruen", "blau");
         List<String> b = List.of("blau", "gelb", "rot");
         // Schnittmenge bilden und ausgeben
         """,
         """
         List<String> a = List.of("rot", "gruen", "blau");
         List<String> b = List.of("blau", "gelb", "rot");
         Set<String> beide = new TreeSet<>(a);
         beide.retainAll(b);
         System.out.println(beide);
         """,
         [req(r"TreeSet|new\s+HashSet", "Lege aus der ersten Liste ein Set an – ein TreeSet sortiert dabei gleich mit."),
          req(r"retainAll|contains", "retainAll behält nur das, was auch in der anderen Sammlung steht."),
          req(r"System\.out\.println", "Am Ende wird die Schnittmenge ausgegeben.")],
         "retainAll ist die Schnittmenge: Alles, was nicht auch in der anderen Sammlung steht, fliegt "
         "hinaus. Das TreeSet sorgt nebenbei für die alphabetische Reihenfolge – bei einem HashSet wäre "
         "die Ausgabe nicht vorhersagbar.",
         expected="[blau, rot]",
         group="t20-5"),
]

# ---------------------------------------------------------------- Testen
TESTING = [
    mc("x-test-1a", "testing", 1, "Was prüft assertEquals?",
       ["Ob der berechnete Wert dem erwarteten entspricht",
        "Ob das Programm ohne Absturz startet",
        "Ob der Code schnell genug läuft",
        "Ob alle Variablen benutzt werden"],
       "assertEquals stellt zwei Werte gegenüber: links, was herauskommen soll, rechts, was tatsächlich "
       "herauskommt. Stimmen sie überein, ist der Test grün – sonst meldet er genau diesen Unterschied.",
       why=[None,
            "Dass das Programm startet, ist nur das Mindeste. Ein Test prüft ein bestimmtes Ergebnis.",
            "Geschwindigkeit misst man mit eigenen Messungen, nicht mit assertEquals.",
            "Ungenutzte Variablen meldet der Compiler oder die Entwicklungsumgebung."],
       group="t21-1"),
    mc("x-test-2a", "testing", 2, "Warum schreibt man Tests, obwohl das Programm doch schon funktioniert?",
       ["Damit spätere Änderungen nicht unbemerkt etwas kaputt machen",
        "Weil der Compiler sonst nicht übersetzt",
        "Damit das Programm schneller läuft",
        "Weil der Code dadurch kürzer wird"],
       "Der eigentliche Wert eines Tests zeigt sich später: Wer etwas umbaut, sieht sofort, ob dabei etwas "
       "zerbrochen ist. Ohne Tests merkt man das oft erst, wenn jemand das Programm benutzt.",
       why=[None,
            "Tests sind freiwillig. Der Compiler übersetzt auch ohne sie.",
            "Auf die Geschwindigkeit haben Tests keinen Einfluss – sie laufen getrennt vom Programm.",
            "Tests machen den Code insgesamt sogar länger. Der Nutzen liegt woanders."],
       group="t21-1"),
    mc("x-test-2b", "testing", 2, "Was bedeutet es, wenn ein Test „rot“ ist?",
       ["Der tatsächliche Wert weicht vom erwarteten ab – oder es gab einen Fehler",
        "Der Test wurde noch nicht ausgeführt",
        "Der Test dauert zu lange",
        "Der Test ist auskommentiert"],
       "Rot heißt: Die Erwartung wurde nicht erfüllt. Der Fehler kann im geprüften Code stecken – oder im "
       "Test selbst, wenn dort ein falscher Erwartungswert steht.",
       why=[None,
            "Ein nicht ausgeführter Test ist gar nicht eingefärbt. Rot wird er erst nach einem Durchlauf.",
            "Dauer allein lässt keinen Test scheitern – nur eine ausdrücklich gesetzte Zeitgrenze.",
            "Ein auskommentierter Test läuft gar nicht und kann deshalb auch nicht rot werden."],
       group="t21-2"),
    out("x-test-3a", "testing", 3, "Welche Zeilen erscheinen?",
        """
        static void pruefe(String name, int erwartet, int tatsaechlich) {
            System.out.println(name + ": " + (erwartet == tatsaechlich ? "ok" : "FEHLER"));
        }

        public static void main(String[] args) {
            pruefe("doppelt 0", 0, 0 * 2);
            pruefe("doppelt 5", 10, 5 * 2);
            pruefe("doppelt -2", -4, -2 * 3);
        }
        """,
        """
        doppelt 0: ok
        doppelt 5: ok
        doppelt -2: FEHLER
        """,
        "Die dritte Prüfung scheitert, weil dort mit 3 statt mit 2 multipliziert wird: erwartet -4, "
        "herausgekommen -6. Genau so arbeitet ein Test – er vergleicht und meldet den Unterschied, "
        "statt das Programm abstürzen zu lassen.",
        ctx="members",
        group="t21-3"),
    fill("x-test-4a", "testing", 4, "Ergänze den JUnit-Test: Er soll prüfen, dass 3 + 4 die Zahl 7 ergibt.",
         r"""
         class RechnerTest {
             {{0}}
             void addiertRichtig() {
                 {{1}}(7, 3 + 4);
             }
         }
         """,
         [["@Test"], ["assertEquals"]],
         "@Test markiert die Methode, damit JUnit sie von selbst findet und startet. assertEquals vergleicht "
         "dann beides – links der erwartete Wert, rechts das tatsächliche Ergebnis. Diese Reihenfolge ist "
         "wichtig, sonst steht die Fehlermeldung später auf dem Kopf.",
         hint="Oben der Hinweiszettel für JUnit, unten der Vergleich zweier Werte.",
         verify={"skip": True},
         group="t21-4"),
    out("x-test-4b", "testing", 4, "Was gibt das Programm aus?",
        """
        static boolean istGerade(int n) {
            return n % 2 == 0;
        }

        public static void main(String[] args) {
            System.out.println(istGerade(0));
            System.out.println(istGerade(-3));
            System.out.println(istGerade(7));
        }
        """,
        """
        true
        false
        false
        """,
        "Das sind drei typische Testfälle: die 0 als Randfall, eine negative und eine positive Zahl. "
        "-3 % 2 ergibt in Java -1, also nicht 0 – und damit false, was hier richtig ist.",
        ctx="members",
        group="t21-3"),
    code("x-test-5a", "testing", 5,
         "Prüfe die Methode laenge dreimal mit pruefe(…): für den leeren Text, für „ab“ und für „Java“. Alle drei Prüfungen sollen „ok“ ergeben.",
         """
         static int laenge(String s) {
             return s.length();
         }

         static void pruefe(String name, int erwartet, int tatsaechlich) {
             System.out.println(name + ": " + (erwartet == tatsaechlich ? "ok" : "FEHLER"));
         }

         public static void main(String[] args) {
             // drei Prüfungen hier ergänzen
         }
         """,
         """
         static int laenge(String s) {
             return s.length();
         }

         static void pruefe(String name, int erwartet, int tatsaechlich) {
             System.out.println(name + ": " + (erwartet == tatsaechlich ? "ok" : "FEHLER"));
         }

         public static void main(String[] args) {
             pruefe("leer", 0, laenge(""));
             pruefe("ab", 2, laenge("ab"));
             pruefe("Java", 4, laenge("Java"));
         }
         """,
         [req(r'laenge\s*\(\s*""\s*\)', "Der leere Text ist der wichtigste Randfall – prüfe ihn mit laenge(\"\").", scope="raw"),
          req(r'laenge\s*\(\s*"ab"\s*\)', 'Prüfe auch „ab“ – erwartet werden 2 Zeichen.', scope="raw"),
          req(r'laenge\s*\(\s*"Java"\s*\)', 'Prüfe auch „Java“ – erwartet werden 4 Zeichen.', scope="raw"),
          req(r'"leer"', "Gib jeder Prüfung einen Namen, damit man in der Ausgabe sieht, welche gescheitert ist.", scope="raw")],
         "Gute Tests nehmen die Ränder mit: den leeren Text, den kürzesten sinnvollen Fall und einen "
         "gewöhnlichen. Der Name als erstes Argument ist kein Schmuck – ohne ihn weiß man bei „FEHLER“ "
         "nicht, welcher Fall danebenlag.",
         ctx="members",
         expected="""
         leer: ok
         ab: ok
         Java: ok
         """,
         group="t21-5"),
]

# ---------------------------------------------------------------- Pakete, Build & Fehlersuche
TOOLING = [
    mc("x-tool-1a", "tooling", 1, "Wozu dienen Pakete (package)?",
       ["Sie ordnen Klassen in Gruppen, damit gleiche Namen sich nicht in die Quere kommen",
        "Sie machen das Programm schneller",
        "Sie verschlüsseln den Quelltext",
        "Sie ersetzen die Klassen"],
       "Ein Paket ist wie ein Ordner für Klassen. Dadurch darf es eine Klasse Liste in zwei Projekten "
       "geben, ohne dass Java durcheinanderkommt – der volle Name enthält immer das Paket.",
       why=[None,
            "Auf die Geschwindigkeit hat die Einteilung keinen Einfluss.",
            "Verschlüsselt wird nichts. Der Quelltext bleibt lesbar.",
            "Die Klassen bleiben bestehen – sie bekommen nur eine Adresse."],
       group="t22-1"),
    mc("x-tool-1b", "tooling", 1, "Was ist der Unterschied zwischen javac und java?",
       ["javac übersetzt den Quelltext, java führt das Übersetzte aus",
        "javac ist für Windows, java für Mac",
        "javac ist die alte, java die neue Fassung",
        "Beide machen dasselbe"],
       "javac ist der Compiler: Er macht aus der .java-Datei eine .class-Datei. Der Befehl java startet "
       "danach die virtuelle Maschine, die diese .class-Datei ausführt.",
       why=[None,
            "Beide Befehle gibt es auf jedem Betriebssystem. Das c steht für „compiler“.",
            "Sie lösen einander nicht ab, sondern gehören zusammen – erst übersetzen, dann ausführen.",
            "Die Aufgaben sind klar getrennt: übersetzen und ausführen."],
       group="t22-2"),
    mc("x-tool-2a", "tooling", 2, "Was steht in einer Datei wie build.gradle oder pom.xml?",
       ["Womit das Projekt gebaut wird und welche fremden Bibliotheken es braucht",
        "Der gesamte Quelltext des Projekts",
        "Die Ausgabe des letzten Programmlaufs",
        "Die persönlichen Einstellungen des Editors"],
       "Diese Datei ist der Bauplan des Projekts: Sie nennt die Java-Fassung, die benötigten Bibliotheken "
       "und die Schritte zum Bauen. Das Werkzeug lädt die Bibliotheken dann selbst herunter.",
       why=[None,
            "Der Quelltext liegt in den .java-Dateien. Der Bauplan verweist nur auf die Ordner.",
            "Ausgaben landen in der Konsole oder in Protokolldateien, nicht im Bauplan.",
            "Editor-Einstellungen sind persönlich und gehören nicht ins Projekt."],
       group="t22-2"),
    out("x-tool-3a", "tooling", 3, "Welche Zeilen zeigt die Fehlersuche?",
        """
        int summe = 0;
        for (int i = 1; i <= 3; i++) {
            summe += i;
            System.out.println("i=" + i + " summe=" + summe);
        }
        """,
        """
        i=1 summe=1
        i=2 summe=3
        i=3 summe=6
        """,
        "Zwischenausgaben sind die einfachste Art der Fehlersuche: Man macht sichtbar, was das Programm "
        "in jeder Runde tatsächlich tut. Gerade bei Schleifen zeigt sich so sofort, ob der Zähler und das "
        "Zwischenergebnis zusammenpassen.",
        group="t22-3"),
    out("x-tool-4a", "tooling", 4, "Welche Summe wird ausgegeben – und warum nicht 60?",
        """
        int[] zahlen = {10, 20, 30};
        int summe = 0;
        for (int i = 0; i < zahlen.length - 1; i++) {
            summe += zahlen[i];
        }
        System.out.println(summe);
        """,
        "30",
        "Das ist der klassische Zaunpfahl-Fehler: Durch das - 1 endet die Schleife eine Runde zu früh, "
        "das letzte Fach wird nie gelesen. Richtig wäre i < zahlen.length – das - 1 braucht man nur, wenn "
        "man den letzten Index direkt ansprechen will.",
        group="t22-4"),
    code("x-tool-5a", "tooling", 5,
         "Fehlersuche: Der Code soll alle Zahlen des Arrays addieren (60), gibt aber 30 aus. Finde die Ursache und behebe sie.",
         """
         int[] zahlen = {10, 20, 30};
         int summe = 0;
         for (int i = 0; i < zahlen.length - 1; i++) {
             summe += zahlen[i];
         }
         System.out.println(summe);
         """,
         """
         int[] zahlen = {10, 20, 30};
         int summe = 0;
         for (int i = 0; i < zahlen.length; i++) {
             summe += zahlen[i];
         }
         System.out.println(summe);
         """,
         [req(r"i\s*<\s*zahlen\.length\s*;", "Die Schleife muss bis zum letzten Fach laufen: i < zahlen.length."),
          forbid(r"length\s*-\s*1", "Mit length - 1 bleibt das letzte Fach außen vor – genau das ist der Fehler."),
          any_of([r"summe\s*\+=", r"summe\s*=\s*summe\s*\+"], "Aufaddiert wird weiterhin.")],
         "Fächer werden ab 0 gezählt, deshalb ist der letzte Index length - 1. In der Schleifenbedingung "
         "steht aber ein Kleiner-Zeichen – i < length hört von selbst nach dem letzten Fach auf. Beides zu "
         "kombinieren ist einer der häufigsten Anfängerfehler.",
         expected="60",
         group="t22-5"),
]

# ---------------------------------------------------------------- sealed & Pattern Matching
PATTERNS = [
    mc("x-pat-1a", "patterns", 1, "Was bewirkt sealed bei einem Interface?",
       ["Nur ausdrücklich erlaubte Typen dürfen es umsetzen",
        "Es kann überhaupt nicht mehr umgesetzt werden",
        "Alle seine Methoden werden privat",
        "Es lässt sich nachträglich nicht mehr ändern"],
       "sealed schließt die Familie: Hinter permits stehen alle Typen, die dazugehören dürfen. Weil Java "
       "damit alle Möglichkeiten kennt, kann es in einem switch prüfen, ob wirklich jeder Fall bedacht ist.",
       why=[None,
            "Umsetzen ist weiterhin erlaubt – nur eben nicht von beliebigen Typen.",
            "Die Sichtbarkeit der Methoden regeln public und private. sealed sagt nichts darüber.",
            "Ändern kann man die Datei jederzeit. sealed beschränkt nur, wer dazugehören darf."],
       group="t25-1"),
    out("x-pat-2a", "patterns", 2, "Was gibt das Programm aus?",
        """
        public class Main {
            static String beschreibe(Object o) {
                if (o instanceof Integer i) {
                    return "Zahl " + i;
                }
                if (o instanceof String s) {
                    return "Text mit " + s.length() + " Zeichen";
                }
                return "unbekannt";
            }

            public static void main(String[] args) {
                System.out.println(beschreibe(7));
                System.out.println(beschreibe("Java"));
                System.out.println(beschreibe(1.5));
            }
        }
        """,
        """
        Zahl 7
        Text mit 4 Zeichen
        unbekannt
        """,
        "Der Name hinter dem Typ – i beziehungsweise s – entsteht nur, wenn die Prüfung zutrifft. Innerhalb "
        "des Blocks hat er schon den richtigen Typ, deshalb darf man sofort s.length() aufrufen. Die 1.5 ist "
        "ein Double und fällt durch beide Prüfungen.",
        ctx="file",
        group="t25-2"),
    out("x-pat-3a", "patterns", 3, "Was gibt das Programm aus?",
        """
        sealed interface Form permits Kreis, Quadrat {}

        record Kreis(double r) implements Form {}

        record Quadrat(double seite) implements Form {}

        public class Main {
            public static void main(String[] args) {
                Form f = new Quadrat(3);
                String text = switch (f) {
                    case Kreis k -> "Kreis mit r=" + k.r();
                    case Quadrat q -> "Quadrat mit Seite " + q.seite();
                };
                System.out.println(text);
            }
        }
        """,
        "Quadrat mit Seite 3.0",
        "Weil Form sealed ist, kennt Java genau zwei Möglichkeiten – deshalb braucht dieses switch kein "
        "default. Die 3 wird beim Anlegen zu 3.0, denn das Feld ist ein double.",
        ctx="file",
        group="t25-3"),
    mc("x-pat-3b", "patterns", 3, "Warum braucht ein switch über ein sealed interface kein default?",
       ["Weil Java alle erlaubten Typen kennt und prüfen kann, dass keiner fehlt",
        "Weil default bei switch-Ausdrücken verboten ist",
        "Weil sealed selbst einen default-Zweig erzeugt",
        "Weil ein sealed interface nur einen einzigen Typ haben darf"],
       "Genau das ist der Gewinn: Java weiß aus dem permits, welche Typen es gibt. Sind alle abgedeckt, "
       "ist kein Rest mehr möglich. Kommt später ein Typ dazu, meldet der Compiler jedes switch, das ihn "
       "noch nicht behandelt.",
       why=[None,
            "Erlaubt ist default weiterhin – nötig ist es hier nur nicht.",
            "Erzeugt wird nichts. Der Compiler rechnet lediglich nach, dass alle Fälle vorkommen.",
            "Ein sealed interface darf beliebig viele erlaubte Typen haben, sie müssen nur genannt sein."],
       group="t25-4"),
    out("x-pat-4a", "patterns", 4, "Was gibt das Programm aus?",
        """
        record Punkt(int x, int y) {}

        public class Main {
            static String zeige(Object o) {
                return switch (o) {
                    case Punkt(int x, int y) when x == y -> "auf der Diagonalen";
                    case Punkt(int x, int y) -> "Punkt " + x + "/" + y;
                    default -> "etwas anderes";
                };
            }

            public static void main(String[] args) {
                System.out.println(zeige(new Punkt(2, 2)));
                System.out.println(zeige(new Punkt(1, 4)));
            }
        }
        """,
        """
        auf der Diagonalen
        Punkt 1/4
        """,
        "Das ist ein Record-Pattern: Punkt(int x, int y) prüft den Typ und holt in einem Zug die Felder "
        "heraus. Das when dahinter ist eine Zusatzbedingung – nur wenn auch sie stimmt, greift der Zweig. "
        "Die Reihenfolge zählt: Der engere Fall muss oben stehen.",
        ctx="file",
        group="t25-3"),
    code("x-pat-5a", "patterns", 5,
         "Ergänze umfang mit einem switch über die Form: Für einen Kreis 2 · π · r, für ein Quadrat 4 · seite.",
         """
         sealed interface Form permits Kreis, Quadrat {}

         record Kreis(double r) implements Form {}

         record Quadrat(double seite) implements Form {}

         class Rechner {
             static double umfang(Form f) {
                 // switch hier ergänzen
             }
         }
         """,
         """
         sealed interface Form permits Kreis, Quadrat {}

         record Kreis(double r) implements Form {}

         record Quadrat(double seite) implements Form {}

         class Rechner {
             static double umfang(Form f) {
                 return switch (f) {
                     case Kreis k -> 2 * Math.PI * k.r();
                     case Quadrat q -> 4 * q.seite();
                 };
             }
         }
         """,
         [req(r"switch\s*\(\s*f\s*\)", "Das switch entscheidet anhand der übergebenen Form."),
          req(r"case\s+Kreis", "Ein Zweig gilt dem Kreis."),
          req(r"case\s+Quadrat", "Der andere Zweig gilt dem Quadrat."),
          req(r"Math\.PI", "Für π nimmt man Math.PI statt einer selbst hingeschriebenen Zahl."),
          req(r"return", "Das Ergebnis des switch muss zurückgegeben werden.")],
         "Weil Form sealed ist, genügen die beiden Zweige – Java prüft selbst, dass nichts fehlt. Math.PI "
         "ist dabei genauer als jede von Hand notierte Kommazahl und sagt zugleich, was gemeint ist.",
         ctx="file",
         verify={"context": "file", "main": "System.out.println(Rechner.umfang(new Quadrat(2.5)));",
                 "output": "10.0"},
         group="t25-5"),
]

# ---------------------------------------------------------------- UML-Klassendiagramme
AMPEL_UML = diagram([
    box("Ampel",
        fields=[m("-", "farbe", "String"), m("-", "nummer", "int")],
        methods=[m("+", "umschalten()"), m("+", "getFarbe()", "String")]),
])

UML_BASICS = [
    mc("x-uml-1a", "umlbasics", 1, "Wie viele Fächer hat ein UML-Klassenkasten?",
       ["Drei: Name, Attribute, Methoden",
        "Zwei: Name und Inhalt",
        "Nur eines mit dem Klassennamen",
        "So viele, wie die Klasse Felder hat"],
       "Von oben nach unten: der Name der Klasse, darunter ihre Attribute (die Felder), ganz unten ihre "
       "Methoden. Leere Fächer lässt man manchmal weg – die Reihenfolge bleibt aber immer dieselbe.",
       diagram=PERSON,
       why=[None,
            "Attribute und Methoden stehen in getrennten Fächern, nicht zusammen in einem.",
            "Ein einzelnes Fach zeigt man nur, wenn Attribute und Methoden gerade nicht interessieren.",
            "Die Anzahl der Fächer hat mit der Anzahl der Felder nichts zu tun – alle Felder teilen sich eines."],
       group="t30-1"),
    mc("x-uml-2a", "umlbasics", 2, "Was bedeutet das Plus vor „+ getName(): String“?",
       ["Öffentlich – die Methode darf von überall aufgerufen werden",
        "Die Methode liefert eine Zahl zurück",
        "Die Methode ist neu hinzugekommen",
        "Die Methode darf nur innerhalb der Klasse benutzt werden"],
       "Das Pluszeichen steht für public. In UML gibt es drei solcher Zeichen: + öffentlich, - privat und "
       "# geschützt, also auch für die Kind-Klassen zugänglich.",
       diagram=PERSON,
       why=[None,
            "Was zurückkommt, steht hinter dem Doppelpunkt – hier String.",
            "Über das Alter einer Methode sagt UML nichts. Das Zeichen betrifft die Sichtbarkeit.",
            "Nur innerhalb der Klasse hieße privat, und dafür stünde dort ein Minus."],
    group="t30-2"),
    mc("x-uml-3a", "umlbasics", 3, "Welcher Java-Code passt zur Zeile „- nummer: int“ im Kasten Ampel?",
       ["private int nummer;",
        "public int nummer;",
        "int nummer();",
        "private nummer int;"],
       "In UML steht erst der Name, dann hinter dem Doppelpunkt der Typ – in Java ist es umgekehrt. "
       "Das Minus wird zu private, und weil keine runden Klammern dastehen, ist es ein Feld und keine Methode.",
       diagram=AMPEL_UML,
       why=[None,
            "public wäre ein Pluszeichen. Das Minus bedeutet ausdrücklich private.",
            "Die runden Klammern machen daraus eine Methode. Im Diagramm stehen hinter nummer keine.",
            "In Java steht der Typ vor dem Namen. Die UML-Reihenfolge darf man nicht einfach übernehmen."],
       group="t30-4"),
    fill("x-uml-4a", "umlbasics", 4, "Ergänze den Code zum Diagramm: beide Attribute und die Sichtbarkeit.",
         """
         class Ampel {
             {{0}} String farbe;
             private {{1}} nummer;

             public void umschalten() {
                 farbe = "gruen";
             }

             public String getFarbe() {
                 return farbe;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 Ampel a = new Ampel();
                 a.umschalten();
                 System.out.println(a.getFarbe());
             }
         }
         """,
         [["private"], ["int"]],
         "Das Minus im Kasten wird zu private, der Typ hinter dem Doppelpunkt wandert in Java nach vorn. "
         "Die beiden Methoden tragen ein Plus, also public – und weil hinter umschalten() kein Typ steht, "
         "gibt sie nichts zurück: void.",
         hint="Das Minus hat einen festen Namen in Java, und der Typ hinter dem Doppelpunkt wandert nach vorn.",
         diagram=AMPEL_UML,
         ctx="file",
         verify={"context": "file", "output": "gruen"},
         group="t30-4"),
    code("x-uml-4b", "umlbasics", 4,
         "Setze den Kasten Konto in Java um: ein privates Feld stand (double) und die beiden öffentlichen Methoden einzahlen() und getStand().",
         """
         // Klasse Konto nach dem Diagramm schreiben
         """,
         """
         class Konto {
             private double stand;

             public void einzahlen() {
                 stand = stand + 10;
             }

             public double getStand() {
                 return stand;
             }
         }
         """,
         [req(r"class\s+Konto", "Der Name im obersten Fach ist der Klassenname."),
          req(r"private\s+double\s+stand", "Das Minus bedeutet private, der Typ steht in Java vorn."),
          req(r"public\s+void\s+einzahlen\s*\(\s*\)", "Hinter einzahlen() steht kein Typ – also void, und das Plus heißt public."),
          req(r"public\s+double\s+getStand\s*\(\s*\)", "getStand() liefert laut Diagramm einen double zurück."),
          req(r"return\s+stand", "getStand() muss den Stand auch zurückgeben.")],
         "Ein Klassenkasten lässt sich Zeile für Zeile übersetzen: Name zu class, jedes Attribut zu einem "
         "Feld, jede Methode zu einem Methodenkopf. Steht hinter einer Methode kein Doppelpunkt mit Typ, "
         "gibt sie nichts zurück – das ist void.",
         diagram=KONTO,
         ctx="file",
         verify={"context": "file",
                 "main": "Konto k = new Konto();\nk.einzahlen();\nSystem.out.println(k.getStand());",
                 "output": "10.0"},
         group="t30-5"),
    code("x-uml-5a", "umlbasics", 5,
         "Setze den Kasten Ampel vollständig um – mit einem Konstruktor, der beide Felder füllt. umschalten() setzt die Farbe auf „gruen“.",
         """
         // Klasse Ampel nach dem Diagramm schreiben, dazu einen Konstruktor (String farbe, int nummer)
         """,
         """
         class Ampel {
             private String farbe;
             private int nummer;

             Ampel(String farbe, int nummer) {
                 this.farbe = farbe;
                 this.nummer = nummer;
             }

             public void umschalten() {
                 farbe = "gruen";
             }

             public String getFarbe() {
                 return farbe;
             }
         }
         """,
         [req(r"class\s+Ampel", "Der Name im obersten Fach ist der Klassenname."),
          req(r"private\s+String\s+farbe", "„- farbe: String“ wird zu einem privaten String-Feld."),
          req(r"private\s+int\s+nummer", "„- nummer: int“ wird zu einem privaten int-Feld."),
          req(r"Ampel\s*\(\s*String\s+farbe\s*,\s*int\s+nummer\s*\)", "Der Konstruktor heißt wie die Klasse und nimmt beide Werte entgegen."),
          req(r"this\.farbe\s*=", "Im Konstruktor unterscheidet this das Feld vom Parameter."),
          req(r"public\s+String\s+getFarbe\s*\(\s*\)", "getFarbe() liefert laut Diagramm einen String zurück.")],
         "Konstruktoren zeigt ein einfaches Klassendiagramm oft gar nicht – sie gehören trotzdem dazu, "
         "sobald ein Objekt seine Werte gleich beim Anlegen bekommen soll. Er trägt immer den Namen der "
         "Klasse und hat keinen Rückgabetyp, nicht einmal void.",
         diagram=AMPEL_UML,
         ctx="file",
         verify={"context": "file",
                 "main": 'Ampel a = new Ampel("rot", 1);\nSystem.out.println(a.getFarbe());\na.umschalten();\nSystem.out.println(a.getFarbe());',
                 "output": "rot\ngruen"},
         group="t30-5"),
    code("x-uml-5b", "umlbasics", 5,
         "Zeichne den Kasten in Java nach: Person mit privatem name (String) und privatem alter (int), dazu getName() und hatGeburtstag(), das das Alter um eins erhöht.",
         """
         // Klasse Person nach dem Diagramm schreiben, Felder im Konstruktor füllen
         """,
         """
         class Person {
             private String name;
             private int alter;

             Person(String name, int alter) {
                 this.name = name;
                 this.alter = alter;
             }

             public String getName() {
                 return name;
             }

             public void hatGeburtstag() {
                 alter++;
             }

             public int getAlter() {
                 return alter;
             }
         }
         """,
         [req(r"class\s+Person", "Der Name im obersten Fach ist der Klassenname."),
          req(r"private\s+String\s+name", "„- name: String“ wird zu einem privaten String-Feld."),
          req(r"private\s+int\s+alter", "„- alter: int“ wird zu einem privaten int-Feld."),
          req(r"public\s+String\s+getName\s*\(\s*\)", "getName() liefert laut Diagramm einen String."),
          req(r"public\s+void\s+hatGeburtstag\s*\(\s*\)", "Hinter hatGeburtstag() steht kein Typ – also void."),
          req(r"alter\s*(\+\+|\+=\s*1|=\s*alter\s*\+)", "Ein Geburtstag erhöht das Alter um eins.")],
         "Das Diagramm zeigt zwei Methoden: getName() liefert etwas zurück, erkennbar am Typ hinter dem "
         "Doppelpunkt. Bei hatGeburtstag() fehlt er – diese Methode verändert nur den Zustand des Objekts "
         "und gibt nichts zurück.",
         diagram=PERSON,
         ctx="file",
         verify={"context": "file",
                 "main": 'Person p = new Person("Ada", 35);\np.hatGeburtstag();\nSystem.out.println(p.getName() + " " + p.getAlter());',
                 "output": "Ada 36"},
         group="t30-5"),
]

# ---------------------------------------------------------------- UML-Beziehungen
UML_RELATIONS = [
    code("x-umlr-5a", "umlrelations", 5,
         "Setze das Diagramm um: Ein Haus besteht aus mindestens einem Raum. Die Räume entstehen im Konstruktor des Hauses und gehen mit ihm unter – lege sie dort an.",
         """
         class Raum {
             private double flaeche;

             Raum(double flaeche) {
                 this.flaeche = flaeche;
             }

             double getFlaeche() {
                 return flaeche;
             }
         }

         // Klasse Haus hier ergänzen: Adresse und eine Liste von Räumen
         """,
         """
         class Raum {
             private double flaeche;

             Raum(double flaeche) {
                 this.flaeche = flaeche;
             }

             double getFlaeche() {
                 return flaeche;
             }
         }

         class Haus {
             private String adresse;
             private List<Raum> raeume = new ArrayList<>();

             Haus(String adresse) {
                 this.adresse = adresse;
                 raeume.add(new Raum(20));
                 raeume.add(new Raum(15));
             }

             int anzahlRaeume() {
                 return raeume.size();
             }
         }
         """,
         [req(r"class\s+Haus", "Es fehlt die Klasse Haus."),
          req(r"private\s+String\s+adresse", "„- adresse: String“ wird zu einem privaten String-Feld."),
          req(r"List\s*<\s*Raum\s*>", "Die Vielfachheit 1..* bedeutet: mehrere Räume, also eine Liste."),
          req(r"new\s+Raum\s*\(", "Bei einer Komposition erzeugt das Ganze seine Teile selbst – mit new im Konstruktor."),
          req(r"raeume\.add", "Die erzeugten Räume gehören in die Liste.")],
         "Die gefüllte Raute steht für Komposition: Die Räume gehören untrennbar zum Haus. Deshalb "
         "erzeugt das Haus sie selbst im Konstruktor, statt sie von außen entgegenzunehmen – verschwindet "
         "das Haus, verschwinden auch die Räume. Die Vielfachheit 1..* wird in Java zu einer Liste.",
         diagram=HAUS,
         ctx="file",
         verify={"context": "file",
                 "main": 'Haus h = new Haus("Hauptstrasse 1");\nSystem.out.println(h.anzahlRaeume());',
                 "output": "2"},
         group="t32-5"),
    code("x-umlr-5b", "umlrelations", 5,
         "Setze das Diagramm um: Eine Bestellung gehört zu genau einem Kunden. Der Kunde wird der Bestellung von außen mitgegeben, nicht von ihr erzeugt.",
         """
         class Kunde {
             private String name;

             Kunde(String name) {
                 this.name = name;
             }

             String getName() {
                 return name;
             }
         }

         // Klasse Bestellung hier ergänzen: Nummer und der zugehörige Kunde
         """,
         """
         class Kunde {
             private String name;

             Kunde(String name) {
                 this.name = name;
             }

             String getName() {
                 return name;
             }
         }

         class Bestellung {
             private int nummer;
             private Kunde kunde;

             Bestellung(int nummer, Kunde kunde) {
                 this.nummer = nummer;
                 this.kunde = kunde;
             }

             String beschreibung() {
                 return nummer + " fuer " + kunde.getName();
             }
         }
         """,
         [req(r"class\s+Bestellung", "Es fehlt die Klasse Bestellung."),
          req(r"private\s+int\s+nummer", "„- nummer: int“ wird zu einem privaten int-Feld."),
          req(r"private\s+Kunde\s+kunde|Kunde\s+kunde\s*;", "Die Assoziation wird in Java zu einem Feld vom Typ Kunde."),
          req(r"Bestellung\s*\(\s*int\s+nummer\s*,\s*Kunde\s+kunde\s*\)", "Der Kunde kommt von außen – also in die Zutatenliste des Konstruktors."),
          forbid(r"new\s+Kunde", "Bei einer Assoziation erzeugt die Bestellung den Kunden nicht selbst; sie bekommt ihn mitgegeben.")],
         "Die einfache Linie ist eine Assoziation: „kennt“. Die Bestellung hält den Kunden als Feld fest, "
         "erzeugt ihn aber nicht – er existiert unabhängig von ihr und kann mehrere Bestellungen haben. "
         "Die Vielfachheit 1 bedeutet: genau einer, nicht null und nicht mehrere.",
         diagram=BESTELLUNG,
         ctx="file",
         verify={"context": "file",
                 "main": 'Bestellung b = new Bestellung(17, new Kunde("Ada"));\nSystem.out.println(b.beschreibung());',
                 "output": "17 fuer Ada"},
         group="t32-5"),
]

POOL_LEVEL_C = (IO + DATETIME + RECURSION + ALGORITHMS + DATASTRUCTURES
                + TESTING + TOOLING + PATTERNS + UML_BASICS + UML_RELATIONS)
