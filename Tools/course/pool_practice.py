"""Übungspool, Teil 5: selber schreiben statt nur lesen.

Gleicht die Aufgabentypen aus: viele Lückentexte und Schreibaufgaben,
dazu bewusst sehr leichte (Niveau 1) und schwere Aufgaben (Niveau 5).
"""
from authoring import code, fill, forbid, mc, out, req

# ---------------------------------------------------------------- Niveau 1: der sanfte Einstieg
EASY = [
    mc("s-easy-1", "syntax", 1, "Was gehört um einen Text in Java?",
       ["Doppelte Anführungszeichen \"…\"", "Einfache Anführungszeichen '…'",
        "Runde Klammern (…)", "Gar nichts"],
       "Text steht in doppelten Anführungszeichen. Einfache umschließen genau ein Zeichen (char).",
       group="t01-2"),
    mc("s-easy-2", "variables", 1, "Welcher Typ passt für die Anzahl der Schüler in einer Klasse?",
       ["int", "double", "String", "boolean"],
       "Schüler zählt man in ganzen Zahlen – dafür ist int da. double hätte unnötige Nachkommastellen.",
       group="t02-1"),
    mc("s-easy-3", "operators", 1, "Was ergibt 6 * 7?",
       ["42", "13", "67", "0"],
       "* ist das Malzeichen. Java rechnet wie ein Taschenrechner, Punkt vor Strich inklusive.",
       group="t03-1"),
    mc("s-easy-4", "conditionals", 1, "Was steht in den Klammern von if (…)?",
       ["Eine Frage, die true oder false ergibt", "Ein beliebiger Text",
        "Der Name einer Methode", "Eine Zahl zwischen 0 und 1"],
       "if erwartet eine Ja-Nein-Frage. Ein Vergleich wie alter >= 18 liefert genau das.",
       group="t04-1"),
    mc("s-easy-5", "loops", 1, "Wofür ist eine Schleife da?",
       ["Sie wiederholt Anweisungen mehrmals", "Sie speichert Werte",
        "Sie beendet das Programm", "Sie erzeugt ein Objekt"],
       "Statt dieselbe Zeile zehnmal zu schreiben, lässt man die Schleife zehn Runden drehen.",
       group="t05-1"),
    mc("s-easy-6", "methods", 1, "Was bedeutet return in einer Methode?",
       ["Das Rezept ist fertig und gibt sein Ergebnis zurück",
        "Die Methode wird neu gestartet", "Die Zeile wird übersprungen",
        "Das Programm endet"],
       "return beendet die Methode und reicht den Wert an die Stelle zurück, die sie aufgerufen hat.",
       group="t06-1"),
    mc("s-easy-7", "arrays", 1, "Mit welchem Index beginnt das erste Fach eines Arrays?",
       ["0", "1", "-1", "Mit dem Namen des Arrays"],
       "Java zählt ab 0. Das erste Fach ist zahlen[0], das fünfte zahlen[4].",
       group="t07-1"),
    mc("s-easy-8", "oop", 1, "Was entsteht beim Aufruf von new Hund();?",
       ["Ein neues Objekt nach dem Bauplan der Klasse", "Eine neue Klasse",
        "Eine neue Methode", "Eine Kopie des Programms"],
       "Die Klasse ist die Kuchenform, new backt daraus einen echten Kuchen – das Objekt.",
       group="t08-1"),
    mc("s-easy-9", "collections", 1, "Was kann eine ArrayList, was ein Array nicht kann?",
       ["Sie wächst, wenn man Einträge hinzufügt", "Sie speichert Zahlen",
        "Sie hat einen Index", "Sie lässt sich durchlaufen"],
       "Der Eierkarton hat eine feste Zahl an Fächern. Der Einkaufszettel bekommt einfach eine Zeile mehr.",
       group="t11-1"),
    mc("s-easy-10", "exceptions", 1, "Wozu dient ein try-Block?",
       ["Er umschließt Code, bei dem etwas schiefgehen kann",
        "Er wiederholt Code so lange, bis er klappt",
        "Er beschleunigt das Programm", "Er beendet das Programm sicher"],
       "Im try steht der riskante Teil. Geht etwas schief, fängt das catch darunter den Alarm auf.",
       group="t10-1"),
]

