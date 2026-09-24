import Foundation

/// Ein Begriff aus dem Befehlslexikon – ein Schlüsselwort, Typ, Befehl oder Operator.
public struct GlossaryEntry: Sendable, Hashable, Identifiable {
    public let term: String
    public let meaning: String
    public var id: String { term }
}

/// Befehlslexikon: kurze Erklärungen in Alltagssprache für jedes Java-Schlüsselwort,
/// jeden Typ, jede Methode und jeden Operator, der im Kurs vorkommt. Ein Test stellt
/// sicher, dass kein Befehl aus den Kursinhalten fehlt.
public enum JavaGlossary {
    /// Schlüsselwörter und Typen (als ganzes Wort erkannt) – in Alltagssprache.
    static let words: [String: String] = [
        "public": "„Öffentlich“: Jeder darf es benutzen.",
        "private": "„Privat“: Nur die eigene Klasse darf es benutzen – wie ein abgeschlossenes Fach.",
        "protected": "„Geschützt“: Die eigene Klasse und ihre Kind-Klassen dürfen es benutzen.",
        "static": "Gehört zur Kuchenform (Klasse) selbst – man braucht keinen Kuchen (kein Objekt), um es zu benutzen.",
        "void": "„Leer“: Die Methode liefert kein Ergebnis zurück.",
        "final": "Versiegelt: Nach dem ersten Befüllen kann sich der Inhalt nie mehr ändern.",
        "abstract": "Unfertig: Eine Kind-Klasse muss den fehlenden Teil ergänzen.",
        "class": "Beginnt eine Klasse – eine Kuchenform, aus der man Objekte (Kuchen) backt.",
        "interface": "Beginnt ein Interface – einen Vertrag: Er sagt, WAS eine Klasse können muss.",
        "record": "Beginnt einen Record – ein fertiges Formular mit festen Feldern.",
        "enum": "Beginnt eine Aufzählung fester Werte.",
        "extends": "„Erweitert“: Die neue Klasse übernimmt (erbt) alles von der Eltern-Klasse.",
        "implements": "„Setzt um“: Die Klasse unterschreibt den Vertrag eines Interfaces.",
        "new": "Backt ein neues Objekt aus einer Kuchenform (oder baut einen neuen Eierkarton).",
        "return": "Gibt das Ergebnis zurück und beendet die Methode – wie ein Automat, der sein Produkt ausgibt.",
        "this": "„Dieses Objekt hier“ – der Kuchen, um den es gerade geht. Mit this(…) ruft ein Konstruktor einen anderen derselben Klasse auf.",
        "super": "Die Eltern-Klasse – z. B. deren Backanleitung (Konstruktor).",
        "if": "„Wenn“: Führt Code nur aus, wenn die Antwort auf eine Frage „ja“ ist.",
        "else": "„Sonst“: Läuft, wenn die if-Frage mit „nein“ beantwortet wurde.",
        "for": "Eine Schleife: wiederholt Code – mit Zähler oder für jedes Element.",
        "while": "„Solange“: wiederholt Code, solange die Antwort auf eine Frage „ja“ ist.",
        "do": "„Mach“: Schleife, die erst einmal läuft und danach fragt.",
        "switch": "Ein Weichensteller: wählt je nach Wert einen von mehreren Wegen.",
        "case": "Ein Weg (Fall) beim Weichensteller switch.",
        "default": "Im switch: der Weg für alle übrigen Werte. In einem Interface: eine Methode, die das Interface fertig mitliefert.",
        "break": "Raus aus der Schleife – sofort.",
        "continue": "Diese Runde abbrechen und direkt mit der nächsten weitermachen.",
        "try": "„Versuch“: Code mit Sicherheitsnetz – ein Fehler (Alarm) bringt das Programm nicht zum Absturz.",
        "catch": "Das Sicherheitsnetz: fängt einen bestimmten Alarm (Exception) auf.",
        "finally": "Läuft zum Schluss immer – wie das Aufräumen nach dem Kochen.",
        "throw": "Löst absichtlich einen Alarm (eine Exception) aus.",
        "throws": "Warnt vorab: „Diese Methode kann folgenden Alarm auslösen.“",
        "var": "Java schaut sich den Inhalt an und wählt das passende Etikett (den Typ) selbst.",
        "null": "„Nichts drin“ – die Box enthält kein Objekt.",
        "true": "„Wahr“ bzw. „ja“.",
        "false": "„Falsch“ bzw. „nein“.",
        "instanceof": "Prüft, ob ein Objekt von einer bestimmten Sorte (Typ) ist.",
        "yield": "Gibt beim Weichensteller den Wert eines Falls zurück.",
        "import": "Holt Werkzeuge (Klassen) aus einem anderen Paket in den Code.",
        "int": "Etikett für ganze Zahlen, z. B. 42.",
        "long": "Etikett für sehr große ganze Zahlen.",
        "double": "Etikett für Kommazahlen, z. B. 9.99 (mit Punkt statt Komma).",
        "float": "Etikett für Kommazahlen mit weniger Genauigkeit.",
        "boolean": "Etikett für Ja/Nein-Werte: true (wahr) oder false (falsch).",
        "char": "Etikett für genau ein Zeichen, in einfachen Anführungszeichen: 'A'.",
        "String": "Etikett für Texte, in doppelten Anführungszeichen: \"Hallo\".",
        "Integer": "Die Objekt-Variante von int – nötig z. B. auf Listen.",
        "Object": "Die Ur-Klasse aller Objekte – passt auf jedes Objekt.",
        "List": "Eine Liste, die wachsen und schrumpfen kann – wie ein Einkaufszettel.",
        "ArrayList": "Die häufigste Listen-Sorte: ein Einkaufszettel, der automatisch mitwächst.",
        "Map": "Ein Wörterbuch: Zu jedem Schlüssel gehört ein Wert.",
        "HashMap": "Ein Wörterbuch, das Einträge sehr schnell findet (ohne feste Reihenfolge).",
        "TreeMap": "Ein Wörterbuch, das seine Schlüssel automatisch sortiert.",
        "Optional": "Eine Schachtel, die etwas enthalten kann – oder leer ist.",
        "StringBuilder": "Ein veränderbarer Text – z. B. zum Umdrehen oder Zusammenbauen.",
        "Comparator": "Eine Regel, wie man zwei Dinge vergleicht.",
        "Comparable": "„Vergleichbar“: Objekte dieser Sorte lassen sich der Größe nach vergleichen.",
        "Function": "Eine kleine Funktion als Objekt: Wert rein, anderer Wert raus.",
        "Predicate": "Eine kleine Ja-Nein-Frage als Objekt: Wert rein, true oder false raus (aufgerufen mit test).",
        "Supplier": "Ein kleiner Lieferant als Objekt: bekommt nichts, liefert etwas (abgerufen mit get).",
        "Consumer": "Ein kleiner Abnehmer als Objekt: bekommt etwas, liefert nichts zurück (aufgerufen mit accept).",
        "Iterator": "Ein Lesezeichen, das Element für Element durch eine Sammlung wandert.",
        "Collectors": "Werkzeuge, um am Ende eines Fließbands (Stream) alles einzusammeln.",
        "Math": "Werkzeugkasten für Mathematik (z. B. π).",
        "Exception": "Oberbegriff für alle Alarme (Fehler), die man auffangen kann.",
        "RuntimeException": "Alarme, die man nicht vorab ankündigen muss.",
        "ArithmeticException": "Rechen-Alarm, z. B. bei einer Division durch 0.",
        "NumberFormatException": "Alarm: Ein Text lässt sich nicht in eine Zahl umwandeln.",
        "IllegalArgumentException": "Alarm: Einer Methode wurde ein ungültiger Wert gegeben.",
        "NullPointerException": "Alarm: In der Box liegt nichts (null), obwohl etwas benutzt werden soll.",
        "ArrayIndexOutOfBoundsException": "Alarm: Dieses Fach im Eierkarton gibt es nicht.",
        "IOException": "Alarm beim Lesen oder Schreiben, z. B. von Dateien.",
        "InterruptedException": "Alarm: Ein wartender Thread wurde unterbrochen.",
        "sealed": "„Versiegelt“: Nur ausdrücklich erlaubte Typen dürfen dazugehören – eine geschlossene Familie.",
        "permits": "Zählt bei sealed auf, welche Typen zur Familie gehören dürfen.",
        "when": "Zusatzbedingung im switch: Der Fall passt nur, wenn auch diese Frage mit „ja“ beantwortet wird.",
        "package": "Legt fest, in welchem Paket (Ordner) eine Klasse liegt.",
        "Test": "JUnit-Hinweis @Test: Diese Methode ist ein automatischer Test.",
        "Override": "Hinweis @Override: Diese Methode ersetzt eine geerbte Methode.",
        "Set": "Eine Menge: Jeder Eintrag kommt höchstens einmal vor – wie ein Stempelheft.",
        "HashSet": "Eine Menge ohne Doppelte, ohne feste Reihenfolge.",
        "TreeSet": "Eine Menge ohne Doppelte, die alles automatisch sortiert.",
        "Deque": "Eine Reihe, an der man vorne und hinten anbauen kann – Stapel oder Warteschlange.",
        "Queue": "Eine Warteschlange: Wer zuerst kommt, ist zuerst dran.",
        "ArrayDeque": "Die übliche Sorte für Stapel und Warteschlangen.",
        "Thread": "Ein eigener Arbeitsstrang – wie ein zweiter Koch, der gleichzeitig arbeitet.",
        "Runnable": "Eine Aufgabe ohne Zutaten und ohne Ergebnis, die man laufen lassen kann.",
        "AtomicInteger": "Ein Zähler, der auch bei mehreren Threads gleichzeitig richtig zählt.",
        "ExecutorService": "Ein Team von Threads, das eingereichte Aufgaben abarbeitet.",
        "Executors": "Werkzeugkasten, der fertige Teams (ExecutorService) baut.",
        "Future": "Ein Abholschein für ein Ergebnis, das erst später fertig wird.",
        "Scanner": "Ein Lesegerät, das Text (z. B. Tastatureingaben) Stück für Stück liest.",
        "LocalDate": "Ein Kalenderdatum ohne Uhrzeit.",
        "Period": "Ein Zeitabstand in Jahren, Monaten und Tagen.",
        "DateTimeFormatter": "Eine Formatvorlage: So soll ein Datum als Text aussehen.",
        "Path": "Die Adresse einer Datei.",
        "Files": "Werkzeugkasten zum Lesen, Schreiben und Löschen von Dateien.",
        "Arrays": "Werkzeugkasten für Eierkartons (Arrays): sortieren, anzeigen, Fließband starten.",
        "Objects": "Werkzeugkasten für Objekte, z. B. um eine Kennnummer (hashCode) zu berechnen.",
        "Character": "Die Objekt-Variante von char – ein einzelnes Zeichen.",
        "Long": "Die Objekt-Variante von long – eine große ganze Zahl.",
    ]

