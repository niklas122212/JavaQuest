"""Kernstoff, der lange fehlte.

Eine Zählung über alle 685 Aufgaben ergab: Zehn Grundlagen, die in jeder Java-Einführung
und in Prüfungen vorkommen, wurden nie oder nur ein einziges Mal geübt – eigene
Exceptions, default-Methoden, anonyme Klassen, Function und Predicate, varargs,
Zahlenüberlauf, Textblöcke, printf, this(…) und der Iterator. Zum Vergleich: Lambdas
kamen 72-mal vor.

Jedes Thema bekommt hier
  * eine Theoriekarte in der Lektion, in die es gehört – erst verstehen, dann üben,
  * eine Lektionsaufgabe als Anker (der Übungspool verlangt eine),
  * zwei weitere Varianten im Übungspool – zusammen drei, wie bei jedem Lernziel.

Bewusst ohne %.2f in geprüften Ausgaben: Das schreibt auf deutsch eingestellten
Rechnern ein Komma, in der CI einen Punkt. Die Karte zu printf erklärt das stattdessen.
"""
from authoring import any_of, card, code, fill, forbid, mc, out, req

# ---------------------------------------------------------------- Theoriekarten
KERNSTOFF_KARTEN = {
    "l03-operators": [
        card("Wenn die Zahl nicht mehr in die Box passt",
             "Eine int-Box fasst Zahlen bis 2147483647 – das ist Integer.MAX_VALUE. Rechnest du darüber "
             "hinaus, meldet Java keinen Fehler: Die Zahl springt einfach ans andere Ende und wird negativ, "
             "wie ein Kilometerzähler, der nach 999999 wieder bei 0 anfängt. Das heißt Überlauf. Wer "
             "größere Zahlen braucht, nimmt long – diese Box fasst rund neun Trillionen.",
             code="""
             int max = Integer.MAX_VALUE;
             System.out.println(max);
             System.out.println(max + 1);
             long gross = (long) max + 1;
             System.out.println(gross);
             """,
             warning="Java warnt nicht. Bei Zählern, Zeitstempeln oder großen Beträgen lieber gleich long nehmen.",
             verify={"output": "2147483647\n-2147483648\n2147483648"}),
    ],
    "l06-methods": [
        card("Beliebig viele Werte: varargs",
             "Manchmal weißt du nicht, wie viele Werte eine Methode bekommt – zwei Zahlen, fünf oder gar "
             "keine. Dafür gibt es drei Punkte hinter dem Typ: int... zahlen. Beim Aufruf schreibst du die "
             "Werte einfach mit Komma hin. In der Methode liegt zahlen dann als ganz normales Array bereit – "
             "wie ein Eierkarton, in den Java alle übergebenen Eier legt.",
             code="""
             static int summe(int... zahlen) {
                 int gesamt = 0;
                 for (int z : zahlen) {
                     gesamt += z;
                 }
                 return gesamt;
             }
             """,
             tip="Die drei Punkte dürfen nur beim letzten Parameter stehen – sonst wüsste Java nicht, wo die Liste endet.",
             verify={"context": "members", "main": "System.out.println(summe(1, 2, 3));\nSystem.out.println(summe());",
                     "output": "6\n0"}),
    ],
    "l07-arrays-strings": [
        card("Texte mit Platzhaltern: printf und format",
             "Statt Text und Zahlen mit + zusammenzukleben, kannst du eine Schablone schreiben: %s steht "
             "für einen Text, %d für eine ganze Zahl und %n für einen Zeilenumbruch. System.out.printf füllt "
             "die Schablone der Reihe nach mit den Werten dahinter und gibt sie aus. String.format füllt sie "
             "genauso, gibt aber nichts aus, sondern liefert den fertigen Text zurück – etwa, um ihn in "
             "einer Variablen zu speichern.",
             code="""
             String name = "Ada";
             int punkte = 42;
             System.out.printf("%s hat %d Punkte%n", name, punkte);
             String zeile = String.format("%s: %d", "Level", 3);
             System.out.println(zeile);
             """,
             info="%.2f schreibt eine Kommazahl mit zwei Nachkommastellen – auf deutsch eingestellten "
                  "Rechnern mit Komma (3,50), sonst mit Punkt (3.50).",
             verify={"output": "Ada hat 42 Punkte\nLevel: 3"}),
    ],
    "l08-classes": [
        card("Ein Konstruktor ruft den anderen: this(…)",
             "Hat eine Klasse mehrere Konstruktoren, müssen sie dieselbe Arbeit nicht doppelt machen. Mit "
             "this(…) ruft ein Konstruktor einen anderen derselben Klasse auf und reicht Werte weiter – wie "
             "jemand, der sagt: „Mach es wie immer, nur mit diesen Zahlen.“ So steht das eigentliche "
             "Befüllen der Felder nur an einer einzigen Stelle.",
             code="""
             class Punkt {
                 int x;
                 int y;

                 Punkt(int x, int y) {
                     this.x = x;
                     this.y = y;
                 }

                 Punkt() {
                     this(0, 0);
                 }
             }
             """,
             tip="Schreib this(…) als erste Zeile in den Konstruktor: Ältere Java-Versionen verlangen das, "
                 "und so ist sofort klar, wer das Befüllen übernimmt.",
             verify={"context": "file", "main": "Punkt p = new Punkt();\nSystem.out.println(p.x + \",\" + p.y);",
                     "output": "0,0"}),
    ],
    "l09-inheritance": [
        card("Interfaces mit fertiger Methode: default",
             "Ein Interface ist ein Vertrag: Es sagt, WAS eine Klasse können muss. Mit default darf es "
             "aber auch eine fertige Methode mitliefern – eine Standardlösung, die jede Klasse automatisch "
             "bekommt. Wer es anders braucht, überschreibt sie einfach. Das ist praktisch, wenn ein "
             "Interface später eine Methode dazubekommt: Alle bestehenden Klassen funktionieren weiter.",
             code="""
             interface Gruss {
                 String name();

                 default String hallo() {
                     return "Hallo, " + name() + "!";
                 }
             }

             class Katze implements Gruss {
                 public String name() {
                     return "Mimi";
                 }
             }
             """,
             verify={"context": "file", "main": "System.out.println(new Katze().hallo());",
                     "output": "Hallo, Mimi!"}),
    ],
    "l10-exceptions": [
        card("Eigene Exceptions",
             "Manche Fehler gibt es nur in deinem Programm – ein leeres Konto oder ein ungültiger Spielzug. "
             "Dafür baust du eine eigene Exception: eine Klasse, die von RuntimeException (unchecked) oder "
             "von Exception (checked) erbt. Mit super(text) gibst du die Fehlermeldung an die Oberklasse "
             "weiter, und getMessage() liefert sie später wieder. Schon der Name sagt dann, was schiefging.",
             code="""
             class KontoLeerException extends RuntimeException {
                 KontoLeerException(String text) {
                     super(text);
                 }
             }
             """,
             tip="Erbt sie von Exception statt von RuntimeException, ist sie checked: Wer sie auslösen kann, "
                 "muss sie fangen oder mit throws ankündigen.",
             verify={"context": "file",
                     "main": "try {\n    throw new KontoLeerException(\"Nur 5 Euro übrig\");\n"
                             "} catch (KontoLeerException e) {\n    System.out.println(e.getMessage());\n}",
                     "output": "Nur 5 Euro übrig"}),
    ],
    "l11-collections": [
        card("Beim Durchlaufen löschen: Iterator",
             "Eine for-each-Schleife verträgt es nicht, wenn man währenddessen Elemente aus der Liste "
             "löscht – Java bricht mit einer ConcurrentModificationException ab. Ein Iterator ist ein "
             "Lesezeichen, das Element für Element durch die Liste wandert: hasNext() fragt, ob noch etwas "
             "kommt, next() holt es, und remove() löscht genau das zuletzt geholte Element – sicher, ohne "
             "dass die Schleife durcheinanderkommt.",
             code="""
             List<String> namen = new ArrayList<>(List.of("Ada", "Bob", "Anna"));
             Iterator<String> it = namen.iterator();
             while (it.hasNext()) {
                 if (it.next().startsWith("A")) {
                     it.remove();
                 }
             }
             System.out.println(namen);
             """,
             tip="Kürzer geht es mit namen.removeIf(n -> n.startsWith(\"A\")) – intern arbeitet auch das mit einem Iterator.",
             verify={"output": "[Bob]"}),
    ],
    "l12-lambdas": [
        card("Lambdas in Variablen: Function & Predicate",
             "Ein Lambda lässt sich auch in einer Variablen aufbewahren – wie ein Rezept auf einem Zettel. "
             "Die Variable braucht dafür einen passenden Typ: Function<Integer, Integer> nimmt einen Wert "
             "und liefert einen neuen (aufgerufen mit apply), Predicate<String> beantwortet eine "
             "Ja-Nein-Frage (aufgerufen mit test). So benutzt du dieselbe Regel an mehreren Stellen oder "
             "gibst sie an eine Methode weiter.",
             code="""
             Function<Integer, Integer> doppelt = x -> x * 2;
             Predicate<String> lang = s -> s.length() > 4;
             System.out.println(doppelt.apply(21));
             System.out.println(lang.test("Java"));
             """,
             info="Außerdem gibt es Supplier (liefert etwas, ohne etwas zu bekommen) und Consumer "
                  "(bekommt etwas, liefert nichts zurück).",
             verify={"output": "42\nfalse"}),
    ],
    "l15-object-methods": [
        card("Eine Klasse ohne Namen: anonyme Klassen",
             "Manchmal braucht man eine Unterklasse nur ein einziges Mal – dann lohnt sich keine eigene "
             "Klasse mit eigenem Namen. Eine anonyme Klasse schreibst du direkt hinter new: erst die "
             "Oberklasse oder das Interface, dann in geschweiften Klammern gleich die fehlenden Methoden. "
             "Java baut daraus eine namenlose Unterklasse und erzeugt sofort ein Objekt davon.",
             code="""
             abstract class Form {
                 abstract double flaeche();
             }

             public class Main {
                 public static void main(String[] args) {
                     Form quadrat = new Form() {
                         double flaeche() {
                             return 3 * 3;
                         }
                     };
                     System.out.println(quadrat.flaeche());
                 }
             }
             """,
             tip="Hat ein Interface nur eine einzige Methode, schreibt man heute meist ein Lambda. Die anonyme "
                 "Klasse bleibt für abstrakte Klassen und Interfaces mit mehreren Methoden.",
             verify={"context": "file", "output": "9.0"}),
    ],
    "l16-text-input": [
        card("Mehrzeilige Texte: Textblöcke",
             "Soll ein Text über mehrere Zeilen gehen, wird es mit \\n und + schnell unübersichtlich. Ein "
             "Textblock beginnt mit drei Anführungszeichen und einem Zeilenumbruch und endet wieder mit drei "
             "Anführungszeichen. Dazwischen steht der Text genau so, wie er später aussehen soll – mit "
             "echten Zeilenumbrüchen und ohne Plus. Die Einrückung, die alle Zeilen gemeinsam haben, "
             "schneidet Java automatisch ab.",
             code='''
             String gedicht = """
                 Rosen sind rot,
                 Java ist toll.
                 """;
             System.out.print(gedicht);
             ''',
             info="Textblöcke gibt es seit Java 15.",
             verify={"output": "Rosen sind rot,\nJava ist toll."}),
    ],
}

