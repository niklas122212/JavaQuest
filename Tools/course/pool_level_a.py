"""Übungspool, Teil 8a: mehr Aufgaben je Thema – Grundlagen.

Bisher hatten manche Themen zwar genug Aufgaben insgesamt, aber keine einzige auf
den oberen Stufen: Bei „Programmaufbau“ war nach Stufe 3 Schluss, bei „Strings“ fehlte
der leichte Einstieg. Wer ein Thema frei übt, bekam dadurch immer dasselbe Niveau.

Dieser Teil füllt die Lücken für Programmaufbau, Variablen, Operatoren, Bedingungen,
Schleifen, Methoden, Arrays und Strings: jedes dieser Themen hat danach mindestens
20 Aufgaben und auf jeder der fünf Stufen mindestens zwei.
"""
from authoring import code, fill, forbid, mc, out, req

# ---------------------------------------------------------------- Programmaufbau
SYNTAX = [
    fill("x-syn-2a", "syntax", 2, "Ergänze das Zeichen, das Text und Zahl zu einer Ausgabe verbindet.",
         """
         int punkte = 10;
         System.out.println("Punkte: " {{0}} punkte);
         """,
         [["+"]],
         "Das Pluszeichen hat bei Text eine zweite Bedeutung: Es rechnet nicht, sondern klebt aneinander. "
         "Sobald links ein Text steht, macht Java auch aus der Zahl rechts Text – heraus kommt „Punkte: 10“.",
         hint="Dasselbe Zeichen wie beim Addieren – nur dass hier ein Text davorsteht.",
         verify={"output": "Punkte: 10"},
         group="t01-3"),
    out("x-syn-3a", "syntax", 3, "Wie viele Zeilen erscheinen – und was steht darin?",
        """
        System.out.println("A");
        System.out.print("B");
        System.out.print("C");
        System.out.println();
        System.out.println("D");
        """,
        """
        A
        BC
        D
        """,
        "println beendet die Zeile, print nicht. B und C landen deshalb nebeneinander. "
        "Das leere println() ohne Text macht nichts anderes, als die angefangene Zeile abzuschließen.",
        group="t01-4"),
    mc("x-syn-3b", "syntax", 3, "Welche dieser Zeilen gibt nichts aus?",
       ['// System.out.println("Hallo");',
        'System.out.println("// Hallo");',
        'System.out.println("/* Hallo */");',
        'System.out.println("Hallo"); // Ausgabe'],
       "Zwei Schrägstriche machen den Rest der Zeile zum Kommentar: Java liest ihn, führt ihn aber nicht aus. "
       "Entscheidend ist, wo die Schrägstriche stehen – innerhalb von Anführungszeichen sind sie ganz normaler Text.",
       why=[None,
            "Hier stehen die Schrägstriche zwischen den Anführungszeichen. Damit sind sie Teil des Textes "
            "und werden mitausgegeben.",
            "Auch /* und */ sind hier nur Zeichen innerhalb des Textes. Ein Kommentar entsteht daraus nicht.",
            "Der Kommentar beginnt erst hinter dem Semikolon. Die Anweisung davor läuft ganz normal."],
       group="t01-2"),
    fill("x-syn-3c", "syntax", 3, "Ergänze den Namen der Methode, bei der Java das Programm startet.",
         """
         public class Main {
             public static void {{0}}(String[] args) {
                 System.out.println("laeuft");
             }
         }
         """,
         [["main"]],
         "Java sucht beim Start nach genau dieser Methode – Schreibweise und Klammerinhalt müssen stimmen. "
         "Ein anderer Name wäre eine ganz normale Methode, die niemand aufruft.",
         hint="Englisch für „Haupt-“.",
         ctx="file",
         verify={"context": "file", "output": "laeuft"},
         group="t01-1"),
    out("x-syn-4a", "syntax", 4, "Was gibt dieses Programm aus?",
        """
        System.out.println("Zeile 1\\nZeile 2");
        System.out.println("Er sagte \\"Hallo\\"");
        """,
        """
        Zeile 1
        Zeile 2
        Er sagte "Hallo"
        """,
        "Ein Backslash im Text leitet ein Sonderzeichen ein: \\n ist ein Zeilenumbruch mitten im Text, "
        "\\\" ist ein Anführungszeichen, das den Text nicht beendet. Beides steht im Quelltext als zwei "
        "Zeichen, wird aber als eines ausgegeben.",
        group="t01-4"),
    mc("x-syn-4b", "syntax", 4, "Warum muss die Methode main static sein?",
       ["Weil Java sie aufruft, bevor irgendein Objekt der Klasse existiert",
        "Weil statische Methoden schneller ausgeführt werden",
        "Weil main dadurch nachträglich nicht mehr verändert werden kann",
        "Weil nur statische Methoden etwas ausgeben dürfen"],
       "static heißt: Die Methode gehört der Klasse selbst, nicht einem einzelnen Objekt. Genau das braucht "
       "Java beim Start – zu diesem Zeitpunkt hat noch niemand mit new ein Objekt erzeugt, an dem man main "
       "aufrufen könnte.",
       why=[None,
            "Mit Geschwindigkeit hat static nichts zu tun. Es sagt nur, wem die Methode gehört: der Klasse "
            "statt einem einzelnen Objekt.",
            "Gegen Veränderung schützt final, nicht static.",
            "Ausgeben darf jede Methode. static regelt nur, ob man für den Aufruf ein Objekt braucht."],
       group="t01-1"),
    code("x-syn-5a", "syntax", 5,
         "Schreibe ein vollständiges Programm: die Klasse Main mit einer main-Methode, die zuerst „Start“ und danach „Ende“ ausgibt.",
         """
         // Hier die komplette Klasse Main mit ihrer main-Methode schreiben
         """,
         """
         public class Main {
             public static void main(String[] args) {
                 System.out.println("Start");
                 System.out.println("Ende");
             }
         }
         """,
         [req(r"class\s+Main", "Es fehlt die Klasse: class Main { … }"),
          req(r"static\s+void\s+main\s*\(\s*String\s*\[\s*\]", "Ohne die Methode main weiß Java nicht, wo es anfangen soll."),
          req(r'"Start"', "Gib zuerst „Start“ aus.", scope="raw"),
          req(r'"Ende"', "Gib danach „Ende“ aus.", scope="raw")],
         "Das ist das kleinste vollständige Java-Programm: eine Klasse als Hülle, darin main als Startpunkt, "
         "darin die Anweisungen in der Reihenfolge, in der sie laufen sollen.",
         expected="""
         Start
         Ende
         """,
         ctx="file",
         group="t01-5"),
    code("x-syn-5b", "syntax", 5,
         "Gib „A-B-C“ in einer einzigen Zeile aus – aber verteilt auf drei Ausgabe-Anweisungen.",
         """
         // drei Ausgaben, am Ende steht genau eine Zeile: A-B-C
         """,
         """
         System.out.print("A-");
         System.out.print("B-");
         System.out.println("C");
         """,
         [req(r"System\.out\.print\s*\(", "Die ersten beiden Ausgaben dürfen die Zeile nicht beenden – nimm print."),
          req(r"System\.out\.println\s*\(", "Die letzte Ausgabe schließt die Zeile ab – dafür ist println da."),
          req(r'"A-"', "Der erste Teil ist „A-“.", scope="raw"),
          req(r'"C"', "Der letzte Teil ist „C“.", scope="raw")],
         "print schreibt weiter in dieselbe Zeile, println schließt sie ab. Wer mehrere Teile nebeneinander "
         "braucht, nimmt print – und erst ganz am Ende einmal println.",
         expected="A-B-C",
         group="t01-4"),
]

