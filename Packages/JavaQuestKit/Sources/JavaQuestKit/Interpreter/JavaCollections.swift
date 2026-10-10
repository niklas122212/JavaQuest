import Foundation

/// Bibliotheksklassen mit Objekten: Listen, Maps, Sets, Warteschlangen, StringBuilder und Exceptions.
extension JavaLibrary {
    // MARK: - Objekte erzeugen

    static func construct(_ className: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch className {
        case "ArrayList", "LinkedList", "Stack":
            let list = JavaObject(kind: .list, className: className)
            if args.count == 1, case .object = args[0] {
                list.elements = try elements(of: args[0], "new \(className)(…)", line: line, interpreter: interpreter)
            } else if args.count == 1, Numeric(args[0]) != nil {
                if case .int(let capacity) = args[0], capacity < 0 {
                    throw .exception("IllegalArgumentException", javaMessage: "Illegal Capacity: \(capacity)", explanation: "Eine Liste kann nicht \(capacity) Plätze haben.", line: line)
                }
            } else if !args.isEmpty {
                throw .syntax("new \(className)(…) nimmt nichts, eine Startgröße oder eine andere Sammlung.", line: line)
            }
            return .object(list)
        case "ArrayDeque":
            let deque = JavaObject(kind: .deque, className: className)
            if args.count == 1, case .object = args[0] {
                deque.elements = try elements(of: args[0], "new ArrayDeque(…)", line: line, interpreter: interpreter)
            }
            return .object(deque)
        case "HashMap", "LinkedHashMap", "TreeMap":
            let map = JavaObject(kind: .map, className: className)
            map.order = className == "HashMap" ? .hash : (className == "TreeMap" ? .sorted : .insertion)
            if args.count == 1, case .object(let source) = args[0], source.kind == .map {
                // Wie HashMap(Map): Tabellengröße passend zur Anzahl der Einträge.
                map.capacity = max(JavaHashing.tableSize(for: Int(Float(source.elements.count) / 0.75 + 1)), 1)
                for (key, value) in try interpreter.mapEntries(source) {
                    _ = try mapPut(map, key, value, line: line, interpreter: interpreter)
                }
            } else if args.count == 1, case .int(let capacity) = args[0] {
                map.capacity = JavaHashing.tableSize(for: max(Int(capacity), 1))
            }
            return .object(map)
        case "HashSet", "LinkedHashSet", "TreeSet":
            let set = JavaObject(kind: .set, className: className)
            set.order = className == "HashSet" ? .hash : (className == "TreeSet" ? .sorted : .insertion)
            if args.count == 1, case .object = args[0] {
                let items = try elements(of: args[0], "new \(className)(…)", line: line, interpreter: interpreter)
                // Wie HashSet(Collection): mindestens 16 Fächer.
                set.capacity = JavaHashing.tableSize(for: max(Int(Float(items.count) / 0.75) + 1, 16))
                for item in items { _ = try setAdd(set, item, line: line, interpreter: interpreter) }
            } else if args.count == 1, case .int(let capacity) = args[0] {
                set.capacity = JavaHashing.tableSize(for: max(Int(capacity), 1))
            }
            return .object(set)
        case "StringBuilder", "StringBuffer":
            let builder = JavaObject(kind: .builder, className: "StringBuilder")
            if let first = args.first, Numeric(first) == nil { builder.text = try interpreter.stringify(first, line: line) }
            return .object(builder)
        case "Object":
            return .object(JavaObject(kind: .plain, className: "Object"))
        case "Integer", "Long", "Double", "Boolean", "Character":
            guard args.count == 1 else { throw .syntax("new \(className)(…) braucht genau einen Wert.", line: line) }
            return try callStatic(className, "valueOf", args, line: line, interpreter: interpreter)
        default:
            if JavaBuiltins.isThrowable(className) {
                let exception = JavaObject(kind: .throwable, className: className)
                exception.fields["$message"] = .null
                exception.fields["$cause"] = .null
                switch args.count {
                case 0: break
                case 1:
                    if case .object(let cause) = args[0], cause.kind == .throwable || interpreter.isThrowableClass(cause.className) {
                        exception.fields["$cause"] = args[0]
                        exception.fields["$message"] = .str(try interpreter.stringify(args[0], line: line))
                    } else {
                        exception.fields["$message"] = try interpreter.coerce(args[0], to: .string, line: line, what: "Die Meldung der Exception")
                    }
                case 2:
                    exception.fields["$message"] = try interpreter.coerce(args[0], to: .string, line: line, what: "Die Meldung der Exception")
                    exception.fields["$cause"] = args[1]
                default:
                    throw .syntax("\(className) hat keinen Konstruktor mit \(args.count) Werten.", line: line)
                }
                return .object(exception)
            }
            throw .unsupported("Objekte mit new \(className)(…) kennt der eingebaute Interpreter nicht.", line: line)
        }
    }

