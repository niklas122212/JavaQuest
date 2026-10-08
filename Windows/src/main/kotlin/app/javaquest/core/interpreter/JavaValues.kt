package app.javaquest.core.interpreter

import java.math.BigDecimal
import java.math.RoundingMode
import java.util.Locale

/** Ein String-Objekt. Gleiche Literale teilen sich ein Objekt (String-Pool), berechnete Texte sind neue Objekte. */
class JavaString(val text: String)

/** Arrays sind in Java Referenzen: Zwei Variablen können auf denselben „Eierkarton“ zeigen. */
class JavaArray(val elementType: JType, val elements: MutableList<JValue>) {
    val serial: Int = nextSerial()

    val identityString: String
        get() {
            val code = when (elementType) {
                JType.IntT -> "[I"
                JType.LongT -> "[J"
                JType.DoubleT -> "[D"
                JType.BooleanT -> "[Z"
                JType.CharT -> "[C"
                JType.StringT -> "[Ljava.lang.String;"
                else -> "[Ljava.lang.Object;"
            }
            return code + "@" + Integer.toHexString(serial)
        }

    companion object {
        private var counter = 0x1b6d3586
        @Synchronized private fun nextSerial(): Int {
            counter = (counter * 31 + 7) and 0x7fffffff
            return counter
        }
    }
}

/** Ein Laufzeitwert. Ganzzahlen haben Javas feste Breite und laufen wie in Java über. */
sealed interface JValue {
    data class IntV(val value: Int) : JValue
    data class LongV(val value: Long) : JValue
    data class DoubleV(val value: Double) : JValue
    data class BoolV(val value: Boolean) : JValue
    data class CharV(val value: Char) : JValue
    class StrV(val ref: JavaString) : JValue
    class ArrV(val array: JavaArray) : JValue
    data object Null : JValue
    data object Void : JValue

    val type: JType
        get() = when (this) {
            is IntV -> JType.IntT
            is LongV -> JType.LongT
            is DoubleV -> JType.DoubleT
            is BoolV -> JType.BooleanT
            is CharV -> JType.CharT
            is StrV -> JType.StringT
            is ArrV -> JType.Arr(array.elementType)
            Null -> JType.Unknown("null")
            Void -> JType.VoidT
        }

    val typeName: String get() = if (this == Null) "null" else type.toString()

    /** Text wie bei System.out.println bzw. String-Verkettung. */
    val javaString: String
        get() = when (this) {
            is IntV -> value.toString()
            is LongV -> value.toString()
            // Die JVM formatiert Kommazahlen von sich aus exakt wie Java.
            is DoubleV -> value.toString()
            is BoolV -> value.toString()
            is CharV -> value.toString()
            is StrV -> ref.text
            is ArrV -> array.identityString
            Null -> "null"
            Void -> ""
        }

    /** Darstellung für die Variablen-Anzeige. */
    val debugDisplay: String
        get() = when (this) {
            is StrV -> "\"${ref.text}\""
            is CharV -> "'$value'"
            is ArrV -> "{" + array.elements.take(12).joinToString(", ") { it.debugDisplay } + (if (array.elements.size > 12) ", …" else "") + "}"
            else -> javaString
        }

    val stringValue: String? get() = (this as? StrV)?.ref?.text

    companion object {
        fun str(text: String): JValue = StrV(JavaString(text))

        fun defaultValue(type: JType): JValue = when (type) {
            JType.IntT -> IntV(0)
            JType.LongT -> LongV(0)
            JType.DoubleT -> DoubleV(0.0)
            JType.BooleanT -> BoolV(false)
            JType.CharT -> CharV('\u0000')
            else -> Null
        }
    }
}

/** Javas numerische Typanpassung: char/int → int, dann long, dann double. */
sealed interface Num {
    data class I(val v: Int) : Num
    data class L(val v: Long) : Num
    data class D(val v: Double) : Num

    val value: JValue
        get() = when (this) {
            is I -> JValue.IntV(v)
            is L -> JValue.LongV(v)
            is D -> JValue.DoubleV(v)
        }