# ---------------------------------------------------------------- Variablen
VARIABLES = [
    mc("x-var-4a", "variables", 4, "Welche Zuweisung lehnt der Compiler ab?",
       ["int x = 3.5;", "double y = 3;", "char c = 'A';", "long n = 3;"],
       "Von einer Kommazahl in eine int-Box geht es nicht von selbst: Dabei ginge die Nachkommastelle "
       "verloren, und Java verlangt, dass man diesen Verlust ausdrücklich erlaubt – mit (int) davor.",
       why=[None,
            "Umgekehrt ist es unproblematisch: Eine ganze Zahl passt immer in eine double-Box, Java macht 3.0 daraus.",
            "Einfache Anführungszeichen stehen für genau ein Zeichen – das ist der Inhalt, den char erwartet.",
            "long fasst noch größere Zahlen als int. Die 3 passt mühelos hinein."],
       group="t02-4"),
    code("x-var-5a", "variables", 5,
         "Lege drei Variablen an – name (Text), alter (ganze Zahl) und groesse (Kommazahl) – und gib daraus die Zeile „Ada, 36 Jahre, 1.7 m“ aus.",
         """
         // Variablen anlegen und die Zeile ausgeben
         """,
         """
         String name = "Ada";
         int alter = 36;
         double groesse = 1.7;
         System.out.println(name + ", " + alter + " Jahre, " + groesse + " m");
         """,
         [req(r"String\s+name\s*=", "Für Text ist String die passende Box."),
          req(r"int\s+alter\s*=", "Für eine ganze Zahl ist int die passende Box."),
          req(r"double\s+groesse\s*=", "Für eine Kommazahl ist double die passende Box."),
          req(r"System\.out\.println", "Am Ende soll die Zeile ausgegeben werden.")],
         "Jede Box bekommt genau den Typ, der zum Inhalt passt. Beim Ausgeben verbindet das Pluszeichen "
         "Text und Zahlen zu einer einzigen Zeile – die Zahlen werden dabei automatisch zu Text.",
         expected="Ada, 36 Jahre, 1.7 m",
         group="t02-5"),
]

