"""Übungsaufgaben außerhalb der Lektionen: Varianten und zusätzliche Aufgaben je Thema.

Der Lernpfad bleibt unverändert – diese Aufgaben speisen Übung, Endlos-Training und
freies Lernen. Aufgaben mit `group=` gehören zum selben Lernziel wie eine Lektionsaufgabe:
Pro Sitzung kommt aus einer Gruppe nur eine Variante dran. Wer eine Aufgabe falsch hatte,
bekommt beim nächsten Mal eine andere Variante – Verstehen statt Auswendiglernen.
"""
from authoring import c, code, fill, forbid, mc, out, req

# ---------------------------------------------------------------- Variablen & Datentypen
VARIABLES = [
    mc("p-var-1a", "variables", 1, "Welcher Typ speichert eine Zahl mit Nachkommastellen?",
       ["double", "int", "boolean", "char"],
       "double speichert Kommazahlen. int kann nur ganze Zahlen ohne Nachkommastellen.",
       group="t02-2"),
    mc("p-var-1b", "variables", 1, "Was passt in eine Box mit dem Etikett boolean?",
       ["true oder false", "Jede ganze Zahl", "Ein einzelnes Zeichen", "Beliebiger Text"],
       "boolean kennt nur zwei Werte: true (ja) und false (nein).",
       group="t02-1"),
    out("p-var-2a", "variables", 2, "Was wird ausgegeben?",
        """
        int punkte = 7;
        punkte = punkte + 3;
        System.out.println("Punkte: " + punkte);
        """,
        "Punkte: 10",
        "punkte wird auf 10 gesetzt. Mit + klebt Java Text und Zahl zu einem Text zusammen.",
        group="t02-3"),
    out("p-var-2b", "variables", 2, "Was wird ausgegeben?",
        """
        double preis = 2.5;
        int menge = 4;
        System.out.println(preis * menge);
        """,
        "10.0",
        "Sobald eine Kommazahl beteiligt ist, rechnet Java in double – deshalb 10.0 und nicht 10.",
        group="t02-2"),
    mc("p-var-3a", "variables", 3, "Warum lässt sich der Inhalt einer final-Box nicht mehr ändern?",
       ["final versiegelt die Box – der Wert bleibt für immer",
        "final macht die Box kleiner",
        "final wandelt die Box in Text um",
        "final löscht den Inhalt nach der Nutzung"],
       "final heißt: einmal gefüllt, für immer gleich. Genau richtig für Konstanten wie MWST.",
       group="t02-4"),
]

# ---------------------------------------------------------------- Operatoren
OPERATORS = [
    out("p-op-1a", "operators", 1, "Was wird ausgegeben?",
        """
        System.out.println(9 % 4);
        """,
        "1",
        "% liefert den Rest der Division: 9 = 2 · 4 + 1.",
        group="t03-1"),
    out("p-op-1b", "operators", 1, "Was wird ausgegeben?",
        """
        System.out.println(10 % 5);
        """,
        "0",
        "10 geht genau 2-mal in 5 · 2 auf – es bleibt kein Rest. Rest 0 heißt: teilbar.",
        group="t03-1"),
    out("p-op-2a", "operators", 2, "Was gibt dieses Programm aus?",
        """
        int a = 9;
        int b = 4;
        System.out.println(a / b);
        System.out.println(a % b);
        """,
        """
        2
        1
        """,
        "Ganzzahldivision schneidet ab: 9 / 4 = 2. Der Rest 1 kommt mit % heraus.",
        group="t03-2"),
    out("p-op-2b", "operators", 2, "Was wird ausgegeben?",
        """
        int zaehler = 5;
        zaehler += 3;
        zaehler++;
        System.out.println(zaehler);
        """,
        "9",
        "+= 3 macht 8 daraus, ++ zählt eins weiter: 9.",
        group="t03-3"),
    mc("p-op-3a", "operators", 3, "Wie rechnet man 7 geteilt durch 2 so, dass 3.5 herauskommt?",
       ["7 / 2.0", "7 / 2", "7 % 2", "(int) 7 / 2"],
       "Sobald eine Kommazahl beteiligt ist, rechnet Java in double. 7 / 2 wäre Ganzzahldivision und ergäbe 3.",
       group="t03-5"),
]

