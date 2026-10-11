package app.javaquest.core.interpreter

import java.util.concurrent.atomic.AtomicReference

/** Eine sichtbare Variable zum Zeitpunkt eines Programmschritts (Arena-Anzeige). */
data class JavaVariable(val name: String, val type: String, val value: String)

/** Ort, an dem ein Host-Objekt (z. B. der Roboter) aufgerufen wurde. */
data class CallContext(val line: Int, val variables: List<JavaVariable>, val output: String)

/** Stellt Objekte bereit, die ohne Deklaration benutzbar sind – etwa `robot`. */
interface JavaHost {
    val objectNames: Set<String>
    val wantsSnapshot: Boolean
    fun call(objectName: String, method: String, args: List<JValue>, context: CallContext): JValue
}

data class JavaWarning(val message: String, val line: Int)

/** Ein Schritt beim Zusehen: Diese Zeile ist als Nächstes dran – mit allem, was bis dahin passiert ist. */
data class JavaTraceStep(
    /** Zeile, die gleich ausgeführt wird; `null` beim letzten Bild (Programm zu Ende). */
    val line: Int?,
    /** Methode, in der das Programm gerade steckt (`null` = Hauptprogramm). */
    val method: String?,
    val variables: List<JavaVariable>,
    /** Konsolenausgabe bis zu diesem Moment. */
    val output: String,
)

/** Der aufgezeichnete Ablauf eines Programms – für „Ausführen und zusehen“. */
class JavaTrace(
    val steps: List<JavaTraceStep>,
    /** Laufzeitfehler, an dem das Programm stehen blieb. */
    val problem: JavaProblem?,
    /** Mehr Schritte als aufgezeichnet – der Ablauf zeigt nur den Anfang. */
    val isTruncated: Boolean,
) {
    /** Lohnt sich das Zusehen? Der Interpreter kennt alle Bausteine, und es passiert mehr als ein Schritt. */
    val isUseful: Boolean
        get() = steps.size >= 3 && problem?.kind != JavaProblem.Kind.SYNTAX && problem?.kind != JavaProblem.Kind.UNSUPPORTED
}

/** Sammelt die Schritte für „Ausführen und zusehen“. */
class TraceRecorder(val limit: Int) {
    val steps = mutableListOf<JavaTraceStep>()
    val isFull: Boolean get() = steps.size >= limit
}

class JavaRunResult(val output: String, val problem: JavaProblem?, val steps: Int, val warnings: List<JavaWarning>) {
    val succeeded: Boolean get() = problem == null
}

/** Führt Java-Code aus – komplett lokal, gleiche Regeln wie die iOS-App. */
object JavaRunner {
    const val DEFAULT_STEP_LIMIT = 200_000

    fun check(source: String): JavaProblem? = try { JavaParser.parse(source); null } catch (e: JavaProblem) { e }

    /** Läuft auf einem eigenen Thread mit großem Stack: tiefe Rekursion wird als StackOverflowError gemeldet. */
    fun run(source: String, stepLimit: Int = DEFAULT_STEP_LIMIT, host: JavaHost? = null): JavaRunResult {
        val result = AtomicReference<JavaRunResult>()
        val thread = Thread(null, { result.set(runDirectly(source, stepLimit, host)) }, "java-interpreter", 64L shl 20)
        thread.start()
        thread.join()
        return result.get() ?: JavaRunResult("", JavaProblem.runtime("Das Programm konnte nicht gestartet werden.", null), 0, emptyList())
    }

    private fun runDirectly(source: String, stepLimit: Int, host: JavaHost?): JavaRunResult {
        val program = try { JavaParser.parse(source) } catch (e: JavaProblem) { return JavaRunResult("", e, 0, emptyList()) }
        val interpreter = JavaInterpreter(program, stepLimit, host)
        val problem = interpreter.run()
        return JavaRunResult(interpreter.output.toString(), problem, interpreter.steps, interpreter.warnings)
    }

    /**
     * Führt das Programm aus und zeichnet jeden Schritt auf: welche Zeile dran ist, welche Variablen es gibt
     * und was schon ausgegeben wurde. Höchstens [maxSteps] Bilder – längere Läufe werden abgeschnitten.
     */
    fun trace(source: String, maxSteps: Int = 400): JavaTrace {
        val result = AtomicReference<JavaTrace>()
        val thread = Thread(null, { result.set(traceDirectly(source, maxSteps)) }, "java-trace", 64L shl 20)
        thread.start()
        thread.join()
        return result.get() ?: JavaTrace(emptyList(), JavaProblem.runtime("Das Programm konnte nicht gestartet werden.", null), false)
    }

    private fun traceDirectly(source: String, maxSteps: Int): JavaTrace {
        val program = try {
            JavaParser.parse(app.javaquest.core.JavaSource.normalizingTypography(source))
        } catch (e: JavaProblem) {
            return JavaTrace(emptyList(), e, false)
        }
        // Zusehen soll schnell gehen: Lange Programme werden nach den ersten Schritten abgeschnitten.
        val interpreter = JavaInterpreter(program, maxSteps * 20, null)
        val recorder = TraceRecorder(maxSteps)
        interpreter.recorder = recorder
        val problem = interpreter.run()
        val stoppedEarly = recorder.isFull || problem?.kind == JavaProblem.Kind.STEP_LIMIT
        if (!stoppedEarly) {
            recorder.steps += JavaTraceStep(problem?.line, null, interpreter.visibleVariables(), interpreter.output.toString())
        }
        return JavaTrace(recorder.steps.toList(), if (problem?.kind == JavaProblem.Kind.STEP_LIMIT) null else problem, stoppedEarly)
    }
}

class JavaInterpreter(internal val program: Program, private val stepLimit: Int, private val host: JavaHost?) {
    internal class Slot(val type: JType, var value: JValue?, val isFinal: Boolean)

    internal class Frame(
        val method: Method?,
        /** Das Objekt, dessen Methode oder Konstruktor gerade läuft (`this`). */
        val thisObject: JavaObject? = null,
        /** Die Klasse, deren Code gerade läuft – für Felder, statische Methoden und private Zugriffe. */
        val currentClass: String? = null,
    ) {
        val scopes = mutableListOf(mutableMapOf<String, Slot>())
    }

    internal sealed interface Flow {
        data object Normal : Flow
        data object Break : Flow
        data object Continue : Flow
        class Returned(val value: JValue) : Flow
        class Yielded(val value: JValue) : Flow
    }

    companion object {
        const val MAX_CALL_DEPTH = 400
        const val MAX_OUTPUT = 60_000
        private val BOXES = setOf("Integer", "Long", "Short", "Byte", "Character", "Double", "Boolean")
    }

    val output = StringBuilder()
    var steps = 0
        private set
    val warnings = mutableListOf<JavaWarning>()
    internal val globals = mutableMapOf<String, Slot>()
    internal val frames = mutableListOf(Frame(null))
    /** Statische Felder eigener Klassen (die Hauptklasse nutzt [globals]). */
    internal val statics = mutableMapOf<String, MutableMap<String, Slot>>()
    /** Enum-Konstanten je Enum, in Deklarationsreihenfolge. */
    internal val enumConstants = mutableMapOf<String, List<JavaObject>>()
    private val random = java.util.Random(42)
    /** Beim Zusehen: zeichnet vor jeder Anweisung und jeder neuen Schleifenrunde ein Bild auf. */
    var recorder: TraceRecorder? = null
    internal val frame: Frame get() = frames.last()

