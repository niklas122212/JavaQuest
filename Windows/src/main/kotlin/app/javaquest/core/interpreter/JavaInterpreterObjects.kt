package app.javaquest.core.interpreter

/*
 * Objektorientierung im Interpreter: eigene Klassen, Konstruktoren, Vererbung, Interfaces,
 * Enums, Records und Exceptions (throw, try/catch/finally) – gleiche Regeln wie die Apple-App.
 */

// MARK: - Klassen nachschlagen

/** Ist [name] ein Typname (eigene Klasse) – und keine Variable? */
internal fun JavaInterpreter.isTypeName(name: String): Boolean =
    lookup(name) == null && (program.classes.containsKey(name) || name == program.mainClass)

/** Äußerste Klasse – private Felder und Methoden sind innerhalb derselben äußeren Klasse sichtbar. */
internal fun JavaInterpreter.topLevel(name: String?): String {
    var current = name ?: program.mainClass ?: ""
    while (true) {
        val outer = program.classes[current]?.outer ?: return current
        current = outer.substringBefore('$')
    }
}

/** Ist [className] gleich [target] oder ein Untertyp davon (Klassen, Interfaces, Exceptions, Bibliothek)? */
internal fun JavaInterpreter.isSubtype(className: String, target: String): Boolean {
    if (className == target || target == "Object") return true
    val visited = mutableSetOf<String>()
    val queue = mutableListOf(className)
    while (queue.isNotEmpty()) {
        val current = queue.removeAt(queue.lastIndex)
        if (current == target) return true
        if (!visited.add(current)) continue
        val decl = program.classes[current]
        if (decl != null) {
            decl.superclass?.let { queue += it }
            queue += decl.interfaces.map { it.substringBefore('<') }
            if (decl.kind == ClassDecl.Kind.ENUM) queue += "Comparable"
        } else if (JavaBuiltins.isThrowable(current)) {
            if (JavaBuiltins.throwableIs(current, target)) return true
        } else if (JavaBuiltins.librarySupertypes[current]?.contains(target) == true) {
            return true
        }
    }
    return false
}

/** Die Kette der eigenen Klassen von [name] aufwärts (ohne Interfaces). */
internal fun JavaInterpreter.classChain(name: String): List<ClassDecl> {
    val chain = mutableListOf<ClassDecl>()
    var current: String? = name
    val visited = mutableSetOf<String>()
    while (current != null) {
        val decl = program.classes[current] ?: break
        if (!visited.add(current)) break
        chain += decl
        current = decl.superclass
    }
    return chain
}

/** Alle eigenen Interfaces, die [name] (mit Oberklassen und Ober-Interfaces) umsetzt. */
internal fun JavaInterpreter.allInterfaces(name: String): List<ClassDecl> {
    val result = mutableListOf<ClassDecl>()
    val visited = mutableSetOf<String>()
    val queue = classChain(name).flatMap { it.interfaces }.toMutableList()
    while (queue.isNotEmpty()) {
        val base = queue.removeAt(queue.lastIndex).substringBefore('<')
        if (!visited.add(base)) continue
        val decl = program.classes[base] ?: continue
        result += decl
        queue += decl.interfaces
    }
    return result
}

/** Eingebaute Oberklasse (Exception …), falls die Kette eigener Klassen in eine mündet. */
internal fun JavaInterpreter.builtinAncestor(name: String): String? {
    if (!program.classes.containsKey(name)) return if (JavaBuiltins.isThrowable(name)) name else null
    for (decl in classChain(name)) {
        val parent = decl.superclass ?: continue
        if (!program.classes.containsKey(parent) && JavaBuiltins.isThrowable(parent)) return parent
    }
    return null
}

internal fun JavaInterpreter.isThrowableClass(name: String): Boolean = builtinAncestor(name) != null

/** Gibt es in [className] (Kette, Interfaces) eine Methode dieses Namens? */
internal fun JavaInterpreter.hasMethod(name: String, className: String): Boolean =
    classChain(className).any { it.methods.containsKey(name) } || allInterfaces(className).any { it.methods.containsKey(name) } ||
        (className == program.mainClass && program.methods.containsKey(name))

/** Methode für einen Aufruf finden: von der Laufzeitklasse aufwärts, dann Default-Methoden der Interfaces. */
internal fun JavaInterpreter.findMethod(name: String, className: String, args: List<JValue>, wantStatic: Boolean?, line: Int): Method? {
    for (decl in classChain(className) + allInterfaces(className)) {
        val candidates = (decl.methods[name] ?: continue).filter { m ->
            m.parameters.size == args.size && !m.isAbstract && (wantStatic == null || m.isStatic == wantStatic)
        }
        if (candidates.isNotEmpty()) return selectOverload(candidates, args, name, line)
    }
    return null
}

// MARK: - Statische Felder

internal fun JavaInterpreter.staticSlot(name: String, className: String?): Pair<String, JavaInterpreter.Slot>? {
    var current = className
    val visited = mutableSetOf<String>()
    while (current != null && current != program.mainClass && visited.add(current)) {
        for (decl in classChain(current)) {
            statics[decl.name]?.get(name)?.let { return decl.name to it }
            for (inter in allInterfaces(decl.name)) statics[inter.name]?.get(name)?.let { return inter.name to it }
        }
        // Verschachtelte Klassen sehen die statischen Felder der äußeren Klasse.
        current = program.classes[current]?.outer?.substringAfterLast('$')
    }
    return null
}

internal fun JavaInterpreter.writeStatic(owner: String, name: String, value: JValue, line: Int): JValue {
    val slot = statics[owner]?.get(name) ?: throw unknownName(name, line)
    if (slot.isFinal && slot.value != null) throw JavaProblem.syntax("„$name“ ist final – der Wert darf nicht mehr geändert werden.", line)
    val stored = coerce(value, slot.type, line, "Das Feld „$name“")
    slot.value = stored
    return stored
}

/** Ist [name] ein Objektfeld der Klasse, deren Code gerade läuft? (Für die static-Meldung.) */
internal fun JavaInterpreter.isInstanceField(name: String): Boolean {
    val className = frame.currentClass ?: program.mainClass ?: return false
    return classChain(className).any { c -> c.fields.any { !it.isStatic && it.name == name } || c.recordComponents.any { it.name == name } }
}

// MARK: - Klassen prüfen und vorbereiten

private val builtinInterfaces: Map<String, List<Pair<String, Int>>> =
    mapOf("Comparable" to listOf("compareTo" to 1), "Runnable" to listOf("run" to 0), "Cloneable" to emptyList(), "Serializable" to emptyList())