# ---------------------------------------------------------------- Operatoren
OPERATORS = [
    out("x-op-2a", "operators", 2, "Was gibt dieses Programm aus?",
        """
        int a = 10;
        int b = 4;
        System.out.println(a / b);
        System.out.println(a % b);
        System.out.println((double) a / b);
        """,
        """
        2
        2
        2.5
        """,
        "Teilt man zwei ganze Zahlen, wirft Java die Nachkommastellen weg: 10 / 4 ergibt 2, der Rest 2 "
        "erscheint nur bei %. Erst wenn eine Seite eine Kommazahl ist – hier durch (double) – rechnet Java genau.",
        group="t03-2"),
    fill("x-op-3a", "operators", 3, "Verdopple punkte mit dem kurzen Operator.",
         """
         int punkte = 7;
         punkte {{0}} 2;
         System.out.println(punkte);
         """,
         [["*="]],
         "punkte *= 2 ist die Kurzform von punkte = punkte * 2: Java nimmt den alten Wert, rechnet und "
         "legt das Ergebnis in dieselbe Box zurück.",
         hint="Wie += beim Addieren – nur mit dem Zeichen fürs Malnehmen.",
         verify={"output": "14"},
         group="t03-3"),
    mc("x-op-3b", "operators", 3, "Was gibt die letzte Zeile aus?",
       ["true", "false", "Der Ausdruck lässt sich nicht übersetzen", "Das hängt davon ab, welcher Teil zuerst geprüft wird"],
       "&& bindet stärker als || – genau wie Malnehmen stärker bindet als Addieren. Java rechnet also "
       "(a && b) || c, das ist false || true und damit true.",
       code="""
       boolean a = false;
       boolean b = false;
       boolean c = true;
       System.out.println(a && b || c);
       """,
       why=[None,
            "false käme heraus, wenn Java zuerst b || c zusammenfasst. Das tut es nicht: && ist zuerst dran.",
            "Der Ausdruck ist gültig – && und || dürfen ohne Klammern in einem Ausdruck stehen.",
            "Offen ist das nicht: Java legt die Reihenfolge fest, && kommt vor ||. Klammern machen es nur lesbarer."],
       group="t03-1"),
    code("x-op-5a", "operators", 5,
         "Rechne 125 Sekunden in Minuten und Sekunden um und gib „2 min 5 s“ aus.",
         """
         int gesamt = 125;
         // Minuten und Sekunden berechnen und ausgeben
         """,
         """
         int gesamt = 125;
         int minuten = gesamt / 60;
         int sekunden = gesamt % 60;
         System.out.println(minuten + " min " + sekunden + " s");
         """,
         [req(r"/\s*60", "Wie oft passen 60 Sekunden hinein? Das ist die Ganzzahldivision."),
          req(r"%\s*60", "Was bleibt übrig? Danach fragt der Rest-Operator %."),
          req(r'" min "', "Zwischen Zahl und Einheit gehört ein Leerzeichen.", scope="raw"),
          req(r"System\.out\.println", "Gib das Ergebnis aus.")],
         "Ganzzahldivision und Rest sind ein Paar: / liefert, wie oft es hineinpasst, % liefert, was übrig "
         "bleibt. Zusammen zerlegen sie jede Zahl in größere und kleinere Einheiten.",
         expected="2 min 5 s",
         group="t03-5"),
]