    fun run(): JavaProblem? = try {
        validateClasses()
        initializeClasses()
        for (field in program.staticFields) execute(field, global = true)
        for (statement in program.statements) {
            when (execute(statement)) {
                Flow.Normal -> continue
                is Flow.Returned -> break
                Flow.Break -> throw JavaProblem.syntax("break steht außerhalb einer Schleife oder eines switch.", statement.line)
                Flow.Continue -> throw JavaProblem.syntax("continue steht außerhalb einer Schleife.", statement.line)
                is Flow.Yielded -> throw JavaProblem.syntax("yield gibt es nur in switch-Ausdrücken.", statement.line)
            }
        }
        null
    } catch (e: JavaProblem) {
        e
    } catch (e: StackOverflowError) {
        JavaProblem.runtime("StackOverflowError: Eine Methode ruft sich immer wieder selbst auf. Jede Rekursion braucht einen Abbruchfall.", null)
    }

    fun nextRandom(): Double = random.nextDouble()

    // MARK: Variablen

    private fun tick(line: Int) {
        recorder?.let { recorder ->
            if (recorder.isFull) throw JavaProblem(JavaProblem.Kind.STEP_LIMIT, "Aufzeichnung voll.", line)
            val step = JavaTraceStep(line, frame.method?.name, visibleVariables(), output.toString())
            // Ein Block und seine erste Anweisung können auf derselben Zeile stehen – das ist ein Schritt.
            if (recorder.steps.lastOrNull() != step) recorder.steps += step
        }
        steps++
        if (steps > stepLimit) {
            throw JavaProblem(JavaProblem.Kind.STEP_LIMIT, "Dein Programm hört nach ${"%,d".format(java.util.Locale.GERMANY, stepLimit)} Schritten immer noch nicht auf – vermutlich eine Endlosschleife. Prüfe, ob sich die Bedingung der Schleife irgendwann ändert.", line)
        }
    }

    private fun declare(name: String, type: JType, value: JValue?, isFinal: Boolean, line: Int, global: Boolean = false) {
        if (global) {
            if (name in globals) throw JavaProblem.syntax("Das Feld „$name“ gibt es schon.", line)
            globals[name] = Slot(type, value, isFinal)
            return
        }
        if (frame.scopes.any { name in it }) {
            throw JavaProblem.syntax("Die Variable „$name“ gibt es hier schon. Eine Box mit demselben Namen darf es nur einmal geben – zum Ändern einfach $name = …; schreiben.", line)
        }
        frame.scopes.last()[name] = Slot(type, value, isFinal)
    }

    internal fun lookup(name: String): Slot? {
        frame.scopes.asReversed().firstNotNullOfOrNull { it[name] }?.let { return it }
        // Felder des eigenen Objekts (this.name ohne this)
        frame.thisObject?.let { obj -> obj.fieldTypes[name]?.let { type -> return Slot(type, obj.fields[name], false) } }
        // Statische Felder der eigenen Klasse und ihrer Oberklassen
        staticSlot(name, frame.currentClass)?.let { return it.second }
        return globals[name]
    }

    private fun read(name: String, line: Int): JValue {
        if (frame.thisObject == null && isInstanceField(name) && frame.scopes.none { name in it }) {
            throw JavaProblem.syntax("„$name“ ist ein Feld des Objekts – in einer static-Methode gibt es aber kein Objekt (this). Lass static weg oder nimm ein Objekt: objekt.$name.", line)
        }
        val slot = lookup(name) ?: throw unknownName(name, line)
        return slot.value ?: throw JavaProblem.syntax("Die Variable „$name“ hat noch keinen Wert. Gib ihr zuerst einen, z. B. $name = 0;", line)
    }

    internal fun write(name: String, value: JValue, line: Int): JValue {
        for (scope in frame.scopes.asReversed()) {
            val slot = scope[name] ?: continue
            if (slot.isFinal && slot.value != null) {
                throw JavaProblem.syntax("„$name“ ist final – der Wert darf nach dem ersten Festlegen nicht mehr geändert werden.", line)
            }
            val stored = coerce(value, slot.type, line, "Die Variable „$name“")
            slot.value = stored
            return stored
        }
        val obj = frame.thisObject
        if (obj != null && name in obj.fieldTypes) return writeField(obj, name, value, line)
        staticSlot(name, frame.currentClass)?.let { return writeStatic(it.first, name, value, line) }
        globals[name]?.let { slot ->
            if (slot.isFinal && slot.value != null) throw JavaProblem.syntax("„$name“ ist final – der Wert darf nicht mehr geändert werden.", line)
            val stored = coerce(value, slot.type, line, "Das Feld „$name“")
            slot.value = stored
            return stored
        }
        if (frame.thisObject == null && isInstanceField(name)) {
            throw JavaProblem.syntax("„$name“ ist ein Feld des Objekts – in einer static-Methode gibt es aber kein Objekt (this).", line)
        }
        throw unknownName(name, line)
    }

    internal fun unknownName(name: String, line: Int): JavaProblem {
        if (host?.objectNames?.contains(name) == true) {
            return JavaProblem.syntax("„$name“ ist ein Objekt – rufe eine seiner Methoden auf, z. B. $name.move();", line)
        }
        val known = frame.scopes.flatMap { it.keys } + globals.keys + (host?.objectNames ?: emptySet())
        val similar = known.firstOrNull { it.lowercase() == name.lowercase() && it != name }
        if (similar != null) return JavaProblem.syntax("„$name“ kennt Java hier nicht. Meintest du „$similar“? Achte auf Groß- und Kleinschreibung.", line)
        return JavaProblem.syntax("„$name“ kennt Java hier nicht. Ist die Variable deklariert (z. B. int $name = 0;) und richtig geschrieben?", line)
    }

    fun visibleVariables(): List<JavaVariable> {
        val merged = LinkedHashMap<String, Slot>()
        globals.keys.sorted().forEach { merged[it] = globals.getValue(it) }
        // Beim Zusehen: das eigene Objekt mit seinen Feldern
        frame.thisObject?.let { merged["this"] = Slot(JType.Obj(it.className), JValue.Obj(it), true) }
        for (scope in frame.scopes) scope.keys.sorted().forEach { merged[it] = scope.getValue(it) }
        return merged.mapNotNull { (name, slot) ->
            val value = slot.value ?: return@mapNotNull null
            JavaVariable(name, if (slot.type == JType.Inferred) value.type.toString() else slot.type.toString(), value.debugDisplay)
        }
    }

    internal fun warn(message: String, line: Int) {
        val warning = JavaWarning(message, line)
        if (warning !in warnings) warnings += warning
    }

    // MARK: Anweisungen

    internal fun executeBlock(statements: List<Stmt>): Flow {
        frame.scopes += mutableMapOf()
        try {
            for (statement in statements) {
                val flow = execute(statement)
                if (flow != Flow.Normal) return flow
            }
            return Flow.Normal
        } finally {
            frame.scopes.removeAt(frame.scopes.lastIndex)
        }
    }

    private fun executeBody(statement: Stmt): Flow = when (statement) {
        is Stmt.Block -> executeBlock(statement.statements)
        is Stmt.VarDecl -> throw JavaProblem.syntax("Eine Variablen-Deklaration braucht hier geschweifte Klammern { … } drumherum.", statement.line)
        else -> execute(statement)
    }

