"""Modul „Java in der Praxis“: JSON, HTTP und Datenbanken.

Datenbanken, HTTP und JSON kamen im ganzen Kurs nicht ein einziges Mal vor – genau das,
was man braucht, sobald ein Programm mit anderen Programmen redet oder Daten dauerhaft
ablegt. Randbedingung wie überall im Kurs: Jeder Schnipsel läuft mit dem reinen JDK.

  * JSON: Das JDK hat keine JSON-Bibliothek. Geübt wird, was man trotzdem wissen muss –
    der Aufbau, JSON aus Records bauen, Sonderzeichen maskieren – und warum man in der
    Praxis Jackson & Co. nimmt. Die eine Jackson-Karte wird bewusst nicht ausgeführt.
  * HTTP: vollständig ausführbar. Die Programme starten ihren eigenen kleinen Server
    (com.sun.net.httpserver) auf einem freien Port und fragen ihn mit HttpClient ab –
    ohne Internet und jedes Mal mit demselben Ergebnis.
  * Datenbanken: Das JDK enthält die JDBC-Schnittstelle, aber keine Datenbank. Der
    JDBC-Code wird deshalb nur übersetzt, nicht ausgeführt; die Lektion sagt das offen.
    Ausgeführt wird, was ohne Datenbank geht – etwa, wie SQL-Injection entsteht.

Jede Lektion: vier Theoriekarten (die vierte, „Der häufigste Irrtum“, steht unten in
PRAXIS_IRRTUM), fünf Aufgaben mit steigendem Niveau und je drei Varianten im Pool.
"""
from authoring import any_of, card, code, fill, forbid, lesson, mc, out, req

PRAXIS_TOPICS = [
    ("json", "JSON", "curlybraces.square", "Daten als Text austauschen – Aufbau, bauen, maskieren"),
    ("http", "HTTP & Web", "globe", "Anfragen senden, Antworten lesen, ein eigener kleiner Server"),
    ("database", "Datenbanken & SQL", "cylinder.split.1x2", "SQL, JDBC und sichere Abfragen mit PreparedStatement"),
]

# ================================================================ JSON
l33 = lesson("l33-json", "Daten als JSON", "Das Austauschformat fast aller Web-Dienste: lesen, bauen, richtig maskieren.",
             ["json"], 9, [
    card("JSON: Daten als Text",
         "Wenn Programme Daten austauschen – eine App mit einem Server, ein Dienst mit einem anderen –, "
         "schicken sie fast immer JSON. Das ist nur Text, aber mit festen Regeln: Geschweifte Klammern "
         "umschließen ein Objekt aus Paaren „Schlüssel: Wert“, eckige Klammern eine Liste. Schlüssel und "
         "Texte stehen in doppelten Anführungszeichen, Zahlen, true, false und null ohne.",
         code='''
         String held = """
             {
               "name": "Mia",
               "level": 3,
               "aktiv": true,
               "items": ["Schwert", "Schild"]
             }
             """;
         System.out.print(held);
         ''',
         tip="Das ähnelt einer Map mit Listen darin – nur eben als Text, den jede Programmiersprache lesen kann.",
         verify={"output": '{\n  "name": "Mia",\n  "level": 3,\n  "aktiv": true,\n  "items": ["Schwert", "Schild"]\n}'}),
    card("JSON aus einem Record bauen",
         "Um eigene Daten als JSON zu verschicken, baust du den Text aus den Feldern zusammen. Weil der "
         "JSON-Text selbst Anführungszeichen enthält, schreibst du sie in Java als \\\" – der Backslash sagt: "
         "Dieses Anführungszeichen gehört zum Text und beendet ihn nicht. Mit String.format bleibt die "
         "Schablone gut lesbar.",
         code=r'''
         record Spieler(String name, int level) {
             String toJson() {
                 return String.format("{\"name\": \"%s\", \"level\": %d}", name, level);
             }
         }
         ''',
         verify={"context": "file", "main": 'System.out.println(new Spieler("Mia", 3).toJson());',
                 "output": '{"name": "Mia", "level": 3}'}),
    card("In der Praxis: eine Bibliothek",
         "Selbst gebautes JSON bricht, sobald ein Wert ein Anführungszeichen oder einen Zeilenumbruch "
         "enthält – beides muss maskiert werden. Und JSON wieder in Objekte zu verwandeln, ist mühsam. "
         "Echte Projekte nehmen deshalb eine Bibliothek wie Jackson: Sie macht aus einem Record JSON und "
         "aus JSON wieder einen Record. Sie gehört nicht zum JDK – du bindest sie mit Maven oder Gradle ein.",
         code='''
         ObjectMapper mapper = new ObjectMapper();
         String json = mapper.writeValueAsString(new Spieler("Mia", 3));
         Spieler zurueck = mapper.readValue(json, Spieler.class);
         ''',
         info="Diese drei Zeilen laufen nur mit der Jackson-Bibliothek. JavaQuest führt sie deshalb nicht "
              "aus – alle anderen Beispiele dieser Lektion schon."),
], [
    mc("t33-1", "json", 1, "Welche Zeile ist gültiges JSON?",
       ['{"name": "Mia"}', '{name: "Mia"}', '{"name": "Mia",}', "{'name': 'Mia'}"],
       "Gültiges JSON: Der Schlüssel steht in doppelten Anführungszeichen, der Text auch, und nach dem "
       "letzten Eintrag folgt kein Komma. Jede der anderen Zeilen verletzt genau eine dieser Regeln – und "
       "schon lehnt ein Programm den ganzen Text ab.",
       why=[None,
            "Hier fehlen die Anführungszeichen um den Schlüssel name – in JSON muss jeder Schlüssel in doppelten Anführungszeichen stehen.",
            "Das Komma nach dem letzten Eintrag ist in JSON verboten, auch wenn Java und JavaScript es an manchen Stellen dulden.",
            "Einfache Anführungszeichen kennt JSON nicht – Schlüssel und Texte brauchen doppelte."],
       hint="Prüfe drei Dinge: Anführungszeichen um den Schlüssel, die Art der Anführungszeichen und was nach dem letzten Eintrag steht."),
    out("t33-2", "json", 2, "Was gibt das Programm aus?",
        r'''
        int punkte = 10 + 5;
        String json = "{\"punkte\": " + punkte + "}";
        System.out.println(json);
        ''',
        '{"punkte": 15}',
        "Java rechnet zuerst 10 + 5 = 15. Jedes \\\" im Code steht für ein Anführungszeichen im Text; der "
        "Backslash selbst wird nicht ausgegeben. Heraus kommt gültiges JSON mit der Zahl 15 – ohne "
        "Anführungszeichen, weil es eine Zahl ist.",
        hint="Aus jedem \\\" im Code wird ein normales Anführungszeichen im Text – der Backslash erscheint nicht."),
    fill("t33-3", "json", 3,
         "Ergänze, damit aus der Liste ein JSON-Array wird: jeder Name in Anführungszeichen, dazwischen ein Komma, außen eckige Klammern.",
         r'''
         List<String> tiere = List.of("Hund", "Katze");
         String json = tiere.stream()
             .map(t -> "\"" + t + "\"")
             .collect(Collectors.{{0}}(", ", "[", "]"));
         System.out.println(json);
         ''',
         [["joining"]],
         "map setzt jeden Namen in Anführungszeichen, joining klebt alles mit „, “ zusammen und setzt „[“ "
         "davor und „]“ dahinter. Heraus kommt ein JSON-Array mit zwei Texten.",
         hint="Gesucht ist der Sammler, der Texte mit Trennzeichen zu einem einzigen Text zusammenklebt – samt Anfang und Ende.",
         verify={"output": '["Hund", "Katze"]'}),
    out("t33-4", "json", 4, "Was gibt das Programm aus?",
        r'''
        String name = "Tom \"der Blitz\"";
        String kaputt = "{\"name\": \"" + name + "\"}";
        String sicher = "{\"name\": \"" + name.replace("\"", "\\\"") + "\"}";
        System.out.println(kaputt);
        System.out.println(sicher);
        ''',
        r'''
        {"name": "Tom "der Blitz""}
        {"name": "Tom \"der Blitz\""}
        ''',
        "Der Name enthält selbst Anführungszeichen. In der ersten Zeile beenden sie den JSON-Text mitten im "
        "Namen – ein Programm würde das ablehnen. In der zweiten setzt replace vor jedes Anführungszeichen "
        "einen Backslash: Dann bleibt es Teil des Textes, und das JSON ist gültig.",
        hint="Folge den Anführungszeichen im Namen: Wo würde ein JSON-Leser glauben, dass der Text schon zu Ende ist?"),
    code("t33-5", "json", 5,
         'Ergänze im Record Buch eine Methode toJson(), die zum Beispiel {"titel": "Momo", "seiten": 304} liefert.',
         '''
         record Buch(String titel, int seiten) {
             // toJson hier ergänzen
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Buch("Momo", 304).toJson());
             }
         }
         ''',
         r'''
         record Buch(String titel, int seiten) {
             String toJson() {
                 return String.format("{\"titel\": \"%s\", \"seiten\": %d}", titel, seiten);
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Buch("Momo", 304).toJson());
             }
         }
         ''',
         [req(r"String\s+toJson\s*\(\s*\)", "Ergänze im Record eine Methode String toJson()."),
          req(r'\\"titel\\"', 'Der Schlüssel titel gehört in Anführungszeichen – im Java-Text als \\"titel\\".', scope="raw"),
          req(r'\\"seiten\\"', 'Der Schlüssel seiten gehört in Anführungszeichen – im Java-Text als \\"seiten\\".', scope="raw"),
          req(r"\breturn\b", "Gib den fertigen JSON-Text mit return zurück."),
          forbid(r'\\"seiten\\":\s*\\"', "Die Seitenzahl ist eine Zahl – in JSON ohne Anführungszeichen.", scope="raw")],
         "toJson setzt die Felder in eine JSON-Schablone: titel als Text in Anführungszeichen, seiten als Zahl "
         "ohne. Mit String.format bleibt die Schablone gut lesbar; ebenso richtig ist das Zusammenkleben mit +.",
         expected='{"titel": "Momo", "seiten": 304}',
         hint="Schreib zuerst auf, wie das Ergebnis aussehen soll, und markiere die Anführungszeichen, die zum JSON gehören – die brauchen im Code einen Backslash.",
         ctx="file"),
])

