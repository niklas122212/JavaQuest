"""Übungspool, Teil 8b: mehr Aufgaben je Thema – Objekte und robuster Code.

Gleiche Absicht wie Teil 8a, nur für die mittleren Themen: Klassen & Objekte,
Vererbung, Exceptions, Collections, Generics, modernes Java, Enums und die
Objektmethoden. Auffällig dünn war hier vor allem der Einstieg – bei Generics gab
es keine einzige Aufgabe auf Stufe 1, obwohl spitze Klammern zu den Dingen gehören,
die man zuerst nicht versteht.
"""
from authoring import code, fill, forbid, mc, out, req

# ---------------------------------------------------------------- Klassen & Objekte
OOP = [
    mc("x-oop-1a", "oop", 1, "Was ist der Unterschied zwischen einer Klasse und einem Objekt?",
       ["Die Klasse ist der Bauplan, das Objekt das daraus gebaute Ding",
        "Eine Klasse ist ein Objekt mit weniger Feldern",
        "Objekte gibt es nur für Zahlen, Klassen nur für Text",
        "Das sind zwei Wörter für dieselbe Sache"],
       "Die Klasse steht einmal in der Datei und beschreibt, welche Felder und Methoden es gibt. Mit new "
       "entstehen daraus beliebig viele Objekte – jedes mit eigenen Werten in seinen Feldern.",
       why=[None,
            "Beide haben dieselben Felder – die Klasse beschreibt sie, das Objekt füllt sie mit Werten.",
            "Beides gilt für jede Sorte von Daten. Der Typ der Felder hat mit dem Unterschied nichts zu tun.",
            "Der Unterschied ist wesentlich: Von einer Klasse kann es viele Objekte geben, die sich in ihren "
            "Werten unterscheiden."],
       group="t08-1"),
    mc("x-oop-2a", "oop", 2, "Wozu dient ein Getter wie getName()?",
       ["Er gibt den Wert eines privaten Feldes nach außen, ohne das Feld selbst freizugeben",
        "Er erzeugt ein neues Objekt der Klasse",
        "Er macht das Feld dauerhaft öffentlich",
        "Er löscht den Wert, nachdem er ihn gelesen hat"],
       "Das Feld bleibt privat – von außen kommt man nur über die Methode heran. Der Vorteil: Die Klasse "
       "behält die Kontrolle und könnte beim Lesen noch etwas prüfen oder umrechnen.",
       why=[None,
            "Objekte entstehen mit new und dem Konstruktor. Ein Getter liest nur, was schon da ist.",
            "Das Feld bleibt private. Genau darin liegt der Sinn: Der Zugang läuft ausschließlich über die Methode.",
            "Gelesen heißt nicht entnommen – der Wert bleibt im Feld stehen und kann beliebig oft gelesen werden."],
       group="t08-2"),
    out("x-oop-3a", "oop", 3, "Was gibt das Programm aus?",
        """
        class Zaehler {
            private int stand = 0;

            void hoch() {
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
                a.hoch();
                a.hoch();
                b.hoch();
                System.out.println(a.getStand());
                System.out.println(b.getStand());
            }
        }
        """,
        """
        2
        1
        """,
        "Jedes new legt ein eigenes Objekt mit eigenem Feld stand an. a und b zählen deshalb getrennt – "
        "was bei a passiert, lässt b unberührt.",
        ctx="file",
        group="t08-3"),
    out("x-oop-4a", "oop", 4, "Was gibt das Programm aus?",
        """
        class Box {
            int wert = 1;
        }

        public class Main {
            public static void main(String[] args) {
                Box a = new Box();
                Box b = a;
                b.wert = 5;
                System.out.println(a.wert);
                System.out.println(a == b);
            }
        }
        """,
        """
        5
        true
        """,
        "Box b = a legt kein zweites Objekt an, sondern nur einen zweiten Namen für dasselbe. Beide zeigen "
        "auf dieselbe Box im Speicher – wer über b etwas ändert, ändert es auch für a. Ein zweites Objekt "
        "entstünde nur mit einem weiteren new.",
        ctx="file",
        group="t08-3"),
    fill("x-oop-4b", "oop", 4, "Ergänze den Konstruktor, der beide Felder füllt.",
         """
         class Punkt {
             private int x;
             private int y;

             Punkt(int x, int y) {
                 {{0}}.x = x;
                 this.y = {{1}};
             }

             int getX() {
                 return x;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Punkt(3, 4).getX());
             }
         }
         """,
         [["this"], ["y"]],
         "Feld und Parameter heißen gleich – ohne this wäre unklar, welches gemeint ist. Links vom "
         "Gleichheitszeichen steht mit this das Feld des Objekts, rechts der übergebene Wert.",
         hint="Links das Feld des Objekts, rechts der Wert aus den Klammern des Konstruktors.",
         ctx="file",
         verify={"context": "file", "output": "3"},
         group="t08-4"),
    code("x-oop-5a", "oop", 5,
         "Schreibe die Klasse Sparschwein: ein privates int-Feld stand, die Methode einzahlen(int betrag), die den Stand erhöht, und getStand(), die ihn zurückgibt.",
         """
         // Klasse Sparschwein hier schreiben
         """,
         """
         class Sparschwein {
             private int stand;

             void einzahlen(int betrag) {
                 stand += betrag;
             }

             int getStand() {
                 return stand;
             }
         }
         """,
         [req(r"class\s+Sparschwein", "Es fehlt die Klasse Sparschwein."),
          req(r"private\s+int\s+stand", "Das Feld stand soll privat sein – von außen nur über die Methoden erreichbar."),
          req(r"void\s+einzahlen\s*\(\s*int\s+betrag\s*\)", "Die Methode heißt einzahlen und nimmt einen int entgegen."),
          req(r"stand\s*(\+=|=\s*stand\s*\+)", "Beim Einzahlen soll der alte Stand erhalten bleiben und wachsen."),
          req(r"int\s+getStand\s*\(\s*\)", "getStand() gibt den Stand zurück."),
          req(r"return\s+stand", "getStand() muss den Stand auch wirklich zurückgeben.")],
         "Das ist das Grundmuster der Kapselung: Der Wert liegt privat im Objekt, verändert wird er nur über "
         "eine Methode. So kann von außen niemand einen unsinnigen Stand hineinschreiben.",
         ctx="file",
         verify={"context": "file",
                 "main": "Sparschwein s = new Sparschwein();\ns.einzahlen(3);\ns.einzahlen(4);\nSystem.out.println(s.getStand());",
                 "output": "7"},
         group="t08-5"),
]