    /// Elemente einer Sammlung (oder eines Arrays) in Javas Reihenfolge.
    static func elements(of value: JavaValue, _ label: String, line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> [JavaValue] {
        switch value {
        case .object(let object) where [.list, .set, .deque].contains(object.kind):
            return try interpreter.iterationOrder(object)
        case .array(let array):
            return array.elements
        case .null:
            throw .exception("NullPointerException", javaMessage: nil, explanation: "\(label) bekommt null statt einer Sammlung.", line: line)
        default:
            throw .syntax("\(label) erwartet eine Sammlung (Liste, Set …), bekommt aber \(value.typeName).", line: line)
        }
    }

    // MARK: - Statische Methoden für Sammlungen

    static func collectionStatic(_ className: String, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue? {
        switch (className, name) {
        case ("List", "of"), ("List", "copyOf"):
            let list = JavaObject(kind: .list, className: "ImmutableList")
            list.isImmutable = true
            if name == "copyOf" || (args.count == 1 && { if case .array = args[0] { true } else { false } }()) {
                list.elements = try elements(of: args[0], "List.\(name)", line: line, interpreter: interpreter)
            } else {
                list.elements = args
            }
            if list.elements.contains(where: { if case .null = $0 { true } else { false } }) {
                throw .exception("NullPointerException", javaMessage: nil, explanation: "List.of verbietet null als Eintrag.", line: line)
            }
            return .object(list)
        case ("Set", "of"), ("Set", "copyOf"):
            let set = JavaObject(kind: .set, className: "ImmutableSet")
            let items = name == "copyOf" ? try elements(of: args[0], "Set.copyOf", line: line, interpreter: interpreter) : args
            for item in items {
                if try interpreter.indexOfKey(item, in: set, line: line) != nil {
                    if name == "copyOf" { continue }
                    throw .exception("IllegalArgumentException", javaMessage: "duplicate element: \(try interpreter.stringify(item, line: line))",
                                     explanation: "Set.of verbietet doppelte Einträge: \(try interpreter.stringify(item, line: line)).", line: line)
                }
                set.elements.append(item)
                set.sequence.append(set.sequence.count)
            }
            set.isImmutable = true
            return .object(set)
        case ("Map", "of"):
            guard args.count.isMultiple(of: 2) else { throw .syntax("Map.of braucht Paare aus Schlüssel und Wert.", line: line) }
            let map = JavaObject(kind: .map, className: "ImmutableMap")
            for index in stride(from: 0, to: args.count, by: 2) {
                if try interpreter.indexOfKey(args[index], in: map, line: line) != nil {
                    throw .exception("IllegalArgumentException", javaMessage: "duplicate key: \(try interpreter.stringify(args[index], line: line))",
                                     explanation: "Map.of verbietet doppelte Schlüssel.", line: line)
                }
                map.elements.append(args[index])
                map.values.append(args[index + 1])
                map.sequence.append(map.sequence.count)
            }
            map.isImmutable = true
            return .object(map)
        case ("Map", "entry"):
            try arity(args, 2, "Map.entry", line: line)
            let entry = JavaObject(kind: .entry, className: "Entry")
            entry.elements = [args[0]]
            entry.values = [args[1]]
            return .object(entry)
        case ("Arrays", "asList"):
            let list = JavaObject(kind: .list, className: "ArrayList")
            if args.count == 1, case .array(let array) = args[0] { list.elements = array.elements } else { list.elements = args }
            return .object(list)
        case ("Collections", _):
            return try collections(name, args, line: line, interpreter: interpreter)
        case ("Objects", _):
            return try objects(name, args, line: line, interpreter: interpreter)
        default:
            return nil
        }
    }

    private static func listArg(_ value: JavaValue, _ label: String, line: Int) throws(JavaProblem) -> JavaObject {
        guard case .object(let object) = value, object.kind == .list else {
            if case .null = value { throw .exception("NullPointerException", javaMessage: nil, explanation: "\(label) bekommt null statt einer Liste.", line: line) }
            throw .syntax("\(label) erwartet eine Liste, bekommt aber \(value.typeName).", line: line)
        }
        return object
    }

    private static func collections(_ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch name {
        case "sort":
            guard args.count == 1 else { throw .unsupported("Collections.sort mit Comparator (Lambda) kennt der eingebaute Interpreter nicht.", line: line) }
            let list = try listArg(args[0], "Collections.sort", line: line)
            try checkMutable(list, "sort", line: line)
            list.elements = try sorted(list.elements, line: line, interpreter: interpreter)
            return .void
        case "reverse":
            let list = try listArg(args.first ?? .null, "Collections.reverse", line: line)
            try checkMutable(list, "reverse", line: line)
            list.elements.reverse()
            return .void
        case "max", "min":
            guard args.count == 1 else { throw .unsupported("Collections.\(name) mit Comparator kennt der eingebaute Interpreter nicht.", line: line) }
            let items = try elements(of: args[0], "Collections.\(name)", line: line, interpreter: interpreter)
            guard var best = items.first else {
                throw .exception("NoSuchElementException", javaMessage: nil, explanation: "Collections.\(name) einer leeren Sammlung gibt es nicht.", line: line)
            }
            for item in items.dropFirst() {
                let order = try interpreter.javaCompare(item, best, line: line)
                if (name == "max" && order > 0) || (name == "min" && order < 0) { best = item }
            }
            return best
        case "frequency":
            try arity(args, 2, "Collections.frequency", line: line)
            let items = try elements(of: args[0], "Collections.frequency", line: line, interpreter: interpreter)
            var count: Int32 = 0
            for item in items where try interpreter.javaEquals(item, args[1], line: line) { count += 1 }
            return .int(count)
        case "swap":
            try arity(args, 3, "Collections.swap", line: line)
            let list = try listArg(args[0], "Collections.swap", line: line)
            let i = try checkedIndex(args[1], count: list.elements.count, line: line)
            let j = try checkedIndex(args[2], count: list.elements.count, line: line)
            list.elements.swapAt(i, j)
            return .void
        case "unmodifiableList", "emptyList":
            let list = JavaObject(kind: .list, className: "ImmutableList")
            list.isImmutable = true
            if let first = args.first { list.elements = try elements(of: first, "Collections.\(name)", line: line, interpreter: interpreter) }
            return .object(list)
        default:
            throw .unsupported("Collections.\(name) kennt der eingebaute Interpreter nicht.", line: line)
        }
    }

    private static func objects(_ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch name {
        case "equals":
            try arity(args, 2, "Objects.equals", line: line)
            return .boolean(try interpreter.javaEquals(args[0], args[1], line: line))
        case "hash":
            var hash: Int32 = 1
            for arg in args { hash = hash &* 31 &+ (try interpreter.javaHash(arg, line: line)) }
            return .int(hash)
        case "hashCode":
            try arity(args, 1, "Objects.hashCode", line: line)
            return .int(try interpreter.javaHash(args[0], line: line))
        case "isNull", "nonNull":
            try arity(args, 1, "Objects.\(name)", line: line)
            let isNull = if case .null = args[0] { true } else { false }
            return .boolean(name == "isNull" ? isNull : !isNull)
        case "requireNonNull":
            if case .null = args.first ?? .null {
                let message = args.count > 1 ? args[1].stringValue : nil
                throw .exception("NullPointerException", javaMessage: message, explanation: message ?? "Objects.requireNonNull: Der Wert ist null.", line: line)
            }
            return args[0]
        case "toString":
            return .str(try interpreter.stringify(args.first ?? .null, line: line))
        default:
            throw .unsupported("Objects.\(name) kennt der eingebaute Interpreter nicht.", line: line)
        }
    }

    static func sorted(_ items: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> [JavaValue] {
        // Stabiles Sortieren durch Einfügen – Fehler beim Vergleichen werden wie in Java gemeldet.
        var result: [JavaValue] = []
        for item in items {
            var index = result.count
            while index > 0, try interpreter.javaCompare(result[index - 1], item, line: line) > 0 { index -= 1 }
            result.insert(item, at: index)
        }
        return result
    }

    // MARK: - Zahlen als Objekte (Integer, Double …)

    /// Methoden von Integer, Long, Double, Character und Boolean – z. B. `zahl.equals(5)` bei `Integer zahl`.
    static func boxedMethod(_ value: JavaValue, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue? {
        switch value {
        case .int, .long, .double, .char, .boolean: break
        default: return nil
        }
        switch (name, args.count) {
        case ("equals", 1):
            switch (value, args[0]) {
            case (.int(let a), .int(let b)): return .boolean(a == b)
            case (.long(let a), .long(let b)): return .boolean(a == b)
            case (.double(let a), .double(let b)): return .boolean(a.bitPattern == b.bitPattern || (a.isNaN && b.isNaN))
            case (.char(let a), .char(let b)): return .boolean(a == b)
            case (.boolean(let a), .boolean(let b)): return .boolean(a == b)
            default: return .boolean(false)
            }
        case ("compareTo", 1):
            // Character.compareTo liefert den Abstand der Zeichen, die anderen nur -1, 0 oder 1.
            if case .char(let a) = value, case .char(let b) = args[0] { return .int(Int32(a) - Int32(b)) }
            return .int(Int32(try interpreter.javaCompare(value, args[0], line: line)))
        case ("hashCode", 0): return .int(try interpreter.javaHash(value, line: line))
        case ("toString", 0): return .str(value.javaString)
        case ("intValue", 0), ("longValue", 0), ("doubleValue", 0):
            guard let number = Numeric(value) else { return nil }
            switch name {
            case "intValue": return .int(Int32(truncatingIfNeeded: number.isDouble ? Int64(number.toDouble.isNaN ? 0 : max(min(number.toDouble, Double(Int32.max)), Double(Int32.min))) : number.toInt64))
            case "longValue": return .long(number.isDouble ? Int64(number.toDouble.isNaN ? 0 : max(min(number.toDouble, 9.2e18), -9.2e18)) : number.toInt64)
            default: return .double(number.toDouble)
            }
        case ("charValue", 0):
            if case .char = value { return value }
            return nil
        case ("booleanValue", 0):
            if case .boolean = value { return value }
            return nil
        case ("isNaN", 0):
            if case .double(let d) = value { return .boolean(d.isNaN) }
            return nil
        case ("isInfinite", 0):
            if case .double(let d) = value { return .boolean(d.isInfinite) }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Methoden an Objekten

    static func callObject(_ object: JavaObject, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        // Was jedes Objekt kann
        switch (name, args.count) {
        case ("toString", 0): return .str(try interpreter.stringify(.object(object), line: line))
        case ("equals", 1): return .boolean(try interpreter.javaEquals(.object(object), args[0], line: line))
        case ("hashCode", 0): return .int(try interpreter.javaHash(.object(object), line: line))
        case ("getClass", 0):
            let info = JavaObject(kind: .classInfo, className: "Class")
            info.fields["name"] = .str(JavaBuiltins.qualifiedName(object.className))
            info.fields["simpleName"] = .str(object.className)
            return .object(info)
        default: break
        }
        switch object.kind {
        case .list: return try listMethod(object, name, args, line: line, interpreter: interpreter)
        case .map: return try mapMethod(object, name, args, line: line, interpreter: interpreter)
        case .set: return try setMethod(object, name, args, line: line, interpreter: interpreter)
        case .deque: return try dequeMethod(object, name, args, line: line, interpreter: interpreter)
        case .builder: return try builderMethod(object, name, args, line: line, interpreter: interpreter)
        case .throwable:
            switch (name, args.count) {
            case ("getMessage", 0), ("getLocalizedMessage", 0): return object.fields["$message"] ?? .null
            case ("getCause", 0): return object.fields["$cause"] ?? .null
            case ("printStackTrace", 0): return .void
            default: break
            }
        case .classInfo:
            switch name {
            case "getSimpleName": return object.fields["simpleName"] ?? .null
            case "getName": return object.fields["name"] ?? .null
            default: break
            }
        case .entry:
            switch (name, args.count) {
            case ("getKey", 0): return object.elements.first ?? .null
            case ("getValue", 0): return object.values.first ?? .null
            case ("setValue", 1):
                let old = object.values.first ?? .null
                object.values = [args[0]]
                if case .object(let map)? = object.fields["$map"], let key = object.elements.first,
                   let index = try interpreter.indexOfKey(key, in: map, line: line) {
                    map.values[index] = args[0]
                }
                return old
            default: break
            }
        case .plain:
            break
        }
        if ["forEach", "stream", "removeIf", "replaceAll", "computeIfAbsent", "merge", "compute", "iterator", "listIterator", "toArray", "spliterator"].contains(name) {
            throw .unsupported("\(name)(…) kennt der eingebaute Interpreter nicht.", line: line)
        }
        throw .syntax("\(displayName(object)) hat keine Methode \(name)(…) mit \(args.count) Wert(en).", line: line)
    }

    private static func displayName(_ object: JavaObject) -> String {
        switch object.className {
        case "ImmutableList": "Die Liste"
        case "ImmutableSet": "Das Set"
        case "ImmutableMap": "Die Map"
        default: object.className
        }
    }

    private static func checkMutable(_ object: JavaObject, _ name: String, line: Int) throws(JavaProblem) {
        if object.isImmutable {
            throw .exception("UnsupportedOperationException", javaMessage: nil,
                             explanation: "\(name)(…) geht hier nicht – die Sammlung ist unveränderlich (z. B. aus List.of, Set.of oder Map.of).", line: line)
        }
    }

    private static func checkedIndex(_ value: JavaValue, count: Int, line: Int, allowEnd: Bool = false) throws(JavaProblem) -> Int {
        guard case .int(let raw) = value else { throw .syntax("Der Index muss eine ganze Zahl (int) sein.", line: line) }
        let index = Int(raw)
        guard index >= 0, index < count || (allowEnd && index == count) else {
            throw .exception("IndexOutOfBoundsException", javaMessage: "Index \(index) out of bounds for length \(count)",
                             explanation: "Index \(index) gibt es nicht – die Liste hat \(count == 0 ? "keine Einträge" : "nur die Plätze 0 bis \(count - 1)").", line: line)
        }
        return index
    }

    private static func noSuchElement(_ label: String, line: Int) -> JavaProblem {
        .exception("NoSuchElementException", javaMessage: nil, explanation: "\(label) – die Sammlung ist leer.", line: line)
    }

    // MARK: Liste

    private static func listMethod(_ list: JavaObject, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch (name, args.count) {
        case ("size", 0): return .int(Int32(list.elements.count))
        case ("isEmpty", 0): return .boolean(list.elements.isEmpty)
        case ("get", 1): return list.elements[try checkedIndex(args[0], count: list.elements.count, line: line)]
        case ("add", 1), ("addLast", 1):
            try checkMutable(list, name, line: line)
            list.elements.append(args[0])
            return name == "add" ? .boolean(true) : .void
        case ("push", 1) where list.className == "Stack":
            // Beim Stack liegt das oberste Element hinten, bei der LinkedList vorne (siehe unten).
            list.elements.append(args[0])
            return args[0]
        case ("add", 2):
            try checkMutable(list, name, line: line)
            let index = try checkedIndex(args[0], count: list.elements.count, line: line, allowEnd: true)
            list.elements.insert(args[1], at: index)
            return .void
        case ("addFirst", 1), ("push", 1):
            try checkMutable(list, name, line: line)
            list.elements.insert(args[0], at: 0)
            return .void
        case ("addAll", 1):
            try checkMutable(list, name, line: line)
            let items = try elements(of: args[0], "addAll", line: line, interpreter: interpreter)
            list.elements += items
            return .boolean(!items.isEmpty)
        case ("set", 2):
            try checkMutable(list, name, line: line)
            let index = try checkedIndex(args[0], count: list.elements.count, line: line)
            let old = list.elements[index]
            list.elements[index] = args[1]
            return old
        case ("remove", 1), ("$removeValue", 1):
            try checkMutable(list, "remove", line: line)
            // Wie in Java: Bei einer ganzen Zahl (int) wird die Stelle entfernt, sonst das Objekt.
            if name == "remove", case .int = args[0] {
                return list.elements.remove(at: try checkedIndex(args[0], count: list.elements.count, line: line))
            }
            if let index = try interpreter.indexOfKey(args[0], in: list, line: line) {
                list.elements.remove(at: index)
                return .boolean(true)
            }
            return .boolean(false)
        case ("removeFirst", 0), ("removeLast", 0), ("pop", 0):
            try checkMutable(list, name, line: line)
            guard !list.elements.isEmpty else {
                if list.className == "Stack" {
                    throw .exception("EmptyStackException", javaMessage: nil, explanation: "pop() auf einem leeren Stapel.", line: line)
                }
                throw noSuchElement("\(name)()", line: line)
            }
            let fromEnd = name == "removeLast" || (name == "pop" && list.className == "Stack")
            return fromEnd ? list.elements.removeLast() : list.elements.removeFirst()
        case ("getFirst", 0), ("getLast", 0), ("peek", 0), ("element", 0), ("peekFirst", 0), ("peekLast", 0):
            guard !list.elements.isEmpty else {
                if name.hasPrefix("peek") { return .null }
                throw noSuchElement("\(name)()", line: line)
            }
            let fromEnd = name == "getLast" || name == "peekLast" || (name == "peek" && list.className == "Stack")
            return fromEnd ? list.elements[list.elements.count - 1] : list.elements[0]
        case ("poll", 0), ("pollFirst", 0):
            try checkMutable(list, name, line: line)
            return list.elements.isEmpty ? .null : list.elements.removeFirst()
        case ("offer", 1):
            try checkMutable(list, name, line: line)
            list.elements.append(args[0])
            return .boolean(true)
        case ("contains", 1): return .boolean(try interpreter.indexOfKey(args[0], in: list, line: line) != nil)
        case ("indexOf", 1): return .int(Int32(try interpreter.indexOfKey(args[0], in: list, line: line) ?? -1))
        case ("lastIndexOf", 1):
            for index in list.elements.indices.reversed() where try interpreter.javaEquals(list.elements[index], args[0], line: line) {
                return .int(Int32(index))
            }
            return .int(-1)
        case ("clear", 0):
            try checkMutable(list, name, line: line)
            list.elements.removeAll()
            return .void
        case ("sort", 1):
            guard case .null = args[0] else {
                throw .unsupported("sort mit Comparator (Lambda) kennt der eingebaute Interpreter nicht – nimm sort(null) oder Collections.sort.", line: line)
            }
            try checkMutable(list, name, line: line)
            list.elements = try sorted(list.elements, line: line, interpreter: interpreter)
            return .void
        case ("subList", 2):
            let from = try checkedIndex(args[0], count: list.elements.count, line: line, allowEnd: true)
            let to = try checkedIndex(args[1], count: list.elements.count, line: line, allowEnd: true)
            guard from <= to else {
                throw .exception("IllegalArgumentException", javaMessage: "fromIndex(\(from)) > toIndex(\(to))", explanation: "subList: Anfang \(from) liegt hinter dem Ende \(to).", line: line)
            }
            let part = JavaObject(kind: .list, className: "ArrayList")
            part.elements = Array(list.elements[from..<to])
            return .object(part)
        case ("reversed", 0):
            let copy = JavaObject(kind: .list, className: list.className)
            copy.elements = list.elements.reversed()
            return .object(copy)
        case ("containsAll", 1):
            for item in try elements(of: args[0], "containsAll", line: line, interpreter: interpreter) where try interpreter.indexOfKey(item, in: list, line: line) == nil {
                return .boolean(false)
            }
            return .boolean(true)
        default:
            return try callObjectFallback(list, name, args, line: line)
        }
    }

    private static func callObjectFallback(_ object: JavaObject, _ name: String, _ args: [JavaValue], line: Int) throws(JavaProblem) -> JavaValue {
        if ["forEach", "stream", "removeIf", "replaceAll", "iterator", "listIterator", "toArray", "computeIfAbsent", "merge", "compute"].contains(name) {
            throw .unsupported("\(name)(…) kennt der eingebaute Interpreter nicht.", line: line)
        }
        throw .syntax("\(displayName(object)) hat keine Methode \(name)(…) mit \(args.count) Wert(en).", line: line)
    }

    // MARK: Map

    /// Schlüssel eintragen oder ersetzen; gibt den alten Wert zurück (oder null).
    static func mapPut(_ map: JavaObject, _ key: JavaValue, _ value: JavaValue, line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        if map.order == .sorted {
            // TreeMap: gleich ist, was compareTo für gleich hält.
            var low = 0
            var high = map.elements.count
            while low < high {
                let mid = (low + high) / 2
                let order = try interpreter.javaCompare(map.elements[mid], key, line: line)
                if order == 0 {
                    let old = map.values[mid]
                    map.values[mid] = value
                    return old
                }
                if order < 0 { low = mid + 1 } else { high = mid }
            }
            map.elements.insert(key, at: low)
            map.values.insert(value, at: low)
            map.sequence.insert(map.nextSequence, at: low)
            map.nextSequence += 1
            return .null
        }
        if let index = try interpreter.indexOfKey(key, in: map, line: line) {
            let old = map.values[index]
            map.values[index] = value
            return old
        }
        if case .null = key, map.order == .sorted {
            throw .exception("NullPointerException", javaMessage: nil, explanation: "Eine TreeMap verbietet null als Schlüssel.", line: line)
        }
        map.elements.append(key)
        map.values.append(value)
        map.sequence.append(map.nextSequence)
        map.nextSequence += 1
        // Wie HashMap: Bei mehr als 3/4 Füllung verdoppelt sich die Tabelle.
        while map.elements.count > map.capacity * 3 / 4 { map.capacity *= 2 }
        return .null
    }

    private static func mapMethod(_ map: JavaObject, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch (name, args.count) {
        case ("put", 2):
            try checkMutable(map, name, line: line)
            return try mapPut(map, args[0], args[1], line: line, interpreter: interpreter)
        case ("putIfAbsent", 2):
            try checkMutable(map, name, line: line)
            if let index = try interpreter.indexOfKey(args[0], in: map, line: line), !isNull(map.values[index]) { return map.values[index] }
            return try mapPut(map, args[0], args[1], line: line, interpreter: interpreter)
        case ("get", 1):
            guard let index = try interpreter.indexOfKey(args[0], in: map, line: line) else { return .null }
            return map.values[index]
        case ("getOrDefault", 2):
            guard let index = try interpreter.indexOfKey(args[0], in: map, line: line) else { return args[1] }
            return map.values[index]
        case ("containsKey", 1): return .boolean(try interpreter.indexOfKey(args[0], in: map, line: line) != nil)
        case ("containsValue", 1):
            for value in map.values where try interpreter.javaEquals(value, args[0], line: line) { return .boolean(true) }
            return .boolean(false)
        case ("remove", 1):
            try checkMutable(map, name, line: line)
            guard let index = try interpreter.indexOfKey(args[0], in: map, line: line) else { return .null }
            map.elements.remove(at: index)
            map.sequence.remove(at: index)
            return map.values.remove(at: index)
        case ("replace", 2):
            try checkMutable(map, name, line: line)
            guard let index = try interpreter.indexOfKey(args[0], in: map, line: line) else { return .null }
            let old = map.values[index]
            map.values[index] = args[1]
            return old
        case ("size", 0): return .int(Int32(map.elements.count))
        case ("isEmpty", 0): return .boolean(map.elements.isEmpty)
        case ("clear", 0):
            try checkMutable(map, name, line: line)
            map.elements.removeAll()
            map.values.removeAll()
            map.sequence.removeAll()
            return .void
        case ("keySet", 0):
            let keys = JavaObject(kind: .set, className: "LinkedHashSet")
            keys.elements = try interpreter.iterationOrder(map)
            keys.sequence = Array(keys.elements.indices)
            return .object(keys)
        case ("values", 0):
            let values = JavaObject(kind: .list, className: "ArrayList")
            values.elements = try interpreter.mapEntries(map).map(\.value)
            return .object(values)
        case ("entrySet", 0):
            let entries = JavaObject(kind: .set, className: "LinkedHashSet")
            for (key, value) in try interpreter.mapEntries(map) {
                let entry = JavaObject(kind: .entry, className: "Entry")
                entry.elements = [key]
                entry.values = [value]
                entry.fields["$map"] = .object(map)
                entries.elements.append(.object(entry))
            }
            entries.sequence = Array(entries.elements.indices)
            return .object(entries)
        case ("firstKey", 0), ("lastKey", 0):
            guard map.order == .sorted else { break }
            guard !map.elements.isEmpty else { throw noSuchElement("\(name)()", line: line) }
            return name == "firstKey" ? map.elements[0] : map.elements[map.elements.count - 1]
        default:
            break
        }
        return try callObjectFallback(map, name, args, line: line)
    }

    private static func isNull(_ value: JavaValue) -> Bool { if case .null = value { true } else { false } }

    // MARK: Set

    /// Element einfügen; false, wenn es schon da ist.
    static func setAdd(_ set: JavaObject, _ item: JavaValue, line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> Bool {
        if set.order == .sorted {
            var low = 0
            var high = set.elements.count
            while low < high {
                let mid = (low + high) / 2
                let order = try interpreter.javaCompare(set.elements[mid], item, line: line)
                if order == 0 { return false }
                if order < 0 { low = mid + 1 } else { high = mid }
            }
            set.elements.insert(item, at: low)
            set.sequence.insert(set.nextSequence, at: low)
            set.nextSequence += 1
            return true
        }
        if try interpreter.indexOfKey(item, in: set, line: line) != nil { return false }
        set.elements.append(item)
        set.sequence.append(set.nextSequence)
        set.nextSequence += 1
        while set.elements.count > set.capacity * 3 / 4 { set.capacity *= 2 }
        return true
    }

    private static func setMethod(_ set: JavaObject, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch (name, args.count) {
        case ("add", 1):
            try checkMutable(set, name, line: line)
            return .boolean(try setAdd(set, args[0], line: line, interpreter: interpreter))
        case ("addAll", 1):
            try checkMutable(set, name, line: line)
            var changed = false
            for item in try elements(of: args[0], "addAll", line: line, interpreter: interpreter) where try setAdd(set, item, line: line, interpreter: interpreter) {
                changed = true
            }
            return .boolean(changed)
        case ("remove", 1):
            try checkMutable(set, name, line: line)
            guard let index = try interpreter.indexOfKey(args[0], in: set, line: line) else { return .boolean(false) }
            set.elements.remove(at: index)
            set.sequence.remove(at: index)
            return .boolean(true)
        case ("removeAll", 1), ("retainAll", 1):
            try checkMutable(set, name, line: line)
            let other = try elements(of: args[0], name, line: line, interpreter: interpreter)
            var kept: [JavaValue] = []
            var keptSequence: [Int] = []
            for (item, sequence) in zip(set.elements, set.sequence) {
                var inOther = false
                for candidate in other where try interpreter.javaEquals(candidate, item, line: line) { inOther = true }
                if inOther == (name == "retainAll") { kept.append(item); keptSequence.append(sequence) }
            }
            let changed = kept.count != set.elements.count
            set.elements = kept
            set.sequence = keptSequence
            return .boolean(changed)
        case ("contains", 1): return .boolean(try interpreter.indexOfKey(args[0], in: set, line: line) != nil)
        case ("containsAll", 1):
            for item in try elements(of: args[0], "containsAll", line: line, interpreter: interpreter) where try interpreter.indexOfKey(item, in: set, line: line) == nil {
                return .boolean(false)
            }
            return .boolean(true)
        case ("size", 0): return .int(Int32(set.elements.count))
        case ("isEmpty", 0): return .boolean(set.elements.isEmpty)
        case ("clear", 0):
            try checkMutable(set, name, line: line)
            set.elements.removeAll()
            set.sequence.removeAll()
            return .void
        case ("first", 0), ("last", 0):
            guard set.order == .sorted else { break }
            guard !set.elements.isEmpty else { throw noSuchElement("\(name)()", line: line) }
            return name == "first" ? set.elements[0] : set.elements[set.elements.count - 1]
        default:
            break
        }
        return try callObjectFallback(set, name, args, line: line)
    }

    // MARK: Deque / Queue (ArrayDeque)

    private static func dequeMethod(_ deque: JavaObject, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        switch (name, args.count) {
        case ("push", 1), ("addFirst", 1), ("offerFirst", 1):
            if case .null = args[0] { throw .exception("NullPointerException", javaMessage: nil, explanation: "ArrayDeque verbietet null.", line: line) }
            deque.elements.insert(args[0], at: 0)
            return name == "offerFirst" ? .boolean(true) : .void
        case ("add", 1), ("addLast", 1), ("offer", 1), ("offerLast", 1):
            if case .null = args[0] { throw .exception("NullPointerException", javaMessage: nil, explanation: "ArrayDeque verbietet null.", line: line) }
            deque.elements.append(args[0])
            return name == "addLast" ? .void : .boolean(true)
        case ("pop", 0), ("removeFirst", 0), ("remove", 0), ("element", 0), ("getFirst", 0):
            guard !deque.elements.isEmpty else { throw noSuchElement("\(name)()", line: line) }
            return ["element", "getFirst"].contains(name) ? deque.elements[0] : deque.elements.removeFirst()
        case ("removeLast", 0), ("getLast", 0):
            guard !deque.elements.isEmpty else { throw noSuchElement("\(name)()", line: line) }
            return name == "getLast" ? deque.elements[deque.elements.count - 1] : deque.elements.removeLast()
        case ("poll", 0), ("pollFirst", 0):
            return deque.elements.isEmpty ? .null : deque.elements.removeFirst()
        case ("pollLast", 0):
            return deque.elements.isEmpty ? .null : deque.elements.removeLast()
        case ("peek", 0), ("peekFirst", 0):
            return deque.elements.first ?? .null
        case ("peekLast", 0):
            return deque.elements.last ?? .null
        case ("size", 0): return .int(Int32(deque.elements.count))
        case ("isEmpty", 0): return .boolean(deque.elements.isEmpty)
        case ("contains", 1): return .boolean(try interpreter.indexOfKey(args[0], in: deque, line: line) != nil)
        case ("remove", 1):
            guard let index = try interpreter.indexOfKey(args[0], in: deque, line: line) else { return .boolean(false) }
            deque.elements.remove(at: index)
            return .boolean(true)
        case ("clear", 0):
            deque.elements.removeAll()
            return .void
        default:
            return try callObjectFallback(deque, name, args, line: line)
        }
    }

    // MARK: StringBuilder

    private static func builderMethod(_ builder: JavaObject, _ name: String, _ args: [JavaValue], line: Int, interpreter: JavaInterpreter) throws(JavaProblem) -> JavaValue {
        var units = Array(builder.text.utf16)
        func index(_ value: JavaValue, allowEnd: Bool = true) throws(JavaProblem) -> Int {
            guard case .int(let raw) = value else { throw .syntax("Die Stelle muss eine ganze Zahl (int) sein.", line: line) }
            let i = Int(raw)
            guard i >= 0, i < units.count || (allowEnd && i == units.count) else {
                throw .exception("StringIndexOutOfBoundsException", javaMessage: "index \(i),length \(units.count)",
                                 explanation: "Stelle \(i) gibt es nicht – der Text hat \(units.count) Zeichen.", line: line)
            }
            return i
        }
        switch (name, args.count) {
        case ("append", 1):
            if case .array(let array) = args[0], array.elementType == .char {
                builder.text += array.elements.map(\.javaString).joined()
            } else {
                builder.text += try interpreter.stringify(args[0], line: line)
            }
            return .object(builder)
        case ("insert", 2):
            let at = try index(args[0])
            units.insert(contentsOf: Array(try interpreter.stringify(args[1], line: line).utf16), at: at)
            builder.text = String(decoding: units, as: UTF16.self)
            return .object(builder)
        case ("reverse", 0):
            builder.text = String(builder.text.reversed())
            return .object(builder)
        case ("toString", 0): return .str(builder.text)
        case ("length", 0): return .int(Int32(units.count))
        case ("isEmpty", 0): return .boolean(units.isEmpty)
        case ("charAt", 1): return .char(units[try index(args[0], allowEnd: false)])
        case ("setCharAt", 2):
            let at = try index(args[0], allowEnd: false)
            guard case .char(let c) = args[1] else { throw .syntax("setCharAt braucht ein Zeichen (char).", line: line) }
            units[at] = c
            builder.text = String(decoding: units, as: UTF16.self)
            return .void
        case ("deleteCharAt", 1):
            units.remove(at: try index(args[0], allowEnd: false))
            builder.text = String(decoding: units, as: UTF16.self)
            return .object(builder)
        case ("delete", 2), ("replace", 3):
            let start = try index(args[0])
            guard case .int(let rawEnd) = args[1] else { throw .syntax("Das Ende muss eine ganze Zahl sein.", line: line) }
            let end = min(Int(rawEnd), units.count)
            guard start <= end else {
                throw .exception("StringIndexOutOfBoundsException", javaMessage: "start \(start), end \(end), length \(units.count)",
                                 explanation: "Der Anfang \(start) liegt hinter dem Ende \(end).", line: line)
            }
            let replacement = name == "replace" ? Array(try interpreter.stringify(args[2], line: line).utf16) : []
            units.replaceSubrange(start..<end, with: replacement)
            builder.text = String(decoding: units, as: UTF16.self)
            return .object(builder)
        case ("indexOf", 1):
            guard let needle = args[0].stringValue else { throw .syntax("indexOf erwartet einen Text.", line: line) }
            return try callInstance(.str(builder.text), "indexOf", [.str(needle)], line: line, interpreter: interpreter)
        case ("setLength", 1):
            guard case .int(let length) = args[0], length >= 0 else { throw .syntax("setLength braucht eine Länge ≥ 0.", line: line) }
            if Int(length) <= units.count { units = Array(units.prefix(Int(length))) } else { units += Array(repeating: 0, count: Int(length) - units.count) }
            builder.text = String(decoding: units, as: UTF16.self)
            return .void
        default:
            return try callObjectFallback(builder, name, args, line: line)
        }
    }
}