    /// Qualifizierte Namen wie `System.out` oder `Integer.parseInt`.
    static let qualified: [String: String] = [
        "System.out": "Der Bildschirm (die Konsole) – dorthin schreibt das Programm.",
        "Integer.parseInt": "Verwandelt einen Text wie \"42\" in die Zahl 42.",
        "Integer.MAX_VALUE": "Die größte Zahl, die in eine int-Box passt: 2147483647. Eins mehr, und die Zahl springt ins Negative (Überlauf).",
        "Integer.MIN_VALUE": "Die kleinste Zahl, die in eine int-Box passt: -2147483648.",
        "String.format": "Füllt eine Schablone mit Platzhaltern wie %s und %d und liefert den fertigen Text zurück, ohne ihn auszugeben.",
        "List.of": "Schreibt sofort einen fertigen Einkaufszettel mit diesen Einträgen (danach unveränderlich).",
        "Optional.of": "Packt einen Wert in eine Schachtel (Optional).",
        "Optional.ofNullable": "Packt einen Wert in eine Schachtel – ist er null, bleibt die Schachtel leer.",
        "Optional.empty": "Eine leere Schachtel (Optional).",
        "Collectors.joining": "Klebt am Ende alle Texte zu einem zusammen, mit Trennzeichen dazwischen.",
        "Math.PI": "Die Kreiszahl π ≈ 3,14159.",
        "Math.max": "Liefert die größere von zwei Zahlen.",
        "Map.of": "Schreibt sofort ein fertiges Wörterbuch mit diesen Einträgen (danach unveränderlich).",
        "Arrays.sort": "Sortiert einen Eierkarton (Array) aufsteigend.",
        "Arrays.toString": "Zeigt den Inhalt eines Eierkartons als Text, z. B. [1, 2, 3].",
        "Arrays.stream": "Legt alle Werte eines Eierkartons aufs Fließband (Stream).",
        "Comparator.comparing": "Baut eine Sortierregel: vergleiche nach diesem Merkmal (z. B. der Länge).",
        "Comparator.naturalOrder": "Die übliche Reihenfolge: Zahlen aufsteigend, Texte alphabetisch.",
        "Collectors.groupingBy": "Sortiert am Ende des Fließbands alles in Fächer – heraus kommt ein Wörterbuch.",
        "Collectors.counting": "Zählt, wie viele Elemente in einem Fach liegen.",
        "Collectors.toList": "Sammelt die Elemente in einer Liste.",
        "Executors.newFixedThreadPool": "Baut ein Team mit einer festen Zahl von Threads.",
        "Executors.newVirtualThreadPerTaskExecutor": "Baut ein Team, das jeder Aufgabe einen eigenen virtuellen Thread gibt (Java 21).",
        "LocalDate.of": "Legt ein Datum an: Jahr, Monat, Tag.",
        "Period.between": "Misst den Abstand zwischen zwei Daten.",
        "DateTimeFormatter.ofPattern": "Baut eine Formatvorlage, z. B. \"dd.MM.yyyy\" für 03.10.2026.",
        "Files.createTempFile": "Legt eine neue, leere Übungsdatei an und liefert ihre Adresse.",
        "Files.writeString": "Schreibt Text in eine Datei (alter Inhalt wird ersetzt).",
        "Files.readAllLines": "Liest alle Zeilen einer Datei als Liste von Texten.",
        "Files.delete": "Löscht eine Datei.",
        "Objects.hash": "Berechnet eine Kennnummer (Hash-Wert) aus mehreren Werten.",
    ]

