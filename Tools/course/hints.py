# Tipps für die Aufgaben.
#
# Ein Tipp ist die Zwischenstufe zwischen Feststecken und Lösung aufdecken. Er sagt,
# WO man hinschauen oder WORAN man denken muss – und nennt das Ergebnis gerade nicht.
# Wer den Tipp liest, soll selbst draufkommen; sonst ist es keine Hilfe, sondern die
# Lösung in kleiner Schrift.
#
# Drei Regeln, die der Bauablauf erzwingt (siehe course_source.py und check_course.py):
#   1. Mindestens MINDESTLAENGE_TIPP Zeichen – ein Halbsatz hilft niemandem.
#   2. Bei Auswahl- und Ausgabe-Aufgaben darf die richtige Antwort nicht wörtlich
#      im Tipp stehen.
#   3. Der Tipp darf nicht einfach die Erklärung wiederholen – sonst verrät er
#      nach dem Lesen nichts Neues mehr.

MINDESTLAENGE_TIPP = 25

HINTS = {
    # ------------------------------------------------------------------ syntax
    "t01-1":
        "Überleg, woher Java wissen soll, welche von vielen Methoden die erste ist. "
        "Der Name ist festgelegt und in jedem Java-Programm derselbe.",
    "t01-2":
        "Denk an das Zeichen, das in jeder bisherigen Beispielzeile am Ende stand. "
        "Java richtet sich nicht danach, wo du die Zeile umbrichst.",
    "q-syn-1a":
        "Java ruft diese Methode auf, bevor ein Objekt existiert, und übergibt ihr "
        "die Kommandozeilen-Argumente. Beides muss sich in der Signatur wiederfinden.",
    "q-syn-1b":
        "Das „ln“ steht für „line“. Überleg, was mit dem Schreibcursor passiert, "
        "nachdem der Text ausgegeben wurde.",
    "q-syn-2a":
        "Nur eine der drei Zeilen setzt am Ende einen Umbruch. Schreib die Textstücke "
        "der Reihe nach hintereinander und frag dich erst danach, wo umgebrochen wird.",
    "q-syn-2b":
        "Die mittlere Zeile beginnt mit zwei Schrägstrichen. Was macht der Compiler "
        "mit allem, was danach in derselben Zeile steht?",
    "q-syn-3a":
        "Gesucht ist die Variante ohne Zeilenumbruch danach – also der kürzere der "
        "beiden Ausgabebefehle.",
    "q-syn-3b":
        "Zwei getrennte Anweisungen, jede mit Semikolon am Ende. Nimm den Befehl, "
        "der nach der Ausgabe in die nächste Zeile springt.",
    "s-easy-1":
        "In Java gibt es zwei Arten von Anführungszeichen mit verschiedener Bedeutung: "
        "eine für einzelne Zeichen, eine für ganze Texte. Gesucht ist die für Texte.",
    "x-syn-3a":
        "Geh die fünf Anweisungen einzeln durch und notier nach jeder, ob der Cursor "
        "in derselben Zeile bleibt. Die leere Klammer in der vierten Zeile zählt mit.",
    "x-syn-3b":
        "Bei drei Zeilen stehen die Schrägstriche innerhalb des Textes oder hinter der "
        "fertigen Anweisung. Entscheidend ist die Zeile, bei der sie ganz vorne stehen.",
    "x-syn-4a":
        "Der Rückstrich davor ändert die Bedeutung des nächsten Zeichens: einmal wird "
        "daraus ein Umbruch, einmal ein Anführungszeichen, das den Text nicht beendet.",
    "x-syn-4b":
        "Frag dich, wer main aufruft und was zu diesem Zeitpunkt schon existiert. "
        "Ohne static bräuchte der Aufrufer zuerst etwas, das es noch gar nicht gibt.",
    "x-syn-5a":
        "Drei Ebenen von außen nach innen: Klasse, Methode, Anweisungen. Die Signatur "
        "der Methode ist genau die aus den vorherigen Aufgaben.",
    "x-syn-5b":
        "Die ersten beiden Ausgaben dürfen die Zeile nicht beenden, die letzte schon. "
        "Die Bindestriche gehören mit in die Texte.",
    "y-syn-1":
        "Nur eine einzige Anweisung steht im Rumpf der Methode. Klasse und Methode "
        "selbst geben nichts aus.",

    # --------------------------------------------------------------- variables
    "t02-1":
        "Die Frage ist, ob Nachkommastellen vorkommen können. Für Zahlen ohne Komma "
        "gibt es einen eigenen, kürzeren Typnamen – die Abkürzung von „integer“.",
    "t02-3":
        "Rechne zuerst die zweite Zeile aus, bevor du die Ausgabe zusammensetzt. Das Pluszeichen "
        "zwischen Text und Zahl rechnet nicht, es hängt aneinander.",
    "t02-4":
        "Drei Zeilen legen etwas Neues an, eine überschreibt etwas Vorhandenes. "
        "Schau bei der Zeile mit zwei Anweisungen nach, was vorne in der Deklaration steht.",
    "p-var-1a":
        "Es gibt zwei Typen für Kommazahlen; gesucht ist der übliche mit doppelter Genauigkeit. "
        "Die anderen drei Antworten speichern Ja/Nein, ein Zeichen oder eine ganze Zahl.",
    "p-var-1b":
        "boolean ist der Typ für eine Ja/Nein-Entscheidung. Überleg, wie viele verschiedene "
        "Werte da überhaupt hineinpassen müssen.",
    "p-var-2a":
        "Die zweite Zeile liest den alten Inhalt, rechnet und schreibt das Ergebnis zurück. "
        "Der Text in der Ausgabe bleibt unverändert stehen.",
    "p-var-2b":
        "Sobald eine Kommazahl beteiligt ist, rechnet Java auch das Ergebnis als Kommazahl – "
        "selbst wenn nichts hinter dem Komma steht. Achte auf die Schreibweise der Ausgabe.",
    "p-var-3a":
        "final heißt „endgültig“. Überleg, was das für spätere Zuweisungen bedeutet – "
        "und was es gerade nicht mit Größe, Typ oder Lebensdauer zu tun hat.",
    "q-var-1a":
        "Die Pluszeichen kleben Textstücke aneinander. Setz die drei Teile in der Reihenfolge "
        "zusammen, in der sie dastehen, und achte auf Komma und Leerzeichen.",
    "q-var-1b":
        "Die zweite Zeile kopiert den Wert, sie verknüpft die beiden Boxen nicht. "
        "Die dritte Zeile ändert deshalb nur eine von beiden.",
    "q-var-2a":
        "var spart dir nur das Tippen des Typs – Java liest ihn aus dem Wert rechts ab. "
        "Überleg, welchen Typ 42 hat und ob er sich danach noch ändern kann.",
    "q-var-2b":
        "Ein char wird ohne Anführungszeichen ausgegeben, ein boolean als sein Wortlaut. "
        "Das Leerzeichen dazwischen steht im Text der Ausgabe.",
    "s-easy-2":
        "Schüler gibt es nur ganz, nie 23,5 davon – und gezählt wird, nicht geschrieben. "
        "Damit fallen drei der vier Typen weg.",
    "s-fill-1":
        "Vorne der Typ für ganze Zahlen, hinten der Wert ohne Anführungszeichen und ohne Komma. "
        "30 ist hier eine Zahl, kein Text.",
    "s-fill-2":
        "Gesucht ist das Schlüsselwort, das vor den Typ gesetzt wird und die Box versiegelt. "
        "Es heißt auf Englisch so viel wie „endgültig“.",
    "s-code-1":
        "Zwei Zeilen: erst Typ, Name und Wert, dann die Ausgabe. Für 4.99 brauchst du den Typ "
        "mit Nachkommastellen, und der Punkt ist das Dezimaltrennzeichen.",
    "x-var-4a":
        "Java füllt kleinere Behälter klaglos in größere um. Problematisch ist die Richtung, "
        "bei der etwas verloren ginge – schau, wo Nachkommastellen abgeschnitten werden müssten.",
    "x-var-5a":
        "Drei Deklarationen mit den passenden Typen, dann eine Ausgabe, in der du die Werte "
        "mit Pluszeichen zwischen die festen Textstücke setzt. Achte auf Komma und Leerzeichen.",

    # --------------------------------------------------------------- operators
    "t03-1":
        "Das Prozentzeichen rechnet nicht in Prozent, sondern liefert den Rest der Division. "
        "Frag dich: Wie oft passt 3 ganz in 7, und was bleibt übrig?",
    "t03-2":
        "Zwei Zeilen, zwei Operatoren. Bei zwei ganzen Zahlen schneidet die Division die "
        "Nachkommastellen ab, das Prozentzeichen liefert genau den abgeschnittenen Rest.",
    "t03-3":
        "Gesucht ist der Operator, der eine Variable um genau eins erhöht, ohne dass du "
        "die Eins hinschreiben musst. Er besteht aus zwei gleichen Zeichen.",
    "t03-4":
        "Rechne die drei Zeilen der Reihe nach durch, bevor du die Bedingung prüfst. "
        "Dann beide Teilbedingungen einzeln beurteilen: Das doppelte Und verlangt beide.",
    "p-op-1a":
        "Wie oft passt 4 vollständig in 9, und was bleibt dann liegen? "
        "Genau dieser Rest ist das Ergebnis.",
    "p-op-1b":
        "5 passt hier glatt hinein. Überleg, was übrig bleibt, wenn nichts übrig bleibt.",
    "p-op-2a":
        "Beide Zeilen arbeiten mit denselben zwei Zahlen. Die erste fragt, wie oft 4 ganz "
        "hineinpasst, die zweite, was danach liegen bleibt.",
    "p-op-2b":
        "Zwei Schritte nacheinander auf derselben Box: erst die Kurzform mit dem Pluszeichen, "
        "dann die Erhöhung um eins. Rechne der Reihe nach.",
    "p-op-3a":
        "Solange beide Zahlen ganze Zahlen sind, wirft Java die Nachkommastellen weg. "
        "Es genügt, eine der beiden Seiten zur Kommazahl zu machen.",
    "q-op-1a":
        "Die Kurzformen wirken nacheinander auf dieselbe Box, nicht gleichzeitig. "
        "Erst abziehen, dann verdoppeln – die Reihenfolge ändert das Ergebnis.",
    "q-op-2a":
        "Das doppelte Kaufmanns-Und ist streng. Überleg, wie viele der beiden Bedingungen "
        "erfüllt sein müssen, damit das Ganze durchgeht.",
    "q-op-2b":
        "Zwei getrennte Prüfungen: Ist 7 größer als 5? Und bleibt beim Teilen durch 2 "
        "ein Rest von null? Jede liefert ein Wort, dazwischen steht ein Leerzeichen.",
    "q-op-3a":
        "Eine Stunde hat 60 Minuten. Die ganzen Stunden bekommst du mit der Division, "
        "den Rest mit dem Prozentzeichen – beide arbeiten mit derselben Zahl 60.",
    "s-easy-3":
        "Ein einfaches Malnehmen. Der Stern ist in Java das Zeichen für die Multiplikation, "
        "er hängt die Zahlen nicht aneinander.",
    "s-fill-3":
        "Gesucht ist die Kurzform für „nimm den alten Wert und zähl etwas dazu“. "
        "Sie besteht aus dem Rechenzeichen und dem Gleichheitszeichen.",
    "x-op-2a":
        "Die ersten beiden Zeilen rechnen mit ganzen Zahlen. In der dritten wird eine Zahl "
        "vorher umgewandelt – das ändert, ob Nachkommastellen erhalten bleiben.",
    "x-op-3b":
        "Das doppelte Und bindet stärker als das doppelte Oder, wird also zuerst ausgewertet. "
        "Fass den vorderen Teil zu einem Wert zusammen und prüf dann das Oder.",
    "x-op-5a":
        "Eine Minute hat 60 Sekunden. Die vollen Minuten liefert die Division, die übrigen "
        "Sekunden das Prozentzeichen. Die Einheiten gehören als Text in die Ausgabe.",

    # ------------------------------------------------------------ conditionals
    "t04-1":
        "In die Klammern kommt etwas, das eindeutig mit ja oder nein beantwortbar ist. "
        "Ein Text oder eine Zahl allein sagt Java nicht, ob abgebogen werden soll.",
    "t04-2":
        "Setz den Wert 16 in die Bedingung ein und prüf, ob sie zutrifft. "
        "Genau einer der beiden Blöcke läuft – nie beide, nie keiner.",
    "t04-3":
        "Gesucht ist der Operator, der den Rest einer Division liefert. "
        "„Rest ist null“ heißt, die Division geht glatt auf.",
    "t04-4":
        "Java prüft die Bedingungen von oben nach unten und steigt beim ersten Treffer aus. "
        "Geh die Kette mit 72 durch und halt bei der ersten Bedingung, die zutrifft.",
    "p-if-1a":
        "Prüf die Bedingung mit dem konkreten Wert 20. Beachte, dass „größer oder gleich“ "
        "die Grenze selbst noch einschließt.",
    "p-if-1b":
        "Geh die Kette von oben nach unten durch. Wenn keine der beiden Bedingungen zutrifft, "
        "bleibt nur der letzte Block übrig.",
    "p-if-2a":
        "Teilbar heißt: Es bleibt nichts übrig. Gesucht ist der Operator, der genau "
        "diesen Rest berechnet.",
    "p-if-2b":
        "Von oben nach unten prüfen und beim ersten Treffer stoppen. Mit 55 scheitern "
        "die ersten beiden Bedingungen – die dritte nicht.",
    "q-if-1a":
        "Das switch vergleicht den Inhalt von tier mit den Fällen. Such den Fall, "
        "dessen Text genau passt, und schau, was auf dessen Pfeil folgt.",
    "q-if-1b":
        "Ein Fall darf mehrere Werte durch Komma auflisten. Such die Zeile, "
        "in der die 7 vorkommt.",
    "q-if-2a":
        "Drei Möglichkeiten, also eine Kette aus if, else if und else. Prüf erst auf "
        "größer null, dann auf kleiner null – der Rest bleibt für den letzten Block.",
    "s-easy-4":
        "Java muss aus den Klammern ablesen können, ob es abbiegen soll oder nicht. "
        "Nur eine der vier Antworten liefert diese Entscheidung.",
    "s-fill-4":
        "Vorne das Schlüsselwort, das die Bedingung einleitet, hinten das für den "
        "Sonst-Fall. Beide sind englische Wörter mit zwei bzw. vier Buchstaben.",
    "x-cond-1a":
        "Ein einzelnes Gleichheitszeichen weist zu, es fragt nicht. Zum Vergleichen "
        "von Zahlen braucht Java ein Zeichen mehr.",
    "x-cond-1b":
        "Überleg, was ein if überhaupt tut: Es entscheidet nur, ob ein Block läuft. "
        "Ohne else gibt es schlicht keinen zweiten Block.",
    "x-cond-2a":
        "Die letzte Ausgabe steht außerhalb der Verzweigung. Überleg getrennt, "
        "welcher Block läuft und was danach auf jeden Fall noch passiert.",
    "x-cond-3b":
        "Hier wird nicht ausgegeben, sondern nur zugewiesen; die Ausgabe kommt ganz am Ende. "
        "Achte bei 75 auf die zweite Bedingung – „größer oder gleich“ schließt die Grenze ein.",
    "x-cond-5a":
        "Ein Fall kann mehrere Werte durch Komma aufnehmen, für alles Übrige gibt es "
        "den Auffang-Fall. Hinter jedem Pfeil steht die Ausgabe.",
    "y-cond-1":
        "Hier gibt es keinen Sonst-Fall. Prüf nur, ob die eine Bedingung mit 10 zutrifft.",

    # ------------------------------------------------------------------- loops
    "t05-1":
        "Zähl die Werte auf, die i nacheinander annimmt, solange die Bedingung noch gilt. "
        "Der Start bei 0 verschiebt das Ergebnis gegenüber einem Start bei 1.",
    "t05-2":
        "Schreib die Werte auf, die i durchläuft. Der Befehl ist der ohne Zeilenumbruch, "
        "und an jede Zahl wird ein Leerzeichen gehängt.",
    "t05-3":
        "Herunterzählen bis einschließlich 1 heißt: Die Bedingung muss bei 1 noch gelten "
        "und bei 0 nicht mehr. Hinten steht der Operator, der um eins verringert.",
    "t05-4":
        "Zwei Abbruchregeln mit verschiedener Wirkung: Die eine überspringt nur die "
        "aktuelle Runde, die andere verlässt die Schleife ganz. Addiere nur die Werte, "
        "die tatsächlich bis zur letzten Zeile durchkommen.",
    "p-loop-1a":
        "Schreib die Werte auf, die i der Reihe nach annimmt. Hier wird mit Zeilenumbruch "
        "ausgegeben, jede Zahl steht also allein.",
    "p-loop-1b":
        "n startet bei 3 und wird nach jeder Ausgabe um eins kleiner. Die Schleife hört auf, "
        "sobald die Bedingung nicht mehr gilt – 0 wird also nicht mehr ausgegeben.",
    "p-loop-2a":
        "Die Schleife addiert nacheinander alle Zahlen von 1 bis 5 auf. "
        "Rechne Runde für Runde mit und notier den Zwischenstand.",
    "p-loop-2b":
        "Das continue bricht nur die aktuelle Runde ab, bevor die Ausgabe erreicht wird. "
        "Übrig bleiben genau die Zahlen, bei denen die Bedingung nicht zutrifft.",
    "p-loop-3a":
        "Rückwärts heißt: hoch anfangen, die Bedingung mit „größer oder gleich“ formulieren "
        "und in jeder Runde um eins verringern statt erhöhen.",
    "q-loop-1a":
        "Der dritte Teil der Schleife erhöht hier nicht um eins, sondern um zwei. "
        "Schreib die Werte auf, die i dadurch annimmt.",
    "q-loop-1b":
        "Diese Schleife gibt erst aus und prüft dann. zahl verdoppelt sich jede Runde – "
        "notiere die Werte und halt an, sobald die Bedingung nicht mehr gilt.",
    "q-loop-2a":
        "Das break verlässt die Schleife sofort, und zwar bevor die Ausgabe in derselben "
        "Runde erreicht wird. Die auslösende Zahl erscheint deshalb nicht mehr.",
    "q-loop-2b":
        "Die innere Schleife läuft für jeden Durchgang der äußeren komplett durch. "
        "Rechne die Produkte zeilenweise aus; der Umbruch kommt nach jeder äußeren Runde.",
    "s-easy-5":
        "Der Name sagt es schon: Es geht im Kreis. Überleg, was dadurch mehrfach passiert, "
        "ohne dass du es mehrfach hinschreiben musst.",
    "s-fill-5":
        "Drei Teile, durch Semikolon getrennt: Startwert, Bedingung, Schrittweite. "
        "Die 3 soll noch mitlaufen – die Bedingung muss die Grenze also einschließen.",
    "s-fill-6":
        "Gesucht ist die Schleife, die nur eine Bedingung braucht und keine Zählvariable "
        "mitführt. Ihr englischer Name bedeutet „solange“.",
    "s-code-2":
        "Du kannst bei 3 starten und in jeder Runde um 3 erhöhen – dann brauchst du gar "
        "nicht zu rechnen, welche Zahl ein Vielfaches ist. Ausgabe ohne Zeilenumbruch.",
    "v-loop-2":
        "i zählt herunter. An jede Zahl wird ein Komma gehängt, auch an die letzte – "
        "es steht zwischen den Zahlen, nicht dazwischen eingefügt.",
    "x-loop-5a":
        "Die Schleife läuft von 1 bis 5. In jeder Zeile stehen drei Bausteine: die feste 7, "
        "der Zähler und das Produkt aus beiden. Klammere die Rechnung, sonst hängt Java sie an.",

    # ----------------------------------------------------------------- methods
    "t06-1":
        "void ist das englische Wort für „leer“. Überleg, worauf es sich bezieht – "
        "auf den Rumpf der Methode oder auf das, was sie zurückliefert.",
    "t06-2":
        "Beide Aufrufe liefern je eine Zahl zurück; erst danach greift das Pluszeichen. "
        "Rechne die beiden Rückgaben einzeln aus und addiere sie.",
    "t06-3":
        "Vorne steht der Typ dessen, was herauskommt – hier werden zwei ganze Zahlen "
        "verglichen. Hinten fehlt das Schlüsselwort, das den Wert hinausreicht.",
    "t06-4":
        "Java wählt die Methode anhand der Anzahl und Typen der übergebenen Werte aus. "
        "Zähl, wie viele Werte im Aufruf stehen.",
    "p-meth-1a":
        "Setz die 4 für x ein und rechne den Ausdruck hinter dem return aus. "
        "Der Rückgabewert landet direkt in der Ausgabe.",
    "p-meth-1b":
        "void sagt nur etwas über das Ergebnis aus, nicht über den Inhalt der Methode. "
        "Eine solche Methode darf durchaus etwas tun – nur zurückreichen tut sie nichts.",
    "p-meth-2a":
        "Das Quadrat einer ganzen Zahl bleibt eine ganze Zahl – daraus folgt der Typ vorne. "
        "Hinten fehlt das Schlüsselwort, das den Wert an den Aufrufer weitergibt.",
    "p-meth-3a":
        "Der Rückgabetyp ist der für ja/nein. Du brauchst kein if: Der Vergleich "
        "zahl > 0 ergibt schon selbst genau diesen Wert.",
    "q-meth-1a":
        "Prüf die Bedingung mit 3 und 8. Trifft sie nicht zu, wird das erste return "
        "übersprungen und die Methode läuft bis zur letzten Zeile weiter.",
    "q-meth-1b":
        "Beide Methoden dürfen gleich heißen, weil sie verschieden viele Werte annehmen. "
        "Ordne jedem Aufruf die passende zu und rechne getrennt.",
    "q-meth-2a":
        "Sie gibt nur aus und liefert nichts zurück – daraus folgt der Rückgabetyp. "
        "Den Namen setzt du mit Pluszeichen zwischen die beiden festen Textstücke.",
    "s-easy-6":
        "Denk an die Methode als Rezept: Irgendwann ist es fertig und liefert ein Gericht ab. "
        "Genau diesen Moment beschreibt das Schlüsselwort.",
    "s-fill-7":
        "Das Doppelte einer ganzen Zahl ist wieder eine ganze Zahl. Hinten fehlt das "
        "Schlüsselwort, ohne das der berechnete Wert nirgendwo ankommt.",
    "s-code-3":
        "Der Durchschnitt zweier ganzer Zahlen hat oft Nachkommastellen – also darf nicht "
        "durch eine ganze 2 geteilt werden. Klammere die Summe vor dem Teilen.",
    "x-meth-1a":
        "Vergleich die Methode mit einem Rezept: Die runden Klammern stehen für das, "
        "was von außen hineingereicht wird, nicht für das Ergebnis.",
    "x-meth-1b":
        "Zwei der Antworten haben mit Ausgabe und Abbruch zu tun, eine ist ein Rückgabetyp. "
        "Gesucht ist das Schlüsselwort, das den Wert an den Aufrufer weiterreicht.",
    "x-meth-2a":
        "Bei der zweiten Zeile steckt ein Aufruf im anderen. Rechne von innen nach außen: "
        "erst das Ergebnis des inneren Aufrufs, das geht dann in den äußeren hinein.",
    "x-meth-2b":
        "Java übergibt eine Kopie des Wertes, nicht die Box selbst. Frag dich, was die "
        "Zuweisung in der Methode dadurch überhaupt erreicht.",
    "x-meth-5a":
        "Zurückgeben statt ausgeben: Im Rumpf darf kein println stehen. Bau den Text "
        "mit Pluszeichen zusammen und reiche ihn hinaus.",
    "y-meth-1":
        "Die Methode wird zweimal aufgerufen und tut jedes Mal dasselbe. "
        "Ihr Rumpf enthält genau eine Ausgabe mit Zeilenumbruch.",
    "z-meth-4":
        "Zwei Methoden dürfen denselben Namen tragen, solange sich ihre Parameterlisten "
        "unterscheiden. Die eine bekommt eine Seite, die andere zwei.",

    # ------------------------------------------------------------------ arrays
    "t07-1":
        "Java zählt nicht wie ein Mensch von eins, sondern gibt den Abstand zum Anfang an. "
        "Beim ersten Fach beträgt dieser Abstand nichts.",
    "t07-3":
        "Die for-each-Schleife braucht kein Semikolon und keinen Zähler, sondern nur ein "
        "einzelnes Zeichen zwischen der Laufvariablen und dem Array. Sprich es als „aus“.",
    "p-arr-1a":
        "Der Index in den eckigen Klammern gibt den Abstand zum Anfang an. "
        "Abstand null bedeutet das allererste Fach.",
    "p-arr-1b":
        "length ist kein Aufruf, sondern eine Eigenschaft – und sie nennt die Anzahl der "
        "Fächer, nicht den höchsten Index. Zähl die Einträge in den geschweiften Klammern.",
    "p-arr-2a":
        "Die for-each-Schleife besucht alle Fächer in ihrer Reihenfolge. Ausgegeben wird "
        "ohne Zeilenumbruch, an jeden Wert wird ein Leerzeichen gehängt.",
    "q-arr-1a":
        "new int[3] legt die Fächer an, aber niemand hat sie gefüllt. Überleg, was Java "
        "in ein leeres Zahlenfach schreibt – und nur eines der beiden wurde danach gesetzt.",
    "q-arr-1b":
        "Die Schleife addiert alle drei Werte nacheinander auf summe. "
        "Rechne Runde für Runde mit.",
    "q-arr-2a":
        "Nimm den ersten Wert als vorläufig kleinsten an und vergleich ihn mit jedem weiteren. "
        "Ist einer kleiner, merkst du dir diesen. Mit 0 zu starten ginge hier schief.",
    "r-arr-1a":
        "Zwei Klammerpaare, zwei Ebenen: Der erste Index wählt die innere Liste aus, "
        "der zweite darin das Fach. Beide zählen ab null.",
    "r-arr-1b":
        "Hier läuft der Index mit, nicht der Wert. Die Bedingung prüft den Index auf gerade – "
        "sammle die Werte an den Positionen, die durchkommen.",
    "s-easy-7":
        "Der Index ist der Abstand zum Anfang, keine laufende Nummer. "
        "Beim ersten Fach ist dieser Abstand null.",
    "s-fill-8":
        "Kein Semikolon, kein Zähler – zwischen Laufvariable und Array steht nur ein "
        "einzelnes Satzzeichen. Lies es als „nimm jedes w aus werte“.",
    "s-code-4":
        "Leg vor der Schleife eine Summe mit dem Startwert null an, zähl darin jedes Fach "
        "auf und gib sie erst nach der Schleife aus.",
    "x-arr-1a":
        "Beim Array ist die Länge eine Eigenschaft, kein Methodenaufruf – anders als bei "
        "String und Liste. Achte also auf die runden Klammern.",
    "x-arr-2a":
        "Drei Zeilen: die Anzahl der Fächer, das erste Fach und das letzte. Das letzte "
        "liegt bei der Anzahl minus eins, weil der erste Index null ist.",
    "x-arr-2b":
        "charAt(0) holt aus jedem Wort das allererste Zeichen. Die Ausgabe erfolgt ohne "
        "Umbruch, die Zeichen landen also direkt hintereinander.",
    "x-arr-3b":
        "Java füllt frisch angelegte Fächer mit einem Standardwert. Bei Zahlen ist das "
        "ein neutraler Wert, bei Objekten das Wort für „hier liegt noch nichts“.",
    "x-arr-5a":
        "Ein Zähler vor der Schleife, in der Schleife eine Bedingung, und nur bei Treffer "
        "wird erhöht. Achte darauf, dass „größer als 10“ die 10 selbst nicht mitzählt.",

    # ----------------------------------------------------------------- strings
    "t07-2":
        "Drei Fragen an dasselbe Wort: Wie viele Zeichen? Welches Zeichen an Position 1 – "
        "gezählt ab null? Und wie sieht es in Großbuchstaben aus?",
    "t07-4":
        "Das doppelte Gleichheitszeichen vergleicht, ob es dasselbe Objekt ist; equals "
        "vergleicht den Inhalt. new erzeugt bewusst ein zweites Objekt. Beim substring ist "
        "der erste Index dabei, der zweite nicht mehr.",
    "p-str-1a":
        "Zähl die Zeichen des Wortes einzeln ab – Großbuchstaben zählen genauso wie kleine. "
        "length() nennt die Anzahl, nicht den höchsten Index.",
    "p-str-1b":
        "Der erste Index ist die Startposition und gehört dazu, der zweite ist die erste "
        "Position, die nicht mehr mitkommt. Gezählt wird ab null.",
    "p-str-2a":
        "Das doppelte Gleichheitszeichen fragt, ob es dieselbe Schachtel ist, nicht ob "
        "derselbe Inhalt darin liegt. Gesucht ist die Methode für den Inhalt.",
    "q-str-1a":
        "Die Methode verwandelt jedes Zeichen in seine große Form. Das Wort selbst bleibt "
        "dabei unverändert, ausgegeben wird nur das Ergebnis.",
    "q-str-1b":
        "Beide Texte haben denselben Inhalt – und genau darauf prüft equals. "
        "Danach zähl die Zeichen des Wortes.",
    "q-str-2a":
        "Gesucht ist die Methode, die ein einzelnes Zeichen an einer Position liefert. "
        "Ihr Name enthält das englische Wort für Zeichen und das Wörtchen „an“.",
    "r-str-1a":
        "contains fragt, ob das Stück irgendwo im Satz vorkommt – egal an welcher Stelle. "
        "Such das Wort im Satz und beachte die Groß- und Kleinschreibung.",
    "r-str-1b":
        "trim schneidet Leerzeichen am Anfang und am Ende weg, aber nicht in der Mitte. "
        "Die eckigen Klammern sind nur da, damit du siehst, wo der Text beginnt und endet.",
    "r-str-2a":
        "split zerlegt den Satz an jedem Komma und liefert die Stücke als Array. "
        "Zähl die Stücke, und denk daran, dass der Index bei null anfängt.",
    "r-str-3a":
        "Es gibt eine Methode, die genau das fragt – ihr Name enthält das englische Wort "
        "für „beginnt“. Ihr Ergebnis ist schon true oder false, du brauchst kein if.",
    "s-fill-9":
        "Der Methodenname setzt sich aus „to“, „upper“ und „case“ zusammen und wird in "
        "Java in Binnen-Großschreibung geschrieben. Die Klammern bleiben leer.",
    "x-str-1a":
        "Beim String ist die Länge ein Methodenaufruf, beim Array dagegen eine Eigenschaft. "
        "Achte deshalb genau auf die runden Klammern.",
    "x-str-1b":
        "Das doppelte Gleichheitszeichen prüft bei Objekten die Identität, nicht den Inhalt. "
        "Ein einzelnes Gleichheitszeichen weist sogar nur zu.",
    "x-str-3a":
        "Drei Schritte: Die ersten vier Zeichen ab Position null, danach die Position des "
        "gesuchten Zeichens – ab null gezählt – und zuletzt alles in groß.",
    "x-str-3b":
        "trim entfernt nur außen. replace tauscht ein Textstück gegen ein anderes. "
        "isBlank fragt, ob nach dem Wegdenken der Leerzeichen noch etwas übrig bleibt.",
    "x-str-4a":
        "split zerlegt an jedem Komma, join fügt wieder zusammen – aber mit einem anderen "
        "Trennzeichen. Achte darauf, welcher Index zum zweiten Stück gehört.",
    "x-str-5a":
        "Drei Schritte: erst alles klein machen, dann eine umgedrehte Fassung erzeugen "
        "– dafür gibt es StringBuilder mit reverse() – und zuletzt beide mit equals vergleichen.",
    "x-str-5b":
        "Zerleg das Wort in zwei Teile: das erste Zeichen und den Rest ab Position 1. "
        "Nur den ersten Teil groß machen und beide mit dem Pluszeichen wieder zusammenhängen.",
    "y-str-2b":
        "Eine Zeile genügt: die Methode für Großbuchstaben direkt in der Ausgabe aufrufen. "
        "Die Klammern der Methode bleiben leer.",

    # --------------------------------------------------------------------- oop
    "t08-1":
        "Ein Objekt entsteht nicht von selbst – es braucht ein Schlüsselwort davor, "
        "das Java sagt: bau mir eines. Danach folgt der Klassenname mit Klammern.",
    "t08-2":
        "Parameter und Feld heißen hier gleich. Überleg, was das vorangestellte this "
        "bewirkt, wenn links und rechts derselbe Name steht.",
    "t08-3":
        "Jedes new erzeugt ein eigenes Objekt mit eigenem Zählerstand. Zähl getrennt mit, "
        "wie oft jedes der beiden Objekte angeklickt wird.",
    "t08-4":
        "Ein Konstruktor trägt immer exakt den Namen seiner Klasse und hat keinen Rückgabetyp. "
        "Im Getter fehlt das Schlüsselwort, das den Wert hinausreicht.",
    "p-oop-1a":
        "Der Konstruktor läuft genau einmal, direkt beim new. Überleg, was in diesem "
        "Moment sinnvollerweise passieren soll.",
    "p-oop-1b":
        "Zwei Objekte, zwei getrennte Zählerstände. Verfolge für a und b einzeln, "
        "wie oft klick() aufgerufen wird.",
    "p-oop-2a":
        "private ändert nichts an Tempo oder Speicher. Überleg, was passieren könnte, "
        "wenn jeder von außen jeden beliebigen Wert hineinschreiben dürfte.",
    "q-oop-1a":
        "Der Konstruktor speichert den übergebenen Text im Feld des Objekts. "
        "Danach wird genau dieses Feld ausgelesen.",
    "q-oop-1b":
        "this taucht erst auf, wenn ein konkretes Objekt existiert. Überleg, worauf es "
        "sich im Konstruktor beziehen kann – auf den Bauplan oder auf das gebaute Stück.",
    "q-oop-2a":
        "Drei Bausteine: zwei private Felder, ein Konstruktor mit dem Namen der Klasse "
        "und ohne Rückgabetyp, ein Getter. Bei gleichen Namen hilft this beim Zuweisen.",
    "s-easy-8":
        "Die Klasse ist der Bauplan und bleibt, was sie ist. Überleg, was beim new "
        "zusätzlich entsteht – etwas Einzelnes, das nach diesem Plan gefertigt wurde.",
    "s-fill-10":
        "Feld und Parameter tragen denselben Namen. Gesucht ist das Wörtchen, das sagt: "
        "Die linke Seite gehört zum Objekt, nicht zur Zutatenliste.",
    "s-code-7":
        "Ein privates Feld für den Stand, eine Methode ohne Rückgabewert zum Erhöhen und "
        "ein Getter mit dem passenden Typ. Ein double-Feld startet von selbst bei null.",
    "x-oop-1a":
        "Denk an einen Bauplan und an das Haus, das danach gebaut wird. Von einem Plan "
        "lassen sich beliebig viele Häuser bauen, die sich dann unterscheiden.",
    "x-oop-2a":
        "Der Getter ist das kleine Fenster in eine geschlossene Klasse. Überleg, was er "
        "herausgibt – den Wert selbst oder den Zugriff auf das Feld.",
    "x-oop-3a":
        "Zwei getrennte Objekte mit je eigenem Stand. Zähl für a und b einzeln mit "
        "und beachte, dass hier jede Zahl in einer eigenen Zeile ausgegeben wird.",
    "x-oop-4a":
        "Die zweite Zeile kopiert kein Objekt, sondern nur den Verweis darauf. "
        "Danach zeigen beide Namen auf dieselbe Box – prüf, was das für beide Ausgaben heißt.",
    "x-oop-5a":
        "Ein privates int-Feld, eine Methode ohne Rückgabewert, die den Betrag aufaddiert, "
        "und ein Getter mit passendem Rückgabetyp. Ein int-Feld startet von selbst bei null.",
    "y-oop-1":
        "Das Feld hat schon im Bauplan einen Startwert. Der Konstruktor fehlt hier, "
        "das Objekt entsteht trotzdem – und das Feld wird direkt ausgelesen.",

    # ------------------------------------------------------------- inheritance
    "t09-1":
        "Eine der Antworten klingt naheliegend, ist aber kein Java-Wort. Eine andere "
        "gehört zu Interfaces, eine dritte zum Eltern-Aufruf. Gesucht ist „erweitert“.",
    "t09-2":
        "Java vermeidet bewusst, dass ein Kind zwei Eltern-Klassen mit gleichnamigen "
        "Methoden erbt. Für mehrere Quellen gibt es stattdessen Interfaces.",
    "t09-3":
        "Entscheidend ist nicht der Typ der Variablen, sondern welches Objekt wirklich "
        "im Fach liegt. Geh das Array der Reihe nach durch – das dritte erbt von niemandem.",
    "t09-4":
        "Form ist ein Interface, keine Klasse – dafür gibt es ein eigenes Schlüsselwort. "
        "Darüber fehlt die Markierung, die sagt: Diese Methode erfüllt eine Vorgabe.",
    "p-inh-1a":
        "Für Klassen gibt es ein Schlüsselwort, für Interfaces ein anderes. "
        "Gesucht ist das, dessen Name „setzt um“ bedeutet.",
    "p-inh-1b":
        "Die Variable ist vom Typ der Eltern-Klasse, das Objekt darin ist eine Kuh. "
        "Java entscheidet beim Aufruf nach dem tatsächlichen Objekt.",
    "p-inh-2a":
        "super zeigt immer nach oben in der Vererbungskette. Mit runden Klammern "
        "dahinter geht es nicht um eine Methode, sondern um den Bau des Objekts.",
    "q-inh-1a":
        "Die überschriebene Methode ruft über super die ursprüngliche Fassung mit auf. "
        "Setz deren Rückgabe in den Text ein, den das Kind darum herumbaut.",
    "q-inh-1b":
        "Interfaces enthalten keine eigenen Felder, deshalb gibt es hier keinen Konflikt. "
        "Genau deswegen ist Java an dieser Stelle großzügiger als beim extends.",
    "s-fill-11":
        "Vorne das Schlüsselwort für „erweitert“ zwischen den beiden Klassennamen, "
        "darüber die Markierung mit dem Klammeraffen, die eine Überschreibung kennzeichnet.",
    "u-inh-1":
        "Die Variable ist vom Typ des Interfaces, das Objekt dahinter ist eine Rechnung. "
        "Deren Methode liefert eine Kommazahl – achte auf die Schreibweise.",
    "u-inh-2":
        "Ein Interface ist ein Vertrag. Überleg, wann der Bruch dieses Vertrags auffällt: "
        "schon beim Übersetzen oder erst, wenn das Programm läuft.",
    "u-inh-3":
        "Die Eltern-Klasse hat keinen Konstruktor ohne Parameter, der Name muss also "
        "weitergereicht werden. Gesucht ist das Schlüsselwort, das nach oben zeigt.",
    "x-inh-1a":
        "Vererbt wird alles, worauf das Kind überhaupt zugreifen darf. Überleg, was "
        "private daran ändert – und dass Felder und Methoden gleich behandelt werden.",
    "x-inh-2a":
        "Die Markierung ist für den Compiler gedacht: Er prüft damit, ob es oben wirklich "
        "eine passende Methode gibt. Verwechsle sie nicht mit final oder static.",
    "x-inh-3a":
        "Die Variable hat den Typ der Eltern-Klasse, aber im Speicher liegt eine Kuh. "
        "Beim Aufruf entscheidet das tatsächliche Objekt, nicht der Typ der Variablen.",
    "x-inh-4a":
        "Bevor das Kind gebaut werden kann, muss der geerbte Teil fertig sein. "
        "Java ruft den Eltern-Konstruktor deshalb automatisch zuerst auf.",
    "x-inh-5a":
        "Das Fahrrad erbt mit extends und reicht im eigenen Konstruktor die feste Zahl 2 "
        "nach oben weiter – das muss die allererste Anweisung sein. Die Gänge speichert es selbst.",
    "y-inh-2":
        "Das Auto hat eine eigene Methode und erbt zusätzlich die der Eltern-Klasse. "
        "Beide werden nacheinander aufgerufen, jede gibt eine Zeile aus.",

    # -------------------------------------------------------------- exceptions
    "t10-1":
        "Vier Schlüsselwörter, vier Rollen: eines umschließt den riskanten Teil, eines löst "
        "aus, eines läuft immer. Gesucht ist das, dessen Name „auffangen“ bedeutet.",
    "t10-2":
        "Die Division durch null bricht den try-Block sofort ab – was danach im Block steht, "
        "wird übersprungen. Der letzte Block läuft in jedem Fall, ob Fehler oder nicht.",
    "t10-3":
        "Drei der vier entstehen durch Programmierfehler, die man vermeiden könnte. Die vierte "
        "kommt von außen – ein Dateisystem kann immer ausfallen, egal wie sauber der Code ist.",
    "t10-4":
        "Zwei ähnliche Wörter: Eines kündigt in der Methodensignatur an, das andere löst "
        "hier und jetzt aus. Gesucht ist das kürzere, ohne s am Ende.",
    "p-exc-1a":
        "Ab der Division durch null wird der Rest des try-Blocks übersprungen. "
        "Es läuft also nicht jede Zeile, die dort steht.",
    "p-exc-1b":
        "„Checked“ heißt: Der Compiler prüft es, nicht erst die Laufzeit. Überleg, wozu er "
        "dich dann zwingt – und dass es zwei erlaubte Wege gibt, nicht nur einen.",
    "p-exc-2a":
        "Vorne der Block, der den riskanten Teil umschließt, hinten der, der den Fehler "
        "auffängt. Beide sind kurze englische Wörter.",
    "q-exc-1a":
        "Das Array hat nur zwei Fächer, Index 5 gibt es nicht. Der catch-Block greift, "
        "und der letzte Block läuft danach in jedem Fall.",
    "q-exc-1b":
        "Ein s macht den Unterschied. Eines steht mitten im Code und löst aus, das andere "
        "steht im Methodenkopf und warnt den Aufrufer vor.",
    "q-exc-2a":
        "Integer.parseInt wandelt Text in eine Zahl und beschwert sich, wenn das nicht geht. "
        "Umschließ den Versuch und fang genau diese Beschwerde ab.",
    "s-easy-10":
        "Der Name ist Programm: Es wird etwas versucht. Überleg, was mit dem Code passieren "
        "soll, bei dem das Versuchen überhaupt nötig ist.",
    "s-code-8":
        "Das Sicherheitsnetz gehört in die Schleife, nicht darum herum – sonst bricht nach "
        "dem ersten Fehler alles ab. Die Division durch null meldet eine ArithmeticException.",
    "x-exc-1a":
        "Eine Exception wandert nach oben, bis sie jemand auffängt. Überleg, was passiert, "
        "wenn auf dem ganzen Weg niemand da ist.",
    "x-exc-2a":
        "Index 5 gibt es in einem Array mit zwei Fächern nicht. Der catch-Block greift, "
        "und danach läuft der letzte Block ohnehin.",
    "x-exc-2b":
        "Der Name kommt von „schließlich“. Genau dafür ist der Block da: zum Aufräumen, "
        "und Aufräumen ist in beiden Fällen nötig.",
    "x-exc-3a":
        "getMessage() liefert den Text, den Java selbst an die Exception gehängt hat – "
        "nicht deinen eigenen. Bei der Division durch null ist das eine kurze englische Notiz.",
    "x-exc-4a":
        "Zwei Aufrufe, zwei Verläufe: Beim ersten klappt die Umwandlung und die Rechnung "
        "läuft, beim zweiten greift der catch-Block und hängt den Text an.",
    "x-exc-5a":
        "Das try gehört in die Schleife hinein, damit es nach einem Fehler mit der nächsten "
        "Zahl weitergeht. Gefangen wird die ArithmeticException.",
    "y-exc-1":
        "Die Division durch null unterbricht den try-Block sofort. Die Zeile danach "
        "innerhalb des Blocks wird nie erreicht.",

    # ------------------------------------------------------------- collections
    "t11-1":
        "Vier Kandidaten aus vier verschiedenen Welten: einer gehört zum Stapel, einer "
        "zur Map, einen gibt es in Java gar nicht. Gesucht ist das kürzeste Wort für „dazu“.",
    "t11-3":
        "remove mit einem Text sucht den Eintrag, nicht die Position. Danach rutschen die "
        "übrigen Einträge nach – schreib die Liste nach dem Entfernen neu auf.",
    "t11-4":
        "getOrDefault holt den bisherigen Stand oder null, falls es ihn noch nicht gibt. "
        "Gesucht ist die Methode, die den neuen Wert unter dem Schlüssel ablegt.",
    "p-col-1a":
        "size() zählt die tatsächlich vorhandenen Einträge. Zähl die add-Aufrufe.",
    "p-col-1b":
        "remove mit einer Zahl meint die Position, nicht den Wert. Gezählt wird ab null – "
        "also fliegt hier der erste Eintrag heraus.",
    "p-col-2a":
        "Eine Map hat jeden Schlüssel nur einmal. Überleg, was das zweite put mit dem "
        "vorhandenen Eintrag macht: ergänzen oder ersetzen?",
    "p-col-3a":
        "Der Schlüssel „b“ wurde nie eingetragen. getOrDefault liefert dann genau das, "
        "was als zweites Argument dabeisteht.",
    "q-col-1a":
        "Der Index zählt ab null, der zweite Eintrag liegt also bei 1. contains prüft, "
        "ob der Wert überhaupt in der Liste steckt.",
    "q-col-1b":
        "Die dritte Zeile liest den alten Wert, rechnet und schreibt unter demselben "
        "Schlüssel zurück. Das ist kein neuer Eintrag – die Größe ändert sich dadurch nicht.",
    "r-col-1a":
        "Bei einer Liste von Zahlen ist remove doppeldeutig: Eine nackte Zahl wäre die "
        "Position. Integer.valueOf erzwingt, dass nach dem Wert gesucht wird.",
    "r-col-1b":
        "keySet() liefert alle Schlüssel. Die Map enthält hier nur einen einzigen Eintrag, "
        "die Schleife läuft also genau eine Runde.",
    "s-easy-9":
        "Drei der vier Fähigkeiten hat ein Array auch. Überleg, was beim Array schon beim "
        "Anlegen endgültig festgelegt wird.",
    "s-fill-12":
        "Beide Male dasselbe kurze Wort zum Einfügen; hinten die Methode, die die Anzahl "
        "nennt – bei Listen heißt sie anders als beim Array.",
    "s-fill-13":
        "Bei der Map heißt Eintragen anders als bei der Liste: Es werden immer zwei Dinge "
        "abgelegt, Schlüssel und Wert. Zum Nachschlagen dient das englische „holen“.",
    "s-code-5":
        "Erst eine Liste anlegen, dann zweimal einfügen, dann mit einer for-each-Schleife "
        "durchlaufen. Jede Ausgabe mit Zeilenumbruch.",
    "x-col-1a":
        "Beide können Objekte speichern, beide haben einen Index. Der Unterschied zeigt "
        "sich, wenn nachträglich ein Eintrag dazukommen soll.",
    "x-col-2a":
        "Eine Liste erlaubt Doppelte – zähl alle drei Einträge. Der Index beginnt bei null, "
        "und contains fragt nach einem Namen, der nie eingefügt wurde.",
    "x-col-3a":
        "Der wiederholte Schlüssel ersetzt nur den Wert, er legt keinen zweiten Eintrag an. "
        "Ein nie eingetragener Schlüssel liefert bei get das Wort für „hier ist nichts“.",
    "x-col-5a":
        "Es gibt eine Methode, die nach einer Bedingung entfernt – ihr Name enthält „remove“ "
        "und „if“. Achte darauf, dass „weniger als vier“ die Vier selbst nicht trifft.",
    "x-col-5b":
        "toCharArray() zerlegt das Wort in einzelne Zeichen. Für jedes holst du den bisherigen "
        "Stand mit getOrDefault und legst ihn um eins erhöht wieder ab.",
    "y-col-1":
        "size() nennt die Anzahl der Einträge. Zähl einfach, wie oft add aufgerufen wurde.",
    "y-col-1b":
        "Die Liste wächst nur beim Hinzufügen, nicht beim Nachfragen. Überleg, was übrig "
        "bleibt, wenn Java an Position 5 nichts findet und nichts erfinden will.",

    # ---------------------------------------------------------- datastructures
    "t20-1":
        "„Zuletzt geändert, zuerst zurückgenommen“ – überleg, welche der vier Strukturen "
        "genau dieses Verhalten hat. Denk an einen Stapel Teller.",
    "t20-2":
        "Ein Set wirft Doppelte weg, und die TreeSet-Variante hält den Rest zusätzlich "
        "sortiert. Die 4 wurde nie eingefügt.",
    "t20-3":
        "push legt oben drauf, pop nimmt oben weg, peek schaut nur hin, ohne zu nehmen. "
        "Verfolg den Stapel Schritt für Schritt.",
    "t20-4":
        "An der Kasse stellt man sich hinten an und wird vorne bedient. Die zweite Zeile "
        "zeigt schon, wie das Anstellen heißt; fürs Abholen gibt es ein Wort mit vier Buchstaben.",
    "t20-5":
        "Ein Set nimmt jeden Wert nur einmal auf – du kannst die Liste direkt beim Anlegen "
        "hineingeben. Danach genügt die Anzahl seiner Einträge.",
    "p-set-1a":
        "Ein Set lässt keine Doppelten zu. Der zweite gleiche Eintrag ändert deshalb nichts.",
    "p-set-1b":
        "push legt oben auf den Stapel. pop nimmt das weg, was zuletzt daraufgelegt wurde – "
        "nicht das, was zuerst kam.",
    "q-ds-1a":
        "TreeSet macht zwei Dinge gleichzeitig: Doppelte verschwinden, und der Rest wird "
        "sortiert. Sortiert wird alphabetisch, Großbuchstaben zuerst.",
    "q-ds-1b":
        "Hier ist es eine Warteschlange, kein Stapel: offer stellt hinten an, poll holt "
        "vorne ab, peek schaut nur nach vorne, ohne jemanden wegzunehmen.",
    "q-ds-2a":
        "Die zuletzt gemachte Änderung soll zuerst weg. Such die Struktur, bei der "
        "das zuletzt Abgelegte auch als Erstes wieder herauskommt.",
    "q-ds-3a":
        "Ein Set kann die Liste direkt beim Anlegen übernehmen und wirft die Doppelten "
        "dabei von selbst weg. Danach nur noch die Anzahl ausgeben.",
    "r-ds-1a":
        "Die Schleife legt 1, 2 und 3 nacheinander oben auf. Die beiden pop-Aufrufe "
        "nehmen von oben weg – in umgekehrter Reihenfolge zum Ablegen.",
    "s-fill-17":
        "Beim Stapel heißen die beiden Bewegungen anders als bei der Warteschlange: "
        "eines bedeutet „drücken“, das andere ist der kurze Laut beim Abheben.",
    "s-code-10":
        "Eine einzige Struktur erledigt beides auf einmal – Doppelte weg und sortiert. "
        "Du kannst ihr die Liste direkt beim Anlegen übergeben.",
    "x-ds-1a":
        "Sortiert ist nur die TreeSet-Variante, nicht jedes Set. Der Unterschied, der "
        "für alle Sets gilt, betrifft mehrfach eingefügte gleiche Werte.",
    "x-ds-1b":
        "Denk an die Schlange an der Supermarktkasse. Wer sich zuerst angestellt hat, "
        "steht vorne – das ist genau das Gegenteil vom Stapel.",
    "x-ds-2a":
        "Der dritte Eintrag ist eine Wiederholung und wird deshalb verworfen. "
        "contains fragt nach einer Farbe, die tatsächlich drin ist.",
    "x-ds-2b":
        "Hier ist es ein Stapel: pop nimmt das zuletzt Abgelegte weg, peek zeigt danach, "
        "was jetzt obenauf liegt – ohne es zu entfernen.",
    "x-ds-4a":
        "TreeSet hält alles alphabetisch sortiert. first() und last() liefern danach die "
        "beiden Enden dieser Sortierung, nicht die Einfüge-Reihenfolge.",
    "x-ds-5a":
        "Leg ein sortiertes Set aus der ersten Liste an und behalte darin nur, was auch in "
        "der zweiten steht – dafür gibt es eine Methode, deren Name „behalte alle“ bedeutet.",
    "y-ds-1":
        "Denk an einen Stapel Teller: push legt einen drauf, pop nimmt den obersten weg. "
        "Welcher der beiden abgelegten Teller liegt am Ende zuoberst?",

    # ----------------------------------------------------------------- lambdas
    "t12-1":
        "Drei der vier Schreibweisen stammen aus anderen Sprachen – Python und JavaScript. "
        "Java nutzt einen Pfeil aus Minus und Größerzeichen.",
    "t12-2":
        "forEach führt das Lambda für jeden Eintrag einmal aus, in der Reihenfolge der Liste. "
        "Innen steht eine Ausgabe mit Zeilenumbruch und eine Umwandlung in Großbuchstaben.",
    "t12-3":
        "Zwei Stationen nacheinander: Erst fällt alles weg, was die Bedingung nicht erfüllt, "
        "und nur der Rest wird danach umgerechnet. Die Reihenfolge bleibt erhalten.",
    "t12-4":
        "Die erste Station siebt nach einer Bedingung aus, die zweite wandelt um – hier als "
        "Methodenverweis auf die String-Methode für Großbuchstaben.",
    "t26-1":
        "Der Name sagt es: Es wird gruppiert. Überleg, was du brauchst, um später zu jedem "
        "Gruppennamen die zugehörigen Elemente nachschlagen zu können.",
    "t26-2":
        "sorted() ordnet die Zahlen aufsteigend, ohne die Ausgangsliste zu ändern. "
        "reduce faltet danach alles zu einem Wert zusammen – hier beginnend bei null.",
    "t26-3":
        "Gruppiert wird nach dem ersten Buchstaben, und TreeMap hält die Schlüssel sortiert. "
        "Innerhalb einer Gruppe bleibt die ursprüngliche Reihenfolge erhalten.",
    "t26-4":
        "Die erste Station macht aus verschachtelten Listen eine flache – ihr Name beginnt "
        "mit „flat“. Die zweite ordnet, ihr Name ist das englische Wort für „sortiert“.",
    "p-lam-1a":
        "filter lässt nur durch, was die Bedingung erfüllt – hier die geraden Zahlen. "
        "Ausgegeben wird ohne Zeilenumbruch, mit Leerzeichen hinter jeder Zahl.",
    "p-lam-1b":
        "map wandelt jeden Eintrag einzeln um und behält die Reihenfolge bei. "
        "Ausgegeben wird die fertige Liste, also mit eckigen Klammern und Komma.",
    "p-lam-2a":
        "mapToInt quadriert zuerst jede Zahl einzeln, erst danach wird summiert. "
        "Rechne also drei Quadrate aus und addiere sie.",
    "q-lam-1a":
        "count() zählt, was nach dem Sieben übrig bleibt. Prüf für jeden Namen einzeln, "
        "ob er mehr als drei Zeichen hat – genau drei reicht nicht.",
    "q-lam-1b":
        "Erst wird jede Zahl verdoppelt, danach wird sortiert. Die Reihenfolge der beiden "
        "Stationen ist entscheidend für das Ergebnis.",
    "q-lam-2a":
        "Beim Hinschreiben des Lambdas passiert noch nichts. Überleg, wann der Code darin "
        "tatsächlich läuft – sofort oder erst, wenn der Stream ihn braucht.",
    "s-fill-14":
        "Die erste Station lässt nur durch, was passt – das englische Wort für „sieben“. "
        "Die zweite bildet jeden Wert auf einen neuen ab und heißt wie eine Landkarte.",
    "s-code-6":
        "Drei Stationen: stream(), dann die Bedingung zum Aussieben, dann die Ausgabe. "
        "Achte darauf, dass „mehr als vier“ die Vier selbst nicht mitnimmt.",
    "v-lam-2":
        "forEach läuft einmal pro Eintrag in der gegebenen Reihenfolge. Jede Farbe wird "
        "in Großbuchstaben und mit Zeilenumbruch ausgegeben.",
    "v-str-1":
        "Gruppieren heißt: Zu jedem Merkmal gehört eine Sammlung. Überleg, welche "
        "Datenstruktur genau diese Zuordnung von Schlüssel zu Inhalt abbildet.",
    "v-str-2":
        "reduce faltet die Liste zu einem einzigen Wert. Der erste Wert ist der Startwert – "
        "beim Multiplizieren muss der neutral sein. Das Sortieren ändert das Produkt nicht.",
    "v-str-3":
        "Gruppiert wird nach der Zeichenzahl, TreeMap sortiert die Schlüssel aufsteigend. "
        "Innerhalb einer Gruppe bleibt die Reihenfolge der Liste erhalten.",
    "v-str-4":
        "Die erste Station löst die Verschachtelung auf; ihr Name beginnt mit „flat“. "
        "Die zweite bringt die Zahlen in aufsteigende Ordnung.",
    "v-str-5":
        "min() braucht eine Vergleichsregel – für Zahlen genügt die natürliche Ordnung. "
        "Das Ergebnis ist ein Optional, du musst also noch einen Ersatzwert angeben.",
    "y-lam-5":
        "Zwei getrennte Auswertungen: Die erste siebt nach Länge, macht groß und fügt mit "
        "Komma zusammen – „ist“ fällt raus. Die zweite addiert die Längen aller drei Wörter.",
    "z-lam-26-3":
        "groupingBy braucht eine Regel, nach der gruppiert wird – hier die Zeichenzahl, "
        "als Methodenverweis auf String. Zwei der Wörter landen in derselben Gruppe.",
    "z-lam-26-4":
        "Zwei Stationen: eine, die die inneren Listen zu einem einzigen Strom verschmilzt, "
        "und eine, die danach sortiert. Die erste heißt wie map, nur mit „flat“ davor.",

    # ---------------------------------------------------------------- generics
    "t11-2":
        "Listen speichern Verweise auf Objekte, keine nackten Zahlen. Für jeden einfachen "
        "Typ gibt es deshalb eine Klassen-Entsprechung mit großem Anfangsbuchstaben.",
    "p-col-2b":
        "Die spitzen Klammern sind ein Etikett für den Inhalt, keine Größenangabe. "
        "Überleg, was der Compiler damit verhindern kann.",
    "q-gen-1a":
        "Der Platzhalter macht die Methode nicht schneller und schränkt sie auch nicht ein. "
        "Überleg, was du gewinnst, wenn du den Typ erst beim Aufruf festlegst.",
    "q-gen-1b":
        "Die Liste enthält Integer-Objekte; Java packt sie beim Rechnen automatisch aus. "
        "Addiere schlicht die beiden Einträge.",
    "r-gen-1a":
        "Weil die Liste als Text-Liste deklariert ist, weiß Java beim get schon den Typ – "
        "du kannst direkt eine String-Methode aufrufen. Das Wort wird groß ausgegeben.",
    "r-gen-1b":
        "Die Liste hat ein Etikett, das nur eine Sorte Inhalt erlaubt. Überleg, ob 42 "
        "dazu passt – und ob das schon beim Übersetzen oder erst zur Laufzeit auffällt.",
    "r-gen-2a":
        "Der Platzhalter wird vor dem Rückgabetyp eingeführt und taucht dann dreimal auf: "
        "als Rückgabetyp, im Parameter und in der Deklaration. Der Rumpf ist eine Zeile.",
    "u-gen-1":
        "Zuerst den Eintrag unter dem Schlüssel holen – das ist selbst wieder eine Liste. "
        "Danach nur noch deren Anzahl an Einträgen bestimmen.",
    "u-gen-2":
        "Links steht das Interface mit dem Etikett, rechts die konkrete Klasse. "
        "Für ganze Zahlen brauchst du die Klassen-Entsprechung, nicht den einfachen Typ.",
    "u-gen-3":
        "In die spitzen Klammern kommt die Klasse für Text – mit großem Anfangsbuchstaben, "
        "so wie sie auch in der Deklaration einer Textvariablen steht.",
    "u-gen-4":
        "Der Platzhalter wird vor dem Rückgabetyp eingeführt. Die Anzahl ist eine ganze Zahl, "
        "also ist der Rückgabetyp hier nicht der Platzhalter selbst.",
    "x-gen-1a":
        "Die spitzen Klammern sagen nichts über Größe oder Sortierung. Überleg, was der "
        "Compiler dank ihnen schon vor dem Start bemängeln kann.",
    "x-gen-1b":
        "In die spitzen Klammern darf kein einfacher Typ. Gesucht ist die Klasse dazu – "
        "sie heißt wie das englische Wort für „ganze Zahl“, ausgeschrieben.",
    "x-gen-2a":
        "Erst die beiden Einträge addieren, dann die Liste selbst ausgeben. "
        "Eine Liste zeigt sich mit eckigen Klammern und Komma zwischen den Einträgen.",
    "x-gen-3a":
        "Dieselbe Methode wird zweimal mit verschiedenen Inhalten aufgerufen. Der Platzhalter "
        "nimmt jedes Mal den passenden Typ an – gefragt ist jeweils das erste Element.",
    "x-gen-4a":
        "T ist kein fester Typ und keine Abkürzung für etwas Bestimmtes. Überleg, wann "
        "entschieden wird, wofür es steht – beim Schreiben der Methode oder beim Aufruf.",
    "x-gen-4b":
        "Zwei Aufrufe mit verschieden vielen Elementen. Ausgegeben wird jeweils die Anzahl, "
        "ein Doppelpunkt und die Liste selbst in eckigen Klammern.",
    "x-gen-5a":
        "subList nimmt eine Startposition und eine Endposition, wobei das Ende nicht mehr "
        "dazugehört. Die letzten beiden beginnen bei der Größe minus zwei.",
    "x-gen-5b":
        "Der Wert der Map ist selbst eine Liste – das steht so in den spitzen Klammern. "
        "List.of ist der kürzeste Weg, die beiden Werte zu erzeugen.",
    "y-gen-5":
        "Die Liste in der Map wird als veränderbare ArrayList angelegt, deshalb geht das "
        "spätere Hinzufügen. Die Map zeigt danach den geänderten Inhalt.",

    # ------------------------------------------------------------------- enums
    "t14-1":
        "Ein enum legt seine Werte im Quelltext fest; zur Laufzeit kommt keiner dazu. "
        "Überleg, welche der vier Aufgaben genau so eine abgeschlossene Liste ist.",
    "t14-2":
        "Ausgegeben wird der Name so, wie er im enum steht. ordinal() nennt die Position "
        "in der Aufzählung – gezählt ab null, wie überall in Java.",
    "t14-3":
        "Vorne der Wert, der zum Regen passt, in Großbuchstaben wie im enum deklariert. "
        "Hinten das Schlüsselwort, das aus mehreren Fällen einen auswählt.",
    "t14-4":
        "Das static-Feld gehört der Klasse, nicht dem einzelnen Objekt – alle drei teilen es. "
        "Das Feld nummer dagegen hat jedes Objekt für sich; verfolg beide getrennt.",
    "p-enum-1a":
        "Zuerst erscheint der Name des Wertes, genau so wie er im enum steht. "
        "Die Position darunter zählt ab null, nicht ab eins.",
    "q-enum-1a":
        "values() liefert alle Werte in der Reihenfolge ihrer Deklaration. Ausgegeben wird "
        "ohne Zeilenumbruch, mit einem Leerzeichen hinter jedem Namen.",
    "q-enum-1b":
        "Der Name kommt von „Ordnungszahl“. Überleg, worauf sich diese Zahl bezieht – "
        "und wo Java üblicherweise zu zählen anfängt.",
    "q-enum-2a":
        "Der Zähler ist static und gilt für alle Tickets gemeinsam. Beide new-Aufrufe "
        "zählen hoch, auch der erste, dessen Ergebnis niemand speichert.",
    "r-enum-1a":
        "Das switch wählt den Fall, der zum übergebenen Wert passt, und liefert dessen "
        "Ergebnis zurück. Such schlicht die Zeile mit dem passenden Namen.",
    "s-fill-15":
        "Gesucht ist das Schlüsselwort für eine Aufzählung – die Kurzform des englischen "
        "„enumeration“, klein geschrieben, an der Stelle, wo sonst class stünde.",
    "u-enum-1":
        "Das Schlüsselwort steht vor der Klammer mit dem zu prüfenden Wert und leitet die "
        "Fall-Liste ein. Hier liefert es sogar einen Wert zurück, deshalb das Semikolon am Ende.",
    "u-enum-2":
        "values() liefert ein Array aller Werte – dessen Länge ist die Anzahl. "
        "ordinal() nennt die Position des letzten Werts, gezählt ab null.",
    "u-enum-3":
        "static hat nichts mit „unveränderlich“ zu tun – dafür gibt es final. Überleg, "
        "wem ein static-Feld gehört: dem einzelnen Objekt oder der Klasse.",
    "x-enum-1a":
        "Die Möglichkeiten stehen im Quelltext und bekommen dort einen Namen. Überleg, "
        "was das im Unterschied zu einer Liste bedeutet, die zur Laufzeit wächst.",
    "x-enum-2a":
        "Drei Fragen: der Name, die Position ab null gezählt und die Anzahl aller Werte "
        "über die Länge von values().",
    "x-enum-3a":
        "Das switch liefert hier einen Wert, der in einer Variablen landet. "
        "Such den Fall, dessen Name zum gesetzten Wert passt.",
    "x-enum-4a":
        "Jeder enum-Wert bekommt über den Konstruktor seine eigene Zahl mit. Die Schleife "
        "geht beide in Deklarationsreihenfolge durch und gibt Name und Zahl aus.",
    "x-enum-5a":
        "Das enum ist eine Zeile mit vier Namen. Die Schleife über values() gibt jeden "
        "Namen und seine Position aus – ordinal() zählt dabei ab null.",
    "x-enum-5b":
        "Innerhalb des enums zeigt this auf den aktuellen Wert. Weil enum-Werte einzigartig "
        "sind, darfst du hier mit == vergleichen – zwei Fälle mit Oder verknüpft.",
    "y-enum-5":
        "Zwei Dinge: der Cent-Wert eines einzelnen Wertes und die Summe über alle. "
        "Die statische Methode läuft mit values() durch beide und addiert auf.",

    # ---------------------------------------------------------- objectmethods
    "t15-1":
        "println fragt jedes Objekt, wie es sich als Text darstellt. Gesucht ist die "
        "Methode, deren Name genau das sagt: „zu Text“.",
    "t15-2":
        "Das eine prüft, ob zwei Namen auf dieselbe Kiste im Speicher zeigen. Das andere "
        "kann jede Klasse selbst festlegen und nach dem Inhalt entscheiden.",
    "t15-3":
        "Ein record bringt equals und toString fertig mit, == bleibt aber der Vergleich "
        "auf Identität. Zwei new-Aufrufe erzeugen immer zwei verschiedene Objekte.",
    "t15-4":
        "Vorne das Schlüsselwort für eine halbfertige Klasse, aus der man kein Objekt bauen "
        "kann. Hinten das für Vererbung von einer Klasse – nicht das für Interfaces.",
    "q-obj-1a":
        "Die Klasse legt mit einer eigenen Methode fest, wie sie sich als Text zeigt. "
        "println benutzt genau diese statt der Standardausgabe.",
    "q-obj-1b":
        "new erzeugt ausdrücklich zwei eigene Objekte, auch wenn der Inhalt gleich ist. "
        "Nur eine der beiden Prüfungen interessiert sich für den Inhalt.",
    "q-obj-2a":
        "HashSet und HashMap suchen zuerst über eine Zahl das richtige Fach und vergleichen "
        "erst darin. Überleg, was passiert, wenn gleiche Objekte verschiedene Fächer nennen.",
    "q-obj-2b":
        "Abstrakt heißt: unvollständig. Eine solche Klasse darf Felder und fertige Methoden "
        "haben – überleg, was mit new daraus trotzdem nicht geht.",
    "r-obj-1a":
        "Ein record bekommt equals und toString automatisch, beide auf Basis seiner Felder. "
        "Die Textform nennt den Namen des records und jedes Feld mit seinem Wert.",
    "s-fill-16":
        "Gesucht ist die Methode, die println bei einem Objekt aufruft. Ihr Name ist "
        "zusammengesetzt aus „to“ und dem englischen Wort für Zeichenkette.",
    "u-obj-1":
        "Die abstrakte Klasse nutzt in ihrer Textform die Methode, die erst das Kind "
        "ausfüllt. Die Fläche ist ein double – achte auf die Nachkommastelle.",
    "u-obj-2":
        "Ohne eigene Regel vergleicht == bei Objekten immer die Identität, nie den Inhalt. "
        "Zwei getrennt erzeugte Objekte sind nie dasselbe Objekt.",
    "v-obj-5":
        "Die Methode heißt wie die, die println aufruft, gibt einen String zurück und ist "
        "public. Setz Titel, Klammern und Jahr mit Pluszeichen zusammen.",
    "x-objm-1a":
        "Ganz oben in Javas Stammbaum steht eine einzige Klasse, von der alles andere "
        "abstammt. Ihr Name ist schlicht das englische Wort für „Gegenstand“.",
    "x-objm-2a":
        "Ohne eigene Textform nimmt Java die geerbte aus Object. Die kennt die Felder nicht "
        "und kann deshalb nur Herkunft und eine interne Kennung nennen.",
    "x-objm-3a":
        "Ein record bringt einen Inhaltsvergleich fertig mit. Eine gewöhnliche Klasse tut "
        "das nicht – dort bleibt es bei der geerbten Prüfung auf Identität.",
    "x-objm-4a":
        "getSimpleName() liefert den Namen der tatsächlichen Klasse, nicht den der abstrakten. "
        "Die Fläche ist ein double, wird also mit Nachkommastelle ausgegeben.",
    "x-objm-5a":
        "Der Parameter ist ein Object, du musst also erst den Typ prüfen – mit instanceof "
        "und Mustervariable geht beides in einem Schritt. Danach beide Felder vergleichen.",
    "x-objm-5b":
        "Die Methode heißt wie die, die println benutzt, ist public und liefert einen String. "
        "Ein double bringt seine Nachkommastelle von selbst mit.",

    # --------------------------------------------------------------- recursion
    "t18-1":
        "Ohne etwas, das den Abstieg beendet, ruft sich die Methode ewig selbst auf. "
        "Überleg, welche der vier Antworten genau diese Bremse ist.",
    "t18-2":
        "Schreib die Kette auf: summe(4) wartet auf summe(3), das auf summe(2) und so weiter. "
        "Ganz unten steht die Null, von dort rechnest du wieder nach oben.",
    "t18-3":
        "Jede Zahl ist die Summe der beiden davor. Schreib die Folge ab 0 und 1 auf, "
        "bis du bei Position 6 bist – gezählt wird ab Position 0.",
    "t18-4":
        "Der Basisfall greift, wenn nichts mehr zu multiplizieren ist – dann ist das Ergebnis "
        "die neutrale Eins. Hinten ruft sich die Methode unter ihrem eigenen Namen auf.",
    "p-rec-1a":
        "Die Methode addiert n und alles darunter. Rechne von unten nach oben: "
        "Bei null ist Schluss, von dort staffelt sich die Summe wieder hoch.",
    "q-rec-1a":
        "Hier wird multipliziert, nicht addiert. Rechne von unten her: Beim Wert 1 ist Schluss, "
        "danach kommen die größeren Faktoren nacheinander dazu.",
    "q-rec-1b":
        "Jeder Aufruf belegt Platz auf dem Aufruf-Stapel, und der ist begrenzt. "
        "Der Compiler kann das nicht erkennen – der Fehler zeigt sich erst beim Laufen.",
    "q-rec-2a":
        "Erst die Abbruchbedingung, dann die Ausgabe, dann der Aufruf mit einer kleineren Zahl. "
        "Die Methode gibt nichts zurück, der Abbruch ist deshalb ein return ohne Wert.",
    "r-rec-1a":
        "Jeder Schritt schneidet mit der Division durch 10 die letzte Ziffer ab. "
        "Zähl mit, wie oft das geht, bis nur noch eine einstellige Zahl übrig ist.",
    "s-fill-18":
        "Vorne der Vergleich, der den Basisfall bei null auslöst – nicht zuweisen, sondern "
        "prüfen. Hinten das Rechenzeichen, das die Zahl bei jedem Aufruf kleiner macht.",
    "u-rec-1":
        "Schreib die Folge ab 0 und 1 auf, jede Zahl ist die Summe der beiden davor. "
        "Gesucht ist die an Position 7, wobei ab Position 0 gezählt wird.",
    "u-rec-2":
        "An dieser Stelle ruft sich die Methode selbst auf – es steht also ihr eigener "
        "Name da, genau so wie oben in der Signatur.",
    "x-rec-1a":
        "Das Wort kommt von „zurücklaufen“. Überleg, auf welche Methode sich der Aufruf "
        "im Rumpf bezieht – auf eine andere oder auf dieselbe.",
    "x-rec-1b":
        "Der Compiler sieht nur einen gewöhnlichen Methodenaufruf und ist zufrieden. "
        "Das Problem zeigt sich erst beim Laufen, wenn der Aufruf-Stapel voll ist.",
    "x-rec-2a":
        "Die Methode addiert n und alles darunter bis null. Rechne die Kette von unten "
        "nach oben zusammen.",
    "x-rec-3a":
        "Die zweite Ausgabe steht nach dem rekursiven Aufruf – sie läuft erst, wenn der "
        "gesamte Abstieg fertig ist. Deshalb erscheint sie in umgekehrter Reihenfolge.",
    "x-rec-3b":
        "Jede Zahl ist die Summe der beiden Vorgänger, beginnend bei 0 und 1. "
        "Zähl die Positionen ab null.",
    "x-rec-5a":
        "Zwei Teile: die Abbruchbedingung für die kleinen Werte, bei denen das Ergebnis "
        "eins ist, und darunter die Multiplikation mit dem Aufruf für n minus eins.",
    "x-rec-5b":
        "Der Basisfall ist der leere Text. Sonst: den Rest ab Position 1 umdrehen und "
        "das erste Zeichen hinten anhängen – die Reihenfolge der beiden ist entscheidend.",
    "y-rec-1":
        "Die Ausgabe steht vor dem rekursiven Aufruf, also erscheint jede Zahl beim Abstieg. "
        "Bei null bricht die Kette ab, ohne noch etwas auszugeben.",
    "y-rec-5":
        "Das ist der euklidische Algorithmus: Er ersetzt das Paar immer wieder durch "
        "den zweiten Wert und den Rest der Division. Rechne die Schritte nach.",

    # -------------------------------------------------------------- algorithms
    "t19-1":
        "Die binäre Suche entscheidet nach einem Blick in die Mitte, in welcher Hälfte "
        "es weitergeht. Überleg, was gelten muss, damit diese Entscheidung überhaupt möglich ist.",
    "t19-2":
        "Bei jedem Blick halbiert sich der Bereich. Frag dich, wie oft man eine Million "
        "halbieren muss, bis nur noch ein Eintrag übrig ist – zweimal zehn ist etwa tausend.",
    "t19-3":
        "Arrays.sort ordnet aufsteigend und verändert das Array selbst. Danach steht der "
        "kleinste Wert vorne, der größte hinten – schreib das sortierte Array auf.",
    "t19-4":
        "Vorne die Eigenschaft für die Anzahl der Fächer – beim Array ohne Klammern. "
        "Hinten die Methode für den Inhaltsvergleich zweier Texte.",
    "p-sort-1a":
        "Arrays.sort ordnet aufsteigend. Arrays.toString zeigt das Ergebnis mit eckigen "
        "Klammern und Komma zwischen den Zahlen.",
    "q-alg-1a":
        "Die binäre Suche sortiert nichts und liest auch nicht genauer. Überleg, wie viel "
        "vom Suchbereich nach einem einzigen Blick in die Mitte schon erledigt ist.",
    "q-alg-1b":
        "Texte werden alphabetisch sortiert, nicht nach Länge. Bring die drei Namen "
        "in die Reihenfolge, in der sie im Wörterbuch stünden.",
    "q-alg-2a":
        "Sortiert wird hier nach der Zeichenzahl, nicht alphabetisch. Zähl die Buchstaben "
        "jedes Wortes und ordne danach aufsteigend.",
    "q-alg-3a":
        "Ein Zähler vor der Schleife, in der Schleife die Bedingung, bei Treffer erhöhen. "
        "„Größer als 10“ schließt die 10 selbst nicht ein.",
    "s-code-9":
        "Lauf mit einem Index über alle Positionen und hol dir mit charAt jedes Zeichen. "
        "Achte auf Groß- und Kleinschreibung – ein einzelnes Zeichen steht in einfachen Hochkommas.",
    "u-alg-1":
        "Verfolg die Schritte: Die Mitte wird aus links und rechts berechnet und abgerundet. "
        "Gezählt wird jeder Durchlauf, auch der, bei dem der Wert gefunden wird.",
    "u-alg-2":
        "Listen haben eine eigene sort-Methode. Für die gewöhnliche alphabetische Ordnung "
        "gibt es eine fertige Vergleichsregel mit „natural“ im Namen.",
    "x-alg-1a":
        "Linear heißt: der Reihe nach, ohne Abkürzung. Zwei der Antworten beschreiben die "
        "binäre Suche, eine den direkten Zugriff über einen Schlüssel.",
    "x-alg-1b":
        "Es geht nicht um Prozessorkerne oder gemerkte Ergebnisse. Überleg, wie viel vom "
        "Suchbereich nach einem Blick in die Mitte schon ausgeschlossen ist.",
    "x-alg-2a":
        "Erst sortieren, dann suchen. binarySearch liefert die Position im sortierten Array – "
        "gezählt ab null, nicht den Wert selbst.",
    "x-alg-2b":
        "Bei jedem Blick halbiert sich der Bereich. Zweimal zehn Halbierungen wären etwa "
        "eine Million, für tausend braucht es entsprechend weniger.",
    "x-alg-3a":
        "Zweimal dasselbe Datenmaterial, zwei verschiedene Ordnungen: erst alphabetisch, "
        "danach nach Zeichenzahl. Die zweite Sortierung geht von der ersten aus.",
    "x-alg-5a":
        "Die Liste hat eine sort-Methode, die eine Vergleichsregel annimmt. Für die "
        "umgekehrte Ordnung gibt es eine fertige mit „reverse“ im Namen.",
    "y-alg-1":
        "Arrays.sort ordnet aufsteigend und ändert das Array selbst. Danach steht an "
        "Position null der kleinste Wert.",
    "y-alg-5":
        "Zwei Kriterien nacheinander: zuerst die Zeichenzahl, und bei gleicher Länge "
        "entscheidet die alphabetische Ordnung. Zähl die Buchstaben jedes Wortes.",

    # ---------------------------------------------------------------- datetime
    "t17-2":
        "Erst der Tag im Monat, dann acht Tage weiter – über den Monats- und Jahreswechsel "
        "hinweg. Java gibt ein Datum von sich aus als Jahr-Monat-Tag mit Bindestrichen aus.",
    "t17-3":
        "Period rechnet in ganzen Jahren, Monaten und Tagen. Der Geburtstag im Mai liegt "
        "vor dem Stichtag im September – das Jahr ist also schon voll.",
    "t17-5":
        "Das Muster besteht aus Platzhaltern: zwei Zeichen für den Tag, zwei für den Monat, "
        "vier für das Jahr, dazwischen die Punkte. Danach das Datum damit formatieren.",
    "q-dat-1a":
        "Der März hat 31 Tage. Zähl vom 15. aus zwanzig Tage weiter und beachte den "
        "Monatswechsel. Die Ausgabe erfolgt als Jahr-Monat-Tag.",
    "q-dat-1b":
        "getYears liefert nur die vollen Jahre, die Monate zählen getrennt. "
        "Vom 1. Januar 2020 bis zum 1. Juli 2026 sind sechs Jahre voll und ein halbes offen.",
    "q-dat-2a":
        "Zwei Zeichen für den Tag, zwei für den Monat, vier für das Jahr. Der Monat wird "
        "groß geschrieben, damit er nicht mit den Minuten verwechselt wird.",
    "r-dat-1a":
        "Der 31. Dezember ist der letzte Tag des Jahres. Ein Tag weiter wechselt also "
        "Tag, Monat und Jahr gleichzeitig.",
    "r-dat-1b":
        "Zwei getrennte Abfragen, zwischen die ein Punkt gehängt wird. Achte darauf, "
        "dass hier nichts auf zwei Stellen aufgefüllt wird.",
    "r-dat-2a":
        "Period.between liefert den Abstand aufgeteilt in Jahre, Monate und Tage. "
        "Gefragt ist nur der Jahresanteil.",
    "u-dat-1":
        "Der Name nennt beide Teile: „Local“ für ohne Zeitzone und „Date“ für den Kalender. "
        "Für die Uhrzeit gibt es eine eigene Klasse mit „Time“ im Namen.",
    "u-dat-2":
        "2026 ist kein Schaltjahr, der Februar hat also 28 Tage. Zähl vom 28. aus "
        "zwei Tage weiter.",
    "u-dat-3":
        "Der Name der Methode sagt wörtlich, was sie tut: Tage dazuzählen. "
        "Er besteht aus dem englischen „plus“ und dem Wort für Tage.",
    "x-dt-1a":
        "Zwei der Antworten sind die alten, längst abgelösten Klassen. Von den beiden "
        "modernen speichert eine nur die Uhrzeit – gesucht ist die andere.",
    "x-dt-1b":
        "Man erzeugt so ein Datum nicht mit new, sondern über eine statische Methode. "
        "Ihr Name ist das englische Wort für „jetzt“.",
    "x-dt-2a":
        "Drei Zeilen: das Datum selbst in Javas Standardform, der Tag im Monat als Zahl "
        "und das Datum zwanzig Tage später – der März hat 31 Tage.",
    "x-dt-3a":
        "Period zerlegt den Abstand in Jahre, Monate und Tage; die Monate zählen nicht "
        "die Tage mit. isBefore fragt schlicht, welches Datum früher liegt.",
    "x-dt-4a":
        "Zwanzig Stunden ab halb zehn morgens überschreiten Mitternacht. LocalDateTime "
        "schreibt Datum und Uhrzeit mit einem T dazwischen; toLocalDate schneidet die Zeit ab.",
    "x-dt-5a":
        "Für den Wochentag gibt es eine Methode mit „DayOfWeek“ im Namen; sie liefert "
        "den englischen Namen in Großbuchstaben. Danach mit einem Muster formatieren.",
    "x-dt-5b":
        "Period zählt in Monaten, nicht in Tagen. Wandle beide Daten stattdessen in eine "
        "fortlaufende Tagesnummer um – dafür gibt es eine Methode mit „EpochDay“ im Namen.",
    "y-dat-5":
        "Der 31. Januar plus ein Monat kann nicht der 31. Februar sein – Java rückt auf den "
        "letzten gültigen Tag. Danach ist der Abstand kein voller Monat mehr.",
    "y-dat-4b":
        "Erst das Datum mit Jahr, Monat und Tag anlegen, dann mit einem Muster aus Tag, "
        "Monat und vierstelligem Jahr formatieren. Der Monat wird großgeschrieben.",

    # ---------------------------------------------------------------------- io
    "t16-1":
        "Ein String lässt sich nach dem Erzeugen nicht mehr ändern – jedes Anhängen baut "
        "einen neuen. Überleg, was der StringBuilder daran anders macht.",
    "t16-2":
        "Zwei Schritte auf demselben Notizblock: erst anhängen, dann das Ganze umdrehen. "
        "Dreh den zusammengesetzten Text Zeichen für Zeichen um.",
    "t16-3":
        "Der Scanner liest hier aus einem festen Text statt von der Tastatur. Die Schleife "
        "läuft, solange noch eine Zahl kommt – addiere alle drei.",
    "t16-4":
        "Vorne die Methode, die das nächste Wort liest – dieselbe wie eine Zeile darunter. "
        "Hinten die Methode, die etwas hinten an den Notizblock hängt.",
    "t17-1":
        "Eine Datei kann fehlen, gesperrt oder das Laufwerk voll sein – daran ist kein "
        "Programm schuld. Java stuft solche Fehler als „checked“ ein.",
    "t17-4":
        "Drei Lücken: das Schreiben eines Textes, das Lesen aller Zeilen als Liste und "
        "die Ausnahme für Ein- und Ausgabe. Die Namen sagen jeweils genau das.",
    "q-io-1a":
        "Zweimal anhängen, dann alles ausgeben. Achte auf die Leerzeichen, die in den "
        "angehängten Textstücken selbst stecken.",
    "q-io-1b":
        "reverse dreht den Inhalt des Notizblocks um. Schreib das Wort Zeichen für Zeichen "
        "rückwärts auf – es ergibt wieder ein sinnvolles englisches Wort.",
    "q-io-2a":
        "next() liest jeweils bis zum nächsten Leerzeichen, nextInt() liest eine Zahl. "
        "Danach werden die Teile in anderer Reihenfolge zusammengesetzt.",
    "q-io-3a":
        "Leg den StringBuilder mit der ersten Farbe an und häng danach abwechselnd "
        "Bindestrich und Farbe an. Am Ende einmal ausgeben.",
    "u-io-1":
        "Die Schleife hängt die Zahlen 1, 2 und 3 nacheinander an. Beim Anhängen einer "
        "Zahl entsteht deren Ziffer als Text, es wird nichts addiert.",
    "u-io-2":
        "Gesucht ist die Methode, die hinten etwas anfügt. Ihr englischer Name bedeutet "
        "genau das: „anhängen“.",
    "u-io-3":
        "Der Scanner liest die beiden Zahlen in der Reihenfolge, in der sie im Text stehen. "
        "Danach wird die zweite von der ersten abgezogen.",
    "v-io-1":
        "Die Datei kann fehlen oder das Laufwerk voll sein – das liegt außerhalb des Programms. "
        "Java zwingt bei solchen Fehlern zu einer Reaktion, schon beim Übersetzen.",
    "v-io-4":
        "Drei Lücken: das Schreiben eines Textes in die Datei, das Lesen aller Zeilen als "
        "Liste und die Ausnahme, deren Name mit IO beginnt.",
    "x-io-1a":
        "Der Scanner liest, er schreibt nicht und prüft auch nichts. Überleg, woher der "
        "Text kommt, den er liefert.",
    "x-io-2a":
        "Drei Anhänge, darunter eine Zahl – die wird zur Ziffernfolge, nicht addiert. "
        "length() zählt danach alle Zeichen des fertigen Textes.",
    "x-io-3a":
        "insert schiebt an einer Position ein, append hängt hinten an. Die zweite Ausgabe "
        "dreht den fertigen Text komplett um, samt Satzzeichen.",
    "x-io-5a":
        "Der Bindestrich gehört zwischen die Zahlen, nicht hinter die letzte. Häng ihn "
        "deshalb vor jeder Zahl außer der ersten an.",
    "y-io-1":
        "Die Datei gibt es nicht, das Lesen scheitert also sofort. Die Zeile darunter "
        "im try-Block wird nie erreicht.",
    "z-io-4":
        "next() liest jeweils bis zum nächsten Leerzeichen. Häng danach am Notizblock "
        "zuerst den Nachnamen an, dann Komma und Leerzeichen, dann den Vornamen.",
    "z-io-4b":
        "Ein offener Datei-Kanal muss geschlossen werden, auch wenn mittendrin etwas "
        "schiefgeht. Überleg, was try-with-resources dir dabei abnimmt.",

    # ------------------------------------------------------------------ modern
    "t13-1":
        "Ein record ist genau dafür da, Tipparbeit zu sparen. Überleg, welche immer "
        "gleichen Bausteine einer Wertklasse Java dir deshalb schenkt – es sind mehrere.",
    "t13-2":
        "Die Zugriffsmethoden heißen wie die Felder, mit Klammern dahinter. Die Textform "
        "nennt den Namen des records und jedes Feld; equals vergleicht den Inhalt.",
    "t13-3":
        "orElse greift nur, wenn nichts drin ist. map rechnet nur, wenn etwas drin ist – "
        "hier die Zeichenzahl. isPresent fragt, ob überhaupt ein Wert vorliegt.",
    "t13-4":
        "Vorne das Schlüsselwort, das aus mehreren Fällen einen auswählt und hier einen "
        "Wert liefert. Hinten der Auffang-Fall für alles, was oben nicht genannt ist.",
    "p-mod-1a":
        "Ein record erzeugt für jedes Feld eine gleichnamige Zugriffsmethode. "
        "Hier wird die für den Titel aufgerufen.",
    "p-mod-1b":
        "Optional.empty() enthält keinen Wert. Überleg, was orElse in diesem Fall "
        "herausgibt – es steht schon in der Klammer.",
    "q-mod-1a":
        "Hier steckt ein Wert im Optional. orElse greift nur ein, wenn keiner da ist – "
        "der Ersatztext bleibt deshalb ungenutzt.",
    "q-mod-1b":
        "Der switch prüft hier den Typ des Objekts, nicht seinen Wert. Der Wert 42 wird "
        "automatisch in seine Klassen-Entsprechung verpackt.",
    "q-mod-2a":
        "Der Pfeil ist nicht nur kürzere Schreibweise. Achte darauf, dass das Ergebnis "
        "hier einer Variablen zugewiesen wird – und dass am Ende ein Semikolon steht.",
    "s-fill-20":
        "Gesucht ist der Operator, der den Typ prüft und das Objekt gleich unter neuem "
        "Namen bereitstellt. Sein Name bedeutet wörtlich „ist ein Exemplar von“.",
    "u-mod-1":
        "Die beiden Zugriffsmethoden heißen wie die Felder des records. "
        "Setz ihre Ergebnisse mit den festen Textstücken zusammen.",
    "u-mod-2":
        "Das Optional ist leer. Die erste Frage prüft genau das, die zweite liefert "
        "deshalb den mitgegebenen Ersatz.",
    "u-mod-3":
        "Ein record hat sehr wohl Felder, aber sie sind final. Überleg, was das für "
        "nachträgliche Änderungen bedeutet – und wozu ein Setter dann noch gut wäre.",
    "v-mod-2":
        "Die Zugriffsmethode heißt wie das Feld. equals vergleicht bei einem record "
        "alle Felder inhaltlich, nicht die Identität der beiden Objekte.",
    "x-mod-1a":
        "Der Name kommt vom Datensatz, nicht vom Aufzeichnen. Überleg, welche Art von "
        "Klasse man damit kürzer hinschreiben kann.",
    "x-mod-2a":
        "Die Textform eines records nennt seinen Namen und jedes Feld mit Wert in eckigen "
        "Klammern. Danach werden die beiden Zahlen über ihre Zugriffsmethoden addiert.",
    "x-mod-3a":
        "Ein Fall darf mehrere Werte durch Komma auflisten. Such die Zeile, "
        "in der die 2 vorkommt.",
    "x-mod-4a":
        "Der April steht in keiner der aufgezählten Zeilen. Überleg, welcher Zweig "
        "dann greift – und wie viele Tage der April hat.",
    "x-mod-5a":
        "Mit instanceof und einer Mustervariablen prüfst und benennst du in einem Schritt. "
        "Trifft die Prüfung nicht zu, fällt die Methode auf den festen Wert durch.",
    "y-mod-2b":
        "Beide Formen gibt es mit Pfeil. Der Unterschied zeigt sich daran, ob das Ergebnis "
        "irgendwo landen kann – etwa in einer Variablen.",

    # ---------------------------------------------------------------- patterns
    "t25-1":
        "Das englische „permits“ heißt „erlaubt“, „sealed“ heißt „versiegelt“. "
        "Überleg, wen diese Erlaubnis betrifft und wer dadurch ausgeschlossen wird.",
    "t25-2":
        "Das Muster in den Klammern zerlegt den record gleich in seine Felder – x und y "
        "sind danach fertige Variablen. Addiere sie.",
    "t25-3":
        "Das when hängt eine zusätzliche Bedingung an den Fall. Java prüft die Fälle von "
        "oben nach unten, der engere steht deshalb zuerst.",
    "t25-4":
        "Vorne das Schlüsselwort für die geschlossene Familie – „versiegelt“. Hinten das, "
        "das aus mehreren Fällen einen auswählt und hier einen Wert liefert.",
    "q-pat-1a":
        "permits steht direkt hinter dem Namen und nennt konkrete Typen. Überleg, wozu "
        "so eine Aufzählung gut ist – sie hat nichts mit der Reihenfolge im switch zu tun.",
    "q-pat-1b":
        "Das Muster zerlegt den Punkt direkt in x und y. Danach werden die beiden "
        "Zahlen multipliziert, nicht addiert.",
    "q-pat-2a":
        "Der erste Fall hat eine Zusatzbedingung, die hier nicht erfüllt ist – „Hallo“ ist "
        "kürzer. Der zweite greift und setzt die Zeichenzahl in den Text ein.",
    "r-pat-1a":
        "Der switch wählt nach dem tatsächlichen Typ. Das Feld ist ein double – "
        "achte deshalb auf die Nachkommastelle in der Ausgabe.",
    "r-pat-1b":
        "Das englische „when“ heißt „wenn“. Überleg, was passiert, wenn der Typ zwar passt, "
        "diese Zusatzbedingung aber nicht – dann geht es weiter nach unten.",
    "r-pat-2a":
        "Der erste Fall verlangt zusätzlich, dass x null ist – das trifft hier zu. "
        "Die zerlegten Felder stehen danach als Variablen zur Verfügung.",
    "u-pat-1":
        "Zwei Schlüsselwörter: eines versiegelt das Interface, das andere leitet die "
        "Liste der erlaubten Typen ein. Beide sind englische Wörter.",
    "u-pat-2":
        "Der erste Fall verlangt zusätzlich einen Wert über 10 – das trifft auf 7 nicht zu. "
        "Der zweite Fall greift und hängt die Zahl an den Text.",
    "v-pat-5":
        "Ein switch über g mit einem Fall je record. Weil das Interface versiegelt ist, "
        "brauchst du keinen default – hol dir die Werte über die Zugriffsmethoden.",
    "x-pat-1a":
        "Umsetzen lässt sich ein sealed interface durchaus – aber nicht von jedem. "
        "Überleg, wer nach der permits-Liste noch übrig bleibt.",
    "x-pat-2a":
        "Drei Aufrufe mit drei verschiedenen Typen. Die beiden Prüfungen greifen der Reihe "
        "nach; eine Kommazahl passt zu keiner von beiden.",
    "x-pat-3a":
        "Der switch wählt nach dem tatsächlichen Typ. Die 3 wird beim Anlegen in ein "
        "double umgewandelt – achte auf die Ausgabe der Nachkommastelle.",
    "x-pat-3b":
        "Bei einem versiegelten Interface steht die Liste der möglichen Typen fest. "
        "Überleg, was der Compiler dadurch schon beim Übersetzen nachprüfen kann.",
    "x-pat-4a":
        "Zwei Aufrufe: Beim ersten greift die Zusatzbedingung, beim zweiten nicht. "
        "Die zerlegten Felder werden im zweiten Fall in den Text eingesetzt.",
    "x-pat-5a":
        "Ein switch über f mit einem Fall je Form. Für den Kreis brauchst du Math.PI, "
        "für das Quadrat genügt das Vierfache der Seite. Ein default ist nicht nötig.",
    "y-pat-5":
        "Der erste Fall zerlegt die Felder und verlangt zusätzlich, dass beide Seiten "
        "gleich sind. Java prüft von oben nach unten, der engere Fall greift also zuerst.",

    # ------------------------------------------------------------- concurrency
    "t23-1":
        "Der Name klingt nach „verbinden“, meint aber das Zusammenführen der Abläufe. "
        "Überleg, was das Hauptprogramm an dieser Stelle tut, statt weiterzulaufen.",
    "t23-2":
        "Ohne Absprache entscheidet das Betriebssystem, wer wann rechnet – und das kann "
        "bei jedem Start anders ausfallen. Genau das macht Nebenläufigkeit tückisch.",
    "t23-3":
        "Die erste Ausgabe kommt vor dem Start. Das join danach hält das Hauptprogramm an, "
        "bis der Thread fertig ist – erst dann folgt die letzte Zeile.",
    "t23-4":
        "Zwei Methoden in der richtigen Reihenfolge: erst loslaufen lassen, dann abwarten. "
        "Ohne das Warten stünde der Zähler womöglich noch auf null.",
    "t24-1":
        "Das Ergebnis ist noch nicht da, aber du bekommst sofort etwas in die Hand, "
        "womit du es später abholen kannst. Denk an die Garderobenmarke.",
    "t24-2":
        "Virtuelle Threads rechnen nicht schneller. Ihr Vorteil zeigt sich, wenn sehr "
        "viele Aufgaben gleichzeitig nur herumsitzen und auf eine Antwort warten.",
    "t24-3":
        "Beide Aufgaben werden eingereicht und liefern je einen Abholschein. get() wartet, "
        "bis das Ergebnis da ist – der erste ist Text, der zweite eine Rechnung.",
    "t24-4":
        "Drei Lücken: die Fabrikmethode für virtuelle Threads, die Methode zum Einreichen "
        "einer Aufgabe und die zum Abholen des Ergebnisses. Alle Namen sagen, was sie tun.",
    "q-con-1a":
        "start() ruft die Aufgabe nicht direkt auf – dann liefe sie im Hauptprogramm. "
        "Überleg, was der Unterschied zu einem gewöhnlichen Methodenaufruf ist.",
    "q-con-1b":
        "Die Schleife erhöht hundertmal. Das join sorgt dafür, dass sie fertig ist, "
        "bevor gelesen wird – deshalb ist das Ergebnis hier verlässlich.",
    "q-con-2a":
        "Erhöhen besteht aus drei Schritten: lesen, rechnen, schreiben. Überleg, was "
        "passiert, wenn zwei Threads mittendrin ineinandergeraten.",
    "q-con-2b":
        "Beide Aufgaben liefern Zahlen. get() wartet auf das Ergebnis – rechne beide "
        "einzeln aus und addiere sie dann.",
    "q-con-3a":
        "Virtuelle Threads brauchen weiterhin Executor und Abwarten und rechnen nicht "
        "schneller. Ihr Vorteil liegt darin, wie wenig Platz jeder einzelne belegt.",
    "r-con-1a":
        "Drei Aufgaben werden eingereicht, jede verzehnfacht ihre Zahl. Danach werden "
        "alle Ergebnisse eingesammelt und addiert – die Reihenfolge ändert die Summe nicht.",
    "s-fill-19":
        "Erst das Loslaufen, dann das Abwarten – in dieser Reihenfolge. Beide Methoden "
        "heißen wie die englischen Wörter für „starten“ und „zusammenführen“.",
    "v-con-3":
        "Die erste Zeile läuft vor dem Start. Danach hält das join das Hauptprogramm an, "
        "bis der Thread durch ist – erst dann kommt die letzte Ausgabe.",
    "v-con-1":
        "Die Aufgabe läuft bereits, das Ergebnis steht nur noch aus. Überleg, wofür "
        "dir das Objekt in der Hand dann dient.",
    "v-con-4":
        "Drei Lücken: die Fabrikmethode für ein Team fester Größe, die Methode zum "
        "Einreichen einer Aufgabe und die zum Abholen des Ergebnisses.",
    "y-con-2":
        "Das join hält das Hauptprogramm so lange an, bis der Thread durch ist. "
        "Deshalb steht die Reihenfolge der beiden Zeilen hier fest.",
    "z-con-23-2":
        "Das join zwischen Start und letzter Ausgabe macht die Reihenfolge eindeutig. "
        "Ohne es wäre sie nicht vorhersagbar.",
    "z-con-23-4":
        "Drei Schritte: Thread mit einem Lambda anlegen, starten, abwarten. Erst nach "
        "dem Abwarten kommt die letzte Ausgabe – sonst stünde die Reihenfolge nicht fest.",
    "z-con-23-5":
        "Das Erhöhen eines gewöhnlichen int besteht aus Lesen, Rechnen und Schreiben. "
        "Überleg, was AtomicInteger an diesen drei Schritten ändert.",
    "z-con-24-1":
        "Die eingereichte Aufgabe liefert einen festen Text zurück. get() wartet, bis sie "
        "durchgelaufen ist, und reicht genau diesen Text heraus.",
    "z-con-24-4":
        "get() wartet, bis das Ergebnis da ist. Überleg, was passiert, wenn du schon "
        "nach der ersten Aufgabe wartest, statt erst alle einzureichen.",

    # ----------------------------------------------------------------- testing
    "t21-1":
        "Ein Test verändert nichts am Programm und macht es nicht schneller. Überleg, "
        "was er stattdessen tut: Er stellt eine Frage und vergleicht die Antwort.",
    "t21-2":
        "Die Reihenfolge ist festgelegt und wichtig für die Fehlermeldung. Schau, welcher "
        "der beiden Werte hier von Hand hingeschrieben wurde und welcher berechnet wird.",
    "t21-3":
        "Prüf für jede der drei Zeilen selbst, ob die Zahl gerade ist, und vergleich das "
        "mit dem erwarteten Wert. Bei einer Zeile ist die Erwartung schlicht falsch.",
    "t21-4":
        "Oben fehlt die Markierung mit dem Klammeraffen, an der JUnit die Testmethode "
        "erkennt. Unten die Prüfmethode, deren Name „gleich“ enthält.",
    "q-test-1a":
        "Die Methode liefert den Betrag, also den Wert ohne Vorzeichen. Prüf alle drei "
        "Erwartungen einzeln nach – hier stimmt jede.",
    "q-test-1b":
        "Tests, die nur den bequemen Fall abdecken, finden wenig. Überleg, an welchen "
        "Stellen Fehler typischerweise sitzen – am Rand oder in der Mitte.",
    "q-test-2a":
        "Ein Test ist auch nur Code und kann eine falsche Erwartung enthalten. "
        "Den Code passend zu biegen, bis es grün wird, verschiebt das Problem nur.",
    "q-test-3a":
        "Gesucht ist die JUnit-Methode, die erwarteten und tatsächlichen Wert vergleicht. "
        "Ihr Name beginnt mit „assert“ und endet auf dem englischen Wort für „gleich“.",
    "r-test-1a":
        "Rechne beide Aufrufe selbst aus. Beim zweiten sind beide Zahlen gleich – "
        "überleg, was die Methode dann liefert und was der Test erwartet.",
    "u-test-1":
        "In die Lücke gehört der Wert, der herauskommen soll. Rechne die Summe in der "
        "Zeile darüber einfach aus.",
    "u-test-2":
        "Die leere Liste ist der Fall, an den beim Schreiben niemand denkt. Genau deshalb "
        "stolpert der Code dort über Dinge, die sonst nie vorkommen.",
    "u-test-3":
        "Ein einziger Aufruf von pruefe mit drei Angaben: ein Name für die Ausgabe, "
        "der erwartete Wert und der Aufruf der zu prüfenden Methode.",
    "x-test-1a":
        "Der Name nennt beide Teile: „assert“ für behaupten, „Equals“ für gleich. "
        "Überleg, welche zwei Dinge dabei verglichen werden.",
    "x-test-2a":
        "Tests ändern weder Tempo noch Länge des Codes. Ihr Nutzen zeigt sich erst, "
        "wenn jemand später etwas umbaut.",
    "x-test-2b":
        "Rot ist die Farbe für „stimmt nicht“. Überleg, welche zwei Gründe es dafür gibt: "
        "ein abweichender Wert oder ein Abbruch mitten im Test.",
    "x-test-3a":
        "Prüf jede Zeile einzeln: Stimmt der erwartete Wert mit der Rechnung dahinter "
        "überein? Bei der letzten wird mit einer anderen Zahl multipliziert.",
    "x-test-4b":
        "Die Methode prüft, ob beim Teilen durch 2 nichts übrig bleibt. Denk daran, "
        "dass null glatt aufgeht und dass negative Zahlen dieselbe Regel befolgen.",
    "x-test-5a":
        "Drei Aufrufe von pruefe mit je einem Namen, dem erwarteten Wert und dem Aufruf "
        "der Methode. Der leere Text hat die Länge null.",
    "y-test-2":
        "Die erste Prüfung fragt, ob der leere Text leer ist. Bei der zweiten zähl die "
        "Zeichen des Wortes und vergleich sie mit der erwarteten Zahl.",

    # ----------------------------------------------------------------- tooling
    "t22-1":
        "Die Zeile steht ganz oben und nennt einen Namen mit Punkten. Überleg, was dieser "
        "Name im Dateisystem entspricht – und dass sie weder lädt noch startet.",
    "t22-2":
        "Ein Build-Werkzeug ist kein Editor und ändert den Code nicht. Überleg, welche "
        "Schritte zwischen Quelltext und fertigem Programm jedes Mal anfallen.",
    "t22-3":
        "Die Variable zeigt auf nichts, der Methodenaufruf darauf scheitert sofort. "
        "Der catch-Block greift, und die Zeile danach steht außerhalb.",
    "t22-4":
        "Vorne das Schlüsselwort, das den Fehler auffängt. Hinten die Ausnahme, die beim "
        "Teilen durch null entsteht – ihr Name enthält das Wort für Rechnen.",
    "q-tool-1a":
        "import erzeugt nichts und lädt keine Datei von der Platte. Es spart dir nur, "
        "den vollen Namen mitsamt Paket überall hinzuschreiben.",
    "q-tool-1b":
        "text zeigt auf nichts. Der Aufruf einer Methode darauf scheitert, bevor etwas "
        "ausgegeben wird – die letzte Zeile steht außerhalb des try.",
    "q-tool-2a":
        "Schau genau auf das Vergleichszeichen in der Schleife. Schreib auf, welche Werte "
        "i wirklich annimmt – die 4 gehört nicht dazu.",
    "q-tool-2b":
        "Ein Stacktrace liest sich von oben nach unten: erst das Was, dann der Weg dorthin. "
        "Der Name des Programmierers steht nirgends darin.",
    "r-tool-1a":
        "Das Vergleichszeichen lässt den Index einen Schritt zu weit laufen. Die gültigen "
        "Werte werden vorher noch alle ausgegeben, erst danach greift der catch-Block.",
    "u-tool-1":
        "Zwei Firmen können dieselbe Klasse „Liste“ nennen. Überleg, was eine Domain "
        "garantiert, was ein selbst ausgedachter Name nicht garantiert.",
    "u-tool-2":
        "Die Liste wurde angelegt, aber nie gefüllt. Der Zugriff auf Position null "
        "scheitert deshalb sofort.",
    "u-tool-3":
        "Vergleich, was die Aufgabe verlangt, mit dem, was die Schleife tut: Sie erhöht "
        "den Index um eins, nicht um zwei. Gefragt ist die tatsächliche Ausgabe.",
    "v-tool-4":
        "Vorne der Block, der den riskanten Zugriff umschließt, hinten der, der auffängt. "
        "Ein Array mit zwei Fächern hat kein Fach mit dem Index 3.",
    "x-tool-1a":
        "Pakete ändern nichts an Tempo oder Sichtbarkeit des Quelltextes. Überleg, welches "
        "Problem entsteht, wenn zwei Bibliotheken dieselbe Klasse gleich nennen.",
    "x-tool-1b":
        "Das c am Ende steht für „compiler“. Überleg, welcher der beiden Befehle aus "
        "dem Quelltext Bytecode macht und welcher diesen Bytecode laufen lässt.",
    "x-tool-2a":
        "In dieser Datei steht kein Java-Code und keine Ausgabe. Überleg, was ein "
        "Build-Werkzeug wissen muss, bevor es loslegen kann.",
    "x-tool-3a":
        "Die Ausgabe steht in der Schleife und zeigt nach jeder Runde den Zwischenstand. "
        "Rechne die Summe Runde für Runde mit.",
    "x-tool-4a":
        "Schau auf die Bedingung: Von der Länge wird eins abgezogen. Überleg, welches "
        "Fach dadurch nie erreicht wird.",
    "x-tool-5a":
        "Der Fehler steckt in der Schleifenbedingung, nicht im Addieren. Das letzte Fach "
        "wird nie besucht – ändere nur den Vergleich.",
    "y-tool-2":
        "Das try steht in der Schleife, deshalb geht es nach dem Fehler mit der nächsten "
        "Zahl weiter. Die erste Division geht glatt auf, die zweite nicht.",

    # ---------------------------------------------------------------- projects
    "t27-1":
        "Rechne den Schnitt einmal von Hand aus: Die Summe geht nicht glatt durch drei. "
        "Überleg, welcher Typ dieses Ergebnis überhaupt festhalten kann.",
    "t27-2":
        "Erst die Summe aller vier Noten. Danach wird sie durch die Anzahl geteilt – "
        "die Umwandlung vorne sorgt dafür, dass das Ergebnis Nachkommastellen behält.",
    "t27-3":
        "Zähl die Noten, die die Bedingung erfüllen; „kleiner oder gleich 4“ schließt "
        "die 4 selbst ein. Die Gesamtzahl steht daneben.",
    "t27-4":
        "Zwei Stream-Methoden: eine für den Mittelwert, eine für den kleinsten Wert. "
        "Beide heißen wie die englischen Wörter dafür.",
    "t28-1":
        "Ein record ist eine kurze Schreibweise für eine Wertklasse. Überleg, was er "
        "dir abnimmt, was du sonst selbst tippen müsstest.",
    "t28-2":
        "Die Zugriffsmethode heißt wie das Feld. Die Textform eines records nennt seinen "
        "Namen und jedes Feld mit seinem Wert in eckigen Klammern.",
    "t28-3":
        "Das Ausrufezeichen dreht die Bedingung um – gesucht sind also die nicht erledigten. "
        "Danach wird nur noch der Titel ausgegeben, jede Zeile einzeln.",
    "t28-4":
        "Ein record ist unveränderlich, das Häkchen lässt sich also nicht setzen. Ersetz "
        "stattdessen den Eintrag an Position null durch ein neues mit dem anderen Wert.",
    "t29-1":
        "Es geht nicht um Tempo. Überleg, was passiert, wenn jemand „Kueche“ statt "
        "„KUECHE“ tippt – bei Text merkt es niemand, beim enum schon.",
    "t29-2":
        "Der erste Schlüssel steht in der Map. Der zweite nicht – dann liefert "
        "getOrDefault den mitgegebenen Ersatzwert.",
    "t29-3":
        "Zwei Aufrufe mit verschiedenen Räumen. Such jeweils den passenden Fall im switch "
        "und gib dessen Text aus – in der Reihenfolge der Aufrufe.",
    "t29-4":
        "Vorne die Schleife, die jeden Befehl aus der Liste holt. Hinten die Methode, die "
        "bei unbekannter Richtung den aktuellen Raum als Ersatz zurückgibt.",
    "q-proj-1a":
        "Erst alle vier Noten aufaddieren, dann durch die Anzahl teilen. Die Umwandlung "
        "sorgt dafür, dass das Ergebnis eine Kommazahl bleibt – auch bei glattem Ergebnis.",
    "q-proj-1b":
        "Das Ausrufezeichen kehrt die Bedingung um: gesucht sind die offenen Aufgaben. "
        "Davon gibt es hier nur eine.",
    "q-proj-2a":
        "Der Schlüssel „sueden“ steht nicht in der Map. getOrDefault liefert dann den "
        "Ersatzwert, der als zweites Argument dabeisteht.",
    "v-grd-1":
        "Rechne einen Schnitt von Hand aus: Er geht fast nie glatt auf. Überleg, was "
        "ein int mit den Nachkommastellen macht.",
    "v-grd-3":
        "„Kleiner oder gleich 4“ schließt die 4 selbst mit ein. Geh die fünf Noten "
        "einzeln durch und zähl die Treffer.",
    "v-grd-4":
        "Zwei Stream-Methoden: eine für den Mittelwert, eine für den größten Wert. "
        "Die schlechteste Note ist hier die höchste Zahl.",
    "v-grd-5":
        "Nimm die erste Note als vorläufig beste und zugleich als vorläufig schlechteste. "
        "Vergleich jede weitere gegen beide – mit 0 zu starten ginge schief.",
    "v-todo-1":
        "Ein record ist nicht schneller und erlaubt gerade kein nachträgliches Ändern. "
        "Überleg, welche immer gleichen Bausteine er dir fertig mitbringt.",
    "v-todo-2":
        "Die Zugriffsmethode heißt wie das Feld und liefert dessen Wert. Danach die "
        "Textform, die Name und alle Felder in eckigen Klammern nennt.",
    "v-todo-4":
        "Vorne die Methode, die hinten anhängt. Hinten die, die einen vorhandenen Eintrag "
        "an einer Position ersetzt – ein record lässt sich nicht nachträglich ändern.",
    "v-todo-5":
        "Lauf mit einer for-each-Schleife über die Liste und entscheide je Aufgabe, "
        "welches Häkchen davor gehört. Der Fragezeichen-Operator macht das in einer Zeile.",
    "v-adv-1":
        "Es geht nicht um Speicher oder Tempo – Texte lassen sich durchaus vergleichen. "
        "Überleg, wann ein vertippter Raumname auffällt: beim Übersetzen oder erst im Spiel.",
    "v-adv-3":
        "Zwei Aufrufe, und der zweite Raum kommt zuerst dran. Such je den passenden "
        "Fall im switch.",
    "v-adv-4":
        "Vorne die Schleife über das Array der Befehle. Hinten die Methode, die bei "
        "unbekannter Richtung den aktuellen Raum als Ersatz liefert – du bleibst dann stehen.",
    "v-adv-5":
        "Eine Schleife über die Befehle, darin der Zugriff auf die Türen mit dem aktuellen "
        "Raum als Ersatzwert. So bleibst du bei einer unbekannten Richtung einfach stehen.",
    "y-proj-1":
        "Die Schleife addiert alle drei Noten nacheinander auf. "
        "Rechne Runde für Runde mit.",
    "z-proj-28-3":
        "Eine for-each-Schleife über die Liste und darin eine Bedingung auf das Häkchen. "
        "Das Ausrufezeichen kehrt sie um, damit die offenen übrig bleiben.",
    "z-proj-28-4":
        "Ein record lässt sich nicht ändern. Hol den alten Eintrag, bau daraus einen neuen "
        "mit demselben Titel und gesetztem Häkchen und ersetz ihn an Position null.",
    "z-proj-29-1":
        "Zwei Dinge: der Name des Raums, so wie er im enum steht, und die Anzahl aller "
        "Werte über die Länge von values().",
    "z-proj-29-4":
        "Die Karte ist zweistufig: erst den aktuellen Raum nachschlagen, dann darin die "
        "Richtung. Bei unbekannter Richtung dient der aktuelle Raum selbst als Ersatzwert.",

    # -------------------------------------------------------------- umlbasics
    "t30-1":
        "Der Kasten wird von oben nach unten gelesen: erst die Überschrift, dann der Zustand, "
        "dann das Verhalten. Überleg, was davon die Überschrift ist.",
    "t30-2":
        "UML kennt drei Sichtbarkeitszeichen: Plus, Minus und Doppelkreuz. Das Minus ist "
        "das strengste davon – überleg, wer damit noch Zugriff hat.",
    "t30-3":
        "In UML steht der Rückgabetyp hinter dem Doppelpunkt am Zeilenende, nicht vorne "
        "wie in Java. Lies dort ab, was die Methode liefert.",
    "t30-4":
        "In UML steht der Name vorne und der Typ hinter dem Doppelpunkt – in Java ist es "
        "umgekehrt. Das Minus wird zur strengsten Sichtbarkeit.",
    "t30-5":
        "Das Minus im Diagramm wird zu private, das Plus zu public. In Java steht der Typ "
        "vor dem Namen, nicht dahinter. Die Methode gibt das Feld einfach zurück.",
    "t32-2":
        "Das Plus steht für öffentlich. Eine Methode ohne Rückgabewert bekommt in UML "
        "keinen Doppelpunkt mit Typ – da steht dann gar nichts.",
    "r-uml-1a":
        "Such die Zeile im unteren Fach, vor der ein Minus steht. Die anderen Zeichen "
        "bedeuten öffentlich oder geschützt.",
    "r-uml-1b":
        "Attribute stehen im mittleren Fach des Kastens, nicht im unteren. "
        "Zähl nur die Zeilen dort.",
    "r-uml-2a":
        "protected ist die mittlere Sichtbarkeit, zwischen public und private. In UML "
        "steht dafür das Doppelkreuz, und der Typ kommt hinter den Doppelpunkt.",
    "v-uml-30-5":
        "Das Minus wird zu private, das Plus zu public. In Java steht der Typ vor dem "
        "Namen. Die Methode liefert schlicht das Feld zurück – ihr Rückgabetyp ist boolean.",
    "v-uml-32-2":
        "private wird in UML zum Minus. Danach kommt erst der Name, dann der Doppelpunkt "
        "und zuletzt der Typ – genau umgekehrt zu Java.",
    "x-uml-1a":
        "Der Kasten trennt drei Dinge voneinander: wie die Klasse heißt, was sie weiß "
        "und was sie kann. Jedes bekommt ein eigenes Fach.",
    "x-uml-2a":
        "Die drei Zeichen Plus, Minus und Doppelkreuz stehen für Sichtbarkeiten, nicht "
        "für Neuigkeit oder Rückgabetyp. Das Plus ist das großzügigste davon.",
    "x-uml-3a":
        "Das Minus wird zu private. Danach dreht sich die Reihenfolge um: In Java kommt "
        "erst der Typ, dann der Name – und ohne Klammern, denn es ist ein Feld.",
    "x-uml-4b":
        "Ein privates Feld mit dem Typ aus dem Diagramm, dazu zwei öffentliche Methoden. "
        "Die eine verändert den Stand und gibt nichts zurück, die andere liefert ihn.",
    "x-uml-5a":
        "Zwei private Felder, dazu ein Konstruktor, der beide füllt – bei gleichen Namen "
        "hilft this. umschalten() gibt nichts zurück, es setzt nur die Farbe.",
    "x-uml-5b":
        "Zwei private Felder mit den Typen aus dem Diagramm, ein Konstruktor für beide "
        "und zwei Methoden: eine liefert den Namen, die andere erhöht das Alter um eins.",
    "z-uml-32-2":
        "Das Konto startet bei null, weil ein double-Feld ohne Zuweisung so beginnt. "
        "Danach wird einmal eingezahlt – achte auf die Nachkommastelle in der Ausgabe.",
    "p-uml-1a":
        "Das Doppelkreuz ist die mittlere der drei Sichtbarkeiten. Überleg, wer außer "
        "der Klasse selbst noch herankommt – es hat mit Vererbung zu tun.",
    "p-uml-1b":
        "Der Kasten hat drei Fächer in fester Reihenfolge: Name, Zustand, Verhalten. "
        "Methoden sind das Verhalten.",

    # ------------------------------------------------------------ umlrelations
    "t31-1":
        "Die Dreiecksspitze zeigt immer nach oben zum Allgemeineren. Lies die Beziehung "
        "als „ist ein“ und prüf, welche Richtung dabei Sinn ergibt.",
    "t31-2":
        "Die gestrichelte Linie mit Dreiecksspitze führt auf ein Interface, nicht auf eine "
        "Klasse. Für Klassen gäbe es ein anderes Schlüsselwort.",
    "t31-3":
        "Es gibt zwei Rauten: eine leere und eine gefüllte. Die gefüllte bedeutet "
        "Schicksalsgemeinschaft – überleg, was dann für die leere übrig bleibt.",
    "t31-4":
        "Der Stern steht für „beliebig viele“, die Zahl davor für die Untergrenze. "
        "Lies „1..*“ also als Spanne von einem Minimum bis nach oben offen.",
    "t31-5":
        "Es gibt kein Feld vom Typ Drucker – die Verbindung besteht nur für die Dauer "
        "des Methodenaufrufs. Für so eine lose Verbindung gibt es die schwächste Linie.",
    "t32-1":
        "Das Diagramm zeigt eine Vererbung zwischen zwei Klassen, kein Interface und "
        "kein Feld. Achte darauf, welche Klasse dabei die Eltern-Rolle hat.",
    "t32-3":
        "Die Variable hat den Typ der abstrakten Klasse, das Objekt ist ein Quadrat. "
        "Die Fläche ist ein double – achte auf die Nachkommastelle.",
    "t32-4":
        "Fahrbar ist ein Interface, keine Klasse. Dafür gibt es ein eigenes Schlüsselwort, "
        "dessen Name „setzt um“ bedeutet.",
    "t32-5":
        "Hund erbt mit extends von Tier und ersetzt die geerbte Methode. Die Markierung "
        "darüber mit dem Klammeraffen kennzeichnet das Überschreiben.",
    "r-uml-2b":
        "Der Stern allein setzt keine Untergrenze – auch null wäre erlaubt. Achte darauf, "
        "an welchem Ende der Linie er steht und wen er damit beschreibt.",
    "r-uml-3a":
        "„Bleiben erhalten“ ist genau der Unterschied zwischen den beiden Rauten. "
        "Die gefüllte bedeutet: Es geht gemeinsam unter.",
    "r-uml-3b":
        "Die Fläche wird hier mit 3.0 statt mit π gerechnet – nimm die Formel so, wie sie "
        "dasteht. Das Ergebnis ist ein double und bekommt eine Nachkommastelle.",
    "v-uml-31-1":
        "Die Spitze zeigt nicht auf den größeren Kasten und nicht auf den mit mehr "
        "Methoden. Lies den Pfeil als „ist ein“ – dann ist die Richtung eindeutig.",
    "v-uml-31-5":
        "„Nur kurz in einer Methode“ heißt: kein Feld, keine dauerhafte Verbindung. "
        "Dafür gibt es die schwächste der vier Beziehungen.",
    "v-uml-32-1":
        "Die gestrichelte Linie führt auf ein Interface. In Java heißt das nicht erben, "
        "sondern umsetzen – und die Klasse steht dabei links.",
    "v-uml-32-4":
        "Zwei Klassen, keine Interfaces – gesucht ist das Schlüsselwort für Vererbung "
        "zwischen Klassen. Es bedeutet „erweitert“.",
    "v-uml-32-5":
        "Auto setzt das Interface um, nicht erbt davon. Die Methode aus dem Vertrag muss "
        "public sein, weil Interface-Methoden das immer sind.",
    "x-umlr-5a":
        "Die Räume entstehen im Konstruktor des Hauses – das ist die gefüllte Raute. "
        "Ein Feld mit einer Liste, die dort gefüllt wird, und eine Methode für die Anzahl.",
    "x-umlr-5b":
        "Der Kunde wird von außen übergeben und lebt weiter – das ist die leere Raute. "
        "Er gehört als Feld in die Bestellung und kommt über den Konstruktor hinein.",
    "y-uml-31-1":
        "Der Hund überschreibt die geerbte Methode und hat zusätzlich eine eigene. "
        "Beide werden nacheinander aufgerufen.",
    "z-uml-31-5":
        "Abhängigkeit heißt: kein Feld vom Typ Drucker. Der Drucker kommt nur als "
        "Parameter der Methode herein und wird darin benutzt.",
    "z-uml-32-1":
        "Zwei Objekte, zwei verschiedene Klassen: das eine die Eltern-Klasse, das andere "
        "das Kind mit der überschriebenen Methode. Jede liefert ihren eigenen Text.",
    "z-uml-32-4":
        "„Unterschreibt den Vertrag“ ist das Bild für ein Interface. Das Schlüsselwort "
        "dafür bedeutet „setzt um“, und die Methode muss public sein.",
    "p-uml-2a":
        "Gefüllt heißt: fest verbunden. Überleg, was mit den Räumen passiert, wenn das "
        "Haus abgerissen wird – genau das unterscheidet sie von der leeren Raute.",
    "p-uml-2b":
        "Die Untergrenze steht vorne, die Obergrenze hinten. Gesucht ist die Spanne, "
        "die bei null anfängt und bei eins aufhört.",
    "p-uml-3a":
        "Die gestrichelte Linie mit Dreiecksspitze führt auf ein Interface. Die Klasse "
        "steht links vom Schlüsselwort, das „setzt um“ bedeutet.",
}