/** Was javac schon beim Übersetzen ablehnen würde: falsche Oberklassen, fehlende Methoden, falsches @Override. */
internal fun JavaInterpreter.validateClasses() {
    for (name in program.classOrder) {
        val decl = program.classes[name] ?: continue
        decl.superclass?.let { parent ->
            val parentDecl = program.classes[parent]
            if (parentDecl != null) {
                if (parentDecl.isInterface) {
                    throw JavaProblem.syntax("$name extends $parent: $parent ist ein Interface – Interfaces setzt man mit implements um, extends ist für Klassen.", decl.line)
                }
                if (parentDecl.kind == ClassDecl.Kind.ENUM || parentDecl.kind == ClassDecl.Kind.RECORD) {
                    throw JavaProblem.syntax("Von $parent kann man nicht erben.", decl.line)
                }
            } else if (parent != "Object" && !JavaBuiltins.isThrowable(parent)) {
                throw JavaProblem.unsupported("Die Oberklasse $parent kennt der eingebaute Interpreter nicht.", decl.line)
            }
            if (classChain(name).size > 64) throw JavaProblem.syntax("Die Vererbung von $name dreht sich im Kreis.", decl.line)
        }
        for (inter in decl.interfaces) {
            val base = inter.substringBefore('<')
            val interfaceDecl = program.classes[base]
            if (interfaceDecl != null) {
                if (!interfaceDecl.isInterface) {
                    throw JavaProblem.syntax("$name implements $base: $base ist eine Klasse, kein Interface – von Klassen erbt man mit extends.", decl.line)
                }
            } else if (base !in builtinInterfaces) {
                throw JavaProblem.unsupported("Das Interface $base kennt der eingebaute Interpreter nicht.", decl.line)
            }
        }
        // @Override: Es muss eine Methode geben, die ersetzt wird.
        for (method in decl.methods.values.flatten().filter { it.isOverride }) {
            if (!overridesSomething(method, decl)) {
                throw JavaProblem.syntax("@Override bei ${method.name}(…): Diese Methode ersetzt keine Methode einer Oberklasse oder eines Interfaces. Stimmen Name (auch Groß- und Kleinschreibung) und Parameter?", method.line)
            }
        }
        // Eine normale Klasse muss alle abstrakten Methoden ihrer Oberklassen und Interfaces umsetzen.
        if (!decl.isAbstract && !decl.isInterface) {
            for ((methodName, count, source) in requiredMethods(decl)) {
                val implemented = classChain(name).any { c -> c.methods[methodName].orEmpty().any { !it.isAbstract && it.parameters.size == count } } ||
                    allInterfaces(name).any { i -> i.methods[methodName].orEmpty().any { !it.isAbstract && it.parameters.size == count } } ||
                    (decl.kind == ClassDecl.Kind.RECORD && count == 0 && decl.recordComponents.any { it.name == methodName }) ||
                    (decl.kind == ClassDecl.Kind.ENUM && methodName == "compareTo")
                if (!implemented) {
                    throw JavaProblem.syntax("Die Klasse $name muss die Methode $methodName(…) aus $source umsetzen – oder selbst abstract sein.", decl.line)
                }
            }
        }
    }
}

private fun JavaInterpreter.overridesSomething(method: Method, decl: ClassDecl): Boolean {
    val count = method.parameters.size
    val signature = method.name to count
    if (signature in listOf("toString" to 0, "equals" to 1, "hashCode" to 0)) return true
    decl.superclass?.let { parent ->
        if (classChain(parent).any { c -> c.methods[method.name].orEmpty().any { it.parameters.size == count } }) return true
        if ((JavaBuiltins.isThrowable(parent) || builtinAncestor(parent) != null) &&
            signature in listOf("getMessage" to 0, "toString" to 0, "getCause" to 0)
        ) return true
    }
    if (allInterfaces(decl.name).any { i -> i.methods[method.name].orEmpty().any { it.parameters.size == count } }) return true
    return classChain(decl.name).any { c -> c.interfaces.any { builtinInterfaces[it.substringBefore('<')]?.contains(signature) == true } }
}

private fun JavaInterpreter.requiredMethods(decl: ClassDecl): List<Triple<String, Int, String>> {
    val required = mutableListOf<Triple<String, Int, String>>()
    for (c in classChain(decl.name).drop(1).filter { it.isAbstract }) {
        for (m in c.methods.values.flatten().filter { it.isAbstract }) required += Triple(m.name, m.parameters.size, c.name)
    }
    for (i in allInterfaces(decl.name)) {
        for (m in i.methods.values.flatten().filter { it.isAbstract }) required += Triple(m.name, m.parameters.size, i.name)
    }
    for (c in classChain(decl.name)) {
        for (inter in c.interfaces) {
            val base = inter.substringBefore('<')
            for ((n, count) in builtinInterfaces[base].orEmpty()) required += Triple(n, count, base)
        }
    }
    return required
}

/** Statische Felder und Enum-Konstanten aller eigenen Klassen anlegen – in der Reihenfolge im Quelltext. */
internal fun JavaInterpreter.initializeClasses() {
    for (name in program.classOrder) {
        if (name == program.mainClass) continue
        val decl = program.classes[name] ?: continue
        val slots = statics.getOrPut(name) { mutableMapOf() }
        frames += JavaInterpreter.Frame(null, currentClass = name)
        try {
            if (decl.kind == ClassDecl.Kind.ENUM) {
                val constants = mutableListOf<JavaObject>()
                decl.enumConstants.forEachIndexed { index, constant ->
                    val obj = JavaObject(JavaObject.Kind.PLAIN, name)
                    obj.fields["\$name"] = JValue.str(constant.name)
                    obj.fields["\$ordinal"] = JValue.IntV(index)
                    initializeFields(obj, name)
                    runConstructor(name, obj, evaluateArgs(constant.args), constant.line)
                    constants += obj
                    slots[constant.name] = JavaInterpreter.Slot(JType.Obj(name), JValue.Obj(obj), true)
                }
                enumConstants[name] = constants
            }
            for (field in decl.fields.filter { it.isStatic }) {
                var value = JValue.defaultValue(field.type)
                field.initializer?.let { value = coerce(evaluate(it, field.type), field.type, field.line, "Das Feld „${field.name}“") }
                slots[field.name] = JavaInterpreter.Slot(field.type, value, field.isFinal)
            }
        } finally {
            frames.removeAt(frames.lastIndex)
        }
    }
}

// MARK: - Objekte erzeugen

