import Foundation

/// Objektorientierung im Interpreter: eigene Klassen, Konstruktoren, Vererbung, Interfaces,
/// Enums, Records und Exceptions (throw, try/catch/finally).
extension JavaInterpreter {
    // MARK: - Klassen nachschlagen

    func classDecl(_ name: String?) -> JavaClass? {
        guard let name else { return nil }
        return program.classes[name]
    }

    /// Ist `name` ein Typname (eigene Klasse oder bekannte Bibliotheksklasse) – und keine Variable?
    func isTypeName(_ name: String) -> Bool {
        lookup(name) == nil && (program.classes[name] != nil || name == program.mainClass)
    }

    /// Äußerste Klasse – private Felder und Methoden sind innerhalb derselben äußeren Klasse sichtbar.
    func topLevel(_ name: String?) -> String {
        var current = name ?? program.mainClass ?? ""
        while let outer = program.classes[current]?.outer {
            current = String(outer.split(separator: "$").first ?? Substring(outer))
        }
        return current
    }

    /// Ist `className` gleich `target` oder ein Untertyp davon (Klassen, Interfaces, Exceptions, Bibliothek)?
    func isSubtype(_ className: String, of target: String) -> Bool {
        if className == target || target == "Object" { return true }
        var visited: Set<String> = []
        var queue = [className]
        while let current = queue.popLast() {
            if current == target { return true }
            guard visited.insert(current).inserted else { continue }
            if let decl = program.classes[current] {
                if let parent = decl.superclass { queue.append(parent) }
                queue += decl.interfaces.map { String($0.prefix { $0 != "<" }) }
                if decl.kind == .enumType { queue.append("Comparable") }
            } else if JavaBuiltins.isThrowable(current) {
                if JavaBuiltins.throwableIs(current, target) { return true }
            } else if JavaBuiltins.librarySupertypes[current]?.contains(target) == true {
                return true
            }
        }
        return false
    }

    /// Die Kette der eigenen Klassen von `name` aufwärts (ohne Interfaces).
    func classChain(_ name: String) -> [JavaClass] {
        var chain: [JavaClass] = []
        var current: String? = name
        var visited: Set<String> = []
        while let n = current, let decl = program.classes[n], visited.insert(n).inserted {
            chain.append(decl)
            current = decl.superclass
        }
        return chain
    }

    /// Alle eigenen Interfaces, die `name` (mit Oberklassen und Ober-Interfaces) umsetzt.
    func allInterfaces(_ name: String) -> [JavaClass] {
        var result: [JavaClass] = []
        var visited: Set<String> = []
        var queue = classChain(name).flatMap(\.interfaces)
        while let next = queue.popLast() {
            let base = String(next.prefix { $0 != "<" })
            guard visited.insert(base).inserted, let decl = program.classes[base] else { continue }
            result.append(decl)
            queue += decl.interfaces
        }
        return result
    }

    /// Eingebaute Oberklasse (Exception …), falls die Kette eigener Klassen in eine mündet.
    func builtinAncestor(_ name: String) -> String? {
        if program.classes[name] == nil { return JavaBuiltins.isThrowable(name) ? name : nil }
        for decl in classChain(name) {
            if let parent = decl.superclass, program.classes[parent] == nil, JavaBuiltins.isThrowable(parent) { return parent }
        }
        return nil
    }

    func isThrowableClass(_ name: String) -> Bool { builtinAncestor(name) != nil }

    /// Gibt es in `name` (Kette, Interfaces) eine Methode dieses Namens?
    func hasMethod(_ name: String, in className: String) -> Bool {
        classChain(className).contains { $0.methods[name] != nil } || allInterfaces(className).contains { $0.methods[name] != nil }
            || (className == program.mainClass && program.methods[name] != nil)
    }

    /// Methode für einen Aufruf finden: von der Laufzeitklasse aufwärts, dann Default-Methoden der Interfaces.
    func findMethod(_ name: String, in className: String, args: [JavaValue], wantStatic: Bool?, line: Int) throws(JavaProblem) -> JavaMethod? {
        for decl in classChain(className) {
            let candidates = (decl.methods[name] ?? []).filter { method in
                method.parameters.count == args.count && !method.isAbstract && (wantStatic == nil || method.isStatic == wantStatic)
            }
            if !candidates.isEmpty { return try selectOverload(candidates, args, name: name, line: line) }
        }
        for decl in allInterfaces(className) {
            let candidates = (decl.methods[name] ?? []).filter { $0.parameters.count == args.count && !$0.isAbstract && (wantStatic == nil || $0.isStatic == wantStatic) }
            if !candidates.isEmpty { return try selectOverload(candidates, args, name: name, line: line) }
        }
        return nil
    }

    // MARK: - Statische Felder

    func staticSlot(_ name: String, from className: String?) -> (owner: String, slot: Slot)? {
        var current = className
        var visited: Set<String> = []
        while let n = current, n != program.mainClass, visited.insert(n).inserted {
            for decl in classChain(n) {
                if let slot = statics[decl.name]?[name] { return (decl.name, slot) }
                for interface in allInterfaces(decl.name) {
                    if let slot = statics[interface.name]?[name] { return (interface.name, slot) }
                }
            }
            // Verschachtelte Klassen sehen die statischen Felder der äußeren Klasse.
            current = program.classes[n]?.outer.map { String($0.split(separator: "$").last ?? Substring($0)) }
        }
        return nil
    }

    func writeStatic(_ owner: String, _ name: String, _ value: JavaValue, line: Int) throws(JavaProblem) -> JavaValue {
        guard var slot = statics[owner]?[name] else { throw unknownName(name, line: line) }
        if slot.isFinal, slot.value != nil {
            throw .syntax("„\(name)“ ist final – der Wert darf nicht mehr geändert werden.", line: line)
        }
        let stored = try coerce(value, to: slot.type, line: line, what: "Das Feld „\(name)“")
        slot.value = stored
        statics[owner]?[name] = slot
        return stored
    }

    /// Ist `name` ein Objektfeld der Klasse, deren Code gerade läuft? (Für die static-Meldung.)
    func isInstanceField(_ name: String) -> Bool {
        guard let className = frame.currentClass ?? program.mainClass else { return false }
        return classChain(className).contains { $0.fields.contains { !$0.isStatic && $0.name == name } || $0.recordComponents.contains { $0.name == name } }
    }

    // MARK: - Klassen prüfen und vorbereiten