    /// Methoden (erkannt als `.name(`), dazu optional, was ihr Ergebnis ist.
    static let methods: [String: (meaning: String, result: String?)] = [
        "println": ("Schreibt etwas auf den Bildschirm und springt danach in eine neue Zeile.", nil),
        "print": ("Schreibt etwas auf den Bildschirm – ohne neue Zeile danach.", nil),
        "length": ("Zählt die Zeichen eines Texts.", "die Anzahl der Zeichen"),
        "charAt": ("Holt das Zeichen an einer Position (gezählt ab 0).", "das Zeichen an dieser Position"),
        "toUpperCase": ("Macht aus dem Text GROSSBUCHSTABEN.", "den Text in Großbuchstaben"),
        "toLowerCase": ("Macht aus dem Text kleinbuchstaben.", "den Text in Kleinbuchstaben"),
        "substring": ("Schneidet ein Stück aus dem Text: von Position A (dabei) bis Position B (nicht mehr dabei).", "das ausgeschnittene Textstück"),
        "equals": ("Vergleicht den Inhalt: Steht in beiden dasselbe? (true/false)", "true, wenn beide inhaltlich gleich sind, sonst false"),
        "equalsIgnoreCase": ("Vergleicht zwei Texte – Groß- und Kleinschreibung egal.", "true, wenn beide Texte gleich sind"),
        "add": ("Schreibt einen neuen Eintrag ans Ende der Liste.", nil),
        "get": ("Holt einen Eintrag – bei Listen über die Position, bei Wörterbüchern über den Schlüssel.", "den gespeicherten Eintrag"),
        "size": ("Zählt, wie viele Einträge es gibt.", "die Anzahl der Einträge"),
        "remove": ("Streicht einen Eintrag – beim Iterator genau den, der zuletzt mit next() geholt wurde.", nil),
        "printf": ("Schreibt eine Schablone auf den Bildschirm und setzt dabei Werte für Platzhalter wie %s und %d ein.", nil),
        "apply": ("Wendet eine Function an: Sie bekommt einen Wert und liefert ihr Ergebnis.", "das Ergebnis der Funktion"),
        "test": ("Stellt die Ja-Nein-Frage eines Predicate für einen Wert (true/false).", "true oder false – die Antwort auf die Frage"),
        "iterator": ("Holt ein Lesezeichen (Iterator), das Element für Element durch die Sammlung wandert.", "ein Lesezeichen für die Sammlung"),
        "hasNext": ("Fragt ein Lesezeichen (Iterator oder Scanner): Kommt noch etwas? (true/false)", "true, wenn noch etwas kommt"),
        "put": ("Trägt ins Wörterbuch ein: Schlüssel → Wert (ersetzt einen alten Eintrag).", nil),
        "getOrDefault": ("Holt den Eintrag zum Schlüssel – oder einen Ersatzwert, falls es keinen gibt.", "den Eintrag oder den Ersatzwert"),
        "orElse": ("Nimmt den Inhalt der Schachtel – oder einen Ersatz, wenn sie leer ist.", "den Inhalt oder den Ersatzwert"),
        "isPresent": ("Schaut nach, ob in der Schachtel etwas drin ist (true/false).", "true, wenn etwas drin ist"),
        "map": ("Umformer: wandelt jedes Element (bzw. den Inhalt der Schachtel) um.", nil),
        "stream": ("Legt alle Elemente auf ein Fließband (Stream) zur Verarbeitung.", nil),
        "filter": ("Sieb am Fließband: lässt nur passende Elemente durch.", nil),
        "mapToInt": ("Umformer am Fließband: macht aus den Elementen ganze Zahlen.", nil),
        "sum": ("Zählt am Ende des Fließbands alle Zahlen zusammen.", "die Summe"),
        "toList": ("Packt am Ende des Fließbands alles in eine neue Liste.", "die neue Liste"),
        "count": ("Zählt am Ende des Fließbands die Elemente.", "die Anzahl"),
        "collect": ("Sammelt am Ende des Fließbands alles ein.", nil),
        "forEach": ("Macht etwas mit jedem einzelnen Element.", nil),
        "compareTo": ("Vergleicht zwei Werte: negativ = kleiner, 0 = gleich, positiv = größer.", "eine Zahl: negativ, 0 oder positiv"),
        "getMessage": ("Liest die Meldung des Alarms (der Exception).", "die Fehlermeldung"),
        "reverse": ("Dreht die Reihenfolge der Zeichen um.", nil),
        "toString": ("Macht aus einem Objekt einen normalen Text.", "den Text"),
        "getLast": ("Holt den letzten Eintrag der Liste.", "den letzten Eintrag"),
        "ordinal": ("Liefert die Position eines enum-Werts – gezählt ab 0.", "die Position, gezählt ab 0"),
        "values": ("Liefert alle Werte eines enums als Eierkarton.", "alle Werte als Eierkarton"),
        "append": ("Hängt etwas an den Notizblock (StringBuilder) an.", nil),
        "next": ("Holt das Nächste: beim Scanner das nächste Wort, beim Iterator das nächste Element.", "das nächste Wort"),
        "nextInt": ("Liest die nächste ganze Zahl.", "die nächste Zahl"),
        "hasNextInt": ("Fragt, ob noch eine Zahl kommt (true/false).", "true, wenn noch eine Zahl kommt"),
        "plusDays": ("Rechnet Tage zu einem Datum dazu – heraus kommt ein neues Datum.", "ein neues, späteres Datum"),
        "getDayOfMonth": ("Liefert den Tag im Monat (1–31).", "den Tag im Monat"),
        "getYears": ("Liefert die vollen Jahre eines Zeitabstands.", "die vollen Jahre"),
        "format": ("Baut Text nach einer Vorlage – ein Datum im gewünschten Format oder eine Schablone mit Platzhaltern wie %s und %d.", "das Datum als Text"),
        "sort": ("Sortiert eine Liste nach einer Regel.", nil),
        "reversed": ("Dreht eine Sortierregel um: absteigend statt aufsteigend.", "die umgedrehte Regel"),
        "contains": ("Fragt, ob etwas enthalten ist (true/false).", "true, wenn es enthalten ist"),
        "trim": ("Schneidet Leerzeichen am Anfang und am Ende weg.", "der Text ohne Leerzeichen am Rand"),
        "split": ("Zerlegt einen Text an einem Trennzeichen in mehrere Teile.", "einen Eierkarton mit den Teilen"),
        "startsWith": ("Fragt, ob der Text so anfängt (true/false).", "true, wenn der Text so beginnt"),
        "keySet": ("Liefert alle Schlüssel eines Wörterbuchs.", "alle Schlüssel"),
        "getMonthValue": ("Die Nummer des Monats (1 = Januar).", "die Monatszahl"),
        "getDayOfWeek": ("Der Wochentag eines Datums – als enum-Wert, also in Großbuchstaben und auf Englisch.", "den Wochentag"),
        "plusMonths": ("Rechnet Monate zu einem Datum dazu. Gibt es den Tag im Zielmonat nicht, rückt das Datum auf den letzten gültigen.", "ein neues, späteres Datum"),
        "readString": ("Liest eine ganze Datei am Stück als Text ein.", "den Inhalt der Datei"),
        "comparingInt": ("Baut eine Sortierregel aus einer Zahl, die man zu jedem Element ausrechnet.", "die Sortierregel"),
        "thenComparing": ("Zweite Sortierregel für den Fall, dass die erste unentschieden ausgeht.", "die erweiterte Sortierregel"),
        "getHour": ("Die Stunde einer Uhrzeit (0–23).", "die Stunde"),
        "getMonths": ("Die vollen Monate eines Zeitabstands – ohne die Jahre und ohne die restlichen Tage.", "die vollen Monate"),
        "getDays": ("Die übrigen Tage eines Zeitabstands – also der Rest nach den vollen Monaten.", "die restlichen Tage"),
        "plusHours": ("Rechnet Stunden dazu – heraus kommt ein neuer Zeitpunkt, notfalls am nächsten Tag.", "einen neuen, späteren Zeitpunkt"),
        "toLocalDate": ("Schneidet die Uhrzeit weg und behält nur den Tag.", "das Datum ohne Uhrzeit"),
        "toEpochDay": ("Macht aus einem Datum eine fortlaufende Tagesnummer, gezählt ab dem 1. Januar 1970.", "die Tagesnummer"),
        "isBefore": ("Fragt, ob dieser Zeitpunkt vor dem anderen liegt (true/false).", "true, wenn er früher liegt"),
        "isEmpty": ("Fragt, ob gar nichts drin ist – kein Zeichen, kein Eintrag (true/false).", "true, wenn es leer ist"),
        "isBlank": ("Fragt, ob der Text nur aus Leerraum besteht – leer oder nur Leerzeichen (true/false).", "true, wenn nichts Sichtbares drinsteht"),
        "indexOf": ("Sucht, an welcher Position etwas zum ersten Mal steht – gezählt ab 0, oder -1, wenn es fehlt.", "die Position oder -1"),
        "replace": ("Ersetzt jedes Vorkommen eines Textstücks durch ein anderes.", "den Text mit den Ersetzungen"),
        "toCharArray": ("Zerlegt einen Text in seine einzelnen Zeichen.", "einen Eierkarton mit den Zeichen"),
        "insert": ("Schiebt etwas an einer Position in den Notizblock (StringBuilder) hinein.", nil),
        "subList": ("Schneidet ein Stück aus der Liste: von Position A (dabei) bis Position B (nicht mehr dabei).", "das ausgeschnittene Stück der Liste"),
        "removeIf": ("Wirft alle Einträge hinaus, auf die eine Bedingung zutrifft.", nil),
        "retainAll": ("Behält nur das, was auch in der anderen Sammlung steht – die Schnittmenge.", nil),
        "binarySearch": ("Sucht in einer sortierten Sammlung durch fortlaufendes Halbieren.", "die Position oder eine negative Zahl"),
        "reverseOrder": ("Liefert die umgekehrte Sortierregel: das Größte zuerst.", "die umgekehrte Regel"),
        "first": ("Holt den kleinsten Eintrag einer sortierten Menge.", "den ersten Eintrag"),
        "last": ("Holt den größten Eintrag einer sortierten Menge.", "den letzten Eintrag"),
        "getSimpleName": ("Der Name der Klasse ohne Paket davor.", "den Klassennamen"),
        "valueOf": ("Verpackt einen einfachen Wert als Objekt – z. B. int zu Integer.", "den Wert als Objekt"),
        "push": ("Legt etwas oben auf den Stapel.", nil),
        "pop": ("Nimmt den obersten Eintrag vom Stapel.", "den obersten Eintrag"),
        "peek": ("Schaut den obersten bzw. vordersten Eintrag an, ohne ihn wegzunehmen.", "den obersten Eintrag"),
        "offer": ("Stellt etwas hinten an die Warteschlange.", nil),
        "poll": ("Holt den vordersten Eintrag aus der Warteschlange.", "den vordersten Eintrag"),
        "start": ("Lässt einen Thread loslaufen.", nil),
        "join": ("Wartet, bis ein Thread fertig ist.", nil),
        "incrementAndGet": ("Zählt einen sicheren Zähler um 1 hoch.", "den neuen Zählerstand"),
        "addAndGet": ("Zählt eine Zahl zu einem sicheren Zähler dazu.", "den neuen Zählerstand"),
        "submit": ("Reicht eine Aufgabe beim Team ein – zurück kommt ein Abholschein (Future).", "einen Abholschein (Future)"),
        "set": ("Ersetzt den Eintrag an einer Position.", nil),
        "flatMap": ("Macht aus Listen von Listen eine flache Liste.", nil),
        "sorted": ("Bringt die Elemente am Fließband in Reihenfolge.", nil),
        "max": ("Sucht das größte Element.", "das größte Element (in einer Schachtel)"),
        "min": ("Sucht das kleinste Element.", "das kleinste Element (in einer Schachtel)"),
        "reduce": ("Fasst alle Elemente zu einem einzigen Wert zusammen.", "einen einzigen Wert"),
        "average": ("Bildet den Durchschnitt.", "den Durchschnitt (in einer Schachtel)"),
        "hash": ("Berechnet eine Kennnummer.", "eine Kennnummer"),
    ]

