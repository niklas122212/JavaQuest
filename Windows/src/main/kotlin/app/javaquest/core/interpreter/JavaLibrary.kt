package app.javaquest.core.interpreter

/** Die Teile der Java-Standardbibliothek, die Anfänger-Programme typischerweise brauchen. */
internal object JavaLibrary {
    private fun arity(args: List<JValue>, count: Int, name: String, line: Int) {
        if (args.size != count) throw JavaProblem.syntax("$name erwartet $count Wert(e) in den Klammern, bekommt aber ${args.size}.", line)
    }

    private fun number(value: JValue, name: String, line: Int): Num =
        Num.of(value) ?: throw JavaProblem.syntax("$name rechnet nur mit Zahlen, nicht mit ${value.typeName}.", line)

    private fun intArg(value: JValue, name: String, line: Int): Int =
        (Num.of(value) as? Num.I)?.v ?: throw JavaProblem.syntax("$name erwartet hier eine ganze Zahl (int), bekommt aber ${value.typeName}.", line)

    private fun stringArg(value: JValue, name: String, line: Int): String = when (value) {
        is JValue.StrV -> value.ref.text
        JValue.Null -> throw JavaProblem.runtime("NullPointerException: $name bekommt null statt eines Textes.", line)
        else -> throw JavaProblem.syntax("$name erwartet einen Text (String), bekommt aber ${value.typeName}.", line)
    }

    // MARK: Statische Methoden

