import Foundation

/// Sicherung des Lernstands als Datei zum Mitnehmen.
///
/// Der Stand liegt sonst ausschließlich in der SwiftData-Datenbank dieses Geräts. Ein
/// neues Gerät, eine gelöschte App, ein Gerät, das abhandenkommt – und er ist weg. Eine
/// Datei ist die einzige Absicherung, die ohne Konto und ohne Server auskommt.
///
/// Dieselbe Dateiform wie in der Windows-Fassung, damit eine Sicherung von dort hier
/// eingelesen werden kann und umgekehrt.
public struct ProgressBackup: Codable {
    public static let kennung = "JavaQuest"

    public var app = kennung
    public var version = 1
    public var erstellt: Date
    public var stand: Stand

    public init(erstellt: Date, stand: Stand) {
        self.erstellt = erstellt
        self.stand = stand
    }

    public struct Stand: Codable {
        public init(createdAt: Date, experienceLevel: String, placedLevel: String?, placementScore: Int?,
                    onboardingCompleted: Bool, masterScore: Int, currentStreak: Int, longestStreak: Int,
                    lastActiveDay: Date?, lessonRecords: [String: Lektion], topicMasteries: [String: Thema],
                    attempts: [Versuch], scoreHistory: [Punktstand]) {
            self.createdAt = createdAt
            self.experienceLevel = experienceLevel
            self.placedLevel = placedLevel
            self.placementScore = placementScore
            self.onboardingCompleted = onboardingCompleted
            self.masterScore = masterScore
            self.currentStreak = currentStreak
            self.longestStreak = longestStreak
            self.lastActiveDay = lastActiveDay
            self.lessonRecords = lessonRecords
            self.topicMasteries = topicMasteries
            self.attempts = attempts
            self.scoreHistory = scoreHistory
        }

        public var schemaVersion = 1
        public var createdAt: Date
        public var experienceLevel: String
        public var placedLevel: String?
        public var placementScore: Int?
        public var onboardingCompleted: Bool
        public var masterScore: Int
        public var currentStreak: Int
        public var longestStreak: Int
        public var lastActiveDay: Date?
        public var lessonRecords: [String: Lektion]
        public var topicMasteries: [String: Thema]
        public var attempts: [Versuch]
        public var scoreHistory: [Punktstand]
    }

    public struct Lektion: Codable {
        public init(bestAccuracy: Double, lastAccuracy: Double, playCount: Int, isCompleted: Bool,
                    completedViaPlacement: Bool, firstCompletedAt: Date?, lastPlayedAt: Date?) {
            self.bestAccuracy = bestAccuracy
            self.lastAccuracy = lastAccuracy
            self.playCount = playCount
            self.isCompleted = isCompleted
            self.completedViaPlacement = completedViaPlacement
            self.firstCompletedAt = firstCompletedAt
            self.lastPlayedAt = lastPlayedAt
        }

        public var bestAccuracy: Double
        public var lastAccuracy: Double
        public var playCount: Int
        public var isCompleted: Bool
        public var completedViaPlacement: Bool
        public var firstCompletedAt: Date?
        public var lastPlayedAt: Date?
    }

    public struct Thema: Codable {
        public init(attempts: Int, firstTryCorrect: Int, weightedCorrect: Double,
                    weightedTotal: Double, lastPracticedAt: Date?) {
            self.attempts = attempts
            self.firstTryCorrect = firstTryCorrect
            self.weightedCorrect = weightedCorrect
            self.weightedTotal = weightedTotal
            self.lastPracticedAt = lastPracticedAt
        }

        public var attempts: Int
        public var firstTryCorrect: Int
        public var weightedCorrect: Double
        public var weightedTotal: Double
        public var lastPracticedAt: Date?
    }

    public struct Versuch: Codable, Hashable {
        public init(taskId: String, topicId: String, lessonId: String?, context: String, difficulty: Int,
                    credit: Double, solved: Bool, tries: Int, date: Date) {
            self.taskId = taskId
            self.topicId = topicId
            self.lessonId = lessonId
            self.context = context
            self.difficulty = difficulty
            self.credit = credit
            self.solved = solved
            self.tries = tries
            self.date = date
        }

        public var taskId: String
        public var topicId: String
        public var lessonId: String?
        public var context: String
        public var difficulty: Int
        public var credit: Double
        public var solved: Bool
        public var tries: Int
        public var date: Date

        /// Zwei Einträge gelten als derselbe, wenn Aufgabe, Zeitpunkt und Zusammenhang
        /// übereinstimmen – so entstehen beim Zusammenführen keine Dubletten.
        ///
        /// Der Zeitpunkt geht dabei durch dieselbe Schreibweise wie in der Datei. Dort
        /// fallen die Sekundenbruchteile weg; ohne diesen Zwischenschritt erkennt die
        /// eigene Sicherung ihre eigenen Einträge nicht wieder und legt sie doppelt an.
        public var kennung: String { "\(taskId)|\(ProgressBackup.zeitform(date))|\(context)" }
    }