    internal fun execute(statement: Stmt, global: Boolean = false): Flow {
        tick(statement.line)
        when (statement) {
            is Stmt.VarDecl -> {
                for (declarator in statement.declarators) {
                    var declared = statement.type
                    repeat(declarator.extraDimensions) { declared = JType.Arr(declared) }
                    var value: JValue? = null
                    if (declarator.initializer != null) {
                        val raw = evaluate(declarator.initializer, declared)
                        if (declared == JType.Inferred) {
                            if (raw == JValue.Null) throw JavaProblem.syntax("Mit var kann Java aus null keinen Typ ableiten.", declarator.line)
                            if (raw == JValue.Void) throw JavaProblem.syntax("Die Methode gibt nichts zurück (void) – das kann man nicht speichern.", declarator.line)
                            declared = raw.type
                        }
                        value = coerce(raw, declared, declarator.line, "Die Variable „${declarator.name}“")
                    } else if (global) {
                        value = JValue.defaultValue(declared)
                    }
                    declare(declarator.name, declared, value, statement.isFinal, declarator.line, global)
                }
                return Flow.Normal
            }
            is Stmt.ExprStmt -> { evaluate(statement.expr); return Flow.Normal }
            is Stmt.Block -> return executeBlock(statement.statements)
            is Stmt.If -> {
                return if (test(statement.condition, "if")) executeBody(statement.then)
                else statement.otherwise?.let { executeBody(it) } ?: Flow.Normal
            }
            is Stmt.While -> {
                while (test(statement.condition, "while")) {
                    when (val flow = executeBody(statement.body)) {
                        Flow.Break -> return Flow.Normal
                        is Flow.Returned, is Flow.Yielded -> return flow
                        else -> Unit
                    }
                    tick(statement.line)
                }
                return Flow.Normal
            }
            is Stmt.DoWhile -> {
                do {
                    when (val flow = executeBody(statement.body)) {
                        Flow.Break -> return Flow.Normal
                        is Flow.Returned, is Flow.Yielded -> return flow
                        else -> Unit
                    }
                    tick(statement.line)
                } while (test(statement.condition, "while"))
                return Flow.Normal
            }
            is Stmt.For -> {
                frame.scopes += mutableMapOf()
                try {
                    statement.init.forEach { execute(it) }
                    while (statement.condition?.let { test(it, "for") } ?: true) {
                        when (val flow = executeBody(statement.body)) {
                            Flow.Break -> return Flow.Normal
                            is Flow.Returned, is Flow.Yielded -> return flow
                            else -> Unit
                        }
                        statement.update.forEach { evaluate(it) }
                        tick(statement.line)
                    }
                    return Flow.Normal
                } finally {
                    frame.scopes.removeAt(frame.scopes.lastIndex)
                }
            }
            is Stmt.ForEach -> {
                val source = evaluate(statement.collection)
                var itemType: JType = JType.Inferred
                val items: List<JValue> = when {
                    source is JValue.ArrV -> { itemType = source.array.elementType; source.array.elements.toList() }
                    // Sammlungen: in derselben Reihenfolge wie in Java (HashSet nach Hash-Fächern).
                    source is JValue.Obj && source.obj.kind in setOf(JavaObject.Kind.LIST, JavaObject.Kind.SET, JavaObject.Kind.DEQUE) -> iterationOrder(source.obj)
                    source is JValue.Obj && source.obj.kind == JavaObject.Kind.MAP ->
                        throw JavaProblem.syntax("Über eine Map kann for-each nicht direkt laufen – nimm map.keySet(), map.values() oder map.entrySet().", statement.line)
                    source is JValue.StrV -> throw JavaProblem.syntax("Über einen String kann for-each nicht direkt laufen – nimm text.toCharArray().", statement.line)
                    source == JValue.Null -> throw JavaProblem.exception("NullPointerException", null, "Das Array bzw. die Liste ist null.", statement.line)
                    else -> throw JavaProblem.syntax("for-each braucht ein Array oder eine Sammlung, bekommt aber ${source.typeName}.", statement.line)
                }
                for (element in items) {
                    val declared = if (statement.type == JType.Inferred) itemType else statement.type
                    frame.scopes += mutableMapOf()
                    val flow = try {
                        val value = coerce(element, declared, statement.line, "Die Schleifenvariable „${statement.name}“")
                        declare(statement.name, declared, value, false, statement.line)
                        executeBody(statement.body)
                    } finally {
                        frame.scopes.removeAt(frame.scopes.lastIndex)
                    }
                    when (flow) {
                        Flow.Break -> return Flow.Normal
                        is Flow.Returned, is Flow.Yielded -> return flow
                        else -> Unit
                    }
                    tick(statement.line)
                }
                return Flow.Normal
            }
            is Stmt.Break -> return Flow.Break
            is Stmt.Continue -> return Flow.Continue
            is Stmt.Return -> {
                val method = frame.method
                if (method == null) {
                    // return im main-Block beendet das Programm.
                    if (statement.value != null) throw JavaProblem.syntax("main gibt nichts zurück – return steht hier ohne Wert.", statement.line)
                    return Flow.Returned(JValue.Void)
                }
                val expr = statement.value
                if (expr == null) {
                    if (method.returnType != JType.VoidT) {
                        throw JavaProblem.syntax("Die Methode ${method.name} muss einen Wert vom Typ ${method.returnType} zurückgeben: return …;", statement.line)
                    }
                    return Flow.Returned(JValue.Void)
                }
                if (method.returnType == JType.VoidT) {
                    throw JavaProblem.syntax("${method.name} ist void und gibt nichts zurück – hinter return darf hier kein Wert stehen.", statement.line)
                }
                val value = evaluate(expr, method.returnType)
                return Flow.Returned(coerce(value, method.returnType, statement.line, "Der Rückgabewert von ${method.name}"))
            }
            is Stmt.Yield -> return Flow.Yielded(evaluate(statement.value))
            is Stmt.Switch -> {
                val value = evaluate(statement.subject)
                frame.scopes += mutableMapOf()
                try {
                    val start = matchingCase(value, statement.cases, statement.line) ?: return Flow.Normal
                    if (statement.cases[start].isArrow) {
                        val flow = executeBlock(statement.cases[start].body)
                        return if (flow == Flow.Break) Flow.Normal else flow
                    }
                    for (index in start until statement.cases.size) {
                        for (inner in statement.cases[index].body) {
                            when (val flow = execute(inner)) {
                                Flow.Normal -> continue
                                Flow.Break -> return Flow.Normal
                                else -> return flow
                            }
                        }
                    }
                    return Flow.Normal
                } finally {
                    frame.scopes.removeAt(frame.scopes.lastIndex)
                }
            }
            is Stmt.Throw -> throw throwing(evaluate(statement.value), statement.line)
            is Stmt.Try -> return executeTry(statement.body, statement.catches, statement.finallyBody)
            is Stmt.Empty -> return Flow.Normal
        }
    }

    internal fun test(expr: Expr, keyword: String): Boolean {
        val value = evaluate(expr)
        if (value is JValue.BoolV) return value.value
        if (expr is Expr.Assign && expr.op == "=") throw JavaProblem.syntax("In der Bedingung steht = (Zuweisung). Zum Vergleichen braucht man ==.", expr.line)
        throw JavaProblem.syntax("Die Bedingung von $keyword muss true oder false ergeben, nicht ${value.typeName}.", expr.line)
    }

    private fun isNullLabel(label: Expr) = label is Expr.Literal && label.value == JValue.Null