# ---------------------------------------------------------------- Bedingungen
CONDITIONALS = [
    mc("x-cond-1a", "conditionals", 1, "Mit welchem Operator prüfst du, ob zwei Zahlen gleich sind?",
       ["==", "=", "equals", "==="],
       "Zwei Gleichheitszeichen stellen eine Frage: „Sind die beiden gleich?“ Heraus kommt true oder false – "
       "genau das, was if braucht.",
       why=[None,
            "Ein einzelnes Gleichheitszeichen fragt nichts, es legt einen Wert in eine Box. Zum Vergleichen "
            "braucht es zwei.",
            "equals vergleicht den Inhalt von Objekten, etwa von Texten. Bei Zahlen wie int nimmt man ==.",
            "Drei Gleichheitszeichen gibt es in Java nicht – die stammen aus JavaScript."],
       group="t04-1"),
    mc("x-cond-1b", "conditionals", 1, "Was passiert, wenn die Bedingung eines if false ist und kein else dahintersteht?",
       ["Der Block wird übersprungen, danach läuft das Programm normal weiter",
        "Das Programm bricht mit einem Fehler ab",
        "Der Block läuft trotzdem genau einmal",
        "Java wartet auf eine Eingabe"],
       "Ein if ohne else ist eine Abzweigung, die man einfach nicht nimmt: Der Block in den geschweiften "
       "Klammern wird übergangen, die nächste Anweisung darunter läuft ganz normal.",
       why=[None,
            "Eine nicht erfüllte Bedingung ist kein Fehler, sondern der Normalfall – genau dafür ist if da.",
            "Das wäre bei do-while so, das den Block immer einmal ausführt. Ein if prüft vorher.",
            "Auf Eingaben wartet nur ein Scanner. if prüft nur, was schon da ist."],
       group="t04-1"),
    out("x-cond-2a", "conditionals", 2, "Was wird ausgegeben?",
        """
        int alter = 17;
        if (alter >= 18) {
            System.out.println("volljaehrig");
        } else {
            System.out.println("minderjaehrig");
        }
        System.out.println("fertig");
        """,
        """
        minderjaehrig
        fertig
        """,
        "17 >= 18 ist false, also läuft der else-Zweig. Genau einer der beiden Blöcke kommt dran – und die "
        "Zeile darunter läuft danach in jedem Fall, sie gehört zu keinem der beiden Zweige.",
        group="t04-2"),
    fill("x-cond-3a", "conditionals", 3, "Ergänze die Verknüpfung: Der Wert soll zwischen 1 und 10 liegen, beide eingeschlossen.",
         """
         int wert = 7;
         if (wert >= 1 {{0}} wert <= 10) {
             System.out.println("im Bereich");
         }
         """,
         [["&&"]],
         "&& heißt „und“: Nur wenn beide Teilfragen mit true antworten, ist die ganze Bedingung wahr. "
         "Mit || („oder“) wäre fast jede Zahl im Bereich, weil schon eine erfüllte Hälfte genügen würde.",
         hint="Gesucht ist „und“ – beide Bedingungen müssen gleichzeitig stimmen.",
         verify={"output": "im Bereich"},
         group="t04-3"),
    out("x-cond-3b", "conditionals", 3, "Welche Note wird ausgegeben?",
        """
        int punkte = 75;
        String note;
        if (punkte >= 90) {
            note = "sehr gut";
        } else if (punkte >= 75) {
            note = "gut";
        } else if (punkte >= 50) {
            note = "bestanden";
        } else {
            note = "nicht bestanden";
        }
        System.out.println(note);
        """,
        "gut",
        "Java geht die Kette von oben nach unten durch und steigt bei der ersten wahren Bedingung aus. "
        "75 >= 90 ist false, 75 >= 75 ist true – ab da wird nichts mehr geprüft, obwohl 75 >= 50 auch stimmen würde.",
        group="t04-4"),
    code("x-cond-5a", "conditionals", 5,
         "Schreibe ein switch mit Pfeil-Syntax: Für tag 6 und 7 soll „Wochenende“ ausgegeben werden, in allen anderen Fällen „Arbeitstag“.",
         """
         int tag = 6;
         // switch hier ergänzen
         """,
         """
         int tag = 6;
         switch (tag) {
             case 6, 7 -> System.out.println("Wochenende");
             default -> System.out.println("Arbeitstag");
         }
         """,
         [req(r"switch\s*\(\s*tag\s*\)", "Das switch prüft die Variable tag."),
          req(r"->", "Gefragt ist die Pfeil-Schreibweise, nicht die alte mit Doppelpunkt und break."),
          req(r"case\s+6\s*,\s*7", "Zwei Werte dürfen sich einen Zweig teilen: case 6, 7 ->"),
          req(r"default", "Alle übrigen Tage fängt der default-Zweig ab."),
          req(r'"Wochenende"', "Für 6 und 7 lautet die Ausgabe „Wochenende“.", scope="raw")],
         "Die Pfeil-Schreibweise braucht kein break: Es läuft genau ein Zweig, danach ist das switch zu Ende. "
         "Mehrere Werte in einem Zweig schreibt man mit Komma getrennt.",
         expected="Wochenende",
         group="t04-5"),
]

