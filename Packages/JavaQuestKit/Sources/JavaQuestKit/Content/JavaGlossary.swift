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
        "this": "„Dieses Objekt hier“ – der Kuchen, um den es gerade geht.",
        "super": "Die Eltern-Klasse – z. B. deren Backanleitung (Konstruktor).",
        "if": "„Wenn“: Führt Code nur aus, wenn die Antwort auf eine Frage „ja“ ist.",
        "else": "„Sonst“: Läuft, wenn die if-Frage mit „nein“ beantwortet wurde.",
        "for": "Eine Schleife: wiederholt Code – mit Zähler oder für jedes Element.",
        "while": "„Solange“: wiederholt Code, solange die Antwort auf eine Frage „ja“ ist.",
        "do": "„Mach“: Schleife, die erst einmal läuft und danach fragt.",
        "switch": "Ein Weichensteller: wählt je nach Wert einen von mehreren Wegen.",
        "case": "Ein Weg (Fall) beim Weichensteller switch.",
        "default": "Der Weg für alle übrigen Werte beim Weichensteller.",
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
    ]

    /// Qualifizierte Namen wie `System.out` oder `Integer.parseInt`.
    static let qualified: [String: String] = [
        "System.out": "Der Bildschirm (die Konsole) – dorthin schreibt das Programm.",
        "Integer.parseInt": "Verwandelt einen Text wie \"42\" in die Zahl 42.",
        "List.of": "Schreibt sofort einen fertigen Einkaufszettel mit diesen Einträgen (danach unveränderlich).",
        "Optional.of": "Packt einen Wert in eine Schachtel (Optional).",
        "Optional.ofNullable": "Packt einen Wert in eine Schachtel – ist er null, bleibt die Schachtel leer.",
        "Optional.empty": "Eine leere Schachtel (Optional).",
        "Collectors.joining": "Klebt am Ende alle Texte zu einem zusammen, mit Trennzeichen dazwischen.",
        "Math.PI": "Die Kreiszahl π ≈ 3,14159.",
        "Math.max": "Liefert die größere von zwei Zahlen.",
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
        "remove": ("Streicht einen Eintrag.", nil),
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
    ]

    /// Operatoren – längste zuerst, damit `<=` nicht als `<` erkannt wird.
    static let operators: [(symbol: String, meaning: String)] = [
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
        pattern: #"[A-Za-z_][A-Za-z0-9_]*(?:\s*\.\s*[A-Za-z_][A-Za-z0-9_]*)*(?:\s*\()?|->|::|\+\+|--|[+\-*/]=|==|!=|<=|>=|&&|\|\||\[\]|<>|[-+*/%<>=!]"#
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
