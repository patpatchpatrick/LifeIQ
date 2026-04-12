//
//  SQPersistenceController.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import SwiftData

typealias SQCurrentLocalSchema = SQLocalPersistenceSchemaV1

enum SQLocalPersistenceSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static let models: [any PersistentModel.Type] = [
        SQLocalPersistenceSchemaV1.SQDailyCheckInSessionEntity.self,
        SQLocalPersistenceSchemaV1.SQWorkoutSessionEntity.self,
        SQLocalPersistenceSchemaV1.SQMetricDefinitionEntity.self,
        SQLocalPersistenceSchemaV1.SQSyncMetadataEntity.self,
        SQLocalPersistenceSchemaV1.SQWorkoutProcessedEntity.self,
        SQLocalPersistenceSchemaV1.SQMetricEntryEntity.self,
        SQLocalPersistenceSchemaV1.SQDailyNoteEntity.self
    ]
}

enum SQPersistenceMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        SQLocalPersistenceSchemaV1.self
    ]

    static let stages: [MigrationStage] = []
}

enum SQPersistenceController {
    static let schema = Schema(versionedSchema: SQCurrentLocalSchema.self)

    static func makeModelContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: SQPersistenceMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

enum SQLocalPersistenceScope {
    static let guestUserId = "guest"
}