    /** Die Muster-Variablen landen im aktuellen (innersten) Bereich – dort gilt dann der Zweig. */
    private fun matchingCase(value: JValue, cases: List<SwitchCase>, line: Int): Int? {
        if (value == JValue.Null) {
            // Nur mit „case null“ darf ein switch null bekommen.
            val index = cases.indexOfFirst { case -> case.labels.any { isNullLabel(it) } }
            if (index >= 0) return index
            throw JavaProblem.exception("NullPointerException", null, "switch über null – ohne „case null“ geht das nicht.", line)
        }
        var defaultIndex: Int? = null
        cases.forEachIndexed { index, case ->
            if (case.isDefault) defaultIndex = index
            for (label in case.labels) {
                if (isNullLabel(label)) continue
                // Typ-Muster: case Kreis k -> … (die Variable k gilt im Zweig)
                if (label is Expr.InstanceOf && label.value is Expr.Name && label.value.name == "\$switch") {
                    if (!isInstance(value, label.type)) continue
                    label.binding?.let { frame.scopes.last()[it] = Slot(label.type, value, false) }
                    if (case.guardExpr != null && !test(case.guardExpr, "when")) continue
                    return index
                }
                if (label is Expr.RecordPattern && label.value is Expr.Name && label.value.name == "\$switch") {
                    val bindings = match(value, label.pattern, label.line) ?: continue
                    for ((name, slot) in bindings) frame.scopes.last()[name] = slot
                    if (case.guardExpr != null && !test(case.guardExpr, "when")) continue
                    return index
                }
                // Enum-Konstante ohne Klassennamen: case ROT ->
                val constantName = (value as? JValue.Obj)?.obj?.fields?.get("\$name")?.stringValue
                if (constantName != null && label is Expr.Name && lookup(label.name) == null) {
                    if (label.name == constantName) return index
                    continue
                }
                if (valuesEqual(value, evaluate(label), label.line)) return index
            }
        }
        return defaultIndex
    }

    private fun valuesEqual(lhs: JValue, rhs: JValue, line: Int): Boolean {
        val a = Num.of(lhs); val b = Num.of(rhs)
        if (a != null && b != null) return Num.compare(a, b) == 0
        if (lhs is JValue.StrV && rhs is JValue.StrV) return lhs.ref.text == rhs.ref.text
        if (lhs is JValue.BoolV && rhs is JValue.BoolV) return lhs.value == rhs.value
        if (lhs is JValue.Obj && rhs is JValue.Obj) return lhs.obj === rhs.obj
        throw JavaProblem.syntax("Der case-Wert (${rhs.typeName}) passt nicht zum Typ im switch (${lhs.typeName}).", line)
    }

    // MARK: Ausdrücke

    internal fun evaluateArgs(exprs: List<Expr>): List<JValue> = exprs.map { evaluate(it) }

    fun evaluate(expr: Expr, expected: JType? = null): JValue = when (expr) {
        is Expr.Literal -> expr.value
        is Expr.Name -> read(expr.name, expr.line)
        is Expr.Unary -> unary(expr.op, evaluate(expr.operand), expr.line)
        is Expr.Increment -> {
            val old = evaluate(expr.target)
            val number = Num.of(old) ?: throw JavaProblem.syntax("${expr.op} funktioniert nur mit Zahlen, nicht mit ${old.typeName}.", expr.line)
            val changed = Num.apply(if (expr.op == "++") "+" else "-", number, Num.I(1))
            val new = cast(changed.value, old.type, expr.line)
            store(new, expr.target, expr.line)
            if (expr.prefix) new else old
        }
        is Expr.Binary -> {
            val left = evaluate(expr.left)
            val right = evaluate(expr.right)
            val same = if (expr.op == "==" || expr.op == "!=") boxedIdentity(expr.left, expr.right, left, right, expr.line) else null
            if (same != null) JValue.BoolV(if (expr.op == "==") same else !same) else binary(expr.op, left, right, expr.line)
        }
        is Expr.Logical -> {
            val left = evaluate(expr.left) as? JValue.BoolV
                ?: throw JavaProblem.syntax("${expr.op} verknüpft nur true/false-Werte.", expr.line)
            if (expr.op == "&&" && !left.value) JValue.BoolV(false)
            else if (expr.op == "||" && left.value) JValue.BoolV(true)
            else evaluate(expr.right) as? JValue.BoolV ?: throw JavaProblem.syntax("${expr.op} verknüpft nur true/false-Werte.", expr.line)
        }
        is Expr.Assign -> {
            if (expr.op == "=") {
                val value = evaluate(expr.value, storageType(expr.target, expr.line))
                if (value == JValue.Void) throw JavaProblem.syntax("Die Methode gibt nichts zurück (void) – das kann man nicht speichern.", expr.line)
                store(value, expr.target, expr.line)
            } else {
                val old = evaluate(expr.target)
                val combined = binary(expr.op.dropLast(1), old, evaluate(expr.value), expr.line)
                // Zusammengesetzte Zuweisungen enthalten einen versteckten Cast: int x += 1.5 ist erlaubt.
                store(cast(combined, old.type, expr.line), expr.target, expr.line)
            }
        }
        is Expr.Conditional -> {
            val flag = evaluate(expr.condition) as? JValue.BoolV ?: throw JavaProblem.syntax("Vor dem ? muss eine Bedingung stehen (true/false).", expr.line)
            evaluate(if (flag.value) expr.then else expr.otherwise, expected)
        }
        is Expr.Cast -> cast(evaluate(expr.operand), expr.type, expr.line)
        is Expr.Index -> {
            val (array, position) = arrayAccess(evaluate(expr.base), evaluate(expr.index), expr.line)
            array.elements[position]
        }
        is Expr.Field -> field(expr.base, expr.name, expr.line)
        is Expr.Call -> call(expr.target, expr.name, expr.args, expr.line)
        is Expr.NewArray -> {
            val counts = expr.sizes.map { size ->
                val number = Num.of(evaluate(size))
                if (number !is Num.I) throw JavaProblem.syntax("Die Größe eines Arrays muss eine ganze Zahl (int) sein.", expr.line)
                if (number.v < 0) throw JavaProblem.exception("NegativeArraySizeException", "${number.v}", "Ein Array kann nicht ${number.v} Plätze haben.", expr.line)
                number.v
            }
            var leaf = expr.element
            repeat(expr.extraDimensions) { leaf = JType.Arr(leaf) }
            makeArray(counts, leaf)
        }
        is Expr.ArrayLiteral -> {
            val elementType = expr.element ?: (expected as? JType.Arr)?.element
                ?: throw JavaProblem.syntax("Bei einer Werteliste { … } muss klar sein, welcher Array-Typ entsteht.", expr.line)
            val values = expr.items.map { coerce(evaluate(it, elementType), elementType, it.line, "Ein Element des Arrays") }
            JValue.ArrV(JavaArray(elementType, values.toMutableList()))
        }
        is Expr.SwitchExpr -> switchExpression(expr, expected)
        is Expr.This -> JValue.Obj(
            frame.thisObject ?: throw JavaProblem.syntax("this gibt es nur in Methoden eines Objekts – in einer static-Methode wie main gibt es kein this.", expr.line),
        )
        is Expr.SuperRef -> throw JavaProblem.syntax("super allein ist kein Wert – nach super folgt eine Methode, z. B. super.laut().", expr.line)
        is Expr.NewObject -> if (expr.className != "String") instantiate(expr.className, evaluateArgs(expr.args), expr.line) else {
            val args = evaluateArgs(expr.args)
            when (args.size) {
                0 -> JValue.str("")
                1 -> {
                    val arg = args[0]
                    if (arg is JValue.ArrV && arg.array.elementType == JType.CharT) JValue.str(arg.array.elements.joinToString("") { it.javaString })
                    // Absichtlich ein neues Objekt – deshalb ist new String("a") == "a" in Java false.
                    else JValue.str(arg.stringValue ?: throw JavaProblem.syntax("new String(…) erwartet einen Text.", expr.line))
                }
                else -> throw JavaProblem.unsupported("new String mit mehreren Werten kennt der eingebaute Interpreter nicht.", expr.line)
            }
        }
        is Expr.RecordPattern -> {
            val bindings = match(evaluate(expr.value), expr.pattern, expr.line)
            if (bindings == null) JValue.BoolV(false) else {
                for ((name, slot) in bindings) frame.scopes.last()[name] = slot
                JValue.BoolV(true)
            }
        }
        is Expr.InstanceOf -> {
            val value = evaluate(expr.value)
            val matches = isInstance(value, expr.type)
            // Muster-Variable: x instanceof Hund h – h ist ab hier ein Hund.
            if (matches && expr.binding != null) frame.scopes.last()[expr.binding] = Slot(expr.type, value, false)
            JValue.BoolV(matches)
        }
    }

