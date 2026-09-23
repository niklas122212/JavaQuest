"""Übungspool, Teil 10: eine dritte Variante für jedes verbliebene Lernziel.

38 Lernziele hatten genau zwei Varianten. Nach einem Fehler kam damit zwar eine andere
Aufgabe – beim zweiten Fehler aber wieder die erste. Mit einer dritten Variante
wiederholt sich auch im dritten Anlauf nichts.

Der Aufgabentyp ist dabei bewusst gewählt: Er ist ein anderer als der, den das Lernziel
schon hat, und in Themen mit vielen „Was gibt das aus?“-Aufgaben wird dieser Typ
gemieden. So wächst mit der Tiefe auch die Abwechslung.
"""
from authoring import any_of, code, fill, forbid, mc, out, req
from uml_content import DRUCKER, FORM_HIERARCHIE, INTERFACE_DIAGRAM, KONTO, TIER_HUND

# ---------------------------------------------------------------- Grundlagen und Texte
BASIS = [
    fill("z-loop-2", "loops", 2, "Ergänze die Schleife, damit 2, 4, 6 untereinander erscheinen.",
         """
         for (int i = 2; i <= 6; i {{0}} 2) {
             System.out.println(i);
         }
         """,
         [["+=", "= i +"]],
         "Der dritte Teil im Schleifenkopf bestimmt die Schrittweite – sie muss nicht 1 sein. Mit i++ "
         "kämen auch 3 und 5 heraus; += 2 überspringt sie. Fehlt der Schritt ganz, ändert sich i nie "
         "und die Schleife läuft endlos.",
         hint="Die Kurzform, die den Zähler um einen Betrag erhöht.",
         verify={"output": "2\n4\n6"},
         group="t05-2"),
    code("z-meth-4", "methods", 4,
         "Schreibe zwei Methoden namens flaeche: eine für ein Quadrat (eine Seite), eine für ein Rechteck (zwei Seiten).",
         """
         // zwei Methoden flaeche – einmal mit einer, einmal mit zwei Zahlen
         """,
         """
         static int flaeche(int seite) {
             return seite * seite;
         }

         static int flaeche(int a, int b) {
             return a * b;
         }
         """,
         [req(r"flaeche\s*\(\s*int\s+\w+\s*\)", "Eine Fassung nimmt genau eine Zahl entgegen."),
          req(r"flaeche\s*\(\s*int\s+\w+\s*,\s*int\s+\w+\s*\)", "Die andere nimmt zwei Zahlen entgegen."),
          req(r"return", "Beide Fassungen geben ihr Ergebnis zurück.")],
         "Zwei Methoden dürfen denselben Namen tragen, solange sich ihre Zutatenliste unterscheidet – "
         "das heißt Überladung. Java sucht beim Aufruf die Fassung, deren Parameter passen. Am "
         "Rückgabetyp allein könnte es sie nicht auseinanderhalten.",
         ctx="members",
         verify={"context": "members", "main": "System.out.println(flaeche(3) + \" \" + flaeche(2, 5));",
                 "output": "9 10"},
         group="t06-4"),
    code("z-io-4", "io", 4,
         "Lies mit dem Scanner Vor- und Nachnamen und baue daraus mit einem StringBuilder „Lovelace, Ada“.",
         """
         Scanner scanner = new Scanner("Ada Lovelace");
         // Namen lesen und zusammensetzen
         """,
         """
         Scanner scanner = new Scanner("Ada Lovelace");
         String vorname = scanner.next();
         String nachname = scanner.next();
         StringBuilder sb = new StringBuilder();
         sb.append(nachname).append(", ").append(vorname);
         System.out.println(sb);
         """,
         [req(r"\.next\s*\(\s*\)", "Einzelne Wörter liest der Scanner mit next()."),
          req(r"new\s+StringBuilder", "Zusammengesetzt wird auf einem StringBuilder."),
          req(r"\.append\s*\(", "Angehängt wird mit append."),
          req(r'", "', "Zwischen Nachname und Vorname stehen Komma und Leerzeichen.", scope="raw")],
         "Der Scanner merkt sich, wie weit er gekommen ist: Der zweite next()-Aufruf setzt dort fort, wo "
         "der erste aufhörte. append liefert den Bauplatz selbst zurück, deshalb lassen sich die Aufrufe "
         "aneinanderhängen.",
         expected="Lovelace, Ada",
         group="t16-4"),
    mc("z-io-4b", "io", 4, "Warum schreibt man eine Datei am besten mit try-with-resources?",
       ["Weil die Datei dann auch bei einem Fehler zuverlässig geschlossen wird",
        "Weil der Text dadurch schneller geschrieben wird",
        "Weil Java sonst keine Dateien anlegen kann",
        "Weil der Inhalt dadurch automatisch gesichert wird"],
       "try-with-resources schließt am Ende des Blocks automatisch – auch dann, wenn zwischendurch eine "
       "Exception fliegt. Von Hand vergisst man das leicht, und eine offene Datei kann bedeuten, dass "
       "die letzten Zeilen nie auf der Festplatte landen.",
       why=[None,
            "Auf die Geschwindigkeit hat es keinen Einfluss – es geht ums verlässliche Aufräumen.",
            "Anlegen kann Java auch ohne. Die Frage ist nur, ob hinterher sauber geschlossen wird.",
            "Gesichert wird nichts. Geschlossen wird die Datei, mehr nicht."],
       group="t17-4"),
]

