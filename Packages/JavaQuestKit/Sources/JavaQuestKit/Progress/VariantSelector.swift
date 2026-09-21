import Foundation

/// Wählt aus Aufgaben-Varianten aus.
///
/// Aufgaben mit derselben `variantGroup` fragen dasselbe Lernziel auf verschiedene Weise ab.
/// Pro Sitzung kommt aus einer Gruppe höchstens eine Variante dran, und zwar in dieser Reihenfolge:
/// 1. eine Variante, die noch nie dran war,
/// 2. irgendeine andere als die zuletzt gezeigte – besonders wichtig nach einer falschen Antwort,
///    damit man das Lernziel noch einmal versteht statt die Antwort auswendig zu lernen,
/// 3. sonst die am längsten nicht gezeigte.
public enum VariantSelector {
    /// Aufgaben nach Lernziel gruppiert, in der Reihenfolge des ersten Auftretens.
    public static func groups(_ tasks: [LearningTask]) -> [(key: String, variants: [LearningTask])] {
        var order: [String] = []
        var byKey: [String: [LearningTask]] = [:]
        for task in tasks {
            if byKey[task.groupKey] == nil { order.append(task.groupKey) }
            byKey[task.groupKey, default: []].append(task)
        }
        return order.map { ($0, byKey[$0] ?? []) }
    }

    /// Die Variante, die als Nächstes dran sein sollte.
    public static func pick(from variants: [LearningTask], history: [String: TaskHistory]) -> LearningTask? {
        guard let first = variants.first else { return nil }
        guard variants.count > 1 else { return first }

        let unseen = variants.filter { history[$0.id] == nil }
        if !unseen.isEmpty {
            // Unter den ungesehenen die leichteste zuerst – der Einstieg bleibt sanft.
            return unseen.min { $0.difficulty < $1.difficulty }
        }

        // Zuletzt gezeigte Variante der Gruppe meiden.
        let sortedByAge = variants.sorted { (history[$0.id]?.lastDate ?? .distantPast) < (history[$1.id]?.lastDate ?? .distantPast) }
        guard let newest = variants.max(by: { (history[$0.id]?.lastDate ?? .distantPast) < (history[$1.id]?.lastDate ?? .distantPast) }) else {
            return first
        }
        let others = sortedByAge.filter { $0.id != newest.id }
        // Nach einem Fehler zuerst eine andere Variante desselben Lernziels.
        if let lastWrong = history[newest.id], lastWrong.lastCredit < 1, let other = others.first { return other }
        return others.first ?? newest
    }

    /// Eine Aufgabe je Lernziel – die Auswahl der Varianten ist schon erledigt.
    public static func collapse(_ tasks: [LearningTask], history: [String: TaskHistory]) -> [LearningTask] {
        groups(tasks).compactMap { pick(from: $0.variants, history: history) }
    }

    /// Die Aufgaben einer Lektion, mit passender Variante je Lernziel.
    ///
    /// Beim ersten Durchlauf sind das genau die Aufgaben der Lektion. Wiederholt man sie,
    /// kommen – soweit vorhanden – andere Varianten derselben Lernziele.
    public static func lessonTasks(_ lesson: Lesson, course: Course, history: [String: TaskHistory]) -> [LearningTask] {
        let extras = course.taskPool.filter { pooled in
            lesson.tasks.contains { $0.groupKey == pooled.groupKey }
        }
        let collapsed = collapse(lesson.tasks + extras, history: history)
        return collapsed.sorted { $0.difficulty < $1.difficulty }
    }
}