internal fun JavaInterpreter.instantiate(className: String, args: List<JValue>, line: Int): JValue {
    val decl = program.classes[className] ?: return JavaCollections.construct(className, args, line, this)
    when {
        decl.kind == ClassDecl.Kind.INTERFACE ->
            throw JavaProblem.syntax("Von einem Interface ($className) kann man kein Objekt erzeugen – nur von einer Klasse, die es umsetzt.", line)
        decl.kind == ClassDecl.Kind.ENUM ->
            throw JavaProblem.syntax("Enum-Werte gibt es nur als Konstanten ($className.NAME) – mit new geht das nicht.", line)
        decl.isAbstract -> throw JavaProblem.syntax("$className ist abstract – davon kann man kein Objekt erzeugen, nur von einer Unterklasse.", line)
    }
    val obj = JavaObject(JavaObject.Kind.PLAIN, className)
    initializeFields(obj, className)
    runConstructor(className, obj, args, line)
    return JValue.Obj(obj)
}

/** Alle Objektfelder der Klasse und ihrer Oberklassen mit Standardwerten anlegen (Oberklasse zuerst). */
internal fun JavaInterpreter.initializeFields(obj: JavaObject, className: String) {
    if (isThrowableClass(className)) {
        obj.fields["\$message"] = JValue.Null
        obj.fields["\$cause"] = JValue.Null
    }
    for (decl in classChain(className).asReversed()) {
        for (component in decl.recordComponents) {
            obj.fieldTypes[component.name] = component.type
            obj.fields[component.name] = JValue.defaultValue(component.type)
            obj.fieldOrder += component.name
            obj.fieldOwners[component.name] = decl.name
            obj.privateFields += component.name
        }
        for (field in decl.fields.filter { !it.isStatic }) {
            obj.fieldTypes[field.name] = field.type
            obj.fields[field.name] = JValue.defaultValue(field.type)
            if (field.name !in obj.fieldOrder) obj.fieldOrder += field.name
            obj.fieldOwners[field.name] = decl.name
            if (field.isPrivate) obj.privateFields += field.name else obj.privateFields -= field.name
            if (field.isFinal) obj.finalFields += field.name
        }
    }
}

private fun pseudoMethod(className: String, parameters: List<Parameter>, line: Int) =
    Method(className, JType.VoidT, parameters, emptyList(), line, isStatic = false, owner = className)

/** Konstruktor ausführen – wie Java: this(…) oder super(…) zuerst, dann Feld-Startwerte, dann der Rest. */
internal fun JavaInterpreter.runConstructor(className: String, obj: JavaObject, args: List<JValue>, line: Int) {
    val decl = program.classes[className] ?: return
    if (frames.size >= JavaInterpreter.MAX_CALL_DEPTH) {
        throw JavaProblem.runtime("StackOverflowError: Konstruktoren rufen sich immer wieder gegenseitig auf.", line)
    }
    // Record ohne eigenen Konstruktor: Werte der Reihe nach in die Felder.
    if (decl.kind == ClassDecl.Kind.RECORD && decl.constructors.none { it.parameters.size == decl.recordComponents.size } &&
        args.size == decl.recordComponents.size
    ) {
        decl.recordComponents.zip(args).forEach { (component, value) ->
            obj.fields[component.name] = coerce(value, component.type, line, "Das Feld „${component.name}“ von $className")
        }
        return
    }
    if (decl.constructors.isEmpty()) {
        if (args.isNotEmpty()) {
            throw JavaProblem.syntax("$className hat keinen Konstruktor mit ${args.size} Wert(en) – nur den leeren Standard-Konstruktor.", line)
        }
        frames += JavaInterpreter.Frame(pseudoMethod(className, emptyList(), decl.line), obj, className)
        try {
            runSuperConstructor(decl, obj, emptyList(), line)
            runFieldInitializers(decl, obj)
        } finally {
            frames.removeAt(frames.lastIndex)
        }
        return
    }
    val matching = decl.constructors.filter { it.parameters.size == args.size }
    if (matching.isEmpty()) {
        val counts = decl.constructors.map { it.parameters.size }.toSortedSet().joinToString(" oder ")
        throw JavaProblem.syntax("Der Konstruktor von $className erwartet $counts Wert(e), bekommt aber ${args.size}.", line)
    }
    val pseudos = matching.map { pseudoMethod(className, it.parameters, it.line) }
    val constructor = matching[pseudos.indexOf(selectOverload(pseudos, args, className, line))]
    if (constructor.isPrivate && topLevel(frame.currentClass) != topLevel(className)) {
        throw JavaProblem.syntax("Der Konstruktor von $className ist private – von außen kann man so kein Objekt erzeugen.", line)
    }
    val newFrame = JavaInterpreter.Frame(pseudoMethod(className, constructor.parameters, constructor.line), obj, className)
    constructor.parameters.zip(args).forEach { (p, a) ->
        newFrame.scopes[0][p.name] = JavaInterpreter.Slot(p.type, coerce(a, p.type, line, "Der Parameter „${p.name}“ des Konstruktors von $className"), false)
    }
    frames += newFrame
    try {
        var body = constructor.body
        val first = (body.firstOrNull() as? Stmt.ExprStmt)?.expr as? Expr.Call
        if (first != null && first.target == null && first.name == "this") {
            runConstructor(className, obj, evaluateArgs(first.args), first.line)
            body = body.drop(1)
        } else {
            var superArgs = emptyList<JValue>()
            if (first != null && first.target == null && first.name == "super") {
                superArgs = evaluateArgs(first.args)
                body = body.drop(1)
            }
            runSuperConstructor(decl, obj, superArgs, line)
            runFieldInitializers(decl, obj)
        }
        for (statement in body) {
            if (execute(statement) is JavaInterpreter.Flow.Returned) {
                if (constructor.isCompact) throw JavaProblem.syntax("In einem kompakten Record-Konstruktor ist return nicht erlaubt.", statement.line)
                break
            }
        }
        if (constructor.isCompact) {
            // Erst nach dem kompakten Konstruktor kommen die (evtl. geänderten) Werte in die Felder.
            for (component in decl.recordComponents) obj.fields[component.name] = newFrame.scopes[0][component.name]?.value ?: JValue.Null
        }
    } finally {
        frames.removeAt(frames.lastIndex)
    }
}