POOL_JSON = [
    mc("k33-1a", "json", 2, "Welcher Wert ist in JSON erlaubt?",
       ["true", "'Hallo'", "undefined", "0x1F"],
       "JSON kennt Texte in doppelten Anführungszeichen, Dezimalzahlen, true, false, null, Objekte und "
       "Listen – mehr nicht. true steht dabei ohne Anführungszeichen, sonst wäre es der Text „true“.",
       why=[None,
            "Texte stehen in JSON immer in doppelten Anführungszeichen – einfache kennt JSON nicht.",
            "undefined gibt es in JavaScript, aber nicht in JSON. Für „nichts“ schreibt JSON null.",
            "Zahlen schreibt JSON nur dezimal – Schreibweisen wie 0x1F sind nicht erlaubt."],
       hint="Geh die Arten von Werten aus der Theoriekarte „JSON: Daten als Text“ durch und prüfe jeden Kandidaten.",
       group="t33-1"),
    fill("k33-1b", "json", 2, "Ergänze den Wahrheitswert so, wie JSON ihn schreibt.",
         r'''
         String json = "{\"aktiv\": {{0}}}";
         System.out.println(json);
         ''',
         [["true"]],
         "true und false schreibt JSON klein und ohne Anführungszeichen. Mit Anführungszeichen wäre es der "
         "Text „true“ – ein Programm, das einen Wahrheitswert erwartet, würde ihn nicht als solchen erkennen.",
         hint="Gesucht ist ein Wahrheitswert für „ja“ – klein geschrieben und ohne Anführungszeichen.",
         verify={"output": '{"aktiv": true}'},
         group="t33-1"),
    out("k33-2a", "json", 3, "Was gibt das Programm aus?",
        r'''
        String name = "Tom";
        int alter = 12;
        String json = "{\"name\": \"" + name + "\", \"alter\": " + alter + "}";
        System.out.println(json);
        ''',
        '{"name": "Tom", "alter": 12}',
        "Die Stücke werden der Reihe nach zusammengeklebt: Aus jedem \\\" wird ein Anführungszeichen. Der "
        "Name landet zwischen zwei Anführungszeichen, weil er Text ist; das Alter steht ohne, weil es eine Zahl ist.",
        hint="Setz die Stücke der Reihe nach zusammen und achte darauf, welcher Wert Anführungszeichen bekommt und welcher nicht.",
        group="t33-2"),
    mc("k33-2b", "json", 3, 'Warum steht die 15 in {"punkte": 15} ohne Anführungszeichen?',
       ["Weil JSON Zahlen ohne Anführungszeichen schreibt – mit wären sie Text",
        "Weil Java Zahlen nicht in Anführungszeichen setzen kann",
        "Weil Anführungszeichen in JSON nur für Schlüssel erlaubt sind",
        "Das ist ein Fehler – JSON verlangt überall Anführungszeichen"],
       "In JSON unterscheiden die Anführungszeichen die Art des Werts: \"15\" wäre ein Text, 15 ist eine "
       "Zahl. Wer die Daten empfängt, kann mit einer Zahl sofort rechnen – mit einem Text erst nach einer Umwandlung.",
       why=[None,
            "Java kann Zahlen problemlos in einen Text mit Anführungszeichen einbauen – die Frage ist, was JSON daraus macht.",
            "Auch Texte als Werte stehen in Anführungszeichen, etwa \"Mia\" – nur Zahlen, true, false und null nicht.",
            "Im Gegenteil: Eine Zahl in Anführungszeichen wäre gar keine Zahl mehr, sondern Text."],
       hint="Überleg, welchen Unterschied es für ein empfangendes Programm macht, ob dort 15 oder \"15\" steht.",
       group="t33-2"),
    out("k33-3a", "json", 3, "Was gibt das Programm aus?",
        '''
        List<Integer> werte = List.of(3, 1, 4);
        String json = werte.stream()
            .map(String::valueOf)
            .collect(Collectors.joining(",", "[", "]"));
        System.out.println(json);
        ''',
        "[3,1,4]",
        "Jede Zahl wird mit String.valueOf zu Text, joining klebt sie mit einem Komma ohne Leerzeichen "
        "zusammen und setzt die eckigen Klammern außen herum. Die Reihenfolge der Liste bleibt erhalten.",
        hint="joining bekommt drei Texte: was zwischen die Elemente kommt, was davor und was dahinter.",
        group="t33-3"),
    mc("k33-3b", "json", 4, 'Was liefert Collectors.joining(", ", "[", "]") für eine leere Liste?',
       ["[]", "Einen leeren Text", "null", "Eine Exception"],
       "Anfang und Ende kommen auf jeden Fall dazu, dazwischen steht nichts – also das leere JSON-Array. "
       "Praktisch: Auch eine leere Liste ergibt gültiges JSON.",
       why=[None,
            "Anfang und Ende werden immer gesetzt – auch wenn dazwischen nichts steht.",
            "joining liefert nie null, sondern immer einen Text.",
            "Eine leere Liste ist kein Fehler; joining kommt damit problemlos zurecht."],
       hint="Überleg, ob Anfang und Ende nur gesetzt werden, wenn es Elemente gibt – oder immer.",
       group="t33-3"),
    mc("k33-4a", "json", 4, "Was muss mit einem Anführungszeichen passieren, das innerhalb eines JSON-Textes stehen soll?",
       ["Es bekommt einen Backslash davor",
        "Nichts – JSON erlaubt es einfach",
        "Es wird durch ein einfaches Anführungszeichen ersetzt",
        "Der ganze Text kommt in eckige Klammern"],
       "Ein Anführungszeichen beendet in JSON den Text. Soll es selbst zum Text gehören, bekommt es einen "
       "Backslash davor: \\\". So erkennt der Leser, dass der Text noch weitergeht.",
       why=[None,
            "Ohne Kennzeichnung hält ein JSON-Leser es für das Ende des Textes – der Rest ergibt dann keinen Sinn mehr.",
            "Damit wäre das Zeichen verfälscht: Aus \" würde ' – und die Daten wären nicht mehr dieselben.",
            "Eckige Klammern machen eine Liste daraus, aber das Anführungszeichen beendet den Text trotzdem."],
       hint="Denk an Java selbst: Wie schreibst du dort ein Anführungszeichen, das zum Text gehören soll?",
       group="t33-4"),
    fill("k33-4b", "json", 4, "Ergänze die Methode, die jedes Anführungszeichen im Zitat durch \\\" ersetzt.",
         r'''
         String zitat = "Er sagte \"Hallo\"";
         String json = "{\"zitat\": \"" + zitat.{{0}}("\"", "\\\"") + "\"}";
         System.out.println(json);
         ''',
         [["replace"]],
         "replace ersetzt jedes Vorkommen des ersten Textes durch den zweiten: Aus jedem Anführungszeichen "
         "wird \\\". Damit bleibt das Zitat Teil des JSON-Textes, statt ihn vorzeitig zu beenden.",
         hint="Gesucht ist die String-Methode, die jedes Vorkommen eines Textes durch einen anderen austauscht.",
         verify={"output": r'{"zitat": "Er sagte \"Hallo\""}'},
         group="t33-4"),
    out("k33-5a", "json", 4, "Was gibt das Programm aus?",
        r'''
        record Punkt(int x, int y) {
            String toJson() {
                return String.format("{\"x\": %d, \"y\": %d}", x, y);
            }
        }

        public class Main {
            public static void main(String[] args) {
                System.out.println(new Punkt(2, -5).toJson());
            }
        }
        ''',
        '{"x": 2, "y": -5}',
        "String.format setzt der Reihe nach x und y für die beiden %d ein. Die \\\" im Code werden zu "
        "Anführungszeichen um die Schlüssel; die Zahlen stehen ohne – auch die negative.",
        hint="Jedes %d wird der Reihe nach durch den nächsten Wert hinter der Schablone ersetzt.",
        ctx="file",
        group="t33-5"),
    fill("k33-5b", "json", 5, "Ergänze die Platzhalter: titel ist ein Text, jahr eine ganze Zahl.",
         r'''
         record Film(String titel, int jahr) {
             String toJson() {
                 return String.format("{\"titel\": \"{{0}}\", \"jahr\": {{1}}}", titel, jahr);
             }
         }
         ''',
         [["%s"], ["%d"]],
         "%s setzt einen Text ein, %d eine ganze Zahl. Die Anführungszeichen um %s gehören zum JSON – der "
         "Titel ist ein Text. Um %d stehen keine, weil das Jahr eine Zahl ist.",
         hint="Welcher Platzhalter steht für Text, welcher für eine ganze Zahl? Die Karte zu printf in Lektion 7 hilft.",
         ctx="file",
         verify={"main": 'System.out.println(new Film("Matrix", 1999).toJson());',
                 "output": '{"titel": "Matrix", "jahr": 1999}'},
         group="t33-5"),
    mc("k33-1c", "json", 1, "Welche Klammern umschließen in JSON eine Liste?",
       ["Eckige Klammern [ ]", "Geschweifte Klammern { }", "Runde Klammern ( )", "Spitze Klammern < >"],
       "Eckige Klammern umschließen in JSON eine Liste, etwa [\"Schwert\", \"Schild\"]. Geschweifte Klammern "
       "gehören zu einem Objekt aus Paaren „Schlüssel: Wert“. Runde und spitze Klammern kommen in JSON gar nicht vor.",
       why=[None,
            "Geschweifte Klammern umschließen ein Objekt aus Schlüssel-Wert-Paaren, keine Liste.",
            "Runde Klammern kennt JSON nicht – in Java stehen sie etwa um die Zutaten einer Methode.",
            "Spitze Klammern gibt es in JSON nicht; in Java stehen sie bei Generics wie List<String>."],
       hint="Schau im Beispiel der Theoriekarte „JSON: Daten als Text“ nach, welche Klammern die Gegenstände unter items zusammenhalten.",
       group="t33-1"),
    fill("k33-2c", "json", 3, "Ergänze beide Lücken so, dass der Name in JSON als Text in Anführungszeichen steht.",
         r"""
         String name = "Mia";
         String json = "{\"name\": {{0}}" + name + "{{1}}}";
         System.out.println(json);
         """,
         [[r'\"'], [r'\"']],
         "Ein Name ist Text und steht in JSON zwischen Anführungszeichen. Im Java-Text schreibst du sie als \\\" – "
         "ein nacktes Anführungszeichen würde den Java-Text an dieser Stelle beenden. So entsteht {\"name\": \"Mia\"}.",
         hint="Der Name braucht Anführungszeichen, die zum Text gehören. Wie schreibst du so eines in Java, ohne dass der Text dort endet?",
         verify={"output": '{"name": "Mia"}'},
         group="t33-2"),
    out("k33-3c", "json", 3, "Was gibt das Programm aus?",
        r"""
        List<String> farben = List.of("rot");
        String json = farben.stream()
            .map(f -> "\"" + f + "\"")
            .collect(Collectors.joining(", ", "[", "]"));
        System.out.println(json);
        """,
        '["rot"]',
        "map setzt „rot“ in Anführungszeichen. Das Trennzeichen „, “ kommt nur zwischen zwei Elemente – bei "
        "einem einzigen Element gibt es kein Dazwischen. Anfang und Ende setzt joining trotzdem, also entsteht [\"rot\"].",
        hint="Überleg, wo das Trennzeichen hinkommt, wenn es nur ein einziges Element gibt – und ob Anfang und Ende trotzdem dazukommen.",
        group="t33-3"),
    mc("k33-4c", "json", 2, 'Der Text Er sagte "Hi" soll als JSON-Wert verschickt werden. Welche Schreibweise ist gültig?',
       [r'"Er sagte \"Hi\""', '"Er sagte "Hi""', """'Er sagte "Hi"'""", 'Er sagte "Hi"'],
       "Ein Text steht in JSON zwischen doppelten Anführungszeichen. Kommen darin selbst welche vor, bekommen "
       "sie einen Backslash davor – sonst hielte der Leser das erste davon schon für das Ende des Textes.",
       why=[None,
            "Das Anführungszeichen vor Hi beendet hier den Text schon nach „Er sagte “ – der Rest ist kein gültiges JSON mehr.",
            "Einfache Anführungszeichen außen herum kennt JSON nicht.",
            "Ohne Anführungszeichen außen herum ist es gar kein Text – JSON wüsste nicht, wo der Wert anfängt und aufhört."],
       hint="Zwei Regeln greifen hier: wie ein Text in JSON eingerahmt wird und was mit Anführungszeichen darin passiert.",
       group="t33-4"),
    code("k33-5c", "json", 4,
         'Ergänze im Record Aufgabe eine Methode toJson(), die zum Beispiel {"titel": "Lernen", "erledigt": false} liefert.',
         """
         record Aufgabe(String titel, boolean erledigt) {
             // toJson hier ergänzen
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Aufgabe("Lernen", false).toJson());
             }
         }
         """,
         r"""
         record Aufgabe(String titel, boolean erledigt) {
             String toJson() {
                 return "{\"titel\": \"" + titel + "\", \"erledigt\": " + erledigt + "}";
             }
         }

         public class Main {
             public static void main(String[] args) {
                 System.out.println(new Aufgabe("Lernen", false).toJson());
             }
         }
         """,
         [req(r"String\s+toJson\s*\(\s*\)", "Ergänze im Record eine Methode String toJson()."),
          req(r'\\"titel\\"', 'Der Schlüssel titel gehört in Anführungszeichen – im Java-Text als \\"titel\\".', scope="raw"),
          req(r'\\"erledigt\\"', 'Der Schlüssel erledigt gehört in Anführungszeichen – im Java-Text als \\"erledigt\\".', scope="raw"),
          req(r"\breturn\b", "Gib den fertigen JSON-Text mit return zurück."),
          forbid(r'\\"erledigt\\":\s*\\"', "Ein Wahrheitswert steht in JSON ohne Anführungszeichen – sonst wäre er der Text „false“.", scope="raw")],
         "titel ist Text und bekommt Anführungszeichen, erledigt ist ein Wahrheitswert und steht ohne – genau wie "
         "eine Zahl. Beim Zusammenkleben schreibt Java für false einfach false in den Text; mit String.format und %s "
         "geht es genauso.",
         expected='{"titel": "Lernen", "erledigt": false}',
         hint="Schreib zuerst das gewünschte Ergebnis auf und überleg für jeden Wert: Text mit Anführungszeichen oder Wahrheitswert ohne?",
         ctx="file",
         group="t33-5"),
]

