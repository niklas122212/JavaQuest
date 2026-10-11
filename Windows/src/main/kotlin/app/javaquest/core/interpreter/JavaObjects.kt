package app.javaquest.core.interpreter

/**
 * Ein Objekt zur Laufzeit: Objekt einer eigenen Klasse, eine Sammlung aus der Bibliothek
 * (Liste, Map, Set, Deque), ein StringBuilder oder eine Exception. Objekte sind Referenzen –
 * zwei Variablen können auf dasselbe Objekt zeigen.
 */
class JavaObject(val kind: Kind, val className: String) {
    enum class Kind {
        /** Objekt einer eigenen Klasse (auch Enum-Konstante und Record). */
        PLAIN,
        LIST,
        MAP,
        SET,
        DEQUE,
        BUILDER,
        /** Eingebaute Exception (eigene Exceptions sind PLAIN mit einer Exception als Oberklasse). */
        THROWABLE,
        /** Ergebnis von `getClass()`. */
        CLASS_INFO,
        /** Ein Eintrag aus `map.entrySet()`. */
        ENTRY,
    }

    /** Reihenfolge beim Durchlaufen von Maps und Sets. */
    enum class Order {
        /** HashMap/HashSet: wie Java nach Hash-Fächern. */
        HASH,
        /** LinkedHashMap/LinkedHashSet und unveränderliche Sammlungen: Reihenfolge des Einfügens. */
        INSERTION,
        /** TreeMap/TreeSet: sortiert. */
        SORTED,
    }

    /** Felder eigener Objekte (Exceptions: `$message`). Die Reihenfolge der Deklaration steht in [fieldOrder]. */
    val fields = mutableMapOf<String, JValue>()
    val fieldTypes = mutableMapOf<String, JType>()
    val fieldOrder = mutableListOf<String>()
    /** Klasse, in der ein Feld deklariert ist – für private Zugriffe und final-Prüfung. */
    val fieldOwners = mutableMapOf<String, String>()
    val privateFields = mutableSetOf<String>()
    val finalFields = mutableSetOf<String>()
    /** Liste, Set, Deque – bei Maps die Schlüssel. */
    var elements = mutableListOf<JValue>()
    /** Werte einer Map (gleiche Stelle wie der Schlüssel in [elements]). */
    var values = mutableListOf<JValue>()
    /** Einfüge-Nummern für Javas HashMap-Reihenfolge. */
    var sequence = mutableListOf<Int>()
    var nextSequence = 0
    /** Größe der Hash-Tabelle (wächst wie in Java, schrumpft nie). */
    var capacity = 16
    var order = Order.INSERTION
    /** Text eines StringBuilders. */
    var text = ""
    /** `List.of`, `Map.of`, `Set.of`: jede Änderung wirft UnsupportedOperationException. */
    var isImmutable = false
    val serial: Int = nextSerial()

    /** Einfache Beschreibung für die Variablen-Anzeige – ohne eigene toString-Methoden aufzurufen. */
    val debugDescription: String
        get() = when (kind) {
            Kind.LIST, Kind.SET, Kind.DEQUE ->
                "[" + elements.take(10).joinToString(", ") { it.debugDisplay } + (if (elements.size > 10) ", …" else "") + "]"
            Kind.MAP -> {
                val pairs = elements.zip(values).take(8).map { (k, v) -> "${k.debugDisplay}=${v.debugDisplay}" }
                "{" + pairs.joinToString(", ") + (if (elements.size > 8) ", …" else "") + "}"
            }
            Kind.BUILDER -> "\"$text\""
            Kind.THROWABLE -> className + (fields["\$message"]?.stringValue?.let { ": $it" } ?: "")
            Kind.CLASS_INFO -> "class " + (fields["name"]?.stringValue ?: "")
            Kind.ENTRY -> "${elements.firstOrNull()?.debugDisplay ?: ""}=${values.firstOrNull()?.debugDisplay ?: ""}"
            Kind.PLAIN -> fields["\$name"]?.stringValue // Enum-Konstante
                ?: (className + "{" + fieldOrder.take(5).mapNotNull { name -> fields[name]?.let { "$name=${it.debugDisplay}" } }.joinToString(", ") +
                    (if (fieldOrder.size > 5) ", …" else "") + "}")
        }

    companion object {
        private var counter = 0x2a139a55
        @Synchronized private fun nextSerial(): Int {
            counter = (counter * 31 + 11) and 0x7fffffff
            return counter
        }
    }
}