private fun JavaInterpreter.runSuperConstructor(decl: ClassDecl, obj: JavaObject, args: List<JValue>, line: Int) {
    val parent = decl.superclass
    if (parent == null || parent == "Object") {
        if (args.isNotEmpty()) throw JavaProblem.syntax("super(…) mit Werten geht nur, wenn die Klasse von einer anderen erbt (extends).", line)
        return
    }
    if (program.classes.containsKey(parent)) {
        runConstructor(parent, obj, args, line)
        return
    }
    // Eingebaute Exception als Oberklasse: super(message) bzw. super(message, cause).
    when (args.size) {
        0 -> Unit
        1 -> {
            val cause = (args[0] as? JValue.Obj)?.obj
            if (cause != null && (isThrowableClass(cause.className) || cause.kind == JavaObject.Kind.THROWABLE)) {
                obj.fields["\$cause"] = args[0]
                obj.fields["\$message"] = JValue.str(stringify(args[0], line))
            } else {
                obj.fields["\$message"] = coerce(args[0], JType.StringT, line, "Die Meldung der Exception")
            }
        }
        2 -> {
            obj.fields["\$message"] = coerce(args[0], JType.StringT, line, "Die Meldung der Exception")
            obj.fields["\$cause"] = args[1]
        }
        else -> throw JavaProblem.syntax("$parent hat keinen Konstruktor mit ${args.size} Werten.", line)
    }
}

private fun JavaInterpreter.runFieldInitializers(decl: ClassDecl, obj: JavaObject) {
    for (field in decl.fields) {
        if (field.isStatic) continue
        val initializer = field.initializer ?: continue
        obj.fields[field.name] = coerce(evaluate(initializer, field.type), field.type, field.line, "Das Feld „${field.name}“")
    }
}

// MARK: - Felder von Objekten

internal fun JavaInterpreter.readField(obj: JavaObject, name: String, line: Int): JValue {
    val value = obj.fields[name]
    if (obj.fieldTypes[name] == null || value == null) {
        val decl = program.classes[obj.className]
        if (obj.kind == JavaObject.Kind.PLAIN && decl?.kind == ClassDecl.Kind.RECORD) {
            throw JavaProblem.syntax("Der Record ${obj.className} hat kein Feld „$name“.", line)
        }
        throw JavaProblem.syntax("Die Klasse ${obj.className} hat kein Feld „$name“.", line)
    }
    if (name in obj.privateFields && topLevel(frame.currentClass) != topLevel(obj.fieldOwners[name])) {
        throw JavaProblem.syntax("„$name“ ist private – von außerhalb der Klasse ${obj.fieldOwners[name] ?: obj.className} darf man nicht direkt darauf zugreifen. Nimm eine Methode (z. B. einen Getter).", line)
    }
    return value
}

internal fun JavaInterpreter.writeField(obj: JavaObject, name: String, value: JValue, line: Int): JValue {
    val type = obj.fieldTypes[name] ?: throw JavaProblem.syntax("Die Klasse ${obj.className} hat kein Feld „$name“.", line)
    if (name in obj.privateFields && topLevel(frame.currentClass) != topLevel(obj.fieldOwners[name])) {
        throw JavaProblem.syntax("„$name“ ist private – von außerhalb der Klasse darf man es nicht ändern. Nimm eine Methode (z. B. einen Setter).", line)
    }
    val inConstructor = frame.thisObject === obj && frame.method?.name == obj.fieldOwners[name] && frame.method?.isStatic == false
    val isRecordField = program.classes[obj.className]?.kind == ClassDecl.Kind.RECORD && obj.fieldOwners[name] == obj.className
    if ((name in obj.finalFields || isRecordField) && !inConstructor) {
        throw JavaProblem.syntax("„$name“ ist final – der Wert darf nach dem Konstruktor nicht mehr geändert werden.", line)
    }
    val stored = coerce(value, type, line, "Das Feld „$name“")
    obj.fields[name] = stored
    return stored
}

/** `this.x`, `Klasse.feld`, `Enum.KONSTANTE` – oder null, wenn der normale Weg greift. */
internal fun JavaInterpreter.objectField(base: Expr, name: String, line: Int): JValue? = when {
    base is Expr.This || base is Expr.SuperRef -> {
        val obj = frame.thisObject ?: throw JavaProblem.syntax("this gibt es nur in Methoden eines Objekts – in einer static-Methode gibt es kein this.", base.line)
        readField(obj, name, line)
    }
    base is Expr.Name && isTypeName(base.name) -> {
        val className = base.name
        if (className == program.mainClass) {
            globals[name]?.value ?: throw JavaProblem.syntax("$className hat kein statisches Feld „$name“.", line)
        } else {
            staticSlot(name, className)?.second?.value
                ?: if (name == "length" || name == "class") null
                else throw JavaProblem.syntax("$className hat kein statisches Feld „$name“ – Objektfelder gibt es nur an einem Objekt (objekt.$name).", line)
        }
    }
    else -> null
}

internal fun JavaInterpreter.storeField(base: Expr, name: String, value: JValue, line: Int): JValue? = when {
    base is Expr.This || base is Expr.SuperRef -> {
        val obj = frame.thisObject ?: throw JavaProblem.syntax("this gibt es nur in Methoden eines Objekts – in einer static-Methode gibt es kein this.", line)
        writeField(obj, name, value, line)
    }
    base is Expr.Name && isTypeName(base.name) -> {
        if (base.name == program.mainClass) {
            write(name, value, line)
        } else {
            val found = staticSlot(name, base.name) ?: throw JavaProblem.syntax("${base.name} hat kein statisches Feld „$name“.", line)
            writeStatic(found.first, name, value, line)
        }
    }
    else -> when (val target = evaluate(base)) {
        is JValue.Obj -> writeField(target.obj, name, value, line)
        JValue.Null -> throw JavaProblem.exception("NullPointerException", null, "Das Objekt ist null – es hat kein Feld „$name“.", line)
        else -> null
    }
}

internal fun JavaInterpreter.fieldType(base: Expr, name: String): JType? = when {
    base is Expr.This || base is Expr.SuperRef -> frame.thisObject?.fieldTypes?.get(name)
    base is Expr.Name && isTypeName(base.name) ->
        if (base.name == program.mainClass) globals[name]?.type else staticSlot(name, base.name)?.second?.type
    else -> (evaluate(base) as? JValue.Obj)?.obj?.fieldTypes?.get(name)
}

/** Statischer Typ eines Empfängers (Variable, Feld, this) – für Javas Prüfung, welche Methoden es gibt. */
internal fun JavaInterpreter.declaredType(target: Expr): JType? = when (target) {
    is Expr.Name -> lookup(target.name)?.type
    is Expr.This -> frame.currentClass?.let { JType.Obj(it) }
    is Expr.Field -> fieldType(target.base, target.name)
    else -> null
}

// MARK: - Methoden aufrufen