    /// Operatoren – längste zuerst, damit `<=` nicht als `<` erkannt wird.
    static let operators: [(symbol: String, meaning: String)] = [
        ("...", "Drei Punkte hinter einem Typ (varargs): beliebig viele Werte – in der Methode liegen sie als Eierkarton (Array) bereit."),
        ("->", "Pfeil: „wird zu“ – trennt bei Mini-Anweisungen (Lambdas) die Eingabe vom Ergebnis, bei switch den Fall vom Ergebnis."),
        ("::", "Verweis auf eine fertige Methode, ohne sie sofort aufzurufen."),
        ("++", "Zählt um 1 hoch."),
        ("--", "Zählt um 1 herunter."),
        ("+=", "Legt etwas zum bisherigen Inhalt dazu."),
        ("-=", "Nimmt etwas vom bisherigen Inhalt weg."),
        ("*=", "Nimmt den bisherigen Inhalt mal eine Zahl."),
        ("/=", "Teilt den bisherigen Inhalt durch eine Zahl."),
        ("==", "Frage „Ist das gleich?“ (bei Objekten: „Ist das dasselbe Objekt?“)."),
        ("!=", "Frage „Ist das ungleich?“."),
        ("<=", "Frage „Kleiner oder gleich?“."),
        (">=", "Frage „Größer oder gleich?“."),
        ("&&", "„Und“: Beide Antworten müssen „ja“ sein."),
        ("||", "„Oder“: Mindestens eine Antwort muss „ja“ sein."),
        ("<", "Frage „Kleiner als?“."),
        (">", "Frage „Größer als?“."),
        ("=", "Einfüllen: Der Wert rechts kommt in die Box links (kein Vergleich!)."),
        ("+", "Plus: rechnet zusammen – oder klebt Texte aneinander."),
        ("-", "Minus."),
        ("*", "Mal."),
        ("/", "Geteilt – bei zwei ganzen Zahlen fallen die Nachkommastellen weg (7 / 2 = 3)."),
        ("%", "Rest beim Teilen: 7 % 2 = 1."),
        ("!", "„Nicht“: macht aus ja ein nein und umgekehrt."),
        ("[]", "Eckige Klammern: ein Eierkarton (Array) bzw. ein bestimmtes Fach darin."),
        ("<>", "Spitze Klammern: sagen, was hineindarf – List<String> = Liste nur für Texte."),
    ]