    /// Was javac schon beim Übersetzen ablehnen würde: falsche Oberklassen, fehlende Methoden, falsches @Override.
    func validateClasses() throws(JavaProblem) {
        let builtinInterfaces: [String: [(String, Int)]] = ["Comparable": [("compareTo", 1)], "Runnable": [("run", 0)], "Cloneable": [], "Serializable": []]
        for name in program.classOrder {
            guard let decl = program.classes[name] else { continue }
            if let parent = decl.superclass {
                if let parentDecl = program.classes[parent] {
                    if parentDecl.isInterface {
                        throw .syntax("\(name) extends \(parent): \(parent) ist ein Interface – Interfaces setzt man mit implements um, extends ist für Klassen.", line: decl.line)
                    }
                    if parentDecl.kind == .enumType || parentDecl.kind == .record {
                        throw .syntax("Von \(parent) kann man nicht erben.", line: decl.line)
                    }
                } else if parent != "Object", !JavaBuiltins.isThrowable(parent) {
                    throw .unsupported("Die Oberklasse \(parent) kennt der eingebaute Interpreter nicht.", line: decl.line)
                }
                if classChain(name).count > 64 { throw .syntax("Die Vererbung von \(name) dreht sich im Kreis.", line: decl.line) }
            }
            for interface in decl.interfaces {
                let base = String(interface.prefix { $0 != "<" })
                if let interfaceDecl = program.classes[base] {
                    if !interfaceDecl.isInterface {
                        throw .syntax("\(name) implements \(base): \(base) ist eine Klasse, kein Interface – von Klassen erbt man mit extends.", line: decl.line)
                    }
                } else if builtinInterfaces[base] == nil {
                    throw .unsupported("Das Interface \(base) kennt der eingebaute Interpreter nicht.", line: decl.line)
                }
            }
            // @Override: Es muss eine Methode geben, die ersetzt wird.
            for method in decl.methods.values.flatMap({ $0 }) where method.isOverride {
                if !overridesSomething(method, in: decl, builtinInterfaces: builtinInterfaces) {
                    throw .syntax("@Override bei \(method.name)(…): Diese Methode ersetzt keine Methode einer Oberklasse oder eines Interfaces. Stimmen Name (auch Groß- und Kleinschreibung) und Parameter?", line: method.line)
                }
            }
            // Eine normale Klasse muss alle abstrakten Methoden ihrer Oberklassen und Interfaces umsetzen.
            if !decl.isAbstract, !decl.isInterface {
                for (methodName, count, source) in requiredMethods(of: decl, builtinInterfaces: builtinInterfaces) {
                    let implemented = classChain(name).contains { c in (c.methods[methodName] ?? []).contains { !$0.isAbstract && $0.parameters.count == count } }
                        || allInterfaces(name).contains { i in (i.methods[methodName] ?? []).contains { !$0.isAbstract && $0.parameters.count == count } }
                        || (decl.kind == .record && count == 0 && decl.recordComponents.contains { $0.name == methodName })
                        || (decl.kind == .enumType && methodName == "compareTo")
                    if !implemented {
                        throw .syntax("Die Klasse \(name) muss die Methode \(methodName)(…) aus \(source) umsetzen – oder selbst abstract sein.", line: decl.line)
                    }
                }
            }
        }
    }

    private func overridesSomething(_ method: JavaMethod, in decl: JavaClass, builtinInterfaces: [String: [(String, Int)]]) -> Bool {
        let count = method.parameters.count
        let objectMethods: [(String, Int)] = [("toString", 0), ("equals", 1), ("hashCode", 0)]
        if objectMethods.contains(where: { $0 == (method.name, count) }) { return true }
        if let parent = decl.superclass {
            if classChain(parent).contains(where: { ($0.methods[method.name] ?? []).contains { $0.parameters.count == count } }) { return true }
            if JavaBuiltins.isThrowable(parent) || builtinAncestor(parent) != nil,
               [("getMessage", 0), ("toString", 0), ("getCause", 0)].contains(where: { $0 == (method.name, count) }) { return true }
        }
        for interface in allInterfaces(decl.name) where (interface.methods[method.name] ?? []).contains(where: { $0.parameters.count == count }) {
            return true
        }
        for c in classChain(decl.name) {
            for interface in c.interfaces {
                if builtinInterfaces[String(interface.prefix { $0 != "<" })]?.contains(where: { $0 == (method.name, count) }) == true { return true }
            }
        }
        return false
    }

    private func requiredMethods(of decl: JavaClass, builtinInterfaces: [String: [(String, Int)]]) -> [(String, Int, String)] {
        var required: [(String, Int, String)] = []
        for c in classChain(decl.name).dropFirst() where c.isAbstract {
            for method in c.methods.values.flatMap({ $0 }) where method.isAbstract {
                required.append((method.name, method.parameters.count, c.name))
            }
        }
        for interface in allInterfaces(decl.name) {
            for method in interface.methods.values.flatMap({ $0 }) where method.isAbstract {
                required.append((method.name, method.parameters.count, interface.name))
            }
        }
        for c in classChain(decl.name) {
            for interface in c.interfaces {
                let base = String(interface.prefix { $0 != "<" })
                for (name, count) in builtinInterfaces[base] ?? [] { required.append((name, count, base)) }
            }
        }
        return required
    }

    /// Statische Felder und Enum-Konstanten aller eigenen Klassen anlegen – in der Reihenfolge im Quelltext.
    func initializeClasses() throws(JavaProblem) {
        for name in program.classOrder where name != program.mainClass {
            guard let decl = program.classes[name] else { continue }
            statics[name] = statics[name] ?? [:]
            frames.append(Frame(method: nil, currentClass: name))
            defer { frames.removeLast() }
            if decl.kind == .enumType {
                var constants: [JavaObject] = []
                for (index, constant) in decl.enumConstants.enumerated() {
                    let object = JavaObject(kind: .plain, className: name)
                    object.fields["$name"] = .str(constant.name)
                    object.fields["$ordinal"] = .int(Int32(index))
                    initializeFields(object, of: name)
                    let args = try evaluateArgs(constant.args)
                    try runConstructor(name, object, args, line: constant.line)
                    constants.append(object)
                    statics[name]?[constant.name] = Slot(type: .object(name), value: .object(object), isFinal: true)
                }
                enumConstants[name] = constants
            }
            for field in decl.fields where field.isStatic {
                var value = JavaValue.defaultValue(for: field.type)
                if let initializer = field.initializer {
                    let raw = try evaluate(initializer, expected: field.type)
                    value = try coerce(raw, to: field.type, line: field.line, what: "Das Feld „\(field.name)“")
                }
                statics[name]?[field.name] = Slot(type: field.type, value: value, isFinal: field.isFinal)
            }
        }
    }

    // MARK: - Objekte erzeugen