# ================================================================ HTTP
_SERVER = '''HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
server.createContext("/hallo", austausch -> {
    byte[] text = "Hallo aus dem Server".getBytes();
    austausch.sendResponseHeaders(200, text.length);
    try (OutputStream aus = austausch.getResponseBody()) {
        aus.write(text);
    }
});
server.start();'''

l34 = lesson("l34-http", "HTTP: Anfragen und ein kleiner Server", "Wie Programme im Netz miteinander reden – mit Bordmitteln des JDK.",
             ["http"], 10, [
    card("Anfrage und Antwort",
         "Im Web fragt ein Programm (der Client) bei einem anderen (dem Server) an: Es nennt eine Methode – "
         "GET heißt „gib mir“, POST heißt „nimm das“ – und eine Adresse. Der Server antwortet mit einem "
         "Statuscode und einem Inhalt. 200 heißt „alles gut“, 404 „gibt es nicht“, 500 „beim Server ist etwas "
         "schiefgegangen“. In Java baust du eine Anfrage mit HttpRequest.",
         code='''
         HttpRequest anfrage = HttpRequest.newBuilder(URI.create("http://localhost:8080/hallo"))
             .GET()
             .build();
         System.out.println(anfrage.method() + " " + anfrage.uri());
         ''',
         tip="Die Anfrage zu bauen, schickt noch nichts los – das passiert erst mit client.send(…).",
         verify={"output": "GET http://localhost:8080/hallo"}),
    card("Ein eigener kleiner Server",
         "Das JDK bringt einen einfachen Webserver mit. Mit createContext legst du fest, was unter einer "
         "Adresse passiert: Der Handler bekommt den Austausch, schickt mit sendResponseHeaders Statuscode und "
         "Länge und schreibt dann den Inhalt. Port 0 heißt: Such dir einen freien Port aus – praktisch zum "
         "Ausprobieren.",
         code=_SERVER + '''
System.out.println("Server läuft: " + (server.getAddress().getPort() > 0));
server.stop(0);''',
         warning="Ein Server läuft, bis man ihn stoppt. stop(0) beendet ihn sofort – sonst würde dein Programm nie enden.",
         verify={"output": "Server läuft: true"}),
    card("Anfrage senden, Antwort lesen",
         "Der HttpClient schickt die Anfrage mit send los und wartet auf die Antwort. BodyHandlers.ofString() "
         "sagt, dass der Inhalt als Text ankommen soll. Die Antwort kennt ihren Statuscode (statusCode) und "
         "ihren Inhalt (body). Hier fragt das Programm seinen eigenen Server – so läuft das Beispiel auch "
         "ohne Internet.",
         code=_SERVER + '''
String adresse = "http://localhost:" + server.getAddress().getPort() + "/hallo";

HttpClient client = HttpClient.newHttpClient();
HttpRequest anfrage = HttpRequest.newBuilder(URI.create(adresse)).build();
HttpResponse<String> antwort = client.send(anfrage, HttpResponse.BodyHandlers.ofString());
System.out.println(antwort.statusCode());
System.out.println(antwort.body());
server.stop(0);''',
         verify={"output": "200\nHallo aus dem Server"}),
], [
    mc("t34-1", "http", 1, "Welcher Statuscode bedeutet „gibt es nicht“?",
       ["404", "200", "500", "301"],
       "404 ist die bekannteste Fehlermeldung des Webs: Unter dieser Adresse gibt es nichts. Codes mit "
       "einer 2 vorne bedeuten Erfolg, mit einer 4 einen Fehler in der Anfrage, mit einer 5 einen Fehler beim Server.",
       why=[None,
            "200 heißt das Gegenteil: Alles hat geklappt.",
            "500 heißt: Beim Server selbst ist etwas schiefgegangen – die Adresse gibt es womöglich schon.",
            "301 heißt: umgezogen – der Inhalt liegt jetzt unter einer anderen Adresse."],
       hint="Codes, die mit einer 4 beginnen, sagen: Mit der Anfrage stimmt etwas nicht."),
    out("t34-2", "http", 2, "Was gibt das Programm aus?",
        r'''
        HttpRequest anfrage = HttpRequest.newBuilder(URI.create("http://localhost:8080/spieler"))
            .POST(HttpRequest.BodyPublishers.ofString("{\"name\": \"Mia\"}"))
            .build();
        System.out.println(anfrage.method());
        System.out.println(anfrage.uri().getPath());
        ''',
        '''
        POST
        /spieler
        ''',
        "POST(…) macht aus der Anfrage eine POST-Anfrage und hängt den JSON-Text als Inhalt an. getPath() "
        "liefert von der Adresse nur den Pfad hinter Server und Port. Losgeschickt ist damit noch nichts.",
        hint="Die Methode steht in der Zeile, die den Inhalt anhängt; der Pfad ist der Teil der Adresse hinter dem Port."),
    fill("t34-3", "http", 3, "Ergänze, damit die Anfrage losgeschickt wird und der Inhalt der Antwort als Text ankommt.",
         '''
         HttpClient client = HttpClient.newHttpClient();
         HttpRequest anfrage = HttpRequest.newBuilder(URI.create("http://localhost:8080/hallo")).build();
         HttpResponse<String> antwort = client.{{0}}(anfrage, HttpResponse.BodyHandlers.{{1}}());
         ''',
         [["send"], ["ofString"]],
         "send schickt die Anfrage ab und wartet auf die Antwort. Der zweite Wert sagt, wie der Inhalt ankommen "
         "soll: BodyHandlers.ofString() macht Text daraus – deshalb steht HttpResponse<String> davor.",
         hint="Die erste Lücke ist die Methode des Clients, die eine Anfrage losschickt; die zweite macht aus dem Inhalt einen Text.",
         verify={}),
    out("t34-4", "http", 4, "Was gibt das Programm aus?",
        '''
        HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
        server.createContext("/hallo", austausch -> {
            austausch.sendResponseHeaders(200, -1);
            austausch.close();
        });
        server.start();
        String basis = "http://localhost:" + server.getAddress().getPort();

        HttpClient client = HttpClient.newHttpClient();
        HttpRequest anfrage = HttpRequest.newBuilder(URI.create(basis + "/weg")).build();
        HttpResponse<String> antwort = client.send(anfrage, HttpResponse.BodyHandlers.ofString());
        System.out.println(antwort.statusCode());
        System.out.println("Weiter geht's");
        server.stop(0);
        ''',
        '''
        404
        Weiter geht's
        ''',
        "Für /weg gibt es keinen Handler – der Server antwortet von selbst mit 404. send wirft deshalb keine "
        "Exception: Die Verbindung hat ja geklappt, nur die Antwort ist eine Fehlermeldung. Das Programm läuft "
        "einfach weiter.",
        hint="Überleg, für welche Adresse der Server einen Handler hat – und ob eine Fehlerantwort dasselbe ist wie eine gescheiterte Verbindung."),
    code("t34-5", "http", 5,
         "Ergänze einen Handler für /ping, der mit Status 200 den Text „pong“ schickt. Der Rest des Programms fragt ihn ab.",
         '''
         HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
         // Handler für /ping hier ergänzen

         server.start();
         String adresse = "http://localhost:" + server.getAddress().getPort() + "/ping";
         HttpClient client = HttpClient.newHttpClient();
         HttpResponse<String> antwort = client.send(HttpRequest.newBuilder(URI.create(adresse)).build(), HttpResponse.BodyHandlers.ofString());
         System.out.println(antwort.statusCode() + " " + antwort.body());
         server.stop(0);
         ''',
         '''
         HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
         server.createContext("/ping", austausch -> {
             byte[] text = "pong".getBytes();
             austausch.sendResponseHeaders(200, text.length);
             try (OutputStream aus = austausch.getResponseBody()) {
                 aus.write(text);
             }
         });

         server.start();
         String adresse = "http://localhost:" + server.getAddress().getPort() + "/ping";
         HttpClient client = HttpClient.newHttpClient();
         HttpResponse<String> antwort = client.send(HttpRequest.newBuilder(URI.create(adresse)).build(), HttpResponse.BodyHandlers.ofString());
         System.out.println(antwort.statusCode() + " " + antwort.body());
         server.stop(0);
         ''',
         [req(r'createContext\s*\(\s*"/ping"', 'Lege mit server.createContext("/ping", …) fest, was unter /ping passiert.', scope="raw"),
          req(r"sendResponseHeaders\s*\(\s*200\b", "Schicke mit sendResponseHeaders(200, …) den Statuscode und die Länge."),
          req(r"getResponseBody\s*\(\s*\)", "Schreibe den Text in austausch.getResponseBody()."),
          req(r'"pong"', "Der Server soll den Text „pong“ schicken.", scope="raw")],
         "createContext verbindet die Adresse /ping mit einem Handler. Der schickt zuerst Statuscode und Länge "
         "(sendResponseHeaders) und schreibt dann die Bytes von „pong“ in den Antwort-Strom. try-with-resources "
         "schließt den Strom – damit ist die Antwort komplett.",
         expected="200 pong",
         hint="Die Theoriekarte „Ein eigener kleiner Server“ zeigt die Reihenfolge: erst Statuscode und Länge, dann der Inhalt."),
])