/** Wissen über die eingebauten Klassen: Wer erbt von wem, in welchem Paket liegt sie. */
object JavaBuiltins {
    /** Oberklasse eingebauter Exceptions und Fehler. */
    val throwableParents: Map<String, String> = mapOf(
        "Throwable" to "Object",
        "Exception" to "Throwable", "Error" to "Throwable",
        "RuntimeException" to "Exception",
        "ArithmeticException" to "RuntimeException",
        "IndexOutOfBoundsException" to "RuntimeException",
        "ArrayIndexOutOfBoundsException" to "IndexOutOfBoundsException",
        "StringIndexOutOfBoundsException" to "IndexOutOfBoundsException",
        "NullPointerException" to "RuntimeException",
        "IllegalArgumentException" to "RuntimeException",
        "NumberFormatException" to "IllegalArgumentException",
        "IllegalFormatException" to "IllegalArgumentException",
        "UnknownFormatConversionException" to "IllegalFormatException",
        "MissingFormatArgumentException" to "IllegalFormatException",
        "IllegalFormatConversionException" to "IllegalFormatException",
        "PatternSyntaxException" to "IllegalArgumentException",
        "IllegalStateException" to "RuntimeException",
        "ClassCastException" to "RuntimeException",
        "UnsupportedOperationException" to "RuntimeException",
        "NegativeArraySizeException" to "RuntimeException",
        "ArrayStoreException" to "RuntimeException",
        "NoSuchElementException" to "RuntimeException",
        "InputMismatchException" to "NoSuchElementException",
        "ConcurrentModificationException" to "RuntimeException",
        "EmptyStackException" to "RuntimeException",
        "DateTimeException" to "RuntimeException",
        "UncheckedIOException" to "RuntimeException",
        "IOException" to "Exception",
        "FileNotFoundException" to "IOException",
        "InterruptedException" to "Exception",
        "CloneNotSupportedException" to "Exception",
        "StackOverflowError" to "Error",
        "OutOfMemoryError" to "Error",
        "AssertionError" to "Error",
    )

    private val packages = mapOf(
        "NoSuchElementException" to "java.util", "InputMismatchException" to "java.util",
        "ConcurrentModificationException" to "java.util", "EmptyStackException" to "java.util",
        "IOException" to "java.io", "FileNotFoundException" to "java.io", "UncheckedIOException" to "java.io",
        "DateTimeException" to "java.time",
    )

    /** Voller Name, wie ihn `toString()` und `getName()` zeigen (`java.lang.ArithmeticException`). */
    fun qualifiedName(className: String): String {
        packages[className]?.let { return "$it.$className" }
        if (className in throwableParents || className in setOf("Object", "String", "Integer", "Long", "Double", "Boolean", "Character", "StringBuilder")) {
            return "java.lang.$className"
        }
        if (className in setOf("ArrayList", "LinkedList", "HashMap", "TreeMap", "LinkedHashMap", "HashSet", "TreeSet", "LinkedHashSet", "ArrayDeque")) {
            return "java.util.$className"
        }
        return className
    }

    /** Bibliotheksklassen und ihre Obertypen (für Zuweisungen, instanceof und Casts). */
    val librarySupertypes: Map<String, Set<String>> = mapOf(
        "ArrayList" to setOf("List", "Collection", "Iterable", "Object", "AbstractList"),
        "LinkedList" to setOf("List", "Deque", "Queue", "Collection", "Iterable", "Object"),
        "ImmutableList" to setOf("List", "Collection", "Iterable", "Object"),
        "HashMap" to setOf("Map", "Object", "AbstractMap"),
        "LinkedHashMap" to setOf("Map", "HashMap", "Object"),
        "TreeMap" to setOf("Map", "SortedMap", "NavigableMap", "Object"),
        "ImmutableMap" to setOf("Map", "Object"),
        "HashSet" to setOf("Set", "Collection", "Iterable", "Object"),
        "LinkedHashSet" to setOf("Set", "HashSet", "Collection", "Iterable", "Object"),
        "TreeSet" to setOf("Set", "SortedSet", "NavigableSet", "Collection", "Iterable", "Object"),
        "ImmutableSet" to setOf("Set", "Collection", "Iterable", "Object"),
        "ArrayDeque" to setOf("Deque", "Queue", "Collection", "Iterable", "Object"),
        "Stack" to setOf("List", "Collection", "Iterable", "Object"),
        "StringBuilder" to setOf("CharSequence", "Object"),
        "Entry" to setOf("Map.Entry", "Object"),
    )

    /** Typen, die der Interpreter kennt, ohne dass sie im Programm stehen. */
    val knownTypes: Set<String> = throwableParents.keys + setOf(
        "Object", "Integer", "Long", "Double", "Boolean", "Character", "Number", "Comparable", "CharSequence",
        "List", "ArrayList", "LinkedList", "Collection", "Iterable", "Map", "HashMap", "TreeMap", "LinkedHashMap",
        "Map.Entry", "Entry", "Set", "HashSet", "TreeSet", "LinkedHashSet", "Deque", "ArrayDeque", "Queue", "Stack",
        "StringBuilder", "SortedMap", "SortedSet", "NavigableMap", "NavigableSet",
    )

    fun isThrowable(className: String): Boolean = className in throwableParents

    /** Ist [child] gleich [ancestor] oder eine (eingebaute) Unterklasse davon? */
    fun throwableIs(child: String, ancestor: String): Boolean {
        var current: String? = child
        while (current != null) {
            if (current == ancestor) return true
            current = throwableParents[current]
        }
        return ancestor == "Object"
    }
}

/** Javas Hash-Werte – nötig, damit HashMap und HashSet in derselben Reihenfolge ausgeben wie Java. */
object JavaHashing {
    /** Fach in der Hash-Tabelle wie in `java.util.HashMap` (Hash gespreizt mit h ^ (h >>> 16)). */
    fun bucket(hash: Int, capacity: Int): Int = (hash xor (hash ushr 16)) and (capacity - 1)

    /** Kleinste Zweierpotenz ≥ n (wie HashMap.tableSizeFor). */
    fun tableSize(n: Int): Int {
        var size = 1
        while (size < n) size = size shl 1
        return maxOf(size, 1)
    }
}