# ---------------------------------------------------------------- Lückentexte
FILLS = [
    fill("s-fill-1", "variables", 2, "Ergänze Typ und Wert: alter soll die ganze Zahl 30 enthalten.",
         """
         {{0}} alter = {{1}};
         System.out.println(alter);
         """,
         [["int"], ["30"]],
         "int ist das Etikett für ganze Zahlen, danach kommt der Wert in die Box.",
         verify={"output": "30"},
         group="t02-1"),
    fill("s-fill-2", "variables", 3, "Ergänze das Schlüsselwort, damit der Wert nicht mehr geändert werden darf.",
         """
         {{0}} double MWST = 0.19;
         System.out.println(MWST);
         """,
         [["final"]],
         "final versiegelt die Box: Der Inhalt bleibt für immer gleich – typisch für Konstanten.",
         verify={"output": "0.19"},
         group="t02-4"),
    fill("s-fill-3", "operators", 2, "Ergänze die Kurzform, die den Inhalt um 5 erhöht.",
         """
         int punkte = 10;
         punkte {{0}} 5;
         System.out.println(punkte);
         """,
         [["+="]],
         "punkte += 5 ist die Kurzform für punkte = punkte + 5.",
         verify={"output": "15"},
         group="t03-3"),
    fill("s-fill-4", "conditionals", 2, "Ergänze die Schlüsselwörter für die Verzweigung.",
         """
         int alter = 12;
         {{0}} (alter >= 18) {
             System.out.println("volljaehrig");
         } {{1}} {
             System.out.println("minderjaehrig");
         }
         """,
         [["if"], ["else"]],
         "if stellt die Frage, else fängt alle übrigen Fälle auf.",
         verify={"output": "minderjaehrig"},
         group="t04-1"),
    fill("s-fill-5", "loops", 2, "Ergänze die drei Teile der for-Schleife: Start bei 1, laufen bis 3, jede Runde eins hoch.",
         """
         for (int i = {{0}}; i {{1}} 3; i{{2}}) {
             System.out.print(i);
         }
         """,
         [["1"], ["<="], ["++"]],
         "Die drei Teile sind Start, Bedingung und Schritt – getrennt durch Semikolons.",
         verify={"output": "123"},
         group="t05-1"),
    fill("s-fill-6", "loops", 3, "Ergänze die Schleife, die läuft, solange n größer als 0 ist.",
         """
         int n = 3;
         {{0}} (n > 0) {
             System.out.print(n);
             n--;
         }
         """,
         [["while"]],
         "while prüft vor jeder Runde. Ist die Antwort schon am Anfang nein, läuft der Block gar nicht.",
         verify={"output": "321"},
         group="t05-3"),
    fill("s-fill-7", "methods", 3, "Ergänze Rückgabetyp und Rückgabe: Die Methode liefert den doppelten Wert.",
         """
         static {{0}} doppelt(int zahl) {
             {{1}} zahl * 2;
         }

         public static void main(String[] args) {
             System.out.println(doppelt(7));
         }
         """,
         [["int"], ["return"]],
         "Der Rückgabetyp steht vor dem Namen, return liefert das Ergebnis zurück: 7 · 2 = 14.",
         ctx="members",
         verify={"context": "members", "output": "14"},
         group="t06-3"),
    fill("s-fill-8", "arrays", 3, "Ergänze die for-each-Schleife über alle Fächer.",
         """
         int[] werte = {2, 4};
         for (int w {{0}} werte) {
             System.out.print(w);
         }
         """,
         [[":"]],
         "Der Doppelpunkt liest sich als „für jedes w in werte“ – ganz ohne Zähler.",
         verify={"output": "24"},
         group="t07-3"),
    fill("s-fill-9", "strings", 3, "Ergänze die Methode, die den Text in Großbuchstaben liefert.",
         """
         String wort = "java";
         System.out.println(wort.{{0}}());
         """,
         [["toUpperCase"]],
         "toUpperCase liefert einen neuen Text in Großbuchstaben; das Original bleibt unverändert.",
         verify={"output": "JAVA"},
         group="t07-2"),
    fill("s-fill-10", "oop", 3, "Ergänze das Schlüsselwort, das Feld und Zutat unterscheidet.",
         """
         class Hund {
             String name;

             Hund(String name) {
                 {{0}}.name = name;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Hund("Rex").name);
             }
         }
         """,
         [["this"]],
         "this.name ist das Fach des Objekts, name allein die mitgegebene Zutat mit demselben Namen.",
         ctx="file",
         verify={"context": "file", "output": "Rex"},
         group="t08-2"),
    fill("s-fill-11", "inheritance", 3, "Ergänze die Schlüsselwörter für Vererbung und Überschreibung.",
         """
         class Tier {
             String laut() {
                 return "...";
             }
         }

         class Katze {{0}} Tier {
             {{1}}
             String laut() {
                 return "Miau";
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Katze().laut());
             }
         }
         """,
         [["extends"], ["@Override"]],
         "extends erweitert die Eltern-Klasse, @Override ist der Hinweiszettel, den Java prüft.",
         ctx="file",
         verify={"context": "file", "output": "Miau"},
         group="t09-1"),
    fill("s-fill-12", "collections", 3, "Ergänze die Methoden zum Hinzufügen und Zählen.",
         """
         List<String> liste = new ArrayList<>();
         liste.{{0}}("Tee");
         liste.{{0}}("Kakao");
         System.out.println(liste.{{1}}());
         """,
         [["add"], ["size"]],
         "add hängt hinten an, size zählt die Einträge – beides typisch für Listen.",
         verify={"output": "2"},
         group="t11-1"),
    fill("s-fill-13", "collections", 4, "Ergänze die Methoden des Wörterbuchs: eintragen und nachschlagen.",
         """
         Map<String, Integer> alter = new HashMap<>();
         alter.{{0}}("Ada", 36);
         System.out.println(alter.{{1}}("Ada"));
         """,
         [["put"], ["get"]],
         "put trägt ein Paar aus Schlüssel und Wert ein, get schlägt den Wert zum Schlüssel nach.",
         verify={"output": "36"},
         group="t11-4"),
    fill("s-fill-14", "lambdas", 4, "Ergänze die Stationen des Fließbands: sieben und umwandeln.",
         """
         List<Integer> zahlen = List.of(1, 2, 3, 4);
         List<Integer> ergebnis = zahlen.stream()
                 .{{0}}(z -> z % 2 == 0)
                 .{{1}}(z -> z * 10)
                 .toList();
         System.out.println(ergebnis);
         """,
         [["filter"], ["map"]],
         "filter siebt aus, map wandelt um. Übrig bleiben 2 und 4, verzehnfacht also 20 und 40.",
         verify={"output": "[20, 40]"},
         group="t12-3"),
    fill("s-fill-15", "enums", 3, "Ergänze das Schlüsselwort für eine feste Auswahl.",
         """
         {{0}} Ampel { ROT, GELB, GRUEN }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(Ampel.ROT);
             }
         }
         """,
         [["enum"]],
         "Ein enum zählt alle erlaubten Werte auf – mehr gibt es nicht, Tippfehler fallen sofort auf.",
         ctx="file",
         verify={"context": "file", "output": "ROT"},
         group="t14-1"),
    fill("s-fill-16", "objectmethods", 4, "Ergänze die Methode, die bestimmt, was println ausgibt.",
         """
         class Stadt {
             String name = "Kiel";

             @Override
             public String {{0}}() {
                 return "Stadt: " + name;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Stadt());
             }
         }
         """,
         [["toString"]],
         "println fragt jedes Objekt nach seiner toString-Methode. Ohne eigene erscheint Klassenname@Nummer.",
         ctx="file",
         verify={"context": "file", "output": "Stadt: Kiel"},
         group="t15-1"),
    fill("s-fill-17", "datastructures", 3, "Ergänze die Methoden des Tellerstapels: drauflegen und abnehmen.",
         """
         Deque<Integer> stapel = new ArrayDeque<>();
         stapel.{{0}}(1);
         stapel.{{0}}(2);
         System.out.println(stapel.{{1}}());
         """,
         [["push"], ["pop"]],
         "push legt oben drauf, pop nimmt oben weg – zuletzt drauf heißt zuerst weg.",
         verify={"output": "2"},
         group="t20-3"),
    fill("s-fill-18", "recursion", 4, "Ergänze Basisfall und rekursiven Aufruf für die Summe von 1 bis n.",
         """
         static int summe(int n) {
             if (n {{0}} 0) {
                 return 0;
             }
             return n + summe(n {{1}} 1);
         }

         public static void main(String[] args) {
             System.out.println(summe(4));
         }
         """,
         [["=="], ["-"]],
         "Bei 0 hört die Kette auf. Sonst ruft sich das Rezept mit einer kleineren Zahl auf: 4+3+2+1 = 10.",
         ctx="members",
         verify={"context": "members", "output": "10"},
         group="t18-4"),
    fill("s-fill-19", "concurrency", 4, "Ergänze: Den Thread loslaufen lassen und auf ihn warten.",
         """
         Thread helfer = new Thread(() -> System.out.println("fertig"));
         helfer.{{0}}();
         helfer.{{1}}();
         System.out.println("weiter");
         """,
         [["start"], ["join"]],
         "start lässt den zweiten Arbeitsstrang loslaufen, join wartet auf sein Ende – erst dann geht es weiter.",
         verify={"output": "fertig\nweiter"},
         group="t23-4"),
    fill("s-fill-20", "modern", 4, "Ergänze die Sorten-Prüfung mit Namensschild.",
         """
         Object o = "Java";
         if (o {{0}} String s) {
             System.out.println(s.length());
         }
         """,
         [["instanceof"]],
         "instanceof String s prüft die Sorte und gibt dem Wert gleich das Namensschild s – ohne Umwandeln.",
         verify={"output": "4"},
         group="t13-5"),
]