# ---------------------------------------------------------------- Schleifen
LOOPS = [
    code("x-loop-5a", "loops", 5,
         "Gib mit einer Schleife die Reihe der 7 aus – fünf Zeilen von „7 x 1 = 7“ bis „7 x 5 = 35“.",
         """
         // Schleife hier
         """,
         """
         for (int i = 1; i <= 5; i++) {
             System.out.println("7 x " + i + " = " + (7 * i));
         }
         """,
         [req(r"for\s*\(|while\s*\(", "Schreibe die Zeilen nicht einzeln hin – nimm eine Schleife."),
          req(r"7\s*\*\s*i|i\s*\*\s*7", "Das Ergebnis rechnest du in der Schleife aus: 7 mal den Zähler."),
          req(r"\s+x\s+", "Zwischen den Zahlen steht ein x mit Leerzeichen drumherum.", scope="raw"),
          req(r"System\.out\.println", "Jede Zeile wird einzeln ausgegeben.")],
         "Der Zähler i ist beides zugleich: die Nummer der Runde und ein Wert, mit dem gerechnet wird. "
         "Die Klammern um (7 * i) sind wichtig – sonst würde Java die 7 an den Text kleben, statt zu rechnen.",
         expected="""
         7 x 1 = 7
         7 x 2 = 14
         7 x 3 = 21
         7 x 4 = 28
         7 x 5 = 35
         """,
         group="t05-5"),
]