# ---------------------------------------------------------------- Nebenläufigkeit
NEBENLAEUFIG = [
    out("z-con-23-2", "concurrency", 2, "Was gibt das Programm aus?",
        """
        Thread a = new Thread(() -> System.out.println("A"));
        a.start();
        a.join();
        System.out.println("B");
        """,
        """
        A
        B
        """,
        "Mit join ist die Reihenfolge festgelegt: Das Hauptprogramm wartet, bis der Thread fertig ist. "
        "Ohne join wäre offen, was zuerst erscheint – dann entscheidet das Betriebssystem, und das "
        "Ergebnis kann bei jedem Lauf anders ausfallen.",
        group="t23-2"),
    fill("z-con-23-3", "concurrency", 3, "Ergänze beide Schritte: loslaufen lassen und abwarten.",
         """
         Thread laeufer = new Thread(() -> System.out.println("gelaufen"));
         laeufer.{{0}}();
         laeufer.{{1}}();
         System.out.println("Ziel");
         """,
         [["start"], ["join"]],
         "start() gibt den zweiten Arbeitsstrang frei und kehrt sofort zurück. Erst join() hält an, bis "
         "er fertig ist. Würde man statt start() die Methode run() aufrufen, liefe alles im Hauptstrang – "
         "von Nebenläufigkeit wäre nichts zu sehen.",
         hint="Erst das englische Wort fürs Starten, dann das fürs Wiedertreffen.",
         verify={"output": "gelaufen\nZiel"},
         group="t23-3"),
    code("z-con-23-4", "concurrency", 4,
         "Starte einen Thread, der „fertig“ ausgibt, warte auf ihn und gib danach „Ende“ aus.",
         """
         // Thread anlegen, starten, abwarten
         """,
         """
         Thread t = new Thread(() -> System.out.println("fertig"));
         t.start();
         t.join();
         System.out.println("Ende");
         """,
         [req(r"new\s+Thread", "Lege einen Thread an."),
          req(r"\.start\s*\(\s*\)", "start() lässt ihn loslaufen."),
          req(r"\.join\s*\(\s*\)", "join() wartet, bis er fertig ist."),
          req(r'"Ende"', "Danach kommt „Ende“.", scope="raw")],
         "Ohne join stünde „Ende“ möglicherweise vor „fertig“ – das Hauptprogramm wartet von sich aus "
         "nicht. Genau deshalb braucht man join, bevor man mit dem Ergebnis eines Threads weiterarbeitet.",
         expected="fertig\nEnde",
         group="t23-4"),
    mc("z-con-23-5", "concurrency", 5, "Warum nimmt man AtomicInteger statt eines gewöhnlichen int-Zählers?",
       ["Weil Erhöhen dort in einem Schritt passiert und nichts verloren geht",
        "Weil int für große Zahlen zu klein ist",
        "Weil Threads gewöhnliche Zahlen nicht verändern dürfen",
        "Weil AtomicInteger schneller rechnet"],
       "zaehler++ sind in Wahrheit drei Schritte: lesen, erhöhen, zurückschreiben. Zwei Threads können "
       "denselben alten Wert lesen und dieselbe neue Zahl schreiben – eine Erhöhung geht verloren. "
       "AtomicInteger erledigt alle drei Schritte ununterbrechbar.",
       why=[None,
            "Mit der Größe hat es nichts zu tun – der Fehler tritt auch bei kleinen Zahlen auf.",
            "Dürfen sie. Das Problem ist, dass sie es gleichzeitig tun.",
            "Schneller ist es nicht, eher etwas langsamer. Dafür ist das Ergebnis verlässlich."],
       group="t23-5"),
    out("z-con-24-1", "concurrency", 1, "Was gibt das Programm aus?",
        """
        try (ExecutorService team = Executors.newFixedThreadPool(1)) {
            Future<String> zettel = team.submit(() -> "fertig");
            System.out.println(zettel.get());
        }
        """,
        "fertig",
        "submit gibt sofort einen Abholschein zurück – die Arbeit läuft erst noch. get holt das Ergebnis "
        "ab und wartet dabei, falls nötig. Das Future ist also nicht das Ergebnis selbst, sondern das "
        "Versprechen darauf.",
        group="t24-1"),
    fill("z-con-24-2", "concurrency", 2, "Ergänze den Executor, der für jede Aufgabe einen virtuellen Thread nimmt.",
         """
         try (ExecutorService team = Executors.{{0}}()) {
             Future<Integer> f = team.submit(() -> 6 * 7);
             System.out.println(f.get());
         }
         """,
         [["newVirtualThreadPerTaskExecutor"]],
         "Virtuelle Threads verwaltet Java selbst statt des Betriebssystems und legt sie beim Warten "
         "beiseite. Deshalb sind Tausende kein Problem – bei gewöhnlichen Threads wäre längst Schluss. "
         "Ihr Vorteil liegt im Warten, nicht im Rechnen.",
         hint="„new“ plus „virtueller Thread pro Aufgabe“ – auf Englisch, in einem Wort.",
         verify={"output": "42"},
         group="t24-2"),
    fill("z-con-24-3", "concurrency", 3, "Ergänze beide Schritte: Aufgabe einreichen und Ergebnis abholen.",
         """
         try (ExecutorService team = Executors.newFixedThreadPool(2)) {
             Future<Integer> f = team.{{0}}(() -> 5 * 5);
             System.out.println(f.{{1}}());
         }
         """,
         [["submit"], ["get"]],
         "submit reicht die Aufgabe ein und kehrt sofort zurück, get holt das Ergebnis ab und wartet "
         "dabei. Genau diese Trennung macht Nebenläufigkeit nutzbar: Man kann mehrere Aufgaben einreichen, "
         "bevor man die erste abholt.",
         hint="Erst das englische Wort fürs Einreichen, dann das fürs Holen.",
         verify={"output": "25"},
         group="t24-3"),
    mc("z-con-24-4", "concurrency", 4, "Warum reicht man erst alle Aufgaben ein und holt die Ergebnisse danach ab?",
       ["Weil sie sonst nacheinander laufen und der Vorteil verloren geht",
        "Weil submit sonst eine Exception wirft",
        "Weil get nur einmal aufgerufen werden darf",
        "Weil der Executor sonst nicht schließt"],
       "get wartet, bis genau diese Aufgabe fertig ist. Ruft man es direkt nach jedem submit auf, steht "
       "man jedes Mal still – die Aufgaben laufen dann der Reihe nach statt nebeneinander. Erst "
       "einreichen, dann einsammeln.",
       why=[None,
            "submit nimmt beliebig viele Aufgaben entgegen, auch während andere noch laufen.",
            "get darf man mehrfach aufrufen – es liefert danach dasselbe Ergebnis zurück.",
            "Der Executor schließt so oder so, bei try-with-resources sogar automatisch."],
       group="t24-4"),
    fill("z-con-24-5", "concurrency", 5, "Ergänze: erst alle drei einreichen, danach einsammeln.",
         """
         try (ExecutorService team = Executors.newFixedThreadPool(3)) {
             List<Future<Integer>> zettel = new ArrayList<>();
             for (int i = 1; i <= 3; i++) {
                 int wert = i;
                 zettel.{{0}}(team.submit(() -> wert * 10));
             }
             int summe = 0;
             for (Future<Integer> f : zettel) {
                 summe += f.{{1}}();
             }
             System.out.println(summe);
         }
         """,
         [["add"], ["get"]],
         "Die Abholscheine wandern zuerst vollständig in die Liste – erst danach beginnt das Einsammeln. "
         "So laufen alle drei Aufgaben nebeneinander. Die Hilfsvariable wert ist nötig, weil ein Lambda "
         "nur auf unveränderliche Werte zugreifen darf, der Schleifenzähler i sich aber ändert.",
         hint="Erst die Methode, die etwas an eine Liste hängt, dann die, die ein Ergebnis abholt.",
         verify={"output": "60"},
         group="t24-5"),
]