    func instantiate(_ className: String, _ args: [JavaValue], line: Int) throws(JavaProblem) -> JavaValue {
        guard let decl = program.classes[className] else {
            return try JavaLibrary.construct(className, args, line: line, interpreter: self)
        }
        switch decl.kind {
        case .interface:
            throw .syntax("Von einem Interface (\(className)) kann man kein Objekt erzeugen – nur von einer Klasse, die es umsetzt.", line: line)
        case .enumType:
            throw .syntax("Enum-Werte gibt es nur als Konstanten (\(className).NAME) – mit new geht das nicht.", line: line)
        default:
            if decl.isAbstract {
                throw .syntax("\(className) ist abstract – davon kann man kein Objekt erzeugen, nur von einer Unterklasse.", line: line)
            }
        }
        let object = JavaObject(kind: .plain, className: className)
        initializeFields(object, of: className)
        try runConstructor(className, object, args, line: line)
        return .object(object)
    }

    /// Alle Objektfelder der Klasse und ihrer Oberklassen mit Standardwerten anlegen (Oberklasse zuerst).
    func initializeFields(_ object: JavaObject, of className: String) {
        if isThrowableClass(className) {
            object.fields["$message"] = .null
            object.fields["$cause"] = .null
        }
        for decl in classChain(className).reversed() {
            for component in decl.recordComponents {
                object.fieldTypes[component.name] = component.type
                object.fields[component.name] = .defaultValue(for: component.type)
                object.fieldOrder.append(component.name)
                object.fieldOwners[component.name] = decl.name
                object.privateFields.insert(component.name)
            }
            for field in decl.fields where !field.isStatic {
                object.fieldTypes[field.name] = field.type
                object.fields[field.name] = .defaultValue(for: field.type)
                if !object.fieldOrder.contains(field.name) { object.fieldOrder.append(field.name) }
                object.fieldOwners[field.name] = decl.name
                if field.isPrivate { object.privateFields.insert(field.name) } else { object.privateFields.remove(field.name) }
                if field.isFinal { object.finalFields.insert(field.name) }
            }
        }
    }

    private func pseudoMethod(_ className: String, _ parameters: [JavaParameter], line: Int) -> JavaMethod {
        JavaMethod(name: className, returnType: .void, parameters: parameters, body: [], line: line, isStatic: false, owner: className)
    }

    /// Konstruktor ausführen – wie Java: this(…) oder super(…) zuerst, dann Feld-Startwerte, dann der Rest.
    func runConstructor(_ className: String, _ object: JavaObject, _ args: [JavaValue], line: Int) throws(JavaProblem) {
        guard let decl = program.classes[className] else { return }
        guard frames.count < Self.maxCallDepth else {
            throw .runtime("StackOverflowError: Konstruktoren rufen sich immer wieder gegenseitig auf.", line: line)
        }
        // Record ohne eigenen Konstruktor: Werte der Reihe nach in die Felder.
        if decl.kind == .record, !decl.constructors.contains(where: { $0.parameters.count == decl.recordComponents.count }) || decl.constructors.isEmpty,
           args.count == decl.recordComponents.count {
            for (component, value) in zip(decl.recordComponents, args) {
                object.fields[component.name] = try coerce(value, to: component.type, line: line, what: "Das Feld „\(component.name)“ von \(className)")
            }
            return
        }
        if decl.constructors.isEmpty {
            guard args.isEmpty else {
                throw .syntax("\(className) hat keinen Konstruktor mit \(args.count) Wert(en) – nur den leeren Standard-Konstruktor.", line: line)
            }
            frames.append(Frame(method: pseudoMethod(className, [], line: decl.line), thisObject: object, currentClass: className))
            defer { frames.removeLast() }
            try runSuperConstructor(decl, object, [], line: line)
            try runFieldInitializers(decl, object)
            return
        }
        let matching = decl.constructors.filter { $0.parameters.count == args.count }
        guard !matching.isEmpty else {
            let counts = Set(decl.constructors.map(\.parameters.count)).sorted().map(String.init).joined(separator: " oder ")
            throw .syntax("Der Konstruktor von \(className) erwartet \(counts) Wert(e), bekommt aber \(args.count).", line: line)
        }
        let pseudos = matching.map { pseudoMethod(className, $0.parameters, line: $0.line) }
        let chosen = try selectOverload(pseudos, args, name: className, line: line)
        guard let index = pseudos.firstIndex(where: { $0.line == chosen.line && $0.parameters.map(\.name) == chosen.parameters.map(\.name) }) else { return }
        let constructor = matching[index]
        if constructor.isPrivate, topLevel(frame.currentClass) != topLevel(className) {
            throw .syntax("Der Konstruktor von \(className) ist private – von außen kann man so kein Objekt erzeugen.", line: line)
        }
        let newFrame = Frame(method: pseudoMethod(className, constructor.parameters, line: constructor.line), thisObject: object, currentClass: className)
        for (parameter, arg) in zip(constructor.parameters, args) {
            let value = try coerce(arg, to: parameter.type, line: line, what: "Der Parameter „\(parameter.name)“ des Konstruktors von \(className)")
            newFrame.scopes[0][parameter.name] = Slot(type: parameter.type, value: value, isFinal: false)
        }
        frames.append(newFrame)
        defer { frames.removeLast() }
        var body = constructor.body[...]
        if case .expr(.call(nil, "this", let thisArgs, let callLine), _)? = body.first {
            let values = try evaluateArgs(thisArgs)
            try runConstructor(className, object, values, line: callLine)
            body = body.dropFirst()
        } else {
            var superArgs: [JavaValue] = []
            if case .expr(.call(nil, "super", let superArgExprs, _), _)? = body.first {
                superArgs = try evaluateArgs(superArgExprs)
                body = body.dropFirst()
            }
            try runSuperConstructor(decl, object, superArgs, line: line)
            try runFieldInitializers(decl, object)
        }
        for statement in body {
            let flow = try execute(statement)
            if case .returned = flow {
                if constructor.isCompact { throw .syntax("In einem kompakten Record-Konstruktor ist return nicht erlaubt.", line: statement.line) }
                break
            }
        }
        if constructor.isCompact {
            // Erst nach dem kompakten Konstruktor kommen die (evtl. geänderten) Werte in die Felder.
            for component in decl.recordComponents {
                object.fields[component.name] = newFrame.scopes[0][component.name]?.value ?? .null
            }
        }
    }