# ---------------------------------------------------------------- Bedingungen
CONDITIONALS = [
    out("p-if-1a", "conditionals", 2, "Was wird ausgegeben?",
        """
        int alter = 20;
        if (alter >= 18) {
            System.out.println("volljaehrig");
        } else {
            System.out.println("minderjaehrig");
        }
        """,
        "volljaehrig",
        "20 >= 18 ist wahr, deshalb läuft der if-Block und der else-Block wird übersprungen.",
        group="t04-2"),
    out("p-if-1b", "conditionals", 2, "Was wird ausgegeben?",
        """
        int temperatur = 3;
        if (temperatur > 20) {
            System.out.println("warm");
        } else if (temperatur > 10) {
            System.out.println("mild");
        } else {
            System.out.println("kalt");
        }
        """,
        "kalt",
        "3 > 20 ist falsch, 3 > 10 auch – deshalb bleibt nur der else-Block übrig.",
        group="t04-4"),
    fill("p-if-2a", "conditionals", 3, "Ergänze die Bedingung: Eine Zahl ist durch 3 teilbar, wenn der Rest bei Division durch 3 null ist.",
         """
         int zahl = 12;
         if (zahl {{0}} 3 == 0) {
             System.out.println("teilbar");
         }
         """,
         [["%"]],
         "zahl % 3 liefert den Rest. Ist er 0, ist die Zahl durch 3 teilbar.",
         verify={"output": "teilbar"},
         group="t04-3"),
    out("p-if-2b", "conditionals", 3, "Was wird ausgegeben?",
        """
        int punkte = 55;
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
        "bestanden",
        "Java prüft von oben nach unten. Die erste wahre Bedingung gewinnt: 55 >= 50.",
        group="t04-4"),
]

# ---------------------------------------------------------------- Schleifen
LOOPS = [
    out("p-loop-1a", "loops", 1, "Was gibt die Schleife aus?",
        """
        for (int i = 1; i <= 3; i++) {
            System.out.println(i);
        }
        """,
        """
        1
        2
        3
        """,
        "i startet bei 1 und läuft, solange i <= 3 gilt – also 1, 2, 3.",
        group="t05-1"),
    out("p-loop-1b", "loops", 2, "Was gibt die Schleife aus?",
        """
        int n = 3;
        while (n > 0) {
            System.out.print(n + " ");
            n--;
        }
        """,
        "3 2 1 ",
        "Die Schleife läuft rückwärts: n wird in jeder Runde um 1 kleiner, bei 0 endet sie.",
        group="t05-3"),
    out("p-loop-2a", "loops", 3, "Was wird ausgegeben?",
        """
        int summe = 0;
        for (int i = 1; i <= 5; i++) {
            summe += i;
        }
        System.out.println(summe);
        """,
        "15",
        "1 + 2 + 3 + 4 + 5 = 15. Die Box summe sammelt das Ergebnis über alle Runden ein.",
        group="t05-5"),
    out("p-loop-2b", "loops", 3, "Was wird ausgegeben?",
        """
        for (int i = 1; i <= 6; i++) {
            if (i % 2 == 0) {
                continue;
            }
            System.out.print(i + " ");
        }
        """,
        "1 3 5 ",
        "continue überspringt den Rest der Runde. Gerade Zahlen werden also nicht ausgegeben.",
        group="t05-4"),
    code("p-loop-3a", "loops", 4, "Gib mit einer Schleife die Zahlen von 10 bis 1 rückwärts aus, jede in einer eigenen Zeile.",
         "// Deine Schleife hier",
         """
         for (int i = 10; i >= 1; i--) {
             System.out.println(i);
         }
         """,
         [req(r"\b(for|while)\b", "Nutze eine Schleife."),
          req(r"System\.out\.println", "Gib jede Zahl mit println aus."),
          forbid(r"println\(10\);[\s\S]*println\(9\);", "Nicht alle Zahlen einzeln hinschreiben – lass die Schleife zählen.")],
         "Der Zähler startet bei 10 und wird mit i-- kleiner, bis die Bedingung i >= 1 nicht mehr gilt.",
         expected="\n".join(str(i) for i in range(10, 0, -1)),
         group="t05-5"),
]

# ---------------------------------------------------------------- Methoden
METHODS = [
    out("p-meth-1a", "methods", 2, "Was wird ausgegeben?",
        """
        static int verdreifache(int x) {
            return x * 3;
        }

        public static void main(String[] args) {
            System.out.println(verdreifache(4));
        }
        """,
        "12",
        "Das Rezept „verdreifache“ bekommt 4 als Zutat und gibt 4 * 3 = 12 zurück.",
        ctx="members",
        group="t06-2"),
    mc("p-meth-1b", "methods", 2, "Was bedeutet void als Rückgabetyp?",
       ["Die Methode gibt keinen Wert zurück",
        "Die Methode gibt immer 0 zurück",
        "Die Methode darf nicht aufgerufen werden",
        "Die Methode gibt einen leeren Text zurück"],
       "void heißt „nichts“: Das Rezept erledigt etwas, liefert aber kein Ergebnis zurück.",
       group="t06-1"),
    fill("p-meth-2a", "methods", 3, "Ergänze die Methode: Sie soll das Quadrat einer Zahl zurückgeben.",
         """
         static {{0}} quadrat(int zahl) {
             {{1}} zahl * zahl;
         }

         public static void main(String[] args) {
             System.out.println(quadrat(6));
         }
         """,
         [["int"], ["return"]],
         "Die Methode liefert eine ganze Zahl (int) und gibt sie mit return zurück: 6 · 6 = 36.",
         ctx="members",
         verify={"context": "members", "output": "36"},
         group="t06-3"),
    code("p-meth-3a", "methods", 4, "Schreibe die Methode istPositiv(int zahl), die true liefert, wenn die Zahl größer als 0 ist.",
         "// Deine Methode hier",
         """
         static boolean istPositiv(int zahl) {
             return zahl > 0;
         }
         """,
         [req(r"boolean\s+istPositiv\s*\(\s*int\s+\w+\s*\)", "Die Methode heißt istPositiv und liefert boolean."),
          req(r"return[^;]*>[^;]*0", "Vergleiche die Zahl mit 0.")],
         "Der Vergleich zahl > 0 ist selbst schon ein boolean und kann direkt zurückgegeben werden.",
         ctx="members",
         verify={"context": "members", "main": "System.out.println(istPositiv(5));", "output": "true"},
         group="t06-5"),
]

# ---------------------------------------------------------------- Arrays & Strings
ARRAYS = [
    out("p-arr-1a", "arrays", 1, "Was wird ausgegeben?",
        """
        int[] zahlen = {10, 20, 30};
        System.out.println(zahlen[0]);
        """,
        "10",
        "Java zählt die Fächer ab 0: In Fach 0 liegt die 10.",
        group="t07-1"),
    out("p-arr-1b", "arrays", 2, "Was wird ausgegeben?",
        """
        String[] namen = {"Ada", "Linus", "Grace"};
        System.out.println(namen.length);
        """,
        "3",
        "length ist die Anzahl der Fächer im Eierkarton – hier 3.",
        group="t07-1"),
    out("p-arr-2a", "arrays", 2, "Was gibt die Schleife aus?",
        """
        int[] werte = {2, 4, 6};
        for (int w : werte) {
            System.out.print(w + " ");
        }
        """,
        "2 4 6 ",
        "Die for-each-Schleife geht jedes Fach der Reihe nach durch – ganz ohne Zähler.",
        group="t07-3"),
    out("p-str-1a", "strings", 2, "Was wird ausgegeben?",
        """
        String wort = "JavaQuest";
        System.out.println(wort.length());
        """,
        "9",
        "length() zählt die Zeichen: J-a-v-a-Q-u-e-s-t sind 9.",
        group="t07-2"),
    out("p-str-1b", "strings", 3, "Was wird ausgegeben?",
        """
        String text = "Programmieren";
        System.out.println(text.substring(0, 7));
        """,
        "Program",
        "substring(0, 7) liefert die Zeichen ab Fach 0 bis vor Fach 7 – also die ersten sieben.",
        group="t07-4"),
    mc("p-str-2a", "strings", 3, "Womit vergleicht man zwei Strings auf gleichen Inhalt?",
       ["equals", "==", "compare", "="],
       "== fragt, ob es dasselbe Objekt ist. equals vergleicht den Inhalt – das ist bei Texten fast immer gemeint.",
       group="t07-4"),
]

# ---------------------------------------------------------------- Klassen & Objekte
OOP = [
    mc("p-oop-1a", "oop", 2, "Wozu dient der Konstruktor einer Klasse?",
       ["Er gibt dem neuen Objekt seine Startwerte",
        "Er löscht ein Objekt aus dem Speicher",
        "Er vergleicht zwei Objekte",
        "Er wandelt ein Objekt in Text um"],
       "Der Konstruktor ist die Backanleitung: Er läuft beim new und füllt die Fächer des neuen Objekts.",
       group="t08-1"),
    out("p-oop-1b", "oop", 3, "Was wird ausgegeben?",
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
        "a und b sind zwei unabhängige Objekte mit eigenen Fächern: a wurde zweimal geklickt, b einmal.",
        ctx="file",
        group="t08-3"),
    mc("p-oop-2a", "oop", 3, "Warum macht man Felder meist private?",
       ["Damit die Klasse selbst bestimmt, welche Werte erlaubt sind",
        "Damit das Programm schneller läuft",
        "Damit die Felder weniger Speicher brauchen",
        "Weil Java sonst einen Fehler meldet"],
       "private ist ein abgeschlossenes Fach: Von außen kommt man nur über Methoden heran, die die Klasse kontrolliert.",
       group="t08-5"),
]

# ---------------------------------------------------------------- Vererbung & Interfaces
INHERITANCE = [
    mc("p-inh-1a", "inheritance", 2, "Mit welchem Schlüsselwort setzt eine Klasse ein Interface um?",
       ["implements", "extends", "super", "new"],
       "extends erweitert eine Eltern-Klasse, implements unterschreibt einen Vertrag (Interface).",
       group="t09-1"),
    out("p-inh-1b", "inheritance", 3, "Was wird ausgegeben?",
        """
        class Tier {
            String laut() {
                return "...";
            }
        }

        class Kuh extends Tier {
            @Override
            String laut() {
                return "Muh";
            }
        }

        public class Main {
            public static void main(String[] args) {
                Tier t = new Kuh();
                System.out.println(t.laut());
            }
        }
        """,
        "Muh",
        "Auf dem Etikett steht Tier, drin liegt eine Kuh – und die antwortet mit ihrer eigenen Methode.",
        ctx="file",
        group="t09-3"),
    mc("p-inh-2a", "inheritance", 3, "Wofür steht super(…) im Konstruktor?",
       ["Es ruft den Konstruktor der Eltern-Klasse auf",
        "Es erzeugt ein zweites Objekt",
        "Es löscht geerbte Methoden",
        "Es macht die Klasse abstrakt"],
       "super(…) reicht die Startwerte an die Eltern-Klasse weiter, bevor die Kind-Klasse weitermacht.",
       group="t09-5"),
]

# ---------------------------------------------------------------- Exceptions
EXCEPTIONS = [
    out("p-exc-1a", "exceptions", 2, "In welcher Reihenfolge erscheinen die Texte?",
        """
        try {
            System.out.println("start");
            int x = 1 / 0;
            System.out.println("nie");
        } catch (ArithmeticException e) {
            System.out.println("gefangen");
        }
        """,
        """
        start
        gefangen
        """,
        "Nach „start“ knallt die Division durch 0. Der Rest im try-Block wird übersprungen, das Sicherheitsnetz catch fängt den Alarm auf.",
        group="t10-2"),
    mc("p-exc-1b", "exceptions", 3, "Was bedeutet es, dass IOException eine checked Exception ist?",
       ["Man muss sie auffangen oder mit throws ankündigen",
        "Sie tritt nur beim Rechnen auf",
        "Sie beendet das Programm immer sofort",
        "Sie kann nicht gefangen werden"],
       "Bei checked Exceptions besteht Java darauf, dass du dich kümmerst – sonst meckert schon der Compiler. Unchecked Exceptions (von RuntimeException abstammend) verlangt Java nicht.",
       group="t10-3"),
    fill("p-exc-2a", "exceptions", 3, "Ergänze das Sicherheitsnetz für die Division durch 0.",
         """
         {{0}} {
             System.out.println(10 / 0);
         } {{1}} (ArithmeticException e) {
             System.out.println("Fehler aufgefangen");
         }
         """,
         [["try"], ["catch"]],
         "Im try-Block steht der riskante Code, catch fängt den Alarm auf.",
         verify={"output": "Fehler aufgefangen"},
         group="t10-1"),
]

# ---------------------------------------------------------------- Collections & Generics
COLLECTIONS = [
    out("p-col-1a", "collections", 2, "Was wird ausgegeben?",
        """
        List<String> liste = new ArrayList<>();
        liste.add("a");
        liste.add("b");
        System.out.println(liste.size());
        """,
        "2",
        "add hängt hinten an, size zählt die Einträge – hier 2.",
        group="t11-1"),
    out("p-col-1b", "collections", 3, "Was wird ausgegeben?",
        """
        List<String> liste = new ArrayList<>(List.of("Tee", "Kakao", "Saft"));
        liste.remove(0);
        System.out.println(liste);
        """,
        "[Kakao, Saft]",
        "remove(0) streicht den ersten Eintrag. Die übrigen rücken auf, die Ausgabe steht in eckigen Klammern.",
        group="t11-3"),
    out("p-col-2a", "collections", 3, "Was wird ausgegeben?",
        """
        Map<String, Integer> alter = new HashMap<>();
        alter.put("Ada", 36);
        alter.put("Ada", 37);
        System.out.println(alter.get("Ada"));
        """,
        "37",
        "put mit demselben Schlüssel überschreibt den alten Wert – im Wörterbuch steht jeder Schlüssel nur einmal.",
        group="t11-4"),
    mc("p-col-2b", "generics", 3, "Was sagt das <String> in List<String> aus?",
       ["Nur Texte dürfen in die Liste",
        "Die Liste hat höchstens String-viele Plätze",
        "Die Liste wandelt alles in Text um",
        "Die Liste ist nach Text sortiert"],
       "Die spitzen Klammern sind das Etikett der Sammlung: Sie legen fest, was hinein darf. Java prüft das schon beim Übersetzen.",
       group="t11-2"),
    out("p-col-3a", "collections", 4, "Was wird ausgegeben?",
        """
        Map<String, Integer> zaehler = new HashMap<>();
        zaehler.put("a", 1);
        System.out.println(zaehler.getOrDefault("b", 0));
        """,
        "0",
        "Den Schlüssel „b“ gibt es nicht – getOrDefault liefert dann den Ersatzwert 0 statt null.",
        group="t11-4"),
]

# ---------------------------------------------------------------- Lambdas & Streams
LAMBDAS = [
    out("p-lam-1a", "lambdas", 3, "Was wird ausgegeben?",
        """
        List<Integer> zahlen = List.of(1, 2, 3, 4);
        zahlen.stream()
                .filter(z -> z % 2 == 0)
                .forEach(z -> System.out.print(z + " "));
        """,
        "2 4 ",
        "filter lässt nur gerade Zahlen aufs Band, forEach gibt jede davon aus.",
        group="t12-3"),
    out("p-lam-1b", "lambdas", 4, "Was wird ausgegeben?",
        """
        List<String> woerter = List.of("hut", "bus");
        List<String> gross = woerter.stream()
                .map(String::toUpperCase)
                .toList();
        System.out.println(gross);
        """,
        "[HUT, BUS]",
        "map wandelt jedes Element um – hier jedes Wort in Großbuchstaben.",
        group="t12-4"),
    out("p-lam-2a", "lambdas", 4, "Was wird ausgegeben?",
        """
        List<Integer> zahlen = List.of(2, 3, 4);
        int summe = zahlen.stream()
                .mapToInt(z -> z * z)
                .sum();
        System.out.println(summe);
        """,
        "29",
        "Jede Zahl wird quadriert (4, 9, 16) und dann zusammengezählt: 29.",
        group="t12-5"),
]

# ---------------------------------------------------------------- Modernes Java
MODERN = [
    out("p-mod-1a", "modern", 2, "Was wird ausgegeben?",
        """
        record Buch(String titel, int jahr) {}

        public class Main {
            public static void main(String[] args) {
                Buch b = new Buch("Momo", 1973);
                System.out.println(b.titel());
            }
        }
        """,
        "Momo",
        "Der Record erzeugt automatisch die Lesemethode titel() – Setter gibt es bewusst nicht.",
        ctx="file",
        group="t13-1"),
    out("p-mod-1b", "modern", 3, "Was wird ausgegeben?",
        """
        Optional<String> leer = Optional.empty();
        System.out.println(leer.orElse("Ersatz"));
        """,
        "Ersatz",
        "Die Schachtel ist leer – orElse liefert dann den Ersatzwert statt eines Alarms.",
        group="t13-3"),
]

# ---------------------------------------------------------------- Enums, Rekursion, Sortieren, Mengen
ADVANCED = [
    out("p-enum-1a", "enums", 2, "Was wird ausgegeben?",
        """
        enum Ampel { ROT, GELB, GRUEN }

        public class Main {
            public static void main(String[] args) {
                Ampel a = Ampel.GELB;
                System.out.println(a);
                System.out.println(a.ordinal());
            }
        }
        """,
        """
        GELB
        1
        """,
        "println zeigt den Namen des Werts. ordinal() ist die Position – gezählt ab 0: ROT = 0, GELB = 1.",
        ctx="file",
        group="t14-2"),
    out("p-rec-1a", "recursion", 3, "Was wird ausgegeben?",
        """
        static int summe(int n) {
            if (n == 0) {
                return 0;
            }
            return n + summe(n - 1);
        }

        public static void main(String[] args) {
            System.out.println(summe(3));
        }
        """,
        "6",
        "summe(3) = 3 + summe(2) = 3 + 2 + summe(1) = 3 + 2 + 1 + 0 = 6. Ohne den Basisfall n == 0 würde es nie enden.",
        ctx="members",
        group="t18-2"),
    out("p-sort-1a", "algorithms", 3, "Was wird ausgegeben?",
        """
        int[] zahlen = {4, 1, 3};
        Arrays.sort(zahlen);
        System.out.println(Arrays.toString(zahlen));
        """,
        "[1, 3, 4]",
        "Arrays.sort sortiert aufsteigend an Ort und Stelle; toString macht daraus einen lesbaren Text.",
        group="t19-3"),
    out("p-set-1a", "datastructures", 3, "Was wird ausgegeben?",
        """
        Set<String> menge = new HashSet<>();
        menge.add("ja");
        menge.add("ja");
        menge.add("nein");
        System.out.println(menge.size());
        """,
        "2",
        "Ein Set ist wie ein Stempelheft: Jeder Eintrag kommt höchstens einmal vor – „ja“ zählt also nur einmal.",
        group="t20-5"),
    out("p-set-1b", "datastructures", 3, "Was wird ausgegeben?",
        """
        Deque<Integer> stapel = new ArrayDeque<>();
        stapel.push(1);
        stapel.push(2);
        System.out.println(stapel.pop());
        """,
        "2",
        "Beim Tellerstapel kommt zuerst weg, was zuletzt draufkam: pop liefert die 2.",
        group="t20-3"),
]

POOL = (
    VARIABLES + OPERATORS + CONDITIONALS + LOOPS + METHODS + ARRAYS
    + OOP + INHERITANCE + EXCEPTIONS + COLLECTIONS + LAMBDAS + MODERN + ADVANCED
)