# ---------------------------------------------------------------- Streams
STREAMS = [
    fill("z-lam-12-1", "lambdas", 1, "Ergänze das Zeichen, das Zutaten und Arbeit eines Lambdas trennt.",
         """
         List<String> namen = List.of("Ada");
         namen.forEach(n {{0}} System.out.println(n));
         """,
         [["->"]],
         "Links vom Pfeil steht, was hereinkommt, rechts, was damit passiert. Der Doppelpfeil => stammt "
         "aus JavaScript, lambda x: aus Python – beides lehnt der Java-Compiler ab.",
         hint="Ein Minus und ein Größer-Zeichen.",
         verify={"output": "Ada"},
         group="t12-1"),
    fill("z-lam-12-2", "lambdas", 2, "Ergänze die Methode, die für jedes Element etwas tut.",
         """
         List<String> farben = List.of("rot", "blau");
         farben.{{0}}(f -> System.out.println(f));
         """,
         [["forEach"]],
         "forEach übernimmt das Durchlaufen – man sagt nur noch, WAS mit jedem Element passieren soll, "
         "nicht mehr, wie man durchzählt. Die Reihenfolge der Liste bleibt dabei erhalten.",
         hint="„für jedes“ – auf Englisch, in einem Wort.",
         verify={"output": "rot\nblau"},
         group="t12-2"),
    fill("z-lam-26-1", "lambdas", 2, "Ergänze den Sammler, der nach dem ersten Buchstaben gruppiert.",
         """
         List<String> tiere = List.of("Hund", "Hase", "Katze");
         Map<Character, List<String>> nach = tiere.stream()
             .collect(Collectors.{{0}}(t -> t.charAt(0)));
         System.out.println(nach);
         """,
         [["groupingBy"]],
         "groupingBy beantwortet „welche gehören zusammen?“ in einem Schritt: Der Schlüssel ist das "
         "gemeinsame Merkmal, der Wert die Liste dazu. Von Hand bräuchte es eine Schleife und jedes Mal "
         "die Abfrage, ob der Schlüssel schon existiert.",
         hint="„gruppieren nach“ – auf Englisch, in einem Wort.",
         verify={"output": "{A=[], H=[Hund, Hase], K=[Katze]}".replace("A=[], ", "")},
         group="t26-1"),
    fill("z-lam-26-2", "lambdas", 3, "Ergänze die Station, die alles zu einem einzigen Wert zusammenfaltet.",
         """
         List<Integer> zahlen = List.of(1, 2, 3, 4);
         int summe = zahlen.stream().{{0}}(0, (a, b) -> a + b);
         System.out.println(summe);
         """,
         [["reduce"]],
         "reduce faltet das ganze Fließband zu einem Wert zusammen: Die 0 ist der Startwert, die Funktion "
         "sagt, wie zwei Werte verschmelzen. Der Startwert ist zugleich das Ergebnis bei einer leeren "
         "Liste – deshalb muss er zur Rechenart passen, bei einer Multiplikation wäre er 1.",
         hint="„reduzieren“ – auf Englisch.",
         verify={"output": "10"},
         group="t26-2"),
    code("z-lam-26-3", "lambdas", 4,
         "Gruppiere die Wörter mit einem Stream nach ihrer Länge und gib die Map aus.",
         """
         List<String> woerter = List.of("Ei", "Hut", "Tee");
         // nach Länge gruppieren und ausgeben
         """,
         """
         List<String> woerter = List.of("Ei", "Hut", "Tee");
         Map<Integer, List<String>> nachLaenge = woerter.stream()
             .collect(Collectors.groupingBy(String::length));
         System.out.println(nachLaenge);
         """,
         [req(r"\.stream\s*\(\s*\)", "Leg die Wörter aufs Fließband."),
          req(r"groupingBy", "Zum Gruppieren gibt es Collectors.groupingBy."),
          req(r"length", "Gruppiert wird nach der Länge."),
          req(r"System\.out\.println", "Am Ende wird die Map ausgegeben.")],
         "Der Schlüssel entsteht aus der Funktion, die man groupingBy mitgibt – hier die Länge. Elemente "
         "mit demselben Schlüssel landen automatisch in derselben Liste. Die Reihenfolge der Schlüssel "
         "bestimmt dabei die Map, nicht die Eingabe.",
         expected="{2=[Ei], 3=[Hut, Tee]}",
         group="t26-3"),
    code("z-lam-26-4", "lambdas", 4,
         "Mach aus den beiden Listen mit einem Stream eine einzige, sortierte Liste und gib sie aus.",
         """
         List<List<String>> gruppen = List.of(List.of("Linus", "Ada"), List.of("Grace"));
         // zu einer flachen, sortierten Liste zusammenführen
         """,
         """
         List<List<String>> gruppen = List.of(List.of("Linus", "Ada"), List.of("Grace"));
         List<String> alle = gruppen.stream()
             .flatMap(List::stream)
             .sorted()
             .toList();
         System.out.println(alle);
         """,
         [req(r"flatMap", "flatMap macht aus Listen von Listen eine flache Folge."),
          req(r"sorted\s*\(\s*\)", "Danach wird sortiert."),
          req(r"toList|collect", "Am Ende werden die Elemente eingesammelt.")],
         "map allein ergäbe ein Fließband von Listen – flatMap packt sie aus, sodass einzelne Namen "
         "darauf liegen. Erst dadurch kann sorted über alle Namen gemeinsam ordnen statt nur innerhalb "
         "jeder Gruppe.",
         expected="[Ada, Grace, Linus]",
         group="t26-4"),
    fill("z-lam-26-5", "lambdas", 5, "Ergänze die Stationen, die das längste Wort finden.",
         """
         List<String> woerter = List.of("Hut", "Banane", "Tee");
         String laengstes = woerter.stream()
             .{{0}}(Comparator.comparingInt(String::length))
             .{{1}}("");
         System.out.println(laengstes);
         """,
         [["max"], ["orElse"]],
         "max braucht eine Regel, wonach verglichen wird – ohne sie wüsste das Fließband nicht, was "
         "„größer“ bedeutet. Zurück kommt ein Optional, weil es bei einer leeren Liste kein Ergebnis "
         "gäbe; orElse legt für diesen Fall einen Ersatz fest.",
         hint="Erst das englische Wort fürs Maximum, dann das für den Ersatzwert.",
         verify={"output": "Banane"},
         group="t26-5"),
]