    private func runSuperConstructor(_ decl: JavaClass, _ object: JavaObject, _ args: [JavaValue], line: Int) throws(JavaProblem) {
        guard let parent = decl.superclass, parent != "Object" else {
            if !args.isEmpty { throw .syntax("super(…) mit Werten geht nur, wenn die Klasse von einer anderen erbt (extends).", line: line) }
            return
        }
        if program.classes[parent] != nil {
            try runConstructor(parent, object, args, line: line)
            return
        }
        // Eingebaute Exception als Oberklasse: super(message) bzw. super(message, cause).
        switch args.count {
        case 0: break
        case 1:
            if case .object(let cause) = args[0], isThrowableClass(cause.className) || cause.kind == .throwable {
                object.fields["$cause"] = args[0]
                object.fields["$message"] = .str(try stringify(args[0], line: line))
            } else {
                object.fields["$message"] = try coerce(args[0], to: .string, line: line, what: "Die Meldung der Exception")
            }
        case 2:
            object.fields["$message"] = try coerce(args[0], to: .string, line: line, what: "Die Meldung der Exception")
            object.fields["$cause"] = args[1]
        default:
            throw .syntax("\(parent) hat keinen Konstruktor mit \(args.count) Werten.", line: line)
        }
    }

    private func runFieldInitializers(_ decl: JavaClass, _ object: JavaObject) throws(JavaProblem) {
        for field in decl.fields where !field.isStatic {
            guard let initializer = field.initializer else { continue }
            let raw = try evaluate(initializer, expected: field.type)
            object.fields[field.name] = try coerce(raw, to: field.type, line: field.line, what: "Das Feld „\(field.name)“")
        }
    }

    // MARK: - Felder von Objekten

    func readField(_ object: JavaObject, _ name: String, line: Int) throws(JavaProblem) -> JavaValue {
        guard object.fieldTypes[name] != nil, let value = object.fields[name] else {
            if object.kind == .plain, let decl = program.classes[object.className], decl.kind == .record,
               decl.recordComponents.contains(where: { $0.name == name }) == false {
                throw .syntax("Der Record \(object.className) hat kein Feld „\(name)“.", line: line)
            }
            throw .syntax("Die Klasse \(object.className) hat kein Feld „\(name)“.", line: line)
        }
        if object.privateFields.contains(name), topLevel(frame.currentClass) != topLevel(object.fieldOwners[name]) {
            throw .syntax("„\(name)“ ist private – von außerhalb der Klasse \(object.fieldOwners[name] ?? object.className) darf man nicht direkt darauf zugreifen. Nimm eine Methode (z. B. einen Getter).", line: line)
        }
        return value
    }

    func writeField(_ object: JavaObject, _ name: String, _ value: JavaValue, line: Int) throws(JavaProblem) -> JavaValue {
        guard let type = object.fieldTypes[name] else {
            throw .syntax("Die Klasse \(object.className) hat kein Feld „\(name)“.", line: line)
        }
        if object.privateFields.contains(name), topLevel(frame.currentClass) != topLevel(object.fieldOwners[name]) {
            throw .syntax("„\(name)“ ist private – von außerhalb der Klasse darf man es nicht ändern. Nimm eine Methode (z. B. einen Setter).", line: line)
        }
        let inConstructor = frame.thisObject === object && frame.method?.name == object.fieldOwners[name] && frame.method?.isStatic == false
        if object.finalFields.contains(name) || (program.classes[object.className]?.kind == .record && object.fieldOwners[name] == object.className), !inConstructor {
            throw .syntax("„\(name)“ ist final – der Wert darf nach dem Konstruktor nicht mehr geändert werden.", line: line)
        }
        let stored = try coerce(value, to: type, line: line, what: "Das Feld „\(name)“")
        object.fields[name] = stored
        return stored
    }

    /// `this.x`, `Klasse.feld`, `Enum.KONSTANTE` – oder nil, wenn der normale Weg greift.
    func objectField(_ base: JavaExpr, _ name: String, line: Int) throws(JavaProblem) -> JavaValue? {
        switch base {
        case .this(let thisLine), .superRef(let thisLine):
            guard let object = frame.thisObject else {
                throw .syntax("this gibt es nur in Methoden eines Objekts – in einer static-Methode gibt es kein this.", line: thisLine)
            }
            return try readField(object, name, line: line)
        case .name(let className, _) where isTypeName(className):
            if className == program.mainClass {
                guard let slot = globals[name], let value = slot.value else { throw .syntax("\(className) hat kein statisches Feld „\(name)“.", line: line) }
                return value
            }
            if let found = staticSlot(name, from: className), let value = found.slot.value { return value }
            if name == "length" || name == "class" { return nil }
            throw .syntax("\(className) hat kein statisches Feld „\(name)“ – Objektfelder gibt es nur an einem Objekt (objekt.\(name)).", line: line)
        default:
            return nil
        }
    }

    func storeField(_ base: JavaExpr, _ name: String, _ value: JavaValue, line: Int) throws(JavaProblem) -> JavaValue? {
        switch base {
        case .this, .superRef:
            guard let object = frame.thisObject else {
                throw .syntax("this gibt es nur in Methoden eines Objekts – in einer static-Methode gibt es kein this.", line: line)
            }
            return try writeField(object, name, value, line: line)
        case .name(let className, _) where isTypeName(className):
            if className == program.mainClass {
                return try write(name, value, line: line)
            }
            guard let found = staticSlot(name, from: className) else {
                throw .syntax("\(className) hat kein statisches Feld „\(name)“.", line: line)
            }
            return try writeStatic(found.owner, name, value, line: line)
        default:
            let target = try evaluate(base)
            switch target {
            case .object(let object): return try writeField(object, name, value, line: line)
            case .null: throw .exception("NullPointerException", javaMessage: nil, explanation: "Das Objekt ist null – es hat kein Feld „\(name)“.", line: line)
            default: return nil
            }
        }
    }

    func fieldType(_ base: JavaExpr, _ name: String, line: Int) throws(JavaProblem) -> JavaType? {
        switch base {
        case .this, .superRef:
            return frame.thisObject?.fieldTypes[name]
        case .name(let className, _) where isTypeName(className):
            if className == program.mainClass { return globals[name]?.type }
            return staticSlot(name, from: className)?.slot.type
        default:
            if case .object(let object) = try evaluate(base) { return object.fieldTypes[name] }
            return nil
        }
    }

    /// Statischer Typ eines Empfängers (Variable, Feld, this) – für Javas Prüfung, welche Methoden es gibt.
    func declaredType(of target: JavaExpr) throws(JavaProblem) -> JavaType? {
        switch target {
        case .name(let name, _): return lookup(name)?.type
        case .this: return frame.currentClass.map { .object($0) }
        case .field(let base, let name, let line): return try fieldType(base, name, line: line)
        default: return nil
        }
    }

    // MARK: - Methoden aufrufen