POOL_HTTP = [
    mc("k34-1a", "http", 2, "Was bedeutet der Statuscode 500?",
       ["Beim Server ist ein Fehler aufgetreten", "Alles hat geklappt", "Die Adresse gibt es nicht", "Der Inhalt ist umgezogen"],
       "Codes mit einer 5 vorne melden einen Fehler beim Server selbst – etwa eine Exception in seinem "
       "Programm. Die Anfrage war womöglich völlig in Ordnung; nochmal versuchen kann später helfen.",
       why=[None,
            "Das wäre 200 – alles, was mit einer 2 beginnt, bedeutet Erfolg.",
            "Das wäre 404 – ein Fehler der Anfrage, nicht des Servers.",
            "Umzüge melden Codes mit einer 3 vorne, etwa 301."],
       hint="Die erste Ziffer verrät, wer schuld ist: 4 heißt Anfrage, 5 heißt …?",
       group="t34-1"),
    fill("k34-1b", "http", 2, "Ergänze den Statuscode, der „alles gut“ bedeutet.",
         '''
         int status = 200;
         if (status == {{0}}) {
             System.out.println("Alles gut");
         } else {
             System.out.println("Fehler " + status);
         }
         ''',
         [["200"]],
         "200 ist der Code für Erfolg. Genau diesen Vergleich macht man in echten Programmen, bevor man den "
         "Inhalt einer Antwort benutzt – bei jedem anderen Code ist der Inhalt vermutlich eine Fehlerseite.",
         hint="Schau in der Theoriekarte „Anfrage und Antwort“ nach, welcher Code für Erfolg steht.",
         verify={"output": "Alles gut"},
         group="t34-1"),
    out("k34-2a", "http", 3, "Was gibt das Programm aus?",
        '''
        HttpRequest anfrage = HttpRequest.newBuilder(URI.create("http://localhost:8080/liste")).build();
        System.out.println(anfrage.method());
        ''',
        "GET",
        "Wer keine Methode angibt, bekommt GET – die Voreinstellung zum Abholen von Daten. Für POST müsste "
        "man es ausdrücklich mit .POST(…) sagen und einen Inhalt mitgeben.",
        hint="Hier wird gar keine Methode festgelegt. Welche nimmt der Builder dann von selbst?",
        group="t34-2"),
    mc("k34-2b", "http", 3, "Welcher Aufruf macht aus einer Anfrage eine POST-Anfrage mit Inhalt?",
       [".POST(HttpRequest.BodyPublishers.ofString(json))", ".GET(json)", ".body(json)", ".send(json)"],
       "POST bekommt einen BodyPublisher, der den Inhalt liefert – mit ofString(json) ist das ein Text. "
       "Damit legt ein einziger Aufruf beides fest: die Methode und den Inhalt.",
       why=[None,
            "GET nimmt keinen Inhalt entgegen – eine GET-Anfrage holt nur etwas ab.",
            "Eine Methode body gibt es beim Bauen der Anfrage nicht; den Inhalt bekommt POST mit.",
            "send gehört zum HttpClient und schickt eine fertige Anfrage ab – bauen kann man damit nichts."],
       hint="Such die Methode, die gleichzeitig die Art der Anfrage festlegt und einen Inhalt mitnimmt.",
       group="t34-2"),
    mc("k34-3a", "http", 3, "Was liefert antwort.body(), wenn beim Senden BodyHandlers.ofString() angegeben wurde?",
       ["Den Inhalt der Antwort als Text", "Den Statuscode", "Die Adresse der Anfrage", "Die Kopfzeilen der Antwort"],
       "ofString() legt fest, dass der Inhalt als String ankommt – body() liefert ihn dann. Den Statuscode "
       "gibt es getrennt davon mit statusCode().",
       why=[None,
            "Den Statuscode liefert statusCode(), nicht body().",
            "Die Adresse steckt in der Anfrage (uri()), nicht im Inhalt der Antwort.",
            "Kopfzeilen liefert headers() – body() ist nur der eigentliche Inhalt."],
       hint="Der Name body heißt auf Deutsch „Körper“ – gemeint ist der eigentliche Hauptteil der Antwort.",
       group="t34-3"),
    out("k34-3b", "http", 4, "Was gibt das Programm aus?",
        '''
        HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
        server.createContext("/neu", austausch -> {
            byte[] text = "Angelegt".getBytes();
            austausch.sendResponseHeaders(201, text.length);
            try (OutputStream aus = austausch.getResponseBody()) {
                aus.write(text);
            }
        });
        server.start();
        String adresse = "http://localhost:" + server.getAddress().getPort() + "/neu";

        HttpClient client = HttpClient.newHttpClient();
        HttpResponse<String> antwort = client.send(HttpRequest.newBuilder(URI.create(adresse)).build(), HttpResponse.BodyHandlers.ofString());
        System.out.println(antwort.statusCode());
        System.out.println(antwort.body());
        server.stop(0);
        ''',
        '''
        201
        Angelegt
        ''',
        "Der Handler schickt Statuscode 201 – „angelegt“, ein Erfolgscode wie 200 – und den Text „Angelegt“. "
        "statusCode() und body() liefern genau das, was der Server geschickt hat.",
        hint="Lies ab, was der Handler mit sendResponseHeaders und write verschickt – genau das kommt beim Client an.",
        group="t34-3"),
    mc("k34-4a", "http", 4, "Was passiert bei client.send(…), wenn der Server mit 404 antwortet?",
       ["send liefert ganz normal eine Antwort mit statusCode() 404",
        "send wirft eine IOException",
        "send liefert null",
        "Das Programm hängt, bis es abgebrochen wird"],
       "Eine 404-Antwort ist eine ganz normale Antwort – die Verbindung hat ja geklappt. send wirft nur, wenn "
       "gar keine Antwort zustande kommt, etwa weil der Server nicht läuft. Den Statuscode muss man selbst prüfen.",
       why=[None,
            "Eine IOException gibt es nur, wenn die Verbindung selbst scheitert – eine Fehlerantwort ist trotzdem eine Antwort.",
            "send liefert nie null, sondern immer ein HttpResponse-Objekt.",
            "Der Server antwortet sofort – nur eben mit einem Fehlercode."],
       hint="Unterscheide zwei Fälle: Es kommt gar keine Antwort – oder es kommt eine Antwort, die „gibt es nicht“ sagt.",
       group="t34-4"),
    fill("k34-4b", "http", 4, "Ergänze: Erst prüfen, ob die Anfrage geklappt hat, dann den Inhalt benutzen.",
         '''
         HttpClient client = HttpClient.newHttpClient();
         HttpRequest anfrage = HttpRequest.newBuilder(URI.create("http://localhost:8080/daten")).build();
         HttpResponse<String> antwort = client.send(anfrage, HttpResponse.BodyHandlers.ofString());
         if (antwort.{{0}}() == 200) {
             System.out.println(antwort.body());
         } else {
             System.out.println("Fehler: " + antwort.statusCode());
         }
         ''',
         [["statusCode"]],
         "statusCode() verrät, ob die Antwort ein Erfolg ist. Nur bei 200 enthält body() die gewünschten Daten "
         "– bei 404 oder 500 steht dort eine Fehlerseite, die man nicht wie Daten behandeln darf.",
         hint="Gesucht ist die Methode der Antwort, die die dreistellige Zahl liefert.",
         verify={},
         group="t34-4"),
    out("k34-5a", "http", 5, "Was gibt das Programm aus?",
        '''
        HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
        server.createContext("/echo", austausch -> {
            byte[] text = ("Methode: " + austausch.getRequestMethod()).getBytes();
            austausch.sendResponseHeaders(200, text.length);
            try (OutputStream aus = austausch.getResponseBody()) {
                aus.write(text);
            }
        });
        server.start();
        String adresse = "http://localhost:" + server.getAddress().getPort() + "/echo";

        HttpClient client = HttpClient.newHttpClient();
        HttpRequest anfrage = HttpRequest.newBuilder(URI.create(adresse))
            .POST(HttpRequest.BodyPublishers.ofString("egal"))
            .build();
        System.out.println(client.send(anfrage, HttpResponse.BodyHandlers.ofString()).body());
        server.stop(0);
        ''',
        "Methode: POST",
        "Der Handler fragt mit getRequestMethod(), welche Methode die Anfrage hatte, und schickt sie als Text "
        "zurück. Der Client hat mit .POST(…) gefragt – also kommt „Methode: POST“ zurück.",
        hint="Verfolge die Anfrage: Mit welcher Methode baut der Client sie, und was schickt der Handler davon zurück?",
        group="t34-5"),
    mc("k34-5b", "http", 5, "Warum steht sendResponseHeaders im Handler vor dem Schreiben des Inhalts?",
       ["Weil zuerst Statuscode und Länge verschickt werden, erst danach der Inhalt",
        "Weil sonst der Port nicht frei wird",
        "Weil getResponseBody() sonst null liefert",
        "Die Reihenfolge ist egal"],
       "Eine HTTP-Antwort beginnt mit Statuscode und Kopfzeilen, erst danach kommt der Inhalt. "
       "sendResponseHeaders verschickt diesen Anfang – schreibt man den Inhalt vorher, meldet der Server einen Fehler.",
       why=[None,
            "Der Port hat mit der Antwort nichts zu tun – er wird beim Start des Servers vergeben.",
            "getResponseBody() liefert immer einen Strom; nur darf man erst hineinschreiben, wenn der Anfang verschickt ist.",
            "Sie ist nicht egal: HTTP verlangt erst den Anfang der Antwort, dann den Inhalt."],
       hint="Überleg, woraus eine Antwort besteht und welcher Teil zuerst beim Client ankommen muss.",
       group="t34-5"),
    mc("k34-1c", "http", 1, "Welche Methode nimmt ein Programm, das beim Server nur Daten abholen will?",
       ["GET", "POST", "SEND", "PUSH"],
       "GET heißt „gib mir“: Die Anfrage holt etwas ab und schickt selbst keinen Inhalt mit. POST ist für den "
       "umgekehrten Fall gedacht – das Programm schickt dem Server etwas, etwa neue Daten zum Speichern.",
       why=[None,
            "POST heißt „nimm das“ – damit schickt das Programm dem Server etwas, statt nur abzuholen.",
            "send ist die Methode des HttpClient, die jede fertige Anfrage losschickt – eine HTTP-Methode SEND gibt es nicht.",
            "Eine HTTP-Methode PUSH gibt es nicht."],
       hint="Die Theoriekarte „Anfrage und Antwort“ übersetzt die beiden wichtigsten Methoden ins Deutsche.",
       group="t34-1"),
    fill("k34-2c", "http", 2, "Ergänze die Methode, damit die Anfrage den JSON-Text an den Server mitschickt.",
         r"""
         HttpRequest anfrage = HttpRequest.newBuilder(URI.create("http://localhost:8080/spieler"))
             .{{0}}(HttpRequest.BodyPublishers.ofString("{\"name\": \"Tom\"}"))
             .build();
         System.out.println(anfrage.method());
         """,
         [["POST"]],
         "POST macht aus der Anfrage eine, die etwas mitschickt – den Inhalt liefert der BodyPublisher, hier den "
         "JSON-Text. Losgeschickt wird noch nichts; method() verrät nur, welche Methode im Bauplan steht.",
         hint="Gesucht ist die Methode für „nimm das“ – im Bauplan wird sie ganz in Großbuchstaben geschrieben.",
         verify={"output": "POST"},
         group="t34-2"),
    fill("k34-3c", "http", 3, "Ergänze: Ausgegeben werden sollen der Statuscode und der Inhalt der Antwort.",
         """
         HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
         server.createContext("/wetter", austausch -> {
             byte[] text = "Sonne".getBytes();
             austausch.sendResponseHeaders(200, text.length);
             try (OutputStream aus = austausch.getResponseBody()) {
                 aus.write(text);
             }
         });
         server.start();
         String adresse = "http://localhost:" + server.getAddress().getPort() + "/wetter";

         HttpClient client = HttpClient.newHttpClient();
         HttpResponse<String> antwort = client.send(HttpRequest.newBuilder(URI.create(adresse)).build(), HttpResponse.BodyHandlers.ofString());
         System.out.println(antwort.{{0}}() + ": " + antwort.{{1}}());
         server.stop(0);
         """,
         [["statusCode"], ["body"]],
         "Die Antwort hat zwei Teile, die man getrennt abfragt: statusCode() liefert die dreistellige Zahl, "
         "body() den eigentlichen Inhalt – dank BodyHandlers.ofString() als Text. Ausgegeben wird also „200: Sonne“.",
         hint="Die erste Lücke liefert die dreistellige Zahl der Antwort, die zweite ihren eigentlichen Inhalt.",
         verify={"output": "200: Sonne"},
         group="t34-3"),
    out("k34-4c", "http", 4, "Was gibt das Programm aus?",
        """
        HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
        server.createContext("/daten", austausch -> {
            byte[] text = "Kaputt".getBytes();
            austausch.sendResponseHeaders(500, text.length);
            try (OutputStream aus = austausch.getResponseBody()) {
                aus.write(text);
            }
        });
        server.start();
        String adresse = "http://localhost:" + server.getAddress().getPort() + "/daten";

        HttpClient client = HttpClient.newHttpClient();
        HttpResponse<String> antwort = client.send(HttpRequest.newBuilder(URI.create(adresse)).build(), HttpResponse.BodyHandlers.ofString());
        if (antwort.statusCode() == 200) {
            System.out.println("Daten: " + antwort.body());
        } else {
            System.out.println("Fehler " + antwort.statusCode() + ": " + antwort.body());
        }
        server.stop(0);
        """,
        "Fehler 500: Kaputt",
        "Der Server antwortet mit 500 – send wirft trotzdem keine Exception, denn eine Antwort ist ja gekommen. "
        "Weil der Statuscode nicht 200 ist, läuft der else-Zweig. Auch eine Fehlerantwort hat einen Inhalt: "
        "Hier ist es der Text „Kaputt“.",
        hint="Verfolge den Statuscode: Welcher Zweig läuft – und hat eine Fehlerantwort überhaupt einen Inhalt?",
        group="t34-4"),
    code("k34-5c", "http", 5,
         "Der Server läuft schon. Schicke eine GET-Anfrage an adresse und gib den Inhalt der Antwort aus.",
         """
         HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
         server.createContext("/name", austausch -> {
             byte[] text = "Mia".getBytes();
             austausch.sendResponseHeaders(200, text.length);
             try (OutputStream aus = austausch.getResponseBody()) {
                 aus.write(text);
             }
         });
         server.start();
         String adresse = "http://localhost:" + server.getAddress().getPort() + "/name";
         // Anfrage hier schicken und den Inhalt ausgeben

         server.stop(0);
         """,
         """
         HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
         server.createContext("/name", austausch -> {
             byte[] text = "Mia".getBytes();
             austausch.sendResponseHeaders(200, text.length);
             try (OutputStream aus = austausch.getResponseBody()) {
                 aus.write(text);
             }
         });
         server.start();
         String adresse = "http://localhost:" + server.getAddress().getPort() + "/name";
         HttpClient client = HttpClient.newHttpClient();
         HttpRequest anfrage = HttpRequest.newBuilder(URI.create(adresse)).build();
         HttpResponse<String> antwort = client.send(anfrage, HttpResponse.BodyHandlers.ofString());
         System.out.println(antwort.body());

         server.stop(0);
         """,
         [req(r"HttpClient\.newHttpClient\s*\(\s*\)", "Hol dir mit HttpClient.newHttpClient() einen Client, der Anfragen verschickt."),
          req(r"URI\.create\s*\(\s*adresse\s*\)", "Baue die Anfrage mit HttpRequest.newBuilder(URI.create(adresse))."),
          req(r"\.send\s*\(", "Schicke die Anfrage mit client.send(…) los."),
          req(r"BodyHandlers\.ofString\s*\(\s*\)", "Gib send mit HttpResponse.BodyHandlers.ofString() mit, damit der Inhalt als Text ankommt."),
          req(r"\.body\s*\(\s*\)", "Gib den Inhalt der Antwort mit body() aus.")],
         "Drei Schritte, die bei jeder Anfrage gleich sind: einen HttpClient holen, die Anfrage für die Adresse "
         "bauen (ohne Angabe ist sie eine GET-Anfrage) und mit send abschicken. BodyHandlers.ofString() macht den "
         "Inhalt zu Text, body() liefert ihn – hier „Mia“.",
         expected="Mia",
         hint="Die Theoriekarte „Anfrage senden, Antwort lesen“ zeigt die Schritte: Client holen, Anfrage bauen, senden, Inhalt lesen.",
         group="t34-5"),
]