    private fun switchExpression(expr: Expr.SwitchExpr, expected: JType?): JValue {
        val value = evaluate(expr.subject)
        frame.scopes += mutableMapOf()
        try {
            val start = matchingCase(value, expr.cases, expr.line)
                ?: throw JavaProblem.syntax("Der switch-Ausdruck braucht einen default-Zweig, damit immer ein Wert herauskommt.", expr.line)
            for (index in start until expr.cases.size) {
                val case = expr.cases[index]
                case.value?.let { return evaluate(it, expected) }
                for (statement in case.body) {
                    when (val flow = execute(statement)) {
                        Flow.Normal -> continue
                        is Flow.Yielded -> return flow.value
                        Flow.Break -> throw JavaProblem.syntax("In einem switch-Ausdruck verlässt man einen Zweig mit yield, nicht mit break.", statement.line)
                        else -> throw JavaProblem.syntax("Ein Zweig des switch-Ausdrucks muss mit yield einen Wert liefern.", case.line)
                    }
                }
                if (case.isArrow) throw JavaProblem.syntax("Ein Zweig des switch-Ausdrucks muss mit yield einen Wert liefern.", case.line)
            }
            throw JavaProblem.syntax("Der switch-Ausdruck liefert keinen Wert (yield fehlt).", expr.line)
        } finally {
            frame.scopes.removeAt(frame.scopes.lastIndex)
        }
    }

    private fun makeArray(counts: List<Int>, leaf: JType): JValue {
        val first = counts.firstOrNull() ?: return JValue.defaultValue(leaf)
        var elementType = leaf
        repeat(counts.size - 1) { elementType = JType.Arr(elementType) }
        val rest = counts.drop(1)
        return JValue.ArrV(JavaArray(elementType, MutableList(first) { if (rest.isEmpty()) JValue.defaultValue(leaf) else makeArray(rest, leaf) }))
    }

    private fun storageType(target: Expr, line: Int): JType? = when (target) {
        is Expr.Name -> (lookup(target.name) ?: throw unknownName(target.name, line)).type
        is Expr.Index -> (evaluate(target.base) as? JValue.ArrV)?.array?.elementType
        is Expr.Field -> fieldType(target.base, target.name)
        else -> null
    }

    /** Speichert den Wert und liefert ihn so zurück, wie er abgelegt wurde (z. B. int → double). */
    private fun store(value: JValue, target: Expr, line: Int): JValue = when (target) {
        is Expr.Name -> write(target.name, value, line)
        is Expr.Index -> {
            val (array, position) = arrayAccess(evaluate(target.base), evaluate(target.index), line)
            coerce(value, array.elementType, line, "Ein Platz im Array").also { array.elements[position] = it }
        }
        is Expr.Field -> storeField(target.base, target.name, value, line) ?: throw JavaProblem.syntax(
            if (target.name == "length") "length eines Arrays kann man nicht ändern – die Größe steht beim Erzeugen fest." else "„${target.name}“ kann man nicht verändern.", line,
        )
        else -> throw JavaProblem.syntax("Links vom = muss eine Variable stehen.", line)
    }

    private fun arrayAccess(container: JValue, index: JValue, line: Int): Pair<JavaArray, Int> {
        val array = (container as? JValue.ArrV)?.array ?: when (container) {
            is JValue.StrV -> throw JavaProblem.syntax("Bei Strings holt man ein Zeichen mit charAt(i), nicht mit [i].", line)
            JValue.Null -> throw JavaProblem.runtime("NullPointerException: Das Array ist null.", line)
            else -> throw JavaProblem.syntax("[ ] gibt es nur bei Arrays, nicht bei ${container.typeName}.", line)
        }
        val position = (Num.of(index) as? Num.I)?.v ?: throw JavaProblem.syntax("Der Index in [ ] muss eine ganze Zahl (int) sein.", line)
        if (position < 0 || position >= array.elements.size) {
            val range = if (array.elements.isEmpty()) "das Array ist leer" else "erlaubt sind nur 0 bis ${array.elements.size - 1}"
            throw JavaProblem.exception(
                "ArrayIndexOutOfBoundsException", "Index $position out of bounds for length ${array.elements.size}",
                "Index $position gibt es nicht – $range. Denk dran: Gezählt wird ab 0.", line,
            )
        }
        return array to position
    }

    // MARK: Operatoren

    private fun unary(op: String, value: JValue, line: Int): JValue {
        if (op == "!") {
            val flag = value as? JValue.BoolV ?: throw JavaProblem.syntax("! (nicht) funktioniert nur mit true/false.", line)
            return JValue.BoolV(!flag.value)
        }
        val number = Num.of(value) ?: throw JavaProblem.syntax("$op funktioniert nur mit Zahlen.", line)
        return when (op) {
            "+" -> number.value
            "-" -> when (number) { is Num.I -> JValue.IntV(-number.v); is Num.L -> JValue.LongV(-number.v); is Num.D -> JValue.DoubleV(-number.v) }
            "~" -> when (number) {
                is Num.I -> JValue.IntV(number.v.inv())
                is Num.L -> JValue.LongV(number.v.inv())
                is Num.D -> throw JavaProblem.syntax("~ funktioniert nur mit ganzen Zahlen.", line)
            }
            else -> throw JavaProblem.syntax("Unbekannter Operator $op.", line)
        }
    }

    /**
     * `Integer a = 1000, b = 1000; a == b` ist in Java false: == vergleicht hier Objekte.
     * Java hält nur kleine Zahlen (-128 bis 127) als gemeinsame Objekte vorrätig.
     */
    private fun boxedIdentity(lhs: Expr, rhs: Expr, left: JValue, right: JValue, line: Int): Boolean? {
        val leftType = (declaredType(lhs) as? JType.Obj)?.name ?: return null
        val rightType = (declaredType(rhs) as? JType.Obj)?.name ?: return null
        if (leftType !in BOXES || rightType !in BOXES || left.isNull || right.isNull) return null
        warn("$leftType-Werte vergleicht man mit equals(), nicht mit ==. == prüft, ob es dasselbe Objekt ist – das klappt nur bei kleinen Zahlen (-128 bis 127) zufällig.", line)
        if (!valuesEqual(left, right, line)) return false
        if (lhs is Expr.Name && rhs is Expr.Name && lhs.name == rhs.name) return true
        return when (left) {
            is JValue.BoolV -> true
            is JValue.DoubleV -> false
            is JValue.CharV -> left.value.code <= 127
            else -> {
                val number = Num.of(left)
                number != null && !number.isDouble && number.toDouble in -128.0..127.0
            }
        }
    }