# ---------------------------------------------------------------- Vererbung & Interfaces
INHERITANCE = [
    mc("x-inh-1a", "inheritance", 1, "Was übernimmt eine Kind-Klasse von ihrer Eltern-Klasse?",
       ["Alle Felder und Methoden, die nicht privat sind",
        "Nur die Felder, keine Methoden",
        "Nur die Methoden, vor denen super steht",
        "Gar nichts – sie muss alles selbst noch einmal schreiben"],
       "Erben heißt: Die Kind-Klasse hat all das schon, ohne es aufzuschreiben. Nur was private ist, bleibt "
       "der Eltern-Klasse vorbehalten – daran kommt das Kind nur über öffentliche Methoden heran.",
       why=[None,
            "Methoden werden genauso vererbt wie Felder. Sonst hätte Vererbung wenig Nutzen.",
            "super ist kein Kennzeichen am Methodenkopf, sondern ein Weg, die Fassung der Eltern-Klasse "
            "aufzurufen.",
            "Genau umgekehrt: Vererbung erspart das Abschreiben. Die Kind-Klasse ergänzt nur, was neu ist."],
       group="t09-1"),
    mc("x-inh-2a", "inheritance", 2, "Was bedeutet @Override über einer Methode?",
       ["Diese Methode ersetzt eine gleichnamige Methode der Eltern-Klasse",
        "Diese Methode darf von niemandem mehr überschrieben werden",
        "Diese Methode wird zweimal ausgeführt",
        "Diese Methode gehört der Klasse, nicht einem einzelnen Objekt"],
       "@Override ist eine Notiz an den Compiler: „Das soll eine Methode von oben ersetzen.“ Stimmt der "
       "Name oder die Zutatenliste nicht überein, meldet er sofort einen Fehler – sonst hätte man "
       "versehentlich eine zweite, nie aufgerufene Methode geschrieben.",
       why=[None,
            "Das Überschreiben verbietet final, nicht @Override.",
            "Ausgeführt wird die Methode ganz normal einmal. @Override ändert am Ablauf gar nichts.",
            "Der Klasse statt dem Objekt gehört eine Methode mit static."],
       group="t09-2"),
    out("x-inh-3a", "inheritance", 3, "Was gibt das Programm aus?",
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
        "Links steht Tier, rechts entsteht eine Kuh. Beim Aufruf zählt, was wirklich im Speicher liegt – "
        "und das ist eine Kuh. Java nimmt deshalb deren Fassung von laut(). Das ist der Kern der "
        "Polymorphie: Der Typ links bestimmt nur, welche Methoden man aufrufen darf.",
        ctx="file",
        group="t09-3"),
    out("x-inh-4a", "inheritance", 4, "In welcher Reihenfolge erscheinen die Buchstaben?",
        """
        class A {
            A() {
                System.out.println("A");
            }
        }

        class B extends A {
            B() {
                System.out.println("B");
            }
        }

        public class Main {
            public static void main(String[] args) {
                new B();
            }
        }
        """,
        """
        A
        B
        """,
        "Bevor der Konstruktor von B loslegt, ruft Java unsichtbar den der Eltern-Klasse auf. Das Erbe wird "
        "also zuerst aufgebaut – erst danach ergänzt das Kind seinen eigenen Teil.",
        ctx="file",
        group="t09-3"),
    fill("x-inh-4b", "inheritance", 4, "Ergänze das Schlüsselwort: Rechnung soll den Vertrag Zahlbar unterschreiben.",
         """
         interface Zahlbar {
             double betrag();
         }

         class Rechnung {{0}} Zahlbar {
             public double betrag() {
                 return 19.99;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Rechnung().betrag());
             }
         }
         """,
         [["implements"]],
         "Ein Interface ist ein Vertrag ohne Inhalt: Es sagt, welche Methoden es geben muss. Wer ihn "
         "unterschreibt, schreibt implements – und muss jede verlangte Methode liefern. extends wäre "
         "Vererbung von einer Klasse und hier falsch.",
         hint="Nicht „erben von“, sondern „umsetzen“.",
         ctx="file",
         verify={"context": "file", "output": "19.99"},
         group="t09-4"),
    code("x-inh-5a", "inheritance", 5,
         "Schreibe unter Fahrzeug die Klasse Fahrrad, die davon erbt. Ihr Konstruktor bekommt nur die Anzahl der Gänge und gibt die feste Räderzahl 2 an den Konstruktor der Eltern-Klasse weiter.",
         """
         class Fahrzeug {
             int raeder;

             Fahrzeug(int raeder) {
                 this.raeder = raeder;
             }
         }

         // Klasse Fahrrad hier ergänzen
         """,
         """
         class Fahrzeug {
             int raeder;

             Fahrzeug(int raeder) {
                 this.raeder = raeder;
             }
         }

         class Fahrrad extends Fahrzeug {
             int gaenge;

             Fahrrad(int gaenge) {
                 super(2);
                 this.gaenge = gaenge;
             }
         }
         """,
         [req(r"class\s+Fahrrad\s+extends\s+Fahrzeug", "Fahrrad erbt von Fahrzeug – dafür steht extends."),
          req(r"super\s*\(\s*2\s*\)", "Die Räderzahl gibst du mit super(2) an die Eltern-Klasse weiter."),
          req(r"int\s+gaenge", "Fahrrad braucht ein eigenes Feld für die Gänge."),
          req(r"this\.gaenge\s*=", "Der übergebene Wert gehört in das Feld gaenge.")],
         "Die Eltern-Klasse hat keinen Konstruktor ohne Zutaten, also muss das Kind ausdrücklich sagen, "
         "womit sie aufgebaut werden soll. super(…) muss dabei die allererste Anweisung im Konstruktor sein – "
         "erst steht das Erbe, dann das Eigene.",
         ctx="file",
         verify={"context": "file",
                 "main": 'Fahrrad f = new Fahrrad(7);\nSystem.out.println(f.raeder + " " + f.gaenge);',
                 "output": "2 7"},
         group="t09-5"),
]