/** Aufrufe auf this, super, eigene Klassen (statisch) und Enums – oder null für den normalen Weg. */
internal fun JavaInterpreter.callOnClassOrObject(target: Expr, name: String, argExprs: List<Expr>, line: Int): JValue? {
    when {
        target is Expr.This -> {
            val obj = frame.thisObject ?: throw JavaProblem.syntax("this gibt es nur in Methoden eines Objekts – in einer static-Methode gibt es kein this.", target.line)
            return callMethod(obj, name, evaluateArgs(argExprs), line, null)
        }
        target is Expr.SuperRef -> {
            val obj = frame.thisObject
            val current = frame.currentClass
            if (obj == null || current == null) throw JavaProblem.syntax("super gibt es nur in Methoden eines Objekts.", line)
            val args = evaluateArgs(argExprs)
            val parent = program.classes[current]?.superclass
            if (parent != null && program.classes.containsKey(parent)) {
                findMethod(name, parent, args, false, line)?.let { return invoke(it, args, line, obj) }
            }
            // Ohne eigene Oberklassen-Methode: Javas Standard (Object bzw. Exception).
            return builtinObjectMethod(obj, name, args, line, skipUserMethods = true)
                ?: throw JavaProblem.syntax("Die Oberklasse hat keine Methode $name(…).", line)
        }
        target is Expr.Name && isTypeName(target.name) -> {
            val className = target.name
            val args = evaluateArgs(argExprs)
            if (className == program.mainClass) {
                val candidates = program.methods[name]?.filter { it.parameters.size == args.size }.orEmpty()
                if (candidates.isEmpty()) throw JavaProblem.syntax("$className hat keine statische Methode $name mit ${args.size} Wert(en).", line)
                return invoke(selectOverload(candidates, args, name, line), args, line)
            }
            val decl = program.classes[className]
            if (decl?.kind == ClassDecl.Kind.ENUM) {
                if (name == "values" && args.isEmpty()) {
                    return JValue.ArrV(JavaArray(JType.Obj(className), enumConstants[className].orEmpty().map { JValue.Obj(it) }.toMutableList()))
                }
                if (name == "valueOf" && args.size == 1) {
                    val wanted = args[0].stringValue ?: ""
                    enumConstants[className]?.firstOrNull { it.fields["\$name"]?.stringValue == wanted }?.let { return JValue.Obj(it) }
                    throw JavaProblem.exception(
                        "IllegalArgumentException", "No enum constant ${decl.binaryName.replace('$', '.')}.$wanted",
                        "Die Konstante „$wanted“ gibt es im Enum $className nicht.", line,
                    )
                }
            }
            findMethod(name, className, args, true, line)?.let {
                checkPrivate(it, line)
                return invoke(it, args, line)
            }
            if (findMethod(name, className, args, false, line) != null) {
                throw JavaProblem.syntax("$name(…) ist eine Objektmethode – man ruft sie an einem Objekt auf (objekt.$name(…)), nicht an der Klasse $className.", line)
            }
            throw JavaProblem.syntax("Die Klasse $className hat keine statische Methode $name mit ${args.size} Wert(en).", line)
        }
        else -> return null
    }
}

/** Unqualifizierter Aufruf `name(…)` in einer Klasse: erst Objektmethoden (über this), dann statische Methoden. */
private val inheritedMethods = setOf("getClass", "toString", "hashCode", "equals", "name", "ordinal", "compareTo", "getMessage", "getCause")

internal fun JavaInterpreter.callInClassContext(name: String, argExprs: List<Expr>, line: Int): JValue? {
    val className = frame.currentClass ?: program.mainClass ?: return null
    val decl = program.classes[className] ?: return null
    if (!hasMethod(name, className)) {
        // Geerbte Standardmethoden ohne this davor: getClass(), toString(), name(), values() …
        val obj = frame.thisObject
        if (obj != null && name in inheritedMethods) {
            builtinObjectMethod(obj, name, evaluateArgs(argExprs), line, skipUserMethods = true)?.let { return it }
        }
        if (decl.kind == ClassDecl.Kind.ENUM && (name == "values" || name == "valueOf")) {
            return evaluate(Expr.Call(Expr.Name(className, line), name, argExprs, line))
        }
        return null
    }
    if (className == program.mainClass && frame.thisObject == null && program.methods.containsKey(name)) return null
    val args = evaluateArgs(argExprs)
    frame.thisObject?.let { obj ->
        val method = findMethod(name, obj.className, args, null, line) ?: findMethod(name, className, args, null, line)
        if (method != null) return invoke(method, args, line, obj)
    }
    findMethod(name, className, args, true, line)?.let { return invoke(it, args, line) }
    if (findMethod(name, className, args, false, line) != null) {
        throw JavaProblem.syntax("$name(…) ist eine Objektmethode – in einer static-Methode gibt es aber kein Objekt (this). Erzeuge ein Objekt und rufe sie daran auf, oder mach die Methode static.", line)
    }
    if (className == program.mainClass) {
        val candidates = program.methods[name]?.filter { it.parameters.size == args.size }.orEmpty()
        if (candidates.isNotEmpty()) return invoke(selectOverload(candidates, args, name, line), args, line)
    }
    throw JavaProblem.syntax("$name erwartet eine andere Anzahl von Werten – mit ${args.size} Wert(en) gibt es die Methode nicht.", line)
}

private fun JavaInterpreter.checkPrivate(method: Method, line: Int) {
    if (method.isPrivate && topLevel(frame.currentClass) != topLevel(method.owner)) {
        throw JavaProblem.syntax("${method.name}(…) ist private – nur die Klasse ${method.owner ?: ""} selbst darf sie aufrufen.", line)
    }
}

/** Methode an einem Objekt aufrufen: eigene Methoden (mit Polymorphie), sonst Javas Standardmethoden. */
internal fun JavaInterpreter.callMethod(obj: JavaObject, name: String, args: List<JValue>, line: Int, staticType: JType?): JValue {
    if (obj.kind != JavaObject.Kind.PLAIN || !program.classes.containsKey(obj.className)) {
        if (obj.kind == JavaObject.Kind.PLAIN) builtinObjectMethod(obj, name, args, line, skipUserMethods = true)?.let { return it }
        return JavaCollections.callObject(obj, name, args, line, this)
    }
    // Java prüft beim Übersetzen den Typ der Variablen: Tier t = new Hund(); t.bellen(); geht nicht.
    val declaredName = (staticType as? JType.Obj)?.let { staticType.className }
    if (declaredName != null && declaredName != obj.className && program.classes.containsKey(declaredName) && !hasMethod(name, declaredName) &&
        name !in setOf("toString", "equals", "hashCode", "getClass", "name", "ordinal", "compareTo", "getMessage")
    ) {
        val declared = (staticType as JType.Obj).name
        throw JavaProblem.syntax("Die Methode $name(…) gibt es in $declared nicht. Die Variable hat den Typ $declared – auch wenn darin ein ${obj.className} steckt, kennt Java nur die Methoden von $declared.", line)
    }
    findMethod(name, obj.className, args, null, line)?.let {
        checkPrivate(it, line)
        return invoke(it, args, line, if (it.isStatic) null else obj)
    }
    builtinObjectMethod(obj, name, args, line, skipUserMethods = true)?.let { return it }
    if (hasMethod(name, obj.className)) {
        throw JavaProblem.syntax("$name erwartet eine andere Anzahl von Werten – mit ${args.size} Wert(en) gibt es die Methode in ${obj.className} nicht.", line)
    }
    throw JavaProblem.syntax("Die Methode $name(…) gibt es in der Klasse ${obj.className} nicht.", line)
}

