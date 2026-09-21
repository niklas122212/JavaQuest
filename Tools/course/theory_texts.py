"""Theorietexte in Alltagssprache – mit durchgängigen Bildern statt Fachjargon.

Schlüssel: (Lektions-ID, Kartenindex) -> (Titel, Text, Hinweis-Art, Hinweis-Text)
Die Codebeispiele der Karten bleiben unverändert (sie sind mit dem JDK geprüft).
"""

THEORY = {
    # --- Hallo, Java!
    ("l01-hello", 0): ("Dein erstes Programm",
        "Ein Java-Programm ist wie ein Kochbuch mit genau einer Startseite: der Methode main. Dort fängt Java an zu lesen – Zeile für Zeile, von oben nach unten. Drumherum steht immer eine Klasse (class). Stell sie dir vorerst als Umschlag vor, der alles zusammenhält.",
        "tip", "Die Datei muss so heißen wie die Klasse: Hallo.java."),
    ("l01-hello", 1): ("Etwas auf den Bildschirm schreiben",
        "Mit System.out.println(…) schreibt dein Programm etwas auf den Bildschirm und drückt danach sozusagen die Enter-Taste. System.out.print(…) schreibt ohne Enter – die nächste Ausgabe kommt direkt dahinter. Text steht in Anführungszeichen. Zahlen nicht – die rechnet Java sogar aus.",
        None, None),
    ("l01-hello", 2): ("Semikolon & Notizzettel",
        "Jede Anweisung endet mit einem Semikolon ; – das ist für Java der Punkt am Satzende. Mit // schreibst du Notizzettel (Kommentare) für Menschen. Java überliest sie einfach.",
        "warning", "Java achtet auf Groß- und Kleinschreibung: System ist nicht dasselbe wie system."),

    # --- Variablen
    ("l02-variables", 0): ("Variablen sind Boxen",
        "Eine Variable ist wie eine beschriftete Box: Sie hat einen Namen (z. B. alter) und einen Inhalt (z. B. 25). Das Etikett davor – der Typ – sagt, was hineinpasst: int für ganze Zahlen, double für Kommazahlen, boolean für ja/nein, char für ein einzelnes Zeichen und String für Text.",
        "tip", "String schreibt man groß – es ist eine eigene Klasse und kein einfacher Grundtyp."),
    ("l02-variables", 1): ("Inhalt tauschen & Box versiegeln",
        "Mit = legst du einen neuen Inhalt in die Box – der alte fliegt raus. Mit final versiegelst du die Box: Der Inhalt bleibt für immer gleich. Und mit var klebt Java das passende Etikett selbst drauf.",
        "warning", "int-Boxen haben eine Grenze (etwa 2,1 Milliarden). Für größere Zahlen gibt es long."),

    # --- Operatoren
    ("l03-operators", 0): ("Rechnen wie mit dem Taschenrechner",
        "+ - * und / funktionieren wie gewohnt. Neu ist %: Es liefert den Rest beim Teilen – 7 % 2 ist 1. Vorsicht: Teilst du zwei ganze Zahlen, schneidet Java die Nachkommastellen einfach ab. 7 / 2 ergibt 3. Mit einer Kommazahl (7.0 / 2) kommt 3.5 heraus.",
        None, None),
    ("l03-operators", 1): ("Praktische Abkürzungen",
        "x += 5 heißt: „Leg 5 zum Inhalt der Box x dazu.“ x *= 2 verdoppelt den Inhalt. x++ zählt um eins hoch – wie ein Klick auf einen Handzähler. x-- zählt herunter.",
        None, None),
    ("l03-operators", 2): ("Fragen stellen mit Vergleichen",
        "Ein Vergleich ist eine Frage mit der Antwort ja (true) oder nein (false): alter >= 18 fragt „Ist alter mindestens 18?“. Mit && (und) und || (oder) verbindest du mehrere Fragen. && wird zuerst ausgewertet – wie Punkt vor Strich.",
        "warning", "= füllt eine Box, == vergleicht zwei Werte. Das ist der häufigste Anfängerfehler."),

    # --- Bedingungen
    ("l04-conditionals", 0): ("if: Das Programm entscheidet",
        "Mit if stellt dein Programm eine Frage – wie an einer Weggabelung. Ist die Antwort ja, geht es in den Block zwischen den geschweiften Klammern { }. Mit else legst du fest, was sonst passiert.",
        None, None),
    ("l04-conditionals", 1): ("else if: mehrere Fragen nacheinander",
        "Mit else if stellst du die nächste Frage, falls die vorige mit nein beantwortet wurde. Java geht von oben nach unten und nimmt den ersten Weg, der passt. Danach wird nichts mehr geprüft – die Reihenfolge zählt also.",
        None, None),
    ("l04-conditionals", 2): ("switch: der Weichensteller",
        "Geht es um einen einzigen Wert mit vielen möglichen Fällen, ist switch übersichtlicher: Je nach Wert fährt das Programm in einen anderen Fall (case). default ist der Weg für alles Übrige. Mehrere Werte kannst du mit Komma zusammenfassen.",
        "tip", "Mit dem Pfeil -> brauchst du kein break (gibt es seit Java 14)."),

    # --- Schleifen
    ("l05-loops", 0): ("for: Runden zählen",
        "Eine for-Schleife wiederholt Code eine bestimmte Anzahl von Runden. In den Klammern stehen drei Dinge: Wo startet der Zähler? Solange welche Frage mit ja beantwortet wird, geht es weiter? Was passiert nach jeder Runde?",
        None, None),
    ("l05-loops", 1): ("while: solange etwas gilt",
        "while wiederholt, solange eine Frage mit ja beantwortet wird – wie „Solange noch Kekse da sind: iss einen“. do-while macht erst eine Runde und fragt danach, läuft also mindestens einmal.",
        None, None),
    ("l05-loops", 2): ("break & continue",
        "break heißt: sofort raus aus der Schleife. continue heißt: diese Runde abbrechen und direkt mit der nächsten weitermachen.",
        "warning", "Wird die Frage nie mit nein beantwortet, läuft die Schleife endlos – das Programm hängt."),

    # --- Methoden
    ("l06-methods", 0): ("Methoden sind Rezepte",
        "Eine Methode ist wie ein Rezept mit Namen: Du gibst ihr Zutaten (Parameter), sie arbeitet damit und liefert mit return ein Ergebnis zurück. Einmal geschrieben, kannst du sie so oft benutzen, wie du willst.",
        None, None),
    ("l06-methods", 1): ("Rezepte ohne Ergebnis: void",
        "Manche Rezepte liefern nichts zurück, sie erledigen nur eine Aufgabe – zum Beispiel etwas auf den Bildschirm schreiben. Das kennzeichnet void (= leer). Mehrere Zutaten trennst du mit Komma, jede bekommt ihr eigenes Etikett.",
        None, None),
    ("l06-methods", 2): ("Gleicher Name, andere Zutaten",
        "Mehrere Methoden dürfen gleich heißen, wenn sie unterschiedliche Zutaten erwarten. Java wählt automatisch die passende aus. Das nennt man Überladen.",
        "tip", "static-Methoden gehören zur Klasse selbst – du kannst sie direkt aus main aufrufen."),

    # --- Arrays & Strings
    ("l07-arrays-strings", 0): ("Arrays: der Eierkarton",
        "Ein Array ist wie ein Eierkarton: eine feste Anzahl nummerierter Fächer für Werte derselben Sorte. Die Nummerierung beginnt bei 0! Mit .length erfährst du, wie viele Fächer es gibt.",
        "warning", "Das letzte Fach hat die Nummer length - 1. Ein Fach dahinter gibt es nicht – das löst einen Alarm aus."),
    ("l07-arrays-strings", 1): ("Alle Fächer durchgehen",
        "Die for-each-Schleife geht jedes Fach der Reihe nach durch. Du musst dich nicht um die Nummern kümmern – in jeder Runde liegt der aktuelle Wert in einer Box.",
        None, None),
    ("l07-arrays-strings", 2): ("Strings: Texte mit Werkzeugen",
        "Ein String bringt viele Werkzeuge mit: length() zählt die Zeichen, charAt(i) holt ein Zeichen, toUpperCase() macht Großbuchstaben, substring schneidet ein Stück heraus.",
        "warning", "Texte vergleichst du mit equals, nicht mit == – == fragt nur, ob es genau dasselbe Objekt ist."),

    # --- Klassen & Objekte
    ("l08-classes", 0): ("Klassen sind Kuchenformen",
        "Eine Klasse ist wie eine Kuchenform: Sie legt fest, welche Eigenschaften (Felder) und Fähigkeiten (Methoden) etwas hat. Mit new backst du daraus echte Objekte – die Kuchen. Jeder Kuchen hat seine eigenen Werte.",
        None, None),
    ("l08-classes", 1): ("Konstruktor: die Backanleitung",
        "Der Konstruktor läuft automatisch beim Backen mit new. Er heißt wie die Klasse und gibt dem neuen Objekt seine Startwerte. this bedeutet „dieser Kuchen hier“ – so unterscheidest du das Fach des Objekts von der mitgegebenen Zutat mit gleichem Namen.",
        None, None),
    ("l08-classes", 2): ("Kapselung: abgeschlossene Fächer",
        "Felder macht man meist private – wie abgeschlossene Fächer. Von außen kommt man nur über Methoden wie getName() heran. So bestimmt die Klasse selbst, welche Werte erlaubt sind.",
        "tip", "Faustregel: Felder private, Methoden nur so öffentlich wie nötig."),

    # --- Vererbung & Interfaces
    ("l09-inheritance", 0): ("Vererbung: erweiterte Kuchenformen",
        "Mit extends baust du eine erweiterte Kuchenform: Die Kind-Klasse übernimmt alles von der Eltern-Klasse und darf einzelne Methoden ersetzen (überschreiben). @Override ist ein Hinweiszettel, den Java prüft.",
        None, None),
    ("l09-inheritance", 1): ("Polymorphie: Jeder antwortet auf seine Art",
        "Eine Box mit dem Etikett Tier kann eine Katze enthalten – jede Katze ist ja auch ein Tier. Fragst du nach dem Laut, antwortet trotzdem die Katze. Mit super greifst du auf die Eltern-Klasse zu.",
        None, None),
    ("l09-inheritance", 2): ("Interfaces: Verträge",
        "Ein Interface ist ein Vertrag: Es sagt nur, WAS eine Klasse können muss – nicht wie. Eine Klasse unterschreibt mit implements und muss dann alle verlangten Methoden liefern. Sie darf viele Verträge haben, aber nur eine Eltern-Klasse.",
        "tip", "Abstrakte Klassen (abstract class) liegen dazwischen: unfertige Kuchenformen, aus denen man selbst keine Kuchen backen kann."),

    # --- Exceptions
    ("l10-exceptions", 0): ("Alarm im Programm",
        "Wenn etwas schiefgeht – zum Beispiel eine Division durch 0 –, löst Java einen Alarm aus: eine Exception. Ohne Vorkehrung stürzt das Programm ab. Mit try und catch spannst du ein Sicherheitsnetz darunter.",
        None, None),
    ("l10-exceptions", 1): ("Mehrere Netze & Aufräumen",
        "Für verschiedene Alarme kannst du mehrere catch-Netze aufspannen. Der finally-Block läuft zum Schluss immer – wie das Aufräumen nach dem Kochen, egal ob etwas angebrannt ist oder nicht.",
        None, None),
    ("l10-exceptions", 2): ("Selbst Alarm schlagen",
        "Mit throw löst du selbst einen Alarm aus – zum Beispiel, wenn jemand ein negatives Alter eingibt. Manche Alarme zwingt Java dich vorher anzukündigen: Eine checked Exception (z. B. IOException) musst du mit try/catch auffangen oder in der Methode mit throws ankündigen, sonst meckert schon der Compiler. Alarme, die von RuntimeException abstammen (unchecked, z. B. NullPointerException oder ArithmeticException), verlangt Java das nicht – auffangen darfst du sie trotzdem.",
        "warning", "Ein leeres catch verschluckt Fehler still und leise. Reagiere immer sinnvoll."),

    # --- Collections & Generics
    ("l11-collections", 0): ("ArrayList: der Einkaufszettel",
        "Anders als der Eierkarton (Array) wächst eine Liste mit: add schreibt einen Eintrag dazu, get holt einen, remove streicht einen und size zählt, wie viele es sind.",
        None, None),
    ("l11-collections", 1): ("HashMap: das Wörterbuch",
        "Eine Map ist wie ein Wörterbuch: Zu jedem Schlüssel (z. B. einem Namen) gehört ein Wert (z. B. ein Alter). put trägt ein, get schlägt nach, getOrDefault liefert einen Ersatzwert, wenn der Schlüssel fehlt.",
        None, None),
    ("l11-collections", 2): ("Generics: Etiketten für Sammlungen",
        "Die spitzen Klammern sagen, was in die Sammlung darf: List<String> ist eine Liste nur für Texte. Für Zahlen nimmst du Integer statt int. Mit <T> schreibst du Methoden, die für jede Sorte funktionieren – T ist ein Platzhalter-Etikett.",
        "info", "Java verwandelt int und Integer automatisch ineinander."),

    # --- Lambdas & Streams
    ("l12-lambdas", 0): ("Lambdas: Mini-Anweisungen",
        "Ein Lambda ist eine kleine Anweisung ohne Namen: links die Eingabe, dann der Pfeil ->, rechts das Ergebnis. (a, b) -> a + b heißt: „Nimm a und b und rechne a + b.“ String::length verweist direkt auf eine fertige Methode.",
        None, None),
    ("l12-lambdas", 1): ("Streams: das Fließband",
        "Ein Stream ist wie ein Fließband: Die Elemente laufen nacheinander durch Stationen. filter ist ein Sieb, map ein Umformer – und am Ende sammelt zum Beispiel toList() alles in einer neuen Liste.",
        None, None),
    ("l12-lambdas", 2): ("Das Ende des Bandes",
        "Erst eine End-Station setzt das Band in Bewegung: toList() sammelt ein, count() zählt, sum() addiert (nach mapToInt) und Collectors.joining klebt Texte zusammen.",
        "tip", "Ohne End-Station passiert gar nichts – das Band steht still."),

    # --- Modernes Java
    ("l13-modern", 0): ("Records: fertige Formulare",
        "Ein record ist wie ein Formular mit festen Feldern: Du schreibst nur die Felder hin, Java erledigt den Rest – Konstruktor, Lesemethoden, Vergleich (equals) und Textdarstellung (toString).",
        None, None),
    ("l13-modern", 1): ("Optional: die Schachtel",
        "Ein Optional ist eine Schachtel, die etwas enthält – oder leer ist. Statt blind hineinzugreifen, fragst du mit orElse: „Gib mir den Inhalt – oder diesen Ersatz.“ So gibt es keinen Alarm wegen leerer Boxen.",
        None, None),
    ("l13-modern", 2): ("switch liefert Werte & Sorten-Prüfung",
        "Ein switch kann direkt einen Wert liefern, den du in eine Box legst. Mit instanceof prüfst du die Sorte eines Objekts und gibst ihm gleich ein passendes Namensschild – das nennt man Pattern Matching: Java erkennt das Muster (die Sorte) und packt den Wert in einem Schritt aus.",
        "info", "Records gibt es seit Java 16, switch mit Sorten-Prüfung seit Java 21."),
}

# Aufgaben-Erklärungen ohne Fachjargon (nur dort, wo nötig).
TASK_EXPLANATIONS = {
    "t06-4": "Java wählt die Variante, deren Zutaten zu den übergebenen Werten passen: ein Text und eine Zahl.",
    "t11-2": "In die spitzen Klammern dürfen nur Klassen – deshalb nimmt man Integer, die Objekt-Variante von int.",
    "t11-5": "<T> ist ein Platzhalter-Etikett: Die Methode funktioniert so für Listen mit beliebigem Inhalt.",
    "t12-5": "Das Fließband: filter siebt die ungeraden Zahlen heraus, mapToInt quadriert sie, sum zählt zusammen – 1 + 9 + 25 = 35.",
    "t13-5": "Mit instanceof String s prüfst du die Sorte und gibst dem Wert gleich das Namensschild s – ganz ohne Umwandeln. Ein switch mit case String s ginge genauso.",
}
