"""Begründungen zu falschen Antworten – Fortsetzung von why_wrong.py.

Gleiche Regel wie dort: Zugeordnet wird über den **Antworttext**, nicht über die
Position, weil die Antworten beim Erzeugen gedreht werden. Passt ein Text nicht mehr
zur Aufgabe, bricht der Kursbau ab.

Jede Begründung beantwortet dieselbe Frage: Warum klingt diese Antwort plausibel –
und woran genau scheitert sie? Ein bloßes „das stimmt nicht“ hilft beim Lernen nicht.
"""

WHY_WRONG_MORE = {
    # ---------------------------------------------------------------- Enums, Objektmethoden, Texte
    "t14-1": {
        "Um Dateien zu speichern":
            "Dateien liest und schreibt man mit Klassen wie Files oder Scanner. Ein enum ist ein Typ "
            "mit festen Werten und hat damit nichts zu tun.",
        "Für beliebig viele Zahlen":
            "Die Werte eines enums stehen im Quelltext fest und lassen sich zur Laufzeit nicht "
            "vermehren. Für beliebig viele Zahlen nimmt man eine Liste.",
        "Für lange Texte":
            "Text speichert ein String. Ein enum hat zwar Namen, aber das sind Bezeichner für feste "
            "Möglichkeiten – kein frei wählbarer Inhalt.",
    },
    "t15-1": {
        "equals()": "equals entscheidet, ob zwei Objekte inhaltlich gleich sind. Mit der Ausgabe hat das nichts zu tun.",
        "hashCode()": "hashCode liefert eine Zahl für Hash-Tabellen wie HashMap. Sie erscheint zwar in der "
                      "Standardausgabe von Object, steuert diese aber nicht.",
        "main()": "main ist der Startpunkt des Programms. Was beim Ausgeben eines Objekts erscheint, entscheidet es nicht.",
    },
    "t15-2": {
        "Es gibt keinen Unterschied":
            "Der Unterschied ist erheblich: Zwei Texte mit gleichem Inhalt können zwei verschiedene "
            "Objekte sein – dann liefert == false und equals true.",
        "equals vergleicht nur Zahlen":
            "Genau umgekehrt: Für Grundtypen wie int gibt es gar kein equals. Es ist gerade für Objekte gedacht.",
        "== vergleicht nur Texte":
            "== funktioniert für alles, fragt aber immer nach der Identität. Bei Texten ist das fast nie "
            "die Frage, die man beantwortet haben will.",
    },
    "t16-1": {
        "Er macht Texte automatisch groß":
            "Die Schreibweise ändert toUpperCase. Der StringBuilder verändert nur den Aufbau des Textes.",
        "Er ist die einzige Art, Texte auszugeben":
            "Ausgegeben wird weiterhin mit System.out.println. Der StringBuilder setzt den Text nur zusammen.",
        "Er übersetzt Texte":
            "Übersetzen kann Java von sich aus nicht. Der StringBuilder ist ein Bauplatz zum Zusammensetzen.",
    },
    "t17-1": {
        "Weil try Dateien automatisch speichert":
            "Speichern muss man selbst. try sorgt dafür, dass ein Fehler abgefangen wird – und schließt "
            "bei try-with-resources die Datei wieder.",
        "Das ist nur eine Stilfrage":
            "Bei IOException hat man keine Wahl: Sie ist eine checked Exception, und ohne catch oder "
            "throws übersetzt Java die Klasse gar nicht erst.",
        "Weil Dateien sonst langsamer sind":
            "Auf die Geschwindigkeit hat try keinen Einfluss. Es geht allein darum, auf Fehler vorbereitet zu sein.",
    },
    "t18-1": {
        "Eine for-Schleife":
            "Gerade nicht – Rekursion ersetzt die Schleife. Die Wiederholung entsteht durch den Aufruf der Methode selbst.",
        "Einen Parameter vom Typ String":
            "Der Typ spielt keine Rolle. Wichtig ist nur, dass sich der Wert Schritt für Schritt dem Basisfall nähert.",
        "Ein static-Feld":
            "Ein gemeinsames Feld bräuchte man gerade nicht – jeder Aufruf arbeitet mit seinen eigenen Werten.",
    },
    "t19-1": {
        "Die Daten müssen Texte sein":
            "Die Sorte ist egal, solange sich die Werte vergleichen lassen. Entscheidend ist allein die Sortierung.",
        "Es dürfen höchstens 10 Elemente sein":
            "Gerade bei vielen Elementen lohnt sie sich. Bei zehn wäre der Unterschied zur linearen Suche kaum spürbar.",
        "Man braucht eine HashMap":
            "Eine HashMap findet über den Schlüssel direkt – da braucht es gar keine Suche. Die binäre "
            "Suche arbeitet auf sortierten Listen oder Arrays.",
    },
    "t19-2": {
        "Etwa 1 000":
            "Das wäre ein Tausendstel – immer noch viel zu viel. Weil sich der Bereich bei jedem Schritt "
            "halbiert, wächst die Zahl der Schritte extrem langsam.",
        "Etwa 500 000": "Die Hälfte anzuschauen ist der Durchschnitt der linearen Suche, nicht der binären.",
        "Genau 1 000 000": "Alles anzusehen wäre der schlimmste Fall der linearen Suche – genau das vermeidet die binäre.",
    },
    "t20-1": {
        "Eine Warteschlange (Queue)":
            "Die Warteschlange gibt das Älteste zuerst heraus – sie würde also die allererste Änderung "
            "zurücknehmen statt der letzten.",
        "Ein Set": "Ein Set kennt weder Reihenfolge noch Doppelte. Beides bräuchte man hier.",
        "Ein Array fester Länge":
            "Ein Array könnte die Änderungen zwar halten, aber das Verwalten müsste man von Hand "
            "schreiben – genau das nimmt einem der Stapel ab.",
    },
    "t21-1": {
        "Er löscht fehlerhaften Code":
            "Ein Test findet Fehler, er behebt sie nicht. Was mit dem Befund passiert, entscheidet der Mensch.",
        "Er macht das Programm schneller":
            "Tests laufen getrennt vom Programm und haben auf dessen Geschwindigkeit keinen Einfluss.",
        "Er übersetzt Java in eine andere Sprache":
            "Übersetzt wird von javac – und zwar in Bytecode. Damit hat ein Test nichts zu tun.",
    },
    "t21-2": {
        "Erst das Ergebnis, dann der erwartete Wert":
            "Der Test besteht dann zwar trotzdem – aber wenn er scheitert, steht die Meldung auf dem "
            "Kopf: erwartet und tatsächlich wären vertauscht.",
        "Es muss immer 0 zuerst stehen":
            "Die 0 hat keine Sonderstellung. Zuerst steht immer der erwartete Wert, welcher auch immer das ist.",
        "Die Werte stehen in zwei getrennten Zeilen":
            "assertEquals nimmt beide Werte in einem einzigen Aufruf, getrennt durch ein Komma.",
    },
    "t22-1": {
        "Sie lädt eine Bibliothek aus dem Internet":
            "Das ist Sache des Build-Werkzeugs. package sagt nur, wo die eigene Klasse einsortiert ist.",
        "Sie startet das Programm":
            "Gestartet wird über die Methode main. package steht zwar ganz oben, führt aber nichts aus.",
        "Sie macht die Klasse unsichtbar":
            "Sichtbarkeit regeln public und private. Ein Paket ordnet nur ein.",
    },
    "t22-2": {
        "Es ist ein Texteditor":
            "Geschrieben wird der Code weiterhin im Editor. Das Build-Werkzeug übernimmt erst danach.",
        "Es macht Java-Code kürzer": "Am Code ändert es nichts – es automatisiert die Schritte drumherum.",
        "Es ersetzt die main-Methode": "Die main-Methode bleibt der Startpunkt. Das Werkzeug ruft sie nur auf.",
    },
    "t23-1": {
        "Es verbindet zwei Threads zu einem":
            "Der Name führt in die Irre: Zusammengelegt wird nichts. join heißt hier „sich wieder treffen“.",
        "Es startet den Thread": "Gestartet wird mit start(). join kommt danach, wenn man auf das Ende warten will.",
        "Es beendet das Programm sofort": "Beendet wird nichts – im Gegenteil, das Hauptprogramm wartet ab.",
    },
    "t23-2": {
        "Immer B zuerst":
            "Eine feste Reihenfolge gibt es nicht. Wer zuerst drankommt, entscheidet das Betriebssystem – "
            "und das kann bei jedem Lauf anders ausfallen.",
        "Es erscheint nur A": "Beide Threads laufen und geben aus. Unbestimmt ist allein die Reihenfolge.",
        "Immer A zuerst":
            "Dass A im Code zuerst gestartet wird, heißt nicht, dass es zuerst ausgibt. Genau darin liegt "
            "die Tücke der Nebenläufigkeit.",
    },
    "t24-1": {
        "Ein Fehler, der erst später auftritt": "Der Name klingt danach, meint aber das Gegenteil: ein Ergebnis, das noch kommt.",
        "Ein Thread, der nie endet": "Ein Future ist kein Thread, sondern der Zettel, mit dem man dessen Ergebnis abholt.",
        "Eine Liste aller Threads": "Ein Future gehört zu genau einer Aufgabe, nicht zu vielen.",
    },
    "t24-2": {
        "Für genau eine Aufgabe pro Programm":
            "Für eine einzige Aufgabe bräuchte man gar keine Threads. Der Vorteil zeigt sich erst bei sehr vielen.",
        "Um den Arbeitsspeicher zu löschen": "Aufräumen ist Sache der Speicherbereinigung. Threads führen Code aus.",
        "Nur für Grafik": "Mit Grafik haben sie nichts zu tun. Es geht um viele gleichzeitig wartende Aufgaben.",
    },
    "t25-1": {
        "Tier kann nicht benutzt werden": "Benutzen darf man es ganz normal. Eingeschränkt ist nur, wer es umsetzen darf.",
        "Hund und Katze sind privat": "Sichtbarkeit regelt private. permits sagt nur, wer zur Familie gehört.",
        "Tier darf beliebig viele Umsetzungen haben": "Genau das verhindert sealed – nur die aufgezählten Typen sind erlaubt.",
    },
    "t26-1": {
        "Einen sortierten Text": "Sortieren macht sorted, Text entsteht mit joining. groupingBy legt Fächer an.",
        "Nichts – es gibt nur aus": "Ausgeben tut es gar nichts. Es sammelt ein und gibt das Ergebnis zurück.",
        "Eine einzelne Zahl": "Eine einzelne Zahl käme von count oder sum. Hier kommt eine ganze Map heraus.",
    },
    "t27-1": {
        "int": "Mit int fiele die Nachkommastelle weg: Aus 1,67 würde 1. Genau die Information, um die es "
               "beim Durchschnitt geht, ginge verloren.",
        "boolean": "boolean kennt nur true und false – damit lässt sich kein Durchschnitt darstellen.",
        "char": "char hält genau ein Zeichen. Ein Durchschnitt ist keine Buchstabenangabe.",
    },
    "t28-1": {
        "Er kann sich selbst abhaken": "Gerade nicht: Ein Record ist unveränderlich. Abhaken heißt, einen neuen zu erzeugen.",
        "Er speichert Daten automatisch in einer Datei":
            "Speichern muss man selbst. Ein Record hält die Daten nur im Arbeitsspeicher zusammen.",
        "Er ist schneller als jede Liste":
            "Record und Liste lösen verschiedene Aufgaben – der eine bündelt Felder, die andere reiht Elemente aneinander.",
    },
    "t29-1": {
        "Ein enum ist ein Wörterbuch":
            "Ein Wörterbuch wäre eine Map mit Schlüsseln und Werten. Ein enum ist eine Aufzählung fester Möglichkeiten.",
        "Damit das Spiel schneller lädt":
            "Auf die Ladezeit hat das keinen Einfluss. Der Gewinn liegt in der Sicherheit schon beim Übersetzen.",
        "Strings können keine Räume speichern":
            "Könnten sie – nur würde ein Tippfehler wie „Kueche“ erst beim Spielen auffallen statt beim Übersetzen.",
    },

    # ---------------------------------------------------------------- UML
    "t30-1": {
        "Die Methoden": "Die Methoden stehen im untersten Fach, nicht im obersten.",
        "Der Konstruktor": "Der Konstruktor taucht in einem einfachen Klassendiagramm meist gar nicht auf – "
                           "und wenn, dann bei den Methoden.",
        "Die Attribute": "Die Attribute stehen im mittleren Fach, zwischen Name und Methoden.",
    },
    "t30-2": {
        "öffentlich – von überall nutzbar": "Öffentlich wäre ein Pluszeichen. Das Minus bedeutet genau das Gegenteil.",
        "geschützt – auch in Kind-Klassen nutzbar": "Geschützt wäre ein Doppelkreuz #. Das Minus schließt auch Kind-Klassen aus.",
        "Das Attribut ist gelöscht": "Gelöschte Dinge stehen gar nicht erst im Diagramm. Das Minus ist eine Sichtbarkeitsangabe.",
    },
    "t30-3": {
        "int": "int stünde dort, wenn die Methode eine ganze Zahl lieferte. Lies nach, was im Diagramm wirklich hinter dem Doppelpunkt steht.",
        "void – sie liefert nichts": "Bei void stünde hinter dem Namen gar kein Typ. Hier steht einer.",
        "Person": "Person ist die Klasse, zu der die Methode gehört – nicht das, was sie zurückgibt.",
    },
    "t30-4": {
        "public double stand;": "public wäre ein Pluszeichen im Diagramm. Dort steht ein Minus, also private.",
        "double stand();": "Die runden Klammern machen daraus eine Methode. Im Kasten steht hinter stand keine Klammer.",
        "private stand: double;": "Das ist die UML-Reihenfolge, nicht die von Java. In Java steht der Typ vor dem Namen.",
    },
    "t31-1": {
        "Tier erbt von Hund": "Die Spitze zeigt zur allgemeineren Klasse. Sie zeigt hier auf Tier, also erbt Hund.",
        "Hund besteht aus Tieren": "„Besteht aus“ wäre eine Raute, keine Dreiecksspitze.",
        "Hund benutzt Tier kurzzeitig": "Kurzzeitiges Benutzen wäre ein gestrichelter Pfeil ohne Dreiecksspitze.",
    },
    "t31-2": {
        "import": "import holt eine Klasse aus einem anderen Paket herein. Im Diagramm taucht das gar nicht auf.",
        "extends": "extends wäre eine durchgezogene Linie. Gestrichelt bedeutet: Vertrag statt Erbe.",
        "new": "new erzeugt ein Objekt. Eine Beziehung zwischen Klassen beschreibt es nicht.",
    },
    "t31-3": {
        "Komposition: Ohne die Schulklasse gibt es die Schüler nicht":
            "Das wäre die gefüllte Raute. Die leere sagt gerade, dass die Teile unabhängig weiterleben.",
        "Vererbung: Schueler erbt von Schulklasse":
            "Vererbung hätte eine Dreiecksspitze statt einer Raute – und inhaltlich ist ein Schüler keine Schulklasse.",
        "Abhängigkeit: Die Schulklasse benutzt Schüler nur kurz":
            "Kurzes Benutzen wäre ein gestrichelter Pfeil. Die Raute steht für ein dauerhaftes Enthalten.",
    },
    "t31-4": {
        "Ein Haus hat höchstens einen Raum": "Der Stern steht für „beliebig viele“. Eine Obergrenze gibt es hier nicht.",
        "Ein Haus hat genau einen Raum": "Genau einer wäre die Vielfachheit 1. Der Stern erlaubt mehr.",
        "Ein Haus hat keine oder einen Raum": "Keiner wäre 0..1. Die 1 vor den Punkten verlangt mindestens einen.",
    },
    "t31-5": {
        "Komposition – gefüllte Raute":
            "Komposition hieße: Das Ganze erzeugt die Teile und sie vergehen mit ihm. Ein Parameter lebt aber unabhängig weiter.",
        "Vererbung – Dreiecksspitze": "Vererbung hieße, eine Rechnung wäre ein Drucker. Sie benutzt ihn nur.",
        "Aggregation – leere Raute":
            "Aggregation wäre ein dauerhaftes Feld. Hier existiert der Drucker nur während des Methodenaufrufs.",
    },
    "t32-1": {
        "class Hund implements Tier { }": "implements gehört zur gestrichelten Linie. Hier ist sie durchgezogen, also Vererbung.",
        "class Hund { Tier tier; }": "Ein Feld wäre eine Assoziation – eine einfache Linie ohne Dreiecksspitze.",
        "class Tier extends Hund { }": "Die Richtung stimmt nicht: Die Spitze zeigt auf Tier, also erbt Hund von Tier.",
    },
    "t32-2": {
        "- einzahlen()": "Das Minus bedeutet privat. Die Methode ist aber public, also ein Plus.",
        "+ einzahlen(): double": "Hinter dem Doppelpunkt stünde der Rückgabetyp. Die Methode ist void, deshalb entfällt er.",
        "# einzahlen(): void": "Das Doppelkreuz steht für protected. Hier ist die Methode public.",
    },

    # ---------------------------------------------------------------- Übungspool
    "p-var-1a": {
        "boolean": "boolean kennt nur true und false – Zahlen passen dort nicht hinein.",
        "char": "char hält genau ein Zeichen, etwa 'A'. Eine Kommazahl ist kein Zeichen.",
        "int": "int speichert nur ganze Zahlen. Eine Kommazahl lehnt Java dort ab, statt sie zu runden.",
    },
    "p-var-1b": {
        "Ein einzelnes Zeichen": "Ein Zeichen gehört in eine char-Box, in einfachen Anführungszeichen.",
        "Beliebiger Text": "Text gehört in einen String. „true“ in Anführungszeichen wäre Text, kein Wahrheitswert.",
        "Jede ganze Zahl": "Anders als in manchen anderen Sprachen gilt in Java keine Zahl als wahr oder falsch.",
    },
    "p-var-3a": {
        "final macht die Box kleiner": "Mit dem Speicherbedarf hat final nichts zu tun – der hängt nur am Typ.",
        "final wandelt die Box in Text um": "Der Typ bleibt derselbe. final betrifft nur, ob neu zugewiesen werden darf.",
        "final löscht den Inhalt nach der Nutzung": "Gelöscht wird nichts – im Gegenteil, der Wert bleibt dauerhaft erhalten.",
    },
    "p-op-3a": {
        "7 % 2": "% liefert den Rest, hier also 1. Nach dem Ergebnis der Division fragt es gar nicht.",
        "(int) 7 / 2": "Der Cast macht die 7 wieder zu einer ganzen Zahl – die Ganzzahldivision bleibt, es kommt 3 heraus.",
        "7 / 2": "Zwei ganze Zahlen ergeben eine ganze Zahl: 3, nicht 3.5. Eine Seite muss eine Kommazahl sein.",
    },
    "p-meth-1b": {
        "Die Methode gibt immer 0 zurück": "0 zurückzugeben wäre ein int. void heißt, dass gar nichts zurückkommt.",
        "Die Methode darf nicht aufgerufen werden":
            "Aufrufen darf man sie ganz normal – man kann ihr Ergebnis nur nicht verwenden, weil es keines gibt.",
        "Die Methode gibt einen leeren Text zurück": "Ein leerer Text wäre ein String. void ist etwas anderes: gar kein Wert.",
    },
    "p-str-2a": {
        "==": "== fragt, ob es dasselbe Objekt ist. Zwei Texte mit gleichem Inhalt können verschiedene "
              "Objekte sein – dann kommt false heraus.",
        "compare": "compare gibt es bei String nicht. Fürs Sortieren gäbe es compareTo – gefragt ist aber der reine Inhaltsvergleich.",
        "=": "Ein einzelnes Gleichheitszeichen vergleicht nichts, es weist zu.",
    },
    "p-oop-1a": {
        "Er vergleicht zwei Objekte": "Vergleichen ist Sache von equals. Der Konstruktor läuft nur beim Erzeugen.",
        "Er wandelt ein Objekt in Text um": "Das macht toString. Der Konstruktor füllt die Felder.",
        "Er löscht ein Objekt aus dem Speicher":
            "Löschen übernimmt die Speicherbereinigung von selbst. Der Konstruktor ist der Anfang, nicht das Ende.",
    },
    "p-oop-2a": {
        "Damit das Programm schneller läuft": "Auf die Geschwindigkeit hat private keinen Einfluss.",
        "Damit die Felder weniger Speicher brauchen": "Der Speicherbedarf hängt am Typ, nicht an der Sichtbarkeit.",
        "Weil Java sonst einen Fehler meldet":
            "Öffentliche Felder sind erlaubt. Sie nehmen der Klasse nur die Kontrolle darüber, was hineingeschrieben wird.",
    },
    "p-inh-1a": {
        "super": "super greift auf die Eltern-Klasse zu. Eine Beziehung zu einem Interface stellt es nicht her.",
        "new": "new erzeugt ein Objekt. Mit Interfaces hat es nichts zu tun.",
        "extends": "extends ist für Klassen – man erbt fertigen Code. Bei einem Interface unterschreibt man nur einen Vertrag.",
    },
    "p-inh-2a": {
        "Es macht die Klasse abstrakt": "Abstrakt wird eine Klasse mit dem Wort abstract.",
        "Es erzeugt ein zweites Objekt": "Es entsteht nur ein Objekt. super füllt lediglich den geerbten Teil davon.",
        "Es löscht geerbte Methoden": "Gelöscht wird nichts. Ersetzen ginge mit einer gleichnamigen Methode.",
    },
    "p-exc-1b": {
        "Sie kann nicht gefangen werden": "Fangen kann man sie sehr wohl – man muss es sogar.",
        "Sie tritt nur beim Rechnen auf": "Beim Rechnen entsteht die ArithmeticException. IOException kommt von Dateien und Netzwerk.",
        "Sie beendet das Programm immer sofort":
            "Nur wenn sie niemand fängt. Genau deshalb verlangt Java, dass man sich vorher darum kümmert.",
    },
    "p-col-2b": {
        "Die Liste hat höchstens String-viele Plätze": "Eine Größe steht dort nie. Eine Liste wächst nach Bedarf.",
        "Die Liste wandelt alles in Text um": "Umgewandelt wird nichts. Was nicht passt, lehnt der Compiler ab.",
        "Die Liste ist nach Text sortiert": "Über die Reihenfolge sagen die spitzen Klammern nichts. Sortiert wird mit sort.",
    },
    "q-syn-1a": {
        "public void start()": "Der Name start hat für Java keine besondere Bedeutung – niemand würde die Methode aufrufen.",
        "static void run()": "run gehört zu Threads. Als Startpunkt des Programms sucht Java ausschließlich main.",
        "public static begin()": "Hier fehlt außerdem der Rückgabetyp – und begin kennt Java gar nicht.",
    },
    "q-syn-1b": {
        "print ist schneller, sonst gleich": "Mit Geschwindigkeit hat es nichts zu tun. Der Unterschied ist der Zeilenumbruch am Ende.",
        "print schreibt in eine Datei, println auf den Bildschirm": "Beide schreiben nach System.out, also auf den Bildschirm.",
        "print schreibt nur Zahlen, println nur Text": "Beide nehmen alles entgegen – Zahlen wie Text.",
    },
    "q-var-2a": {
        "Die Variable kann jeden Typ annehmen": "Der Typ steht nach der ersten Zuweisung fest. var spart nur das Hinschreiben.",
        "Die Variable ist eine Konstante": "Unveränderlich macht sie erst final. var allein nicht.",
        "Die Variable hat noch keinen Typ": "Sie hat einen – Java liest ihn nur aus dem Wert rechts ab.",
    },
    "q-op-2a": {
        "Wenn mindestens eine Bedingung wahr ist": "Das wäre ||. Bei && müssen beide stimmen.",
        "Wenn beide Bedingungen falsch sind": "Dann ist das Ganze falsch. && verlangt zweimal wahr.",
        "Immer, wenn alter mindestens 18 ist": "Die zweite Bedingung zählt genauso. Ohne Ausweis kommt false heraus.",
    },
    "q-oop-1b": {
        "Für die Klasse selbst": "Die Klasse ist der Bauplan. this meint das konkrete Objekt, das gerade entsteht.",
        "Für den zuletzt gespeicherten Wert": "Mit Werten hat this nichts zu tun – es zeigt auf das Objekt.",
        "Für das Elternobjekt": "Auf die Eltern-Klasse greift super zu, nicht this.",
    },
    "q-inh-1b": {
        "Höchstens zwei": "Eine Obergrenze gibt es nicht. Nur bei Klassen ist bei einer Eltern-Klasse Schluss.",
        "Keines, wenn sie schon erbt": "Beides geht gleichzeitig: erst extends, dann implements.",
        "Genau eines": "Genau eine gilt für die Eltern-Klasse. Bei Verträgen gibt es diese Einschränkung nicht, weil sie keine Felder mitbringen.",
    },
    "q-exc-1b": {
        "Beide bedeuten dasselbe": "Der Unterschied ist grundlegend: throw löst aus, throws kündigt nur an.",
        "throws fängt den Alarm ab": "Gefangen wird im catch. throws reicht die Verantwortung weiter nach oben.",
        "throw kündigt an, throws löst aus": "Genau andersherum. Das s am Ende gehört zur Ankündigung im Methodenkopf.",
    },
    "q-gen-1a": {
        "Die Methode wird schneller": "Auf die Geschwindigkeit hat der Platzhalter keinen Einfluss.",
        "Die Methode darf nur Text verarbeiten": "Das wäre String statt T. Der Platzhalter lässt gerade alles zu.",
        "Die Methode kann keine Zahlen verarbeiten": "Zahlen gehen genauso – beim Aufruf wird T einfach zu Integer.",
    },
    "q-lam-2a": {
        "Es rechnet sofort z mal 2": "Gerechnet wird erst, wenn jemand das Lambda aufruft – etwa map für jedes Element.",
        "Es legt eine neue Variable z an": "z ist die Zutat, die bei jedem Aufruf hereinkommt – wie ein Parameter.",
        "Es sortiert die Liste": "Sortieren macht sorted. Ein Lambda beschreibt nur, was mit einem einzelnen Wert passiert.",
    },
    "q-mod-2a": {
        "Nichts – er ist nur eine Abkürzung":
            "Der Pfeil ist mehr als Schreiberleichterung: Das switch liefert einen Wert und darf rechts "
            "vom Gleichheitszeichen stehen.",
        "Immer nur eine Ausgabe auf dem Bildschirm":
            "Ausgeben kann man damit auch, aber der eigentliche Gewinn ist der zurückgegebene Wert.",
        "Eine Liste aller Fälle": "Zurück kommt genau ein Wert – der des passenden Zweigs.",
    },


    # ---------------------------------------------------------------- Übungspool, zweiter Teil
    "q-enum-1b": {
        "Seinen Namen als Text":
            "Den Namen liefert name() oder toString(). ordinal() gibt eine Zahl zurück.",
        "Die Anzahl aller Werte":
            "Die Anzahl bekommt man über values().length. ordinal() betrifft nur den einen Wert.",
        "Eine Zufallszahl":
            "Die Zahl steht fest: Sie ergibt sich aus der Reihenfolge im Quelltext.",
    },
    "q-obj-2a": {
        "Sonst ist equals immer false":
            "equals arbeitet weiterhin korrekt. Das Problem entsteht erst in Hash-Sammlungen.",
        "Sonst lässt sich das Objekt nicht ausgeben":
            "Ausgeben regelt toString. hashCode hat damit nichts zu tun.",
        "Sonst kann man das Objekt nicht erzeugen":
            "Erzeugen geht immer. Die Regel betrifft nur das Wiederfinden in HashSet und HashMap.",
    },
    "q-obj-2b": {
        "Sie darf nur eine Methode enthalten":
            "Sie darf beliebig viele haben – abstrakte wie fertige. Genau eine Methode wäre ein funktionales Interface.",
        "Sie kann nicht vererbt werden":
            "Vererbt werden muss sie sogar: Nur über eine Kind-Klasse kommt man an Objekte.",
        "Sie darf keine Felder haben":
            "Felder sind erlaubt und üblich – das unterscheidet sie von einem Interface.",
    },
    "q-rec-1b": {
        "Der Compiler meldet einen Fehler":
            "Syntaktisch ist der Code in Ordnung. Auffallen tut es erst beim Laufen.",
        "Java ergänzt den Basisfall automatisch":
            "Wann Schluss ist, kann nur der Mensch wissen. Java ergänzt nichts.",
        "Die Methode gibt 0 zurück":
            "Sie gibt gar nichts zurück – sie kommt nie bis zu einem return.",
    },
    "q-alg-1a": {
        "Sie schaut sich jeden Eintrag genauer an":
            "Im Gegenteil: Sie schaut sich viel weniger Einträge an, dafür gezielt den mittleren.",
        "Sie sortiert die Liste vorher":
            "Sortiert sein muss die Liste schon vorher – das Sortieren gehört nicht zur Suche.",
        "Sie braucht weniger Speicher":
            "Der Speicherbedarf ist bei beiden gleich. Der Gewinn liegt allein in der Zahl der Vergleiche.",
    },
    "q-ds-2a": {
        "Eine Warteschlange – wer zuerst kommt, ist zuerst dran":
            "Die würde die älteste Änderung zurücknehmen, nicht die letzte.",
        "Ein Set – jeder Eintrag nur einmal":
            "Ein Set kennt keine Reihenfolge – und dieselbe Änderung darf durchaus zweimal vorkommen.",
        "Eine Map – Schlüssel und Wert":
            "Eine Map ordnet Werte Schlüsseln zu. Eine Reihenfolge zum Zurücknehmen liefert sie nicht.",
    },
    "q-test-1b": {
        "Nur Fälle, die sicher funktionieren":
            "Solche Tests bestehen immer und finden nie etwas. Interessant sind gerade die wackligen Stellen.",
        "Die Geschwindigkeit des Programms":
            "Geschwindigkeit misst man getrennt. Ein Unit-Test prüft das Ergebnis.",
        "Nur besonders große Zahlen":
            "Große Zahlen sind ein Randfall von vielen. Die 0 und negative Werte werden häufiger vergessen.",
    },
    "q-test-2a": {
        "Den Code anpassen, bis der Test grün wird":
            "Das wäre gefährlich: Steht im Test ein falscher Erwartungswert, baut man den Fehler in den Code ein.",
        "Den Test löschen":
            "Dann verliert man die Prüfung ganz. Erst klären, wer recht hat.",
        "Die Prüfung ignorieren":
            "Ein dauerhaft roter Test wird bald von allen übersehen – auch dann, wenn er einen echten Fehler meldet.",
    },
    "q-tool-1a": {
        "Es erzeugt eine neue Liste":
            "Eine Liste entsteht mit new ArrayList<>(). import macht den Namen nur bekannt.",
        "Es lädt eine Datei von der Festplatte":
            "Geladen wird nichts – die Klasse liegt bereits in der Java-Bibliothek.",
        "Es startet das Programm":
            "Gestartet wird über main. import steht nur oben in der Datei.",
    },
    "q-tool-2b": {
        "Der Name des Programmierers":
            "Den kennt Java nicht. Oben steht die Art des Fehlers.",
        "Die letzte erfolgreiche Zeile":
            "Die Zeilen darunter zeigen den Weg dorthin – aber ganz oben steht der Fehler selbst.",
        "Die Uhrzeit des Absturzes":
            "Eine Uhrzeit gibt Java nicht aus. Das übernähme ein Protokoll-Werkzeug.",
    },
    "q-con-1a": {
        "Es wartet, bis der Thread fertig ist":
            "Das macht join(). start() kehrt sofort zurück.",
        "Es führt die Aufgabe sofort im Hauptprogramm aus":
            "Das wäre run(). Dann gäbe es keinen zweiten Arbeitsstrang.",
        "Es beendet den Thread":
            "Beendet wird er, wenn seine Arbeit fertig ist. start() setzt sie erst in Gang.",
    },
    "q-con-2a": {
        "int ist zu klein für große Zahlen":
            "Mit der Größe hat es nichts zu tun – auch bei kleinen Zahlen geht es schief.",
        "Threads dürfen keine Zahlen ändern":
            "Dürfen sie. Das Problem ist, dass sie es gleichzeitig tun.",
        "Der Zähler wird automatisch zurückgesetzt":
            "Zurückgesetzt wird nichts. Es gehen einzelne Erhöhungen verloren, weil beide denselben alten Wert gelesen haben.",
    },
    "q-con-3a": {
        "Sie rechnen schneller als normale Threads":
            "Beim reinen Rechnen sind sie nicht schneller. Der Vorteil zeigt sich beim Warten.",
        "Sie brauchen kein join()":
            "Auf ein Ergebnis muss man genauso warten – etwa mit get() oder join().",
        "Sie laufen ohne Executor":
            "Starten kann man sie auch einzeln, üblich ist aber ein Executor. Das ist nicht der Punkt.",
    },
    "q-pat-1a": {
        "Es legt die Reihenfolge im switch fest":
            "Die Reihenfolge bestimmt man selbst im switch. permits sagt nur, wer dazugehört.",
        "Es erlaubt jedem, das Interface umzusetzen":
            "Genau das Gegenteil: Es beschränkt den Kreis auf die genannten Typen.",
        "Es verbietet jede Vererbung":
            "Vererbt werden darf – nur eben ausschließlich von den aufgezählten Typen.",
    },
    "r-gen-1b": {
        "add funktioniert nur mit Objekten der Klasse Object":
            "add nimmt genau den Typ, der in den spitzen Klammern steht.",
        "Die Liste ist voll":
            "Eine Liste wird nie voll – sie wächst nach Bedarf.",
        "42 ist zu groß für eine Liste":
            "Die Größe spielt keine Rolle. Es geht allein um den Typ.",
    },
    "r-pat-1b": {
        "Es beendet den switch":
            "Beendet wird der switch, sobald ein Zweig passt. when prüft nur zusätzlich.",
        "Es legt die Reihenfolge der Fälle fest":
            "Die Reihenfolge bestimmt, wie man die Fälle hinschreibt.",
        "Es wiederholt den Fall":
            "Wiederholt wird nichts – jeder Zweig läuft höchstens einmal.",
    },
    "r-uml-1a": {
        "keine davon":
            "Doch, eine ist es: Schau noch einmal, vor welcher Zeile ein Minus steht.",
        "getName()":
            "Vor getName() steht ein Plus – die Methode ist öffentlich.",
        "addiere()":
            "Auch addiere() trägt ein Plus und ist damit von überall nutzbar.",
    },
    "r-uml-1b": {
        "3":
            "Gezählt werden nur die Zeilen im mittleren Fach. Methoden gehören nicht dazu.",
        "5":
            "Das wären alle Zeilen zusammen. Gefragt sind nur die Attribute im mittleren Fach.",
        "1":
            "Im mittleren Fach stehen zwei Zeilen, nicht eine.",
    },
    "r-uml-2a": {
        "- punkte: int":
            "Das Minus steht für private. Gesucht ist protected.",
        "+ punkte: int":
            "Das Plus steht für public. Gesucht ist protected.",
        "punkte: protected int":
            "Die Sichtbarkeit steht in UML als Zeichen ganz vorn, nicht als Wort beim Typ.",
    },
    "r-uml-2b": {
        "Eine Bibliothek hat genau ein Buch":
            "Genau eines wäre die Vielfachheit 1. Der Stern lässt beliebig viele zu.",
        "Jedes Buch gehört zu beliebig vielen Bibliotheken":
            "Die Angabe steht am Ende der Linie bei Buch und beschreibt, wie viele Bücher zur Bibliothek gehören.",
        "Es gibt keine Bücher":
            "Der Stern schließt null zwar ein, bedeutet aber „beliebig viele“ – nicht „keine“.",
    },
    "r-uml-3a": {
        "Abhängigkeit – gestrichelter Pfeil":
            "Abhängigkeit wäre nur kurzes Benutzen. Hier hält die Bibliothek die Bücher dauerhaft.",
        "Komposition – gefüllte Raute an der Bibliothek":
            "Bei Komposition würden die Bücher mit der Bibliothek verschwinden. Genau das ist hier nicht der Fall.",
        "Vererbung – Dreiecksspitze zur Bibliothek":
            "Vererbung hieße, ein Buch wäre eine Bibliothek. Es gehört ihr nur.",
    },
    "s-easy-1": {
        "Einfache Anführungszeichen '…'":
            "Die umschließen genau ein Zeichen (char). 'Hallo' lehnt der Compiler ab.",
        "Runde Klammern (…)":
            "Runde Klammern gehören zu Methodenaufrufen und Bedingungen, nicht zu Text.",
        "Gar nichts":
            "Ohne Anführungszeichen hielte Java das Wort für einen Variablennamen und meldet, dass es ihn nicht kennt.",
    },
    "s-easy-2": {
        "String":
            "String wäre Text. Mit „25“ in Anführungszeichen könnte man nicht rechnen.",
        "boolean":
            "boolean kennt nur true und false – eine Anzahl lässt sich damit nicht darstellen.",
        "double":
            "double ginge zwar, ist aber unnötig: Eine Anzahl hat nie Nachkommastellen, und double rechnet ungenauer.",
    },
    "s-easy-3": {
        "67":
            "Das wären die Ziffern aneinandergehängt – so verhält sich + bei Text, nicht * bei Zahlen.",
        "0":
            "0 käme heraus, wenn einer der Faktoren 0 wäre.",
        "13":
            "13 ist 6 + 7. Der Stern steht fürs Malnehmen.",
    },
    "s-easy-4": {
        "Ein beliebiger Text":
            "Ein Text ist keine Ja-Nein-Frage – Java kann damit nicht entscheiden.",
        "Der Name einer Methode":
            "Ein Name allein sagt nichts aus. Erst das Ergebnis eines Aufrufs kann true oder false sein.",
        "Eine Zahl zwischen 0 und 1":
            "Anders als in manchen Sprachen gilt in Java keine Zahl als wahr.",
    },
    "s-easy-5": {
        "Sie beendet das Programm":
            "Beendet wird das Programm am Ende von main oder mit System.exit.",
        "Sie erzeugt ein Objekt":
            "Objekte entstehen mit new.",
        "Sie speichert Werte":
            "Werte speichern Variablen. Die Schleife wiederholt nur.",
    },
    "s-easy-6": {
        "Die Methode wird neu gestartet":
            "Neu gestartet wird nichts – return beendet sie.",
        "Die Zeile wird übersprungen":
            "Übersprungen wird alles danach, weil die Methode an dieser Stelle endet.",
        "Das Programm endet":
            "Nur die Methode endet. Das Programm läuft an der aufrufenden Stelle weiter.",
    },
    "s-easy-7": {
        "-1":
            "Negative Indizes gibt es in Java nicht – der Zugriff löst sofort einen Fehler aus.",
        "Mit dem Namen des Arrays":
            "Über den Namen erreicht man das ganze Array. Ein einzelnes Fach wählt eine Zahl.",
        "1":
            "1 wäre menschlich gedacht. Java gibt aber den Abstand zum Anfang an – und der ist beim ersten Fach keiner.",
    },
    "s-easy-8": {
        "Eine Kopie des Programms":
            "Kopiert wird nichts. Es entsteht ein einzelnes Objekt im Arbeitsspeicher.",
        "Eine neue Klasse":
            "Die Klasse steht schon im Quelltext – sie ist der Bauplan. new nutzt ihn nur.",
        "Eine neue Methode":
            "Methoden schreibt man im Quelltext. new führt den Konstruktor aus.",
    },
    "s-easy-9": {
        "Sie hat einen Index":
            "Einen Index hat auch ein Array – das ist kein Unterschied.",
        "Sie lässt sich durchlaufen":
            "Durchlaufen kann man beide, etwa mit for-each.",
        "Sie speichert Zahlen":
            "Zahlen speichern beide. Der Unterschied ist die veränderliche Größe.",
    },
    "s-easy-10": {
        "Er beendet das Programm sicher":
            "Beendet wird nichts – im Gegenteil, das Programm soll weiterlaufen können.",
        "Er wiederholt Code so lange, bis er klappt":
            "Wiederholt wird nichts. Dafür bräuchte es eine Schleife um das try herum.",
        "Er beschleunigt das Programm":
            "Auf die Geschwindigkeit hat try keinen Einfluss.",
    },
    "u-gen-2": {
        "List zahlen = new ArrayList<int>();":
            "Gleich zwei Fehler: Links fehlt das Etikett, und int ist in spitzen Klammern nicht erlaubt.",
        "ArrayList<> zahlen = new List<Integer>();":
            "Die Seiten sind vertauscht: Links steht der allgemeine Typ, rechts die konkrete Umsetzung mit new.",
        "List<int> zahlen = new ArrayList<>();":
            "In spitzen Klammern steht nur eine Klasse. Für ganze Zahlen ist das Integer.",
    },
    "u-dat-1": {
        "Die Zeit seit 1970 in Millisekunden":
            "Das wäre ein Zeitstempel, etwa in Instant. LocalDate denkt in Kalendertagen.",
        "Datum und Uhrzeit":
            "Beides zusammen hält LocalDateTime.",
        "Nur die Uhrzeit":
            "Nur die Uhrzeit speichert LocalTime.",
    },
    "u-test-2": {
        "Leere Listen kommen am häufigsten vor":
            "Häufig sind sie nicht – aber sie brechen den Code besonders oft, weil niemand an sie denkt.",
        "Damit der Test länger wird":
            "Länge ist kein Wert an sich. Es geht um Fälle, die etwas Neues prüfen.",
        "Weil Java das verlangt":
            "Java verlangt gar keine Tests. Der Nutzen entsteht durch die gefundenen Fehler.",
    },
    "u-tool-1": {
        "Damit das Programm schneller lädt":
            "Auf die Ladezeit hat der Name keinen Einfluss.",
        "Damit man die Datei leichter findet":
            "Das ist ein Nebeneffekt der Ordnerstruktur, nicht der Grund für die Umkehrung.",
        "Weil Java das erzwingt":
            "Erzwungen wird es nicht – es ist eine Vereinbarung, die Namenskollisionen verhindert.",
    },
    "u-inh-2": {
        "Das Programm startet, stürzt aber ab":
            "So weit kommt es nicht: Der Fehler fällt schon beim Übersetzen auf.",
        "Die Methode wird automatisch ergänzt":
            "Java ergänzt nichts. Was der Vertrag verlangt, muss man selbst schreiben.",
        "Sie gibt beim Aufruf null zurück":
            "Es gibt nichts, was aufgerufen werden könnte – die Klasse lässt sich gar nicht erst übersetzen.",
    },
    "u-mod-3": {
        "Setter sind in Java abgeschafft":
            "In gewöhnlichen Klassen sind sie weiterhin üblich. Nur Records verzichten darauf.",
        "Records haben keine Felder":
            "Sie haben welche – genau die in den Klammern hinter dem Namen.",
        "Setter müsste man selbst schreiben, sie fehlen nur zufällig":
            "Sie fehlen mit Absicht: Ein Record ist nach dem Erzeugen unveränderlich.",
    },
    "u-enum-3": {
        "Wenn der Wert sich nie ändern darf":
            "Unveränderlich macht final, nicht static. Beides lässt sich kombinieren.",
        "Wenn das Feld privat sein soll":
            "Sichtbarkeit regelt private. static sagt nur, wem das Feld gehört.",
        "Wenn jedes Objekt einen eigenen Wert braucht":
            "Genau dann gerade nicht – dafür ist das gewöhnliche Feld da.",
    },
    "u-obj-2": {
        "Das hängt vom Typ ab":
            "Bei Objekten fragt == immer nach der Identität, unabhängig vom Typ.",
        "Immer true":
            "true käme nur heraus, wenn beide Namen auf dasselbe Objekt zeigen.",
        "Immer false":
            "Nicht immer: Zeigen beide auf dasselbe Objekt, liefert == true.",
    },
    "v-io-1": {
        "Weil sonst die Datei gelöscht wird":
            "Gelöscht wird nichts. Es geht darum, auf einen möglichen Fehler vorbereitet zu sein.",
        "Weil try-catch die Datei öffnet":
            "Geöffnet wird sie vom Code im try. Der Block selbst öffnet nichts.",
        "Weil Dateien immer langsam sind":
            "Mit Geschwindigkeit hat es nichts zu tun.",
    },
    "v-con-1": {
        "Für einen Thread, der noch nicht gestartet ist":
            "Ein Future ist kein Thread, sondern der Zettel für dessen Ergebnis.",
        "Für eine Aufgabe, die fehlgeschlagen ist":
            "Ein Fehler kann darin stecken, ist aber nicht der Normalfall.",
        "Für die Uhrzeit, zu der eine Aufgabe startet":
            "Mit Uhrzeiten hat ein Future nichts zu tun.",
    },
    "v-str-1": {
        "Eine sortierte Liste":
            "Sortieren macht sorted. groupingBy legt Fächer an.",
        "Eine einzelne Zahl":
            "Eine Zahl käme von count oder sum. Hier entsteht eine Map.",
        "Ein Eierkarton fester Größe":
            "Ein Array fester Größe wäre etwas anderes. Die Map wächst mit den gefundenen Schlüsseln.",
    },
    "v-grd-1": {
        "Weil int zu klein für Noten ist":
            "Noten passen mühelos in ein int. Das Problem ist die fehlende Nachkommastelle.",
        "Weil Java bei Noten immer double verlangt":
            "Java verlangt gar nichts – der Typ ergibt sich aus dem, was man darstellen will.",
        "Weil Noten negativ sein können":
            "Noten sind positiv. Der Grund ist der Durchschnitt, nicht das Vorzeichen.",
    },
    "v-todo-1": {
        "Er ist schneller als eine Klasse":
            "Geschwindigkeit ist nicht der Punkt – ein Record ist selbst eine Klasse.",
        "Er erlaubt das nachträgliche Ändern der Felder":
            "Genau umgekehrt: Ein Record ist unveränderlich.",
        "Er braucht keine Feldnamen":
            "Die Feldnamen stehen in den Klammern hinter dem Namen – ohne sie ginge es nicht.",
    },
    "v-adv-1": {
        "Ein enum braucht weniger Speicher":
            "Der Speicherbedarf ist nicht der Grund. Es geht um Sicherheit beim Übersetzen.",
        "Texte kann man nicht vergleichen":
            "Kann man – mit equals. Nur fällt ein Tippfehler dabei nicht auf.",
        "Ein enum lässt sich schneller ausgeben":
            "Ausgegeben wird beides gleich schnell.",
    },
    "v-uml-31-1": {
        "Zur Kind-Klasse":
            "Andersherum: Die Spitze zeigt vom Kind weg, hin zum Allgemeineren.",
        "Zum größeren Kasten":
            "Die Größe des Kastens sagt nichts aus – sie hängt nur von der Zahl der Zeilen ab.",
        "Zur Klasse mit den meisten Methoden":
            "Die Zahl der Methoden spielt keine Rolle. Entscheidend ist, wer von wem erbt.",
    },
    "v-uml-31-5": {
        "Komposition – gefüllte Raute":
            "Komposition hieße dauerhaftes Enthalten. Hier existiert das Objekt nur während der Methode.",
        "Aggregation – leere Raute":
            "Aggregation wäre ein dauerhaftes Feld, kein kurzlebiges Objekt.",
        "Vererbung – Dreiecksspitze":
            "Vererbung wäre „ist ein“. Hier wird nur kurz etwas benutzt.",
    },
    "v-uml-32-1": {
        "class Auto extends Fahrbar { }":
            "extends gehört zur durchgezogenen Linie. Gestrichelt heißt implements.",
        "class Fahrbar implements Auto { }":
            "Die Richtung stimmt nicht: Die Spitze zeigt auf das Interface, also setzt Auto es um.",
        "interface Auto extends Fahrbar { }":
            "Auto ist im Diagramm eine Klasse, kein Interface – erkennbar am fehlenden «interface».",
    },
    "v-uml-32-2": {
        "+ stand: double":
            "Das Plus steht für public. Gesucht ist private.",
        "# stand: double":
            "Das Doppelkreuz steht für protected. Gesucht ist private.",
        "- double: stand":
            "Name und Typ sind vertauscht. In UML steht erst der Name, dann hinter dem Doppelpunkt der Typ.",
    },
    "p-uml-1a": {
        "privat – nur in der eigenen Klasse":
            "Privat wäre ein Minus. Das Doppelkreuz erlaubt auch den Kind-Klassen den Zugriff.",
        "öffentlich – von überall":
            "Öffentlich wäre ein Plus. Das Doppelkreuz ist enger gefasst.",
        "Das Attribut ist eine Konstante":
            "Konstanten kennzeichnet UML durch Unterstreichung oder das Wort final – nicht durch #.",
    },
    "p-uml-1b": {
        "Im obersten Fach":
            "Oben steht der Name der Klasse.",
        "Im mittleren Fach":
            "In der Mitte stehen die Attribute.",
        "Neben dem Klassennamen":
            "Neben dem Namen steht höchstens ein Stereotyp wie «interface».",
    },
    "p-uml-2a": {
        "Aggregation: Die Räume leben ohne das Haus weiter":
            "Das wäre die leere Raute. Die gefüllte bindet die Teile ans Ganze.",
        "Vererbung: Raum erbt von Haus":
            "Vererbung hätte eine Dreiecksspitze – und ein Raum ist kein Haus.",
        "Assoziation ohne weitere Bedeutung":
            "Eine schlichte Assoziation hätte gar keine Raute.",
    },
    "p-uml-2b": {
        "*":
            "Der Stern heißt „beliebig viele“, also auch mehr als eine.",
        "1":
            "Die 1 allein heißt „genau eine“ – keine ist damit nicht erlaubt.",
        "1..*":
            "Das heißt „mindestens eine“. Gesucht war, dass auch keine erlaubt ist.",
    },
    "p-uml-3a": {
        "interface Auto extends Fahrbar { }":
            "Dann wäre Auto selbst ein Interface. Im Diagramm ist es eine Klasse.",
        "class Fahrbar implements Auto { }":
            "Die Richtung stimmt nicht: Die Spitze zeigt auf Fahrbar, also setzt Auto es um.",
        "class Auto extends Fahrbar { }":
            "extends gehört zur durchgezogenen Linie. Gestrichelt bedeutet implements.",
    },
}