    fun callStatic(className: String, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue = when (className) {
        "Math" -> math(name, args, line, interpreter)
        "Integer", "Long", "Double", "Boolean" -> wrapper(className, name, args, line)
        "String" -> stringStatic(name, args, line)
        "Character" -> character(name, args, line)
        "Arrays" -> arrays(name, args, line, interpreter)
        "System" -> throw JavaProblem.unsupported("System.$name kennt der eingebaute Interpreter nicht.", line)
        else -> if (className.first().isUpperCase()) throw JavaProblem.unsupported("Die Klasse $className kennt der eingebaute Interpreter nicht.", line)
        else throw JavaProblem.syntax("„$className“ kennt Java hier nicht. Ist die Variable deklariert und richtig geschrieben?", line)
    }

    private fun math(name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        val label = "Math.$name"
        fun d(i: Int) = number(args[i], label, line).toDouble
        return when (name) {
            "random" -> { arity(args, 0, label, line); JValue.DoubleV(interpreter.nextRandom()) }
            "abs" -> {
                arity(args, 1, label, line)
                when (val n = number(args[0], label, line)) {
                    is Num.I -> JValue.IntV(Math.abs(n.v))
                    is Num.L -> JValue.LongV(Math.abs(n.v))
                    is Num.D -> JValue.DoubleV(Math.abs(n.v))
                }
            }
            "max", "min" -> {
                arity(args, 2, label, line)
                val (a, b) = Num.promote(number(args[0], label, line), number(args[1], label, line))
                if (a.isNaN || b.isNaN) return JValue.DoubleV(Double.NaN)
                val order = Num.compare(a, b)
                (if (name == "max") (if (order >= 0) a else b) else (if (order <= 0) a else b)).value
            }
            "pow" -> { arity(args, 2, label, line); JValue.DoubleV(Math.pow(d(0), d(1))) }
            "round" -> { arity(args, 1, label, line); JValue.LongV(Math.round(d(0))) }
            "floorDiv", "floorMod" -> {
                arity(args, 2, label, line)
                val (a, b) = Num.promote(number(args[0], label, line), number(args[1], label, line))
                if (a.isDouble) throw JavaProblem.syntax("$label rechnet nur mit ganzen Zahlen.", line)
                if (b.isZeroIntegral) throw JavaProblem.runtime("ArithmeticException: / by zero", line)
                if (a is Num.I) {
                    val divisor = (b as Num.I).v
                    JValue.IntV(if (name == "floorDiv") Math.floorDiv(a.v, divisor) else Math.floorMod(a.v, divisor))
                }
                else JValue.LongV(if (name == "floorDiv") Math.floorDiv(a.toLong, b.toLong) else Math.floorMod(a.toLong, b.toLong))
            }
            "hypot" -> { arity(args, 2, label, line); JValue.DoubleV(Math.hypot(d(0), d(1))) }
            else -> {
                val unary: Map<String, (Double) -> Double> = mapOf(
                    "sqrt" to Math::sqrt, "cbrt" to Math::cbrt, "floor" to Math::floor, "ceil" to Math::ceil,
                    "log" to Math::log, "log10" to Math::log10, "exp" to Math::exp, "sin" to Math::sin, "cos" to Math::cos,
                    "tan" to Math::tan, "toRadians" to Math::toRadians, "toDegrees" to Math::toDegrees, "signum" to Math::signum,
                )
                val function = unary[name] ?: throw JavaProblem.unsupported("$label kennt der eingebaute Interpreter nicht.", line)
                arity(args, 1, label, line)
                JValue.DoubleV(function(d(0)))
            }
        }
    }

    private fun wrapper(className: String, name: String, args: List<JValue>, line: Int): JValue {
        val label = "$className.$name"
        return when {
            className == "Integer" && (name == "parseInt" || name == "valueOf") -> {
                arity(args, 1, label, line)
                val text = args[0].stringValue
                if (text == null) {
                    if (name == "parseInt") stringArg(args[0], label, line)
                    JValue.IntV(intArg(args[0], label, line))
                } else {
                    JValue.IntV(text.toIntOrNull() ?: throw JavaProblem.runtime("NumberFormatException: For input string: \"$text\" – das ist keine ganze Zahl.", line))
                }
            }
            className == "Long" && (name == "parseLong" || name == "valueOf") -> {
                arity(args, 1, label, line)
                val text = stringArg(args[0], label, line)
                JValue.LongV(text.toLongOrNull() ?: throw JavaProblem.runtime("NumberFormatException: For input string: \"$text\"", line))
            }
            className == "Double" && (name == "parseDouble" || name == "valueOf") -> {
                arity(args, 1, label, line)
                Num.of(args[0])?.let { return JValue.DoubleV(it.toDouble) }
                val text = stringArg(args[0], label, line).trim()
                JValue.DoubleV(text.toDoubleOrNull() ?: throw JavaProblem.runtime("NumberFormatException: For input string: \"$text\" – das ist keine Zahl (Kommazahlen mit Punkt schreiben).", line))
            }
            className == "Boolean" && name == "parseBoolean" -> {
                arity(args, 1, label, line)
                JValue.BoolV(args[0].stringValue?.lowercase() == "true")
            }
            name == "toString" -> { arity(args, 1, label, line); JValue.str(args[0].javaString) }
            className == "Integer" && name == "toBinaryString" -> { arity(args, 1, label, line); JValue.str(Integer.toBinaryString(intArg(args[0], label, line))) }
            name == "compare" -> {
                arity(args, 2, label, line)
                JValue.IntV(Num.compare(number(args[0], label, line), number(args[1], label, line)).coerceIn(-1, 1))
            }
            className == "Integer" && name == "sum" -> { arity(args, 2, label, line); JValue.IntV(intArg(args[0], label, line) + intArg(args[1], label, line)) }
            className == "Integer" && (name == "max" || name == "min") -> {
                arity(args, 2, label, line)
                val a = intArg(args[0], label, line); val b = intArg(args[1], label, line)
                JValue.IntV(if (name == "max") maxOf(a, b) else minOf(a, b))
            }
            else -> throw JavaProblem.unsupported("$label kennt der eingebaute Interpreter nicht.", line)
        }
    }

    private fun stringStatic(name: String, args: List<JValue>, line: Int): JValue = when (name) {
        "valueOf" -> {
            arity(args, 1, "String.valueOf", line)
            val arg = args[0]
            if (arg is JValue.ArrV && arg.array.elementType == JType.CharT) JValue.str(arg.array.elements.joinToString("") { it.javaString })
            else JValue.str(arg.javaString)
        }
        "format" -> {
            val pattern = args.firstOrNull()?.stringValue ?: throw JavaProblem.syntax("String.format braucht als Erstes einen Format-Text.", line)
            JValue.str(JavaFormat.format(pattern, args.drop(1), line))
        }
        "join" -> {
            if (args.size < 2) throw JavaProblem.syntax("String.join braucht ein Trennzeichen und Texte.", line)
            val separator = stringArg(args[0], "String.join", line)
            val second = args[1]
            val parts = if (args.size == 2 && second is JValue.ArrV) second.array.elements.map { it.javaString }
            else args.drop(1).map { stringArg(it, "String.join", line) }
            JValue.str(parts.joinToString(separator))
        }
        else -> throw JavaProblem.unsupported("String.$name kennt der eingebaute Interpreter nicht.", line)
    }

    private fun character(name: String, args: List<JValue>, line: Int): JValue {
        val label = "Character.$name"
        arity(args, 1, label, line)
        val c = (args[0] as? JValue.CharV)?.value ?: throw JavaProblem.syntax("$label erwartet ein Zeichen (char), bekommt aber ${args[0].typeName}.", line)
        return when (name) {
            "isDigit" -> JValue.BoolV(Character.isDigit(c))
            "isLetter" -> JValue.BoolV(Character.isLetter(c))
            "isLetterOrDigit" -> JValue.BoolV(Character.isLetterOrDigit(c))
            "isUpperCase" -> JValue.BoolV(Character.isUpperCase(c))
            "isLowerCase" -> JValue.BoolV(Character.isLowerCase(c))
            "isWhitespace" -> JValue.BoolV(Character.isWhitespace(c))
            "toUpperCase" -> JValue.CharV(Character.toUpperCase(c))
            "toLowerCase" -> JValue.CharV(Character.toLowerCase(c))
            "getNumericValue" -> JValue.IntV(Character.getNumericValue(c))
            "toString", "valueOf" -> JValue.str(c.toString())
            else -> throw JavaProblem.unsupported("$label kennt der eingebaute Interpreter nicht.", line)
        }
    }

    private fun arrays(name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        val label = "Arrays.$name"
        val array = (args.firstOrNull() as? JValue.ArrV)?.array ?: if (args.firstOrNull() == JValue.Null) {
            throw JavaProblem.runtime("NullPointerException: $label bekommt null statt eines Arrays.", line)
        } else {
            throw JavaProblem.syntax("$label erwartet ein Array.", line)
        }
        return when (name) {
            "toString" -> { arity(args, 1, label, line); JValue.str("[" + array.elements.joinToString(", ") { it.javaString } + "]") }
            "sort" -> {
                arity(args, 1, label, line)
                when (array.elementType) {
                    JType.StringT -> array.elements.sortWith { a, b -> a.javaString.compareTo(b.javaString) }
                    JType.BooleanT -> throw JavaProblem.syntax("Ein boolean-Array kann man nicht sortieren.", line)
                    else -> array.elements.sortWith { a, b -> Num.compare(Num.of(a)!!, Num.of(b)!!) }
                }
                JValue.Void
            }
            "fill" -> {
                arity(args, 2, label, line)
                val value = interpreter.coerce(args[1], array.elementType, line, label)
                for (i in array.elements.indices) array.elements[i] = value
                JValue.Void
            }
            "copyOf" -> {
                arity(args, 2, label, line)
                val length = intArg(args[1], label, line)
                if (length < 0) throw JavaProblem.runtime("NegativeArraySizeException: $length", line)
                JValue.ArrV(JavaArray(array.elementType, MutableList(length) { array.elements.getOrElse(it) { JValue.defaultValue(array.elementType) } }))
            }
            "equals" -> {
                arity(args, 2, label, line)
                val other = (args[1] as? JValue.ArrV)?.array ?: return JValue.BoolV(false)
                JValue.BoolV(array.elements.map { it.javaString } == other.elements.map { it.javaString })
            }
            else -> throw JavaProblem.unsupported("$label kennt der eingebaute Interpreter nicht.", line)
        }
    }

    // MARK: Methoden auf Werten

    fun callInstance(receiver: JValue, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue = when (receiver) {
        is JValue.StrV -> stringMethod(receiver.ref.text, name, args, line)
        is JValue.ArrV -> when (name) {
            "clone" -> { arity(args, 0, "clone", line); JValue.ArrV(JavaArray(receiver.array.elementType, receiver.array.elements.toMutableList())) }
            "length" -> throw JavaProblem.syntax("Bei Arrays ist length ein Feld ohne Klammern: zahlen.length.", line)
            else -> throw JavaProblem.syntax("Arrays haben keine Methode $name(). Für Hilfsfunktionen gibt es Arrays.$name(…).", line)
        }
        JValue.Null -> throw JavaProblem.runtime("NullPointerException: Der Wert ist null – auf null kann man keine Methode $name() aufrufen.", line)
        JValue.Void -> throw JavaProblem.syntax("Die Methode davor gibt nichts zurück (void) – darauf kann man nicht .$name() aufrufen.", line)
        else -> throw JavaProblem.syntax("${receiver.typeName} ist ein einfacher Wert und hat keine Methoden wie $name().", line)
    }

    private fun pattern(regex: String, line: Int): java.util.regex.Pattern = try {
        java.util.regex.Pattern.compile(regex)
    } catch (e: java.util.regex.PatternSyntaxException) {
        throw JavaProblem.runtime("PatternSyntaxException: „$regex“ ist kein gültiger regulärer Ausdruck.", line)
    }

    private fun stringMethod(text: String, name: String, args: List<JValue>, line: Int): JValue {
        fun index(i: Int) = intArg(args[i], name, line)
        fun needle(i: Int): String = (args[i] as? JValue.CharV)?.value?.toString() ?: stringArg(args[i], name, line)
        return when (name) {
            "length" -> { arity(args, 0, "length()", line); JValue.IntV(text.length) }
            "charAt" -> {
                arity(args, 1, "charAt", line)
                val i = index(0)
                if (i < 0 || i >= text.length) {
                    throw JavaProblem.runtime("StringIndexOutOfBoundsException: Index $i gibt es nicht – \"$text\" hat nur die Positionen 0 bis ${text.length - 1}.", line)
                }
                JValue.CharV(text[i])
            }
            "substring" -> {
                if (args.size !in 1..2) throw JavaProblem.syntax("substring erwartet 1 oder 2 Zahlen.", line)
                val begin = index(0)
                val end = if (args.size == 2) index(1) else text.length
                if (begin < 0 || end > text.length || begin > end) {
                    throw JavaProblem.runtime("StringIndexOutOfBoundsException: begin $begin, end $end, length ${text.length} – der Bereich passt nicht in den Text.", line)
                }
                JValue.str(text.substring(begin, end))
            }
            "indexOf" -> {
                if (args.size !in 1..2) throw JavaProblem.syntax("indexOf erwartet 1 oder 2 Werte.", line)
                JValue.IntV(if (args.size == 2) text.indexOf(needle(0), index(1)) else text.indexOf(needle(0)))
            }
            "lastIndexOf" -> {
                if (args.size !in 1..2) throw JavaProblem.syntax("lastIndexOf erwartet 1 oder 2 Werte.", line)
                JValue.IntV(if (args.size == 2) text.lastIndexOf(needle(0), index(1)) else text.lastIndexOf(needle(0)))
            }
            "contains" -> { arity(args, 1, name, line); JValue.BoolV(needle(0) in text) }
            "equals" -> { arity(args, 1, name, line); JValue.BoolV(args[0].stringValue == text) }
            "equalsIgnoreCase" -> { arity(args, 1, name, line); JValue.BoolV(args[0].stringValue?.equals(text, ignoreCase = true) == true) }
            "compareTo" -> { arity(args, 1, name, line); JValue.IntV(text.compareTo(stringArg(args[0], name, line))) }
            "compareToIgnoreCase" -> { arity(args, 1, name, line); JValue.IntV(text.compareTo(stringArg(args[0], name, line), ignoreCase = true)) }
            "toUpperCase" -> { arity(args, 0, name, line); JValue.str(text.uppercase()) }
            "toLowerCase" -> { arity(args, 0, name, line); JValue.str(text.lowercase()) }
            "trim" -> { arity(args, 0, name, line); JValue.str(text.trim { it <= ' ' }) }
            "strip" -> { arity(args, 0, name, line); JValue.str(text.trim()) }
            "isEmpty" -> { arity(args, 0, name, line); JValue.BoolV(text.isEmpty()) }
            "isBlank" -> { arity(args, 0, name, line); JValue.BoolV(text.isBlank()) }
            "startsWith" -> { arity(args, 1, name, line); JValue.BoolV(text.startsWith(stringArg(args[0], name, line))) }
            "endsWith" -> { arity(args, 1, name, line); JValue.BoolV(text.endsWith(stringArg(args[0], name, line))) }
            "replace" -> { arity(args, 2, name, line); JValue.str(text.replace(needle(0), needle(1))) }
            "replaceAll" -> {
                arity(args, 2, name, line)
                JValue.str(pattern(stringArg(args[0], name, line), line).matcher(text).replaceAll(stringArg(args[1], name, line)))
            }
            "matches" -> { arity(args, 1, name, line); JValue.BoolV(pattern(stringArg(args[0], name, line), line).matcher(text).matches()) }
            "split" -> {
                arity(args, 1, name, line)
                // Java-Semantik direkt von der JVM: Regex, leere Elemente am Ende entfallen.
                val parts = pattern(stringArg(args[0], name, line), line).split(text)
                JValue.ArrV(JavaArray(JType.StringT, parts.map { JValue.str(it) }.toMutableList()))
            }
            "repeat" -> {
                arity(args, 1, name, line)
                val count = index(0)
                if (count < 0) throw JavaProblem.runtime("IllegalArgumentException: count is negative: $count", line)
                JValue.str(text.repeat(count))
            }
            "concat" -> { arity(args, 1, name, line); JValue.str(text + stringArg(args[0], name, line)) }
            "toCharArray" -> { arity(args, 0, name, line); JValue.ArrV(JavaArray(JType.CharT, text.map { JValue.CharV(it) }.toMutableList())) }
            "hashCode" -> { arity(args, 0, name, line); JValue.IntV(text.hashCode()) }
            else -> throw JavaProblem.unsupported("Die String-Methode $name() kennt der eingebaute Interpreter nicht.", line)
        }
    }
}
