import Foundation

/// Ein Objekt zur Laufzeit: Objekt einer eigenen Klasse, eine Sammlung aus der Bibliothek
/// (Liste, Map, Set, Deque), ein StringBuilder oder eine Exception. Objekte sind Referenzen –
/// zwei Variablen können auf dasselbe Objekt zeigen.
public final class JavaObject: @unchecked Sendable {
    enum Kind: Sendable {
        /// Objekt einer eigenen Klasse (auch Enum-Konstante und Record).
        case plain
        case list
        case map
        case set
        case deque
        case builder
        /// Eingebaute Exception (eigene Exceptions sind `.plain` mit einer Exception als Oberklasse).
        case throwable
        /// Ergebnis von `getClass()`.
        case classInfo
        /// Ein Eintrag aus `map.entrySet()`.
        case entry
    }

    /// Reihenfolge beim Durchlaufen von Maps und Sets.
    enum Order: Sendable {
        /// HashMap/HashSet: wie Java nach Hash-Fächern.
        case hash
        /// LinkedHashMap/LinkedHashSet und unveränderliche Sammlungen: Reihenfolge des Einfügens.
        case insertion
        /// TreeMap/TreeSet: sortiert.
        case sorted
    }

    let kind: Kind
    /// Laufzeitklasse, z. B. `Hund`, `ArrayList`, `ArithmeticException`.
    let className: String
    /// Felder eigener Objekte (Exceptions: `message`). Die Reihenfolge der Deklaration steht in `fieldOrder`.
    var fields: [String: JavaValue] = [:]
    var fieldTypes: [String: JavaType] = [:]
    var fieldOrder: [String] = []
    /// Klasse, in der ein Feld deklariert ist – für private Zugriffe und final-Prüfung.
    var fieldOwners: [String: String] = [:]
    var privateFields: Set<String> = []
    var finalFields: Set<String> = []
    /// Liste, Set, Deque – bei Maps die Schlüssel.
    var elements: [JavaValue] = []
    /// Werte einer Map (gleiche Stelle wie der Schlüssel in `elements`).
    var values: [JavaValue] = []
    /// Einfüge-Nummern für Javas HashMap-Reihenfolge.
    var sequence: [Int] = []
    var nextSequence = 0
    /// Größe der Hash-Tabelle (wächst wie in Java, schrumpft nie).
    var capacity = 16
    var order: Order = .insertion
    /// Text eines StringBuilders.
    var text = ""
    /// `List.of`, `Map.of`, `Set.of`: jede Änderung wirft UnsupportedOperationException.
    var isImmutable = false
    let serial: Int

    private static let counterLock = NSLock()
    nonisolated(unsafe) private static var counter = 0x2a139a55

    init(kind: Kind, className: String) {
        self.kind = kind
        self.className = className
        self.serial = Self.counterLock.withLock {
            Self.counter = (Self.counter &* 31 &+ 11) & 0x7fffffff
            return Self.counter
        }
    }

    /// Einfache Beschreibung für die Variablen-Anzeige – ohne eigene toString-Methoden aufzurufen.
    var debugDescription: String {
        switch kind {
        case .list, .set, .deque:
            return "[" + elements.prefix(10).map(\.debugDisplay).joined(separator: ", ") + (elements.count > 10 ? ", …" : "") + "]"
        case .map:
            let pairs = zip(elements, values).prefix(8).map { "\($0.debugDisplay)=\($1.debugDisplay)" }
            return "{" + pairs.joined(separator: ", ") + (elements.count > 8 ? ", …" : "") + "}"
        case .builder:
            return "\"\(text)\""
        case .throwable:
            return className + (fields["message"].flatMap { $0.stringValue }.map { ": \($0)" } ?? "")
        case .classInfo:
            return "class " + (fields["name"]?.stringValue ?? "")
        case .entry:
            return "\(elements.first?.debugDisplay ?? "")=\(values.first?.debugDisplay ?? "")"
        case .plain:
            if let name = fields["$name"]?.stringValue { return name } // Enum-Konstante
            let shown = fieldOrder.prefix(5).compactMap { name in fields[name].map { "\(name)=\($0.debugDisplay)" } }
            return className + "{" + shown.joined(separator: ", ") + (fieldOrder.count > 5 ? ", …" : "") + "}"
        }
    }
}

/// Wissen über die eingebauten Klassen: Wer erbt von wem, in welchem Paket liegt sie.
enum JavaBuiltins {
    /// Oberklasse eingebauter Exceptions und Fehler.
    static let throwableParents: [String: String] = [
        "Throwable": "Object",
        "Exception": "Throwable", "Error": "Throwable",
        "RuntimeException": "Exception",
        "ArithmeticException": "RuntimeException",
        "IndexOutOfBoundsException": "RuntimeException",
        "ArrayIndexOutOfBoundsException": "IndexOutOfBoundsException",
        "StringIndexOutOfBoundsException": "IndexOutOfBoundsException",
        "NullPointerException": "RuntimeException",
        "IllegalArgumentException": "RuntimeException",
        "NumberFormatException": "IllegalArgumentException",
        "IllegalFormatException": "IllegalArgumentException",
        "UnknownFormatConversionException": "IllegalFormatException",
        "MissingFormatArgumentException": "IllegalFormatException",
        "IllegalFormatConversionException": "IllegalFormatException",
        "PatternSyntaxException": "IllegalArgumentException",
        "IllegalStateException": "RuntimeException",
        "ClassCastException": "RuntimeException",
        "UnsupportedOperationException": "RuntimeException",
        "NegativeArraySizeException": "RuntimeException",
        "ArrayStoreException": "RuntimeException",
        "NoSuchElementException": "RuntimeException",
        "InputMismatchException": "NoSuchElementException",
        "ConcurrentModificationException": "RuntimeException",
        "EmptyStackException": "RuntimeException",
        "DateTimeException": "RuntimeException",
        "UncheckedIOException": "RuntimeException",
        "IOException": "Exception",
        "FileNotFoundException": "IOException",
        "InterruptedException": "Exception",
        "CloneNotSupportedException": "Exception",
        "StackOverflowError": "Error",
        "OutOfMemoryError": "Error",
        "AssertionError": "Error",
    ]