    /// Aufrufe auf this, super, eigene Klassen (statisch) und Enums – oder nil für den normalen Weg.
    func callOnClassOrObject(_ target: JavaExpr, _ name: String, _ argExprs: [JavaExpr], line: Int) throws(JavaProblem) -> JavaValue? {
        switch target {
        case .this(let thisLine):
            guard let object = frame.thisObject else {
                throw .syntax("this gibt es nur in Methoden eines Objekts – in einer static-Methode gibt es kein this.", line: thisLine)
            }
            return try callMethod(on: object, name, try evaluateArgs(argExprs), line: line, staticType: nil)
        case .superRef:
            guard let object = frame.thisObject, let current = frame.currentClass else {
                throw .syntax("super gibt es nur in Methoden eines Objekts.", line: line)
            }
            let args = try evaluateArgs(argExprs)
            if let parent = program.classes[current]?.superclass, program.classes[parent] != nil,
               let method = try findMethod(name, in: parent, args: args, wantStatic: false, line: line) {
                return try invoke(method, args, line: line, this: object)
            }
            // Ohne eigene Oberklassen-Methode: Javas Standard (Object bzw. Exception).
            if let result = try builtinObjectMethod(object, name, args, line: line, skipUserMethods: true) { return result }
            throw .syntax("Die Oberklasse hat keine Methode \(name)(…).", line: line)
        case .name(let className, _) where isTypeName(className):
            let args = try evaluateArgs(argExprs)
            if className == program.mainClass {
                guard let candidates = program.methods[name]?.filter({ $0.parameters.count == args.count }), !candidates.isEmpty else {
                    throw .syntax("\(className) hat keine statische Methode \(name) mit \(args.count) Wert(en).", line: line)
                }
                return try invoke(try selectOverload(candidates, args, name: name, line: line), args, line: line)
            }
            if let decl = program.classes[className], decl.kind == .enumType {
                switch (name, args.count) {
                case ("values", 0):
                    return .array(JavaArray(elementType: .object(className), elements: (enumConstants[className] ?? []).map { .object($0) }))
                case ("valueOf", 1):
                    let wanted = args[0].stringValue ?? ""
                    if let constant = enumConstants[className]?.first(where: { $0.fields["$name"]?.stringValue == wanted }) { return .object(constant) }
                    throw .exception("IllegalArgumentException", javaMessage: "No enum constant \(decl.binaryName.replacingOccurrences(of: "$", with: ".")).\(wanted)",
                                     explanation: "Die Konstante „\(wanted)“ gibt es im Enum \(className) nicht.", line: line)
                default: break
                }
            }
            if let method = try findMethod(name, in: className, args: args, wantStatic: true, line: line) {
                try checkPrivate(method, line: line)
                return try invoke(method, args, line: line)
            }
            if (try findMethod(name, in: className, args: args, wantStatic: false, line: line)) != nil {
                throw .syntax("\(name)(…) ist eine Objektmethode – man ruft sie an einem Objekt auf (objekt.\(name)(…)), nicht an der Klasse \(className).", line: line)
            }
            throw .syntax("Die Klasse \(className) hat keine statische Methode \(name) mit \(args.count) Wert(en).", line: line)
        default:
            return nil
        }
    }

    /// Unqualifizierter Aufruf `name(…)` in einer Klasse: erst Objektmethoden (über this), dann statische Methoden.
    static let inheritedMethods: Set<String> = ["getClass", "toString", "hashCode", "equals", "name", "ordinal", "compareTo", "getMessage", "getCause"]

    func callInClassContext(_ name: String, _ argExprs: [JavaExpr], line: Int) throws(JavaProblem) -> JavaValue? {
        let className = frame.currentClass ?? program.mainClass
        guard let className, let decl = program.classes[className] else { return nil }
        if !hasMethod(name, in: className) {
            // Geerbte Standardmethoden ohne this davor: getClass(), toString(), name(), values() …
            if let object = frame.thisObject, Self.inheritedMethods.contains(name) {
                if let result = try builtinObjectMethod(object, name, try evaluateArgs(argExprs), line: line, skipUserMethods: true) { return result }
            }
            if decl.kind == .enumType, name == "values" || name == "valueOf" {
                return try evaluate(.call(target: .name(className, line: line), name: name, args: argExprs, line: line))
            }
            return nil
        }
        if className == program.mainClass, frame.thisObject == nil, program.methods[name] != nil { return nil }
        let args = try evaluateArgs(argExprs)
        if let object = frame.thisObject {
            var method = try findMethod(name, in: object.className, args: args, wantStatic: nil, line: line)
            if method == nil { method = try findMethod(name, in: className, args: args, wantStatic: nil, line: line) }
            if let method { return try invoke(method, args, line: line, this: object) }
        }
        if let method = try findMethod(name, in: className, args: args, wantStatic: true, line: line) {
            return try invoke(method, args, line: line)
        }
        if (try findMethod(name, in: className, args: args, wantStatic: false, line: line)) != nil {
            throw .syntax("\(name)(…) ist eine Objektmethode – in einer static-Methode gibt es aber kein Objekt (this). Erzeuge ein Objekt und rufe sie daran auf, oder mach die Methode static.", line: line)
        }
        if className == program.mainClass, program.methods[name] != nil {
            let candidates = program.methods[name]!.filter { $0.parameters.count == args.count }
            if !candidates.isEmpty { return try invoke(try selectOverload(candidates, args, name: name, line: line), args, line: line) }
        }
        throw .syntax("\(name) erwartet eine andere Anzahl von Werten – mit \(args.count) Wert(en) gibt es die Methode nicht.", line: line)
    }

    private func checkPrivate(_ method: JavaMethod, line: Int) throws(JavaProblem) {
        if method.isPrivate, topLevel(frame.currentClass) != topLevel(method.owner) {
            throw .syntax("\(method.name)(…) ist private – nur die Klasse \(method.owner ?? "") selbst darf sie aufrufen.", line: line)
        }
    }

    /// Methode an einem Objekt aufrufen: eigene Methoden (mit Polymorphie), sonst Javas Standardmethoden.
    func callMethod(on object: JavaObject, _ name: String, _ args: [JavaValue], line: Int, staticType: JavaType?) throws(JavaProblem) -> JavaValue {
        guard object.kind == .plain, program.classes[object.className] != nil else {
            if object.kind == .plain, let builtin = try builtinObjectMethod(object, name, args, line: line, skipUserMethods: true) { return builtin }
            return try JavaLibrary.callObject(object, name, args, line: line, interpreter: self)
        }
        // Java prüft beim Übersetzen den Typ der Variablen: Tier t = new Hund(); t.bellen(); geht nicht.
        if case .object(let declared)? = staticType, let declaredName = staticType?.className, declaredName != object.className,
           program.classes[declaredName] != nil, !hasMethod(name, in: declaredName),
           !["toString", "equals", "hashCode", "getClass", "name", "ordinal", "compareTo", "getMessage"].contains(name) {
            throw .syntax("Die Methode \(name)(…) gibt es in \(declared) nicht. Die Variable hat den Typ \(declared) – auch wenn darin ein \(object.className) steckt, kennt Java nur die Methoden von \(declared).", line: line)
        }
        if let method = try findMethod(name, in: object.className, args: args, wantStatic: nil, line: line) {
            try checkPrivate(method, line: line)
            return try invoke(method, args, line: line, this: method.isStatic ? nil : object)
        }
        if let builtin = try builtinObjectMethod(object, name, args, line: line, skipUserMethods: true) { return builtin }
        if hasMethod(name, in: object.className) {
            throw .syntax("\(name) erwartet eine andere Anzahl von Werten – mit \(args.count) Wert(en) gibt es die Methode in \(object.className) nicht.", line: line)
        }
        throw .syntax("Die Methode \(name)(…) gibt es in der Klasse \(object.className) nicht.", line: line)
    }