# ---------------------------------------------------------------- Exceptions
EXCEPTIONS = [
    mc("x-exc-1a", "exceptions", 1, "Was passiert, wenn eine Exception nirgends aufgefangen wird?",
       ["Das Programm bricht an dieser Stelle ab und meldet den Fehler",
        "Das Programm läuft einfach in der nächsten Zeile weiter",
        "Java setzt automatisch einen sinnvollen Standardwert ein",
        "Das Programm startet von vorn"],
       "Eine Exception steigt so lange nach oben, bis sie jemand fängt. Findet sich niemand, endet das "
       "Programm – mit einer Meldung, die zeigt, wo der Fehler auftrat.",
       why=[None,
            "Weiterlaufen gibt es nicht: Ab der Fehlerstelle wird der restliche Block übersprungen.",
            "Raten tut Java nicht. Was bei einem Fehler geschehen soll, muss im catch stehen.",
            "Neu gestartet wird nichts. Das Programm endet."],
       group="t10-1"),
    out("x-exc-2a", "exceptions", 2, "Was wird ausgegeben?",
        """
        try {
            int[] zahlen = {1, 2};
            System.out.println(zahlen[5]);
        } catch (ArrayIndexOutOfBoundsException e) {
            System.out.println("Index daneben");
        } finally {
            System.out.println("fertig");
        }
        """,
        """
        Index daneben
        fertig
        """,
        "Der Zugriff auf Fach 5 scheitert, die Zeile mit println wird deshalb gar nicht erst zu Ende "
        "ausgeführt. Java springt sofort ins catch – und der finally-Block läuft danach in jedem Fall.",
        group="t10-2"),
    mc("x-exc-2b", "exceptions", 2, "Wann läuft ein finally-Block?",
       ["Immer – ob ein Fehler auftrat oder nicht",
        "Nur wenn kein Fehler auftrat",
        "Nur wenn ein Fehler auftrat",
        "Nur wenn man ihn selbst aufruft"],
       "finally ist für Aufräumarbeiten gedacht, die auf keinen Fall ausfallen dürfen – eine Datei "
       "schließen zum Beispiel. Deshalb läuft der Block in jedem Fall.",
       why=[None,
            "Gerade im Fehlerfall ist finally besonders wichtig: Auch dann muss aufgeräumt werden.",
            "Auch ohne Fehler läuft finally – sonst würde beim Normalfall nichts geschlossen.",
            "Aufrufen kann man finally nicht. Java führt den Block von selbst aus, sobald das try verlassen wird."],
       group="t10-1"),
    out("x-exc-3a", "exceptions", 3, "Was wird ausgegeben?",
        """
        try {
            System.out.println(10 / 0);
        } catch (ArithmeticException e) {
            System.out.println("Fehler: " + e.getMessage());
        }
        """,
        "Fehler: / by zero",
        "Durch 0 zu teilen ist bei ganzen Zahlen nicht möglich – Java löst eine ArithmeticException aus. "
        "Das gefangene Objekt e trägt die Begründung bei sich; getMessage() holt sie heraus.",
        group="t10-2"),
    out("x-exc-4a", "exceptions", 4, "Was gibt das Programm aus?",
        """
        static void pruefe(String text) {
            try {
                System.out.println(Integer.parseInt(text) * 2);
            } catch (NumberFormatException e) {
                System.out.println("keine Zahl: " + text);
            }
        }

        public static void main(String[] args) {
            pruefe("21");
            pruefe("zwei");
        }
        """,
        """
        42
        keine Zahl: zwei
        """,
        "parseInt verwandelt Text in eine Zahl – aber nur, wenn wirklich eine darinsteht. Bei „zwei“ "
        "scheitert die Umwandlung und der catch-Block übernimmt. Weil das try in der Methode steht, "
        "läuft das Programm danach ganz normal weiter.",
        ctx="members",
        group="t10-3"),
    fill("x-exc-4b", "exceptions", 4, "Ergänze das Schlüsselwort, mit dem der Fehler ausgelöst wird.",
         """
         static int wurzelAus(int n) {
             if (n < 0) {
                 {{0}} new IllegalArgumentException("negativ");
             }
             return (int) Math.sqrt(n);
         }

         public static void main(String[] args) {
             System.out.println(wurzelAus(9));
             try {
                 wurzelAus(-1);
             } catch (IllegalArgumentException e) {
                 System.out.println("abgefangen: " + e.getMessage());
             }
         }
         """,
         [["throw"]],
         "throw löst den Alarm aus: Die Methode bricht sofort ab und reicht das Fehlerobjekt nach oben. "
         "Nicht zu verwechseln mit throws im Methodenkopf – das kündigt nur an, dass ein Fehler kommen könnte.",
         hint="Englisch für „werfen“ – in der Einzahl, ohne s.",
         ctx="members",
         verify={"context": "members", "output": "3\nabgefangen: negativ"},
         group="t10-4"),
    code("x-exc-5a", "exceptions", 5,
         "Teile 100 durch jede Zahl im Array und gib das Ergebnis aus. Bei einer 0 soll das Programm nicht abstürzen, sondern „nicht teilbar“ ausgeben.",
         """
         int[] teiler = {5, 0, 4};
         // Schleife mit Sicherheitsnetz
         """,
         """
         int[] teiler = {5, 0, 4};
         for (int t : teiler) {
             try {
                 System.out.println(100 / t);
             } catch (ArithmeticException e) {
                 System.out.println("nicht teilbar");
             }
         }
         """,
         [req(r"for\s*\(", "Geh mit einer Schleife durch das Array."),
          req(r"try", "Die riskante Rechnung gehört in einen try-Block."),
          req(r"catch\s*\(\s*ArithmeticException", "Die Division durch 0 löst eine ArithmeticException aus."),
          req(r"100\s*/", "Geteilt wird 100 durch den jeweiligen Wert."),
          req(r'"nicht teilbar"', "Im Fehlerfall lautet die Ausgabe „nicht teilbar“.", scope="raw")],
         "Entscheidend ist, dass try und catch innerhalb der Schleife stehen: So betrifft ein Fehler nur "
         "die eine Runde, und die restlichen Zahlen werden noch gerechnet. Stünde das try außen herum, "
         "wäre nach der 0 Schluss.",
         expected="""
         20
         nicht teilbar
         25
         """,
         group="t10-5"),
]

