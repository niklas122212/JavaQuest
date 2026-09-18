import Foundation
import SwiftData

/// Version 1 des Speicherschemas. Kommt später ein neues Feld dazu, entsteht ein
/// `JavaQuestSchemaV2` plus eine `MigrationStage` im Plan – bestehende Fortschritte
/// bleiben so bei App-Updates erhalten.
enum JavaQuestSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [LearnerProfile.self, LessonRecord.self, TopicMastery.self, TaskAttempt.self, ScoreSnapshot.self]
    }
}

enum JavaQuestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [JavaQuestSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum PersistenceController {
    static let storeName = "JavaQuest"

    /// Rein lokaler Speicher: kein CloudKit, keine App Group.
    static func configuration(inMemory: Bool) -> ModelConfiguration {
        ModelConfiguration(
            storeName,
            schema: Schema(versionedSchema: JavaQuestSchemaV1.self),
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: JavaQuestSchemaV1.self),
            migrationPlan: JavaQuestMigrationPlan.self,
            configurations: [configuration(inMemory: inMemory)]
        )
    }

    /// Letzter Ausweg, wenn sich der Speicher nicht öffnen lässt (z. B. beschädigte Datei).
    static func destroyPersistentStore() throws {
        let url = configuration(inMemory: false).url
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            if fileManager.fileExists(atPath: file.path) {
                try fileManager.removeItem(at: file)
            }
        }
    }
}