# ---------------------------------------------------------------- Methoden
METHODS = [
    mc("x-meth-1a", "methods", 1, "Was steht in den runden Klammern eines Methodenkopfes?",
       ["Die Zutaten, die die Methode zum Arbeiten braucht – die Parameter",
        "Der Wert, den die Methode später zurückgibt",
        "Der Name der Klasse, zu der die Methode gehört",
        "Die Anweisungen, die die Methode ausführt"],
       "In den runden Klammern steht die Zutatenliste: für jede Zutat ein Typ und ein Name, etwa "
       "(String name, int alter). Beim Aufruf muss man genau dazu passende Werte mitgeben.",
       why=[None,
            "Was zurückkommt, steht vor dem Namen – zum Beispiel int oder String, oder void für „nichts“.",
            "Die Klasse steht weiter oben in der Datei. Im Methodenkopf taucht ihr Name nicht auf.",
            "Die Anweisungen stehen in den geschweiften Klammern darunter, nicht in den runden."],
       group="t06-1"),
    mc("x-meth-1b", "methods", 1, "Womit gibt eine Methode ihr Ergebnis an die aufrufende Stelle zurück?",
       ["return", "print", "void", "break"],
       "return beendet die Methode und reicht den Wert dorthin zurück, wo die Methode aufgerufen wurde. "
       "Dort kann man ihn weiterverwenden – in eine Variable legen, damit rechnen oder ihn ausgeben.",
       why=[None,
            "println schreibt etwas auf den Bildschirm. Zur aufrufenden Stelle gelangt der Wert dadurch nicht – "
            "man kann mit ihm anschließend nicht weiterrechnen.",
            "void ist das Gegenteil: Es sagt ausdrücklich, dass gar kein Ergebnis zurückkommt.",
            "break verlässt eine Schleife oder ein switch. Einen Wert liefert es nicht."],
       group="t06-1"),
    out("x-meth-2a", "methods", 2, "Was gibt main aus?",
        """
        static int verdopple(int n) {
            return n * 2;
        }

        public static void main(String[] args) {
            System.out.println(verdopple(5));
            System.out.println(verdopple(verdopple(3)));
        }
        """,
        """
        10
        12
        """,
        "Weil verdopple einen Wert zurückgibt, darf man ihn sofort weiterverwenden – auch als Zutat für "
        "denselben Aufruf. Java rechnet von innen nach außen: erst verdopple(3) zu 6, dann verdopple(6) zu 12.",
        ctx="members",
        group="t06-2"),
    out("x-meth-2b", "methods", 2, "Welchen Wert hat wert am Ende?",
        """
        static void aendere(int zahl) {
            zahl = 99;
        }

        public static void main(String[] args) {
            int wert = 5;
            aendere(wert);
            System.out.println(wert);
        }
        """,
        "5",
        "Beim Aufruf bekommt die Methode eine Kopie des Wertes, keine Verbindung zur Box draußen. "
        "zahl = 99 füllt also nur die Kopie innerhalb der Methode – wert bleibt unangetastet.",
        ctx="members",
        group="t06-2"),
    code("x-meth-5a", "methods", 5,
         "Schreibe die Methode begruessung(String name), die den Text „Hallo, Ada!“ zurückgibt – zurückgeben, nicht ausgeben.",
         """
         static String begruessung(String name) {
             // hier den Text zusammenbauen und zurückgeben
         }
         """,
         """
         static String begruessung(String name) {
             return "Hallo, " + name + "!";
         }
         """,
         [req(r"return\s+", "Das Ergebnis muss mit return zurückgehen."),
          req(r'"Hallo, "', "Der Text beginnt mit „Hallo, “ – Komma und Leerzeichen inklusive.", scope="raw"),
          req(r"\+\s*name", "Der übergebene Name gehört in die Mitte."),
          req(r'"!"', "Am Ende steht ein Ausrufezeichen.", scope="raw"),
          forbid(r"System\.out\.print", "Die Methode soll den Text zurückgeben. Ausgegeben wird er an der aufrufenden Stelle.")],
         "Eine Methode, die zurückgibt statt auszugeben, ist vielseitiger: Der Aufrufer entscheidet, ob der "
         "Text auf dem Bildschirm landet, in einer Datei oder in einer weiteren Rechnung.",
         ctx="members",
         verify={"context": "members", "main": 'System.out.println(begruessung("Ada"));', "output": "Hallo, Ada!"},
         group="t06-5"),
]