# ================================================================ Datenbanken
l35 = lesson("l35-database", "Datenbanken mit JDBC", "Daten dauerhaft in Tabellen ablegen und sicher abfragen.",
             ["database"], 10, [
    card("Tabellen und SQL",
         "Eine Datenbank speichert Daten in Tabellen – Zeilen sind Einträge, Spalten ihre Eigenschaften. "
         "Gesprochen wird mit ihr in SQL: SELECT liest Zeilen, INSERT fügt welche hinzu, UPDATE ändert, "
         "DELETE löscht. Mit WHERE wählst du nur passende Zeilen aus, mit ORDER BY sortierst du. In Java "
         "steht SQL einfach als Text – ein Textblock macht es gut lesbar.",
         code='''
         String abfrage = """
             SELECT name, punkte
             FROM spieler
             WHERE punkte > 100
             ORDER BY punkte DESC
             """;
         System.out.println(abfrage.lines().count());
         ''',
         tip="SQL-Wörter schreibt man üblicherweise GROSS – Pflicht ist das nicht, aber es liest sich leichter.",
         verify={"output": "4"}),
    card("JDBC: Verbindung, Abfrage, Ergebnis",
         "JDBC ist die Schnittstelle des JDK zu Datenbanken. DriverManager.getConnection öffnet die Verbindung, "
         "prepareStatement bereitet eine Abfrage vor, executeQuery führt sie aus und liefert ein ResultSet – "
         "eine Tabelle, die du Zeile für Zeile durchgehst. try-with-resources schließt die Verbindung am Ende "
         "von selbst.",
         code='''
         try (Connection db = DriverManager.getConnection("jdbc:sqlite:spiel.db")) {
             PreparedStatement abfrage = db.prepareStatement("SELECT name FROM spieler WHERE punkte > ?");
             abfrage.setInt(1, 100);
             ResultSet zeilen = abfrage.executeQuery();
             while (zeilen.next()) {
                 System.out.println(zeilen.getString("name"));
             }
         }
         ''',
         info="Zum Ausführen braucht es einen Treiber für die jeweilige Datenbank, etwa sqlite-jdbc oder H2 – "
              "das JDK bringt nur die Schnittstelle mit. JavaQuest prüft bei allen Datenbank-Beispielen, dass "
              "sie übersetzen, führt sie aber nicht aus.",
         verify={"context": "statements"}),
    card("Werte nie in SQL kleben: PreparedStatement",
         "Klebt man eine Eingabe direkt in den SQL-Text, kann sie selbst zu SQL werden: Aus dem Namen "
         "x' OR '1'='1 wird eine Bedingung, die immer stimmt – und plötzlich liefert die Abfrage alle "
         "Einträge. Das heißt SQL-Injection. Mit Fragezeichen als Platzhaltern und setString übergibst du "
         "Werte getrennt vom SQL; die Datenbank behandelt sie dann immer nur als Wert.",
         code='''
         String name = "x' OR '1'='1";
         String gefaehrlich = "SELECT * FROM nutzer WHERE name = '" + name + "'";
         System.out.println(gefaehrlich);
         ''',
         warning="Nimm für Werte immer ? mit setString bzw. setInt – auch wenn die Eingabe harmlos aussieht.",
         verify={"output": "SELECT * FROM nutzer WHERE name = 'x' OR '1'='1'"}),
], [
    mc("t35-1", "database", 1, "Welcher SQL-Befehl liest Daten aus einer Tabelle?",
       ["SELECT", "INSERT", "DELETE", "UPDATE"],
       "SELECT wählt Zeilen und Spalten aus und liefert sie zurück, ohne etwas zu verändern. Die anderen drei "
       "verändern die Tabelle: INSERT fügt hinzu, UPDATE ändert, DELETE löscht.",
       why=[None,
            "INSERT fügt neue Zeilen hinzu, statt welche zu lesen.",
            "DELETE löscht Zeilen – danach sind sie weg.",
            "UPDATE ändert Zeilen, die schon da sind."],
       hint="Die Theoriekarte „Tabellen und SQL“ nennt vier Befehle und was jeder davon tut."),
    out("t35-2", "database", 2, "Was gibt das Programm aus?",
        '''
        String eingabe = "' OR 1=1 --";
        String sql = "SELECT * FROM konto WHERE name = '" + eingabe + "'";
        System.out.println(sql);
        ''',
        "SELECT * FROM konto WHERE name = '' OR 1=1 --'",
        "Die Eingabe wird wörtlich in den SQL-Text geklebt. Ihr erstes Anführungszeichen beendet den Namen, "
        "OR 1=1 ist eine Bedingung, die immer stimmt, und -- macht den Rest zum Kommentar. Die Datenbank "
        "würde alle Konten liefern – genau das ist SQL-Injection.",
        hint="Setz die Eingabe Zeichen für Zeichen an ihre Stelle ein – der Code prüft nicht, was drinsteht."),
    fill("t35-3", "database", 3, "Ergänze: Der erste Platzhalter bekommt den Namen, der zweite die Punktzahl.",
         '''
         try (Connection db = DriverManager.getConnection("jdbc:sqlite:spiel.db")) {
             PreparedStatement neu = db.prepareStatement("INSERT INTO spieler (name, punkte) VALUES (?, ?)");
             neu.setString({{0}}, "Mia");
             neu.setInt({{1}}, 120);
             neu.executeUpdate();
         }
         ''',
         [["1"], ["2"]],
         "Die Fragezeichen werden ab 1 durchgezählt – anders als Arrays und Listen, die bei 0 anfangen. "
         "setString(1, …) füllt also das erste ?, setInt(2, …) das zweite. executeUpdate führt das INSERT dann aus.",
         hint="Zähl die Fragezeichen im SQL-Text – aber Achtung: Wo fängt JDBC mit dem Zählen an?",
         verify={}),
    mc("t35-4", "database", 4, "Warum steht vor dem ersten zeilen.getString(…) ein zeilen.next()?",
       ["Weil das ResultSet anfangs vor der ersten Zeile steht",
        "Weil next() die Abfrage erst ausführt",
        "Weil getString sonst die letzte Zeile liefert",
        "Weil next() die Verbindung öffnet"],
       "Ein frisches ResultSet zeigt noch auf keine Zeile, sondern davor. next() rückt eine Zeile weiter und "
       "sagt dabei, ob es sie gibt (true) – erst dann kann getString etwas lesen.",
       why=[None,
            "Ausgeführt hat die Abfrage schon executeQuery – next() blättert nur im Ergebnis.",
            "Ohne next() gibt es gar keine aktuelle Zeile; getString wirft dann eine SQLException.",
            "Die Verbindung öffnet DriverManager.getConnection – lange vor dem Ergebnis."],
       hint="Stell dir das ResultSet wie ein Lesezeichen vor: Wo steht es direkt nach executeQuery?"),
    code("t35-5", "database", 5,
         "Schreibe die Methode punkteVon: Sie holt per PreparedStatement die Punktzahl des Spielers und gibt "
         "sie zurück – oder 0, wenn es ihn nicht gibt.",
         '''
         static int punkteVon(Connection db, String name) throws SQLException {
             // Abfrage hier
             return 0;
         }
         ''',
         '''
         static int punkteVon(Connection db, String name) throws SQLException {
             PreparedStatement abfrage = db.prepareStatement("SELECT punkte FROM spieler WHERE name = ?");
             abfrage.setString(1, name);
             ResultSet zeilen = abfrage.executeQuery();
             if (zeilen.next()) {
                 return zeilen.getInt("punkte");
             }
             return 0;
         }
         ''',
         [req(r"prepareStatement\s*\(", "Bereite die Abfrage mit db.prepareStatement(…) vor."),
          req(r"=\s*\?", "Nimm ein ? als Platzhalter für den Namen.", scope="raw"),
          req(r"setString\s*\(\s*1\s*,\s*name\s*\)", "Fülle das ? mit setString(1, name)."),
          req(r"executeQuery\s*\(\s*\)", "Führe die Abfrage mit executeQuery() aus."),
          req(r"\.next\s*\(\s*\)", "Rücke mit next() auf die erste Zeile vor – vorher steht das Ergebnis davor."),
          req(r"getInt\s*\(", "Lies die Punkte mit getInt(…)."),
          forbid(r"'\s*\"\s*\+\s*name|name\s*\+\s*\"\s*'", "Klebe den Namen nicht in den SQL-Text – dafür ist das ? da.", scope="raw")],
         "Vier Schritte: vorbereiten mit ?, den Namen mit setString(1, name) einsetzen, ausführen – und vor dem "
         "Lesen mit next() auf die erste Zeile rücken. Liefert next() false, gibt es den Spieler nicht, und die "
         "Methode gibt 0 zurück.",
         hint="Vier Schritte: vorbereiten, einsetzen, ausführen – und vor dem Lesen auf die erste Zeile vorrücken.",
         ctx="members"),
])