# ---------------------------------------------------------------- Lektionsaufgaben (Anker)
KERNSTOFF_AUFGABEN = {
    "l03-operators": [
        out("t03-6", "operators", 3, "Was gibt das Programm aus?",
            """
            int punkte = Integer.MAX_VALUE;
            punkte++;
            System.out.println(punkte < 0);
            """,
            "true",
            "punkte stand schon auf dem größten int-Wert. Ein Schritt weiter springt die Box ans andere "
            "Ende auf -2147483648 – eine negative Zahl, deshalb ist punkte < 0 wahr. Java meldet dabei "
            "keinen Fehler.",
            hint="Wie verhält sich ein Kilometerzähler, der schon am Ende seiner Skala steht?"),
    ],
    "l06-methods": [
        fill("t06-6", "methods", 3, "Ergänze, damit groesste beliebig viele Zahlen annimmt.",
             """
             static int groesste(int{{0}} zahlen) {
                 int max = zahlen[0];
                 for (int z : zahlen) {
                     if (z > max) {
                         max = z;
                     }
                 }
                 return max;
             }
             """,
             [["..."]],
             "Mit int... nimmt groesste beliebig viele Zahlen an. Innerhalb der Methode ist zahlen ein "
             "ganz normales int-Array – deshalb funktionieren zahlen[0] und die for-each-Schleife genau "
             "wie bei jedem anderen Array.",
             hint="Beliebig viele Werte eines Typs: Dafür gibt es eine eigene Schreibweise direkt hinter dem Typ.",
             ctx="members",
             verify={"main": "System.out.println(groesste(3, 9, 4));\nSystem.out.println(groesste(5));",
                     "output": "9\n5"}),
    ],
    "l07-arrays-strings": [
        out("t07-6", "strings", 3, "Was gibt das Programm aus?",
            """
            String held = "Mia";
            int leben = 3;
            System.out.printf("%s hat noch %d Leben%n", held, leben);
            System.out.printf("%d + %d = %d%n", 2, 3, 2 + 3);
            """,
            """
            Mia hat noch 3 Leben
            2 + 3 = 5
            """,
            "printf ersetzt die Platzhalter der Reihe nach: %s durch den Text „Mia“, %d durch die Zahl 3. "
            "In der zweiten Zeile werden drei %d nacheinander mit 2, 3 und dem Ergebnis von 2 + 3 gefüllt. "
            "%n beendet jeweils die Zeile.",
            hint="Jeder Platzhalter wird der Reihe nach durch den nächsten Wert hinter dem Text ersetzt."),
    ],
    "l08-classes": [
        out("t08-6", "oop", 3, "Was gibt das Programm aus?",
            """
            class Becher {
                String inhalt;
                int ml;

                Becher(String inhalt, int ml) {
                    this.inhalt = inhalt;
                    this.ml = ml;
                }

                Becher(String inhalt) {
                    this(inhalt, 250);
                }
            }

            public class Main {
                public static void main(String[] args) {
                    Becher b = new Becher("Kakao");
                    System.out.println(b.inhalt + ": " + b.ml + " ml");
                }
            }
            """,
            "Kakao: 250 ml",
            "new Becher(\"Kakao\") passt zum Konstruktor mit einem Parameter. Der ruft mit this(inhalt, 250) "
            "den Konstruktor mit zwei Parametern auf, der beide Felder befüllt. Am Ende stehen also „Kakao“ "
            "und 250 im Becher.",
            hint="Folge dem Aufruf: Welcher Konstruktor passt zu einem einzigen Text – und an wen reicht er weiter?",
            ctx="file"),
    ],
    "l09-inheritance": [
        out("t09-6", "inheritance", 3, "Was gibt das Programm aus?",
            """
            interface Fahrzeug {
                default String hupe() {
                    return "Tut";
                }
            }

            class Auto implements Fahrzeug {
            }

            class Lkw implements Fahrzeug {
                public String hupe() {
                    return "TUUUT";
                }
            }

            public class Main {
                public static void main(String[] args) {
                    System.out.println(new Auto().hupe());
                    System.out.println(new Lkw().hupe());
                }
            }
            """,
            """
            Tut
            TUUUT
            """,
            "Auto schreibt hupe nicht selbst und bekommt deshalb die default-Methode aus dem Interface. "
            "Lkw überschreibt hupe mit einer eigenen Fassung – dann gilt die eigene. Die default-Methode "
            "ist nur die Standardlösung für alle, die nichts Eigenes haben.",
            hint="Prüfe für jede Klasse: Hat sie eine eigene hupe-Methode? Wenn nicht, woher bekommt sie eine?",
            ctx="file"),
    ],
    "l10-exceptions": [
        fill("t10-6", "exceptions", 3,
             "Ergänze die eigene Exception: Sie soll unchecked sein und ihre Meldung an die Oberklasse weitergeben.",
             """
             class ZuJungException extends {{0}} {
                 ZuJungException(String text) {
                     {{1}}(text);
                 }
             }
             """,
             [["RuntimeException", "IllegalArgumentException", "IllegalStateException"], ["super"]],
             "Wer von RuntimeException erbt, baut eine unchecked Exception – niemand muss sie mit throws "
             "ankündigen. super(text) reicht die Meldung an den Konstruktor der Oberklasse weiter, deshalb "
             "liefert getMessage() sie später wieder.",
             hint="Die erste Lücke ist die Oberklasse der unchecked Exceptions, die zweite das Wort für den Konstruktor der Oberklasse.",
             ctx="file",
             verify={"main": "try {\n    throw new ZuJungException(\"Erst ab 16\");\n"
                             "} catch (ZuJungException e) {\n    System.out.println(e.getMessage());\n}",
                     "output": "Erst ab 16"}),
    ],
    "l11-collections": [
        out("t11-6", "collections", 3, "Was gibt das Programm aus?",
            """
            List<Integer> zahlen = new ArrayList<>(List.of(4, 7, 10, 3));
            Iterator<Integer> it = zahlen.iterator();
            while (it.hasNext()) {
                int z = it.next();
                if (z % 2 == 0) {
                    it.remove();
                }
            }
            System.out.println(zahlen);
            """,
            "[7, 3]",
            "Der Iterator holt nacheinander 4, 7, 10 und 3. Bei den geraden Zahlen 4 und 10 löscht "
            "it.remove() genau das gerade geholte Element. Übrig bleiben 7 und 3 – in ihrer ursprünglichen "
            "Reihenfolge.",
            hint="Geh die Liste Element für Element durch und streiche alles, was die Bedingung im if erfüllt."),
    ],
    "l12-lambdas": [
        out("t12-6", "lambdas", 3, "Was gibt das Programm aus?",
            """
            Function<String, Integer> laenge = s -> s.length();
            Predicate<Integer> gross = n -> n > 3;
            int n = laenge.apply("Kaffee");
            System.out.println(n);
            System.out.println(gross.test(n));
            """,
            """
            6
            true
            """,
            "laenge.apply(\"Kaffee\") wendet das Lambda an und liefert die Länge 6. gross.test(6) prüft, "
            "ob 6 größer als 3 ist – das stimmt, also true. apply liefert einen Wert, test eine Antwort "
            "ja oder nein.",
            hint="apply wendet eine Regel an und liefert einen Wert, test beantwortet eine Ja-Nein-Frage."),
    ],
    "l15-object-methods": [
        out("t15-6", "objectmethods", 3, "Was gibt das Programm aus?",
            """
            abstract class Tier {
                abstract String laut();

                String vorstellen() {
                    return "Ich mache " + laut();
                }
            }

            public class Main {
                public static void main(String[] args) {
                    Tier eule = new Tier() {
                        String laut() {
                            return "Huhu";
                        }
                    };
                    System.out.println(eule.vorstellen());
                }
            }
            """,
            "Ich mache Huhu",
            "new Tier() { … } baut eine namenlose Unterklasse von Tier und liefert gleich ein Objekt davon. "
            "Sie ergänzt die fehlende Methode laut(); vorstellen() erbt sie unverändert von Tier und setzt "
            "beides zusammen.",
            hint="Die anonyme Klasse liefert nur laut() – vorstellen() kommt aus Tier. Setz beides zusammen.",
            ctx="file"),
    ],
    "l16-text-input": [
        out("t16-6", "io", 3, "Was gibt das Programm aus? Achte auf die Leerzeichen am Zeilenanfang.",
            '''
            String menue = """
                Pizza
                  mit Salami
                Pasta
                """;
            System.out.print(menue);
            ''',
            "Pizza\n  mit Salami\nPasta",
            "Alle Zeilen sind mindestens vier Leerzeichen eingerückt – diese gemeinsame Einrückung schneidet "
            "Java ab. „mit Salami“ war zwei Leerzeichen weiter eingerückt und behält diese zwei. Weil die "
            "schließenden Anführungszeichen in einer eigenen Zeile stehen, endet der Text mit einem Umbruch.",
            hint="Java schneidet nur die Einrückung ab, die alle Zeilen gemeinsam haben – was darüber hinausgeht, bleibt."),
    ],
}