    /// Methoden, die jedes Objekt von Java mitbekommt: toString, equals, hashCode, getClass –
    /// bei Enums name/ordinal, bei Records die Lese-Methoden, bei Exceptions getMessage.
    func builtinObjectMethod(_ object: JavaObject, _ name: String, _ args: [JavaValue], line: Int, skipUserMethods: Bool) throws(JavaProblem) -> JavaValue? {
        let decl = program.classes[object.className]
        switch (name, args.count) {
        case ("toString", 0): return .str(try defaultToString(object, line: line))
        case ("equals", 1):
            if decl?.kind == .record, case .object(let other) = args[0], other.className == object.className {
                for component in decl?.recordComponents ?? [] where !(try javaEquals(object.fields[component.name] ?? .null, other.fields[component.name] ?? .null, line: line)) {
                    return .boolean(false)
                }
                return .boolean(true)
            }
            if case .object(let other) = args[0] { return .boolean(other === object) }
            return .boolean(false)
        case ("hashCode", 0): return .int(try javaHash(.object(object), line: line, userMethods: !skipUserMethods))
        case ("getClass", 0):
            let info = JavaObject(kind: .classInfo, className: "Class")
            info.fields["name"] = .str(decl?.binaryName ?? JavaBuiltins.qualifiedName(object.className))
            info.fields["simpleName"] = .str(object.className)
            return .object(info)
        default: break
        }
        if decl?.kind == .enumType {
            switch (name, args.count) {
            case ("name", 0): return object.fields["$name"]
            case ("ordinal", 0): return object.fields["$ordinal"]
            case ("compareTo", 1):
                guard case .object(let other) = args[0], case .int(let a)? = object.fields["$ordinal"], case .int(let b)? = other.fields["$ordinal"] else {
                    throw .syntax("compareTo vergleicht nur Werte desselben Enums.", line: line)
                }
                return .int(a - b)
            default: break
            }
        }
        if decl?.kind == .record, args.isEmpty, decl?.recordComponents.contains(where: { $0.name == name }) == true {
            return object.fields[name]
        }
        if isThrowableClass(object.className) || object.kind == .throwable {
            switch (name, args.count) {
            case ("getMessage", 0), ("getLocalizedMessage", 0): return object.fields["$message"] ?? .null
            case ("getCause", 0): return object.fields["$cause"] ?? .null
            case ("printStackTrace", 0): return .void // Java schreibt nach System.err – nicht in die Ausgabe.
            default: break
            }
        }
        return nil
    }

    /// Standard-toString: Enum → Name, Record → Punkt[x=1, y=2], Exception → Klasse: Meldung, sonst Klasse@Adresse.
    func defaultToString(_ object: JavaObject, line: Int) throws(JavaProblem) -> String {
        if let name = object.fields["$name"]?.stringValue { return name }
        let decl = program.classes[object.className]
        if let decl, decl.kind == .record {
            let parts = try decl.recordComponents.map { (component) throws(JavaProblem) -> String in
                "\(component.name)=\(try stringify(object.fields[component.name] ?? .null, line: line))"
            }
            return "\(object.className)[\(parts.joined(separator: ", "))]"
        }
        if isThrowableClass(object.className) || object.kind == .throwable {
            let qualified = decl?.binaryName ?? JavaBuiltins.qualifiedName(object.className)
            if let message = object.fields["$message"], case .string = message { return "\(qualified): \(message.javaString)" }
            return qualified
        }
        return "\(decl?.binaryName ?? JavaBuiltins.qualifiedName(object.className))@\(String(object.serial, radix: 16))"
    }

    /// Text eines Werts wie bei println und String-Verkettung – mit eigenem toString().
    func stringify(_ value: JavaValue, line: Int) throws(JavaProblem) -> String {
        guard case .object(let object) = value else { return value.javaString }
        switch object.kind {
        case .plain:
            if program.classes[object.className] != nil,
               let method = try findMethod("toString", in: object.className, args: [], wantStatic: false, line: line) {
                let result = try invoke(method, [], line: line, this: object)
                return result.stringValue ?? result.javaString
            }
            return try defaultToString(object, line: line)
        case .list, .set, .deque:
            let items = try iterationOrder(object).map { (item) throws(JavaProblem) -> String in
                if case .object(let inner) = item, inner === object { return "(this Collection)" }
                return try stringify(item, line: line)
            }
            return "[" + items.joined(separator: ", ") + "]"
        case .map:
            let pairs = try mapEntries(object).map { (entry) throws(JavaProblem) -> String in
                "\(try stringify(entry.key, line: line))=\(try stringify(entry.value, line: line))"
            }
            return "{" + pairs.joined(separator: ", ") + "}"
        case .builder:
            return object.text
        case .throwable:
            return try defaultToString(object, line: line)
        case .classInfo:
            return "class " + (object.fields["name"]?.javaString ?? "")
        case .entry:
            return "\(try stringify(object.elements.first ?? .null, line: line))=\(try stringify(object.values.first ?? .null, line: line))"
        }
    }

    // MARK: - Typen prüfen