/**
 * Methoden, die jedes Objekt von Java mitbekommt: toString, equals, hashCode, getClass –
 * bei Enums name/ordinal, bei Records die Lese-Methoden, bei Exceptions getMessage.
 */
internal fun JavaInterpreter.builtinObjectMethod(obj: JavaObject, name: String, args: List<JValue>, line: Int, skipUserMethods: Boolean): JValue? {
    val decl = program.classes[obj.className]
    when {
        name == "toString" && args.isEmpty() -> return JValue.str(defaultToString(obj, line))
        name == "equals" && args.size == 1 -> {
            val other = (args[0] as? JValue.Obj)?.obj
            if (decl?.kind == ClassDecl.Kind.RECORD && other != null && other.className == obj.className) {
                return JValue.BoolV(decl.recordComponents.all { javaEquals(obj.fields[it.name] ?: JValue.Null, other.fields[it.name] ?: JValue.Null, line) })
            }
            return JValue.BoolV(other === obj)
        }
        name == "hashCode" && args.isEmpty() -> return JValue.IntV(javaHash(JValue.Obj(obj), line, userMethods = !skipUserMethods))
        name == "getClass" && args.isEmpty() -> {
            val info = JavaObject(JavaObject.Kind.CLASS_INFO, "Class")
            info.fields["name"] = JValue.str(decl?.binaryName ?: JavaBuiltins.qualifiedName(obj.className))
            info.fields["simpleName"] = JValue.str(obj.className)
            return JValue.Obj(info)
        }
    }
    if (decl?.kind == ClassDecl.Kind.ENUM) {
        when {
            name == "name" && args.isEmpty() -> return obj.fields["\$name"]
            name == "ordinal" && args.isEmpty() -> return obj.fields["\$ordinal"]
            name == "compareTo" && args.size == 1 -> {
                val a = (obj.fields["\$ordinal"] as? JValue.IntV)?.value
                val b = ((args[0] as? JValue.Obj)?.obj?.fields?.get("\$ordinal") as? JValue.IntV)?.value
                if (a == null || b == null) throw JavaProblem.syntax("compareTo vergleicht nur Werte desselben Enums.", line)
                return JValue.IntV(a - b)
            }
        }
    }
    if (decl?.kind == ClassDecl.Kind.RECORD && args.isEmpty() && decl.recordComponents.any { it.name == name }) return obj.fields[name]
    if (isThrowableClass(obj.className) || obj.kind == JavaObject.Kind.THROWABLE) {
        when {
            (name == "getMessage" || name == "getLocalizedMessage") && args.isEmpty() -> return obj.fields["\$message"] ?: JValue.Null
            name == "getCause" && args.isEmpty() -> return obj.fields["\$cause"] ?: JValue.Null
            name == "printStackTrace" && args.isEmpty() -> return JValue.Void // Java schreibt nach System.err – nicht in die Ausgabe.
        }
    }
    return null
}

/** Standard-toString: Enum → Name, Record → Punkt[x=1, y=2], Exception → Klasse: Meldung, sonst Klasse@Adresse. */
internal fun JavaInterpreter.defaultToString(obj: JavaObject, line: Int): String {
    obj.fields["\$name"]?.stringValue?.let { return it }
    val decl = program.classes[obj.className]
    if (decl?.kind == ClassDecl.Kind.RECORD) {
        return "${obj.className}[" + decl.recordComponents.joinToString(", ") { "${it.name}=${stringify(obj.fields[it.name] ?: JValue.Null, line)}" } + "]"
    }
    if (isThrowableClass(obj.className) || obj.kind == JavaObject.Kind.THROWABLE) {
        val qualified = decl?.binaryName ?: JavaBuiltins.qualifiedName(obj.className)
        val message = obj.fields["\$message"]
        return if (message is JValue.StrV) "$qualified: ${message.ref.text}" else qualified
    }
    return "${decl?.binaryName ?: JavaBuiltins.qualifiedName(obj.className)}@${Integer.toHexString(obj.serial)}"
}

/** Text eines Werts wie bei println und String-Verkettung – mit eigenem toString(). */
internal fun JavaInterpreter.stringify(value: JValue, line: Int): String {
    if (value !is JValue.Obj) return value.javaString
    val obj = value.obj
    return when (obj.kind) {
        JavaObject.Kind.PLAIN -> {
            if (program.classes.containsKey(obj.className)) {
                findMethod("toString", obj.className, emptyList(), false, line)?.let {
                    val result = invoke(it, emptyList(), line, obj)
                    return result.stringValue ?: result.javaString
                }
            }
            defaultToString(obj, line)
        }
        JavaObject.Kind.LIST, JavaObject.Kind.SET, JavaObject.Kind.DEQUE ->
            "[" + iterationOrder(obj).joinToString(", ") { if (it is JValue.Obj && it.obj === obj) "(this Collection)" else stringify(it, line) } + "]"
        JavaObject.Kind.MAP -> "{" + mapEntries(obj).joinToString(", ") { (k, v) -> "${stringify(k, line)}=${stringify(v, line)}" } + "}"
        JavaObject.Kind.BUILDER -> obj.text
        JavaObject.Kind.THROWABLE -> defaultToString(obj, line)
        JavaObject.Kind.CLASS_INFO -> "class " + (obj.fields["name"]?.javaString ?: "")
        JavaObject.Kind.ENTRY -> "${stringify(obj.elements.firstOrNull() ?: JValue.Null, line)}=${stringify(obj.values.firstOrNull() ?: JValue.Null, line)}"
    }
}

// MARK: - Typen prüfen

