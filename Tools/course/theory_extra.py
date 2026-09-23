# Eine zusätzliche Theoriekarte je Lektion: der häufigste Irrtum.
#
# Gemessen war die Theorie knapp: 597 Zeichen je Lektion gegenüber 204 000 Zeichen
# Erklärungen und Tipps – auf ein Zeichen Theorie kamen elf Zeichen Übungstext. Die
# App lehrte fast ausschließlich über das Üben. Wer erst lesen und dann üben will,
# hatte pro Lektion rund neunzig Sekunden Text.
#
# Diese Karte schließt die Lücke an der Stelle, an der sie am meisten nützt: Sie nennt
# den Fehler, den in dieser Lektion fast jeder einmal macht – bevor er passiert. Die
# Inhalte decken sich mit den Begründungen der falschen Antworten; was dort nach dem
# Fehler erklärt wird, steht hier davor.
#
# Bewusst ohne Code-Beispiel: Jede Codezeile im Kurs braucht eine Zeilenerklärung,
# und dieser Text soll für sich stehen.
#
# Aufbau je Eintrag: (Titel, Text, Art des Hinweises, Hinweistext)

EXTRA_THEORY = {
    "l01-hello": (
        "Der häufigste Irrtum",
        "Java achtet strikt auf Groß- und Kleinschreibung: System ist etwas anderes als system, "
        "und println ist etwas anderes als Println. Das ist kein Schikane-Detail, sondern folgt "
        "daraus, dass Namen in Java eindeutig sein müssen – eine Klasse Auto und eine Variable "
        "auto dürfen nebeneinander stehen. Der zweite Klassiker: das vergessene Semikolon. Java "
        "liest weiter, bis es eines findet, und meldet den Fehler deshalb oft eine Zeile zu spät.",
        "warning", "Fehlermeldungen zeigen auf die Zeile, in der Java stolpert – die Ursache steht oft darüber.",
    ),
    "l02-variables": (
        "Der häufigste Irrtum",
        "„int ist doch auch eine Zahl, dann passt das schon.“ Tut es nicht: Java füllt kleinere "
        "Behälter klaglos in größere um, aber nie umgekehrt. Ein double in ein int zu legen würde "
        "Nachkommastellen verlieren, und Java verweigert das lieber, als still etwas abzuschneiden. "
        "Und final versiegelt nur die Box, nicht ihren Inhalt: Eine final-Liste kann weiterhin "
        "neue Einträge bekommen – nur eine andere Liste darf nicht mehr hinein.",
        "tip", "Frag beim Anlegen: Kann hier jemals etwas hinter dem Komma stehen? Dann double.",
    ),
    "l03-operators": (
        "Der häufigste Irrtum",
        "7 / 2 ergibt in Java 3, nicht 3,5. Sobald links und rechts ganze Zahlen stehen, rechnet "
        "Java ganzzahlig und wirft den Rest weg – ohne Warnung. Das ist die Fehlerquelle Nummer "
        "eins bei Durchschnitten und Prozentrechnungen. Es genügt, eine der beiden Seiten zur "
        "Kommazahl zu machen. Das Prozentzeichen % rechnet übrigens nicht in Prozent, sondern "
        "liefert genau den Rest, den die Division weggeworfen hat.",
        "warning", "Ein Durchschnitt aus int-Werten braucht immer eine Kommazahl im Nenner: / 3.0 statt / 3.",
    ),
    "l04-conditionals": (
        "Der häufigste Irrtum",
        "Ein einzelnes = weist zu, zwei == vergleichen. Bei Zahlen fällt der Verwechsler sofort "
        "auf, weil der Code nicht übersetzt. Tückischer ist == bei Texten: Es fragt, ob beide "
        "Namen auf dieselbe Kiste im Speicher zeigen, nicht ob derselbe Inhalt darin liegt. Zwei "
        "Texte mit gleichem Wortlaut können zwei verschiedene Objekte sein – dann kommt false "
        "heraus, obwohl beide „Hallo“ enthalten. Für den Inhalt gibt es equals.",
        "warning", "Faustregel: Zahlen und Wahrheitswerte mit ==, alles andere mit equals.",
    ),
    "l05-loops": (
        "Der häufigste Irrtum",
        "Der Zaunpfahl-Fehler: eine Runde zu viel oder zu wenig. Er entsteht fast immer am "
        "Vergleichszeichen. i < 10 läuft zehnmal und endet bei 9, i <= 10 läuft elfmal. Beim "
        "Array ist < zahlen.length richtig und <= falsch, weil das letzte Fach die Nummer "
        "length - 1 trägt. Zweite Falle: eine while-Schleife, in der sich die Bedingung nie "
        "ändert – dann läuft das Programm für immer.",
        "tip", "Schreib bei jeder neuen Schleife einmal auf, welchen ersten und welchen letzten Wert der Zähler annimmt.",
    ),
    "l06-methods": (
        "Der häufigste Irrtum",
        "„Die Methode hat den Wert doch geändert.“ Java übergibt eine Kopie: Eine Methode, die "
        "ihren int-Parameter überschreibt, ändert draußen nichts. Bei Objekten ist es feiner – "
        "kopiert wird der Verweis, nicht das Objekt. Die Methode kann den Inhalt eines "
        "übergebenen Objekts also sehr wohl verändern, nur nicht, auf welches Objekt der "
        "Aufrufer zeigt. Und: void heißt nicht „leer“, sondern „gibt nichts zurück“.",
        "info", "Was eine Methode dauerhaft weitergeben soll, gehört hinter return – nicht in einen Parameter.",
    ),
    "l07-arrays-strings": (
        "Der häufigste Irrtum",
        "Der Index ist kein Abzählen, sondern ein Abstand vom Anfang. Deshalb beginnt er bei 0 "
        "und das letzte Fach trägt die Nummer length - 1. Daraus folgt der häufigste Absturz "
        "überhaupt, die ArrayIndexOutOfBoundsException. Zweite Stolperstelle: Beim Array ist "
        "length eine Eigenschaft ohne Klammern, beim String ist length() ein Methodenaufruf mit "
        "Klammern, und bei einer Liste heißt dasselbe size().",
        "warning", "Ein Array hat nach dem Anlegen eine feste Größe. Wachsen kann nur eine Liste.",
    ),
    "l08-classes": (
        "Der häufigste Irrtum",
        "„Klasse und Objekt sind doch dasselbe.“ Die Klasse ist der Bauplan und existiert einmal; "
        "das Objekt entsteht bei jedem new neu und hat seinen eigenen Zustand. Zwei Zähler, aus "
        "derselben Klasse gebaut, zählen unabhängig voneinander. Und beim Konstruktor: Heißen "
        "Parameter und Feld gleich, gewinnt ohne this der Parameter – die Zuweisung name = name "
        "schreibt den Wert auf sich selbst und lässt das Feld leer.",
        "warning", "Ein Konstruktor trägt exakt den Namen der Klasse und hat keinen Rückgabetyp – auch kein void.",
    ),
    "l09-inheritance": (
        "Der häufigste Irrtum",
        "„Die Variable ist vom Typ Tier, also läuft auch die Methode aus Tier.“ Nein: Welche "
        "Fassung läuft, entscheidet das Objekt, das wirklich im Speicher liegt – nicht der Typ "
        "der Variablen. Genau das ist Polymorphie, und genau dafür ist Vererbung da. Zweiter "
        "Irrtum: extends und implements seien austauschbar. extends gilt zwischen Klassen und "
        "nur einmal, implements gilt für Interfaces und beliebig oft.",
        "tip", "Schreib @Override über jede überschriebene Methode. Vertippst du dich im Namen, meldet es der Compiler sofort.",
    ),
    "l10-exceptions": (
        "Der häufigste Irrtum",
        "catch (Exception e) fängt alles – auch das, was man gar nicht auffangen wollte, etwa "
        "einen Tippfehler im eigenen Code. Dann läuft das Programm scheinbar weiter, obwohl "
        "etwas kaputt ist. Fang so eng wie möglich. Zweiter Fehler: ein leerer catch-Block. Er "
        "verschluckt den Alarm, ohne darauf zu reagieren – der Fehler taucht später an einer "
        "Stelle auf, an der niemand mehr nach der Ursache sucht.",
        "warning", "finally läuft immer – auch nach einem return. Dort gehört das Aufräumen hin, nicht die Fehlerbehandlung.",
    ),
    "l11-collections": (
        "Der häufigste Irrtum",
        "List<int> gibt es nicht. In die spitzen Klammern dürfen nur Klassen, für ganze Zahlen "
        "also Integer. Java packt beim Rechnen automatisch aus und wieder ein, deshalb merkt man "
        "es selten – bis remove(1) bei einer Zahlenliste nicht den Wert 1 entfernt, sondern das "
        "Fach an Position 1. Und List.of(…) erzeugt eine unveränderliche Liste: add darauf löst "
        "einen Alarm aus.",
        "tip", "Soll die Liste wachsen, leg sie als new ArrayList<>(…) an – auch wenn du sie aus List.of füllst.",
    ),
    "l12-lambdas": (
        "Der häufigste Irrtum",
        "„Der Stream hat meine Liste sortiert.“ Hat er nicht: Ein Stream ändert die Ausgangsliste "
        "nie, er baut ein Ergebnis daneben. Wer das Ergebnis nicht auffängt, hat nichts getan. "
        "Zweiter Punkt: Ein Stream läuft erst los, wenn am Ende etwas gefordert wird – ohne "
        "collect, forEach oder sum passiert gar nichts. Und ein Stream ist einmalig; ihn zweimal "
        "zu benutzen löst einen Alarm aus.",
        "info", "Die Reihenfolge der Stationen zählt: erst filtern und dann umwandeln ist etwas anderes als umgekehrt.",
    ),
    "l13-modern": (
        "Der häufigste Irrtum",
        "Ein Optional löst das null-Problem nicht dadurch, dass man get() aufruft – das wirft "
        "genauso einen Alarm, wenn nichts drin ist. Der Sinn liegt darin, dass der Typ dich "
        "zwingt, den leeren Fall zu behandeln: mit orElse, map oder ifPresent. Und ein Record "
        "hat absichtlich keine Setter: Seine Werte stehen nach dem Erzeugen fest. Wer etwas "
        "ändern will, baut ein neues.",
        "tip", "switch als Ausdruck liefert einen Wert und endet deshalb mit einem Semikolon – anders als ein switch-Block.",
    ),
    "l14-enums-static": (
        "Der häufigste Irrtum",
        "static wird gern mit „unveränderlich“ verwechselt. Dafür ist final da. static heißt: "
        "gehört der Klasse, nicht dem einzelnen Objekt – alle teilen sich denselben Wert. Ein "
        "static-Zähler zählt deshalb über alle Objekte hinweg. Beim enum ist ordinal() die "
        "Position in der Aufzählung, gezählt ab null; wer sich darauf verlässt, bekommt beim "
        "Umsortieren der Werte stillschweigend andere Zahlen.",
        "warning", "Aus einer statischen Methode ist this nicht erreichbar – dort gibt es kein Objekt.",
    ),
    "l15-object-methods": (
        "Der häufigste Irrtum",
        "equals ohne hashCode ist die klassische stille Falle. HashSet und HashMap suchen zuerst "
        "über die Zahl aus hashCode das richtige Fach und vergleichen erst darin mit equals. "
        "Liefern zwei inhaltlich gleiche Objekte verschiedene Zahlen, landen sie in verschiedenen "
        "Fächern und finden sich nie. Der Fehler zeigt sich erst dort, wo man ihn nicht sucht – "
        "beim Nachschlagen in einer Map.",
        "tip", "Ein Record bringt equals, hashCode und toString fertig mit. Wo er passt, ist er die sicherere Wahl.",
    ),
    "l16-text-input": (
        "Der häufigste Irrtum",
        "Ein String lässt sich nach dem Erzeugen nicht mehr ändern. text += "
        "\"etwas\" in einer Schleife baut deshalb bei jedem Durchlauf einen ganz neuen Text – "
        "bei tausend Runden tausend Objekte. Genau dafür gibt es den StringBuilder, der auf "
        "demselben Notizblock weiterschreibt. Beim Scanner ist die häufigste Stolperstelle, dass "
        "nextInt() den Zeilenumbruch stehen lässt, über den das nächste nextLine() dann fällt.",
        "info", "Für wenige Textstücke ist das Pluszeichen völlig in Ordnung – der StringBuilder lohnt sich in Schleifen.",
    ),
    "l17-files-time": (
        "Der häufigste Irrtum",
        "Dateizugriffe sind in Java „checked“: Der Compiler verlangt, dass du auf einen möglichen "
        "Fehler reagierst, weil eine Datei fehlen oder ein Laufwerk voll sein kann – daran ist "
        "kein Programm schuld. Beim Datum ist die Falle eine andere: LocalDate ist "
        "unveränderlich. plusDays(7) ändert das Datum nicht, sondern liefert ein neues. Wer das "
        "Ergebnis nicht auffängt, hat nichts erreicht.",
        "warning", "Date und Calendar sind die alten Klassen. Neuer Code nimmt java.time.",
    ),
    "l18-recursion": (
        "Der häufigste Irrtum",
        "Ohne Abbruchbedingung ruft sich die Methode endlos selbst auf, bis der Aufruf-Stapel "
        "voll ist – ein StackOverflowError. Der Compiler warnt nicht davor, er sieht nur einen "
        "gewöhnlichen Methodenaufruf. Zweite Stolperstelle: Der rekursive Aufruf muss dem "
        "Abbruch näher kommen. fakultaet(n) aufzurufen statt fakultaet(n - 1) sieht fast gleich "
        "aus und läuft trotzdem für immer.",
        "tip", "Schreib zuerst den Abbruch, dann den Aufruf. In dieser Reihenfolge vergisst man ihn nicht.",
    ),
    "l19-search-sort": (
        "Der häufigste Irrtum",
        "Die binäre Suche setzt voraus, dass die Daten sortiert sind – sonst liefert sie ein "
        "falsches Ergebnis, ohne sich zu beschweren. Das ist gefährlicher als ein Absturz. "
        "Zweiter Punkt: Arrays.sort verändert das Array selbst und gibt nichts zurück, während "
        "ein Stream mit sorted() die Vorlage unangetastet lässt. Wer beides verwechselt, sucht "
        "lange nach der Stelle, an der die Reihenfolge verlorengeht.",
        "info", "Texte sortiert Java alphabetisch nach Zeichencode – Großbuchstaben kommen dabei vor den kleinen.",
    ),
    "l20-sets-queues": (
        "Der häufigste Irrtum",
        "„Ein Set ist sortiert.“ Nur das TreeSet ist es. Ein HashSet hat überhaupt keine "
        "verlässliche Reihenfolge – sie kann sich zwischen zwei Programmläufen ändern. Wer sich "
        "darauf verlässt, baut einen Fehler ein, der nur manchmal auftritt. Und damit ein Set "
        "Doppelte erkennt, müssen die Objekte equals und hashCode mitbringen; sonst gilt jedes "
        "Objekt als neu, auch bei gleichem Inhalt.",
        "tip", "Stapel: zuletzt drauf, zuerst weg. Warteschlange: wer zuerst kommt, ist zuerst dran.",
    ),
    "l21-testing": (
        "Der häufigste Irrtum",
        "Einen roten Test so lange umzubauen, bis er grün wird, verschiebt das Problem nur. Auch "
        "Tests sind Code und können eine falsche Erwartung enthalten – erst prüfen, welche der "
        "beiden Seiten irrt. Zweiter Punkt: Tests, die nur den bequemen Fall abdecken, finden "
        "wenig. Die Fehler sitzen am Rand: die leere Liste, die Null, die negative Zahl, der "
        "Wert genau auf der Grenze.",
        "info", "Bei assertEquals steht der erwartete Wert vorn. Vertauscht liest sich die Fehlermeldung genau falsch herum.",
    ),
    "l22-tools-debugging": (
        "Der häufigste Irrtum",
        "Einen Stacktrace liest man von oben: Ganz oben steht, was passiert ist, darunter der Weg "
        "dorthin. Die erste Zeile mit dem eigenen Klassennamen ist fast immer die interessante. "
        "Zweiter Punkt: Ein Paketname sieht aus wie eine umgedrehte Internetadresse, damit er "
        "weltweit eindeutig bleibt – zwei Bibliotheken dürfen dieselbe Klasse „Liste“ enthalten, "
        "solange die Pakete verschieden sind.",
        "tip", "Vor dem Suchen messen: eine Ausgabe an der Stelle, an der man den Fehler vermutet, spart oft eine Stunde.",
    ),
    "l23-threads": (
        "Der häufigste Irrtum",
        "start() und run() sehen austauschbar aus und sind es nicht: run() führt die Aufgabe "
        "einfach im Hauptprogramm aus, nur start() lässt sie wirklich nebenher laufen. Zweite "
        "Falle: Das Erhöhen eines gewöhnlichen Zählers besteht aus drei Schritten – lesen, "
        "rechnen, schreiben. Geraten zwei Threads mittendrin ineinander, geht ein Schritt "
        "verloren, und der Zähler steht am Ende zu niedrig.",
        "warning", "Ohne join() steht die Reihenfolge der Ausgaben nicht fest – sie kann bei jedem Start anders sein.",
    ),
    "l24-executors": (
        "Der häufigste Irrtum",
        "Erst eine Aufgabe einreichen, sofort ihr Ergebnis abholen, dann die nächste einreichen – "
        "damit laufen sie nacheinander, und der ganze Vorteil ist weg. get() wartet. Also erst "
        "alle einreichen, danach einsammeln. Zweiter Punkt: Virtuelle Threads rechnen nicht "
        "schneller. Ihr Vorteil liegt darin, wie wenig Platz jeder belegt – Tausende können "
        "gleichzeitig auf eine Antwort warten.",
        "info", "Ein Executor in try-with-resources wird am Ende sauber geschlossen und wartet dabei auf seine Aufgaben.",
    ),
    "l25-sealed-patterns": (
        "Der häufigste Irrtum",
        "„sealed heißt, dass niemand es umsetzen darf.“ Nein – nur die in permits aufgezählten "
        "Typen dürfen es. Genau darin liegt der Gewinn: Weil die Liste feststeht, kann der "
        "Compiler prüfen, ob dein switch alle Fälle abdeckt, und du brauchst keinen "
        "default-Zweig. Setzt du später einen Typ dazu, meldet er jede Stelle, die du vergessen "
        "hast. Ein default würde genau diese Warnung verschlucken.",
        "tip", "Der engere case mit when gehört nach oben – Java prüft von oben nach unten und nimmt den ersten Treffer.",
    ),
    "l26-streams-pro": (
        "Der häufigste Irrtum",
        "groupingBy liefert eine HashMap, und die hat keine verlässliche Reihenfolge. Wer die "
        "Gruppen sortiert braucht, muss eine TreeMap anfordern. Zweiter Punkt: reduce braucht "
        "einen Startwert, der nichts verändert – beim Addieren die Null, beim Multiplizieren die "
        "Eins. Wer beim Produkt mit 0 startet, bekommt immer 0 heraus, ohne dass irgendetwas "
        "einen Fehler meldet.",
        "info", "flatMap ist map für den Fall, dass jedes Element selbst wieder eine Sammlung ist.",
    ),
    "l27-project-grades": (
        "Der häufigste Irrtum",
        "Der Durchschnitt aus ganzen Noten ist fast nie eine ganze Zahl. Wer summe / anzahl mit "
        "zwei int-Werten rechnet, bekommt 2 statt 2,33 – und merkt es nicht, weil kein Fehler "
        "auftritt. Zweiter Punkt: Die beste Note ist die kleinste Zahl. Wer mit 0 als Startwert "
        "sucht, findet nie etwas Kleineres. Starte stattdessen mit dem ersten tatsächlichen "
        "Wert aus den Daten.",
        "warning", "„Bestanden bis 4“ heißt kleiner oder gleich 4 – die 4 selbst gehört dazu.",
    ),
    "l28-project-todo": (
        "Der häufigste Irrtum",
        "Ein Record lässt sich nicht abhaken: Seine Werte stehen nach dem Erzeugen fest. Eine "
        "Aufgabe als erledigt zu markieren heißt deshalb, sie durch eine neue zu ersetzen – mit "
        "set an derselben Position, nicht mit add. Zweiter Punkt: Wer beim Durchlaufen einer "
        "Liste gleichzeitig Einträge entfernt, bringt die Positionen durcheinander. Dafür gibt "
        "es removeIf.",
        "tip", "List.of(…) ist unveränderlich. Für eine Liste, die sich ändern soll, brauchst du new ArrayList<>(…).",
    ),
    "l29-project-adventure": (
        "Der häufigste Irrtum",
        "Eine unbekannte Richtung darf nicht zum Absturz führen. get() auf eine Map liefert null, "
        "wenn der Schlüssel fehlt – und der nächste Zugriff darauf löst einen Alarm aus. "
        "getOrDefault mit dem aktuellen Raum als Ersatz lässt den Spieler stattdessen einfach "
        "stehen. Zweiter Punkt: Räume als enum statt als Text bedeuten, dass ein Tippfehler "
        "schon beim Übersetzen auffällt und nicht erst mitten im Spiel.",
        "info", "Die Karte ist zweistufig: erst den Raum nachschlagen, dann darin die Richtung.",
    ),
    "l30-uml-basics": (
        "Der häufigste Irrtum",
        "In UML steht der Name vorn und der Typ hinter dem Doppelpunkt, in Java ist es genau "
        "umgekehrt. Aus „- stand: double“ wird deshalb „private double stand;“. Zweiter Punkt: "
        "Die drei Zeichen davor sind keine Verzierung. Das Minus bedeutet privat, das Plus "
        "öffentlich, das Doppelkreuz geschützt – also auch für erbende Klassen sichtbar. Fehlt "
        "hinter einer Methode der Doppelpunkt, gibt sie nichts zurück.",
        "tip", "Der Kasten hat drei Fächer in fester Reihenfolge: Name, Attribute, Methoden.",
    ),
    "l31-uml-relations": (
        "Der häufigste Irrtum",
        "Die beiden Rauten werden ständig verwechselt. Die gefüllte bedeutet: Es geht gemeinsam "
        "unter – die Räume verschwinden mit dem Haus. Die leere bedeutet: Es lebt weiter – die "
        "Bücher bleiben, wenn die Bibliothek schließt. Zweiter Punkt: Die Dreiecksspitze zeigt "
        "immer zum Allgemeineren, nie zum Kind. Lies den Pfeil als „ist ein“, dann stimmt die "
        "Richtung von selbst.",
        "info", "Steht kein Feld dieses Typs in der Klasse, ist es eine Abhängigkeit – der gestrichelte Pfeil.",
    ),
    "l32-uml-java": (
        "Der häufigste Irrtum",
        "Ein Diagramm bildet nicht jede Zeile Code ab, und das ist Absicht: Es zeigt die "
        "Struktur, nicht die Umsetzung. Konstruktoren und triviale Getter lässt man oft weg. "
        "Umgekehrt gilt aber: Was im Diagramm steht, muss im Code vorkommen. Zweiter Punkt: "
        "extends und implements sehen im Diagramm fast gleich aus – durchgezogene Linie für "
        "Klassen, gestrichelte für Interfaces. Nur die Spitze ist bei beiden dieselbe.",
        "tip", "Beim Übersetzen in beide Richtungen zuerst die Kästen, dann die Linien – Struktur vor Beziehung.",
    ),
}