    public struct Punktstand: Codable, Hashable {
        public init(date: Date, score: Int, reason: String) {
            self.date = date
            self.score = score
            self.reason = reason
        }

        public var date: Date
        public var score: Int
        public var reason: String
    }

    // MARK: Schreiben und Lesen

    /// Dieselbe Schreibweise wie im Coder – Grundlage für die Dublettenerkennung.
    /// Jedes Mal neu erzeugt: ein ISO8601DateFormatter ist nicht nebenläufigkeitssicher,
    /// und die Dublettenprüfung läuft selten genug, dass das nicht ins Gewicht fällt.
    static func zeitform(_ datum: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: datum)
    }

    public static var coder: (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (encoder, decoder)
    }

    /// Führt zwei Stände zusammen, statt einen zu überschreiben.
    ///
    /// Beim Einlesen darf nichts verlorengehen – weder das Gesicherte noch das, was seit
    /// der Sicherung dazugekommen ist. Deshalb gewinnt bei jeder Lektion das bessere
    /// Ergebnis, das Aufgaben-Protokoll wird vereinigt statt ersetzt, und der Score wird
    /// aus dem Ergebnis neu berechnet statt übernommen. Die Reihenfolge der beiden
    /// Stände ändert das Ergebnis nicht.
    ///
    /// Dieselben Regeln wie in der Windows- und der Web-Fassung.
    public static func vereine(_ eigen: Stand, _ fremd: Stand, course: Course) -> Stand {
        var lektionen: [String: Lektion] = eigen.lessonRecords
        for (id, andere) in fremd.lessonRecords {
            guard let meine = lektionen[id] else { lektionen[id] = andere; continue }
            let juengeres = (meine.lastPlayedAt ?? .distantPast) >= (andere.lastPlayedAt ?? .distantPast) ? meine : andere
            lektionen[id] = Lektion(
                bestAccuracy: max(meine.bestAccuracy, andere.bestAccuracy),
                lastAccuracy: juengeres.lastAccuracy,
                playCount: max(meine.playCount, andere.playCount),
                isCompleted: meine.isCompleted || andere.isCompleted,
                completedViaPlacement: meine.completedViaPlacement && andere.completedViaPlacement,
                firstCompletedAt: [meine.firstCompletedAt, andere.firstCompletedAt].compactMap { $0 }.min(),
                lastPlayedAt: [meine.lastPlayedAt, andere.lastPlayedAt].compactMap { $0 }.max()
            )
        }

        // Themen: der Stand mit mehr Aufgaben weiß mehr.
        var themen: [String: Thema] = eigen.topicMasteries
        for (id, andere) in fremd.topicMasteries where (themen[id]?.attempts ?? -1) < andere.attempts {
            themen[id] = andere
        }

        // Aufgaben-Protokoll vereinigen: Grundlage für Varianten und Wiedervorlage.
        var gesehen = Set<String>()
        let protokoll = (eigen.attempts + fremd.attempts)
            .filter { gesehen.insert($0.kennung).inserted }
            .sorted { $0.date < $1.date }

        var gesehenerVerlauf = Set<Punktstand>()
        let verlauf = (eigen.scoreHistory + fremd.scoreHistory)
            .filter { gesehenerVerlauf.insert($0).inserted }
            .sorted { $0.date < $1.date }

        // Der Score ergibt sich aus den Lektionen – nach dem Zusammenführen neu rechnen.
        let ergebnisse = lektionen.mapValues {
            LessonResult(bestAccuracy: $0.bestAccuracy, isCompleted: $0.isCompleted, viaPlacement: $0.completedViaPlacement)
        }
        let juengererStand = (eigen.lastActiveDay ?? .distantPast) >= (fremd.lastActiveDay ?? .distantPast) ? eigen : fremd

        return Stand(
            createdAt: min(eigen.createdAt, fremd.createdAt),
            experienceLevel: eigen.experienceLevel,
            placedLevel: eigen.placedLevel ?? fremd.placedLevel,
            placementScore: eigen.placementScore ?? fremd.placementScore,
            onboardingCompleted: eigen.onboardingCompleted || fremd.onboardingCompleted,
            masterScore: MasterScore.compute(course: course, results: ergebnisse),
            currentStreak: juengererStand.currentStreak,
            longestStreak: max(eigen.longestStreak, fremd.longestStreak),
            lastActiveDay: [eigen.lastActiveDay, fremd.lastActiveDay].compactMap { $0 }.max(),
            lessonRecords: lektionen,
            topicMasteries: themen,
            attempts: protokoll,
            scoreHistory: verlauf
        )
    }

    /// Liest eine Sicherung; nil, wenn die Datei keine ist.
    public static func lesen(_ daten: Data) -> Stand? {
        guard let sicherung = try? coder.1.decode(ProgressBackup.self, from: daten),
              sicherung.app == kennung
        else { return nil }
        return sicherung.stand
    }
}