# ---------------------------------------------------------------- Collections
COLLECTIONS = [
    mc("x-col-1a", "collections", 1, "Was ist der wichtigste Unterschied zwischen einem Array und einer ArrayList?",
       ["Die ArrayList kann wachsen und schrumpfen, das Array hat eine feste Größe",
        "Ein Array kann nur Zahlen speichern",
        "Die ArrayList ist immer automatisch sortiert",
        "Ein Array darf keine doppelten Werte enthalten"],
       "Ein Array legt seine Größe beim Anlegen fest und behält sie. Eine ArrayList kümmert sich selbst "
       "darum: Man fügt mit add hinzu, sie besorgt bei Bedarf mehr Platz.",
       why=[None,
            "Ein Array nimmt jede Sorte auf – int[], String[], auch eigene Klassen.",
            "Sortiert wird nichts von selbst. Eine ArrayList behält die Reihenfolge, in der man einfügt.",
            "Doppelte Werte sind in beiden erlaubt. Sie ausschließen würde ein Set."],
       group="t11-1"),
    out("x-col-2a", "collections", 2, "Was gibt das Programm aus?",
        """
        List<String> namen = new ArrayList<>();
        namen.add("Ada");
        namen.add("Linus");
        namen.add("Ada");
        System.out.println(namen.size());
        System.out.println(namen.get(1));
        System.out.println(namen.contains("Grace"));
        """,
        """
        3
        Linus
        false
        """,
        "Eine Liste erlaubt doppelte Einträge – „Ada“ steht zweimal darin, size zählt beide. get(1) holt "
        "das zweite Element, denn gezählt wird ab 0. contains fragt, ob ein Wert überhaupt vorkommt.",
        group="t11-3"),
    out("x-col-3a", "collections", 3, "Was gibt das Programm aus?",
        """
        Map<String, Integer> alter = new HashMap<>();
        alter.put("Ada", 36);
        alter.put("Linus", 54);
        alter.put("Ada", 37);
        System.out.println(alter.size());
        System.out.println(alter.get("Ada"));
        System.out.println(alter.get("Grace"));
        """,
        """
        2
        37
        null
        """,
        "In einer Map ist jeder Schlüssel nur einmal vergeben. Das zweite put zu „Ada“ legt deshalb keinen "
        "neuen Eintrag an, sondern überschreibt den alten Wert. Nach einem Schlüssel zu fragen, den es nicht "
        "gibt, ist kein Fehler – es kommt null zurück.",
        group="t11-4"),
    code("x-col-5a", "collections", 5,
         "Entferne aus der Liste alle Wörter mit weniger als vier Buchstaben und gib die Liste danach aus.",
         """
         List<String> woerter = new ArrayList<>(List.of("Hut", "Java", "ok", "Code"));
         // kurze Wörter entfernen und ausgeben
         """,
         """
         List<String> woerter = new ArrayList<>(List.of("Hut", "Java", "ok", "Code"));
         woerter.removeIf(w -> w.length() < 4);
         System.out.println(woerter);
         """,
         [req(r"removeIf|iterator|for\s*\(", "Zum Entfernen gibt es removeIf – oder eine Schleife mit Iterator."),
          req(r"length\s*\(\s*\)", "Entscheidend ist die Länge des jeweiligen Wortes."),
          req(r"<\s*4", "Weg sollen die Wörter mit weniger als vier Buchstaben."),
          req(r"System\.out\.println", "Am Ende wird die Liste ausgegeben.")],
         "removeIf geht die Liste durch und wirft alles hinaus, worauf die Bedingung zutrifft. Mit einer "
         "gewöhnlichen for-each-Schleife ginge das nicht: Wer aus einer Liste entfernt, während er sie "
         "durchläuft, bekommt eine ConcurrentModificationException.",
         expected="[Java, Code]",
         group="t11-3"),
    code("x-col-5b", "collections", 5,
         "Zähle mit einer HashMap, wie oft jeder Buchstabe in „banane“ vorkommt, und gib die Map aus.",
         """
         Map<Character, Integer> zaehler = new HashMap<>();
         // jeden Buchstaben zählen, danach die Map ausgeben
         """,
         """
         Map<Character, Integer> zaehler = new HashMap<>();
         for (char c : "banane".toCharArray()) {
             zaehler.put(c, zaehler.getOrDefault(c, 0) + 1);
         }
         System.out.println(zaehler);
         """,
         [req(r"for\s*\(", "Geh die Zeichen des Wortes einzeln durch."),
          req(r"toCharArray\s*\(\s*\)|charAt\s*\(", "An die einzelnen Zeichen kommst du mit toCharArray() oder charAt()."),
          req(r"getOrDefault|containsKey", "Beim ersten Vorkommen steht noch nichts in der Map – getOrDefault liefert dann 0."),
          req(r"\.put\s*\(", "Der neue Zählerstand muss zurück in die Map."),
          req(r"System\.out\.println", "Am Ende wird die Map ausgegeben.")],
         "getOrDefault(c, 0) beantwortet die heikle erste Runde: Für einen Buchstaben, der noch nicht in der "
         "Map steht, liefert es 0 statt null – damit lässt sich sofort rechnen. Die Reihenfolge in der Ausgabe "
         "bestimmt die HashMap selbst; sie ist nicht die Reihenfolge des Einfügens.",
         expected="{a=2, b=1, e=1, n=2}",
         group="t11-4"),
]