    internal fun binary(op: String, lhs: JValue, rhs: JValue, line: Int): JValue {
        if (lhs == JValue.Void) throw JavaProblem.syntax("Links von $op steht ein Methodenaufruf, der nichts zurückgibt (void).", line)
        if (rhs == JValue.Void) throw JavaProblem.syntax("Rechts von $op steht ein Methodenaufruf, der nichts zurückgibt (void).", line)
        // Objekte werden mit ihrem toString() angehängt – wie in Java.
        if (op == "+" && (lhs is JValue.StrV || rhs is JValue.StrV)) return JValue.str(stringify(lhs, line) + stringify(rhs, line))

        when (op) {
            "==", "!=" -> {
                val a = Num.of(lhs); val b = Num.of(rhs)
                val equal = when {
                    a != null && b != null -> Num.compare(a, b) == 0 && !a.isNaN && !b.isNaN
                    lhs is JValue.BoolV && rhs is JValue.BoolV -> lhs.value == rhs.value
                    lhs is JValue.StrV && rhs is JValue.StrV -> {
                        warn("Strings vergleicht man mit equals(), nicht mit $op. == prüft nur, ob beide Variablen auf dasselbe Objekt zeigen – nicht, ob der Text gleich ist.", line)
                        // Wie in Java: dasselbe String-Objekt?
                        lhs.ref === rhs.ref
                    }
                    lhs == JValue.Null && rhs == JValue.Null -> true
                    (lhs == JValue.Null && (rhs is JValue.StrV || rhs is JValue.ArrV || rhs is JValue.Obj)) ||
                        (rhs == JValue.Null && (lhs is JValue.StrV || lhs is JValue.ArrV || lhs is JValue.Obj)) -> false
                    lhs is JValue.ArrV && rhs is JValue.ArrV -> lhs.array === rhs.array
                    // Objekte: == prüft, ob es dasselbe Objekt ist (gleicher Inhalt reicht nicht – dafür gibt es equals).
                    lhs is JValue.Obj && rhs is JValue.Obj -> lhs.obj === rhs.obj
                    lhs == JValue.Null || rhs == JValue.Null -> throw JavaProblem.exception(
                        "NullPointerException", null,
                        "Ein Wert ist null – null lässt sich nicht als ${(if (lhs.isNull) rhs else lhs).typeName} vergleichen (z. B. weil get(…) nichts gefunden hat).", line,
                    )
                    else -> throw JavaProblem.syntax("${lhs.typeName} und ${rhs.typeName} kann man nicht mit $op vergleichen.", line)
                }
                return JValue.BoolV(if (op == "==") equal else !equal)
            }
            "&", "|", "^" -> if (lhs is JValue.BoolV && rhs is JValue.BoolV) {
                return JValue.BoolV(when (op) { "&" -> lhs.value && rhs.value; "|" -> lhs.value || rhs.value; else -> lhs.value != rhs.value })
            }
        }

        val a = Num.of(lhs); val b = Num.of(rhs)
        if (a == null || b == null) {
            val offender = if (a == null) lhs else rhs
            throw when (offender) {
                JValue.Null -> JavaProblem.exception("NullPointerException", null, "Mit null kann man nicht rechnen – der Wert fehlt (z. B. weil get(…) den Schlüssel nicht gefunden hat).", line)
                is JValue.BoolV -> JavaProblem.syntax("Mit $op kann man nicht mit true/false rechnen.", line)
                is JValue.StrV -> JavaProblem.syntax("Mit $op kann man nicht mit Text (String) rechnen. Nur + hängt Texte aneinander.", line)
                else -> JavaProblem.syntax("$op passt nicht zu ${lhs.typeName} und ${rhs.typeName}.", line)
            }
        }
        return when (op) {
            "<", ">", "<=", ">=" -> {
                if (a.isNaN || b.isNaN) return JValue.BoolV(false)
                val order = Num.compare(a, b)
                JValue.BoolV(when (op) { "<" -> order < 0; ">" -> order > 0; "<=" -> order <= 0; else -> order >= 0 })
            }
            "/", "%" -> {
                val (x, y) = Num.promote(a, b)
                if (y.isZeroIntegral) throw JavaProblem.exception("ArithmeticException", "/ by zero", "/ by zero – durch 0 teilen geht bei ganzen Zahlen nicht.", line)
                Num.apply(op, x, y).value
            }
            "+", "-", "*" -> Num.apply(op, a, b).value
            "&", "|", "^", "<<", ">>", ">>>" -> {
                if (a.isDouble || b.isDouble) throw JavaProblem.syntax("$op funktioniert nur mit ganzen Zahlen.", line)
                Num.bitwise(op, a, b).value
            }
            else -> throw JavaProblem.syntax("Unbekannter Operator $op.", line)
        }
    }

    // MARK: Typen

    /** Implizite Umwandlung wie bei Zuweisung und Methodenaufruf: nur verlustfreie Verbreiterung. */
    fun coerce(value: JValue, type: JType, line: Int, what: String): JValue {
        fun mismatch(): JavaProblem {
            var message = "Typen passen nicht: $what erwartet $type, bekommt aber ${value.typeName}."
            when {
                value is JValue.DoubleV && (type == JType.IntT || type == JType.LongT) || value is JValue.LongV && type == JType.IntT ->
                    message += " Das ginge nur mit Verlust. Wenn du die Nachkommastellen bewusst abschneiden willst: ($type) davor schreiben."
                value is JValue.StrV && (type == JType.IntT || type == JType.DoubleT || type == JType.LongT) ->
                    message += " Ein Text ist keine Zahl – umwandeln geht mit Integer.parseInt(text) bzw. Double.parseDouble(text)."
                type == JType.StringT && (value is JValue.IntV || value is JValue.DoubleV || value is JValue.LongV || value is JValue.BoolV || value is JValue.CharV) ->
                    message += " Eine Zahl ist kein Text – umwandeln geht mit String.valueOf(wert) oder \"\" + wert."
                value is JValue.StrV && type == JType.CharT -> message += " Ein einzelnes Zeichen (char) steht in einfachen Anführungszeichen: 'a'."
                value == JValue.Void -> message = "Die Methode gibt nichts zurück (void) – $what bekommt deshalb keinen Wert."
            }
            return JavaProblem.syntax(message, line)
        }
        if (value.isNull && type.isPrimitive) {
            throw JavaProblem.exception(
                "NullPointerException", null,
                "$what erwartet $type, bekommt aber null – zum Beispiel, weil get(…) den Schlüssel nicht gefunden hat. null passt in keine Zahlen-Variable.", line,
            )
        }
        return when (type) {
            JType.Inferred -> value
            JType.IntT -> when (value) { is JValue.IntV -> value; is JValue.CharV -> JValue.IntV(value.value.code); else -> throw mismatch() }
            JType.LongT -> when (value) {
                is JValue.LongV -> value
                is JValue.IntV -> JValue.LongV(value.value.toLong())
                is JValue.CharV -> JValue.LongV(value.value.code.toLong())
                else -> throw mismatch()
            }
            JType.DoubleT -> when (value) {
                is JValue.DoubleV -> value
                is JValue.IntV -> JValue.DoubleV(value.value.toDouble())
                is JValue.LongV -> JValue.DoubleV(value.value.toDouble())
                is JValue.CharV -> JValue.DoubleV(value.value.code.toDouble())
                else -> throw mismatch()
            }
            JType.BooleanT -> if (value is JValue.BoolV) value else throw mismatch()
            JType.CharT -> when {
                value is JValue.CharV -> value
                // Ganzzahl-Konstanten im char-Bereich darf man direkt zuweisen (char c = 65;).
                value is JValue.IntV && value.value in 0..65_535 -> JValue.CharV(value.value.toChar())
                else -> throw mismatch()
            }
            JType.StringT -> if (value is JValue.StrV || value == JValue.Null) value else throw mismatch()
            is JType.Arr -> when {
                value == JValue.Null -> value
                value is JValue.ArrV && value.array.elementType == type.element -> value
                else -> throw mismatch()
            }
            JType.VoidT -> throw JavaProblem.syntax("Eine Variable kann nicht den Typ void haben.", line)
            is JType.Unknown -> throw JavaProblem.unsupported("Den Typ ${type.name} kennt der eingebaute Interpreter nicht.", line)
            is JType.Obj -> if (canAssign(value, type.name)) value else throw mismatch()
        }
    }