POOL_DATENBANK = [
    mc("k35-1a", "database", 2, "Welcher SQL-Befehl fügt eine neue Zeile hinzu?",
       ["INSERT", "SELECT", "UPDATE", "ADD"],
       "INSERT INTO tabelle (spalten) VALUES (werte) legt eine neue Zeile an. UPDATE ändert dagegen Zeilen, "
       "die es schon gibt, und SELECT liest nur.",
       why=[None,
            "SELECT liest nur – es verändert nichts.",
            "UPDATE ändert Zeilen, die schon da sind; eine neue legt es nicht an.",
            "Einen Befehl ADD gibt es in SQL nicht."],
       hint="Die Theoriekarte „Tabellen und SQL“ ordnet jedem der vier Befehle zu, was er tut.",
       group="t35-1"),
    fill("k35-1b", "database", 2, "Ergänze den SQL-Befehl, der Namen und Punkte liest.",
         '''
         String sql = "{{0}} name, punkte FROM spieler WHERE punkte > 100";
         System.out.println(sql);
         ''',
         [["SELECT", "select"]],
         "SELECT nennt die Spalten, die man haben will, FROM die Tabelle und WHERE die Bedingung. So liest die "
         "Abfrage Namen und Punkte aller Spieler mit mehr als 100 Punkten.",
         hint="Gesucht ist der Befehl, der Daten liest, ohne etwas zu verändern.",
         verify={"output": "SELECT name, punkte FROM spieler WHERE punkte > 100"},
         group="t35-1"),
    mc("k35-2a", "database", 3, "Warum schützt ein PreparedStatement mit ? vor SQL-Injection?",
       ["Weil der Wert getrennt vom SQL übergeben und nie als SQL gelesen wird",
        "Weil es gefährliche Wörter wie OR aus der Eingabe löscht",
        "Weil es die Eingabe in Großbuchstaben umwandelt",
        "Weil es nur Zahlen als Eingabe erlaubt"],
       "Beim PreparedStatement steht das SQL fest, bevor ein Wert dazukommt. setString liefert den Wert "
       "getrennt – die Datenbank behandelt ihn immer als Wert, egal ob Anführungszeichen oder OR darin stehen.",
       why=[None,
            "Es löscht nichts aus der Eingabe – der Name x' OR '1'='1 bleibt genau so, er wird nur als Wert behandelt.",
            "Groß- und Kleinschreibung spielt dabei keine Rolle; die Eingabe bleibt unverändert.",
            "Texte sind genauso erlaubt – mit setString statt setInt."],
       hint="Überleg, wann die Datenbank das SQL liest – vor oder nach dem Einsetzen des Werts?",
       group="t35-2"),
    fill("k35-2b", "database", 3, "Ergänze den Platzhalter, über den der Name später sicher eingesetzt wird.",
         '''
         String sql = "SELECT * FROM konto WHERE name = {{0}}";
         System.out.println(sql);
         ''',
         [["?"]],
         "Das Fragezeichen hält den Platz für einen Wert frei, der erst später mit setString dazukommt. Ohne "
         "Anführungszeichen drumherum – die setzt die Datenbank selbst richtig.",
         hint="Gesucht ist das Zeichen, das in einem PreparedStatement für einen Wert steht, der erst später kommt.",
         verify={"output": "SELECT * FROM konto WHERE name = ?"},
         group="t35-2"),
    mc("k35-3a", "database", 3, 'Welcher Aufruf füllt das erste Fragezeichen in "... WHERE name = ?" mit dem Namen?',
       ["setString(1, name)", "setString(0, name)", "setName(name)", "set(name)"],
       "Die Methode richtet sich nach dem Typ des Werts – für Text setString –, die Zahl nach der Position des "
       "Fragezeichens, gezählt ab 1.",
       why=[None,
            "Die Platzhalter werden ab 1 gezählt – eine 0 führt zu einer SQLException.",
            "Eine Methode setName gibt es nicht: Welcher Platzhalter gemeint ist, sagt die Nummer, nicht der Spaltenname.",
            "Es muss klar sein, welches Fragezeichen gemeint ist und welcher Typ – deshalb setString mit Nummer."],
       hint="Die Methode richtet sich nach dem Typ des Werts – und die Nummer nach der Position des Fragezeichens.",
       group="t35-3"),
    code("k35-3b", "database", 4,
         "Lösche den Spieler „Tom“ mit dem SQL „DELETE FROM spieler WHERE name = ?“ – per PreparedStatement, "
         "ohne den Namen in den SQL-Text zu kleben.",
         '''
         try (Connection db = DriverManager.getConnection("jdbc:sqlite:spiel.db")) {
             // Spieler "Tom" per PreparedStatement löschen
         }
         ''',
         '''
         try (Connection db = DriverManager.getConnection("jdbc:sqlite:spiel.db")) {
             PreparedStatement weg = db.prepareStatement("DELETE FROM spieler WHERE name = ?");
             weg.setString(1, "Tom");
             weg.executeUpdate();
         }
         ''',
         [req(r"prepareStatement\s*\(", "Bereite das SQL mit db.prepareStatement(…) vor."),
          req(r"DELETE\s+FROM\s+spieler\s+WHERE\s+name\s*=\s*\?", "Das SQL braucht ein ? für den Namen: DELETE FROM spieler WHERE name = ?", scope="raw"),
          req(r'setString\s*\(\s*1\s*,\s*"Tom"\s*\)', 'Fülle das ? mit setString(1, "Tom").', scope="raw"),
          req(r"executeUpdate\s*\(\s*\)", "Führe das DELETE mit executeUpdate() aus – executeQuery ist nur zum Lesen.")],
         "prepareStatement legt das SQL mit einem ? fest, setString(1, \"Tom\") setzt den Namen getrennt ein, und "
         "executeUpdate führt das DELETE aus. executeQuery wäre falsch: Es ist für Abfragen, die Zeilen liefern.",
         hint="Wie beim Lesen: vorbereiten mit ?, einsetzen – nur ausgeführt wird ein DELETE mit einer anderen Methode als ein SELECT.",
         group="t35-3"),
    fill("k35-4a", "database", 4, "Ergänze: Zeile für Zeile vorrücken und jeweils den Namen lesen.",
         '''
         try (Connection db = DriverManager.getConnection("jdbc:sqlite:spiel.db")) {
             ResultSet zeilen = db.prepareStatement("SELECT name FROM spieler").executeQuery();
             while (zeilen.{{0}}()) {
                 System.out.println(zeilen.{{1}}("name"));
             }
         }
         ''',
         [["next"], ["getString"]],
         "next() rückt eine Zeile weiter und liefert false, wenn keine mehr kommt – deshalb passt es genau in "
         "die while-Bedingung. getString(\"name\") liest aus der aktuellen Zeile die Spalte name.",
         hint="Die erste Lücke rückt vor und sagt, ob es noch eine Zeile gibt; die zweite liest einen Text aus einer Spalte.",
         verify={},
         group="t35-4"),
    mc("k35-4b", "database", 5, "Eine Abfrage findet keine einzige Zeile. Was passiert bei while (zeilen.next()) { … }?",
       ["Die Schleife läuft kein einziges Mal",
        "next() wirft eine Exception",
        "Die Schleife läuft einmal mit leeren Werten",
        "Das Programm hängt"],
       "next() liefert schon beim ersten Aufruf false, weil es keine Zeile gibt, zu der es vorrücken könnte. Die "
       "Bedingung ist also sofort falsch, und die Schleife wird übersprungen – ganz ohne Fehler.",
       why=[None,
            "Ein leeres Ergebnis ist kein Fehler – next() antwortet einfach mit false.",
            "Es gibt keine Zeile, also auch keinen Durchlauf mit leeren Werten.",
            "next() wartet auf nichts: Das Ergebnis liegt schon vollständig vor."],
       hint="Was liefert next(), wenn es keine Zeile gibt, zu der es vorrücken kann?",
       group="t35-4"),
    mc("k35-5a", "database", 5, "Welche Variante liest die Punkte eines Spielers sicher?",
       ['prepareStatement("SELECT punkte FROM spieler WHERE name = ?"), dann setString(1, name)',
        'prepareStatement("SELECT punkte FROM spieler WHERE name = \'" + name + "\'")',
        'prepareStatement("SELECT punkte FROM spieler WHERE name = ?") ohne setString',
        'prepareStatement("SELECT punkte FROM spieler WHERE name = name")'],
       "Nur mit ? und setString bleibt der Name ein Wert. Wer ihn in den SQL-Text klebt, öffnet die Tür für "
       "SQL-Injection – ein PreparedStatement allein schützt nicht, wenn man es trotzdem mit + zusammensetzt.",
       why=[None,
            "Hier wird der Name in den SQL-Text geklebt – trotz prepareStatement ist das SQL-Injection-anfällig.",
            "Ohne setString bleibt das ? leer; die Datenbank meldet beim Ausführen einen Fehler.",
            "name = name vergleicht die Spalte mit sich selbst – das stimmt für jede Zeile, nicht nur für einen Spieler."],
       hint="Achte darauf, wie der Name in die Abfrage kommt: als Teil des Textes oder getrennt davon?",
       group="t35-5"),
    fill("k35-5b", "database", 5, "Ergänze den Typ der Abfrage, die try-with-resources am Ende von selbst schließt.",
         '''
         static int anzahl(Connection db) throws SQLException {
             try ({{0}} abfrage = db.prepareStatement("SELECT COUNT(*) FROM spieler")) {
                 ResultSet zeilen = abfrage.executeQuery();
                 zeilen.next();
                 return zeilen.getInt(1);
             }
         }
         ''',
         [["PreparedStatement", "var"]],
         "prepareStatement liefert ein PreparedStatement. In den Klammern hinter try schließt Java es am Ende "
         "von selbst – auch wenn unterwegs eine Exception auftritt. COUNT(*) liefert genau eine Zeile mit einer Zahl.",
         hint="Gesucht ist der Typ, den db.prepareStatement(…) zurückgibt.",
         ctx="members",
         verify={},
         group="t35-5"),
    mc("k35-1c", "database", 1, "Womit wählt eine SQL-Abfrage nur bestimmte Zeilen aus – etwa alle mit mehr als 100 Punkten?",
       ["WHERE", "ORDER BY", "FROM", "INTO"],
       "WHERE nennt eine Bedingung; nur Zeilen, für die sie stimmt, kommen ins Ergebnis. FROM sagt, aus welcher "
       "Tabelle gelesen wird, und ORDER BY sortiert das, was WHERE übrig gelassen hat.",
       why=[None,
            "ORDER BY sortiert nur – es lässt alle Zeilen im Ergebnis und ändert bloß die Reihenfolge.",
            "FROM nennt die Tabelle, aus der gelesen wird, aber keine Bedingung für die Zeilen.",
            "INTO gehört zu INSERT und sagt, in welche Tabelle eine neue Zeile kommt."],
       hint="Die Theoriekarte „Tabellen und SQL“ nennt ein Wort zum Auswählen und eins zum Sortieren.",
       group="t35-1"),
    out("k35-2c", "database", 3, "Was gibt das Programm aus?",
        """
        String name = "O'Brien";
        String sql = "SELECT * FROM spieler WHERE name = '" + name + "'";
        System.out.println(sql);
        """,
        "SELECT * FROM spieler WHERE name = 'O'Brien'",
        "Der Name wird Zeichen für Zeichen eingeklebt. Für die Datenbank endet der Text aber schon nach O – der "
        "Apostroph im Namen schließt ihn. Übrig bleibt Brien' als ungültiges SQL, und die Abfrage scheitert. Nicht "
        "nur Angriffe, auch ganz normale Namen brechen zusammengeklebtes SQL; mit ? und setString passiert das nicht.",
        hint="Setz den Namen Zeichen für Zeichen ein und zähl danach die einfachen Anführungszeichen in der Zeile.",
        group="t35-2"),
    fill("k35-3c", "database", 3, "Ergänze: Das erste Fragezeichen bekommt die Punktzahl, das zweite den Namen.",
         """
         try (Connection db = DriverManager.getConnection("jdbc:sqlite:spiel.db")) {
             PreparedStatement neu = db.prepareStatement("UPDATE spieler SET punkte = ? WHERE name = ?");
             neu.{{0}}(1, 150);
             neu.{{1}}(2, "Mia");
             neu.executeUpdate();
         }
         """,
         [["setInt"], ["setString"]],
         "Welche set-Methode passt, entscheidet der Typ des Werts: 150 ist eine ganze Zahl, also setInt; „Mia“ ist "
         "Text, also setString. Die Nummer davor sagt, welches Fragezeichen gemeint ist – gezählt ab 1.",
         hint="Die Methode richtet sich nach dem Typ des Werts: eine ganze Zahl für das erste Fragezeichen, ein Text für das zweite.",
         verify={},
         group="t35-3"),
    mc("k35-4c", "database", 4, "Eine Abfrage liefert drei Zeilen. Wie oft gibt zeilen.next() in while (zeilen.next()) { … } true zurück?",
       ["Dreimal – der vierte Aufruf liefert false",
        "Viermal",
        "Zweimal – die erste Zeile ist schon ausgewählt",
        "Einmal – danach steht das Ergebnis am Ende"],
       "Jeder Aufruf rückt eine Zeile weiter: zur ersten, zur zweiten, zur dritten – jedes Mal true. Der vierte "
       "Aufruf findet keine Zeile mehr, liefert false und beendet die Schleife. next() läuft also viermal, aber nur "
       "dreimal mit true.",
       why=[None,
            "Es gibt nur drei Zeilen, zu denen next() vorrücken kann – der vierte Aufruf findet keine mehr.",
            "Anfangs steht das Ergebnis vor der ersten Zeile; erst der erste next()-Aufruf wählt sie aus.",
            "next() rückt jedes Mal nur eine einzige Zeile weiter, nicht gleich ans Ende."],
       hint="Zähl mit: Wo steht das Ergebnis vor dem ersten Aufruf, und wohin rückt jeder Aufruf?",
       group="t35-4"),
    code("k35-5c", "database", 5,
         "Schreibe die Methode neuerSpieler: Sie legt mit dem SQL „INSERT INTO spieler (name, punkte) VALUES (?, ?)“ "
         "einen Spieler an – per PreparedStatement, ohne die Werte in den SQL-Text zu kleben.",
         """
         static void neuerSpieler(Connection db, String name, int punkte) throws SQLException {
             // Einfügen hier
         }
         """,
         """
         static void neuerSpieler(Connection db, String name, int punkte) throws SQLException {
             PreparedStatement neu = db.prepareStatement("INSERT INTO spieler (name, punkte) VALUES (?, ?)");
             neu.setString(1, name);
             neu.setInt(2, punkte);
             neu.executeUpdate();
         }
         """,
         [req(r"prepareStatement\s*\(", "Bereite das SQL mit db.prepareStatement(…) vor."),
          req(r"INSERT\s+INTO\s+spieler\s*\(\s*name\s*,\s*punkte\s*\)\s*VALUES\s*\(\s*\?\s*,\s*\?\s*\)",
              "Das SQL braucht zwei Platzhalter: INSERT INTO spieler (name, punkte) VALUES (?, ?)", scope="raw"),
          req(r"setString\s*\(\s*1\s*,\s*name\s*\)", "Fülle das erste ? mit setString(1, name)."),
          req(r"setInt\s*\(\s*2\s*,\s*punkte\s*\)", "Fülle das zweite ? mit setInt(2, punkte)."),
          req(r"executeUpdate\s*\(\s*\)", "Führe das INSERT mit executeUpdate() aus – executeQuery ist nur zum Lesen."),
          forbid(r'"\s*\+\s*(?:name|punkte)\b|\b(?:name|punkte)\s*\+\s*"', "Klebe die Werte nicht in den SQL-Text – dafür sind die ? da.", scope="raw")],
         "Das SQL steht mit zwei Fragezeichen fest, bevor ein Wert dazukommt. setString(1, name) und setInt(2, punkte) "
         "liefern die Werte getrennt – die Datenbank liest sie nie als SQL. executeUpdate führt das INSERT aus, weil "
         "es keine Zeilen zurückliefert.",
         hint="Wie beim Löschen: vorbereiten mit Platzhaltern, jeden Wert mit der passenden set-Methode einsetzen, dann ausführen.",
         ctx="members",
         group="t35-5"),
]