    static let packages: [String: String] = [
        "NoSuchElementException": "java.util", "InputMismatchException": "java.util",
        "ConcurrentModificationException": "java.util", "EmptyStackException": "java.util",
        "IOException": "java.io", "FileNotFoundException": "java.io", "UncheckedIOException": "java.io",
        "DateTimeException": "java.time",
    ]

    /// Voller Name, wie ihn `toString()` und `getName()` zeigen (`java.lang.ArithmeticException`).
    static func qualifiedName(_ className: String) -> String {
        if let package = packages[className] { return "\(package).\(className)" }
        if throwableParents[className] != nil || ["Object", "String", "Integer", "Long", "Double", "Boolean", "Character", "StringBuilder"].contains(className) {
            return "java.lang.\(className)"
        }
        if ["ArrayList", "LinkedList", "HashMap", "TreeMap", "LinkedHashMap", "HashSet", "TreeSet", "LinkedHashSet", "ArrayDeque"].contains(className) {
            return "java.util.\(className)"
        }
        return className
    }

    /// Bibliotheksklassen und ihre Obertypen (für Zuweisungen, instanceof und Casts).
    static let librarySupertypes: [String: Set<String>] = [
        "ArrayList": ["List", "Collection", "Iterable", "Object", "AbstractList"],
        "LinkedList": ["List", "Deque", "Queue", "Collection", "Iterable", "Object"],
        "ImmutableList": ["List", "Collection", "Iterable", "Object"],
        "HashMap": ["Map", "Object", "AbstractMap"],
        "LinkedHashMap": ["Map", "HashMap", "Object"],
        "TreeMap": ["Map", "SortedMap", "NavigableMap", "Object"],
        "ImmutableMap": ["Map", "Object"],
        "HashSet": ["Set", "Collection", "Iterable", "Object"],
        "LinkedHashSet": ["Set", "HashSet", "Collection", "Iterable", "Object"],
        "TreeSet": ["Set", "SortedSet", "NavigableSet", "Collection", "Iterable", "Object"],
        "ImmutableSet": ["Set", "Collection", "Iterable", "Object"],
        "ArrayDeque": ["Deque", "Queue", "Collection", "Iterable", "Object"],
        "Stack": ["List", "Collection", "Iterable", "Object"],
        "StringBuilder": ["CharSequence", "Object"],
        "Entry": ["Map.Entry", "Object"],
    ]

    /// Typen, die der Interpreter kennt, ohne dass sie im Programm stehen.
    static let knownTypes: Set<String> = Set(throwableParents.keys).union([
        "Object", "Integer", "Long", "Double", "Boolean", "Character", "Number", "Comparable", "CharSequence",
        "List", "ArrayList", "LinkedList", "Collection", "Iterable", "Map", "HashMap", "TreeMap", "LinkedHashMap",
        "Map.Entry", "Entry", "Set", "HashSet", "TreeSet", "LinkedHashSet", "Deque", "ArrayDeque", "Queue", "Stack",
        "StringBuilder", "SortedMap", "SortedSet", "NavigableMap", "NavigableSet",
    ])

    static func isThrowable(_ className: String) -> Bool { throwableParents[className] != nil }

    /// Ist `child` gleich `ancestor` oder eine (eingebaute) Unterklasse davon?
    static func throwableIs(_ child: String, _ ancestor: String) -> Bool {
        var current: String? = child
        while let name = current {
            if name == ancestor { return true }
            current = throwableParents[name]
        }
        return ancestor == "Object"
    }
}

/// Javas Hash-Werte – nötig, damit HashMap und HashSet in derselben Reihenfolge ausgeben wie Java.
enum JavaHashing {
    static func stringHash(_ text: String) -> Int32 {
        var hash: Int32 = 0
        for unit in text.utf16 { hash = hash &* 31 &+ Int32(unit) }
        return hash
    }

    static func doubleHash(_ value: Double) -> Int32 {
        // Double.hashCode: Bits (mit NaN-Normalisierung) als long, dann oberes XOR unteres Wort.
        let bits = value.isNaN ? Int64(0x7ff8000000000000) : Int64(bitPattern: value.bitPattern)
        return Int32(truncatingIfNeeded: bits ^ Int64(bitPattern: UInt64(bitPattern: bits) >> 32))
    }

    static func longHash(_ value: Int64) -> Int32 {
        Int32(truncatingIfNeeded: value ^ Int64(bitPattern: UInt64(bitPattern: value) >> 32))
    }

    /// Fach in der Hash-Tabelle wie in `java.util.HashMap` (Hash gespreizt mit h ^ (h >>> 16)).
    static func bucket(_ hash: Int32, capacity: Int) -> Int {
        let h = UInt32(bitPattern: hash)
        let spread = h ^ (h >> 16)
        return Int(spread) & (capacity - 1)
    }

    /// Kleinste Zweierpotenz ≥ n (wie HashMap.tableSizeFor).
    static func tableSize(for n: Int) -> Int {
        var size = 1
        while size < n { size <<= 1 }
        return max(size, 1)
    }
}