    public static func entry(for term: String) -> GlossaryEntry? {
        if let meaning = words[term] ?? qualified[term] { return GlossaryEntry(term: term, meaning: meaning) }
        if let method = methods[term] { return GlossaryEntry(term: term + "()", meaning: method.meaning) }
        if let op = operators.first(where: { $0.symbol == term }) { return GlossaryEntry(term: op.symbol, meaning: op.meaning) }
        return nil
    }

    static func resultPhrase(forMethod name: String) -> String? { methods[name]?.result }

    private static let tokenPattern = try? NSRegularExpression(
        pattern: #"\.\.\.|[A-Za-z_][A-Za-z0-9_]*(?:\s*\.\s*[A-Za-z_][A-Za-z0-9_]*)*(?:\s*\()?|->|::|\+\+|--|[+\-*/]=|==|!=|<=|>=|&&|\|\||\[\]|<>|[-+*/%<>=!]"#
    )

    /// Alle Lexikon-Begriffe in einer (maskierten) Codezeile, in Lesereihenfolge.
    public static func terms(in maskedLine: String) -> [GlossaryEntry] {
        guard let tokenPattern else { return [] }
        var result: [GlossaryEntry] = []
        var seen = Set<String>()
        func add(_ entry: GlossaryEntry?) {
            if let entry, seen.insert(entry.term).inserted { result.append(entry) }
        }
        let chars = Array(maskedLine)
        let range = NSRange(maskedLine.startIndex..., in: maskedLine)
        for match in tokenPattern.matches(in: maskedLine, range: range) {
            guard let tokenRange = Range(match.range, in: maskedLine) else { continue }
            let token = String(maskedLine[tokenRange])
            let start = match.range.location
            let end = start + match.range.length
            let before: Character? = start > 0 ? chars[start - 1] : nil
            let after: Character? = end < chars.count ? chars[end] : nil

            if let first = token.first, first.isLetter || first == "_" {
                let hasParen = token.hasSuffix("(")
                let parts = token.replacingOccurrences(of: "(", with: "")
                    .split(separator: ".").map { $0.trimmingCharacters(in: .whitespaces) }
                var index = 0
                if parts.count >= 2, let meaning = qualified["\(parts[0]).\(parts[1])"] {
                    add(GlossaryEntry(term: "\(parts[0]).\(parts[1])", meaning: meaning))
                    index = 2
                } else {
                    add(entry(for: parts[0]))
                    index = 1
                }
                while index < parts.count {
                    let name = parts[index]
                    let isLast = index == parts.count - 1
                    if isLast && hasParen, methods[name] != nil {
                        add(entry(for: name))
                    } else if name == "length" && !(isLast && hasParen) {
                        add(GlossaryEntry(term: ".length", meaning: "Zählt die Fächer eines Eierkartons (Array) – ohne Klammern dahinter."))
                    }
                    index += 1
                }
                // Generics direkt hinter einem Typ: List<String>
                if after == "<" { add(entry(for: "<>")) }
                continue
            }

            switch token {
            case "<", ">":
                // Vergleich nur mit Leerzeichen davor und danach – sonst sind es Generics.
                if before == " " && after == " " { add(entry(for: token)) }
            case "+", "-", "*", "/", "%", "=":
                if before == " " && after == " " { add(entry(for: token)) }
            case "!":
                if after != "=" { add(entry(for: token)) }
            case "<>":
                add(entry(for: "<>"))
            default:
                add(entry(for: token))
            }
        }
        return result
    }
}
