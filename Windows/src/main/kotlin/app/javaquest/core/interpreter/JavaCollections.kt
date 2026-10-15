package app.javaquest.core.interpreter

/** Bibliotheksklassen mit Objekten: Listen, Maps, Sets, Warteschlangen, StringBuilder und Exceptions. */
internal object JavaCollections {
    private fun arity(args: List<JValue>, count: Int, name: String, line: Int) {
        if (args.size != count) throw JavaProblem.syntax("$name erwartet $count Wert(e) in den Klammern, bekommt aber ${args.size}.", line)
    }

    // MARK: - Objekte erzeugen

    fun construct(className: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        when (className) {
            "ArrayList", "LinkedList", "Stack" -> {
                val list = JavaObject(JavaObject.Kind.LIST, className)
                val first = args.singleOrNull()
                when {
                    first is JValue.Obj -> list.elements = elements(first, "new $className(…)", line, interpreter).toMutableList()
                    first != null && Num.of(first) != null -> {
                        if (first is JValue.IntV && first.value < 0) {
                            throw JavaProblem.exception("IllegalArgumentException", "Illegal Capacity: ${first.value}", "Eine Liste kann nicht ${first.value} Plätze haben.", line)
                        }
                    }
                    args.isNotEmpty() -> throw JavaProblem.syntax("new $className(…) nimmt nichts, eine Startgröße oder eine andere Sammlung.", line)
                }
                return JValue.Obj(list)
            }
            "ArrayDeque" -> {
                val deque = JavaObject(JavaObject.Kind.DEQUE, className)
                val first = args.singleOrNull()
                if (first is JValue.Obj) deque.elements = elements(first, "new ArrayDeque(…)", line, interpreter).toMutableList()
                return JValue.Obj(deque)
            }
            "HashMap", "LinkedHashMap", "TreeMap" -> {
                val map = JavaObject(JavaObject.Kind.MAP, className)
                map.order = when (className) {
                    "HashMap" -> JavaObject.Order.HASH
                    "TreeMap" -> JavaObject.Order.SORTED
                    else -> JavaObject.Order.INSERTION
                }
                val first = args.singleOrNull()
                if (first is JValue.Obj && first.obj.kind == JavaObject.Kind.MAP) {
                    // Wie HashMap(Map): Tabellengröße passend zur Anzahl der Einträge.
                    map.capacity = maxOf(JavaHashing.tableSize((first.obj.elements.size.toFloat() / 0.75f + 1).toInt()), 1)
                    for ((key, value) in interpreter.mapEntries(first.obj)) mapPut(map, key, value, line, interpreter)
                } else if (first is JValue.IntV) {
                    map.capacity = JavaHashing.tableSize(maxOf(first.value, 1))
                }
                return JValue.Obj(map)
            }
            "HashSet", "LinkedHashSet", "TreeSet" -> {
                val set = JavaObject(JavaObject.Kind.SET, className)
                set.order = when (className) {
                    "HashSet" -> JavaObject.Order.HASH
                    "TreeSet" -> JavaObject.Order.SORTED
                    else -> JavaObject.Order.INSERTION
                }
                val first = args.singleOrNull()
                if (first is JValue.Obj) {
                    val items = elements(first, "new $className(…)", line, interpreter)
                    // Wie HashSet(Collection): mindestens 16 Fächer.
                    set.capacity = JavaHashing.tableSize(maxOf((items.size.toFloat() / 0.75f).toInt() + 1, 16))
                    for (item in items) setAdd(set, item, line, interpreter)
                } else if (first is JValue.IntV) {
                    set.capacity = JavaHashing.tableSize(maxOf(first.value, 1))
                }
                return JValue.Obj(set)
            }
            "StringBuilder", "StringBuffer" -> {
                val builder = JavaObject(JavaObject.Kind.BUILDER, "StringBuilder")
                val first = args.firstOrNull()
                if (first != null && Num.of(first) == null) builder.text = interpreter.stringify(first, line)
                return JValue.Obj(builder)
            }
            "Object" -> return JValue.Obj(JavaObject(JavaObject.Kind.PLAIN, "Object"))
            "Integer", "Long", "Double", "Boolean", "Character" -> {
                if (args.size != 1) throw JavaProblem.syntax("new $className(…) braucht genau einen Wert.", line)
                return JavaLibrary.callStatic(className, "valueOf", args, line, interpreter)
            }
        }
        if (JavaBuiltins.isThrowable(className)) {
            val exception = JavaObject(JavaObject.Kind.THROWABLE, className)
            exception.fields["\$message"] = JValue.Null
            exception.fields["\$cause"] = JValue.Null
            when (args.size) {
                0 -> Unit
                1 -> {
                    val arg = args[0]
                    if (arg is JValue.Obj && (arg.obj.kind == JavaObject.Kind.THROWABLE || interpreter.isThrowableClass(arg.obj.className))) {
                        exception.fields["\$cause"] = arg
                        exception.fields["\$message"] = JValue.str(interpreter.stringify(arg, line))
                    } else {
                        exception.fields["\$message"] = interpreter.coerce(arg, JType.StringT, line, "Die Meldung der Exception")
                    }
                }
                2 -> {
                    exception.fields["\$message"] = interpreter.coerce(args[0], JType.StringT, line, "Die Meldung der Exception")
                    exception.fields["\$cause"] = args[1]
                }
                else -> throw JavaProblem.syntax("$className hat keinen Konstruktor mit ${args.size} Werten.", line)
            }
            return JValue.Obj(exception)
        }
        throw JavaProblem.unsupported("Objekte mit new $className(…) kennt der eingebaute Interpreter nicht.", line)
    }