# ---------------------------------------------------------------- Generics
GENERICS = [
    mc("x-gen-1a", "generics", 1, "Wofür stehen die spitzen Klammern in List<String>?",
       ["Sie legen fest, welche Sorte von Dingen in der Liste liegen darf",
        "Sie geben an, wie viele Elemente hineinpassen",
        "Sie sind reine Schreibgewohnheit und dürfen weggelassen werden",
        "Sie bestimmen, wie die Liste sortiert wird"],
       "In den spitzen Klammern steht der Inhaltstyp. Dadurch weiß der Compiler schon beim Übersetzen, was "
       "herauskommt – man muss nichts umwandeln, und etwas Falsches hineinzulegen fällt sofort auf.",
       why=[None,
            "Eine Größe steht dort nie. Eine Liste wächst ohnehin nach Bedarf.",
            "Weglassen ginge zwar, führt aber zu Warnungen und verliert genau den Schutz, um den es geht.",
            "Über die Reihenfolge sagen die Klammern nichts. Sortiert wird mit sort oder einem TreeSet."],
       group="t11-2"),
    mc("x-gen-1b", "generics", 1, "Welche Schreibweise ergibt eine Liste für ganze Zahlen?",
       ["List<Integer>", "List<int>", "List<Int>", "List<zahl>"],
       "In den spitzen Klammern muss eine Klasse stehen. Für ganze Zahlen ist das Integer – die "
       "Objekt-Fassung von int. Java packt Zahlen beim Einfügen automatisch in diese Hülle.",
       why=[None,
            "int ist ein Grundtyp, keine Klasse. In spitzen Klammern sind nur Klassen erlaubt – deshalb Integer.",
            "Int mit dieser Schreibweise gibt es in Java nicht. Die Klasse heißt ausgeschrieben Integer.",
            "zahl ist kein Typ, sondern klingt nur wie einer. Typen beginnen in Java groß und müssen existieren."],
       group="t11-2"),
    out("x-gen-2a", "generics", 2, "Was gibt das Programm aus?",
        """
        List<Integer> zahlen = new ArrayList<>();
        zahlen.add(3);
        zahlen.add(7);
        int summe = zahlen.get(0) + zahlen.get(1);
        System.out.println(summe);
        System.out.println(zahlen);
        """,
        """
        10
        [3, 7]
        """,
        "Weil in den spitzen Klammern Integer steht, liefert get() sofort eine Zahl – man kann damit "
        "rechnen, ohne etwas umzuwandeln. Beim Ausgeben der ganzen Liste setzt Java eckige Klammern und "
        "Kommas selbst.",
        group="t11-2"),
    out("x-gen-3a", "generics", 3, "Was gibt das Programm aus?",
        """
        static <T> T erstes(List<T> liste) {
            return liste.get(0);
        }

        public static void main(String[] args) {
            System.out.println(erstes(List.of("a", "b")));
            System.out.println(erstes(List.of(10, 20)));
        }
        """,
        """
        a
        10
        """,
        "Dieselbe Methode arbeitet mit Texten und mit Zahlen. Das T ist ein Platzhalter, den erst der "
        "Aufruf festlegt: beim ersten Mal String, beim zweiten Mal Integer.",
        ctx="members",
        group="t11-5"),
    mc("x-gen-4a", "generics", 4, "Was bedeutet das T in static <T> T erstes(List<T> liste)?",
       ["Einen Platzhalter für einen Typ, den erst der Aufruf festlegt",
        "Den festen Typ für Text",
        "Eine Abkürzung für true",
        "Den Namen der Klasse, zu der die Methode gehört"],
       "T ist ein frei gewählter Name für „irgendein Typ“. Das erste <T> kündigt den Platzhalter an, danach "
       "darf er überall im Methodenkopf stehen. Beim Aufruf setzt Java den tatsächlichen Typ ein.",
       why=[None,
            "Für Text steht String. T ist absichtlich unbestimmt und passt zu jedem Typ.",
            "true und false gehören zu boolean und haben mit Platzhaltern nichts zu tun.",
            "Der Klassenname steht weiter oben in der Datei. T wird ausdrücklich in <…> eingeführt."],
       group="t11-5"),
    out("x-gen-4b", "generics", 4, "Was gibt das Programm aus?",
        """
        static <T> void zeige(List<T> liste) {
            System.out.println(liste.size() + ": " + liste);
        }

        public static void main(String[] args) {
            zeige(List.of("x", "y", "z"));
            zeige(List.of(1.5));
        }
        """,
        """
        3: [x, y, z]
        1: [1.5]
        """,
        "Was T ist, spielt hier gar keine Rolle – die Methode fragt nur nach der Größe und gibt die Liste "
        "aus. Genau das ist der Vorteil: Ein einziger Code funktioniert für jede Sorte von Liste.",
        ctx="members",
        group="t11-5"),
    code("x-gen-5a", "generics", 5,
         "Schreibe die generische Methode letzteZwei, die aus einer List<T> die letzten beiden Elemente als Liste zurückgibt.",
         """
         static <T> List<T> letzteZwei(List<T> liste) {
             // hier die letzten beiden zurückgeben
         }
         """,
         """
         static <T> List<T> letzteZwei(List<T> liste) {
             return liste.subList(liste.size() - 2, liste.size());
         }
         """,
         [req(r"<\s*T\s*>", "Der Platzhalter T muss vor dem Rückgabetyp angekündigt werden."),
          req(r"List\s*<\s*T\s*>", "Zurück kommt wieder eine Liste desselben Typs."),
          req(r"size\s*\(\s*\)\s*-\s*2", "Zwei vor dem Ende beginnt der Ausschnitt."),
          req(r"return", "Das Ergebnis muss zurückgegeben werden.")],
         "subList schneidet ein Stück heraus: ab der ersten Zahl bis vor die zweite. Dass die Methode mit "
         "List<T> arbeitet statt mit List<String>, macht sie für jede Sorte von Liste brauchbar – und der "
         "Aufrufer bekommt genau den Typ zurück, den er hineingegeben hat.",
         ctx="members",
         verify={"context": "members", "main": "System.out.println(letzteZwei(List.of(1, 2, 3, 4)));",
                 "output": "[3, 4]"},
         group="t11-5"),
    code("x-gen-5b", "generics", 5,
         "Lege eine Map an, die zu einem Text eine Liste von Texten speichert. Trage unter „Obst“ die Werte „Apfel“ und „Birne“ ein und gib die Map aus.",
         """
         // Map mit Listen als Werten anlegen, füllen und ausgeben
         """,
         """
         Map<String, List<String>> regale = new HashMap<>();
         regale.put("Obst", List.of("Apfel", "Birne"));
         System.out.println(regale);
         """,
         [req(r"Map\s*<\s*String\s*,\s*List\s*<\s*String\s*>\s*>", "Der Wert-Typ ist selbst wieder eine Liste: Map<String, List<String>>."),
          req(r"\.put\s*\(", "Eingetragen wird mit put."),
          req(r'"Obst"', "Der Schlüssel lautet „Obst“.", scope="raw"),
          req(r"System\.out\.println", "Am Ende wird die Map ausgegeben.")],
         "Platzhalter lassen sich schachteln: Der Wert einer Map darf selbst wieder ein Typ mit spitzen "
         "Klammern sein. So entsteht eine Zuordnung von einem Schlüssel auf mehrere Werte – ein sehr "
         "häufiges Muster, etwa für Kategorien und ihre Einträge.",
         expected="{Obst=[Apfel, Birne]}",
         group="t11-2"),
]