# ---------------------------------------------------------------- Arrays
ARRAYS = [
    mc("x-arr-1a", "arrays", 1, "Wie fragst du ab, wie viele Fächer das Array zahlen hat?",
       ["zahlen.length", "zahlen.length()", "zahlen.size()", "length(zahlen)"],
       "Bei einem Array ist length ein Feld, keine Methode – deshalb ohne Klammern. Es steht fest, sobald "
       "das Array angelegt ist, denn ein Array kann später nicht wachsen.",
       why=[None,
            "Die runden Klammern gehören zu Methoden. Bei einem Array ist length ein schlichtes Feld.",
            "size() kennen Listen wie ArrayList, die wachsen können. Ein Array hat stattdessen length.",
            "So schreibt man es in manchen anderen Sprachen. In Java steht length hinter dem Punkt."],
       group="t07-1"),
    out("x-arr-2a", "arrays", 2, "Was gibt dieses Programm aus?",
        """
        int[] zahlen = {4, 8, 15};
        System.out.println(zahlen.length);
        System.out.println(zahlen[0]);
        System.out.println(zahlen[zahlen.length - 1]);
        """,
        """
        3
        4
        15
        """,
        "Drei Fächer, nummeriert von 0 bis 2. Deshalb ist das letzte Fach immer length - 1: "
        "zahlen[3] gäbe es nicht mehr und würde das Programm abbrechen.",
        group="t07-1"),
    out("x-arr-2b", "arrays", 2, "Was erscheint in der Zeile?",
        """
        String[] farben = {"rot", "gruen", "blau"};
        for (String f : farben) {
            System.out.print(f.charAt(0));
        }
        System.out.println();
        """,
        "rgb",
        "Die for-each-Schleife holt nacheinander jeden Wert aus dem Array – ohne Zähler und ohne Indexe. "
        "charAt(0) nimmt davon jeweils das erste Zeichen, print hängt sie in derselben Zeile aneinander.",
        group="t07-3"),
    fill("x-arr-3a", "arrays", 3, "Ergänze die Bedingung, damit die Schleife das Array rückwärts ausgibt.",
         """
         int[] zahlen = {1, 2, 3};
         for (int i = zahlen.length - 1; i {{0}} 0; i--) {
             System.out.print(zahlen[i]);
         }
         System.out.println();
         """,
         [[">=", "> -1"]],
         "Rückwärts beginnt man beim letzten Fach (length - 1) und zählt herunter. Fach 0 soll noch "
         "drankommen, deshalb >= statt >: Mit > würde die 1 fehlen.",
         hint="Fach 0 ist das letzte, das noch ausgegeben werden soll.",
         verify={"output": "321"},
         group="t07-3"),
    out("x-arr-3b", "arrays", 3, "Was steht in den Fächern, bevor jemand etwas hineinlegt?",
        """
        int[] zahlen = new int[3];
        String[] namen = new String[2];
        System.out.println(zahlen[0]);
        System.out.println(namen[0]);
        """,
        """
        0
        null
        """,
        "Ein mit new angelegtes Array ist nie undefiniert: Zahlenfächer starten bei 0, boolean-Fächer bei "
        "false, und Fächer für Objekte – auch für Text – enthalten null, also „noch nichts hinterlegt“.",
        group="t07-1"),
    code("x-arr-5a", "arrays", 5,
         "Zähle, wie viele Zahlen im Array größer als 10 sind, und gib die Anzahl aus.",
         """
         int[] zahlen = {4, 12, 7, 20, 10};
         // zählen und ausgeben
         """,
         """
         int[] zahlen = {4, 12, 7, 20, 10};
         int anzahl = 0;
         for (int z : zahlen) {
             if (z > 10) {
                 anzahl++;
             }
         }
         System.out.println(anzahl);
         """,
         [req(r"for\s*\(", "Geh mit einer Schleife durch das Array."),
          req(r">\s*10", "Gezählt wird, was echt größer als 10 ist – die 10 selbst also nicht."),
          req(r"\+\+|\+=\s*1", "Erhöhe den Zähler bei jedem Treffer."),
          req(r"System\.out\.println", "Am Ende wird die Anzahl ausgegeben.")],
         "Ein Zähler, der vor der Schleife auf 0 steht und drinnen nur bei Treffern wächst, ist das Grundmuster "
         "für jedes „wie viele …“. Wichtig: Der Zähler muss außerhalb stehen, sonst beginnt er in jeder Runde neu.",
         expected="2",
         group="t07-5"),
]

