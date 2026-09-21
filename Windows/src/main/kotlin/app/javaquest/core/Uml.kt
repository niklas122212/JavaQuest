package app.javaquest.core

/**
 * UML-Klassendiagramme, wie sie im Kurs gezeigt und abgefragt werden.
 * Gleiche Struktur wie in der Apple-Version – dieselbe Kursdatei speist beide.
 */
data class UmlDiagram(val classes: List<UmlBox>, val relations: List<UmlRelation>) {
    fun box(name: String) = classes.firstOrNull { it.name == name }
}

/** Sichtbarkeit wie in UML: + öffentlich, - privat, # geschützt. */
enum class UmlVisibility(val symbol: String, val meaning: String) {
    PUBLIC("+", "öffentlich – von überall nutzbar"),
    PRIVATE("-", "privat – nur innerhalb der Klasse"),
    PROTECTED("#", "geschützt – in der Klasse und in ihren Kind-Klassen");

    companion object {
        fun fromSymbol(symbol: String) = entries.firstOrNull { it.symbol == symbol } ?: PUBLIC
    }
}

/** Ein Feld oder eine Methode im Kasten. */
data class UmlMember(val visibility: UmlVisibility, val name: String, val type: String?) {
    /** Zeile wie im Diagramm: „- name: String“. */
    val line: String get() = if (type != null) "${visibility.symbol} $name: $type" else "${visibility.symbol} $name"
}

enum class UmlBoxKind(val stereotype: String?) {
    CLASS(null),
    INTERFACE("«interface»"),
    ABSTRACT("«abstract»"),
    RECORD("«record»");

    companion object {
        fun fromRaw(raw: String?) = when (raw) {
            "interfaceType" -> INTERFACE
            "abstractType" -> ABSTRACT
            "recordType" -> RECORD
            else -> CLASS
        }
    }
}

data class UmlBox(
    val name: String,
    val kind: UmlBoxKind = UmlBoxKind.CLASS,
    val fields: List<UmlMember> = emptyList(),
    val methods: List<UmlMember> = emptyList(),
)

enum class UmlRelationKind(val title: String, val meaning: String, val isDashed: Boolean) {
    EXTENDS(
        "Vererbung (extends)",
        "„ist ein“: Die Kind-Klasse erbt alles von der Eltern-Klasse. Pfeil mit leerer Dreiecksspitze zur Eltern-Klasse.",
        false,
    ),
    IMPLEMENTS(
        "Interface umsetzen (implements)",
        "Die Klasse unterschreibt einen Vertrag. Gestrichelte Linie mit leerer Dreiecksspitze zum Interface.",
        true,
    ),
    ASSOCIATION(
        "Assoziation",
        "„kennt“: Die eine Klasse benutzt die andere dauerhaft, z. B. als Feld.",
        false,
    ),
    AGGREGATION(
        "Aggregation",
        "„hat“, aber die Teile leben weiter: Eine Schulklasse hat Schüler – ohne die Klasse gibt es sie trotzdem. Leere Raute an der Ganzes-Seite.",
        false,
    ),
    COMPOSITION(
        "Komposition",
        "„besteht aus“: Ohne das Ganze gibt es die Teile nicht – ein Haus und seine Räume. Gefüllte Raute an der Ganzes-Seite.",
        false,
    ),
    DEPENDENCY(
        "Abhängigkeit",
        "„benutzt kurz“: Die Klasse braucht die andere nur vorübergehend, z. B. als Parameter. Gestrichelter Pfeil.",
        true,
    );

    companion object {
        fun fromRaw(raw: String) = when (raw) {
            "extendsRelation" -> EXTENDS
            "implementsRelation" -> IMPLEMENTS
            "aggregation" -> AGGREGATION
            "composition" -> COMPOSITION
            "dependency" -> DEPENDENCY
            else -> ASSOCIATION
        }

        /** Vielfachheit in Worten – damit „1..*“ niemanden ratlos zurücklässt. */
        fun meaningOfMultiplicity(value: String) = when (value) {
            "1" -> "genau eins"
            "0..1" -> "keins oder eins"
            "1..*" -> "mindestens eins"
            "*" -> "beliebig viele"
            else -> "so viele wie angegeben"
        }
    }
}