# ---------------------------------------------------------------- Modernes Java
MODERN = [
    mc("x-mod-1a", "modern", 1, "Was ist ein Record?",
       ["Eine kurze Schreibweise für eine Klasse, die vor allem Werte zusammenhält",
        "Eine Liste mit fester Länge",
        "Eine Methode, die ihren eigenen Aufruf aufzeichnet",
        "Ein besonderer Kommentar für die Dokumentation"],
       "Ein Record beschreibt in einer Zeile, welche Werte zusammengehören. Konstruktor, Lesemethoden, "
       "equals, hashCode und toString erzeugt Java daraus von selbst – man schreibt nur noch, was "
       "wirklich besonders ist.",
       why=[None,
            "Eine feste Länge hat ein Array. Ein Record ist ein eigener Typ mit benannten Feldern.",
            "Mit Aufzeichnen hat der Name nichts zu tun – gemeint ist „Datensatz“.",
            "Ein Record ist echter Code, kein Kommentar. Er erzeugt eine Klasse."],
       group="t13-1"),
    out("x-mod-2a", "modern", 2, "Was gibt das Programm aus?",
        """
        record Punkt(int x, int y) {}

        public class Main {
            public static void main(String[] args) {
                Punkt p = new Punkt(2, 5);
                System.out.println(p);
                System.out.println(p.x() + p.y());
            }
        }
        """,
        """
        Punkt[x=2, y=5]
        7
        """,
        "Die toString-Methode kommt vom Record selbst – deshalb erscheinen Name und Felder statt einer "
        "kryptischen Speicheradresse. Die Lesemethoden heißen wie die Felder, also x() und y(), nicht getX().",
        ctx="file",
        group="t13-2"),
    out("x-mod-3a", "modern", 3, "Was gibt das Programm aus?",
        """
        int note = 2;
        String text = switch (note) {
            case 1, 2 -> "gut";
            case 3, 4 -> "geht so";
            default -> "schlecht";
        };
        System.out.println(text);
        """,
        "gut",
        "Das ist ein switch als Ausdruck: Es liefert einen Wert, der direkt in die Variable text wandert. "
        "Deshalb steht am Ende ein Semikolon hinter der schließenden Klammer – anders als beim switch, "
        "das nur Anweisungen ausführt.",
        group="t13-3"),
    out("x-mod-4a", "modern", 4, "Welche Zahl wird ausgegeben?",
        """
        int monat = 4;
        int tage = switch (monat) {
            case 1, 3, 5, 7, 8, 10, 12 -> 31;
            case 2 -> 28;
            default -> 30;
        };
        System.out.println(tage);
        """,
        "30",
        "Der April steht in keinem der aufgezählten Fälle, also greift default. Ein switch-Ausdruck braucht "
        "immer einen Zweig für alle übrigen Fälle – sonst wüsste Java nicht, welchen Wert es liefern soll.",
        group="t13-4"),
    code("x-mod-5a", "modern", 5,
         "Schreibe die Methode laenge(Object o) mit Pattern Matching: Für einen String liefert sie dessen Länge, für alles andere -1.",
         """
         static int laenge(Object o) {
             // mit instanceof prüfen und passend zurückgeben
         }
         """,
         """
         static int laenge(Object o) {
             if (o instanceof String s) {
                 return s.length();
             }
             return -1;
         }
         """,
         [req(r"instanceof\s+String\s+\w+", "Mit instanceof String s prüfst du und bekommst in einem Zug die Variable s."),
          req(r"\.length\s*\(\s*\)", "Die Länge eines Textes liefert length()."),
          req(r"return\s+-\s*1", "In allen anderen Fällen kommt -1 zurück.")],
         "Früher musste man nach dem instanceof noch selbst umwandeln: ((String) o).length(). Mit Pattern "
         "Matching erledigt der Name hinter dem Typ beides – geprüft und umgewandelt in einem Schritt.",
         ctx="members",
         verify={"context": "members", "main": 'System.out.println(laenge("Hallo"));\nSystem.out.println(laenge(42));',
                 "output": "5\n-1"},
         group="t13-5"),
]