# ---------------------------------------------------------------- Strings
STRINGS = [
    mc("x-str-1a", "strings", 1, "Wie fragst du die Länge eines Textes ab?",
       ["text.length()", "text.length", "text.size()", "length(text)"],
       "Ein String ist ein Objekt und length() eine seiner Methoden – deshalb mit runden Klammern. "
       "Zurück kommt die Anzahl der Zeichen, Leerzeichen mitgezählt.",
       why=[None,
            "Ohne Klammern ist length das Längenfeld eines Arrays. Ein String hat stattdessen die Methode length().",
            "size() gehört zu Listen wie ArrayList. Ein Text kennt diese Methode nicht.",
            "So schreibt man es in manchen anderen Sprachen. In Java steht die Methode hinter dem Punkt."],
       group="t07-2"),
    mc("x-str-1b", "strings", 1, "Womit prüfst du, ob zwei Texte denselben Inhalt haben?",
       ["a.equals(b)", "a == b", "a.compare(b)", "a = b"],
       "equals schaut Zeichen für Zeichen nach, ob derselbe Inhalt darinsteht. Das ist bei Text fast immer "
       "das, was man wissen will.",
       why=[None,
            "== fragt, ob es dasselbe Objekt im Speicher ist. Zwei Texte mit gleichem Inhalt können trotzdem "
            "zwei verschiedene Objekte sein – dann kommt false heraus.",
            "compare gibt es so bei String nicht. Zum Sortieren gäbe es compareTo, zum Vergleichen equals.",
            "Ein einzelnes Gleichheitszeichen vergleicht nichts – es überschreibt a mit b."],
       group="t07-2"),
    out("x-str-3a", "strings", 3, "Was gibt dieses Programm aus?",
        """
        String text = "JavaQuest";
        System.out.println(text.substring(0, 4));
        System.out.println(text.indexOf("Q"));
        System.out.println(text.toUpperCase());
        """,
        """
        Java
        4
        JAVAQUEST
        """,
        "substring(0, 4) nimmt die Zeichen ab Position 0 bis vor Position 4 – das Ende ist ausgeschlossen. "
        "indexOf sagt, an welcher Position ein Zeichen zum ersten Mal steht; gezählt wird auch hier ab 0.",
        group="t07-2"),
    out("x-str-3b", "strings", 3, "Was erscheint auf dem Bildschirm?",
        """
        String satz = "  Hallo Welt  ";
        System.out.println("[" + satz.trim() + "]");
        System.out.println(satz.trim().replace("Welt", "Java"));
        System.out.println(satz.isBlank());
        """,
        """
        [Hallo Welt]
        Hallo Java
        false
        """,
        "trim schneidet Leerzeichen am Anfang und Ende weg – die eckigen Klammern machen sichtbar, dass "
        "wirklich nichts mehr übrig ist. isBlank fragt, ob der Text nur aus Leerraum besteht; hier stehen "
        "Buchstaben darin, also false.",
        group="t07-4"),
    out("x-str-4a", "strings", 4, "Was gibt dieses Programm aus?",
        """
        String liste = "rot,gruen,blau";
        String[] teile = liste.split(",");
        System.out.println(teile.length);
        System.out.println(teile[1]);
        System.out.println(String.join(" | ", teile));
        """,
        """
        3
        gruen
        rot | gruen | blau
        """,
        "split zerlegt den Text an jedem Komma und legt die Stücke in ein Array – das Trennzeichen selbst "
        "verschwindet. String.join ist der Rückweg: Es fügt die Stücke wieder zusammen, diesmal mit einem "
        "anderen Trenner dazwischen.",
        group="t07-4"),
    code("x-str-5a", "strings", 5,
         "Prüfe, ob „Level“ vorwärts und rückwärts gleich geschrieben wird – Groß- und Kleinschreibung soll dabei egal sein. Gib true oder false aus.",
         """
         String wort = "Level";
         // umdrehen, vergleichen, ausgeben
         """,
         """
         String wort = "Level";
         String klein = wort.toLowerCase();
         String rueckwaerts = new StringBuilder(klein).reverse().toString();
         System.out.println(klein.equals(rueckwaerts));
         """,
         [req(r"toLowerCase\s*\(\s*\)", "Damit die Schreibweise egal ist, bring den Text zuerst komplett in Kleinbuchstaben."),
          req(r"reverse\s*\(\s*\)", "Zum Umdrehen hat der StringBuilder die Methode reverse()."),
          req(r"\.equals\s*\(", "Vergleiche die beiden Texte mit equals, nicht mit ==."),
          req(r"System\.out\.println", "Gib das Ergebnis des Vergleichs aus.")],
         "Ein String lässt sich nicht verändern, deshalb geht das Umdrehen den Umweg über einen StringBuilder: "
         "hineingeben, reverse(), mit toString() wieder einen Text herausholen. Das Kleinschreiben vorher sorgt "
         "dafür, dass „Level“ und „levaL“ nicht an einem großen L scheitern.",
         expected="true",
         group="t07-4"),
    code("x-str-5b", "strings", 5,
         "Gib „programmieren“ mit großem Anfangsbuchstaben aus – also „Programmieren“.",
         """
         String wort = "programmieren";
         // ersten Buchstaben groß, Rest unverändert
         """,
         """
         String wort = "programmieren";
         String gross = wort.substring(0, 1).toUpperCase() + wort.substring(1);
         System.out.println(gross);
         """,
         [req(r"substring\s*\(\s*0\s*,\s*1\s*\)", "Den ersten Buchstaben holst du mit substring(0, 1)."),
          req(r"toUpperCase\s*\(\s*\)", "Diesen einen Buchstaben machst du mit toUpperCase() groß."),
          req(r"substring\s*\(\s*1\s*\)", "Der Rest ab Position 1 bleibt, wie er ist: substring(1)."),
          req(r"System\.out\.println", "Gib das Ergebnis aus.")],
         "substring mit einer Zahl nimmt alles ab dieser Position bis zum Ende, mit zwei Zahlen ein Stück "
         "dazwischen. Beide Teile werden mit + wieder zusammengesetzt – der ursprüngliche Text bleibt dabei unberührt.",
         expected="Programmieren",
         group="t07-2"),
]

POOL_LEVEL_A = SYNTAX + VARIABLES + OPERATORS + CONDITIONALS + LOOPS + METHODS + ARRAYS + STRINGS