data class UmlRelation(
    val from: String,
    val to: String,
    val kind: UmlRelationKind,
    val label: String? = null,
    val multiplicity: String? = null,
)

/**
 * Rechnet aus, wo die Kästen liegen – dieselbe Anordnung wie in der Apple-Version:
 * Eltern-Klassen oben, Kinder darunter, Kästen einer Ebene nebeneinander.
 */
object UmlLayout {
    const val BOX_WIDTH = 220.0
    const val HEADER_HEIGHT = 38.0
    const val ROW_HEIGHT = 22.0
    const val SECTION_PADDING = 8.0
    const val DIVIDER_HEIGHT = 1.0
    const val HORIZONTAL_GAP = 40.0
    const val VERTICAL_GAP = 70.0

    data class Placed(val box: UmlBox, val x: Double, val y: Double, val width: Double, val height: Double) {
        val centerX: Double get() = x + width / 2
        val bottom: Double get() = y + height
    }

    data class Result(val boxes: List<Placed>, val width: Double, val height: Double) {
        fun placed(name: String) = boxes.firstOrNull { it.box.name == name }
    }

    /**
     * Höhe eines Kastens: Kopf, zwei Trennlinien und beide Fächer mit eigenem Polster.
     * Leere Fächer behalten eine Zeile Höhe, damit der Kasten seine drei Teile zeigt.
     */
    fun height(box: UmlBox): Double {
        fun section(count: Int) = maxOf(count, 1) * ROW_HEIGHT + SECTION_PADDING * 2
        return HEADER_HEIGHT + DIVIDER_HEIGHT * 2 + section(box.fields.size) + section(box.methods.size)
    }

    fun levels(diagram: UmlDiagram): Map<String, Int> {
        val level = diagram.classes.associate { it.name to 0 }.toMutableMap()
        repeat(maxOf(diagram.classes.size, 1)) {
            for (relation in diagram.relations) {
                if (relation.kind != UmlRelationKind.EXTENDS && relation.kind != UmlRelationKind.IMPLEMENTS) continue
                val parent = level[relation.to] ?: 0
                if ((level[relation.from] ?: 0) <= parent) level[relation.from] = parent + 1
            }
        }
        return level
    }

    fun compute(diagram: UmlDiagram): Result {
        val levelOf = levels(diagram)
        val grouped = diagram.classes.groupBy { levelOf[it.name] ?: 0 }
        val placed = mutableListOf<Placed>()
        var y = 0.0
        var maxWidth = 0.0

        for (level in grouped.keys.sorted()) {
            val row = grouped[level].orEmpty()
            val rowWidth = row.size * BOX_WIDTH + maxOf(row.size - 1, 0) * HORIZONTAL_GAP
            maxWidth = maxOf(maxWidth, rowWidth)
            var x = 0.0
            var rowHeight = 0.0
            for (box in row) {
                val boxHeight = height(box)
                placed += Placed(box, x, y, BOX_WIDTH, boxHeight)
                x += BOX_WIDTH + HORIZONTAL_GAP
                rowHeight = maxOf(rowHeight, boxHeight)
            }
            y += rowHeight + VERTICAL_GAP
        }

        // Zeilen mittig ausrichten, damit das Bild ruhig wirkt.
        val centered = placed.map { item ->
            val row = placed.filter { it.y == item.y }
            val rowWidth = (row.maxOf { it.x + it.width }) - (row.minOf { it.x })
            item.copy(x = item.x + (maxWidth - rowWidth) / 2)
        }
        return Result(centered, maxWidth, maxOf(y - VERTICAL_GAP, 0.0))
    }
}