# ---------------------------------------------------------------- Enums & static
ENUMS = [
    mc("x-enum-1a", "enums", 1, "Was ist ein enum?",
       ["Ein Typ mit einer festen, benannten Liste von Möglichkeiten",
        "Eine Liste, die zur Laufzeit beliebig wachsen kann",
        "Ein anderes Wort für eine ganze Zahl",
        "Eine Methode ohne Rückgabewert"],
       "Ein enum zählt alle erlaubten Werte einmal auf – etwa ROT, GELB, GRUEN. Danach kann nichts anderes "
       "mehr hineingeraten: Ein Tippfehler fällt schon beim Übersetzen auf, anders als bei Text.",
       why=[None,
            "Gerade das Gegenteil macht ein enum aus: Die Liste steht fest und ändert sich zur Laufzeit nicht.",
            "Jeder Wert hat zwar eine Position, ist aber ein eigenständiges Objekt mit Namen – keine Zahl.",
            "Ohne Rückgabewert ist eine Methode mit void. Ein enum ist ein Typ, keine Methode."],
       group="t14-1"),
    out("x-enum-2a", "enums", 2, "Was gibt das Programm aus?",
        """
        enum Ampel { ROT, GELB, GRUEN }

        public class Main {
            public static void main(String[] args) {
                Ampel a = Ampel.GELB;
                System.out.println(a);
                System.out.println(a.ordinal());
                System.out.println(Ampel.values().length);
            }
        }
        """,
        """
        GELB
        1
        3
        """,
        "Ausgegeben wird der Name, wie er im enum steht. ordinal() ist die Position in der Aufzählung – "
        "gezählt ab 0, deshalb 1 für den zweiten Wert. values() liefert alle Werte als Array.",
        ctx="file",
        group="t14-2"),
    out("x-enum-3a", "enums", 3, "Was gibt das Programm aus?",
        """
        enum Ampel { ROT, GELB, GRUEN }

        public class Main {
            public static void main(String[] args) {
                Ampel a = Ampel.ROT;
                String tipp = switch (a) {
                    case ROT -> "stehen";
                    case GELB -> "achtung";
                    case GRUEN -> "fahren";
                };
                System.out.println(tipp);
            }
        }
        """,
        "stehen",
        "Im switch über ein enum darf der Vorname weg: case ROT statt case Ampel.ROT. Und weil alle drei "
        "Möglichkeiten abgedeckt sind, braucht es hier kein default – Java weiß, dass es keine vierte gibt.",
        ctx="file",
        group="t14-3"),
    out("x-enum-4a", "enums", 4, "Was gibt das Programm aus?",
        """
        enum Planet {
            ERDE(6371), MARS(3390);

            private final int radius;

            Planet(int radius) {
                this.radius = radius;
            }

            int getRadius() {
                return radius;
            }
        }

        public class Main {
            public static void main(String[] args) {
                for (Planet p : Planet.values()) {
                    System.out.println(p + ": " + p.getRadius());
                }
            }
        }
        """,
        """
        ERDE: 6371
        MARS: 3390
        """,
        "Ein enum kann mehr als nur Namen: Jeder Wert darf eigene Daten mitbringen. Die Zahlen in den "
        "Klammern hinter ERDE und MARS gehen an den Konstruktor des enums – der läuft einmal pro Wert, "
        "wenn die Klasse geladen wird.",
        ctx="file",
        group="t14-4"),
    code("x-enum-5a", "enums", 5,
         "Lege ein enum Richtung mit NORD, OST, SUED und WEST an und gib zu jedem Wert seine Position aus – also „NORD 0“ bis „WEST 3“.",
         """
         // enum Richtung und Klasse Main hier schreiben
         """,
         """
         enum Richtung { NORD, OST, SUED, WEST }

         public class Main {
             public static void main(String[] args) {
                 for (Richtung r : Richtung.values()) {
                     System.out.println(r + " " + r.ordinal());
                 }
             }
         }
         """,
         [req(r"enum\s+Richtung", "Es fehlt das enum Richtung."),
          req(r"NORD\s*,\s*OST\s*,\s*SUED\s*,\s*WEST", "Die vier Werte gehören in genau diese Reihenfolge."),
          req(r"values\s*\(\s*\)", "Alle Werte auf einmal liefert values()."),
          req(r"ordinal\s*\(\s*\)", "Die Position eines Wertes liefert ordinal().")],
         "values() gibt alle Werte in der Reihenfolge zurück, in der sie im enum stehen – damit lässt sich "
         "eine Aufzählung ohne Umwege durchlaufen. ordinal() liefert dazu die Position, wieder ab 0 gezählt.",
         ctx="file",
         expected="""
         NORD 0
         OST 1
         SUED 2
         WEST 3
         """,
         group="t14-5"),
    code("x-enum-5b", "enums", 5,
         "Ergänze im enum Wochentag die Methode istWochenende(), die für SAMSTAG und SONNTAG true liefert und sonst false.",
         """
         enum Wochentag {
             MONTAG, SAMSTAG, SONNTAG;

             // Methode istWochenende() hier ergänzen
         }
         """,
         """
         enum Wochentag {
             MONTAG, SAMSTAG, SONNTAG;

             boolean istWochenende() {
                 return this == SAMSTAG || this == SONNTAG;
             }
         }
         """,
         [req(r"boolean\s+istWochenende\s*\(\s*\)", "Die Methode heißt istWochenende() und liefert einen Wahrheitswert."),
          req(r"SAMSTAG", "SAMSTAG gehört zum Wochenende."),
          req(r"SONNTAG", "SONNTAG gehört zum Wochenende."),
          req(r"\|\||switch", "Zwei Werte sollen true ergeben – verknüpfe sie mit || oder nimm ein switch."),
          req(r"return", "Das Ergebnis muss zurückgegeben werden.")],
         "Ein enum darf eigene Methoden haben – das Semikolon hinter der Werteliste trennt sie ab. this "
         "meint den Wert, auf dem die Methode gerade aufgerufen wurde; verglichen wird mit ==, weil es "
         "jeden enum-Wert im ganzen Programm nur ein einziges Mal gibt.",
         ctx="file",
         verify={"context": "file",
                 "main": "System.out.println(Wochentag.MONTAG.istWochenende());\nSystem.out.println(Wochentag.SONNTAG.istWochenende());",
                 "output": "false\ntrue"},
         group="t14-5"),
]