    /** Expliziter Cast `(int) x` – mit Javas Regeln für Abschneiden und Überlauf. */
    fun cast(value: JValue, type: JType, line: Int): JValue {
        if (type is JType.Obj) return castObject(value, type.name, line)
        if (type == JType.StringT) {
            return if (value is JValue.StrV || value == JValue.Null) value
            else throw JavaProblem.syntax("${value.typeName} kann man nicht in String casten – nimm String.valueOf(wert).", line)
        }
        if (type == JType.BooleanT) {
            return value as? JValue.BoolV ?: throw JavaProblem.syntax("Zahlen lassen sich nicht in boolean umwandeln.", line)
        }
        val number = Num.of(value)
            ?: if (value is JValue.BoolV) throw JavaProblem.syntax("true/false lässt sich nicht in eine Zahl umwandeln.", line)
            else return coerce(value, type, line, "Der Cast")
        return when (type) {
            JType.IntT -> JValue.IntV(number.toInt)
            JType.LongT -> JValue.LongV(number.toLong)
            JType.DoubleT -> JValue.DoubleV(number.toDouble)
            JType.CharT -> JValue.CharV(number.toInt.toChar())
            else -> coerce(value, type, line, "Der Cast")
        }
    }

    // MARK: Felder

    private fun field(base: Expr, name: String, line: Int): JValue {
        objectField(base, name, line)?.let { return it }
        if (base is Expr.Name && lookup(base.name) == null) {
            val className = base.name
            if (className == "java" || className == "javax") {
                throw JavaProblem.unsupported("Voll qualifizierte Klassen ($className.$name…) kennt der eingebaute Interpreter nicht.", line)
            }
            return when (className to name) {
                "Math" to "PI" -> JValue.DoubleV(Math.PI)
                "Math" to "E" -> JValue.DoubleV(Math.E)
                "Integer" to "MAX_VALUE" -> JValue.IntV(Int.MAX_VALUE)
                "Integer" to "MIN_VALUE" -> JValue.IntV(Int.MIN_VALUE)
                "Long" to "MAX_VALUE" -> JValue.LongV(Long.MAX_VALUE)
                "Long" to "MIN_VALUE" -> JValue.LongV(Long.MIN_VALUE)
                "Double" to "MAX_VALUE" -> JValue.DoubleV(Double.MAX_VALUE)
                "Double" to "MIN_VALUE" -> JValue.DoubleV(java.lang.Double.MIN_VALUE)
                "Double" to "POSITIVE_INFINITY" -> JValue.DoubleV(Double.POSITIVE_INFINITY)
                "Double" to "NEGATIVE_INFINITY" -> JValue.DoubleV(Double.NEGATIVE_INFINITY)
                "Double" to "NaN" -> JValue.DoubleV(Double.NaN)
                "System" to "out" -> throw JavaProblem.syntax("System.out allein macht nichts – zum Ausgeben: System.out.println(…);", line)
                else -> when {
                    host?.objectNames?.contains(className) == true ->
                        throw JavaProblem.syntax("$className.$name braucht runde Klammern: $className.$name();", line)
                    className.first().isUpperCase() -> throw JavaProblem.unsupported("$className.$name kennt der eingebaute Interpreter nicht.", line)
                    else -> throw unknownName(className, line)
                }
            }
        }
        val value = evaluate(base)
        return when {
            value is JValue.ArrV && name == "length" -> JValue.IntV(value.array.elements.size)
            value is JValue.StrV && name == "length" -> throw JavaProblem.syntax("Bei Strings ist length eine Methode und braucht Klammern: length().", line)
            value == JValue.Null -> throw JavaProblem.exception("NullPointerException", null, "Der Wert ist null – darauf gibt es kein „$name“.", line)
            value is JValue.Obj -> readField(value.obj, name, line)
            else -> throw JavaProblem.syntax("${value.typeName} hat kein Feld „$name“.", line)
        }
    }

    // MARK: Methodenaufrufe

    private fun call(target: Expr?, name: String, argExprs: List<Expr>, line: Int): JValue {
        if (target == null) {
            if (name == "this" || name == "super") throw JavaProblem.syntax("$name(…) darf nur als erste Zeile in einem Konstruktor stehen.", line)
            return callUserMethod(name, argExprs, line)
        }
        callOnClassOrObject(target, name, argExprs, line)?.let { return it }
        // System.out.println(…)
        if (target is Expr.Field && target.base is Expr.Name && target.base.name == "System" && lookup("System") == null) {
            if (target.name != "out" && target.name != "err") throw JavaProblem.unsupported("System.${target.name} kennt der eingebaute Interpreter nicht.", line)
            return printCall(name, evaluateArgs(argExprs), line)
        }
        if (target is Expr.Name && lookup(target.name) == null) {
            val args = evaluateArgs(argExprs)
            val host = host
            if (host != null && target.name in host.objectNames) {
                args.forEachIndexed { index, arg -> if (arg == JValue.Void) throw JavaProblem.syntax("Argument ${index + 1} gibt keinen Wert zurück (void).", line) }
                val context = if (host.wantsSnapshot) CallContext(line, visibleVariables(), output.toString()) else CallContext(line, emptyList(), "")
                return host.call(target.name, name, args, context)
            }
            return JavaLibrary.callStatic(target.name, name, args, line, this)
        }
        val receiver = evaluate(target)
        val args = evaluateArgs(argExprs)
        if (receiver is JValue.Obj) {
            // list.remove(Integer.valueOf(7)) entfernt den Wert 7, list.remove(7) die Stelle 7.
            if (name == "remove" && receiver.obj.kind == JavaObject.Kind.LIST && argExprs.size == 1 && isBoxed(argExprs[0])) {
                return JavaCollections.callObject(receiver.obj, "\$removeValue", args, line, this)
            }
            return callMethod(receiver.obj, name, args, line, declaredType(target))
        }
        // Zahlen aus Sammlungen oder Integer-Variablen sind in Java Objekte: liste.get(0).equals(…)
        if (!isPlainPrimitive(target)) JavaCollections.boxedMethod(receiver, name, args, line, this)?.let { return it }
        return JavaLibrary.callInstance(receiver, name, args, line, this)
    }