PRAXIS_MODULE = {"id": "m14-practice", "title": "Java in der Praxis", "subtitle": "JSON, HTTP und Datenbanken",
                 "tier": "advanced", "symbol": "network", "lessons": [l33, l34, l35]}
POOL_PRAXIS = POOL_JSON + POOL_HTTP + POOL_DATENBANK

PRAXIS_IRRTUM = {
    "l33-json": (
        "Der häufigste Irrtum",
        "„JSON ist doch einfach JavaScript.“ Fast – aber strenger. Schlüssel stehen immer in doppelten "
        "Anführungszeichen, einfache sind nicht erlaubt. Nach dem letzten Eintrag steht kein Komma, und "
        "Kommentare gibt es gar nicht. Ein einziges falsches Zeichen, und das empfangende Programm lehnt den "
        "ganzen Text ab. Wer JSON von Hand baut, prüft es deshalb am besten – oder lässt es gleich von einer "
        "Bibliothek erzeugen.",
        "warning", "Häufigster Fehler beim Selberbauen: ein Komma nach dem letzten Eintrag.",
    ),
    "l34-http": (
        "Der häufigste Irrtum",
        "„Wenn die Seite nicht existiert, gibt es eine Exception.“ Nein: send wirft nur, wenn die Verbindung "
        "selbst scheitert – etwa weil der Server nicht läuft. Ein 404 oder 500 ist eine ganz normale Antwort "
        "mit einem anderen Statuscode. Wer body() liest, ohne vorher statusCode() zu prüfen, verarbeitet "
        "womöglich eine Fehlerseite, als wären es die gewünschten Daten.",
        "warning", "Erst statusCode() prüfen, dann body() benutzen.",
    ),
    "l35-database": (
        "Der häufigste Irrtum",
        "„Das ResultSet zeigt schon auf die erste Zeile.“ Nein: Anfangs steht es davor. Erst next() rückt auf "
        "die erste Zeile vor und sagt dabei, ob es überhaupt eine gibt. Wer gleich getString aufruft, bekommt "
        "eine SQLException. Die zweite Falle: Die Platzhalter ? werden ab 1 gezählt, nicht ab 0 wie Arrays "
        "und Listen.",
        "warning", "Erst next(), dann lesen – und setString(1, …) für das erste Fragezeichen.",
    ),
}

