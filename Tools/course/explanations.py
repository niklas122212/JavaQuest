"""Bessere Aufgaben-Erklärungen: nicht nur WAS passiert, sondern WARUM es so ist.

Viele Erklärungen waren Lexikoneinträge: „int steht für integer, also ganze Zahlen.“
Das beantwortet die Frage nicht, die beim Lernen wirklich aufkommt – warum nimmt man
int und nicht double? Warum beendet println die Zeile und print nicht?

Die Texte hier überschreiben die Erklärung der jeweiligen Aufgabe. Der Kursbau prüft,
dass jede ID existiert und dass der neue Text tatsächlich mehr sagt als der alte –
sonst bricht er ab. So kann diese Sammlung nicht unbemerkt veralten.
"""

# Ab dieser Länge gilt eine Erklärung als ausgeführt genug, um ein „Warum“ zu enthalten.
# Die Zahl ist kein Qualitätsmaß, sondern eine Untergrenze gegen Rückfälle.
MINDESTLAENGE = 90

BETTER_EXPLANATIONS = {
    # ---------------------------------------------------------------- Modul 1: Erste Schritte
    "t01-1":
        "Java liest die Datei zwar von oben nach unten, führt aber nichts davon aus, bevor es main "
        "gefunden hat. Der Grund: Eine Klasse ist nur ein Bauplan – irgendwo muss festgelegt sein, "
        "welche Anweisungen den Anfang machen. Darauf haben sich alle Java-Programme geeinigt: "
        "Es ist immer public static void main(String[] args).",
    "t01-3":
        "println heißt „print line“: Es schreibt den Text und hängt danach einen Zeilenumbruch an. "
        "Das ist wichtig, weil die nächste Ausgabe sonst direkt dahinterklebt. Wer mehrere Teile in "
        "einer Zeile braucht, nimmt print – und erst zum Schluss einmal println.",
    "t01-5":
        "Die Anführungszeichen sagen Java: Alles dazwischen ist Text und kein Befehl. Ohne sie würde "
        "Java „Ich“ für einen Variablennamen halten und den Fehler melden, dass es ihn nicht kennt. "
        "Das Semikolon markiert, wo die Anweisung aufhört – Zeilenumbrüche sind für Java nur Optik.",

    # ---------------------------------------------------------------- Modul 1: Variablen
    "t02-1":
        "int steht für „integer“, also ganze Zahlen. Warum nicht gleich double für alles? Weil eine "
        "int-Box exakt rechnet und beim Lesen sofort verrät, dass hier nie Nachkommastellen "
        "auftauchen. double rechnet dagegen mit winzigen Rundungsfehlern – 0.1 + 0.2 ergibt dort "
        "nicht genau 0.3.",
    "t02-2":
        "double ist in Java die Standardwahl für Kommazahlen: Eine Zahl wie 4.99 ist von sich aus "
        "ein double. float wäre kleiner und ungenauer und verlangt ein f am Ende (4.99f), sonst "
        "meldet der Compiler einen Fehler. Deshalb nimmt man im Zweifel double.",
    "t02-3":
        "Erst wird gerechnet: punkte steht danach auf 15. Beim Ausgeben hat das Pluszeichen dann "
        "eine andere Bedeutung – sobald einer der beiden Teile Text ist, klebt es zusammen statt zu "
        "addieren. Deshalb wird aus der Zahl 15 das Textstück „15“.",
    "t02-5":
        "Eine Zuweisung überschreibt den alten Inhalt unwiderruflich. Stünde a = b zuerst, wäre der "
        "ursprüngliche Wert von a weg, und b = a würde ihn nur zurückkopieren – beide Boxen hätten "
        "denselben Wert. tmp bewahrt ihn genau so lange auf, bis er gebraucht wird.",

    # ---------------------------------------------------------------- Modul 1: Operatoren
    "t03-1":
        "% ist nicht das Prozentzeichen, sondern der Rest-Operator: Er fragt, was nach der "
        "Ganzzahldivision übrig bleibt. 3 passt zweimal in die 7, das macht 6 – es bleibt 1. Genau "
        "dieser Rest verrät zum Beispiel, ob eine Zahl gerade ist: Rest 0 bei Division durch 2.",
    "t03-2":
        "Teilt Java zwei ganze Zahlen, ist auch das Ergebnis eine ganze Zahl – die Nachkommastelle "
        "wird nicht gerundet, sondern abgeschnitten. Das überrascht oft: 7 / 2 ergibt 3, nicht 3,5. "
        "Wer genau rechnen will, muss eine Seite zur Kommazahl machen, etwa 7 / 2.0.",
    "t03-3":
        "++ erhöht den Wert der Box um genau 1. Diesen Operator gibt es, weil Hochzählen so häufig "
        "vorkommt – vor allem in Schleifen. zaehler += 1 und zaehler = zaehler + 1 tun dasselbe, "
        "sind nur länger zu schreiben.",
    "t03-4":
        "x += 3 macht 8 daraus, x *= 2 verdoppelt auf 16. && verlangt, dass beide Seiten stimmen: "
        "16 ist größer als 10, und 16 % 2 ergibt 0, also gerade. Nur weil beides zutrifft, kommt "
        "true heraus – bei && genügt eine falsche Hälfte, um alles falsch zu machen.",

    # ---------------------------------------------------------------- Modul 2: Bedingungen
    "t04-1":
        "if muss eine Ja-Nein-Entscheidung treffen und braucht dafür etwas, das genau zwei Werte "
        "kennt: true oder false. Anders als in C oder JavaScript gilt in Java keine Zahl und kein "
        "Text als „wahr“. Das verhindert Fehler wie if (x = 5), wo versehentlich zugewiesen statt "
        "verglichen wird – Java lehnt das ab, weil eine Zahl keine Bedingung ist.",
    "t04-2":
        "16 >= 18 ergibt false, also wird der erste Block übersprungen und der else-Zweig läuft. "
        "Von beiden Blöcken kommt immer genau einer dran – nie beide und nie keiner. Die Zeile "
        "hinter der schließenden Klammer läuft dann wieder in jedem Fall.",
    "t04-3":
        "Gerade heißt: durch 2 teilbar ohne Rest. Genau das beantwortet zahl % 2 – kommt 0 heraus, "
        "ist die Zahl gerade. Mit / ginge es nicht, denn die Ganzzahldivision verschluckt genau die "
        "Information, auf die es hier ankommt.",
    "t04-4":
        "Java geht die Kette von oben nach unten durch und steigt bei der ersten wahren Bedingung "
        "aus. Deshalb muss die strengste Bedingung oben stehen: Stünde punkte >= 70 zuerst, bekäme "
        "auch ein Ergebnis von 95 nur „gut“, weil danach gar nicht mehr geprüft wird.",
    "t04-5":
        "Die Pfeil-Schreibweise braucht kein break: Es läuft genau ein Zweig, danach ist das switch "
        "zu Ende. Bei der alten Schreibweise mit Doppelpunkt lief ohne break der nächste Fall "
        "einfach mit – eine der häufigsten Fehlerquellen überhaupt. default fängt alles ab, woran "
        "man nicht gedacht hat.",

    # ---------------------------------------------------------------- Modul 2: Schleifen
    "t05-1":
        "Die Bedingung wird vor jeder Runde geprüft, nicht danach. i startet bei 0 und läuft durch "
        "0, 1 und 2 – bei 3 ist i < 3 falsch und die Schleife endet, ohne noch einmal zu laufen. "
        "Deshalb sind es drei Runden, obwohl im Code eine 3 steht: Gezählt wird ab 0.",
    "t05-2":
        "print schreibt weiter in dieselbe Zeile, println würde sie beenden. Deshalb stehen die "
        "Zahlen nebeneinander statt untereinander. Das Leerzeichen im Text ist nötig – sonst klebten "
        "sie als „123“ aneinander.",
    "t05-3":
        "Die Bedingung steht vor dem Block und wird vor jeder Runde neu geprüft. Deshalb muss im "
        "Block etwas passieren, das sie irgendwann falsch macht – hier n--. Fehlt das Herunterzählen, "
        "bleibt die Bedingung für immer wahr und die Schleife läuft endlos.",
    "t05-4":
        "continue überspringt den Rest der Runde und macht mit der nächsten weiter, break verlässt "
        "die Schleife ganz. Gerade Zahlen fallen also heraus; addiert werden 1, 3, 5 und 7. Bei 9 "
        "greift break – die 9 wird nicht mehr mitgezählt, obwohl sie ungerade ist.",
    "t05-5":
        "Der Zähler muss außerhalb der Schleife stehen. Stünde int summe = 0 innerhalb, begänne er "
        "in jeder Runde von vorn und am Ende käme nur 100 heraus. Das ist das Grundmuster für jedes "
        "Aufsummieren: Speicher draußen anlegen, drinnen füllen.",


    # ---------------------------------------------------------------- Weitere Lektionsaufgaben
    "t06-1":
        "Eine Methode ohne Rückgabe ist nicht nutzlos: Sie tut etwas – ausgeben, ein Feld ändern – liefert aber nichts an die aufrufende Stelle zurück. void zwingt dazu, das klar zu sagen. Dadurch kann man das Ergebnis auch nicht versehentlich in eine Variable legen, denn es gibt keines.",
    "t06-2":
        "Beide Aufrufe laufen zu Ende, bevor addiert wird: Java rechnet von innen nach außen. doppelt(4) wird zu 8, doppelt(1) zu 2 – erst dann steht 8 + 2 da. Dass eine Methode mitten in einem Ausdruck stehen darf, ist der Grund, warum return praktischer ist als println.",
    "t06-3":
        "Der Rückgabetyp vor dem Namen ist ein Versprechen: Diese Methode liefert genau einen int. Java prüft, dass auf jedem möglichen Weg ein return steht – fehlt einer, gibt es schon beim Übersetzen einen Fehler statt später eine Überraschung.",
    "t07-1":
        "Der Index ist kein Abzählen, sondern ein Abstand vom Anfang: Das erste Fach liegt 0 Schritte hinter dem Anfang, das zweite einen. Deshalb hat das letzte Fach immer die Nummer length - 1 – genau hier entsteht der häufigste Anfängerfehler.",
    "t07-2":
        "length() zählt alle Zeichen, charAt zählt ab 0 – Index 1 ist deshalb das zweite Zeichen. toUpperCase verändert den Text nicht, sondern liefert einen neuen zurück: wort selbst steht danach unverändert da.",
    "t07-5":
        "Das Muster heißt „bisher bester Wert“: Man startet mit dem ersten Element und ersetzt es, sobald ein größeres auftaucht. Mit 0 zu starten wäre ein Fehler – bei lauter negativen Zahlen käme sonst 0 heraus, obwohl die 0 gar nicht im Array steht.",
    "t08-1":
        "new macht zwei Dinge auf einmal: Es besorgt Platz im Speicher und ruft dann den Konstruktor auf, der die Felder füllt. Ohne new hätte man nur den Bauplan – Auto() allein sucht Java als Methode, und die gibt es nicht.",
    "t08-3":
        "Jedes new legt einen eigenen Satz Felder an. Deshalb zählen a und b getrennt: a wurde zweimal geklickt, b einmal. Wäre stand static, gäbe es den Zähler nur einmal für alle Objekte – dann stünde dort 3 und 3.",
    "t08-4":
        "Der Konstruktor heißt wie die Klasse und hat keinen Rückgabetyp – daran erkennt Java ihn. Schriebe man void davor, wäre es eine ganz normale Methode namens Konto, die beim new nie aufgerufen würde.",
    "t09-1":
        "extends heißt: Diese Klasse ist eine besondere Art der anderen und hat alles schon, ohne es abzuschreiben. implements ist etwas anderes – dort verspricht man nur, bestimmte Methoden zu liefern, erbt aber keinen fertigen Code.",
    "t10-1":
        "Die Aufteilung hat einen Grund: Im try steht, was schiefgehen kann, im catch, was dann passieren soll. So bleibt der normale Ablauf lesbar und die Fehlerbehandlung steht gebündelt daneben – statt einer Prüfung nach jeder einzelnen Zeile.",
    "t10-4":
        "throw löst den Alarm sofort aus: Die Methode bricht an dieser Stelle ab, die Zeilen danach laufen nicht mehr. Nicht zu verwechseln mit throws im Methodenkopf – das kündigt nur an, dass ein Fehler kommen könnte.",
    "t11-1":
        "add gehört zu allen Sammlungen, die Elemente einfach aneinanderreihen. put gäbe es nur bei einer Map, weil dort jeder Eintrag zusätzlich einen Schlüssel braucht. Die Methodennamen verraten also, womit man es zu tun hat.",
    "t11-4":
        "getOrDefault löst das Henne-Ei-Problem: Beim ersten Vorkommen steht noch nichts in der Map, und null + 1 würde abstürzen. Die 0 als Ersatzwert macht die erste Runde zur ganz normalen. put schreibt den erhöhten Stand dann zurück.",
    "t12-1":
        "Der Pfeil trennt Zutaten von Arbeit: links, was hereinkommt, rechts, was damit passiert. => stammt aus JavaScript, lambda x: aus Python – beides lehnt der Java-Compiler ab, auch wenn man es von woanders gewohnt ist.",
    "t12-2":
        "forEach übernimmt das Durchlaufen und ruft für jedes Element den kurzen Block rechts vom Pfeil auf – in der Reihenfolge der Liste. Man sagt also nur noch, WAS mit jedem Element passieren soll, nicht mehr, wie man durchzählt.",
    "t12-3":
        "Die Reihenfolge der Stationen entscheidet: Erst siebt filter die ungeraden aus, dann verzehnfacht map, was übrig bleibt. Umgekehrt käme etwas anderes heraus. Passieren tut übrigens gar nichts, bis am Ende toList die Ergebnisse einsammelt.",
    "t12-4":
        "filter entscheidet, WAS durchkommt, map, WIE es sich verändert – zwei Aufgaben, zwei Stationen. String::toUpperCase ist dabei nur eine Kurzschreibweise für w -> w.toUpperCase().",
    "t13-1":
        "Ein Record hält Werte zusammen und ist dabei unveränderlich – deshalb gibt es Lesemethoden, aber bewusst keine Setter. Wer andere Werte braucht, legt einen neuen an. Das erspart eine ganze Klasse voller immer gleichem Code.",
    "t13-3":
        "Optional ist eine Schachtel, die leer sein darf – das zwingt dazu, den leeren Fall zu behandeln, statt ihn zu vergessen. orElse greift nur, wenn nichts drin ist; map arbeitet nur, wenn etwas drin ist. Genau das verhindert die NullPointerException.",
    "t13-4":
        "Ein switch-Ausdruck liefert einen Wert und braucht deshalb für jeden möglichen Fall eine Antwort – sonst wüsste Java nicht, was in die Variable soll. Bei einem enum kann der Compiler die Fälle nachzählen, bei int nicht: Dort muss default her.",
    "t14-3":
        "Der switch über ein enum kommt ohne den Vornamen aus: case REGEN genügt, Wetter.REGEN wäre sogar ein Fehler. Weil alle Werte aufgezählt sind, prüft Java, dass keiner fehlt – bei Text statt enum ginge das nicht.",
    "t15-5":
        "println fragt jedes Objekt nach seiner toString-Methode. Ohne eigene Fassung greift die von Object und zeigt Klassennamen und eine kryptische Zahl. Wer toString schreibt, bestimmt also selbst, was beim Ausgeben erscheint.",
    "t16-5":
        "Ein String lässt sich nicht verändern: Bei text += \"*\" entsteht jedes Mal ein komplett neuer Text. Der StringBuilder ist dagegen ein Bauplatz, an den angehängt wird – bei fünf Runden egal, bei Tausenden ein spürbarer Unterschied.",
    "t17-5":
        "Das Datum selbst weiß nichts von deutscher Schreibweise – es speichert nur Jahr, Monat und Tag. Erst die Formatvorlage bestimmt die Darstellung: dd zweistelliger Tag, MM zweistelliger Monat, yyyy vierstelliges Jahr. Klein geschriebenes mm wären Minuten.",
    "t18-1":
        "Jeder Aufruf belegt Platz auf dem Aufruf-Stapel. Ohne Abbruchbedingung wächst dieser Stapel, bis der Platz aufgebraucht ist – das Programm endet mit StackOverflowError. Der Basisfall ist also nicht Kür, sondern das Einzige, was die Kette beenden kann.",
    "t18-2":
        "Jeder Aufruf wartet auf den nächsten: summe(4) kann erst rechnen, wenn summe(3) fertig ist, und so weiter bis summe(0). Erst dann lösen sich die wartenden Aufrufe von innen nach außen auf – 0, 1, 3, 6, 10.",
    "t18-4":
        "Der Basisfall muss vor dem Aufruf stehen, sonst wird er nie erreicht. Exponent 0 liefert 1, weil jede Zahl hoch 0 genau 1 ergibt – und weil 1 der Wert ist, der beim Multiplizieren nichts verändert.",
    "t19-3":
        "Arrays.sort ordnet das Array an Ort und Stelle – es entsteht kein neues, das alte ist danach verändert. Deshalb liegt in Fach 0 nun die kleinste Zahl. Wer die ursprüngliche Reihenfolge noch braucht, muss vorher eine Kopie anlegen.",
    "t20-1":
        "Rückgängig heißt: zuletzt Gemachtes zuerst zurücknehmen. Genau das leistet ein Stapel – oben drauflegen, oben herunternehmen. Eine Warteschlange würde die älteste Änderung zuerst zurücknehmen, also genau die falsche.",
    "t20-2":
        "Das Set wirft Doppelte weg, weil eine Menge jeden Wert nur einmal kennt – aus fünf Zahlen werden drei. Das TreeSet hält sie zusätzlich sortiert; ein HashSet hätte dieselben Zahlen, aber in unvorhersagbarer Reihenfolge.",
    "t20-4":
        "offer und poll arbeiten an entgegengesetzten Enden: hinten anstellen, vorne abholen. Genau das macht eine Warteschlange aus – wer zuerst kommt, wird zuerst bedient. Beim Stapel wären es push und pop, beide am selben Ende.",
    "t20-5":
        "Das Set beantwortet „wie viele verschiedene“ ohne eine einzige Vergleichsschleife: Doppelte fallen beim Einfügen von selbst weg. Mit einer Liste müsste man jedes Wort mit allen vorherigen vergleichen.",
    "t21-5":
        "Gute Tests nehmen die Ränder mit: die 0 als Grenzfall, eine gewöhnliche positive und eine negative Zahl. Gerade negative Werte werden beim Programmieren oft vergessen – ein Test, der nur die 5 prüft, übersieht solche Fehler.",
    "t22-1":
        "Das Paket ist der Nachname der Klasse: Zwei Projekte dürfen beide eine Klasse Liste haben, solange die Pakete verschieden sind. Deshalb muss die Datei auch im passenden Ordner liegen – Java sucht sie genau dort.",
    "t22-2":
        "Ohne Build-Werkzeug müsste man Bibliotheken von Hand herunterladen, Versionen selbst im Blick behalten und die Übersetzungsbefehle jedes Mal neu tippen. Ein Bauplan im Projekt macht daraus einen einzigen Befehl – und jeder im Team bekommt dasselbe Ergebnis.",
    "t23-1":
        "Ein gestarteter Thread läuft nebenher weiter; das Hauptprogramm wartet nicht von selbst auf ihn. Ohne join stünde man womöglich vor einem Ergebnis, das es noch gar nicht gibt. join hält an, bis der Thread wirklich fertig ist.",
    "t24-2":
        "Ein gewöhnlicher Thread belegt Speicher vom Betriebssystem – ein paar tausend davon bringen den Rechner an die Grenze. Virtuelle Threads verwaltet Java selbst und legt sie beim Warten beiseite. Deshalb lohnen sie sich genau dort, wo viel gewartet wird.",
    "t24-3":
        "submit gibt sofort einen Abholschein (Future) zurück, nicht das Ergebnis – die Arbeit läuft erst noch. get holt es ab und wartet dabei, falls nötig. Dadurch können beide Aufgaben gleichzeitig laufen statt nacheinander.",
    "t24-5":
        "Erst alle drei einreichen, dann einsammeln: So laufen sie nebeneinander. Würde man nach jedem submit sofort get aufrufen, wartete man jedes Mal – und hätte den Vorteil der Nebenläufigkeit verschenkt.",
    "t25-1":
        "sealed schließt die Familie: Nur die nach permits genannten Typen dürfen dazugehören. Der Gewinn zeigt sich beim switch – weil Java alle Möglichkeiten kennt, meldet es, wenn ein Fall fehlt. Bei einem offenen Interface ginge das nicht.",
    "t25-3":
        "Die Reihenfolge entscheidet: Der Zweig mit when ist der engere und muss oben stehen, sonst fängt der allgemeinere ihn vorher ab. Java prüft von oben nach unten und nimmt den ersten Treffer.",
    "t25-5":
        "Weil Fahrzeug sealed ist, genügen die aufgezählten Zweige – Java rechnet nach, dass nichts fehlt, und verlangt kein default. Kommt später eine Form dazu, meldet der Compiler jedes switch, das sie noch nicht behandelt.",
    "t26-1":
        "groupingBy beantwortet „welche gehören zusammen?“ in einem Schritt. Das Ergebnis ist eine Map: der Schlüssel das gemeinsame Merkmal, der Wert die Liste der Elemente dazu. Von Hand bräuchte es eine Schleife und eine Abfrage, ob der Schlüssel schon existiert.",
    "t26-2":
        "sorted verändert die ursprüngliche Liste nicht – sie ist unveränderlich, und das Fließband arbeitet auf einer Kopie. reduce faltet alles zu einem einzigen Wert zusammen; die 0 am Anfang ist der Startwert, der bei einer leeren Liste herauskäme.",
    "t26-4":
        "flatMap macht aus einem Fließband von Listen ein Fließband von Elementen – mit map bliebe es eine Liste von Listen. Erst danach kann sorted alle Namen gemeinsam ordnen statt nur innerhalb jeder Klasse.",
    "t27-1":
        "Ein Durchschnitt ist selten eine ganze Zahl. Mit int käme hier 1 heraus, weil die Ganzzahldivision abschneidet – aus 1,67 würde 1. Zu beachten: Auch die Rechnung selbst muss mit Kommazahlen laufen, sonst hilft die double-Box nichts.",
    "t27-3":
        "<= 4 statt < 4 ist der springende Punkt: Note 4 gilt noch als bestanden. Solche Grenzfälle sind die häufigste Fehlerquelle überhaupt – deshalb prüft man beim Testen zuerst genau sie.",
    "t27-5":
        "Zwei Dinge in einem Durchlauf: aufsummieren und die kleinste Note merken. Beim Durchschnitt muss mindestens eine Seite eine Kommazahl sein, sonst schneidet die Ganzzahldivision das Ergebnis ab.",
    "t28-2":
        "Die Lesemethode heißt wie das Feld, nicht getTitel() – das ist die Record-Schreibweise. Das mitgelieferte toString zeigt Klassennamen und alle Felder mit Namen, was beim Suchen von Fehlern viel wert ist.",
    "t28-4":
        "Ein Record lässt sich nicht verändern – abhaken heißt deshalb: neuen Record bauen und den alten ersetzen. set tauscht ihn an Ort und Stelle aus. Das klingt umständlich, verhindert aber, dass ein Objekt sich unbemerkt hinter dem Rücken ändert.",
    "t28-5":
        "Die laufende Nummer ist i + 1, weil Listen ab 0 zählen, Menschen aber ab 1. Das Häkchen entsteht aus einer Ja-Nein-Entscheidung mitten im Ausgabetext – dafür eignet sich der Fragezeichen-Operator.",
    "t29-3":
        "Der switch über ein enum liefert hier einen Wert zurück, statt nur etwas zu tun. Weil alle Räume aufgezählt sind, weiß Java, dass jeder Fall abgedeckt ist – ein default wäre überflüssig.",
    "t29-4":
        "Die verschachtelte Map ist die Landkarte: zu jedem Raum die Richtungen und wohin sie führen. getOrDefault fängt Befehle ab, für die es keinen Weg gibt – dann bleibt man einfach stehen, statt abzustürzen.",
    "t29-5":
        "getOrDefault(befehl, hier) ist der Kern: Gibt es den Weg, geht es weiter; gibt es ihn nicht, bleibt man im selben Raum. Ohne diesen Ersatzwert käme null zurück und der nächste Schritt würde abstürzen.",
    "t31-1":
        "Die Dreiecksspitze zeigt immer zur allgemeineren Klasse – man liest den Pfeil als „ist ein“. Ein Hund ist ein Tier, aber nicht jedes Tier ist ein Hund. Deshalb wäre der Pfeil andersherum schlicht falsch.",
    "t32-4":
        "Gestrichelt heißt: Hier wird nichts geerbt, sondern ein Vertrag unterschrieben. Das Interface gibt nur vor, welche Methoden es geben muss – den Inhalt liefert die Klasse. Bei durchgezogener Linie stünde extends.",


    # ---------------------------------------------------------------- Übungspool, Teil 1
    "p-var-1a":
        "Das Etikett bestimmt, was hineinpasst: In eine int-Box passt keine Nachkommastelle – Java schneidet sie nicht etwa ab, sondern lehnt die Zuweisung gleich ab. double ist die Standardwahl für Kommazahlen; float wäre ungenauer und verlangte ein f am Ende.",
    "p-var-1b":
        "boolean kennt genau zwei Werte, weil es Ja-Nein-Fragen beantwortet. Diese Beschränkung ist Absicht: Weil in Java keine Zahl als „wahr“ gilt, kann man nicht versehentlich eine Zuweisung statt eines Vergleichs in ein if schreiben.",
    "p-var-2a":
        "Erst wird gerechnet, dann ausgegeben: punkte steht auf 10. Beim Ausgeben hat das Pluszeichen eine zweite Bedeutung – sobald links Text steht, klebt es zusammen statt zu addieren, und aus der Zahl 10 wird das Textstück „10“.",
    "p-var-2b":
        "Trifft eine Kommazahl auf eine ganze Zahl, rechnet Java in der genaueren von beiden weiter – also in double. Deshalb erscheint 10.0 statt 10. Der Punkt in der Ausgabe verrät den Typ des Ergebnisses.",
    "p-var-3a":
        "final versiegelt die Box: Nach der ersten Füllung lehnt der Compiler jede weitere Zuweisung ab. Das schützt nicht vor Angreifern, sondern vor einem selbst – wer eine Konstante wie MWST versehentlich überschreibt, merkt es sonst erst an falschen Zahlen.",
    "p-op-1a":
        "% fragt nach dem Rest, nicht nach dem Ergebnis: 4 passt zweimal in die 9, das macht 8 – es bleibt 1. Genau dieser Rest verrät Teilbarkeit: Rest 0 heißt, es geht glatt auf.",
    "p-op-1b":
        "Rest 0 heißt: Es geht glatt auf, 5 ist ein Teiler von 10. Genau so prüft man Teilbarkeit – mit / ginge es nicht, weil die Ganzzahldivision den Rest verschluckt.",
    "p-op-2a":
        "Zwei ganze Zahlen ergeben bei / wieder eine ganze Zahl – gerundet wird nicht, abgeschnitten schon. Die weggefallene Hälfte steckt im Rest: / liefert 2, % liefert 1. Zusammen beschreiben die beiden die Division vollständig.",
    "p-op-2b":
        "Beide Kurzformen verändern dieselbe Box: += 3 macht aus 5 die 8, ++ zählt auf 9 weiter. Sie sind nur Schreiberleichterung für zaehler = zaehler + 3 – das Ergebnis landet jedes Mal wieder in derselben Box.",
    "p-if-1a":
        "Von if und else läuft immer genau einer – nie beide und nie keiner. Weil 20 >= 18 wahr ist, wird der else-Block übersprungen. Die Zeilen hinter der schließenden Klammer laufen danach wieder in jedem Fall.",
    "p-if-1b":
        "Java prüft die Kette von oben nach unten und steigt beim ersten Treffer aus. Hier trifft keine Bedingung zu, also bleibt der else-Block – er ist der Auffangkorb für alles, was übrig bleibt.",
    "p-if-2a":
        "Teilbar heißt: kein Rest. % liefert genau diesen Rest, und der Vergleich mit 0 macht daraus eine Ja-Nein-Frage. Mit / ginge es nicht – die Ganzzahldivision wirft die Information weg, auf die es hier ankommt.",
    "p-if-2b":
        "Die Reihenfolge ist entscheidend: Java nimmt den ersten Treffer und prüft danach nichts mehr. Stünde punkte >= 50 oben, bekäme auch ein Ergebnis von 95 nur „bestanden“.",
    "p-loop-1a":
        "Die Bedingung wird vor jeder Runde geprüft: Bei i = 4 ist i <= 3 falsch und die Schleife endet. Weil hier ab 1 gezählt wird und <= steht, kommen genau drei Runden heraus.",
    "p-loop-1b":
        "Anders als bei for steht hier nichts über das Herunterzählen im Kopf – n-- muss im Block passieren. Fehlt es, bleibt n für immer 3 und die Schleife läuft endlos.",
    "p-loop-2a":
        "Die Box summe muss außerhalb der Schleife stehen, sonst begänne sie in jeder Runde wieder bei 0 und am Ende stünde nur 5 da. Das ist das Grundmuster für jedes Aufsummieren.",
    "p-loop-2b":
        "continue springt zum Anfang der nächsten Runde und überspringt alles darunter – die Ausgabe wird für gerade Zahlen gar nicht erst erreicht. Die Schleife läuft trotzdem alle sechs Runden.",
    "p-meth-1a":
        "Weil die Methode ihr Ergebnis mit return zurückgibt, darf der Aufruf mitten in einer anderen Anweisung stehen. Mit einem println innerhalb der Methode ginge das nicht – dann könnte man mit dem Wert nicht weiterrechnen.",
    "p-meth-1b":
        "void heißt: Diese Methode liefert nichts zurück. Nutzlos ist sie deshalb nicht – sie kann ausgeben oder ein Feld ändern. Aber ihr Aufruf lässt sich nicht in eine Variable legen, weil es kein Ergebnis gibt.",
    "p-meth-2a":
        "Der Typ vor dem Namen ist ein Versprechen: Hier kommt genau ein int heraus. Java prüft schon beim Übersetzen, dass auf jedem Weg ein return steht – fehlt einer, gibt es einen Fehler statt später eine Überraschung.",
    "p-meth-3a":
        "Ein Vergleich wie zahl > 0 ist selbst schon ein Wahrheitswert und kann direkt zurückgegeben werden. Der Umweg über if (…) return true; else return false; sagt dasselbe mit vier Zeilen mehr – und lenkt vom Kern ab.",
    "p-arr-1a":
        "Der Index ist ein Abstand vom Anfang, kein Abzählen: Fach 0 liegt null Schritte hinter dem Anfang. Deshalb liegt in zahlen[0] die erste Zahl und das letzte Fach hat die Nummer length - 1.",
    "p-arr-1b":
        "length steht ohne Klammern, weil es bei einem Array ein Feld ist und keine Methode. Der Wert steht beim Anlegen fest – ein Array kann später nicht wachsen. Bei einem String hieße es dagegen length().",
    "p-arr-2a":
        "Die for-each-Schleife holt die Werte selbst aus dem Array – ohne Zähler und ohne Index. Dadurch kann man sich nicht vertun, zahlt aber mit einem Verzicht: Welche Position gerade dran ist, weiß man nicht.",
    "p-str-1a":
        "length() zählt alle Zeichen, auch Leerzeichen und Satzzeichen. Die Klammern gehören dazu, weil es bei einem String eine Methode ist – beim Array wäre es das Feld length ohne Klammern.",
    "p-str-1b":
        "Die zweite Zahl ist das Ende und gehört nicht mehr dazu: von 0 bis vor 7 sind sieben Zeichen. Diese Regel gilt in Java überall gleich – so ergibt Ende minus Anfang immer direkt die Länge.",
    "p-inh-1a":
        "implements verspricht nur, bestimmte Methoden zu liefern; den Inhalt schreibt die Klasse selbst. extends übernimmt dagegen fertigen Code. Deshalb darf man beliebig viele Verträge unterschreiben, aber nur von einer Klasse erben.",
    "p-exc-2a":
        "Die Trennung ist der Sinn der Sache: Im try steht, was schiefgehen kann, im catch, was dann passieren soll. So bleibt der normale Ablauf lesbar, statt nach jeder Zeile eine Prüfung einzustreuen.",
    "p-col-1a":
        "add hängt immer hinten an, size zählt nach. Im Unterschied zum Array muss man die Größe nicht vorher kennen – die Liste besorgt sich bei Bedarf selbst mehr Platz.",
    "p-col-3a":
        "get würde hier null liefern, und damit weiterzurechnen führt zum Absturz. getOrDefault nimmt einem die Abfrage ab: Fehlt der Schlüssel, kommt der Ersatzwert. Deshalb eignet es sich so gut zum Zählen.",
    "p-lam-1a":
        "Das Fließband arbeitet erst, wenn am Ende jemand etwas abholt: filter merkt sich nur die Regel, forEach setzt alles in Gang. Ohne diese Endstation würde gar nichts passieren.",
    "p-lam-1b":
        "map formt jedes Element um und lässt die ursprüngliche Liste unangetastet – sie ist unveränderlich. String::toUpperCase ist dabei nur die Kurzform für w -> w.toUpperCase().",
    "p-lam-2a":
        "mapToInt wechselt von Objekten zu echten Zahlen – erst dadurch gibt es überhaupt ein sum(). Mit map bliebe es ein Fließband von Integer-Objekten, das Summieren nicht kennt.",
    "p-mod-1a":
        "Die Lesemethode heißt wie das Feld, nicht getTitel() – das ist die Record-Schreibweise. Setter fehlen bewusst: Ein Record ist unveränderlich, wer andere Werte braucht, legt einen neuen an.",
    "p-mod-1b":
        "Optional zwingt dazu, den leeren Fall zu behandeln, statt ihn zu vergessen. Genau darin liegt der Gewinn gegenüber null: Der Compiler erinnert an die Stelle, an der sonst später die NullPointerException käme.",
    "p-set-1b":
        "push und pop arbeiten beide am selben Ende – deshalb kommt zuerst herunter, was zuletzt drauflag. Genau diese Reihenfolge braucht man für „Rückgängig“. Bei einer Warteschlange wäre es umgekehrt.",
    "q-syn-1b":
        "Das ln steht für „line“: println hängt hinter dem Text einen Zeilenumbruch an. Deshalb nimmt man print, solange man in derselben Zeile weiterschreiben will – und erst ganz am Ende einmal println.",
    "q-syn-2b":
        "Alles hinter // ist ein Notizzettel für Menschen; Java überliest den Rest der Zeile. Das nutzt man beim Fehlersuchen: eine Zeile kurz stilllegen, ohne sie zu löschen.",
    "q-syn-3a":
        "print und println unterscheiden sich nur im Zeilenumbruch am Ende. Wer mehrere Teile nebeneinander braucht, nimmt print – sonst stünde jeder Teil in einer eigenen Zeile.",
    "q-var-1a":
        "Das Pluszeichen hat bei Text eine zweite Bedeutung: Es klebt aneinander, statt zu rechnen. Die Leerzeichen müssen dabei im Text stehen – Java fügt von sich aus keine ein.",
    "q-var-2b":
        "char nimmt genau ein Zeichen und steht in einfachen Anführungszeichen – doppelte wären ein String. Beim Ausgeben wird beides zu Text, deshalb erscheint true als Wort und nicht als Zahl.",
    "q-op-2a":
        "&& verlangt beide Seiten: Fehlt eine, ist das Ganze falsch. Praktisch nebenbei – Java prüft die rechte Seite gar nicht mehr, wenn die linke schon falsch ist. Das verhindert Abstürze bei Prüfungen wie obj != null && obj.wert > 0.",
    "q-op-2b":
        "Ein Vergleich liefert selbst schon true oder false und lässt sich deshalb direkt in einer boolean-Box speichern. 7 % 2 ergibt 1, und 1 == 0 ist falsch – also ungerade.",
    "q-if-1a":
        "switch vergleicht den Wert der Reihe nach mit jedem case. Bei Text nimmt es dabei den Inhalt und nicht die Objektgleichheit – man braucht hier also kein equals.",
    "q-if-1b":
        "Mehrere Werte in einem Zweig sparen die Wiederholung: case 6, 7, 8 statt drei getrennter Fälle mit demselben Inhalt. Getrennt werden sie durch Kommas.",
    "q-loop-1a":
        "Der dritte Teil im Schleifenkopf bestimmt die Schrittweite – sie muss nicht 1 sein. i += 2 überspringt jede zweite Zahl; mit i-- liefe die Schleife rückwärts.",
    "q-loop-1b":
        "Bei do-while steht die Prüfung hinten: Der Block läuft deshalb mindestens einmal, auch wenn die Bedingung von Anfang an falsch wäre. Genau das braucht man bei Eingaben, die erst einmal gelesen werden müssen.",
    "q-loop-2a":
        "break verlässt die Schleife sofort und ganz – die restlichen Runden fallen aus. Das unterscheidet es von continue, das nur die laufende Runde abbricht und mit der nächsten weitermacht.",
    "q-arr-1a":
        "Ein mit new angelegtes Array ist nie undefiniert: Zahlenfächer starten bei 0, boolean-Fächer bei false, Objektfächer bei null. Deshalb steht in Fach 0 eine 0, obwohl dort nie etwas hineingelegt wurde.",
    "q-arr-1b":
        "Die Box summe steht außerhalb der Schleife – sonst begänne sie in jeder Runde von vorn. Die for-each-Schleife übernimmt das Durchzählen, man muss sich nur noch ums Aufaddieren kümmern.",
    "q-arr-2a":
        "Der Startwert ist entscheidend: Man beginnt mit dem ersten Element, nicht mit 0. Sonst käme bei lauter Zahlen über 0 immer die 0 heraus – ein Wert, der gar nicht im Array steht.",
    "q-str-1b":
        "equals vergleicht Zeichen für Zeichen, == fragt dagegen, ob es dasselbe Objekt im Speicher ist. Bei Texten will man fast immer den Inhalt wissen – deshalb ist equals hier die richtige Wahl.",
    "q-str-2a":
        "charAt zählt ab 0, genau wie beim Array: Fach 0 ist das erste Zeichen. Zurück kommt ein char, kein String – für ein einzelnes Zeichen nimmt Java den kleineren Typ.",
    "q-inh-1b":
        "Verträge darf man beliebig viele unterschreiben, weil ein Interface nur vorgibt, was es geben muss – es bringt keinen Code mit, der sich widersprechen könnte. Bei mehreren Eltern-Klassen wäre dagegen unklar, welche geerbte Methode gilt.",
    "q-enum-1b":
        "Die Reihenfolge im enum ist verbindlich: Der erste Wert hat die Position 0. Darauf sollte man sich im Programm aber nicht verlassen – schiebt jemand später einen Wert dazwischen, verschieben sich alle Zahlen dahinter.",
    "q-io-1b":
        "reverse verändert den Notizblock selbst und gibt ihn zurück – anders als bei einem String, der immer unangetastet bleibt. Genau deshalb nimmt man für solche Umbauten einen StringBuilder.",
    "q-io-2a":
        "next() liest bis zum nächsten Leerzeichen, nextInt() liest die nächste Zahl. Der Scanner merkt sich dabei, wie weit er gekommen ist – jeder Aufruf setzt dort fort, wo der letzte aufhörte.",
    "q-dat-1a":
        "plusDays kennt die Länge jedes Monats und rechnet über das Monatsende hinweg richtig. Wichtig: Das Datum wird nicht verändert – es kommt ein neues zurück, denn LocalDate ist unveränderlich.",
    "q-rec-1a":
        "Der Basisfall n <= 1 ist das Einzige, was die Kette beendet – ohne ihn liefe sie bis zum StackOverflowError. Dass dort <= und nicht == steht, fängt zusätzlich die 0 ab, deren Fakultät ebenfalls 1 ist.",
    "q-alg-3a":
        "Der Zähler muss vor der Schleife stehen und darf nur bei Treffern wachsen. Das ist das Grundmuster für jedes „wie viele …“ – innerhalb der Schleife angelegt, begänne er jede Runde neu.",


    # ---------------------------------------------------------------- Übungspool, Teil 2
    "q-ds-3a":
        "Das Set beantwortet „wie viele verschiedene“, ohne dass man vergleichen muss: Beim Einfügen fällt jedes Doppelte von selbst weg. Mit einer Liste müsste man jeden Buchstaben mit allen vorherigen abgleichen.",
    "q-test-3a":
        "Die Reihenfolge ist Absicht: erwarteter Wert zuerst, tatsächliches Ergebnis danach. Verdreht man sie, besteht der Test zwar trotzdem – aber im Fehlerfall steht die Meldung auf dem Kopf und führt in die Irre.",
    "q-con-1a":
        "start() gibt den zweiten Arbeitsstrang frei und kehrt sofort zurück – das Hauptprogramm läuft weiter. Würde man stattdessen run() aufrufen, liefe der Code ganz normal im selben Strang, und von Nebenläufigkeit wäre nichts zu sehen.",
    "q-con-2b":
        "submit gibt sofort einen Abholschein zurück, die Arbeit läuft nebenher. Erst get holt das Ergebnis und wartet, falls es noch nicht fertig ist. Deshalb laufen beide Rechnungen gleichzeitig statt nacheinander: 9 + 25 = 34.",
    "q-proj-2a":
        "getOrDefault ist hier das Sicherheitsnetz: Ohne Tür nach Süden käme bei get null zurück, und der nächste Schritt würde abstürzen. Mit dem Ersatzwert bleibt man einfach stehen, wo man war.",
    "r-dat-1a":
        "plusDays kennt Monatslängen, Jahreswechsel und sogar Schaltjahre – nachrechnen muss man nichts. Das Datum bleibt dabei unverändert; zurück kommt ein neues, denn LocalDate ist unveränderlich.",
    "r-str-2a":
        "split zerlegt an jedem Trennzeichen, das Trennzeichen selbst verschwindet dabei. Gezählt wird ab 0, deshalb ist Fach 2 der dritte Teil. String.join wäre der Rückweg.",
    "r-pat-2a":
        "Das Record-Muster prüft den Typ und packt in einem Zug die Felder aus – ohne instanceof und ohne Umwandlung. Die when-Bedingung ist ein zusätzlicher Filter: Nur wenn auch sie stimmt, greift dieser Zweig.",
    "r-uml-1a":
        "In UML steht die Sichtbarkeit ganz vorn: - privat, + öffentlich, # geschützt. Das ist die kürzeste Art zu zeigen, was von außen erreichbar ist – ohne den Code lesen zu müssen.",
    "r-uml-2a":
        "Die drei Zeichen decken die Sichtbarkeiten ab: + öffentlich, - privat, # geschützt. In UML steht danach der Name und erst hinter dem Doppelpunkt der Typ – in Java ist die Reihenfolge umgekehrt.",
    "r-arr-1a":
        "Ein zweidimensionales Array ist ein Array aus Arrays: Der erste Index wählt die Reihe, der zweite das Fach darin. Beide zählen ab 0, deshalb ist feld[1][0] das erste Fach der zweiten Reihe.",
    "r-arr-1b":
        "Hier braucht es die Zählschleife statt for-each: Nur sie kennt den Index, und genau auf den kommt es an. Mit for-each hätte man zwar die Werte, wüsste aber nicht, an welcher Position sie stehen.",
    "r-col-1b":
        "keySet liefert alle Schlüssel, get holt den Wert dazu – so durchläuft man eine Map. Auf die Reihenfolge sollte man sich nicht verlassen: Eine HashMap ordnet nach internen Regeln, nicht nach dem Einfügen.",
    "r-enum-1a":
        "Weil im enum alle Werte aufgezählt sind, kann Java nachrechnen, ob jeder Fall behandelt wird – deshalb ist hier kein default nötig. Kommt später ein Wert dazu, meldet der Compiler genau diese Stelle.",
    "r-con-1a":
        "Erst alle Aufgaben einreichen, dann die Ergebnisse einsammeln – so laufen sie nebeneinander. Würde man nach jedem submit sofort get aufrufen, wartete man jedes Mal und hätte nichts gewonnen.",
    "s-easy-1":
        "Doppelte Anführungszeichen stehen für Text beliebiger Länge, einfache für genau ein Zeichen (char). Verwechselt man sie, meldet der Compiler einen Fehler – 'Hallo' ist kein gültiges einzelnes Zeichen.",
    "s-easy-3":
        "Java rechnet wie ein Taschenrechner, samt Punkt vor Strich. Wichtig wird das bei gemischten Ausdrücken: 2 + 3 * 4 ergibt 14 und nicht 20, weil die Multiplikation zuerst dran ist.",
    "s-easy-4":
        "if braucht eine Ja-Nein-Frage, damit es sich entscheiden kann. Ein Vergleich wie alter >= 18 liefert genau das: true oder false. Ein Text oder eine Zahl wären keine Frage – Java lehnt sie deshalb ab.",
    "s-easy-5":
        "Eine Schleife trennt die Anweisung von der Anzahl: Man schreibt einmal, was passieren soll, und einmal, wie oft. Dadurch funktioniert derselbe Code für drei Runden genauso wie für dreitausend.",
    "s-easy-7":
        "Der Index ist ein Abstand vom Anfang, kein Abzählen – deshalb beginnt er bei 0. Daraus folgt die Regel, die am häufigsten Fehler verursacht: Das letzte Fach hat die Nummer length - 1.",
    "s-easy-8":
        "Die Klasse ist die Kuchenform, new backt daraus einen echten Kuchen. Deshalb kann es zu einer Klasse beliebig viele Objekte geben – jedes mit eigenen Werten in seinen Feldern.",
    "s-fill-1":
        "Der Typ steht vor dem Namen und legt fest, was in die Box darf. Java prüft das schon beim Übersetzen: Ein Text in einer int-Box wäre kein Fehler zur Laufzeit, sondern fällt sofort auf.",
    "s-fill-2":
        "final versiegelt die Box nach der ersten Füllung – jede weitere Zuweisung lehnt der Compiler ab. Konstanten schreibt man deshalb oft in Großbuchstaben, damit man sie beim Lesen sofort erkennt.",
    "s-fill-3":
        "punkte += 5 ist die Kurzform für punkte = punkte + 5: Der alte Wert wird gelesen, verändert und wieder in dieselbe Box gelegt. Solche Kurzformen gibt es für alle Rechenarten, auch -=, *= und /=.",
    "s-fill-4":
        "if stellt die Frage, else fängt alles Übrige auf. Genau einer der beiden Blöcke läuft – nie beide. Ein else ohne vorheriges if gibt es nicht, es gehört immer zu einer Frage.",
    "s-fill-5":
        "Die drei Teile im Kopf beantworten drei Fragen: Wo fängt es an, wie lange läuft es, was passiert nach jeder Runde. Dass alles in einer Zeile steht, macht auf einen Blick sichtbar, wie oft die Schleife läuft.",
    "s-fill-7":
        "Der Rückgabetyp vor dem Namen ist ein Versprechen; return löst es ein. Java prüft beim Übersetzen, dass auf jedem Weg ein return steht – so kann keine Methode versehentlich ohne Ergebnis enden.",
    "s-fill-8":
        "Der Doppelpunkt liest sich als „für jedes w in werte“. Die Schleife übernimmt das Durchzählen selbst – dafür weiß man nicht, an welcher Position man gerade ist.",
    "s-fill-9":
        "toUpperCase liefert einen neuen Text zurück; das Original bleibt unverändert, weil ein String in Java nicht veränderbar ist. Wer das Ergebnis behalten will, muss es also auch irgendwo hinlegen.",
    "s-fill-11":
        "extends holt sich alles von der Eltern-Klasse, @Override kündigt an, dass eine geerbte Methode ersetzt wird. Der Hinweiszettel ist nicht Pflicht, aber nützlich: Java meldet damit Tippfehler im Namen sofort.",
    "s-fill-12":
        "add hängt hinten an, size zählt nach. Anders als beim Array muss die Größe nicht vorher feststehen – die Liste besorgt sich bei Bedarf selbst mehr Platz.",
    "s-fill-13":
        "put braucht zwei Angaben, weil in einer Map jeder Wert an einem Schlüssel hängt. get geht den umgekehrten Weg. Ein zweites put mit demselben Schlüssel legt keinen neuen Eintrag an, sondern überschreibt den alten.",
    "s-fill-14":
        "filter entscheidet, WAS durchkommt, map, WIE es sich verändert – zwei verschiedene Aufgaben, deshalb zwei Stationen. Die Reihenfolge zählt: Erst sieben, dann umwandeln ergibt etwas anderes als umgekehrt.",
    "s-fill-17":
        "push und pop arbeiten am selben Ende des Stapels. Genau deshalb kommt zuerst herunter, was zuletzt drauflag – die Reihenfolge, die man für „Rückgängig“ braucht.",
    "s-code-1":
        "4.99 ist von sich aus ein double – deshalb passt die Box. Mit float müsste ein f dahinter (4.99f), sonst meldet der Compiler, dass die genauere Zahl nicht in die kleinere Box passt.",
    "s-code-2":
        "Der dritte Teil im Schleifenkopf bestimmt die Schrittweite: i += 3 springt jede Runde um drei weiter. Dass der Start ebenfalls 3 ist, passt zu den Vielfachen – mit 0 käme eine 0 zu viel heraus.",
    "s-code-3":
        "/ 2 wäre eine Ganzzahldivision und würde die Hälfte abschneiden – aus 3,5 würde 3. Die 2.0 zwingt Java, in Kommazahlen weiterzurechnen. Eine double-Box allein genügt nicht, die Rechnung selbst muss stimmen.",
    "s-code-4":
        "Die Box für die Summe muss vor der Schleife stehen und bei 0 beginnen. Stünde sie innerhalb, begänne sie in jeder Runde von vorn – am Ende stünde nur der letzte Wert darin.",
    "s-code-6":
        "filter merkt sich nur die Regel; gearbeitet wird erst, wenn am Ende jemand etwas abholt. Deshalb braucht jedes Fließband eine Endstation – hier forEach, sonst passiert überhaupt nichts.",
    "s-code-10":
        "Das TreeSet erledigt zwei Dinge auf einmal: Doppelte fallen beim Einfügen weg, und der Inhalt bleibt immer sortiert. Bei einem HashSet wären die Doppelten zwar auch weg, die Reihenfolge aber unvorhersagbar.",
    "u-gen-3":
        "Das Etikett in den spitzen Klammern prüft der Compiler: Wer versehentlich eine Zahl hineinlegt, erfährt es sofort und nicht erst beim Laufen. Zusätzlich braucht man beim Herausholen nichts umzuwandeln.",
    "u-gen-4":
        "Der Platzhalter macht die Methode für jede Sorte brauchbar, ohne den Code zu verdoppeln. Zählen funktioniert schließlich für Texte genauso wie für Zahlen – der Typ spielt dabei keine Rolle.",
    "u-dat-1":
        "LocalDate ist reiner Kalender: Jahr, Monat, Tag. Diese Trennung ist Absicht – für einen Geburtstag ist eine Uhrzeit sinnlos und würde beim Vergleichen nur stören. Für die Uhrzeit gibt es LocalTime.",
    "u-dat-3":
        "plusDays rechnet Tage dazu und kümmert sich selbst um Monats- und Jahreswechsel. Das Datum selbst bleibt unverändert – zurück kommt ein neues. Wer das Ergebnis braucht, muss es also auffangen.",
    "u-mod-1":
        "Die Lesemethoden heißen wie die Felder: name() und alter(), nicht getName(). Der Record erzeugt sie automatisch – zusammen mit Konstruktor, equals, hashCode und toString.",
    "u-mod-3":
        "Ein Record ist wie ein ausgefülltes Formular: Wer etwas ändern will, füllt ein neues aus. Der Vorteil zeigt sich, wenn mehrere Stellen dasselbe Objekt benutzen – niemand kann es hinter dem Rücken der anderen verändern.",
    "u-enum-1":
        "Weil im enum alle Werte aufgezählt sind, kann Java prüfen, ob jeder Fall behandelt wird – ein default ist deshalb unnötig. Bei Text oder int ginge das nicht, dort sind die Möglichkeiten unbegrenzt.",
    "u-io-1":
        "Der Notizblock sammelt in der Schleife alles ein; erst am Ende entsteht daraus ein Text. Mit text += i entstünde in jeder Runde ein komplett neuer String – bei drei Runden egal, bei Tausenden spürbar.",
    "u-rec-1":
        "Jeder Aufruf verzweigt sich in zwei neue – deshalb wächst der Aufwand rasant. Für fib(7) sind es schon Dutzende Aufrufe, viele davon doppelt. Eine Schleife wäre hier deutlich schneller.",
    "u-rec-2":
        "Der rekursive Aufruf muss das Problem kleiner machen, sonst endet die Kette nie: exponent - 1 nähert sich dem Basisfall 0. Multipliziert wird erst auf dem Rückweg, wenn die inneren Aufrufe fertig sind.",
    "u-pat-2":
        "Die Reihenfolge entscheidet: Der Zweig mit when ist der engere und wird zuerst geprüft. Stünde der allgemeine Integer-Fall oben, käme der Fall mit der Zusatzbedingung nie zum Zug.",
    "v-loop-2":
        "Die Schleife zählt herunter: Startwert oben, Bedingung >= 1, Schritt i--. print bleibt dabei in derselben Zeile, deshalb stehen alle Zahlen hintereinander – samt Komma nach der letzten.",
    "v-lam-2":
        "forEach übernimmt das Durchlaufen und ruft für jedes Element den Block rechts vom Pfeil auf. Man beschreibt also nur noch, WAS passieren soll – die Reihenfolge der Liste bleibt dabei erhalten.",
    "v-grd-1":
        "2, 1 und 2 ergeben im Schnitt 1,67. Mit int fiele der Rest weg und es stünde 1 da. Zu beachten: Auch die Rechnung muss mit Kommazahlen laufen – eine double-Box allein rettet das Ergebnis nicht.",
    "v-grd-3":
        "<= 4 statt < 4 ist der springende Punkt: Note 4 gilt noch als bestanden. Solche Grenzfälle sind die häufigste Fehlerquelle – beim Testen prüft man deshalb zuerst genau sie.",
    "v-todo-5":
        "Der Fragezeichen-Operator wählt zwischen zwei Werten: Bedingung ? dann : sonst. Er ist ein Ausdruck, kein if – deshalb darf er mitten im Text stehen, wo ein if nicht hinpasst.",
    "v-uml-30-5":
        "Ein Klassenkasten lässt sich Zeile für Zeile übersetzen: Name zu class, jedes Attribut zu einem Feld. Nur die Reihenfolge dreht sich – in UML steht der Typ hinter dem Namen, in Java davor.",
    "p-uml-1b":
        "Die Reihenfolge ist immer dieselbe: oben der Name, in der Mitte die Attribute, unten die Methoden. Dadurch findet man sich in jedem Diagramm sofort zurecht, ohne Beschriftungen zu brauchen.",
    "p-uml-2a":
        "Die gefüllte Raute heißt Komposition: Die Teile entstehen mit dem Ganzen und vergehen mit ihm. In Java erzeugt das Haus seine Räume deshalb selbst. Bei einer leeren Raute (Aggregation) bekäme es sie von außen gereicht.",
}