    /** Ist der Ausdruck sicher ein einfacher Wert (int, double …)? Daran gibt es in Java keine Methoden. */
    private fun isPlainPrimitive(expr: Expr): Boolean = when (expr) {
        is Expr.Literal, is Expr.Binary, is Expr.Unary, is Expr.Increment -> true
        is Expr.Cast -> expr.type.className == null
        is Expr.Field -> expr.name == "length"
        is Expr.Name -> lookup(expr.name)?.type?.isPrimitive == true
        else -> false
    }

    /** Steht hier eine Zahl als Objekt (Integer statt int)? */
    private fun isBoxed(expr: Expr): Boolean {
        val boxes = setOf("Integer", "Long", "Double", "Character", "Boolean", "Object", "Number")
        return when {
            expr is Expr.Call && expr.name == "valueOf" && expr.target is Expr.Name -> expr.target.name in boxes
            expr is Expr.Cast && expr.type is JType.Obj -> expr.type.name in boxes
            expr is Expr.NewObject -> expr.className in boxes
            else -> (declaredType(expr) as? JType.Obj)?.name in boxes
        }
    }

    private fun printCall(name: String, args: List<JValue>, line: Int): JValue {
        when (name) {
            "println" -> {
                if (args.size > 1) throw JavaProblem.syntax("println nimmt höchstens einen Wert – verbinde mehrere mit +.", line)
                args.firstOrNull()?.let { emit(printable(it, line), line) }
                emit("\n", line)
            }
            "print" -> {
                if (args.size != 1) throw JavaProblem.syntax("print braucht genau einen Wert in den Klammern.", line)
                emit(printable(args[0], line), line)
            }
            "printf", "format" -> {
                val pattern = args.firstOrNull()?.stringValue
                    ?: throw JavaProblem.syntax("printf braucht als Erstes einen Format-Text, z. B. printf(\"%d%n\", zahl).", line)
                emit(JavaFormat.format(pattern, formatArgs(args.drop(1), line), line), line)
            }
            else -> throw JavaProblem.syntax("System.out.$name gibt es nicht. Meintest du println oder print?", line)
        }
        return JValue.Void
    }

    /** Objekte für `%s` vorab in Text verwandeln – mit ihrer eigenen toString-Methode. */
    internal fun formatArgs(args: List<JValue>, line: Int): List<JValue> = args.map { if (it is JValue.Obj) JValue.str(stringify(it, line)) else it }

    private fun printable(value: JValue, line: Int): String = when {
        value == JValue.Void -> throw JavaProblem.syntax("Diese Methode gibt nichts zurück (void) – es gibt nichts auszugeben.", line)
        value is JValue.ArrV && value.array.elementType == JType.CharT -> value.array.elements.joinToString("") { it.javaString }
        else -> stringify(value, line)
    }

    private fun emit(text: String, line: Int) {
        output.append(text)
        if (output.length > MAX_OUTPUT) {
            throw JavaProblem(JavaProblem.Kind.STEP_LIMIT, "Dein Programm gibt sehr viel aus und wurde gestoppt – vermutlich eine Endlosschleife mit println.", line)
        }
    }

    private fun callUserMethod(name: String, argExprs: List<Expr>, line: Int): JValue {
        // In einer Klasse: erst deren Methoden (Objektmethoden über this, dann statische), dann die des Hauptprogramms.
        callInClassContext(name, argExprs, line)?.let { return it }
        val candidates = program.methods[name]
        if (candidates == null) {
            if (name == "println" || name == "print") throw JavaProblem.syntax("$name allein kennt Java nicht – es heißt System.out.$name(…).", line)
            program.methods.keys.firstOrNull { it.lowercase() == name.lowercase() }?.let {
                throw JavaProblem.syntax("Die Methode $name(…) gibt es nicht. Meintest du $it? Achte auf Groß- und Kleinschreibung.", line)
            }
            host?.objectNames?.sorted()?.firstOrNull()?.let {
                throw JavaProblem.syntax("Die Methode $name(…) gibt es nicht. Befehle für den Roboter schreibt man mit Punkt davor: $it.$name();", line)
            }
            throw JavaProblem.syntax("Die Methode $name(…) gibt es nicht. Ist sie geschrieben und richtig benannt?", line)
        }
        val args = evaluateArgs(argExprs)
        val matching = candidates.filter { it.parameters.size == args.size }
        if (matching.isEmpty()) {
            throw JavaProblem.syntax("$name erwartet ${candidates.joinToString(" oder ") { it.parameters.size.toString() }} Wert(e) in den Klammern, bekommt aber ${args.size}.", line)
        }
        return invoke(selectOverload(matching, args, name, line), args, line)
    }

    /** Wählt die passende Variante: erst exakte Typen, dann erlaubte Verbreiterung (int → double usw.). */
    internal fun selectOverload(matching: List<Method>, args: List<JValue>, name: String, line: Int): Method {
        val exact = matching.firstOrNull { m -> m.parameters.zip(args).all { (p, a) -> p.type == a.type || p.type == JType.Inferred } }
        val widening = matching.firstOrNull { m -> m.parameters.zip(args).all { (p, a) -> runCatching { coerce(a, p.type, line, "") }.isSuccess } }
        return exact ?: widening ?: run {
            // Keine passt: die Meldung der ersten Variante erklärt, welcher Parameter nicht passt.
            matching[0].parameters.zip(args).forEach { (p, a) -> coerce(a, p.type, line, "Der Parameter „${p.name}“ von $name") }
            throw JavaProblem.syntax("Die Werte passen nicht zu den Parametern von $name.", line)
        }
    }

    internal fun invoke(method: Method, args: List<JValue>, line: Int, self: JavaObject? = null): JValue {
        if (frames.size >= MAX_CALL_DEPTH) {
            throw JavaProblem.runtime("StackOverflowError: ${method.name} ruft sich immer wieder selbst auf und hört nie auf. Jede Rekursion braucht einen Abbruchfall.", line)
        }
        if (method.isAbstract) {
            throw JavaProblem.syntax("${method.name} hat keinen Körper (abstract) – aufrufen kann man nur eine Klasse, die die Methode umsetzt.", line)
        }
        val newFrame = Frame(method, if (method.isStatic) null else self, method.owner)
        method.parameters.zip(args).forEach { (p, a) ->
            newFrame.scopes[0][p.name] = Slot(p.type, coerce(a, p.type, line, "Der Parameter „${p.name}“ von ${method.name}"), false)
        }
        frames += newFrame
        try {
            for (statement in method.body) {
                when (val flow = execute(statement)) {
                    Flow.Normal -> continue
                    is Flow.Returned -> return flow.value
                    Flow.Break -> throw JavaProblem.syntax("break steht außerhalb einer Schleife.", statement.line)
                    Flow.Continue -> throw JavaProblem.syntax("continue steht außerhalb einer Schleife.", statement.line)
                    is Flow.Yielded -> throw JavaProblem.syntax("yield gibt es nur in switch-Ausdrücken.", statement.line)
                }
            }
            if (method.returnType != JType.VoidT) {
                throw JavaProblem.syntax("Die Methode ${method.name} endet, ohne einen Wert zurückzugeben. Es fehlt ein return mit einem ${method.returnType}-Wert.", method.line)
            }
            return JValue.Void
        } finally {
            frames.removeAt(frames.lastIndex)
        }
    }
}