/** Passt der Wert zum Muster? Dann die neuen Variablen, sonst null. */
internal fun JavaInterpreter.match(value: JValue, pattern: Pattern, line: Int): List<Pair<String, JavaInterpreter.Slot>>? = when (pattern) {
    is Pattern.Binding -> when {
        pattern.type == JType.Inferred -> listOf(pattern.name to JavaInterpreter.Slot(value.type, value, false))
        pattern.type.isPrimitive -> listOf(pattern.name to JavaInterpreter.Slot(pattern.type, coerce(value, pattern.type, line, "Das Feld im Record-Muster"), false))
        // Ein Typ-Muster im Record passt auch zu null, wenn der Typ alles abdeckt – sonst wie instanceof.
        value == JValue.Null || isInstance(value, pattern.type) -> listOf(pattern.name to JavaInterpreter.Slot(pattern.type, value, false))
        else -> null
    }
    is Pattern.Record -> {
        val obj = (value as? JValue.Obj)?.obj
        if (obj == null || !isInstance(value, JType.Obj(pattern.className))) {
            null
        } else {
            val decl = program.classes[pattern.className]
            if (decl == null || decl.kind != ClassDecl.Kind.RECORD) throw JavaProblem.syntax("${pattern.className}(…) als Muster geht nur bei Records.", line)
            if (decl.recordComponents.size != pattern.parts.size) {
                throw JavaProblem.syntax("Der Record ${pattern.className} hat ${decl.recordComponents.size} Felder – im Muster stehen aber ${pattern.parts.size}.", line)
            }
            val bindings = mutableListOf<Pair<String, JavaInterpreter.Slot>>()
            var matches = true
            for ((component, part) in decl.recordComponents.zip(pattern.parts)) {
                val inner = match(obj.fields[component.name] ?: JValue.Null, part, line)
                if (inner == null) { matches = false; break }
                bindings += inner
            }
            if (matches) bindings else null
        }
    }
}

/** instanceof: Passt der Wert zum Typ? null passt nie. */
internal fun JavaInterpreter.isInstance(value: JValue, type: JType): Boolean = when {
    value == JValue.Null -> false
    type == JType.StringT -> value is JValue.StrV
    type is JType.Obj -> canAssign(value, type.name)
    type is JType.Arr -> value is JValue.ArrV && value.array.elementType == type.element
    else -> value.type == type
}

/** Darf der Wert in eine Variable vom Typ [typeName]? (Mit Autoboxing: int → Integer usw.) */
internal fun JavaInterpreter.canAssign(value: JValue, typeName: String): Boolean {
    val base = typeName.substringBefore('<')
    return when (value) {
        JValue.Null -> true
        is JValue.Obj -> isSubtype(value.obj.className, base)
        is JValue.StrV -> base in setOf("Object", "CharSequence", "Comparable", "String")
        is JValue.IntV -> base in setOf("Integer", "Number", "Object", "Comparable")
        is JValue.LongV -> base in setOf("Long", "Number", "Object", "Comparable")
        is JValue.DoubleV -> base in setOf("Double", "Number", "Object", "Comparable")
        is JValue.BoolV -> base in setOf("Boolean", "Object", "Comparable")
        is JValue.CharV -> base in setOf("Character", "Object", "Comparable")
        is JValue.ArrV -> base == "Object"
        JValue.Void -> false
    }
}

internal fun JavaInterpreter.castObject(value: JValue, typeName: String, line: Int): JValue {
    if (canAssign(value, typeName)) return value
    val from = when (value) {
        is JValue.Obj -> program.classes[value.obj.className]?.binaryName ?: JavaBuiltins.qualifiedName(value.obj.className)
        is JValue.StrV -> "java.lang.String"
        else -> value.typeName
    }
    val base = typeName.substringBefore('<')
    val to = program.classes[base]?.binaryName ?: JavaBuiltins.qualifiedName(base)
    throw JavaProblem.exception(
        "ClassCastException", "class $from cannot be cast to class $to",
        "$from lässt sich nicht in $to umwandeln – das Objekt ist gar kein $base. Prüfe vorher mit instanceof.", line,
    )
}

// MARK: - Exceptions

/** `throw wert;` – nur Exceptions dürfen geworfen werden. */
internal fun JavaInterpreter.throwing(value: JValue, line: Int): JavaProblem {
    val obj = (value as? JValue.Obj)?.obj ?: return if (value == JValue.Null) {
        JavaProblem.exception("NullPointerException", null, "throw null – geworfen werden kann nur eine Exception, nicht null.", line)
    } else {
        JavaProblem.syntax("Werfen (throw) kann man nur Exceptions, nicht ${value.typeName}.", line)
    }
    if (obj.kind != JavaObject.Kind.THROWABLE && !isThrowableClass(obj.className)) {
        return JavaProblem.syntax("Werfen (throw) kann man nur Exceptions – ${obj.className} erbt nicht von Exception.", line)
    }
    val message = obj.fields["\$message"]?.stringValue
    val name = program.classes[obj.className]?.name ?: obj.className
    return JavaProblem(JavaProblem.Kind.RUNTIME, message?.let { "$name: $it" } ?: "$name wurde geworfen und nicht aufgefangen.", line).also {
        it.exceptionClass = obj.className
        it.javaMessage = message
        it.thrown = value
    }
}

/** try/catch/finally – fängt Laufzeitfehler, deren Exception zu einem catch passt. */
internal fun JavaInterpreter.executeTry(body: List<Stmt>, catches: List<Catch>, finallyBody: List<Stmt>?): JavaInterpreter.Flow {
    var flow: JavaInterpreter.Flow = JavaInterpreter.Flow.Normal
    var pending: JavaProblem? = null
    try {
        flow = executeBlock(body)
    } catch (error: JavaProblem) {
        val exceptionClass = error.exceptionClass ?: "RuntimeException"
        val handler = if (error.kind == JavaProblem.Kind.RUNTIME) catches.firstOrNull { h -> h.types.any { isSubtype(exceptionClass, it) } } else null
        if (handler != null) {
            val exception = error.thrown ?: makeThrowable(error)
            frame.scopes += mutableMapOf(handler.name to JavaInterpreter.Slot(JType.Obj(exceptionClass), exception, false))
            try {
                flow = executeBlock(handler.body)
            } catch (inner: JavaProblem) {
                pending = inner
            } finally {
                frame.scopes.removeAt(frame.scopes.lastIndex)
            }
        } else {
            pending = error
        }
    }
    if (finallyBody != null) {
        val finallyFlow = executeBlock(finallyBody)
        if (finallyFlow != JavaInterpreter.Flow.Normal) return finallyFlow
    }
    pending?.let { throw it }
    return flow
}

/** Exception-Objekt für einen Laufzeitfehler des Interpreters (z. B. / by zero). */
private fun makeThrowable(problem: JavaProblem): JValue {
    val obj = JavaObject(JavaObject.Kind.THROWABLE, problem.exceptionClass ?: "RuntimeException")
    obj.fields["\$message"] = problem.javaMessage?.let { JValue.str(it) } ?: JValue.Null
    obj.fields["\$cause"] = JValue.Null
    return JValue.Obj(obj)
}

// MARK: - Gleichheit, Hash, Reihenfolge (für Sammlungen)