    /// instanceof: Passt der Wert zum Typ? null passt nie.
    /// Passt der Wert zum Muster? Dann die neuen Variablen, sonst nil.
    func match(_ value: JavaValue, _ pattern: JavaPattern, line: Int) throws(JavaProblem) -> [(String, Slot)]? {
        switch pattern {
        case .binding(let type, let name):
            if type == .inferred { return [(name, Slot(type: value.type, value: value, isFinal: false))] }
            switch type {
            case .int, .long, .double, .boolean, .char:
                return [(name, Slot(type: type, value: try coerce(value, to: type, line: line, what: "Das Feld im Record-Muster"), isFinal: false))]
            default:
                // Ein Typ-Muster im Record passt auch zu null, wenn der Typ alles abdeckt – sonst wie instanceof.
                if case .null = value { return [(name, Slot(type: type, value: value, isFinal: false))] }
                guard try isInstance(value, of: type, line: line) else { return nil }
                return [(name, Slot(type: type, value: value, isFinal: false))]
            }
        case .record(let className, let parts):
            guard try isInstance(value, of: .object(className), line: line), case .object(let object) = value else { return nil }
            guard let decl = program.classes[className], decl.kind == .record else {
                throw .syntax("\(className)(…) als Muster geht nur bei Records.", line: line)
            }
            guard decl.recordComponents.count == parts.count else {
                throw .syntax("Der Record \(className) hat \(decl.recordComponents.count) Felder – im Muster stehen aber \(parts.count).", line: line)
            }
            var bindings: [(String, Slot)] = []
            for (component, part) in zip(decl.recordComponents, parts) {
                guard let inner = try match(object.fields[component.name] ?? .null, part, line: line) else { return nil }
                bindings += inner
            }
            return bindings
        }
    }

    func isInstance(_ value: JavaValue, of type: JavaType, line: Int) throws(JavaProblem) -> Bool {
        if case .null = value { return false }
        switch type {
        case .string:
            if case .string = value { return true }
            return false
        case .object(let name):
            return try canAssign(value, to: name)
        case .array(let element):
            if case .array(let array) = value { return array.elementType == element }
            return false
        default:
            return value.type == type
        }
    }

    /// Darf der Wert in eine Variable vom Typ `typeName`? (Mit Autoboxing: int → Integer usw.)
    func canAssign(_ value: JavaValue, to typeName: String) throws(JavaProblem) -> Bool {
        let base = String(typeName.prefix { $0 != "<" })
        switch value {
        case .null: return true
        case .object(let object): return isSubtype(object.className, of: base) || isSubtype(libraryClass(object), of: base)
        case .string: return ["Object", "CharSequence", "Comparable", "String"].contains(base)
        case .int: return ["Integer", "Number", "Object", "Comparable"].contains(base)
        case .long: return ["Long", "Number", "Object", "Comparable"].contains(base)
        case .double: return ["Double", "Number", "Object", "Comparable"].contains(base)
        case .boolean: return ["Boolean", "Object", "Comparable"].contains(base)
        case .char: return ["Character", "Object", "Comparable"].contains(base)
        case .array: return base == "Object"
        case .void: return false
        }
    }

    /// Bibliotheksklasse für die Typprüfung (List.of liefert eine unveränderliche Liste usw.).
    func libraryClass(_ object: JavaObject) -> String { object.className }

    func castObject(_ value: JavaValue, to typeName: String, line: Int) throws(JavaProblem) -> JavaValue {
        if try canAssign(value, to: typeName) { return value }
        let from: String = switch value {
        case .object(let object): program.classes[object.className]?.binaryName ?? JavaBuiltins.qualifiedName(object.className)
        case .string: "java.lang.String"
        default: value.typeName
        }
        let base = String(typeName.prefix { $0 != "<" })
        let to = program.classes[base]?.binaryName ?? JavaBuiltins.qualifiedName(base)
        throw .exception("ClassCastException", javaMessage: "class \(from) cannot be cast to class \(to)",
                         explanation: "\(from) lässt sich nicht in \(to) umwandeln – das Objekt ist gar kein \(base). Prüfe vorher mit instanceof.", line: line)
    }

    // MARK: - Exceptions

    /// `throw wert;` – nur Exceptions dürfen geworfen werden.
    func throwing(_ value: JavaValue, line: Int) throws(JavaProblem) -> JavaProblem {
        guard case .object(let object) = value else {
            if case .null = value {
                return .exception("NullPointerException", javaMessage: nil, explanation: "throw null – geworfen werden kann nur eine Exception, nicht null.", line: line)
            }
            return .syntax("Werfen (throw) kann man nur Exceptions, nicht \(value.typeName).", line: line)
        }
        guard object.kind == .throwable || isThrowableClass(object.className) else {
            return .syntax("Werfen (throw) kann man nur Exceptions – \(object.className) erbt nicht von Exception.", line: line)
        }
        let message = object.fields["$message"]?.stringValue
        let name = program.classes[object.className]?.name ?? object.className
        var problem = JavaProblem(.runtime, message.map { "\(name): \($0)" } ?? "\(name) wurde geworfen und nicht aufgefangen.", line: line)
        problem.exceptionClass = object.className
        problem.javaMessage = message
        problem.thrown = ThrownObject(value)
        return problem
    }

    /// try/catch/finally – fängt Laufzeitfehler, deren Exception zu einem catch passt.
    func executeTry(_ body: [JavaStmt], _ catches: [JavaCatch], _ finallyBody: [JavaStmt]?, line: Int) throws(JavaProblem) -> Flow {
        var flow: Flow = .normal
        var pending: JavaProblem?
        do {
            flow = try executeBlock(body)
        } catch {
            let exceptionClass = error.exceptionClass ?? "RuntimeException"
            if error.kind == .runtime,
               let handler = catches.first(where: { handler in handler.types.contains { isSubtype(exceptionClass, of: $0) } }) {
                let exception = error.thrown?.value ?? makeThrowable(error)
                frame.scopes.append([handler.name: Slot(type: .object(exceptionClass), value: exception, isFinal: false)])
                do {
                    flow = try executeBlock(handler.body)
                } catch {
                    pending = error
                }
                frame.scopes.removeLast()
            } else {
                pending = error
            }
        }
        if let finallyBody {
            let finallyFlow = try executeBlock(finallyBody)
            if case .normal = finallyFlow {} else { return finallyFlow }
        }
        if let pending { throw pending }
        return flow
    }

    /// Exception-Objekt für einen Laufzeitfehler des Interpreters (z. B. / by zero).
    func makeThrowable(_ problem: JavaProblem) -> JavaValue {
        let object = JavaObject(kind: .throwable, className: problem.exceptionClass ?? "RuntimeException")
        object.fields["$message"] = problem.javaMessage.map { .str($0) } ?? .null
        object.fields["$cause"] = .null
        return .object(object)
    }

    // MARK: - Gleichheit, Hash, Reihenfolge (für Sammlungen)

