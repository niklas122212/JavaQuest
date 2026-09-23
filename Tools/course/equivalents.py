# Gleichwertige Lösungen für die Code-Aufgaben.
#
# Jede Lösung hier ist richtig: Sie übersetzt und liefert genau das, was die Aufgabe
# verlangt – nur auf einem anderen Weg als die Musterlösung. Eine Schleife als while
# statt als for, eine Summe über den Index statt mit for-each, ein ausgeschriebenes
# if statt des kurzen Vergleichs.
#
# Sie sind der Gegentest zu den Prüfregeln. Ein Prüfer ohne Compiler kann nur Muster
# im Quelltext suchen, und solche Muster beschreiben schnell den WEG statt das
# ERGEBNIS. Dann lehnt die App funktionierenden Java-Code ab – und bestraft genau
# das eigenständige Denken, um das es hier geht. Swift und Kotlin prüfen deshalb
# bei jedem Testlauf, dass jede dieser Lösungen akzeptiert wird.
#
# Wer eine Regel verschärft, muss hier nachsehen. Wer hier etwas hinzufügt und es
# fällt durch, hat entweder eine zu enge Regel gefunden oder sich selbst vertan.

EQUIVALENTS = {
    # ------------------------------------------------------------------ syntax
    "t01-5": [
        'String text = "Ich lerne Java";\nSystem.out.println(text);',
    ],
    "q-syn-3b": [
        'System.out.println("Zeile 1");\nSystem.out.print("Zeile 2");\nSystem.out.println();',
    ],
    "x-syn-5a": [
        'public class Main {\n'
        '    public static void main(String[] args) {\n'
        '        String[] zeilen = {"Start", "Ende"};\n'
        '        for (String z : zeilen) {\n'
        '            System.out.println(z);\n'
        '        }\n'
        '    }\n'
        '}',
    ],
    "x-syn-5b": [
        'System.out.print("A-");\nSystem.out.print("B-");\nSystem.out.print("C");\nSystem.out.println();',
    ],

    # --------------------------------------------------------------- variables
    "s-code-1": [
        'var preis = 4.99;\nSystem.out.println(preis);',
        'double preis = 4.99;\nSystem.out.println("" + preis);',
    ],
    "t02-5": [
        'int a = 3;\nint b = 7;\nvar tmp = a;\na = b;\nb = tmp;\nSystem.out.println(a + " " + b);',
    ],
    "x-var-5a": [
        'String name = "Ada";\n'
        'int alter = 36;\n'
        'double groesse = 1.7;\n'
        'String zeile = name + ", " + alter + " Jahre, " + groesse + " m";\n'
        'System.out.println(zeile);',
    ],

    # --------------------------------------------------------------- operators
    "t03-5": [
        'int n1 = 2;\nint n2 = 3;\nint n3 = 3;\n'
        'double summe = n1 + n2 + n3;\n'
        'double schnitt = summe / 3;\n'
        'System.out.println(schnitt);',
    ],
    "q-op-3a": [
        'int minutenGesamt = 137;\n'
        'int stunden = minutenGesamt / 60;\n'
        'int rest = minutenGesamt - stunden * 60;\n'
        'System.out.println(stunden);\n'
        'System.out.println(rest);',
    ],
    "x-op-5a": [
        'int gesamt = 125;\n'
        'int minuten = gesamt / 60;\n'
        'int sekunden = gesamt - minuten * 60;\n'
        'System.out.println(minuten + " min " + sekunden + " s");',
    ],

    # ------------------------------------------------------------ conditionals
    "t04-5": [
        'int monat = 1;\n'
        'switch (monat) {\n'
        '    case 1, 2, 12 -> System.out.println("Winter");\n'
        '    default -> System.out.println("Kein Winter");\n'
        '}',
    ],
    "q-if-2a": [
        'int zahl = -4;\n'
        'if (zahl == 0) {\n'
        '    System.out.println("null");\n'
        '} else if (zahl > 0) {\n'
        '    System.out.println("positiv");\n'
        '} else {\n'
        '    System.out.println("negativ");\n'
        '}',
    ],
    "x-cond-5a": [
        'int tag = 6;\n'
        'switch (tag) {\n'
        '    case 7, 6 -> System.out.println("Wochenende");\n'
        '    default -> System.out.println("Arbeitstag");\n'
        '}',
        'int tag = 6;\n'
        'String text = switch (tag) {\n'
        '    case 6, 7 -> "Wochenende";\n'
        '    default -> "Arbeitstag";\n'
        '};\n'
        'System.out.println(text);',
    ],

    # ------------------------------------------------------------------- loops
    "t05-5": [
        'int summe = 0;\n'
        'int i = 1;\n'
        'while (i <= 100) {\n'
        '    summe = summe + i;\n'
        '    i++;\n'
        '}\n'
        'System.out.println(summe);',
    ],
    "p-loop-3a": [
        'int i = 10;\n'
        'while (i >= 1) {\n'
        '    System.out.println(i);\n'
        '    i--;\n'
        '}',
    ],
    "s-code-2": [
        'for (int i = 1; i <= 5; i++) {\n'
        '    System.out.print(i * 3 + " ");\n'
        '}',
        'int i = 3;\n'
        'while (i <= 15) {\n'
        '    System.out.print(i + " ");\n'
        '    i += 3;\n'
        '}',
    ],
    "x-loop-5a": [
        'int i = 1;\n'
        'while (i <= 5) {\n'
        '    System.out.println("7 x " + i + " = " + i * 7);\n'
        '    i++;\n'
        '}',
    ],

    # ----------------------------------------------------------------- methods
    "t06-5": [
        'static boolean istGerade(int zahl) {\n'
        '    if (zahl % 2 == 0) {\n'
        '        return true;\n'
        '    }\n'
        '    return false;\n'
        '}',
    ],
    "p-meth-3a": [
        'static boolean istPositiv(int zahl) {\n'
        '    if (zahl > 0) {\n'
        '        return true;\n'
        '    }\n'
        '    return false;\n'
        '}',
    ],
    "q-meth-2a": [
        'static void begruesse(String name) {\n'
        '    String gruss = "Hallo, " + name + "!";\n'
        '    System.out.println(gruss);\n'
        '}',
    ],
    "s-code-3": [
        'static double mittelwert(int a, int b) {\n'
        '    double summe = a + b;\n'
        '    return summe / 2;\n'
        '}',
    ],
    "x-meth-5a": [
        'static String begruessung(String name) {\n'
        '    StringBuilder sb = new StringBuilder("Hallo, ");\n'
        '    sb.append(name).append("!");\n'
        '    return sb.toString();\n'
        '}',
    ],
    "z-meth-4": [
        'static int flaeche(int seite) {\n'
        '    return flaeche(seite, seite);\n'
        '}\n'
        '\n'
        'static int flaeche(int a, int b) {\n'
        '    return a * b;\n'
        '}',
    ],

    # ------------------------------------------------------------------ arrays
    "t07-5": [
        'int[] zahlen = {12, 45, 7, 23, 38};\n'
        'int max = zahlen[0];\n'
        'for (int i = 1; i < zahlen.length; i++) {\n'
        '    max = Math.max(max, zahlen[i]);\n'
        '}\n'
        'System.out.println(max);',
    ],
    "q-arr-2a": [
        'int[] zahlen = {12, 4, 9, 7};\n'
        'int kleinster = zahlen[0];\n'
        'for (int i = 1; i < zahlen.length; i++) {\n'
        '    if (zahlen[i] < kleinster) {\n'
        '        kleinster = zahlen[i];\n'
        '    }\n'
        '}\n'
        'System.out.println(kleinster);',
    ],
    "s-code-4": [
        'int[] zahlen = {2, 5, 9};\n'
        'int summe = 0;\n'
        'for (int i = 0; i < zahlen.length; i++) {\n'
        '    summe = summe + zahlen[i];\n'
        '}\n'
        'System.out.println(summe);',
    ],
    "x-arr-5a": [
        'int[] zahlen = {4, 12, 7, 20, 10};\n'
        'int anzahl = 0;\n'
        'for (int i = 0; i < zahlen.length; i++) {\n'
        '    if (zahlen[i] > 10) {\n'
        '        anzahl += 1;\n'
        '    }\n'
        '}\n'
        'System.out.println(anzahl);',
    ],

    # ----------------------------------------------------------------- strings
    "r-str-3a": [
        'String wort = "JavaQuest";\n'
        'boolean beginnt = wort.startsWith("Ja");\n'
        'System.out.println(beginnt);',
    ],
    "x-str-5a": [
        'String wort = "Level";\n'
        'String klein = wort.toLowerCase();\n'
        'StringBuilder sb = new StringBuilder(klein);\n'
        'System.out.println(klein.equals(sb.reverse().toString()));',
    ],
    "x-str-5b": [
        'String wort = "programmieren";\n'
        'System.out.println(wort.substring(0, 1).toUpperCase() + wort.substring(1));',
    ],
    "y-str-2b": [
        'String satz = "Hallo Welt";\n'
        'String gross = satz.toUpperCase();\n'
        'System.out.println(gross);',
    ],

    # --------------------------------------------------------------------- oop
    "t08-5": [
        'class Rechteck {\n'
        '    private double breite;\n'
        '    private double hoehe;\n'
        '\n'
        '    Rechteck(double b, double h) {\n'
        '        breite = b;\n'
        '        hoehe = h;\n'
        '    }\n'
        '\n'
        '    double flaeche() {\n'
        '        return hoehe * breite;\n'
        '    }\n'
        '}',
    ],
    "q-oop-2a": [
        'class Punkt {\n'
        '    private int x;\n'
        '    private int y;\n'
        '\n'
        '    Punkt(int neuX, int neuY) {\n'
        '        x = neuX;\n'
        '        y = neuY;\n'
        '    }\n'
        '\n'
        '    int getX() {\n'
        '        return x;\n'
        '    }\n'
        '}',
    ],
    "s-code-7": [
        'class Konto {\n'
        '    private double stand;\n'
        '\n'
        '    void einzahlen(double betrag) {\n'
        '        stand += betrag;\n'
        '    }\n'
        '\n'
        '    double getStand() {\n'
        '        return this.stand;\n'
        '    }\n'
        '}',
    ],
    "x-oop-5a": [
        'class Sparschwein {\n'
        '    private int stand;\n'
        '\n'
        '    void einzahlen(int betrag) {\n'
        '        stand = stand + betrag;\n'
        '    }\n'
        '\n'
        '    int getStand() {\n'
        '        return stand;\n'
        '    }\n'
        '}',
    ],

    # ------------------------------------------------------------- inheritance
    "t09-5": [
        'class Rechteck {\n'
        '    protected double breite;\n'
        '    protected double hoehe;\n'
        '\n'
        '    Rechteck(double breite, double hoehe) {\n'
        '        this.breite = breite;\n'
        '        this.hoehe = hoehe;\n'
        '    }\n'
        '\n'
        '    double flaeche() {\n'
        '        return breite * hoehe;\n'
        '    }\n'
        '}\n'
        '\n'
        'class Quadrat extends Rechteck {\n'
        '    Quadrat(double kante) {\n'
        '        super(kante, kante);\n'
        '    }\n'
        '}',
    ],
    "x-inh-5a": [
        'class Fahrzeug {\n'
        '    int raeder;\n'
        '\n'
        '    Fahrzeug(int raeder) {\n'
        '        this.raeder = raeder;\n'
        '    }\n'
        '}\n'
        '\n'
        'class Fahrrad extends Fahrzeug {\n'
        '    int gaenge;\n'
        '\n'
        '    Fahrrad(int gaenge) {\n'
        '        super(2);\n'
        '        this.gaenge = gaenge;\n'
        '    }\n'
        '\n'
        '    int getGaenge() {\n'
        '        return gaenge;\n'
        '    }\n'
        '}',
    ],

    # -------------------------------------------------------------- exceptions
    "t10-5": [
        'String eingabe = "12a";\n'
        'try {\n'
        '    int zahl = Integer.parseInt(eingabe);\n'
        '    int doppelt = zahl + zahl;\n'
        '    System.out.println(doppelt);\n'
        '} catch (NumberFormatException e) {\n'
        '    System.out.println("Ungültige Eingabe");\n'
        '}',
    ],
    "q-exc-2a": [
        'String eingabe = "abc";\n'
        'try {\n'
        '    System.out.println(Integer.parseInt(eingabe));\n'
        '} catch (NumberFormatException e) {\n'
        '    System.out.println("keine Zahl");\n'
        '}',
    ],
    "s-code-8": [
        'int[] teiler = {2, 0, 5};\n'
        'for (int i = 0; i < teiler.length; i++) {\n'
        '    try {\n'
        '        System.out.println(10 / teiler[i]);\n'
        '    } catch (ArithmeticException e) {\n'
        '        System.out.println("nicht teilbar");\n'
        '    }\n'
        '}',
    ],
    "x-exc-5a": [
        'int[] teiler = {5, 0, 4};\n'
        'for (int i = 0; i < teiler.length; i++) {\n'
        '    try {\n'
        '        System.out.println(100 / teiler[i]);\n'
        '    } catch (ArithmeticException e) {\n'
        '        System.out.println("nicht teilbar");\n'
        '    }\n'
        '}',
    ],

    # ------------------------------------------------------------- collections
    "s-code-5": [
        'List<String> farben = new ArrayList<>(List.of("rot", "blau"));\n'
        'for (String f : farben) {\n'
        '    System.out.println(f);\n'
        '}',
    ],
    "x-col-5a": [
        'List<String> woerter = new ArrayList<>(List.of("Hut", "Java", "ok", "Code"));\n'
        'woerter.removeIf(w -> w.length() <= 3);\n'
        'System.out.println(woerter);',
    ],
    "x-col-5b": [
        'Map<Character, Integer> zaehler = new HashMap<>();\n'
        'String wort = "banane";\n'
        'for (int i = 0; i < wort.length(); i++) {\n'
        '    char c = wort.charAt(i);\n'
        '    if (zaehler.containsKey(c)) {\n'
        '        zaehler.put(c, zaehler.get(c) + 1);\n'
        '    } else {\n'
        '        zaehler.put(c, 1);\n'
        '    }\n'
        '}\n'
        'System.out.println(zaehler);',
    ],

    # ---------------------------------------------------------- datastructures
    "t20-5": [
        'List<String> woerter = List.of("ja", "nein", "ja", "vielleicht", "nein");\n'
        'Set<String> verschieden = new TreeSet<>(woerter);\n'
        'System.out.println(verschieden.size());',
    ],
    "q-ds-3a": [
        'List<String> zeichen = List.of("a", "b", "a", "c", "b");\n'
        'Set<String> verschieden = new HashSet<>();\n'
        'verschieden.addAll(zeichen);\n'
        'System.out.println(verschieden.size());',
    ],
    "s-code-10": [
        'List<String> woerter = List.of("Birne", "Apfel", "Birne");\n'
        'Set<String> sortiert = new TreeSet<>();\n'
        'sortiert.addAll(woerter);\n'
        'System.out.println(sortiert);',
    ],
    "x-ds-5a": [
        'List<String> a = List.of("rot", "gruen", "blau");\n'
        'List<String> b = List.of("blau", "gelb", "rot");\n'
        'Set<String> beide = new TreeSet<>();\n'
        'for (String s : a) {\n'
        '    if (b.contains(s)) {\n'
        '        beide.add(s);\n'
        '    }\n'
        '}\n'
        'System.out.println(beide);',
    ],

    # --------------------------------------------------------------- recursion
    "t18-5": [
        'static int quersumme(int n) {\n'
        '    if (n < 10) {\n'
        '        return n;\n'
        '    }\n'
        '    return quersumme(n / 10) + n % 10;\n'
        '}\n'
        '\n'
        'public static void main(String[] args) {\n'
        '    System.out.println(quersumme(472));\n'
        '}',
    ],
    "q-rec-2a": [
        'static void zaehleRunter(int n) {\n'
        '    if (n > 0) {\n'
        '        System.out.println(n);\n'
        '        zaehleRunter(n - 1);\n'
        '    }\n'
        '}',
    ],
    "x-rec-5a": [
        'static int fakultaet(int n) {\n'
        '    if (n <= 1) {\n'
        '        return 1;\n'
        '    }\n'
        '    return fakultaet(n - 1) * n;\n'
        '}',
    ],
    "x-rec-5b": [
        'static String rueckwaerts(String text) {\n'
        '    if (text.length() == 0) {\n'
        '        return "";\n'
        '    }\n'
        '    return rueckwaerts(text.substring(1)) + text.charAt(0);\n'
        '}',
    ],

    # -------------------------------------------------------------- algorithms
    "t19-5": [
        'List<String> woerter = new ArrayList<>(List.of("Kiwi", "Banane", "Apfel"));\n'
        'woerter.sort((a, b) -> b.length() - a.length());\n'
        'System.out.println(woerter);',
    ],
    "q-alg-3a": [
        'int[] zahlen = {4, 17, 9, 23, 11};\n'
        'int anzahl = 0;\n'
        'for (int i = 0; i < zahlen.length; i++) {\n'
        '    if (zahlen[i] > 10) {\n'
        '        anzahl = anzahl + 1;\n'
        '    }\n'
        '}\n'
        'System.out.println(anzahl);',
    ],
    "s-code-9": [
        'String wort = "Banane";\n'
        'int anzahl = 0;\n'
        'for (char c : wort.toCharArray()) {\n'
        '    if (c == \'a\') {\n'
        '        anzahl++;\n'
        '    }\n'
        '}\n'
        'System.out.println(anzahl);',
    ],
    "u-alg-2": [
        'List<String> namen = new ArrayList<>(List.of("Mia", "Ada", "Zoe"));\n'
        'namen.sort((a, b) -> a.compareTo(b));\n'
        'System.out.println(namen);',
    ],
    "x-alg-5a": [
        'List<Integer> zahlen = new ArrayList<>(List.of(3, 9, 1, 7));\n'
        'zahlen.sort(Comparator.<Integer>naturalOrder().reversed());\n'
        'System.out.println(zahlen);',
    ],

    # ---------------------------------------------------------------------- io
    "t16-5": [
        'StringBuilder sb = new StringBuilder();\n'
        'int i = 0;\n'
        'while (i < 5) {\n'
        '    sb.append("*");\n'
        '    i++;\n'
        '}\n'
        'System.out.println(sb.toString());',
    ],
    "q-io-3a": [
        'String[] farben = {"rot", "gelb", "blau"};\n'
        'StringBuilder sb = new StringBuilder();\n'
        'sb.append(farben[0]).append("-").append(farben[1]).append("-").append(farben[2]);\n'
        'System.out.println(sb);',
    ],
    "x-io-5a": [
        'StringBuilder sb = new StringBuilder();\n'
        'for (int i = 1; i <= 5; i++) {\n'
        '    sb.append(i);\n'
        '    if (i < 5) {\n'
        '        sb.append("-");\n'
        '    }\n'
        '}\n'
        'System.out.println(sb.toString());',
    ],
    "z-io-4": [
        'Scanner scanner = new Scanner("Ada Lovelace");\n'
        'String vorname = scanner.next();\n'
        'String nachname = scanner.next();\n'
        'StringBuilder sb = new StringBuilder(nachname);\n'
        'sb.append(", ");\n'
        'sb.append(vorname);\n'
        'System.out.println(sb.toString());',
    ],

    # ----------------------------------------------------------- objectmethods
    "t15-5": [
        'class Buch {\n'
        '    String titel;\n'
        '    String autor;\n'
        '\n'
        '    Buch(String titel, String autor) {\n'
        '        this.titel = titel;\n'
        '        this.autor = autor;\n'
        '    }\n'
        '\n'
        '    @Override\n'
        '    public String toString() {\n'
        '        return this.titel + " von " + this.autor;\n'
        '    }\n'
        '}\n'
        '\n'
        'public class Main {\n'
        '    public static void main(String[] args) {\n'
        '        System.out.println(new Buch("Momo", "Michael Ende"));\n'
        '    }\n'
        '}',
    ],
    "v-obj-5": [
        'class Film {\n'
        '    String titel = "Matrix";\n'
        '    int jahr = 1999;\n'
        '\n'
        '    @Override\n'
        '    public String toString() {\n'
        '        String klammer = "(" + jahr + ")";\n'
        '        return titel + " " + klammer;\n'
        '    }\n'
        '}',
    ],
    "x-objm-5a": [
        'class Punkt {\n'
        '    int x = 1;\n'
        '    int y = 2;\n'
        '\n'
        '    @Override\n'
        '    public boolean equals(Object o) {\n'
        '        if (o instanceof Punkt) {\n'
        '            Punkt p = (Punkt) o;\n'
        '            return x == p.x && y == p.y;\n'
        '        }\n'
        '        return false;\n'
        '    }\n'
        '}',
    ],
    "x-objm-5b": [
        'class Temperatur {\n'
        '    double wert = 21.5;\n'
        '\n'
        '    @Override\n'
        '    public String toString() {\n'
        '        return String.valueOf(wert) + " Grad";\n'
        '    }\n'
        '}',
    ],

    # ----------------------------------------------------------------- lambdas
    "t12-5": [
        'List<Integer> zahlen = List.of(1, 2, 3, 4, 5);\n'
        'int summe = zahlen.stream()\n'
        '        .filter(n -> n % 2 == 1)\n'
        '        .map(n -> n * n)\n'
        '        .reduce(0, Integer::sum);\n'
        'System.out.println(summe);',
    ],
    "t26-5": [
        'List<String> woerter = List.of("Tee", "Kakao", "Saft");\n'
        'String laengstes = woerter.stream()\n'
        '        .sorted((a, b) -> b.length() - a.length())\n'
        '        .findFirst()\n'
        '        .orElse("");\n'
        'System.out.println(laengstes);',
    ],
    "s-code-6": [
        'List<String> woerter = List.of("Hut", "Apfel", "Banane");\n'
        'woerter.stream()\n'
        '        .filter(w -> w.length() >= 5)\n'
        '        .forEach(System.out::println);',
    ],
    "v-str-5": [
        'List<Integer> zahlen = List.of(8, 3, 11);\n'
        'int kleinste = zahlen.stream()\n'
        '        .sorted()\n'
        '        .findFirst()\n'
        '        .orElse(0);\n'
        'System.out.println(kleinste);',
    ],
    "z-lam-26-3": [
        'List<String> woerter = List.of("Ei", "Hut", "Tee");\n'
        'Map<Integer, List<String>> nachLaenge = woerter.stream()\n'
        '    .collect(Collectors.groupingBy(w -> w.length()));\n'
        'System.out.println(nachLaenge);',
    ],
    "z-lam-26-4": [
        'List<List<String>> gruppen = List.of(List.of("Linus", "Ada"), List.of("Grace"));\n'
        'List<String> alle = gruppen.stream()\n'
        '    .flatMap(g -> g.stream())\n'
        '    .sorted()\n'
        '    .collect(Collectors.toList());\n'
        'System.out.println(alle);',
    ],

    # ---------------------------------------------------------------- generics
    "t11-5": [
        'static <T> T letztes(List<T> liste) {\n'
        '    int letzterIndex = liste.size() - 1;\n'
        '    return liste.get(letzterIndex);\n'
        '}',
    ],
    "r-gen-2a": [
        'static <T> T erstes(List<T> liste) {\n'
        '    T ersterEintrag = liste.get(0);\n'
        '    return ersterEintrag;\n'
        '}',
    ],
    "u-gen-4": [
        'static <T> int anzahl(List<T> liste) {\n'
        '    int wieViele = liste.size();\n'
        '    return wieViele;\n'
        '}',
    ],
    "x-gen-5a": [
        'static <T> List<T> letzteZwei(List<T> liste) {\n'
        '    int ab = liste.size() - 2;\n'
        '    return liste.subList(ab, liste.size());\n'
        '}',
    ],
    "x-gen-5b": [
        'Map<String, List<String>> regale = new HashMap<>();\n'
        'List<String> obst = new ArrayList<>();\n'
        'obst.add("Apfel");\n'
        'obst.add("Birne");\n'
        'regale.put("Obst", obst);\n'
        'System.out.println(regale);',
    ],

    # ---------------------------------------------------------------- datetime
    "t17-5": [
        'LocalDate tag = LocalDate.of(2026, 10, 3);\n'
        'DateTimeFormatter deutsch = DateTimeFormatter.ofPattern("dd.MM.yyyy");\n'
        'System.out.println(deutsch.format(tag));',
    ],
    "r-dat-2a": [
        'LocalDate start = LocalDate.of(2000, 1, 1);\n'
        'LocalDate ende = LocalDate.of(2026, 1, 1);\n'
        'Period abstand = Period.between(start, ende);\n'
        'System.out.println(abstand.getYears());',
    ],
    "x-dt-5a": [
        'LocalDate d = LocalDate.of(2027, 1, 1);\n'
        'DateTimeFormatter deutsch = DateTimeFormatter.ofPattern("dd.MM.yyyy");\n'
        'System.out.println(d.getDayOfWeek());\n'
        'System.out.println(deutsch.format(d));',
    ],
    "x-dt-5b": [
        'LocalDate start = LocalDate.of(2026, 3, 1);\n'
        'LocalDate ende = LocalDate.of(2026, 12, 24);\n'
        'long tage = ende.toEpochDay() - start.toEpochDay();\n'
        'System.out.println(tage);',
    ],
    "y-dat-4b": [
        'LocalDate weihnachten = LocalDate.of(2026, 12, 24);\n'
        'DateTimeFormatter deutsch = DateTimeFormatter.ofPattern("dd.MM.yyyy");\n'
        'System.out.println(weihnachten.format(deutsch));',
    ],

    # ------------------------------------------------------------------- enums
    "t14-5": [
        'enum Jahreszeit { FRUEHLING, SOMMER, HERBST, WINTER }\n'
        '\n'
        'public static void main(String[] args) {\n'
        '    Jahreszeit[] alle = Jahreszeit.values();\n'
        '    for (int i = 0; i < alle.length; i++) {\n'
        '        System.out.println(alle[i]);\n'
        '    }\n'
        '}',
    ],
    "x-enum-5a": [
        'enum Richtung { NORD, OST, SUED, WEST }\n'
        '\n'
        'public class Main {\n'
        '    public static void main(String[] args) {\n'
        '        Richtung[] alle = Richtung.values();\n'
        '        for (int i = 0; i < alle.length; i++) {\n'
        '            System.out.println(alle[i] + " " + alle[i].ordinal());\n'
        '        }\n'
        '    }\n'
        '}',
    ],
    "x-enum-5b": [
        'enum Wochentag {\n'
        '    MONTAG, SAMSTAG, SONNTAG;\n'
        '\n'
        '    boolean istWochenende() {\n'
        '        switch (this) {\n'
        '            case SAMSTAG:\n'
        '            case SONNTAG:\n'
        '                return true;\n'
        '            default:\n'
        '                return false;\n'
        '        }\n'
        '    }\n'
        '}',
    ],

    # ----------------------------------------------------------------- testing
    "t21-5": [
        'static int verdopple(int x) {\n'
        '    return x * 2;\n'
        '}\n'
        '\n'
        'static void pruefe(String name, int erwartet, int erhalten) {\n'
        '    System.out.println((erwartet == erhalten ? "OK: " : "FEHLER: ") + name);\n'
        '}\n'
        '\n'
        'public static void main(String[] args) {\n'
        '    pruefe("verdopple(0)", 0, verdopple(0));\n'
        '    pruefe("verdopple(5)", 10, verdopple(5));\n'
        '    pruefe("verdopple(-2)", -4, verdopple(-2));\n'
        '}',
    ],
    "u-test-3": [
        'static int laenge(String text) {\n'
        '    return text.length();\n'
        '}\n'
        '\n'
        'static void pruefe(String name, int erwartet, int erhalten) {\n'
        '    if (erwartet == erhalten) {\n'
        '        System.out.println("OK: " + name);\n'
        '    } else {\n'
        '        System.out.println("FEHLER: " + name);\n'
        '    }\n'
        '}\n'
        '\n'
        'public static void main(String[] args) {\n'
        '    int erwartet = 4;\n'
        '    pruefe("laenge(Java)", erwartet, laenge("Java"));\n'
        '}',
    ],
    "x-test-5a": [
        'static int laenge(String s) {\n'
        '    return s.length();\n'
        '}\n'
        '\n'
        'static void pruefe(String name, int erwartet, int tatsaechlich) {\n'
        '    if (erwartet == tatsaechlich) {\n'
        '        System.out.println(name + ": ok");\n'
        '    } else {\n'
        '        System.out.println(name + ": FEHLER");\n'
        '    }\n'
        '}\n'
        '\n'
        'public static void main(String[] args) {\n'
        '    pruefe("leer", 0, laenge(""));\n'
        '    pruefe("ab", 2, laenge("ab"));\n'
        '    pruefe("Java", 4, laenge("Java"));\n'
        '}',
    ],

    # ------------------------------------------------------------- concurrency
    "t23-5": [
        'AtomicInteger zaehler = new AtomicInteger();\n'
        'Runnable arbeit = () -> {\n'
        '    int i = 0;\n'
        '    while (i < 500) {\n'
        '        zaehler.getAndIncrement();\n'
        '        i++;\n'
        '    }\n'
        '};\n'
        'Thread a = new Thread(arbeit);\n'
        'Thread b = new Thread(arbeit);\n'
        'a.start();\n'
        'b.start();\n'
        'a.join();\n'
        'b.join();\n'
        'System.out.println(zaehler.get());',
    ],
    "t24-5": [
        'try (ExecutorService team = Executors.newVirtualThreadPerTaskExecutor()) {\n'
        '    Future<Integer> a = team.submit(() -> 10);\n'
        '    Future<Integer> b = team.submit(() -> 20);\n'
        '    Future<Integer> c = team.submit(() -> 30);\n'
        '    int summe = a.get() + b.get();\n'
        '    summe = summe + c.get();\n'
        '    System.out.println(summe);\n'
        '}',
    ],
    "z-con-23-4": [
        'Runnable arbeit = () -> System.out.println("fertig");\n'
        'Thread t = new Thread(arbeit);\n'
        't.start();\n'
        't.join();\n'
        'System.out.println("Ende");',
    ],

    # ---------------------------------------------------------------- patterns
    "t25-5": [
        'sealed interface Form permits Kreis, Quadrat {}\n'
        'record Kreis(double r) implements Form {}\n'
        'record Quadrat(double seite) implements Form {}\n'
        '\n'
        'public class Main {\n'
        '    static double flaeche(Form f) {\n'
        '        return switch (f) {\n'
        '            case Kreis k -> Math.PI * Math.pow(k.r(), 2);\n'
        '            case Quadrat q -> Math.pow(q.seite(), 2);\n'
        '        };\n'
        '    }\n'
        '\n'
        '    public static void main(String[] args) {\n'
        '        System.out.println(flaeche(new Quadrat(3)));\n'
        '    }\n'
        '}',
    ],
    "v-pat-5": [
        'sealed interface Getraenk permits Tee, Saft {}\n'
        'record Tee(String sorte) implements Getraenk {}\n'
        'record Saft(String frucht) implements Getraenk {}\n'
        '\n'
        'public class Main {\n'
        '    static String beschreibe(Getraenk g) {\n'
        '        return switch (g) {\n'
        '            case Tee(String sorte) -> "Tee: " + sorte;\n'
        '            case Saft(String frucht) -> "Saft: " + frucht;\n'
        '        };\n'
        '    }\n'
        '\n'
        '    public static void main(String[] args) {\n'
        '        System.out.println(beschreibe(new Saft("Apfel")));\n'
        '    }\n'
        '}',
    ],
    "x-pat-5a": [
        'sealed interface Form permits Kreis, Quadrat {}\n'
        '\n'
        'record Kreis(double r) implements Form {}\n'
        '\n'
        'record Quadrat(double seite) implements Form {}\n'
        '\n'
        'class Rechner {\n'
        '    static double umfang(Form f) {\n'
        '        return switch (f) {\n'
        '            case Kreis k -> Math.PI * 2 * k.r();\n'
        '            case Quadrat q -> q.seite() * 4;\n'
        '        };\n'
        '    }\n'
        '}',
    ],

    # ------------------------------------------------------------------ modern
    "t13-5": [
        'static String beschreibe(Object o) {\n'
        '    return switch (o) {\n'
        '        case String s -> "Text mit " + s.length() + " Zeichen";\n'
        '        case Integer i -> "Zahl " + i;\n'
        '        default -> "Unbekannt";\n'
        '    };\n'
        '}',
    ],
    "x-mod-5a": [
        'static int laenge(Object o) {\n'
        '    if (!(o instanceof String s)) {\n'
        '        return -1;\n'
        '    }\n'
        '    return s.length();\n'
        '}',
    ],

    # ----------------------------------------------------------------- tooling
    "t22-5": [
        'int summe = 0;\n'
        'for (int i = 1; i < 6; i++) {\n'
        '    summe = summe + i;\n'
        '}\n'
        'System.out.println(summe);',
    ],
    "x-tool-5a": [
        'int[] zahlen = {10, 20, 30};\n'
        'int summe = 0;\n'
        'for (int i = 0; i < zahlen.length; i++) {\n'
        '    summe = summe + zahlen[i];\n'
        '}\n'
        'System.out.println(summe);',
    ],

    # ---------------------------------------------------------------- projects
    "t27-5": [
        'static void bericht(int[] noten) {\n'
        '    int summe = 0;\n'
        '    int beste = noten[0];\n'
        '    for (int n : noten) {\n'
        '        summe += n;\n'
        '        beste = Math.min(beste, n);\n'
        '    }\n'
        '    double schnitt = (double) summe / noten.length;\n'
        '    System.out.println("Schnitt: " + schnitt + ", beste Note: " + beste);\n'
        '}\n'
        '\n'
        'public static void main(String[] args) {\n'
        '    bericht(new int[]{2, 3, 1, 2});\n'
        '}',
    ],
    "t28-5": [
        'record Aufgabe(String titel, boolean erledigt) {}\n'
        '\n'
        'List<Aufgabe> liste = List.of(new Aufgabe("Einkaufen", false), new Aufgabe("Java lernen", true));\n'
        'int nummer = 1;\n'
        'for (Aufgabe a : liste) {\n'
        '    String haken = a.erledigt() ? "[x]" : "[ ]";\n'
        '    System.out.println(nummer + ". " + haken + " " + a.titel());\n'
        '    nummer++;\n'
        '}',
    ],
    "t29-5": [
        'enum Raum { FLUR, KUECHE, GARTEN }\n'
        '\n'
        'Map<Raum, Map<String, Raum>> wege = new HashMap<>();\n'
        'wege.put(Raum.FLUR, Map.of("norden", Raum.KUECHE, "osten", Raum.GARTEN));\n'
        'wege.put(Raum.KUECHE, Map.of("sueden", Raum.FLUR));\n'
        'wege.put(Raum.GARTEN, Map.of("westen", Raum.FLUR));\n'
        'List<String> befehle = List.of("norden", "sueden", "springen", "osten");\n'
        'Raum hier = Raum.FLUR;\n'
        'for (String befehl : befehle) {\n'
        '    Map<String, Raum> tueren = wege.get(hier);\n'
        '    if (tueren.containsKey(befehl)) {\n'
        '        hier = tueren.get(befehl);\n'
        '    }\n'
        '}\n'
        'System.out.println(hier);',
    ],
    "v-grd-5": [
        'static void zeugnis(int[] noten) {\n'
        '    int beste = Arrays.stream(noten).min().orElse(0);\n'
        '    int schlechteste = Arrays.stream(noten).max().orElse(0);\n'
        '    System.out.println("Beste: " + beste + ", Schlechteste: " + schlechteste);\n'
        '}',
    ],
    "v-todo-5": [
        'record Aufgabe(String titel, boolean erledigt) {}\n'
        '\n'
        'public class Main {\n'
        '    public static void main(String[] args) {\n'
        '        List<Aufgabe> liste = List.of(new Aufgabe("Einkaufen", true), new Aufgabe("Lernen", false));\n'
        '        liste.forEach(a -> {\n'
        '            String haken = a.erledigt() ? "[x] " : "[ ] ";\n'
        '            System.out.println(haken + a.titel());\n'
        '        });\n'
        '    }\n'
        '}',
    ],
    "v-adv-5": [
        'enum Raum { FLUR, KUECHE }\n'
        '\n'
        'public class Main {\n'
        '    public static void main(String[] args) {\n'
        '        Map<String, Raum> tueren = Map.of("norden", Raum.KUECHE);\n'
        '        Raum aktuell = Raum.FLUR;\n'
        '        String[] befehle = {"sueden", "norden"};\n'
        '        for (String befehl : befehle) {\n'
        '            if (tueren.containsKey(befehl)) {\n'
        '                aktuell = tueren.get(befehl);\n'
        '            }\n'
        '        }\n'
        '        System.out.println(aktuell);\n'
        '    }\n'
        '}',
    ],
    "z-proj-28-3": [
        'record Aufgabe(String titel, boolean erledigt) {}\n'
        '\n'
        'public class Main {\n'
        '    public static void main(String[] args) {\n'
        '        List<Aufgabe> liste = new ArrayList<>();\n'
        '        liste.add(new Aufgabe("Einkaufen", false));\n'
        '        liste.add(new Aufgabe("Lernen", true));\n'
        '        liste.add(new Aufgabe("Sport", false));\n'
        '        liste.stream()\n'
        '            .filter(a -> !a.erledigt())\n'
        '            .forEach(a -> System.out.println(a.titel()));\n'
        '    }\n'
        '}',
    ],
    "z-proj-28-4": [
        'record Aufgabe(String titel, boolean erledigt) {}\n'
        '\n'
        'public class Main {\n'
        '    public static void main(String[] args) {\n'
        '        List<Aufgabe> liste = new ArrayList<>();\n'
        '        liste.add(new Aufgabe("Putzen", false));\n'
        '        String titel = liste.get(0).titel();\n'
        '        liste.set(0, new Aufgabe(titel, true));\n'
        '        System.out.println(liste);\n'
        '    }\n'
        '}',
    ],
    "z-proj-29-4": [
        'enum Raum { FLUR, KUECHE }\n'
        '\n'
        'public class Main {\n'
        '    public static void main(String[] args) {\n'
        '        Map<Raum, Map<String, Raum>> wege = new HashMap<>();\n'
        '        wege.put(Raum.FLUR, Map.of("norden", Raum.KUECHE));\n'
        '        wege.put(Raum.KUECHE, Map.of("sueden", Raum.FLUR));\n'
        '        String[] befehle = {"norden", "springen"};\n'
        '        Raum hier = Raum.FLUR;\n'
        '        for (int i = 0; i < befehle.length; i++) {\n'
        '            hier = wege.get(hier).getOrDefault(befehle[i], hier);\n'
        '        }\n'
        '        System.out.println(hier);\n'
        '    }\n'
        '}',
    ],

    # -------------------------------------------------------------- umlbasics
    "t30-5": [
        'class Person {\n'
        '    private String name;\n'
        '\n'
        '    public String getName() {\n'
        '        return this.name;\n'
        '    }\n'
        '}',
    ],
    "v-uml-30-5": [
        'class Lampe {\n'
        '    private boolean an;\n'
        '\n'
        '    public boolean istAn() {\n'
        '        return this.an;\n'
        '    }\n'
        '}',
    ],
    "x-uml-4b": [
        'class Konto {\n'
        '    private double stand;\n'
        '\n'
        '    public void einzahlen() {\n'
        '        stand += 10;\n'
        '    }\n'
        '\n'
        '    public double getStand() {\n'
        '        return stand;\n'
        '    }\n'
        '}',
    ],
    "x-uml-5a": [
        'class Ampel {\n'
        '    private String farbe;\n'
        '    private int nummer;\n'
        '\n'
        '    Ampel(String farbe, int nummer) {\n'
        '        this.farbe = farbe;\n'
        '        this.nummer = nummer;\n'
        '    }\n'
        '\n'
        '    public void umschalten() {\n'
        '        this.farbe = "gruen";\n'
        '    }\n'
        '\n'
        '    public String getFarbe() {\n'
        '        return this.farbe;\n'
        '    }\n'
        '}',
    ],
    "x-uml-5b": [
        'class Person {\n'
        '    private String name;\n'
        '    private int alter;\n'
        '\n'
        '    Person(String name, int alter) {\n'
        '        this.name = name;\n'
        '        this.alter = alter;\n'
        '    }\n'
        '\n'
        '    public String getName() {\n'
        '        return name;\n'
        '    }\n'
        '\n'
        '    public void hatGeburtstag() {\n'
        '        alter += 1;\n'
        '    }\n'
        '\n'
        '    public int getAlter() {\n'
        '        return alter;\n'
        '    }\n'
        '}',
    ],

    # ------------------------------------------------------------ umlrelations
    "t32-5": [
        'class Tier {\n'
        '    protected String name;\n'
        '\n'
        '    public String laut() {\n'
        '        return "...";\n'
        '    }\n'
        '}\n'
        '\n'
        'class Hund extends Tier {\n'
        '    public String laut() {\n'
        '        return "Wau";\n'
        '    }\n'
        '}',
    ],
    "v-uml-32-5": [
        'interface Fahrbar {\n'
        '    void fahren();\n'
        '}\n'
        '\n'
        'class Auto implements Fahrbar {\n'
        '    @Override\n'
        '    public void fahren() {\n'
        '        String text = "faehrt";\n'
        '        System.out.println(text);\n'
        '    }\n'
        '}',
    ],
    "x-umlr-5a": [
        'class Raum {\n'
        '    private double flaeche;\n'
        '\n'
        '    Raum(double flaeche) {\n'
        '        this.flaeche = flaeche;\n'
        '    }\n'
        '\n'
        '    double getFlaeche() {\n'
        '        return flaeche;\n'
        '    }\n'
        '}\n'
        '\n'
        'class Haus {\n'
        '    private String adresse;\n'
        '    private List<Raum> raeume;\n'
        '\n'
        '    Haus(String adresse) {\n'
        '        this.adresse = adresse;\n'
        '        this.raeume = new ArrayList<>();\n'
        '        this.raeume.add(new Raum(20));\n'
        '        this.raeume.add(new Raum(15));\n'
        '    }\n'
        '\n'
        '    int anzahlRaeume() {\n'
        '        return raeume.size();\n'
        '    }\n'
        '}',
    ],
    "x-umlr-5b": [
        'class Kunde {\n'
        '    private String name;\n'
        '\n'
        '    Kunde(String name) {\n'
        '        this.name = name;\n'
        '    }\n'
        '\n'
        '    String getName() {\n'
        '        return name;\n'
        '    }\n'
        '}\n'
        '\n'
        'class Bestellung {\n'
        '    private int nummer;\n'
        '    private Kunde kunde;\n'
        '\n'
        '    Bestellung(int nummer, Kunde kunde) {\n'
        '        this.nummer = nummer;\n'
        '        this.kunde = kunde;\n'
        '    }\n'
        '\n'
        '    String beschreibung() {\n'
        '        return this.nummer + " fuer " + this.kunde.getName();\n'
        '    }\n'
        '}',
    ],
    "z-uml-31-5": [
        'class Drucker {\n'
        '    void ausgeben(String text) {\n'
        '        System.out.println(text);\n'
        '    }\n'
        '}\n'
        '\n'
        'class Rechnung {\n'
        '    void drucke(Drucker geraet) {\n'
        '        String text = "Rechnung";\n'
        '        geraet.ausgeben(text);\n'
        '    }\n'
        '}',
    ],
    "z-uml-32-4": [
        'interface Fahrbar {\n'
        '    void fahren();\n'
        '}\n'
        '\n'
        'class Auto implements Fahrbar {\n'
        '    @Override\n'
        '    public void fahren() {\n'
        '        System.out.println("faehrt");\n'
        '    }\n'
        '}',
    ],
}