    /** Elemente einer Sammlung (oder eines Arrays) in Javas Reihenfolge. */
    fun elements(value: JValue, label: String, line: Int, interpreter: JavaInterpreter): List<JValue> = when {
        value is JValue.Obj && value.obj.kind in setOf(JavaObject.Kind.LIST, JavaObject.Kind.SET, JavaObject.Kind.DEQUE) -> interpreter.iterationOrder(value.obj)
        value is JValue.ArrV -> value.array.elements.toList()
        value == JValue.Null -> throw JavaProblem.exception("NullPointerException", null, "$label bekommt null statt einer Sammlung.", line)
        else -> throw JavaProblem.syntax("$label erwartet eine Sammlung (Liste, Set …), bekommt aber ${value.typeName}.", line)
    }

    // MARK: - Statische Methoden für Sammlungen

    fun collectionStatic(className: String, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue? {
        when {
            className == "List" && (name == "of" || name == "copyOf") -> {
                val list = JavaObject(JavaObject.Kind.LIST, "ImmutableList")
                list.isImmutable = true
                list.elements = if (name == "copyOf" || (args.size == 1 && args[0] is JValue.ArrV)) {
                    elements(args[0], "List.$name", line, interpreter).toMutableList()
                } else {
                    args.toMutableList()
                }
                if (list.elements.any { it == JValue.Null }) {
                    throw JavaProblem.exception("NullPointerException", null, "List.of verbietet null als Eintrag.", line)
                }
                return JValue.Obj(list)
            }
            className == "Set" && (name == "of" || name == "copyOf") -> {
                val set = JavaObject(JavaObject.Kind.SET, "ImmutableSet")
                val items = if (name == "copyOf") elements(args[0], "Set.copyOf", line, interpreter) else args
                for (item in items) {
                    if (interpreter.indexOfKey(item, set, line) != null) {
                        if (name == "copyOf") continue
                        val shown = interpreter.stringify(item, line)
                        throw JavaProblem.exception("IllegalArgumentException", "duplicate element: $shown", "Set.of verbietet doppelte Einträge: $shown.", line)
                    }
                    set.elements.add(item)
                    set.sequence.add(set.sequence.size)
                }
                set.isImmutable = true
                return JValue.Obj(set)
            }
            className == "Map" && name == "of" -> {
                if (args.size % 2 != 0) throw JavaProblem.syntax("Map.of braucht Paare aus Schlüssel und Wert.", line)
                val map = JavaObject(JavaObject.Kind.MAP, "ImmutableMap")
                for (index in args.indices step 2) {
                    if (interpreter.indexOfKey(args[index], map, line) != null) {
                        throw JavaProblem.exception("IllegalArgumentException", "duplicate key: ${interpreter.stringify(args[index], line)}",
                            "Map.of verbietet doppelte Schlüssel.", line)
                    }
                    map.elements.add(args[index])
                    map.values.add(args[index + 1])
                    map.sequence.add(map.sequence.size)
                }
                map.isImmutable = true
                return JValue.Obj(map)
            }
            className == "Map" && name == "entry" -> {
                arity(args, 2, "Map.entry", line)
                val entry = JavaObject(JavaObject.Kind.ENTRY, "Entry")
                entry.elements = mutableListOf(args[0])
                entry.values = mutableListOf(args[1])
                return JValue.Obj(entry)
            }
            className == "Arrays" && name == "asList" -> {
                val list = JavaObject(JavaObject.Kind.LIST, "ArrayList")
                val first = args.singleOrNull()
                list.elements = if (first is JValue.ArrV) first.array.elements.toMutableList() else args.toMutableList()
                return JValue.Obj(list)
            }
            className == "Collections" -> return collections(name, args, line, interpreter)
            className == "Objects" -> return objects(name, args, line, interpreter)
        }
        return null
    }

    private fun listArg(value: JValue, label: String, line: Int): JavaObject {
        if (value is JValue.Obj && value.obj.kind == JavaObject.Kind.LIST) return value.obj
        if (value == JValue.Null) throw JavaProblem.exception("NullPointerException", null, "$label bekommt null statt einer Liste.", line)
        throw JavaProblem.syntax("$label erwartet eine Liste, bekommt aber ${value.typeName}.", line)
    }

    private fun collections(name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue = when (name) {
        "sort" -> {
            if (args.size != 1) throw JavaProblem.unsupported("Collections.sort mit Comparator (Lambda) kennt der eingebaute Interpreter nicht.", line)
            val list = listArg(args[0], "Collections.sort", line)
            checkMutable(list, "sort", line)
            list.elements = sorted(list.elements, line, interpreter).toMutableList()
            JValue.Void
        }
        "reverse" -> {
            val list = listArg(args.firstOrNull() ?: JValue.Null, "Collections.reverse", line)
            checkMutable(list, "reverse", line)
            list.elements.reverse()
            JValue.Void
        }
        "max", "min" -> {
            if (args.size != 1) throw JavaProblem.unsupported("Collections.$name mit Comparator kennt der eingebaute Interpreter nicht.", line)
            val items = elements(args[0], "Collections.$name", line, interpreter)
            var best = items.firstOrNull()
                ?: throw JavaProblem.exception("NoSuchElementException", null, "Collections.$name einer leeren Sammlung gibt es nicht.", line)
            for (item in items.drop(1)) {
                val order = interpreter.javaCompare(item, best, line)
                if ((name == "max" && order > 0) || (name == "min" && order < 0)) best = item
            }
            best
        }
        "frequency" -> {
            arity(args, 2, "Collections.frequency", line)
            val items = elements(args[0], "Collections.frequency", line, interpreter)
            JValue.IntV(items.count { interpreter.javaEquals(it, args[1], line) })
        }
        "swap" -> {
            arity(args, 3, "Collections.swap", line)
            val list = listArg(args[0], "Collections.swap", line)
            val i = checkedIndex(args[1], list.elements.size, line)
            val j = checkedIndex(args[2], list.elements.size, line)
            val tmp = list.elements[i]
            list.elements[i] = list.elements[j]
            list.elements[j] = tmp
            JValue.Void
        }
        "unmodifiableList", "emptyList" -> {
            val list = JavaObject(JavaObject.Kind.LIST, "ImmutableList")
            list.isImmutable = true
            args.firstOrNull()?.let { list.elements = elements(it, "Collections.$name", line, interpreter).toMutableList() }
            JValue.Obj(list)
        }
        else -> throw JavaProblem.unsupported("Collections.$name kennt der eingebaute Interpreter nicht.", line)
    }

    private fun objects(name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue = when (name) {
        "equals" -> {
            arity(args, 2, "Objects.equals", line)
            JValue.BoolV(interpreter.javaEquals(args[0], args[1], line))
        }
        "hash" -> {
            var hash = 1
            for (arg in args) hash = hash * 31 + interpreter.javaHash(arg, line)
            JValue.IntV(hash)
        }
        "hashCode" -> {
            arity(args, 1, "Objects.hashCode", line)
            JValue.IntV(interpreter.javaHash(args[0], line))
        }
        "isNull", "nonNull" -> {
            arity(args, 1, "Objects.$name", line)
            val isNull = args[0] == JValue.Null
            JValue.BoolV(if (name == "isNull") isNull else !isNull)
        }
        "requireNonNull" -> {
            if ((args.firstOrNull() ?: JValue.Null) == JValue.Null) {
                val message = args.getOrNull(1)?.stringValue
                throw JavaProblem.exception("NullPointerException", message, message ?: "Objects.requireNonNull: Der Wert ist null.", line)
            }
            args[0]
        }
        "toString" -> JValue.str(interpreter.stringify(args.firstOrNull() ?: JValue.Null, line))
        else -> throw JavaProblem.unsupported("Objects.$name kennt der eingebaute Interpreter nicht.", line)
    }

    fun sorted(items: List<JValue>, line: Int, interpreter: JavaInterpreter): List<JValue> {
        // Stabiles Sortieren durch Einfügen – Fehler beim Vergleichen werden wie in Java gemeldet.
        val result = mutableListOf<JValue>()
        for (item in items) {
            var index = result.size
            while (index > 0 && interpreter.javaCompare(result[index - 1], item, line) > 0) index--
            result.add(index, item)
        }
        return result
    }

    // MARK: - Zahlen als Objekte (Integer, Double …)

    /** Methoden von Integer, Long, Double, Character und Boolean – z. B. `zahl.equals(5)` bei `Integer zahl`. */
    fun boxedMethod(value: JValue, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue? {
        if (value !is JValue.IntV && value !is JValue.LongV && value !is JValue.DoubleV && value !is JValue.CharV && value !is JValue.BoolV) return null
        return when {
            name == "equals" && args.size == 1 -> {
                val other = args[0]
                JValue.BoolV(
                    when {
                        value is JValue.IntV && other is JValue.IntV -> value.value == other.value
                        value is JValue.LongV && other is JValue.LongV -> value.value == other.value
                        value is JValue.DoubleV && other is JValue.DoubleV ->
                            value.value.toRawBits() == other.value.toRawBits() || (value.value.isNaN() && other.value.isNaN())
                        value is JValue.CharV && other is JValue.CharV -> value.value == other.value
                        value is JValue.BoolV && other is JValue.BoolV -> value.value == other.value
                        else -> false
                    },
                )
            }
            name == "compareTo" && args.size == 1 -> {
                // Character.compareTo liefert den Abstand der Zeichen, die anderen nur -1, 0 oder 1.
                val other = args[0]
                if (value is JValue.CharV && other is JValue.CharV) JValue.IntV(value.value.code - other.value.code)
                else JValue.IntV(interpreter.javaCompare(value, other, line))
            }
            name == "hashCode" && args.isEmpty() -> JValue.IntV(interpreter.javaHash(value, line))
            name == "toString" && args.isEmpty() -> JValue.str(value.javaString)
            (name == "intValue" || name == "longValue" || name == "doubleValue") && args.isEmpty() -> {
                val number = Num.of(value) ?: return null
                when (name) {
                    "intValue" -> JValue.IntV(if (number.isDouble) number.toDouble.toInt() else number.toLong.toInt())
                    "longValue" -> JValue.LongV(number.toLong)
                    else -> JValue.DoubleV(number.toDouble)
                }
            }
            name == "charValue" && args.isEmpty() -> if (value is JValue.CharV) value else null
            name == "booleanValue" && args.isEmpty() -> if (value is JValue.BoolV) value else null
            name == "isNaN" && args.isEmpty() -> if (value is JValue.DoubleV) JValue.BoolV(value.value.isNaN()) else null
            name == "isInfinite" && args.isEmpty() -> if (value is JValue.DoubleV) JValue.BoolV(value.value.isInfinite()) else null
            else -> null
        }
    }

    // MARK: - Methoden an Objekten

    fun callObject(obj: JavaObject, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        // Was jedes Objekt kann
        when {
            name == "toString" && args.isEmpty() -> return JValue.str(interpreter.stringify(JValue.Obj(obj), line))
            name == "equals" && args.size == 1 -> return JValue.BoolV(interpreter.javaEquals(JValue.Obj(obj), args[0], line))
            name == "hashCode" && args.isEmpty() -> return JValue.IntV(interpreter.javaHash(JValue.Obj(obj), line))
            name == "getClass" && args.isEmpty() -> {
                val info = JavaObject(JavaObject.Kind.CLASS_INFO, "Class")
                info.fields["name"] = JValue.str(JavaBuiltins.qualifiedName(obj.className))
                info.fields["simpleName"] = JValue.str(obj.className)
                return JValue.Obj(info)
            }
        }
        when (obj.kind) {
            JavaObject.Kind.LIST -> return listMethod(obj, name, args, line, interpreter)
            JavaObject.Kind.MAP -> return mapMethod(obj, name, args, line, interpreter)
            JavaObject.Kind.SET -> return setMethod(obj, name, args, line, interpreter)
            JavaObject.Kind.DEQUE -> return dequeMethod(obj, name, args, line, interpreter)
            JavaObject.Kind.BUILDER -> return builderMethod(obj, name, args, line, interpreter)
            JavaObject.Kind.THROWABLE -> when {
                (name == "getMessage" || name == "getLocalizedMessage") && args.isEmpty() -> return obj.fields["\$message"] ?: JValue.Null
                name == "getCause" && args.isEmpty() -> return obj.fields["\$cause"] ?: JValue.Null
                name == "printStackTrace" && args.isEmpty() -> return JValue.Void
            }
            JavaObject.Kind.CLASS_INFO -> when (name) {
                "getSimpleName" -> return obj.fields["simpleName"] ?: JValue.Null
                "getName" -> return obj.fields["name"] ?: JValue.Null
            }
            JavaObject.Kind.ENTRY -> when {
                name == "getKey" && args.isEmpty() -> return obj.elements.firstOrNull() ?: JValue.Null
                name == "getValue" && args.isEmpty() -> return obj.values.firstOrNull() ?: JValue.Null
                name == "setValue" && args.size == 1 -> {
                    val old = obj.values.firstOrNull() ?: JValue.Null
                    obj.values = mutableListOf(args[0])
                    val map = (obj.fields["\$map"] as? JValue.Obj)?.obj
                    val key = obj.elements.firstOrNull()
                    if (map != null && key != null) interpreter.indexOfKey(key, map, line)?.let { map.values[it] = args[0] }
                    return old
                }
            }
            JavaObject.Kind.PLAIN -> Unit
        }
        return callObjectFallback(obj, name, args, line)
    }

    private fun displayName(obj: JavaObject): String = when (obj.className) {
        "ImmutableList" -> "Die Liste"
        "ImmutableSet" -> "Das Set"
        "ImmutableMap" -> "Die Map"
        else -> obj.className
    }

    private fun checkMutable(obj: JavaObject, name: String, line: Int) {
        if (obj.isImmutable) {
            throw JavaProblem.exception("UnsupportedOperationException", null,
                "$name(…) geht hier nicht – die Sammlung ist unveränderlich (z. B. aus List.of, Set.of oder Map.of).", line)
        }
    }

    private fun checkedIndex(value: JValue, count: Int, line: Int, allowEnd: Boolean = false): Int {
        val index = (value as? JValue.IntV)?.value ?: throw JavaProblem.syntax("Der Index muss eine ganze Zahl (int) sein.", line)
        if (index < 0 || !(index < count || (allowEnd && index == count))) {
            throw JavaProblem.exception("IndexOutOfBoundsException", "Index $index out of bounds for length $count",
                "Index $index gibt es nicht – die Liste hat ${if (count == 0) "keine Einträge" else "nur die Plätze 0 bis ${count - 1}"}.", line)
        }
        return index
    }

    private fun noSuchElement(label: String, line: Int) =
        JavaProblem.exception("NoSuchElementException", null, "$label – die Sammlung ist leer.", line)

    private fun callObjectFallback(obj: JavaObject, name: String, args: List<JValue>, line: Int): Nothing {
        if (name in setOf("forEach", "stream", "removeIf", "replaceAll", "iterator", "listIterator", "toArray", "computeIfAbsent", "merge", "compute", "spliterator")) {
            throw JavaProblem.unsupported("$name(…) kennt der eingebaute Interpreter nicht.", line)
        }
        throw JavaProblem.syntax("${displayName(obj)} hat keine Methode $name(…) mit ${args.size} Wert(en).", line)
    }

    // MARK: Liste

    private fun listMethod(list: JavaObject, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        val items = list.elements
        when (args.size) {
            0 -> when (name) {
                "size" -> return JValue.IntV(items.size)
                "isEmpty" -> return JValue.BoolV(items.isEmpty())
                "removeFirst", "removeLast", "pop" -> {
                    checkMutable(list, name, line)
                    if (items.isEmpty()) {
                        if (list.className == "Stack") throw JavaProblem.exception("EmptyStackException", null, "pop() auf einem leeren Stapel.", line)
                        throw noSuchElement("$name()", line)
                    }
                    val fromEnd = name == "removeLast" || (name == "pop" && list.className == "Stack")
                    return if (fromEnd) items.removeAt(items.lastIndex) else items.removeAt(0)
                }
                "getFirst", "getLast", "peek", "element", "peekFirst", "peekLast" -> {
                    if (items.isEmpty()) {
                        if (name.startsWith("peek")) return JValue.Null
                        throw noSuchElement("$name()", line)
                    }
                    val fromEnd = name == "getLast" || name == "peekLast" || (name == "peek" && list.className == "Stack")
                    return if (fromEnd) items.last() else items.first()
                }
                "poll", "pollFirst" -> {
                    checkMutable(list, name, line)
                    return if (items.isEmpty()) JValue.Null else items.removeAt(0)
                }
                "clear" -> {
                    checkMutable(list, name, line)
                    items.clear()
                    return JValue.Void
                }
                "reversed" -> {
                    val copy = JavaObject(JavaObject.Kind.LIST, list.className)
                    copy.elements = items.reversed().toMutableList()
                    return JValue.Obj(copy)
                }
            }
            1 -> when (name) {
                "get" -> return items[checkedIndex(args[0], items.size, line)]
                "add", "addLast" -> {
                    checkMutable(list, name, line)
                    items.add(args[0])
                    return if (name == "add") JValue.BoolV(true) else JValue.Void
                }
                "push" -> {
                    if (list.className == "Stack") {
                        // Beim Stack liegt das oberste Element hinten, bei der LinkedList vorne.
                        items.add(args[0])
                        return args[0]
                    }
                    checkMutable(list, name, line)
                    items.add(0, args[0])
                    return JValue.Void
                }
                "addFirst" -> {
                    checkMutable(list, name, line)
                    items.add(0, args[0])
                    return JValue.Void
                }
                "addAll" -> {
                    checkMutable(list, name, line)
                    val added = elements(args[0], "addAll", line, interpreter)
                    items.addAll(added)
                    return JValue.BoolV(added.isNotEmpty())
                }
                "remove", "\$removeValue" -> {
                    checkMutable(list, "remove", line)
                    // Wie in Java: Bei einer ganzen Zahl (int) wird die Stelle entfernt, sonst das Objekt.
                    if (name == "remove" && args[0] is JValue.IntV) return items.removeAt(checkedIndex(args[0], items.size, line))
                    val index = interpreter.indexOfKey(args[0], list, line) ?: return JValue.BoolV(false)
                    items.removeAt(index)
                    return JValue.BoolV(true)
                }
                "offer" -> {
                    checkMutable(list, name, line)
                    items.add(args[0])
                    return JValue.BoolV(true)
                }
                "contains" -> return JValue.BoolV(interpreter.indexOfKey(args[0], list, line) != null)
                "indexOf" -> return JValue.IntV(interpreter.indexOfKey(args[0], list, line) ?: -1)
                "lastIndexOf" -> {
                    for (index in items.indices.reversed()) if (interpreter.javaEquals(items[index], args[0], line)) return JValue.IntV(index)
                    return JValue.IntV(-1)
                }
                "sort" -> {
                    if (args[0] != JValue.Null) {
                        throw JavaProblem.unsupported("sort mit Comparator (Lambda) kennt der eingebaute Interpreter nicht – nimm sort(null) oder Collections.sort.", line)
                    }
                    checkMutable(list, name, line)
                    list.elements = sorted(items, line, interpreter).toMutableList()
                    return JValue.Void
                }
                "containsAll" -> {
                    for (item in elements(args[0], "containsAll", line, interpreter)) {
                        if (interpreter.indexOfKey(item, list, line) == null) return JValue.BoolV(false)
                    }
                    return JValue.BoolV(true)
                }
            }
            2 -> when (name) {
                "add" -> {
                    checkMutable(list, name, line)
                    items.add(checkedIndex(args[0], items.size, line, allowEnd = true), args[1])
                    return JValue.Void
                }
                "set" -> {
                    checkMutable(list, name, line)
                    val index = checkedIndex(args[0], items.size, line)
                    val old = items[index]
                    items[index] = args[1]
                    return old
                }
                "subList" -> {
                    val from = checkedIndex(args[0], items.size, line, allowEnd = true)
                    val to = checkedIndex(args[1], items.size, line, allowEnd = true)
                    if (from > to) {
                        throw JavaProblem.exception("IllegalArgumentException", "fromIndex($from) > toIndex($to)", "subList: Anfang $from liegt hinter dem Ende $to.", line)
                    }
                    val part = JavaObject(JavaObject.Kind.LIST, "ArrayList")
                    part.elements = items.subList(from, to).toMutableList()
                    return JValue.Obj(part)
                }
            }
        }
        callObjectFallback(list, name, args, line)
    }

    // MARK: Map

    /** Schlüssel eintragen oder ersetzen; gibt den alten Wert zurück (oder null). */
    fun mapPut(map: JavaObject, key: JValue, value: JValue, line: Int, interpreter: JavaInterpreter): JValue {
        if (map.order == JavaObject.Order.SORTED) {
            // TreeMap: gleich ist, was compareTo für gleich hält.
            if (key == JValue.Null) throw JavaProblem.exception("NullPointerException", null, "Eine TreeMap verbietet null als Schlüssel.", line)
            var low = 0
            var high = map.elements.size
            while (low < high) {
                val mid = (low + high) / 2
                val order = interpreter.javaCompare(map.elements[mid], key, line)
                if (order == 0) {
                    val old = map.values[mid]
                    map.values[mid] = value
                    return old
                }
                if (order < 0) low = mid + 1 else high = mid
            }
            map.elements.add(low, key)
            map.values.add(low, value)
            map.sequence.add(low, map.nextSequence)
            map.nextSequence++
            return JValue.Null
        }
        interpreter.indexOfKey(key, map, line)?.let { index ->
            val old = map.values[index]
            map.values[index] = value
            return old
        }
        map.elements.add(key)
        map.values.add(value)
        map.sequence.add(map.nextSequence)
        map.nextSequence++
        // Wie HashMap: Bei mehr als 3/4 Füllung verdoppelt sich die Tabelle.
        while (map.elements.size > map.capacity * 3 / 4) map.capacity *= 2
        return JValue.Null
    }

    private fun mapMethod(map: JavaObject, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        when (args.size) {
            0 -> when (name) {
                "size" -> return JValue.IntV(map.elements.size)
                "isEmpty" -> return JValue.BoolV(map.elements.isEmpty())
                "clear" -> {
                    checkMutable(map, name, line)
                    map.elements.clear()
                    map.values.clear()
                    map.sequence.clear()
                    return JValue.Void
                }
                "keySet" -> {
                    val keys = JavaObject(JavaObject.Kind.SET, "LinkedHashSet")
                    keys.elements = interpreter.iterationOrder(map).toMutableList()
                    keys.sequence = keys.elements.indices.toMutableList()
                    return JValue.Obj(keys)
                }
                "values" -> {
                    val values = JavaObject(JavaObject.Kind.LIST, "ArrayList")
                    values.elements = interpreter.mapEntries(map).map { it.second }.toMutableList()
                    return JValue.Obj(values)
                }
                "entrySet" -> {
                    val entries = JavaObject(JavaObject.Kind.SET, "LinkedHashSet")
                    for ((key, value) in interpreter.mapEntries(map)) {
                        val entry = JavaObject(JavaObject.Kind.ENTRY, "Entry")
                        entry.elements = mutableListOf(key)
                        entry.values = mutableListOf(value)
                        entry.fields["\$map"] = JValue.Obj(map)
                        entries.elements.add(JValue.Obj(entry))
                    }
                    entries.sequence = entries.elements.indices.toMutableList()
                    return JValue.Obj(entries)
                }
                "firstKey", "lastKey" -> if (map.order == JavaObject.Order.SORTED) {
                    if (map.elements.isEmpty()) throw noSuchElement("$name()", line)
                    return if (name == "firstKey") map.elements.first() else map.elements.last()
                }
            }
            1 -> when (name) {
                "get" -> return interpreter.indexOfKey(args[0], map, line)?.let { map.values[it] } ?: JValue.Null
                "containsKey" -> return JValue.BoolV(interpreter.indexOfKey(args[0], map, line) != null)
                "containsValue" -> return JValue.BoolV(map.values.any { interpreter.javaEquals(it, args[0], line) })
                "remove" -> {
                    checkMutable(map, name, line)
                    val index = interpreter.indexOfKey(args[0], map, line) ?: return JValue.Null
                    map.elements.removeAt(index)
                    map.sequence.removeAt(index)
                    return map.values.removeAt(index)
                }
            }
            2 -> when (name) {
                "put" -> {
                    checkMutable(map, name, line)
                    return mapPut(map, args[0], args[1], line, interpreter)
                }
                "putIfAbsent" -> {
                    checkMutable(map, name, line)
                    val index = interpreter.indexOfKey(args[0], map, line)
                    if (index != null && map.values[index] != JValue.Null) return map.values[index]
                    return mapPut(map, args[0], args[1], line, interpreter)
                }
                "getOrDefault" -> return interpreter.indexOfKey(args[0], map, line)?.let { map.values[it] } ?: args[1]
                "replace" -> {
                    checkMutable(map, name, line)
                    val index = interpreter.indexOfKey(args[0], map, line) ?: return JValue.Null
                    val old = map.values[index]
                    map.values[index] = args[1]
                    return old
                }
            }
        }
        callObjectFallback(map, name, args, line)
    }

    // MARK: Set

    /** Element einfügen; false, wenn es schon da ist. */
    fun setAdd(set: JavaObject, item: JValue, line: Int, interpreter: JavaInterpreter): Boolean {
        if (set.order == JavaObject.Order.SORTED) {
            var low = 0
            var high = set.elements.size
            while (low < high) {
                val mid = (low + high) / 2
                val order = interpreter.javaCompare(set.elements[mid], item, line)
                if (order == 0) return false
                if (order < 0) low = mid + 1 else high = mid
            }
            set.elements.add(low, item)
            set.sequence.add(low, set.nextSequence)
            set.nextSequence++
            return true
        }
        if (interpreter.indexOfKey(item, set, line) != null) return false
        set.elements.add(item)
        set.sequence.add(set.nextSequence)
        set.nextSequence++
        while (set.elements.size > set.capacity * 3 / 4) set.capacity *= 2
        return true
    }

    private fun setMethod(set: JavaObject, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        when (args.size) {
            0 -> when (name) {
                "size" -> return JValue.IntV(set.elements.size)
                "isEmpty" -> return JValue.BoolV(set.elements.isEmpty())
                "clear" -> {
                    checkMutable(set, name, line)
                    set.elements.clear()
                    set.sequence.clear()
                    return JValue.Void
                }
                "first", "last" -> if (set.order == JavaObject.Order.SORTED) {
                    if (set.elements.isEmpty()) throw noSuchElement("$name()", line)
                    return if (name == "first") set.elements.first() else set.elements.last()
                }
            }
            1 -> when (name) {
                "add" -> {
                    checkMutable(set, name, line)
                    return JValue.BoolV(setAdd(set, args[0], line, interpreter))
                }
                "addAll" -> {
                    checkMutable(set, name, line)
                    var changed = false
                    for (item in elements(args[0], "addAll", line, interpreter)) if (setAdd(set, item, line, interpreter)) changed = true
                    return JValue.BoolV(changed)
                }
                "remove" -> {
                    checkMutable(set, name, line)
                    val index = interpreter.indexOfKey(args[0], set, line) ?: return JValue.BoolV(false)
                    set.elements.removeAt(index)
                    set.sequence.removeAt(index)
                    return JValue.BoolV(true)
                }
                "removeAll", "retainAll" -> {
                    checkMutable(set, name, line)
                    val other = elements(args[0], name, line, interpreter)
                    val kept = mutableListOf<JValue>()
                    val keptSequence = mutableListOf<Int>()
                    for ((item, sequence) in set.elements.zip(set.sequence)) {
                        val inOther = other.any { interpreter.javaEquals(it, item, line) }
                        if (inOther == (name == "retainAll")) {
                            kept.add(item)
                            keptSequence.add(sequence)
                        }
                    }
                    val changed = kept.size != set.elements.size
                    set.elements = kept
                    set.sequence = keptSequence
                    return JValue.BoolV(changed)
                }
                "contains" -> return JValue.BoolV(interpreter.indexOfKey(args[0], set, line) != null)
                "containsAll" -> {
                    for (item in elements(args[0], "containsAll", line, interpreter)) {
                        if (interpreter.indexOfKey(item, set, line) == null) return JValue.BoolV(false)
                    }
                    return JValue.BoolV(true)
                }
            }
        }
        callObjectFallback(set, name, args, line)
    }

    // MARK: Deque / Queue (ArrayDeque)

    private fun dequeMethod(deque: JavaObject, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        val items = deque.elements
        when (args.size) {
            0 -> when (name) {
                "pop", "removeFirst", "remove", "element", "getFirst" -> {
                    if (items.isEmpty()) throw noSuchElement("$name()", line)
                    return if (name == "element" || name == "getFirst") items.first() else items.removeAt(0)
                }
                "removeLast", "getLast" -> {
                    if (items.isEmpty()) throw noSuchElement("$name()", line)
                    return if (name == "getLast") items.last() else items.removeAt(items.lastIndex)
                }
                "poll", "pollFirst" -> return if (items.isEmpty()) JValue.Null else items.removeAt(0)
                "pollLast" -> return if (items.isEmpty()) JValue.Null else items.removeAt(items.lastIndex)
                "peek", "peekFirst" -> return items.firstOrNull() ?: JValue.Null
                "peekLast" -> return items.lastOrNull() ?: JValue.Null
                "size" -> return JValue.IntV(items.size)
                "isEmpty" -> return JValue.BoolV(items.isEmpty())
                "clear" -> {
                    items.clear()
                    return JValue.Void
                }
            }
            1 -> when (name) {
                "push", "addFirst", "offerFirst" -> {
                    if (args[0] == JValue.Null) throw JavaProblem.exception("NullPointerException", null, "ArrayDeque verbietet null.", line)
                    items.add(0, args[0])
                    return if (name == "offerFirst") JValue.BoolV(true) else JValue.Void
                }
                "add", "addLast", "offer", "offerLast" -> {
                    if (args[0] == JValue.Null) throw JavaProblem.exception("NullPointerException", null, "ArrayDeque verbietet null.", line)
                    items.add(args[0])
                    return if (name == "addLast") JValue.Void else JValue.BoolV(true)
                }
                "contains" -> return JValue.BoolV(interpreter.indexOfKey(args[0], deque, line) != null)
                "remove" -> {
                    val index = interpreter.indexOfKey(args[0], deque, line) ?: return JValue.BoolV(false)
                    items.removeAt(index)
                    return JValue.BoolV(true)
                }
            }
        }
        callObjectFallback(deque, name, args, line)
    }

    // MARK: StringBuilder

    private fun builderMethod(builder: JavaObject, name: String, args: List<JValue>, line: Int, interpreter: JavaInterpreter): JValue {
        val text = StringBuilder(builder.text)
        fun index(value: JValue, allowEnd: Boolean = true): Int {
            val i = (value as? JValue.IntV)?.value ?: throw JavaProblem.syntax("Die Stelle muss eine ganze Zahl (int) sein.", line)
            if (i < 0 || !(i < text.length || (allowEnd && i == text.length))) {
                throw JavaProblem.exception("StringIndexOutOfBoundsException", "index $i,length ${text.length}",
                    "Stelle $i gibt es nicht – der Text hat ${text.length} Zeichen.", line)
            }
            return i
        }
        fun done(): JValue {
            builder.text = text.toString()
            return JValue.Obj(builder)
        }
        when {
            name == "append" && args.size == 1 -> {
                val arg = args[0]
                if (arg is JValue.ArrV && arg.array.elementType == JType.CharT) {
                    text.append(arg.array.elements.joinToString("") { it.javaString })
                } else {
                    text.append(interpreter.stringify(arg, line))
                }
                return done()
            }
            name == "insert" && args.size == 2 -> {
                text.insert(index(args[0]), interpreter.stringify(args[1], line))
                return done()
            }
            name == "reverse" && args.isEmpty() -> {
                // Wie Java: Ersatzpaare (Emoji) bleiben zusammen.
                text.reverse()
                return done()
            }
            name == "toString" && args.isEmpty() -> return JValue.str(builder.text)
            name == "length" && args.isEmpty() -> return JValue.IntV(text.length)
            name == "isEmpty" && args.isEmpty() -> return JValue.BoolV(text.isEmpty())
            name == "charAt" && args.size == 1 -> return JValue.CharV(text[index(args[0], allowEnd = false)])
            name == "setCharAt" && args.size == 2 -> {
                val at = index(args[0], allowEnd = false)
                val c = (args[1] as? JValue.CharV)?.value ?: throw JavaProblem.syntax("setCharAt braucht ein Zeichen (char).", line)
                text.setCharAt(at, c)
                builder.text = text.toString()
                return JValue.Void
            }
            name == "deleteCharAt" && args.size == 1 -> {
                text.deleteCharAt(index(args[0], allowEnd = false))
                return done()
            }
            (name == "delete" && args.size == 2) || (name == "replace" && args.size == 3) -> {
                val start = index(args[0])
                val rawEnd = (args[1] as? JValue.IntV)?.value ?: throw JavaProblem.syntax("Das Ende muss eine ganze Zahl sein.", line)
                val end = minOf(rawEnd, text.length)
                if (start > end) {
                    throw JavaProblem.exception("StringIndexOutOfBoundsException", "start $start, end $end, length ${text.length}",
                        "Der Anfang $start liegt hinter dem Ende $end.", line)
                }
                text.replace(start, end, if (name == "replace") interpreter.stringify(args[2], line) else "")
                return done()
            }
            name == "indexOf" && args.size == 1 -> {
                val needle = args[0].stringValue ?: throw JavaProblem.syntax("indexOf erwartet einen Text.", line)
                return JavaLibrary.callInstance(JValue.str(builder.text), "indexOf", listOf(JValue.str(needle)), line, interpreter)
            }
            name == "setLength" && args.size == 1 -> {
                val length = (args[0] as? JValue.IntV)?.value?.takeIf { it >= 0 }
                    ?: throw JavaProblem.syntax("setLength braucht eine Länge ≥ 0.", line)
                text.setLength(length)
                builder.text = text.toString()
                return JValue.Void
            }
        }
        callObjectFallback(builder, name, args, line)
    }
}