    func javaEquals(_ a: JavaValue, _ b: JavaValue, line: Int) throws(JavaProblem) -> Bool {
        switch (a, b) {
        case (.null, .null): return true
        case (.null, _), (_, .null): return false
        case (.string(let x), .string(let y)): return x.text == y.text
        case (.boolean(let x), .boolean(let y)): return x == y
        case (.char(let x), .char(let y)): return x == y
        case (.int(let x), .int(let y)): return x == y
        case (.long(let x), .long(let y)): return x == y
        case (.double(let x), .double(let y)): return x.bitPattern == y.bitPattern || x == y
        case (.object(let x), _):
            if x.kind == .plain, program.classes[x.className] != nil,
               let method = try findMethod("equals", in: x.className, args: [b], wantStatic: false, line: line) {
                if case .boolean(let result) = try invoke(method, [b], line: line, this: x) { return result }
                return false
            }
            if x.kind == .plain { return (try builtinObjectMethod(x, "equals", [b], line: line, skipUserMethods: true)).map { if case .boolean(let r) = $0 { r } else { false } } ?? false }
            guard case .object(let y) = b else { return false }
            if x === y { return true }
            switch (x.kind, y.kind) {
            case (.list, .list):
                guard x.elements.count == y.elements.count else { return false }
                for (p, q) in zip(x.elements, y.elements) where !(try javaEquals(p, q, line: line)) { return false }
                return true
            case (.set, .set):
                guard x.elements.count == y.elements.count else { return false }
                for p in x.elements where try indexOfKey(p, in: y, line: line) == nil { return false }
                return true
            case (.map, .map):
                guard x.elements.count == y.elements.count else { return false }
                for (key, value) in zip(x.elements, x.values) {
                    guard let index = try indexOfKey(key, in: y, line: line), try javaEquals(value, y.values[index], line: line) else { return false }
                }
                return true
            case (.builder, .builder): return false
            default: return false
            }
        default: return false
        }
    }

    func javaHash(_ value: JavaValue, line: Int, userMethods: Bool = true) throws(JavaProblem) -> Int32 {
        switch value {
        case .null: return 0
        case .int(let v): return v
        case .long(let v): return JavaHashing.longHash(v)
        case .double(let v): return JavaHashing.doubleHash(v)
        case .boolean(let v): return v ? 1231 : 1237
        case .char(let c): return Int32(c)
        case .string(let s): return JavaHashing.stringHash(s.text)
        case .array(let array): return Int32(truncatingIfNeeded: array.serial)
        case .void: return 0
        case .object(let object):
            switch object.kind {
            case .plain:
                let decl = program.classes[object.className]
                if userMethods, decl != nil, let method = try findMethod("hashCode", in: object.className, args: [], wantStatic: false, line: line),
                   case .int(let hash) = try invoke(method, [], line: line, this: object) {
                    return hash
                }
                if let decl, decl.kind == .record {
                    var hash: Int32 = 0
                    for component in decl.recordComponents {
                        hash = hash &* 31 &+ (try javaHash(object.fields[component.name] ?? .null, line: line))
                    }
                    return hash
                }
                return Int32(truncatingIfNeeded: object.serial)
            case .list:
                var hash: Int32 = 1
                for element in object.elements { hash = hash &* 31 &+ (try javaHash(element, line: line)) }
                return hash
            case .set:
                var hash: Int32 = 0
                for element in object.elements { hash = hash &+ (try javaHash(element, line: line)) }
                return hash
            case .map:
                var hash: Int32 = 0
                for (key, value) in zip(object.elements, object.values) {
                    hash = hash &+ ((try javaHash(key, line: line)) ^ (try javaHash(value, line: line)))
                }
                return hash
            default:
                return Int32(truncatingIfNeeded: object.serial)
            }
        }
    }

    /// Natürliche Reihenfolge wie compareTo – für TreeMap, TreeSet und Collections.sort.
    func javaCompare(_ a: JavaValue, _ b: JavaValue, line: Int) throws(JavaProblem) -> Int {
        if let x = Numeric(a), let y = Numeric(b), case .char = a, case .char = b {
            return Numeric.compare(x, y) == .orderedAscending ? -1 : (Numeric.compare(x, y) == .orderedSame ? 0 : 1)
        }
        if let x = Numeric(a), let y = Numeric(b) {
            switch Numeric.compare(x, y) {
            case .orderedAscending: return -1
            case .orderedSame: return 0
            case .orderedDescending: return 1
            }
        }
        switch (a, b) {
        case (.string(let x), .string(let y)): return JavaLibrary.compareStrings(x.text, y.text)
        case (.boolean(let x), .boolean(let y)): return x == y ? 0 : (x ? 1 : -1)
        case (.null, _), (_, .null):
            throw .exception("NullPointerException", javaMessage: nil, explanation: "null lässt sich nicht vergleichen (z. B. in einer TreeMap oder beim Sortieren).", line: line)
        case (.object(let x), _):
            if x.kind == .plain, program.classes[x.className] != nil {
                if let method = try findMethod("compareTo", in: x.className, args: [b], wantStatic: false, line: line),
                   case .int(let result) = try invoke(method, [b], line: line, this: x) {
                    return Int(result)
                }
                if program.classes[x.className]?.kind == .enumType, case .object(let y) = b,
                   case .int(let p)? = x.fields["$ordinal"], case .int(let q)? = y.fields["$ordinal"] {
                    return Int(p - q)
                }
            }
            fallthrough
        default:
            let name = if case .object(let x) = a { x.className } else { a.typeName }
            throw .exception("ClassCastException", javaMessage: "class \(name) cannot be cast to class java.lang.Comparable",
                             explanation: "\(name) lässt sich nicht sortieren – die Klasse braucht compareTo (implements Comparable).", line: line)
        }
    }

    // MARK: - Sammlungen durchlaufen

    /// Elemente in Javas Reihenfolge: Listen wie gespeichert, HashSet nach Hash-Fächern, TreeSet sortiert.
    func iterationOrder(_ object: JavaObject) throws(JavaProblem) -> [JavaValue] {
        switch object.order {
        case .insertion, .sorted:
            return object.elements
        case .hash:
            let hashes = try object.elements.map { (element) throws(JavaProblem) -> Int32 in try javaHash(element, line: 0) }
            let indices = object.elements.indices.sorted { lhs, rhs in
                let a = JavaHashing.bucket(hashes[lhs], capacity: object.capacity)
                let b = JavaHashing.bucket(hashes[rhs], capacity: object.capacity)
                return a != b ? a < b : object.sequence[lhs] < object.sequence[rhs]
            }
            return indices.map { object.elements[$0] }
        }
    }

    func mapEntries(_ object: JavaObject) throws(JavaProblem) -> [(key: JavaValue, value: JavaValue)] {
        let keys = try iterationOrder(object)
        return try keys.map { (key) throws(JavaProblem) -> (key: JavaValue, value: JavaValue) in
            let index = try indexOfKey(key, in: object, line: 0) ?? 0
            return (key, object.values[index])
        }
    }

    func indexOfKey(_ key: JavaValue, in object: JavaObject, line: Int) throws(JavaProblem) -> Int? {
        for (index, element) in object.elements.enumerated() where try javaEquals(element, key, line: line) { return index }
        return nil
    }
}
