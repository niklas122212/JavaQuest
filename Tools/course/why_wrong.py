"""Warum die gewählte Antwort nicht stimmt.

Wer eine Multiple-Choice-Frage falsch beantwortet, soll nicht nur „falsch“ lesen,
sondern erfahren, welcher Denkfehler dahintersteckt.

Zugeordnet wird über den **Antworttext**, nicht über die Position: Die Antworten
werden beim Erzeugen gedreht, damit die richtige nicht immer vorne steht. Eine
Zuordnung über Positionen ginge dabei schief. Passt ein Text nicht mehr zur Aufgabe,
bricht der Kursbau ab – so fällt jede Umformulierung sofort auf.
"""

WHY_WRONG = {
    # --- Modul 1: Erste Schritte
    "t01-1": {
        "In der ersten Zeile der Datei":
            "Java liest die Datei zwar von oben nach unten, startet aber nicht dort. Gesucht wird immer "
            "zuerst die Methode main – erst dort beginnt die Ausführung.",
        "In einer Methode namens start":
            "Der Name start hat für Java keine besondere Bedeutung. Nur main mit genau dieser Schreibweise "
            "ist der Startknopf.",
        "Im Konstruktor der Klasse":
            "Ein Konstruktor läuft erst, wenn jemand mit new ein Objekt erzeugt. Beim Programmstart "
            "passiert das noch gar nicht.",
    },
    "t01-2": {
        "Mit einem Doppelpunkt :":
            "Der Doppelpunkt kommt in Java nur an wenigen Stellen vor, etwa in der for-each-Schleife. "
            "Eine normale Anweisung endet damit nicht.",
        "Mit einem Zeilenumbruch":
            "Zeilenumbrüche sind für Java reine Optik – man könnte das ganze Programm in eine Zeile "
            "schreiben. Den Satz beendet erst das Semikolon.",
        "Mit einem Punkt .":
            "Der Punkt trennt ein Objekt von seiner Methode (System.out.println). Als Satzzeichen am "
            "Ende dient er nicht.",
    },

    # --- Modul 1: Variablen
    "t02-1": {
        "boolean": "boolean kennt nur zwei Werte: true und false. Zahlen passen dort nicht hinein.",
        "double": "double speichert zwar Zahlen, aber mit Nachkommastellen. Für ganze Zahlen ist int die passende Box.",
        "String": "String ist für Text. „5“ in Anführungszeichen wäre Text, mit dem sich nicht rechnen lässt.",
    },
    "t02-4": {
        "long l = 100;": "long fasst sogar größere Zahlen als int – 100 passt problemlos hinein.",
        'var text = "Hi";': "Mit var klebt Java das passende Etikett selbst drauf, hier String. Das ist erlaubt.",
        "double d = 5;": "Eine ganze Zahl passt immer in eine double-Box: Java erweitert sie automatisch zu 5.0.",
    },

    # --- Modul 1: Operatoren
    "t03-1": {
        "2.33": "2,33 wäre das Ergebnis von 7 geteilt durch 3. Das Zeichen % fragt aber nicht nach dem "
                "Ergebnis, sondern nach dem Rest.",
        "0": "0 käme heraus, wenn 7 ohne Rest durch 3 teilbar wäre. 3 passt aber nur zweimal hinein, "
             "eins bleibt übrig.",
        "2": "2 ist, wie oft die 3 in die 7 passt – also das Ergebnis der Ganzzahldivision 7 / 3. "
             "Der Rest ist dagegen 1.",
    },

    # --- Modul 2: Kontrollfluss
    "t04-1": {
        "Ein String": 'Ein Text ist keine Ja-Nein-Frage. Java kann mit "Hallo" nicht entscheiden, ob der '
                      "Block laufen soll.",
        "Der Name einer Methode":
            "Ein Methodenname allein sagt nichts aus. Erst das Ergebnis eines Aufrufs kann true oder "
            "false sein – dann gehört auch das Klammernpaar dazu.",
        "Eine beliebige Zahl":
            "Anders als in manchen anderen Sprachen gilt in Java keine Zahl als „wahr“. if verlangt "
            "ausdrücklich einen Wahrheitswert.",
    },
    "t05-1": {
        "Endlos": "Endlos liefe die Schleife nur, wenn der Zähler nie wächst oder die Bedingung immer "
                  "wahr bleibt. Hier zählt i++ jede Runde hoch.",
        "2-mal": "Bei 2-mal würde man das Ende zu früh ansetzen. i nimmt die Werte 0, 1 und 2 an – "
                 "das sind drei Runden.",
        "4-mal": "4-mal wäre richtig bei i <= 3. Mit i < 3 ist bei der 3 Schluss, sie führt zu keiner "
                 "Runde mehr.",
    },
    "t06-1": {
        "Die Methode gibt 0 zurück":
            "0 zurückgeben könnte nur eine Methode mit Rückgabetyp int. Bei void kommt gar nichts zurück.",
        "Die Methode ist leer":
            "Eine void-Methode darf durchaus etwas tun – zum Beispiel etwas ausgeben. Sie liefert nur "
            "kein Ergebnis an die aufrufende Stelle.",
        "Die Methode ist privat":
            "Ob eine Methode privat ist, regelt private. void sagt nur etwas über das Ergebnis aus.",
    },
    "t06-4": {
        "Die Variante mit (String name)":
            "Die Variante mit nur einem Namen passt nicht: Beim Aufruf stehen zwei Zutaten in den "
            "Klammern, ein Text und eine Zahl.",
        "Beide nacheinander":
            "Java führt immer genau eine Variante aus – nämlich die, deren Zutatenliste passt.",
        "Keine – der Code kompiliert nicht":
            "Der Code ist gültig. Mehrere Methoden dürfen denselben Namen tragen, solange sich ihre "
            "Zutaten unterscheiden.",
    },

    # --- Modul 3: Daten & Objekte
    "t07-1": {
        "Das hängt von der Länge ab":
            "Die Länge spielt keine Rolle: Der Anfang ist immer Fach 0, das letzte Fach hat die "
            "Nummer length - 1.",
        "1": "1 wäre menschlich gedacht. Java zählt bei Arrays und auch bei Text ab 0.",
        "-1": "Negative Indizes gibt es in Java nicht – der Zugriff löst sofort einen Alarm aus.",
    },
    "t08-1": {
        "Auto.create()": "Eine Methode create() gibt es nur, wenn jemand sie selbst geschrieben hat. "
                         "Der eingebaute Weg ist new.",
        "Auto()": "Auto() allein ruft den Konstruktor nicht auf. Erst new davor lässt Java ein Objekt anlegen.",
        "make Auto": "make ist kein Java-Schlüsselwort. Objekte entstehen ausschließlich mit new.",
    },
    "t08-2": {
        "Es ruft einen anderen Konstruktor auf":
            "Einen anderen Konstruktor ruft man mit this(…) auf – mit runden Klammern, ohne Punkt und "
            "ohne Feldnamen.",
        "Es vergleicht zwei Namen":
            "Zum Vergleichen bräuchte es == oder equals. Das einfache Gleichheitszeichen legt etwas in die Box.",
        "Es erzeugt eine neue lokale Variable":
            "Eine neue lokale Variable entstünde nur mit einem Typ davor. Hier wird das schon vorhandene "
            "Feld gefüllt.",
    },
    "t09-1": {
        "inherits": "inherits klingt passend, ist aber kein Java-Wort – das gibt es in anderen Sprachen.",
        "super": "super greift auf die Eltern-Klasse zu, stellt die Verbindung aber nicht her. "
                 "Dafür ist extends da.",
        "implements": "implements ist für Interfaces – also für Verträge, nicht für das Erben von "
                      "Feldern und Methoden.",
    },
    "t09-2": {
        "Beliebig viele":
            "Mehrfachvererbung bei Klassen erlaubt Java bewusst nicht, weil sonst unklar wäre, welche "
            "geerbte Methode gilt. Über Interfaces geht es trotzdem.",
        "Zwei": "Auch zwei sind zu viele. Es bleibt bei genau einer Eltern-Klasse.",
        "Keine – nur Interfaces":
            "Ohne extends erbt eine Klasse automatisch von Object – ganz ohne Eltern-Klasse ist also "
            "keine Klasse.",
    },

    # --- Modul 4: Robuster Code
    "t10-1": {
        "throw": "throw löst einen Alarm selbst aus, statt ihn aufzufangen.",
        "final": "final versiegelt eine Box oder verhindert Vererbung – mit Fehlern hat es nichts zu tun. "
                 "Gemeint ist vielleicht finally, das immer zum Schluss läuft.",
        "try": "Im try steht der riskante Code. Aufgefangen wird der Alarm erst im catch darunter.",
    },
    "t10-3": {
        "NullPointerException":
            "NullPointerException stammt von RuntimeException ab und gehört damit zu den unchecked "
            "Exceptions – Java verlangt hier nichts.",
        "ArithmeticException":
            "ArithmeticException (etwa bei Division durch 0) ist ebenfalls unchecked. Auffangen darf "
            "man sie, müssen muss man nicht.",
        "ArrayIndexOutOfBoundsException":
            "ArrayIndexOutOfBoundsException ist unchecked. Sie deutet meist auf einen Denkfehler hin, "
            "den man beheben statt auffangen sollte.",
    },
    "t11-1": {
        "push": "push gehört zum Stapel (Deque) und legt oben drauf. Eine Liste kennt diese Methode nicht.",
        "insert": "insert gibt es in Java nicht. Zum Einfügen an einer bestimmten Stelle dient add mit "
                  "Positionsangabe.",
        "put": "put trägt ein Paar aus Schlüssel und Wert in eine Map ein – eine Liste hat keine Schlüssel.",
    },
    "t11-2": {
        "Weil int zu klein ist":
            "Mit der Größe hat es nichts zu tun: Auch long oder double sind in spitzen Klammern nicht erlaubt.",
        "List<int> ist erlaubt": "List<int> lässt sich nicht übersetzen – der Compiler lehnt es ab.",
        "Weil Listen nur Strings speichern":
            "Eine Liste speichert jede Sorte, solange es eine Klasse ist. Für Zahlen nimmt man Integer.",
    },

    # --- Modul 5: Modernes Java
    "t12-1": {
        "x => x * 2": "Der Doppelpfeil => stammt aus JavaScript und C#. Java nutzt den einfachen Pfeil ->.",
        "function(x) { x * 2 }":
            "Das ist die Schreibweise einer benannten Funktion aus anderen Sprachen. Ein Lambda kommt "
            "ohne dieses Gerüst aus.",
        "lambda x: x * 2": "lambda x: gehört zu Python. In Java stehen die Zutaten links vom Pfeil.",
    },
    "t13-1": {
        "Setter-Methoden für x und y":
            "Setter gibt es bewusst nicht: Ein Record ist unveränderlich. Wer andere Werte braucht, "
            "legt einen neuen an.",
        "Nichts – Records müssen alles selbst definieren":
            "Genau umgekehrt – der Record nimmt einem die Arbeit ab und erzeugt den ganzen Rumpf von selbst.",
        "Nur einen leeren Konstruktor":
            "Es entsteht nicht nur ein leerer Konstruktor, sondern einer mit allen Feldern, dazu die "
            "Lesemethoden und equals, hashCode und toString.",
    },
}