# ---------------------------------------------------------------- equals, toString & abstrakt
OBJECTMETHODS = [
    mc("x-objm-1a", "objectmethods", 1, "Von welcher Klasse erbt in Java jede Klasse automatisch?",
       ["Object", "Main", "System", "Class"],
       "Object ist die Wurzel aller Klassen. Von dort stammen Methoden wie toString, equals und hashCode – "
       "deshalb kann man sie bei jedem Objekt aufrufen, auch ohne sie selbst geschrieben zu haben.",
       why=[None,
            "Main ist nur ein üblicher Name für die Startklasse. Eine besondere Bedeutung hat er beim Erben nicht.",
            "System ist die Klasse mit out, in und err. Geerbt wird von ihr nichts.",
            "Class beschreibt eine Klasse zur Laufzeit – das ist ein Werkzeug zur Selbstauskunft, nicht die Wurzel des Stammbaums."],
       group="t15-1"),
    mc("x-objm-2a", "objectmethods", 2, "Was gibt println bei einem Objekt aus, das keine eigene toString-Methode hat?",
       ["Den Klassennamen und eine kryptische Zahl, etwa Buch@1b6d3586",
        "Alle Felder mit ihren Werten",
        "Nur den Klassennamen",
        "Eine leere Zeile"],
       "Ohne eigene toString-Methode greift die von Object. Die kennt die Felder nicht und kann nur sagen, "
       "um welche Klasse es sich handelt und wo das Objekt ungefähr liegt – die Zahl ist der hashCode in "
       "Hexadezimalschreibweise.",
       why=[None,
            "Die Felder auszugeben würde Java nur tun, wenn man es selbst schreibt – oder bei einem Record, "
            "der genau das mitbringt.",
            "Der Klassenname allein wäre schon lesbar. Object hängt aber noch das Kürzel für das einzelne "
            "Objekt an.",
            "Leer bleibt die Zeile nie – irgendetwas gibt Object immer aus."],
       group="t15-1"),
    out("x-objm-3a", "objectmethods", 3, "Was gibt das Programm aus?",
        """
        record Farbe(String name) {}

        class Ton {
            String name = "hoch";
        }

        public class Main {
            public static void main(String[] args) {
                System.out.println(new Farbe("rot").equals(new Farbe("rot")));
                System.out.println(new Ton().equals(new Ton()));
            }
        }
        """,
        """
        true
        false
        """,
        "Der Record bringt eine equals-Methode mit, die die Felder vergleicht – gleicher Inhalt, also true. "
        "Die gewöhnliche Klasse hat keine eigene, also gilt die von Object: Die fragt nur, ob es dasselbe "
        "Objekt ist. Zwei getrennte new ergeben zwei Objekte, also false.",
        ctx="file",
        group="t15-3"),
    out("x-objm-4a", "objectmethods", 4, "Was gibt das Programm aus?",
        """
        abstract class Form {
            abstract double flaeche();

            @Override
            public String toString() {
                return getClass().getSimpleName() + ": " + flaeche();
            }
        }

        class Quadrat extends Form {
            double seite = 3;

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
        "Quadrat: 9.0",
        "Die abstrakte Klasse schreibt toString einmal für alle Kinder – und ruft darin flaeche() auf, "
        "obwohl sie selbst gar nicht weiß, wie man die berechnet. Zur Laufzeit läuft die Fassung des "
        "tatsächlichen Objekts, also die von Quadrat. Weil seite ein double ist, erscheint 9.0 statt 9.",
        ctx="file",
        group="t15-4"),
    code("x-objm-5a", "objectmethods", 5,
         "Ergänze in der Klasse Punkt eine equals-Methode, die zwei Punkte als gleich ansieht, wenn x und y übereinstimmen.",
         """
         class Punkt {
             int x = 1;
             int y = 2;

             // equals hier ergänzen
         }
         """,
         """
         class Punkt {
             int x = 1;
             int y = 2;

             @Override
             public boolean equals(Object o) {
                 if (!(o instanceof Punkt p)) {
                     return false;
                 }
                 return x == p.x && y == p.y;
             }
         }
         """,
         [req(r"public\s+boolean\s+equals\s*\(\s*Object", "equals muss genau diese Zutatenliste haben: (Object o)."),
          req(r"instanceof\s+Punkt", "Zuerst prüfen, ob das andere Objekt überhaupt ein Punkt ist."),
          req(r"x\s*==", "Verglichen werden die Felder x …"),
          req(r"y\s*==", "… und y."),
          req(r"return", "Das Ergebnis des Vergleichs muss zurückgegeben werden.")],
         "equals bekommt ein Object, denn es soll mit allem verglichen werden können. Deshalb steht am "
         "Anfang die Prüfung mit instanceof – sie schützt vor einem Absturz, wenn jemand einen Punkt mit "
         "einem Text vergleicht, und liefert in einem Zug die passend umgewandelte Variable p.",
         ctx="file",
         verify={"context": "file", "main": "System.out.println(new Punkt().equals(new Punkt()));",
                 "output": "true"},
         group="t15-5"),
    code("x-objm-5b", "objectmethods", 5,
         "Ergänze in der Klasse Temperatur eine toString-Methode, die „21.5 Grad“ liefert.",
         """
         class Temperatur {
             double wert = 21.5;

             // toString hier ergänzen
         }
         """,
         """
         class Temperatur {
             double wert = 21.5;

             @Override
             public String toString() {
                 return wert + " Grad";
             }
         }
         """,
         [req(r"public\s+String\s+toString\s*\(\s*\)", "Die Methode heißt toString(), ist public und liefert einen String."),
          req(r"return\s+wert|wert\s*\+", "Der Wert gehört in den Text."),
          req(r'" Grad"', "Hinter der Zahl steht ein Leerzeichen und das Wort „Grad“.", scope="raw")],
         "println fragt jedes Objekt nach seiner toString-Methode. Wer sie selbst schreibt, bestimmt damit, "
         "was beim Ausgeben erscheint – statt der unleserlichen Standardfassung von Object.",
         ctx="file",
         verify={"context": "file", "main": "System.out.println(new Temperatur());", "output": "21.5 Grad"},
         group="t15-5"),
]

POOL_LEVEL_B = OOP + INHERITANCE + EXCEPTIONS + COLLECTIONS + GENERICS + MODERN + ENUMS + OBJECTMETHODS