    val isDouble: Boolean get() = this is D
    val isNaN: Boolean get() = this is D && v.isNaN()
    val isZeroIntegral: Boolean get() = (this is I && v == 0) || (this is L && v == 0L)
    val toDouble: Double get() = when (this) { is I -> v.toDouble(); is L -> v.toDouble(); is D -> v }
    val toLong: Long get() = when (this) { is I -> v.toLong(); is L -> v; is D -> v.toLong() }  // Kotlin/JVM: wie Javas (long)-Cast
    val toInt: Int get() = when (this) { is I -> v; is L -> v.toInt(); is D -> v.toInt() }       // NaN → 0, sättigt wie Java

    companion object {
        fun of(value: JValue): Num? = when (value) {
            is JValue.IntV -> I(value.value)
            is JValue.CharV -> I(value.value.code)
            is JValue.LongV -> L(value.value)
            is JValue.DoubleV -> D(value.value)
            else -> null
        }

        fun promote(a: Num, b: Num): Pair<Num, Num> = when {
            a is D || b is D -> D(a.toDouble) to D(b.toDouble)
            a is L || b is L -> L(a.toLong) to L(b.toLong)
            else -> a to b
        }

        fun compare(a: Num, b: Num): Int = when (val p = promote(a, b)) {
            else -> when (val x = p.first) {
                is I -> x.v.compareTo((p.second as I).v)
                is L -> x.v.compareTo((p.second as L).v)
                is D -> {
                    val y = (p.second as D).v
                    if (x.v < y) -1 else if (x.v > y) 1 else if (x.v == y) 0 else -1
                }
            }
        }

        fun apply(op: String, a: Num, b: Num): Num {
            val (x, y) = promote(a, b)
            return when (x) {
                is I -> {
                    val q = (y as I).v
                    I(when (op) { "+" -> x.v + q; "-" -> x.v - q; "*" -> x.v * q; "/" -> x.v / q; else -> x.v % q })
                }
                is L -> {
                    val q = (y as L).v
                    L(when (op) { "+" -> x.v + q; "-" -> x.v - q; "*" -> x.v * q; "/" -> x.v / q; else -> x.v % q })
                }
                is D -> {
                    val q = (y as D).v
                    D(when (op) { "+" -> x.v + q; "-" -> x.v - q; "*" -> x.v * q; "/" -> x.v / q; else -> x.v % q })
                }
            }
        }

        fun bitwise(op: String, a: Num, b: Num): Num {
            if (op == "<<" || op == ">>" || op == ">>>") {
                // Bei Shifts bestimmt nur der linke Operand den Typ.
                val n = b.toLong.toInt()
                return when (a) {
                    is I -> I(when (op) { "<<" -> a.v shl n; ">>" -> a.v shr n; else -> a.v ushr n })
                    else -> {
                        val x = a.toLong
                        L(when (op) { "<<" -> x shl n; ">>" -> x shr n; else -> x ushr n })
                    }
                }
            }
            val (x, y) = promote(a, b)
            return if (x is I) {
                val q = (y as I).v
                I(when (op) { "&" -> x.v and q; "|" -> x.v or q; else -> x.v xor q })
            } else {
                val p = x.toLong; val q = y.toLong
                L(when (op) { "&" -> p and q; "|" -> p or q; else -> p xor q })
            }
        }
    }
}

object JavaFormat {
    /** String.format/printf – mit Punkt als Dezimaltrenner (wie in den Kursbeispielen). */
    fun format(pattern: String, args: List<JValue>, line: Int): String {
        val javaArgs = args.map<JValue, Any?> { arg ->
            when (arg) {
                is JValue.IntV -> arg.value
                is JValue.LongV -> arg.value
                is JValue.DoubleV -> arg.value
                is JValue.BoolV -> arg.value
                is JValue.CharV -> arg.value
                is JValue.StrV -> arg.ref.text
                is JValue.ArrV -> arg.array.identityString
                JValue.Null -> null
                JValue.Void -> throw JavaProblem.syntax("Ein Argument gibt nichts zurück (void).", line)
            }
        }.toTypedArray()
        return try {
            String.format(Locale.US, pattern, *javaArgs)
        } catch (e: java.util.IllegalFormatException) {
            throw JavaProblem.runtime("${e.javaClass.simpleName}: Das Format „$pattern“ passt nicht zu den Werten.", line)
        }
    }

    fun fixed(value: Double, precision: Int): String = BigDecimal(value.toString()).setScale(precision, RoundingMode.HALF_UP).toPlainString()
}