internal fun JavaInterpreter.javaEquals(a: JValue, b: JValue, line: Int): Boolean {
    if (a == JValue.Null || b == JValue.Null) return a == b
    return when {
        a is JValue.StrV && b is JValue.StrV -> a.ref.text == b.ref.text
        a is JValue.BoolV && b is JValue.BoolV -> a.value == b.value
        a is JValue.CharV && b is JValue.CharV -> a.value == b.value
        a is JValue.IntV && b is JValue.IntV -> a.value == b.value
        a is JValue.LongV && b is JValue.LongV -> a.value == b.value
        a is JValue.DoubleV && b is JValue.DoubleV -> a.value.toRawBits() == b.value.toRawBits() || a.value == b.value
        a is JValue.Obj -> {
            val x = a.obj
            if (x.kind == JavaObject.Kind.PLAIN && program.classes.containsKey(x.className)) {
                findMethod("equals", x.className, listOf(b), false, line)?.let { return (invoke(it, listOf(b), line, x) as? JValue.BoolV)?.value ?: false }
            }
            if (x.kind == JavaObject.Kind.PLAIN) return (builtinObjectMethod(x, "equals", listOf(b), line, skipUserMethods = true) as? JValue.BoolV)?.value ?: false
            val y = (b as? JValue.Obj)?.obj ?: return false
            if (x === y) return true
            when {
                x.kind == JavaObject.Kind.LIST && y.kind == JavaObject.Kind.LIST ->
                    x.elements.size == y.elements.size && x.elements.zip(y.elements).all { (p, q) -> javaEquals(p, q, line) }
                x.kind == JavaObject.Kind.SET && y.kind == JavaObject.Kind.SET ->
                    x.elements.size == y.elements.size && x.elements.all { indexOfKey(it, y, line) != null }
                x.kind == JavaObject.Kind.MAP && y.kind == JavaObject.Kind.MAP ->
                    x.elements.size == y.elements.size && x.elements.zip(x.values).all { (key, value) ->
                        val index = indexOfKey(key, y, line)
                        index != null && javaEquals(value, y.values[index], line)
                    }
                else -> false
            }
        }
        else -> false
    }
}

internal fun JavaInterpreter.javaHash(value: JValue, line: Int, userMethods: Boolean = true): Int = when (value) {
    JValue.Null, JValue.Void -> 0
    is JValue.IntV -> value.value
    is JValue.LongV -> java.lang.Long.hashCode(value.value)
    is JValue.DoubleV -> java.lang.Double.hashCode(value.value)
    is JValue.BoolV -> if (value.value) 1231 else 1237
    is JValue.CharV -> value.value.code
    is JValue.StrV -> value.ref.text.hashCode()
    is JValue.ArrV -> value.array.serial
    is JValue.Obj -> {
        val obj = value.obj
        when (obj.kind) {
            JavaObject.Kind.PLAIN -> {
                val decl = program.classes[obj.className]
                val custom = if (userMethods && decl != null) findMethod("hashCode", obj.className, emptyList(), false, line) else null
                val customHash = custom?.let { invoke(it, emptyList(), line, obj) as? JValue.IntV }
                when {
                    customHash != null -> customHash.value
                    decl?.kind == ClassDecl.Kind.RECORD -> decl.recordComponents.fold(0) { hash, c -> hash * 31 + javaHash(obj.fields[c.name] ?: JValue.Null, line) }
                    else -> obj.serial
                }
            }
            JavaObject.Kind.LIST -> obj.elements.fold(1) { hash, e -> hash * 31 + javaHash(e, line) }
            JavaObject.Kind.SET -> obj.elements.sumOf { javaHash(it, line) }
            JavaObject.Kind.MAP -> obj.elements.zip(obj.values).sumOf { (k, v) -> javaHash(k, line) xor javaHash(v, line) }
            else -> obj.serial
        }
    }
}

/** Natürliche Reihenfolge wie compareTo – für TreeMap, TreeSet und Collections.sort. */
internal fun JavaInterpreter.javaCompare(a: JValue, b: JValue, line: Int): Int {
    val x = Num.of(a); val y = Num.of(b)
    if (x != null && y != null) return Num.compare(x, y).coerceIn(-1, 1)
    when {
        a is JValue.StrV && b is JValue.StrV -> return a.ref.text.compareTo(b.ref.text)
        a is JValue.BoolV && b is JValue.BoolV -> return if (a.value == b.value) 0 else if (a.value) 1 else -1
        a == JValue.Null || b == JValue.Null ->
            throw JavaProblem.exception("NullPointerException", null, "null lässt sich nicht vergleichen (z. B. in einer TreeMap oder beim Sortieren).", line)
        a is JValue.Obj && a.obj.kind == JavaObject.Kind.PLAIN && program.classes.containsKey(a.obj.className) -> {
            findMethod("compareTo", a.obj.className, listOf(b), false, line)?.let { method ->
                (invoke(method, listOf(b), line, a.obj) as? JValue.IntV)?.let { return it.value }
            }
            val p = (a.obj.fields["\$ordinal"] as? JValue.IntV)?.value
            val q = ((b as? JValue.Obj)?.obj?.fields?.get("\$ordinal") as? JValue.IntV)?.value
            if (program.classes[a.obj.className]?.kind == ClassDecl.Kind.ENUM && p != null && q != null) return p - q
        }
    }
    val name = (a as? JValue.Obj)?.obj?.className ?: a.typeName
    throw JavaProblem.exception(
        "ClassCastException", "class $name cannot be cast to class java.lang.Comparable",
        "$name lässt sich nicht sortieren – die Klasse braucht compareTo (implements Comparable).", line,
    )
}

// MARK: - Sammlungen durchlaufen

/** Elemente in Javas Reihenfolge: Listen wie gespeichert, HashSet nach Hash-Fächern, TreeSet sortiert. */
internal fun JavaInterpreter.iterationOrder(obj: JavaObject): List<JValue> {
    if (obj.order != JavaObject.Order.HASH) return obj.elements.toList()
    val buckets = obj.elements.map { JavaHashing.bucket(javaHash(it, 0), obj.capacity) }
    return obj.elements.indices.sortedWith(compareBy<Int>({ buckets[it] }, { obj.sequence[it] })).map { obj.elements[it] }
}

internal fun JavaInterpreter.mapEntries(obj: JavaObject): List<Pair<JValue, JValue>> =
    iterationOrder(obj).map { key -> key to obj.values[indexOfKey(key, obj, 0) ?: 0] }

internal fun JavaInterpreter.indexOfKey(key: JValue, obj: JavaObject, line: Int): Int? {
    obj.elements.forEachIndexed { index, element -> if (javaEquals(element, key, line)) return index }
    return null
}