# ---------------------------------------------------------------- Varianten im Übungspool
POOL_KERNSTOFF = [
    # --- Überlauf
    mc("k-ovf-1", "operators", 2, "Was passiert, wenn eine int-Rechnung über Integer.MAX_VALUE hinausgeht?",
       ["Das Ergebnis springt ins Negative – ohne Fehlermeldung",
        "Java bricht mit einer Exception ab",
        "Das Ergebnis bleibt bei Integer.MAX_VALUE stehen",
        "Java macht automatisch einen long daraus"],
       "Eine int-Box hat einen festen Zahlenbereich. Wer darüber hinaus rechnet, landet am anderen Ende: "
       "Aus 2147483647 + 1 wird -2147483648. Java prüft das nicht – das nennt man Überlauf.",
       why=[None,
            "Bei int-Rechnungen gibt es keine Exception – Java rechnet stillschweigend weiter. Nur eigens "
            "dafür gebaute Methoden wie Math.addExact melden so etwas.",
            "Die Box bleibt nicht am Rand stehen, sie läuft über den Rand hinaus auf die andere Seite.",
            "Der Typ ändert sich nie von allein: int bleibt int. Einen long bekommst du nur, wenn du ihn selbst hinschreibst."],
       hint="Denk an einen Kilometerzähler: Was zeigt er an, nachdem er seine höchste Zahl erreicht hat?",
       group="t03-6"),
    fill("k-ovf-2", "operators", 4,
         "Ergänze, damit die Rechnung nicht überläuft: 50000 · 50000 soll 2500000000 ergeben.",
         """
         int a = 50000;
         int b = 50000;
         {{0}} produkt = ({{1}}) a * b;
         System.out.println(produkt);
         """,
         [["long", "var"], ["long"]],
         "a * b wäre eine int-Rechnung und liefe über, weil 2,5 Milliarden nicht in eine int-Box passen. "
         "Mit (long) wird a vor dem Malnehmen zur long-Zahl – dann rechnet Java die ganze Multiplikation "
         "in long, und das Ergebnis passt in die Box produkt.",
         hint="Welcher Zahlentyp fasst mehr als rund 2,1 Milliarden – und wann muss die Umwandlung passieren: vor oder nach dem Malnehmen?",
         verify={"output": "2500000000"},
         group="t03-6"),

    # --- varargs
    out("k-var-1", "methods", 3, "Was gibt das Programm aus?",
        """
        static int anzahl(String... woerter) {
            return woerter.length;
        }

        public static void main(String[] args) {
            System.out.println(anzahl("a", "b", "c"));
            System.out.println(anzahl());
        }
        """,
        """
        3
        0
        """,
        "Die drei übergebenen Texte landen im Array woerter – Länge 3. Ruft man anzahl ganz ohne Werte "
        "auf, bekommt die Methode ein leeres Array, nicht null: Länge 0.",
        hint="Innerhalb der Methode ist woerter ein ganz normales Array – was liefert .length, wenn gar nichts übergeben wurde?",
        ctx="members",
        group="t06-6"),
    code("k-var-2", "methods", 4,
         "Schreibe eine Methode durchschnitt, die beliebig viele double-Werte annimmt und ihren Durchschnitt "
         "zurückgibt. Rufe sie in main mit 2.0, 4.0 und 6.0 auf und gib das Ergebnis aus.",
         """
         // Methode durchschnitt hier

         public static void main(String[] args) {
             // Aufruf und Ausgabe hier
         }
         """,
         """
         static double durchschnitt(double... werte) {
             double summe = 0;
             for (double w : werte) {
                 summe += w;
             }
             return summe / werte.length;
         }

         public static void main(String[] args) {
             System.out.println(durchschnitt(2.0, 4.0, 6.0));
         }
         """,
         [req(r"double\s*\.\.\.\s*\w+", "Nimm die Werte mit double... entgegen – dann passen beliebig viele hinein."),
          req(r"\bdurchschnitt\s*\(\s*2\.0\s*,\s*4\.0\s*,\s*6\.0\s*\)", "Rufe durchschnitt(2.0, 4.0, 6.0) auf."),
          req(r"\breturn\b", "Gib den Durchschnitt mit return zurück."),
          forbid(r"\(\s*double\s*\[\s*\]", "Nimm double... statt eines Arrays als Parameter – dann muss beim Aufruf niemand ein Array bauen.")],
         "Mit double... nimmt die Methode beliebig viele Kommazahlen an; drinnen ist werte ein double-Array. "
         "Summe durch Anzahl (werte.length) ergibt den Durchschnitt: (2 + 4 + 6) / 3 = 4.0.",
         expected="4.0",
         hint="Die Parameterliste braucht die Schreibweise für „beliebig viele“ – und für die Anzahl hat jedes Array eine Eigenschaft.",
         ctx="members",
         group="t06-6"),

    # --- printf / String.format
    mc("k-fmt-1", "strings", 2, "Welcher Platzhalter steht bei printf für eine ganze Zahl?",
       ["%d", "%s", "%n", "%i"],
       "%d steht für eine ganze Zahl (d wie decimal). %s ist für Texte gedacht, %n bricht die Zeile um. "
       "%i gibt es in Java nicht – wer es verwendet, bekommt beim Ausführen einen Fehler.",
       why=[None,
            "%s ist der Platzhalter für Texte. Eine Zahl zeigt er zwar auch an, gedacht ist er aber für Strings.",
            "%n steht für keinen Wert, sondern für einen Zeilenumbruch.",
            "%i kennt man aus anderen Sprachen wie C. Java kennt es nicht und bricht mit einer Exception ab."],
       hint="Schau in die Theoriekarte „Texte mit Platzhaltern“: Dort steht zu jedem Platzhalter, wofür er da ist.",
       group="t07-6"),
    fill("k-fmt-2", "strings", 4,
         "Ergänze: Der fertige Text soll in der Variablen zeile landen, nicht direkt auf dem Bildschirm.",
         """
         String name = "Tom";
         int alter = 12;
         String zeile = String.{{0}}("%s ist %d Jahre alt", name, alter);
         System.out.println(zeile);
         """,
         [["format"]],
         "String.format füllt die Schablone genau wie printf, gibt aber nichts aus – es liefert den fertigen "
         "Text zurück. So kann er in zeile gespeichert und später weiterverwendet werden.",
         hint="printf würde sofort ausgeben. Gesucht ist die Methode der Klasse String, die dieselbe Schablone füllt und den Text zurückgibt.",
         verify={"output": "Tom ist 12 Jahre alt"},
         group="t07-6"),

    # --- this(…)
    mc("k-this-1", "oop", 2, "Was bewirkt this(0, 0) im Konstruktor Punkt()?",
       ["Es ruft den anderen Konstruktor der Klasse mit 0 und 0 auf",
        "Es erzeugt ein zweites Punkt-Objekt",
        "Es setzt nur das Feld x auf 0",
        "Es ruft den Konstruktor der Oberklasse auf"],
       "this(0, 0) ruft den Konstruktor derselben Klasse auf, der zwei Zahlen erwartet, und reicht 0 und 0 "
       "weiter. Er arbeitet am selben Objekt, das gerade gebaut wird – es entsteht kein zweites.",
       why=[None,
            "Es entsteht kein neues Objekt: this(…) arbeitet am selben Objekt weiter, das gerade gebaut wird.",
            "this(0, 0) übergibt beide Werte an einen passenden Konstruktor – der setzt x und y.",
            "Das wäre super(…). Mit this(…) bleibt der Aufruf in derselben Klasse."],
       hint="Schau, welche anderen Konstruktoren Punkt hat – und welcher davon zu zwei Zahlen passt.",
       group="t08-6"),
    fill("k-this-2", "oop", 4, "Ergänze: Der Konstruktor ohne Alter soll 18 als Alter weiterreichen.",
         """
         class Mitglied {
             String name;
             int alter;

             Mitglied(String name, int alter) {
                 this.name = name;
                 this.alter = alter;
             }

             Mitglied(String name) {
                 {{0}}(name, 18);
             }
         }
         """,
         [["this"]],
         "this(name, 18) ruft den Konstruktor mit zwei Parametern auf und gibt den Namen und die 18 weiter. "
         "So steht das Befüllen der Felder nur an einer Stelle und muss nicht doppelt geschrieben werden.",
         hint="Gesucht ist das Wort, mit dem ein Konstruktor einen anderen Konstruktor derselben Klasse aufruft – nicht den der Oberklasse.",
         ctx="file",
         verify={"main": "Mitglied m = new Mitglied(\"Lea\");\nSystem.out.println(m.name + \" \" + m.alter);",
                 "output": "Lea 18"},
         group="t08-6"),

    # --- default-Methoden
    mc("k-def-1", "inheritance", 2, "Was erlaubt das Schlüsselwort default in einem Interface?",
       ["Eine fertige Methode, die Klassen übernehmen oder überschreiben können",
        "Einen Standardwert für ein Feld",
        "Einen default-Zweig wie im switch",
        "Eine Methode, die keine Klasse überschreiben darf"],
       "Mit default liefert ein Interface eine fertige Methode mit. Jede Klasse, die das Interface "
       "umsetzt, bekommt sie automatisch – und darf sie überschreiben, wenn sie es anders braucht.",
       why=[None,
            "Felder in Interfaces sind immer Konstanten. Mit default hat das nichts zu tun.",
            "default gibt es auch im switch, dort heißt es „alle übrigen Fälle“. In einem Interface markiert es etwas anderes.",
            "Das Gegenteil stimmt: Jede Klasse darf eine default-Methode überschreiben."],
       hint="Denk an den Vertrag, den ein Interface darstellt – und daran, was eine Klasse bekommt, die eine Methode nicht selbst schreibt.",
       group="t09-6"),
    fill("k-def-2", "inheritance", 4,
         "Ergänze, damit das Interface leer() gleich mitliefert und Korb die Methode nicht selbst schreiben muss.",
         """
         interface Zaehlbar {
             int anzahl();

             {{0}} boolean leer() {
                 return anzahl() == 0;
             }
         }

         class Korb implements Zaehlbar {
             public int anzahl() {
                 return 0;
             }
         }
         """,
         [["default"]],
         "Ohne default wäre leer() eine Methode ohne Inhalt, die jede Klasse selbst schreiben müsste. Mit "
         "default bringt das Interface die Umsetzung mit – sie nutzt anzahl(), die jede Klasse ohnehin liefern muss.",
         hint="Vor boolean fehlt das Schlüsselwort, das einer Interface-Methode einen fertigen Inhalt erlaubt.",
         ctx="file",
         verify={"main": "System.out.println(new Korb().leer());", "output": "true"},
         group="t09-6"),

    # --- eigene Exceptions
    out("k-exc-1", "exceptions", 3, "Was gibt das Programm aus?",
        """
        class LeerException extends RuntimeException {
            LeerException(String text) {
                super(text);
            }
        }

        public class Main {
            static int erstes(int[] zahlen) {
                if (zahlen.length == 0) {
                    throw new LeerException("Keine Zahlen");
                }
                return zahlen[0];
            }

            public static void main(String[] args) {
                try {
                    System.out.println(erstes(new int[] {7, 8}));
                    System.out.println(erstes(new int[] {}));
                    System.out.println("Fertig");
                } catch (LeerException e) {
                    System.out.println("Fehler: " + e.getMessage());
                }
            }
        }
        """,
        """
        7
        Fehler: Keine Zahlen
        """,
        "Der erste Aufruf liefert 7. Beim leeren Array wirft erstes die eigene LeerException – der Rest des "
        "try-Blocks wird übersprungen, auch die letzte Ausgabe. Der catch-Block fängt sie und gibt die "
        "Meldung aus, die per super(text) gespeichert wurde.",
        hint="Verfolge die drei Ausgaben im try-Block: Welche davon wird nach der Exception noch erreicht?",
        ctx="file",
        group="t10-6"),
    code("k-exc-2", "exceptions", 4,
         "Schreibe eine eigene unchecked Exception NegativException mit einem Konstruktor, der eine Meldung "
         "annimmt und an die Oberklasse weitergibt. Die Methode pruefe wirft sie schon – ergänze nur die Klasse.",
         """
         // Klasse NegativException hier

         public class Main {
             static void pruefe(int wert) {
                 if (wert < 0) {
                     throw new NegativException("Wert negativ: " + wert);
                 }
             }

             public static void main(String[] args) {
                 try {
                     pruefe(-3);
                 } catch (NegativException e) {
                     System.out.println(e.getMessage());
                 }
             }
         }
         """,
         """
         class NegativException extends RuntimeException {
             NegativException(String text) {
                 super(text);
             }
         }

         public class Main {
             static void pruefe(int wert) {
                 if (wert < 0) {
                     throw new NegativException("Wert negativ: " + wert);
                 }
             }

             public static void main(String[] args) {
                 try {
                     pruefe(-3);
                 } catch (NegativException e) {
                     System.out.println(e.getMessage());
                 }
             }
         }
         """,
         [req(r"class\s+NegativException\s+extends\s+(RuntimeException|IllegalArgumentException|IllegalStateException)\b",
              "NegativException soll von RuntimeException erben – dann ist sie unchecked und pruefe braucht kein throws."),
          req(r"NegativException\s*\(\s*String\s+\w+\s*\)", "Der Konstruktor braucht einen String-Parameter für die Meldung."),
          req(r"\bsuper\s*\(\s*\w+\s*\)", "Gib die Meldung mit super(…) an die Oberklasse weiter – sonst liefert getMessage() nichts.")],
         "Die Klasse erbt von RuntimeException und ist damit unchecked – pruefe muss sie nicht mit throws "
         "ankündigen. Der Konstruktor nimmt die Meldung entgegen und reicht sie mit super(…) weiter; "
         "getMessage() gibt sie im catch-Block wieder aus.",
         expected="Wert negativ: -3",
         hint="Die Klasse braucht zwei Dinge: die passende Oberklasse hinter extends und einen Konstruktor, der seinen Text weiterreicht.",
         ctx="file",
         group="t10-6"),

    # --- Iterator
    mc("k-it-1", "collections", 3,
       "Warum nimmt man einen Iterator statt einer for-each-Schleife, um beim Durchlaufen Elemente zu löschen?",
       ["Weil for-each beim Löschen mit einer ConcurrentModificationException abbricht",
        "Weil ein Iterator schneller ist",
        "Weil for-each keine Listen durchlaufen kann",
        "Weil remove() nur bei Arrays funktioniert"],
       "Löscht man in einer for-each-Schleife aus der Liste, merkt Java beim nächsten Schritt, dass sich die "
       "Liste verändert hat, und bricht ab. Der Iterator weiß über seine eigenen Löschungen Bescheid – mit "
       "it.remove() geht es sicher.",
       why=[None,
            "Um Tempo geht es nicht – beide laufen die Liste gleich schnell durch. Der Unterschied zeigt sich erst beim Löschen.",
            "for-each durchläuft Listen problemlos, solange man sie dabei nicht verändert.",
            "Arrays haben gar kein remove(). Listen schon – nur eben nicht mitten in einer for-each-Schleife."],
       hint="Überleg, was passiert, wenn man einer Schleife die Liste verändert, die sie gerade durchläuft.",
       group="t11-6"),
    fill("k-it-2", "collections", 4, "Ergänze die Schleife, die mit dem Iterator alle leeren Texte entfernt.",
         """
         List<String> woerter = new ArrayList<>(List.of("Java", "", "macht", "", "Spass"));
         Iterator<String> it = woerter.iterator();
         while (it.{{0}}()) {
             if (it.{{1}}().isEmpty()) {
                 it.{{2}}();
             }
         }
         System.out.println(woerter);
         """,
         [["hasNext"], ["next"], ["remove"]],
         "hasNext() fragt, ob noch ein Element kommt, next() holt es, und remove() löscht genau dieses "
         "zuletzt geholte Element. So verschwinden die beiden leeren Texte, ohne dass die Schleife "
         "durcheinanderkommt.",
         hint="Drei Schritte des Lesezeichens: fragen, ob noch etwas kommt – das Nächste holen – das Geholte löschen.",
         verify={"output": "[Java, macht, Spass]"},
         group="t11-6"),

    # --- Function & Predicate
    mc("k-fun-1", "lambdas", 2,
       "Welcher Typ passt zu einem Lambda, das eine Ja-Nein-Frage über einen String beantwortet?",
       ["Predicate<String>", "Function<String, String>", "Supplier<String>", "Consumer<String>"],
       "Ein Predicate beantwortet eine Frage mit true oder false und wird mit test aufgerufen – etwa "
       "s -> s.isEmpty(). Function liefert einen Wert, Supplier liefert ohne Eingabe, Consumer nimmt nur entgegen.",
       why=[None,
            "Function<String, String> liefert wieder einen String – keine Antwort ja oder nein.",
            "Ein Supplier bekommt gar nichts, er liefert nur etwas. Hier soll aber ein String geprüft werden.",
            "Ein Consumer nimmt den String entgegen, gibt aber nichts zurück – auch kein Ja oder Nein."],
       hint="Ja oder nein heißt: Das Ergebnis ist ein boolean. Welches dieser Interfaces liefert genau das?",
       group="t12-6"),
    code("k-fun-2", "lambdas", 4,
         "Lege in der Variablen quadrat eine Function<Integer, Integer> an, die ihre Zahl mit sich selbst "
         "malnimmt, und gib quadrat.apply(7) aus.",
         """
         // Function quadrat hier
         """,
         """
         Function<Integer, Integer> quadrat = x -> x * x;
         System.out.println(quadrat.apply(7));
         """,
         [req(r"Function\s*<\s*Integer\s*,\s*Integer\s*>\s+quadrat\s*=", "Lege quadrat als Function<Integer, Integer> an."),
          req(r"->", "Belege quadrat mit einem Lambda: x -> …"),
          req(r"quadrat\s*\.\s*apply\s*\(\s*7\s*\)", "Rufe quadrat.apply(7) auf und gib das Ergebnis aus.")],
         "Function<Integer, Integer> bedeutet: nimmt eine ganze Zahl, liefert eine ganze Zahl. Das Lambda "
         "x -> x * x beschreibt die Regel, apply(7) wendet sie an: 7 · 7 = 49.",
         expected="49",
         hint="Der Typ steht vor dem Variablennamen, das Lambda nach dem Gleichheitszeichen – angewendet wird eine Function mit apply.",
         group="t12-6"),

    # --- anonyme Klassen
    mc("k-anon-1", "objectmethods", 3,
       "Was entsteht bei new Tier() { String laut() { return \"Muh\"; } }, wenn Tier eine abstrakte Klasse ist?",
       ["Ein Objekt einer namenlosen Unterklasse von Tier",
        "Ein Objekt der abstrakten Klasse Tier selbst",
        "Eine neue Methode in der Klasse Tier",
        "Ein Lambda"],
       "Hinter new Tier() folgt ein Klassenkörper: Java baut daraus eine Unterklasse von Tier ohne eigenen "
       "Namen und erzeugt sofort ein Objekt davon. Deshalb klappt das auch mit abstrakten Klassen – die "
       "Unterklasse liefert die fehlende Methode.",
       why=[None,
            "Von einer abstrakten Klasse selbst kann man kein Objekt bauen – es entsteht eine Unterklasse, die die fehlende Methode ergänzt.",
            "Tier bleibt unverändert. Die Methode gehört nur zu dieser einen Unterklasse ohne Namen.",
            "Ein Lambda sähe anders aus, etwa x -> …, und passt nur zu Interfaces mit einer einzigen Methode, nicht zu abstrakten Klassen."],
       hint="Tier ist abstrakt – überleg, was Java daraus machen muss, damit trotzdem ein Objekt entstehen kann.",
       group="t15-6"),
    fill("k-anon-2", "objectmethods", 4,
         "Ergänze, damit speichern ein Objekt einer anonymen Klasse bekommt, die Aktion umsetzt.",
         """
         interface Aktion {
             void ausfuehren();
         }

         public class Main {
             public static void main(String[] args) {
                 Aktion speichern = {{0}} Aktion() {
                     public void ausfuehren() {
                         System.out.println("Gespeichert");
                     }
                 };
                 speichern.ausfuehren();
             }
         }
         """,
         [["new"]],
         "new Aktion() { … } erzeugt ein Objekt einer namenlosen Klasse, die das Interface Aktion umsetzt. "
         "Weil Aktion nur eine Methode hat, ginge es heute kürzer mit einem Lambda: "
         "Aktion speichern = () -> System.out.println(\"Gespeichert\");",
         hint="Wie bei jedem Objekt fehlt vor dem Typnamen das Wort, mit dem Java ein neues Objekt baut.",
         ctx="file",
         verify={"output": "Gespeichert"},
         group="t15-6"),

    # --- Textblöcke
    mc("k-tb-1", "io", 2, "Womit beginnt ein Textblock in Java?",
       ['Mit drei Anführungszeichen """ und einem Zeilenumbruch',
        "Mit einem einzelnen Anführungszeichen und \\n",
        "Mit dem Wort text",
        "Mit einem Backslash"],
       "Ein Textblock beginnt mit drei Anführungszeichen, auf die direkt ein Zeilenumbruch folgt, und endet "
       "wieder mit drei Anführungszeichen. Dazwischen steht der Text mit echten Zeilenumbrüchen – ohne \\n "
       "und ohne Plus.",
       why=[None,
            "Das ist ein ganz normaler String mit einem Zeilenumbruch darin – kein Textblock.",
            "Ein Schlüsselwort text gibt es in Java nicht.",
            "Ein Backslash leitet in Strings Sonderzeichen wie \\n ein, aber keinen Textblock."],
       hint="Schau in die Theoriekarte „Mehrzeilige Texte“: Wie sieht die erste Zeile eines Textblocks aus?",
       group="t16-6"),
    fill("k-tb-2", "io", 3, "Ergänze Anfang und Ende des Textblocks.",
         '''
         String adresse = {{0}}
             Musterweg 1
             12345 Beispielstadt
             {{1}};
         System.out.print(adresse);
         ''',
         [['"""'], ['"""']],
         "Ein Textblock beginnt und endet mit drei Anführungszeichen. Der Anfang muss am Zeilenende stehen, "
         "der eigentliche Text beginnt erst in der nächsten Zeile. Weil das Ende in einer eigenen Zeile "
         "steht, endet der Text mit einem Umbruch.",
         hint="Anfang und Ende sehen gleich aus: das Zeichen, mit dem jeder String beginnt – nur öfter.",
         verify={"output": "Musterweg 1\n12345 Beispielstadt"},
         group="t16-6"),
]

# ---------------------------------------------------------------- gleichwertige Lösungen
# Jede Code-Aufgabe braucht mindestens einen zweiten, ebenso richtigen Weg – der Prüfer
# soll nicht den einen Lösungsweg belohnen, den die Musterlösung zufällig nimmt.
KERNSTOFF_GLEICHWERTIG = {
    "k-var-2": ["""static double durchschnitt(double... werte) {
    return Arrays.stream(werte).average().orElse(0);
}

public static void main(String[] args) {
    double ergebnis = durchschnitt(2.0, 4.0, 6.0);
    System.out.println(ergebnis);
}"""],
    "k-exc-2": ["""class NegativException extends IllegalArgumentException {
    public NegativException(String meldung) {
        super(meldung);
    }
}

public class Main {
    static void pruefe(int wert) {
        if (wert < 0) {
            throw new NegativException("Wert negativ: " + wert);
        }
    }

    public static void main(String[] args) {
        try {
            pruefe(-3);
        } catch (NegativException e) {
            System.out.println(e.getMessage());
        }
    }
}"""],
    "k-fun-2": ["""Function<Integer, Integer> quadrat = (Integer x) -> {
    return x * x;
};
int ergebnis = quadrat.apply(7);
System.out.println(ergebnis);"""],
}