# ---------------------------------------------------------------- Projekte
PROJEKTE = [
    fill("z-proj-27-3", "projects", 3, "Ergänze den Vergleich: Bestanden ist bis Note 4 einschließlich.",
         """
         int[] noten = {2, 5, 4};
         int bestanden = 0;
         for (int n : noten) {
             if (n {{0}} 4) {
                 bestanden++;
             }
         }
         System.out.println(bestanden);
         """,
         [["<="]],
         "Der Unterschied zwischen < und <= entscheidet hier über eine ganze Note: Mit < fiele die 4 "
         "durch. Solche Grenzfälle sind die häufigste Fehlerquelle überhaupt – beim Testen prüft man "
         "deshalb zuerst genau den Wert an der Grenze.",
         hint="Die 4 soll noch dazugehören.",
         verify={"output": "2"},
         group="t27-3"),
    fill("z-proj-27-5", "projects", 5, "Ergänze den Bericht: Schnitt als Kommazahl, beste Note als kleinste Zahl.",
         """
         int[] noten = {3, 1, 4};
         double schnitt = ({{0}}) (3 + 1 + 4) / noten.length;
         int beste = Arrays.stream(noten).{{1}}().orElse(0);
         System.out.println("Schnitt: " + schnitt + ", beste Note: " + beste);
         """,
         [["double"], ["min"]],
         "Ohne den Cast rechnete Java ganzzahlig: 8 / 3 ergäbe 2 statt 2.666… Der Cast muss dabei vor "
         "der Division stehen – danach wäre das Ergebnis schon abgeschnitten. Bei Noten ist die beste "
         "die kleinste Zahl, deshalb min und nicht max.",
         hint="Erst der Typ, der Nachkommastellen kann, dann das englische Wort fürs Minimum.",
         verify={"output": "Schnitt: 2.6666666666666665, beste Note: 1"},
         group="t27-5"),
    fill("z-proj-28-1", "projects", 2, "Ergänze den Datentyp, der Titel und Häkchen zusammenhält.",
         """
         {{0}} Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 Aufgabe a = new Aufgabe("Einkaufen", false);
                 System.out.println(a);
             }
         }
         """,
         [["record"]],
         "Ein Record bündelt zusammengehörige Werte und bringt Konstruktor, Lesemethoden, equals, "
         "hashCode und toString gleich mit. Genau deshalb passt er zu einer Aufgabe: Es geht um Daten, "
         "nicht um Verhalten.",
         hint="Englisch für „Datensatz“.",
         ctx="file",
         verify={"context": "file", "output": "Aufgabe[titel=Einkaufen, erledigt=false]"},
         group="t28-1"),
    fill("z-proj-28-2", "projects", 2, "Ergänze die Lesemethode des Records.",
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 Aufgabe a = new Aufgabe("Lernen", true);
                 System.out.println(a.{{0}}());
             }
         }
         """,
         [["titel"]],
         "Die Lesemethode heißt genauso wie das Feld – titel(), nicht getTitel(). Das ist die "
         "Record-Schreibweise und ein sichtbarer Unterschied zur gewöhnlichen Klasse.",
         hint="Genau wie das Feld heißt – ohne „get“ davor.",
         ctx="file",
         verify={"context": "file", "output": "Lernen"},
         group="t28-2"),
    code("z-proj-28-3", "projects", 3,
         "Gib nur die Titel der noch offenen Aufgaben aus – eine pro Zeile.",
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 List<Aufgabe> liste = new ArrayList<>();
                 liste.add(new Aufgabe("Einkaufen", false));
                 liste.add(new Aufgabe("Lernen", true));
                 liste.add(new Aufgabe("Sport", false));
                 // offene Aufgaben ausgeben
             }
         }
         """,
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 List<Aufgabe> liste = new ArrayList<>();
                 liste.add(new Aufgabe("Einkaufen", false));
                 liste.add(new Aufgabe("Lernen", true));
                 liste.add(new Aufgabe("Sport", false));
                 for (Aufgabe a : liste) {
                     if (!a.erledigt()) {
                         System.out.println(a.titel());
                     }
                 }
             }
         }
         """,
         [req(r"for\s*\(|stream", "Geh die Liste durch – mit einer Schleife oder einem Stream."),
          req(r"!\s*\w+\.erledigt\s*\(\s*\)|erledigt\s*\(\s*\)\s*==\s*false", "Offen heißt: erledigt ist false."),
          req(r"\.titel\s*\(\s*\)", "Ausgegeben wird der Titel."),
          req(r"System\.out\.println", "Eine Aufgabe pro Zeile.")],
         "Das Ausrufezeichen dreht den Wahrheitswert um – „nicht erledigt“ ist kürzer und lesbarer als "
         "der Vergleich mit false. Weil erledigt() schon einen boolean liefert, braucht es keinen "
         "zusätzlichen Vergleich.",
         ctx="file",
         expected="Einkaufen\nSport",
         group="t28-3"),
    code("z-proj-28-4", "projects", 4,
         "Hake die erste Aufgabe ab, indem du sie durch eine neue mit erledigt = true ersetzt.",
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 List<Aufgabe> liste = new ArrayList<>();
                 liste.add(new Aufgabe("Putzen", false));
                 // Aufgabe 0 abhaken und die Liste ausgeben
             }
         }
         """,
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 List<Aufgabe> liste = new ArrayList<>();
                 liste.add(new Aufgabe("Putzen", false));
                 Aufgabe alt = liste.get(0);
                 liste.set(0, new Aufgabe(alt.titel(), true));
                 System.out.println(liste);
             }
         }
         """,
         [req(r"\.set\s*\(\s*0", "set ersetzt den Eintrag an Position 0."),
          req(r"new\s+Aufgabe\s*\(", "Ein Record lässt sich nicht ändern – es muss ein neuer entstehen."),
          req(r"true", "Die neue Fassung ist erledigt."),
          req(r"System\.out\.println", "Am Ende wird die Liste ausgegeben.")],
         "Ein Record ist unveränderlich – abhaken heißt deshalb: neuen bauen und den alten ersetzen. Das "
         "klingt umständlich, hat aber einen Vorteil: Wer den alten Record noch irgendwo hält, erlebt "
         "keine überraschende Änderung hinter seinem Rücken.",
         ctx="file",
         expected="[Aufgabe[titel=Putzen, erledigt=true]]",
         group="t28-4"),
    fill("z-proj-28-5", "projects", 5, "Ergänze die Nummerierung und das Häkchen.",
         """
         record Aufgabe(String titel, boolean erledigt) {}

         public class Main {
             public static void main(String[] args) {
                 List<Aufgabe> liste = new ArrayList<>();
                 liste.add(new Aufgabe("Einkaufen", false));
                 liste.add(new Aufgabe("Java lernen", true));
                 for (int i = 0; i < liste.size(); i++) {
                     Aufgabe a = liste.get(i);
                     System.out.println((i {{0}} 1) + ". [" + (a.erledigt() {{1}} "x" : " ") + "] " + a.titel());
                 }
             }
         }
         """,
         [["+"], ["?"]],
         "Listen zählen ab 0, Menschen ab 1 – deshalb i + 1. Das Fragezeichen wählt mitten im Text "
         "zwischen zwei Werten: Bedingung ? dann : sonst. Ein if ginge dort nicht, weil es eine "
         "Anweisung ist und keinen Wert liefert.",
         hint="Erst die Rechenart für die Nummer, dann das Zeichen, das eine Auswahl im Text einleitet.",
         ctx="file",
         verify={"context": "file", "output": "1. [ ] Einkaufen\n2. [x] Java lernen"},
         group="t28-5"),
    out("z-proj-29-1", "projects", 1, "Was gibt das Programm aus?",
        """
        enum Raum { FLUR, KUECHE }

        public class Main {
            public static void main(String[] args) {
                Raum hier = Raum.KUECHE;
                System.out.println(hier);
                System.out.println(Raum.values().length);
            }
        }
        """,
        """
        KUECHE
        2
        """,
        "Ein enum gibt seinen Namen aus, nicht eine Zahl. Und weil alle Werte aufgezählt sind, kennt "
        "das Programm ihre Anzahl – bei Texten als Raumnamen wüsste niemand, welche es überhaupt gibt, "
        "und ein Tippfehler fiele erst beim Spielen auf.",
        ctx="file",
        group="t29-1"),
    fill("z-proj-29-2", "projects", 2, "Ergänze den Zugriff auf die Karte.",
         """
         enum Raum { FLUR, KUECHE }

         public class Main {
             public static void main(String[] args) {
                 Map<Raum, Raum> norden = new HashMap<>();
                 norden.{{0}}(Raum.FLUR, Raum.KUECHE);
                 System.out.println(norden.{{1}}(Raum.FLUR));
             }
         }
         """,
         [["put"], ["get"]],
         "Eine Map ordnet jedem Schlüssel genau einen Wert zu – hier: von welchem Raum führt Norden "
         "wohin. put trägt ein, get schlägt nach. Ein enum eignet sich besonders gut als Schlüssel, "
         "weil es nur endlich viele Möglichkeiten gibt.",
         hint="Erst das englische Wort fürs Hineinlegen, dann das fürs Holen.",
         ctx="file",
         verify={"context": "file", "output": "KUECHE"},
         group="t29-2"),
    fill("z-proj-29-3", "projects", 3, "Ergänze den switch-Ausdruck über das enum.",
         """
         enum Raum { FLUR, GARTEN }

         public class Main {
             public static void main(String[] args) {
                 Raum hier = Raum.GARTEN;
                 String text = {{0}} (hier) {
                     case FLUR -> "Ein langer Flur.";
                     case GARTEN -> "Die Sonne scheint.";
                 };
                 System.out.println(text);
             }
         }
         """,
         [["switch"]],
         "Als Ausdruck liefert das switch einen Wert, der direkt in die Variable wandert – deshalb steht "
         "hinter der schließenden Klammer ein Semikolon. Weil alle enum-Werte aufgezählt sind, prüft Java, "
         "dass kein Fall fehlt; ein default ist unnötig.",
         hint="Der Weichensteller, der zwischen mehreren Fällen wählt.",
         ctx="file",
         verify={"context": "file", "output": "Die Sonne scheint."},
         group="t29-3"),
    code("z-proj-29-4", "projects", 4,
         "Geh die Befehle durch und bewege dich über die Karte. Unbekannte Richtungen lassen dich stehen.",
         """
         enum Raum { FLUR, KUECHE }

         public class Main {
             public static void main(String[] args) {
                 Map<Raum, Map<String, Raum>> wege = new HashMap<>();
                 wege.put(Raum.FLUR, Map.of("norden", Raum.KUECHE));
                 wege.put(Raum.KUECHE, Map.of("sueden", Raum.FLUR));
                 String[] befehle = {"norden", "springen"};
                 Raum hier = Raum.FLUR;
                 // Befehle abarbeiten, danach den Raum ausgeben
             }
         }
         """,
         """
         enum Raum { FLUR, KUECHE }

         public class Main {
             public static void main(String[] args) {
                 Map<Raum, Map<String, Raum>> wege = new HashMap<>();
                 wege.put(Raum.FLUR, Map.of("norden", Raum.KUECHE));
                 wege.put(Raum.KUECHE, Map.of("sueden", Raum.FLUR));
                 String[] befehle = {"norden", "springen"};
                 Raum hier = Raum.FLUR;
                 for (String befehl : befehle) {
                     hier = wege.get(hier).getOrDefault(befehl, hier);
                 }
                 System.out.println(hier);
             }
         }
         """,
         [req(r"for\s*\(", "Geh alle Befehle der Reihe nach durch."),
          req(r"getOrDefault", "Unbekannte Richtungen fängt getOrDefault ab."),
          req(r"System\.out\.println", "Am Ende wird der Raum ausgegeben.")],
         "getOrDefault(befehl, hier) ist der Kern: Gibt es den Weg, geht es weiter; gibt es ihn nicht, "
         "bleibt man stehen. Mit get käme null zurück und der nächste Schleifendurchlauf würde abstürzen – "
         "ein Tippfehler des Spielers würde das ganze Spiel beenden.",
         ctx="file",
         expected="KUECHE",
         group="t29-4"),
    fill("z-proj-29-5", "projects", 5, "Ergänze die Spielschleife.",
         """
         enum Raum { FLUR, GARTEN }

         public class Main {
             public static void main(String[] args) {
                 Map<Raum, Map<String, Raum>> wege = new HashMap<>();
                 wege.put(Raum.FLUR, Map.of("osten", Raum.GARTEN));
                 wege.put(Raum.GARTEN, Map.of("westen", Raum.FLUR));
                 String[] befehle = {"osten", "fliegen"};
                 Raum hier = Raum.FLUR;
                 for (String befehl : befehle) {
                     hier = wege.get(hier).{{0}}(befehl, {{1}});
                 }
                 System.out.println(hier);
             }
         }
         """,
         [["getOrDefault"], ["hier"]],
         "Der zweite Wert ist der Ersatz, falls es den Weg nicht gibt – und genau dafür setzt man den "
         "aktuellen Raum ein: Dann bleibt man einfach stehen. Ein anderer Ersatzwert würde den Spieler "
         "bei jedem Tippfehler teleportieren.",
         hint="Die Methode mit Ersatzwert – und als Ersatz der Raum, in dem man gerade steht.",
         ctx="file",
         verify={"context": "file", "output": "GARTEN"},
         group="t29-5"),
]

# ---------------------------------------------------------------- UML
UML = [
    fill("z-uml-31-2", "umlrelations", 2, "Ergänze das Schlüsselwort zur gestrichelten Linie.",
         """
         interface Fahrbar {
             void fahren();
         }

         class Roller {{0}} Fahrbar {
             public void fahren() {
                 System.out.println("rollt");
             }
         }

         public class Main {
             public static void main(String[] args) {
                 new Roller().fahren();
             }
         }
         """,
         [["implements"]],
         "Gestrichelt heißt: Hier wird nichts geerbt, sondern ein Vertrag unterschrieben. Das Interface "
         "gibt nur vor, welche Methoden es geben muss – den Inhalt liefert die Klasse. Bei durchgezogener "
         "Linie stünde extends.",
         hint="Nicht „erben von“, sondern „umsetzen“.",
         ctx="file",
         diagram=INTERFACE_DIAGRAM,
         verify={"context": "file", "output": "rollt"},
         group="t31-2"),
    code("z-uml-31-5", "umlrelations", 4,
         "Setze die Abhängigkeit um: Rechnung benutzt einen Drucker nur als Parameter der Methode drucke.",
         """
         class Drucker {
             void ausgeben(String text) {
                 System.out.println(text);
             }
         }

         // Klasse Rechnung hier ergänzen – ohne Feld vom Typ Drucker
         """,
         """
         class Drucker {
             void ausgeben(String text) {
                 System.out.println(text);
             }
         }

         class Rechnung {
             void drucke(Drucker drucker) {
                 drucker.ausgeben("Rechnung");
             }
         }
         """,
         [req(r"class\s+Rechnung", "Es fehlt die Klasse Rechnung."),
          req(r"drucke\s*\(\s*Drucker\s+\w+\s*\)", "Der Drucker kommt als Parameter herein, nicht als Feld."),
          req(r"\.ausgeben\s*\(", "Innerhalb der Methode wird der Drucker benutzt."),
          forbid(r"(private|public)?\s*Drucker\s+\w+\s*;", "Ein Feld wäre eine Assoziation – der gestrichelte Pfeil meint nur kurzes Benutzen.")],
         "Der gestrichelte Pfeil ist die schwächste aller Beziehungen: Die Rechnung kennt den Drucker nur "
         "für die Dauer des Methodenaufrufs. Ein Feld wäre schon eine Assoziation, eine Raute ein Enthalten. "
         "Je schwächer die Beziehung, desto leichter lässt sich später etwas austauschen.",
         ctx="file",
         diagram=DRUCKER,
         verify={"context": "file", "main": "new Rechnung().drucke(new Drucker());", "output": "Rechnung"},
         group="t31-5"),
    out("z-uml-32-1", "umlrelations", 1, "Was gibt der Code zum Diagramm aus?",
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
        }

        public class Main {
            public static void main(String[] args) {
                System.out.println(new Tier().laut());
                System.out.println(new Hund().laut());
            }
        }
        """,
        """
        ...
        Wau
        """,
        "Die Eltern-Klasse behält ihre eigene Fassung – vererben heißt nicht, dass sich oben etwas ändert. "
        "Nur das Kind ersetzt die Methode für sich. Der Pfeil im Diagramm zeigt deshalb vom Hund zum Tier "
        "und nicht umgekehrt.",
        ctx="file",
        diagram=TIER_HUND,
        group="t32-1"),
    out("z-uml-32-2", "umlbasics", 2, "Was gibt der Code zum Kasten aus?",
        """
        class Konto {
            private double stand;

            public void einzahlen(double betrag) {
                stand = stand + betrag;
            }

            public double getStand() {
                return stand;
            }
        }

        public class Main {
            public static void main(String[] args) {
                Konto k = new Konto();
                k.einzahlen(20.5);
                System.out.println(k.getStand());
            }
        }
        """,
        "20.5",
        "Im Kasten steht „+ einzahlen()“ ohne Typ hinter dem Doppelpunkt – die Methode gibt nichts "
        "zurück, sie verändert nur den Stand. Bei „+ getStand(): double“ steht der Typ dagegen dabei. "
        "Ein privates Feld startet bei 0.0, deshalb reicht eine Einzahlung für das Ergebnis.",
        ctx="file",
        diagram=KONTO,
        group="t32-2"),
    fill("z-uml-32-3", "umlrelations", 3, "Ergänze Vererbung und Überschreibung passend zum Diagramm.",
         """
         abstract class Form {
             abstract double flaeche();
         }

         class Quadrat {{0}} Form {
             double seite = 3;

             @Override
             double {{1}}() {
                 return seite * seite;
             }
         }

         public class Main {
             public static void main(String[] args) {
                 Form f = new Quadrat();
                 System.out.println(f.flaeche());
             }
         }
         """,
         [["extends"], ["flaeche"]],
         "Die durchgezogene Linie mit Dreiecksspitze bedeutet extends. Weil Form abstrakt ist, muss das "
         "Kind die Methode liefern – sonst ließe sich die Klasse gar nicht übersetzen. Links steht Form, "
         "im Speicher liegt ein Quadrat: Aufgerufen wird dessen Fassung.",
         hint="Erst das Wort für Vererbung, dann der Name der Methode aus dem Diagramm.",
         ctx="file",
         diagram=FORM_HIERARCHIE,
         verify={"context": "file", "output": "9.0"},
         group="t32-3"),
    code("z-uml-32-4", "umlrelations", 3,
         "Setze das Diagramm um: Auto unterschreibt den Vertrag Fahrbar und gibt beim Fahren „faehrt“ aus.",
         """
         interface Fahrbar {
             void fahren();
         }

         // Klasse Auto hier ergänzen
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
          req(r"public\s+void\s+fahren\s*\(\s*\)", "Die Methode muss public sein – im Interface ist sie es automatisch."),
          req(r'"faehrt"', "Ausgegeben wird „faehrt“.", scope="raw")],
         "Wer einen Vertrag unterschreibt, muss jede verlangte Methode liefern – sonst übersetzt Java die "
         "Klasse gar nicht erst. Das public ist dabei Pflicht: Methoden eines Interfaces sind öffentlich, "
         "und beim Umsetzen darf man die Sichtbarkeit nicht einschränken.",
         ctx="file",
         diagram=INTERFACE_DIAGRAM,
         verify={"context": "file", "main": "new Auto().fahren();", "output": "faehrt"},
         group="t32-4"),
]

POOL_DEPTH = BASIS + NEBENLAEUFIG + STREAMS + PROJEKTE + UML