# ---------------------------------------------------------------- gleichwertige Lösungen
PRAXIS_GLEICHWERTIG = {
    "t33-5": [r'''record Buch(String titel, int seiten) {
    String toJson() {
        return "{\"titel\": \"" + titel + "\", \"seiten\": " + seiten + "}";
    }
}

public class Main {
    public static void main(String[] args) {
        System.out.println(new Buch("Momo", 304).toJson());
    }
}'''],
    "t34-5": ['''HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
server.createContext("/ping", ex -> {
    byte[] antwortText = "pong".getBytes();
    ex.sendResponseHeaders(200, antwortText.length);
    ex.getResponseBody().write(antwortText);
    ex.close();
});

server.start();
String adresse = "http://localhost:" + server.getAddress().getPort() + "/ping";
HttpClient client = HttpClient.newHttpClient();
HttpResponse<String> antwort = client.send(HttpRequest.newBuilder(URI.create(adresse)).build(), HttpResponse.BodyHandlers.ofString());
System.out.println(antwort.statusCode() + " " + antwort.body());
server.stop(0);'''],
    "t35-5": ['''static int punkteVon(Connection db, String name) throws SQLException {
    try (PreparedStatement abfrage = db.prepareStatement("SELECT punkte FROM spieler WHERE name = ?")) {
        abfrage.setString(1, name);
        try (ResultSet zeilen = abfrage.executeQuery()) {
            return zeilen.next() ? zeilen.getInt("punkte") : 0;
        }
    }
}'''],
    "k33-5c": [r"""record Aufgabe(String titel, boolean erledigt) {
    String toJson() {
        return String.format("{\"titel\": \"%s\", \"erledigt\": %s}", titel, erledigt);
    }
}

public class Main {
    public static void main(String[] args) {
        System.out.println(new Aufgabe("Lernen", false).toJson());
    }
}"""],
    "k34-5c": ["""HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
server.createContext("/name", austausch -> {
    byte[] text = "Mia".getBytes();
    austausch.sendResponseHeaders(200, text.length);
    try (OutputStream aus = austausch.getResponseBody()) {
        aus.write(text);
    }
});
server.start();
String adresse = "http://localhost:" + server.getAddress().getPort() + "/name";
System.out.println(HttpClient.newHttpClient()
    .send(HttpRequest.newBuilder(URI.create(adresse)).GET().build(), HttpResponse.BodyHandlers.ofString())
    .body());

server.stop(0);"""],
    "k35-5c": ["""static void neuerSpieler(Connection db, String name, int punkte) throws SQLException {
    try (PreparedStatement neu = db.prepareStatement("INSERT INTO spieler (name, punkte) VALUES (?, ?)")) {
        neu.setString(1, name);
        neu.setInt(2, punkte);
        neu.executeUpdate();
    }
}"""],
    "k35-3b": ['''try (Connection db = DriverManager.getConnection("jdbc:sqlite:spiel.db");
     PreparedStatement weg = db.prepareStatement("DELETE FROM spieler WHERE name = ?")) {
    weg.setString(1, "Tom");
    int geloescht = weg.executeUpdate();
}'''],
}