# ---------------------------------------------------------------- Selber schreiben
CODING = [
    code("s-code-1", "variables", 2, "Lege eine Box preis mit der Kommazahl 4.99 an und gib sie aus.",
         "// Deine Zeilen hier",
         """
         double preis = 4.99;
         System.out.println(preis);
         """,
         [req(r"double\s+preis", "Nutze den Typ double für Kommazahlen."),
          req(r"4\.99", "Lege 4.99 hinein."),
          req(r"System\.out\.println", "Gib den Wert aus.")],
         "Kommazahlen brauchen double. Mit float müsste am Ende ein f stehen (4.99f).",
         expected="4.99",
         group="t02-2"),
    code("s-code-2", "loops", 3, "Gib mit einer Schleife die Vielfachen von 3 bis 15 aus, durch Leerzeichen getrennt.",
         "// Deine Schleife hier",
         """
         for (int i = 3; i <= 15; i += 3) {
             System.out.print(i + " ");
         }
         """,
         [req(r"\bfor\b", "Nutze eine for-Schleife."),
          req(r"\+=\s*3|i\s*=\s*i\s*\+\s*3", "Zähle in Dreierschritten."),
          forbid(r"print\(3 6 9", "Nicht die Zahlen hinschreiben – lass die Schleife zählen.")],
         "Der Zähler startet bei 3 und springt jede Runde um 3 weiter, bis er 15 überschreitet.",
         expected="3 6 9 12 15 ",
         group="t05-1"),
    code("s-code-3", "methods", 3, "Schreibe die Methode mittelwert(int a, int b), die den Durchschnitt als double zurückgibt.",
         "// Deine Methode hier",
         """
         static double mittelwert(int a, int b) {
             return (a + b) / 2.0;
         }
         """,
         [req(r"double\s+mittelwert\s*\(\s*int\s+\w+\s*,\s*int\s+\w+\s*\)", "Die Methode heißt mittelwert und liefert double."),
          req(r"2\.0|\(double\)", "Verhindere die Ganzzahldivision – teile durch 2.0.")],
         "Mit / 2 wäre es eine Ganzzahldivision. 2.0 zwingt Java, in Kommazahlen zu rechnen.",
         ctx="members",
         verify={"context": "members", "main": "System.out.println(mittelwert(3, 4));", "output": "3.5"},
         group="t06-5"),
    code("s-code-4", "arrays", 4, "Bilde die Summe aller Fächer und gib sie aus.",
         """
         int[] zahlen = {2, 5, 9};
         // Summe berechnen und ausgeben
         """,
         """
         int[] zahlen = {2, 5, 9};
         int summe = 0;
         for (int z : zahlen) {
             summe += z;
         }
         System.out.println(summe);
         """,
         [req(r"\bfor\b", "Geh mit einer Schleife durch alle Fächer."),
          req(r"\+=|=\s*\w+\s*\+", "Addiere jeden Wert auf."),
          forbid(r"println\(16\)", "Nicht die Antwort hinschreiben – lass Java rechnen.")],
         "Eine Box sammelt die Summe ein: Sie startet bei 0 und wächst mit jedem Fach.",
         expected="16",
         group="t07-5"),
    code("s-code-5", "collections", 4, "Lege eine Liste mit „rot“ und „blau“ an und gib jeden Eintrag in einer eigenen Zeile aus.",
         "// Liste anlegen, füllen und ausgeben",
         """
         List<String> farben = new ArrayList<>();
         farben.add("rot");
         farben.add("blau");
         for (String f : farben) {
             System.out.println(f);
         }
         """,
         [req(r"new\s+ArrayList", "Lege eine ArrayList an."),
          req(r"\.add\(", "Füge die Einträge mit add hinzu."),
          req(r"\bfor\b", "Geh die Liste mit einer Schleife durch.")],
         "Die Liste wächst mit jedem add. Die for-each-Schleife holt danach jeden Eintrag der Reihe nach.",
         expected="rot\nblau",
         group="t11-1"),
    code("s-code-6", "lambdas", 4, "Gib mit einem Stream nur die Wörter mit mehr als vier Zeichen aus.",
         """
         List<String> woerter = List.of("Hut", "Apfel", "Banane");
         // Stream mit filter und forEach
         """,
         """
         List<String> woerter = List.of("Hut", "Apfel", "Banane");
         woerter.stream()
                 .filter(w -> w.length() > 4)
                 .forEach(w -> System.out.println(w));
         """,
         [req(r"\.stream\(\)", "Leg die Liste aufs Fließband mit stream()."),
          req(r"\.filter\(", "Siebe mit filter."),
          req(r"forEach|println", "Gib die übrigen Wörter aus.")],
         "filter lässt nur Wörter mit mehr als vier Zeichen durch: Apfel (5) und Banane (6).",
         expected="Apfel\nBanane",
         group="t12-4"),
    code("s-code-7", "oop", 5, "Schreibe die Klasse Konto mit privatem Feld stand, der Methode einzahlen(double) und getStand().",
         "// Deine Klasse hier",
         """
         class Konto {
             private double stand;

             void einzahlen(double betrag) {
                 stand = stand + betrag;
             }

             double getStand() {
                 return stand;
             }
         }
         """,
         [req(r"class\s+Konto", "Schreibe die Klasse Konto."),
          req(r"private\s+double\s+stand", "Das Feld stand soll privat sein."),
          req(r"einzahlen\s*\(\s*double\s+\w+\s*\)", "Ergänze die Methode einzahlen(double)."),
          req(r"double\s+getStand\s*\(\s*\)", "Ergänze getStand().")],
         "Das Feld bleibt privat, verändert wird es nur über einzahlen – so behält die Klasse die Kontrolle.",
         ctx="file",
         verify={"context": "file", "main": "Konto k = new Konto(); k.einzahlen(20); System.out.println(k.getStand());", "output": "20.0"},
         group="t08-5"),
    code("s-code-8", "exceptions", 5, "Teile 10 durch jede Zahl im Array und gib das Ergebnis aus. Fange die Division durch 0 ab und gib dort „nicht teilbar“ aus.",
         """
         int[] teiler = {2, 0, 5};
         // Schleife mit try/catch
         """,
         """
         int[] teiler = {2, 0, 5};
         for (int t : teiler) {
             try {
                 System.out.println(10 / t);
             } catch (ArithmeticException e) {
                 System.out.println("nicht teilbar");
             }
         }
         """,
         [req(r"\bfor\b", "Geh mit einer Schleife durch alle Fächer."),
          req(r"\btry\b", "Der riskante Teil gehört in einen try-Block."),
          req(r"catch\s*\(\s*ArithmeticException", "Fange die ArithmeticException ab.")],
         "Das Sicherheitsnetz steht in der Schleife – so läuft sie nach dem Alarm mit der nächsten Zahl weiter.",
         expected="5\nnicht teilbar\n2",
         group="t10-5"),
    code("s-code-9", "algorithms", 5, "Zähle, wie oft „a“ in dem Wort vorkommt, und gib die Zahl aus.",
         """
         String wort = "Banane";
         // Zählen und ausgeben
         """,
         """
         String wort = "Banane";
         int anzahl = 0;
         for (int i = 0; i < wort.length(); i++) {
             if (wort.charAt(i) == 'a') {
                 anzahl++;
             }
         }
         System.out.println(anzahl);
         """,
         [req(r"\bfor\b", "Geh mit einer Schleife durch alle Zeichen."),
          req(r"charAt", "Hol jedes Zeichen mit charAt."),
          forbid(r"println\(2\)", "Nicht die Antwort hinschreiben – lass Java zählen.")],
         "charAt(i) holt das Zeichen aus Fach i: In „Banane“ steht zweimal ein a. Ein einzelnes Zeichen "
         "gehört in einfache Anführungszeichen.",
         expected="2",
         group="t19-4"),
    code("s-code-10", "datastructures", 5, "Gib die Wörter ohne Doppelte alphabetisch sortiert aus.",
         """
         List<String> woerter = List.of("Birne", "Apfel", "Birne");
         // TreeSet nutzen und ausgeben
         """,
         """
         List<String> woerter = List.of("Birne", "Apfel", "Birne");
         Set<String> sortiert = new TreeSet<>(woerter);
         System.out.println(sortiert);
         """,
         [req(r"new\s+TreeSet", "Nutze ein TreeSet."),
          req(r"System\.out\.println", "Gib die Menge aus.")],
         "Das TreeSet nimmt jeden Eintrag nur einmal und hält alles automatisch sortiert.",
         expected="[Apfel, Birne]",
         group="t20-2"),
]

POOL_PRACTICE = EASY + FILLS + CODING
