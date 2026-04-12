//
//  SQWorkoutProcessedEntity.swift
//  BeastFitness
//

import SwiftData
import Foundation

/// Records that a workout has been reviewed by the user in the "New Workout" modal.
/// Keyed by `sourceId` (the stable HealthKit UUID for HK workouts, or workoutId for manual workouts).
extension SQLocalPersistenceSchemaV1 {
    @Model
    final class SQWorkoutProcessedEntity {
        @Attribute(.unique) var storageId: String
        var userId: String
        var sourceId: String
        var processedAt: Date

        init(userId: String, sourceId: String, processedAt: Date = .now) {
            self.storageId = Self.makeStorageId(userId: userId, sourceId: sourceId)
            self.userId = userId
            self.sourceId = sourceId
            self.processedAt = processedAt
        }
    }
}

typealias SQWorkoutProcessedEntity = SQCurrentLocalSchema.SQWorkoutProcessedEntity

extension SQWorkoutProcessedEntity {
    static func makeStorageId(userId: String, sourceId: String) -> String {
        "\(userId)/\(sourceId)"
    }

    /// Upserts a processed record for the given sourceId. No-op if already exists.
    static func markAsProcessed(sourceId: String, userId: String, context: ModelContext) {
        let descriptor = FetchDescriptor<SQWorkoutProcessedEntity>(
            predicate: #Predicate { $0.userId == userId && $0.sourceId == sourceId }
        )
        guard (try? context.fetch(descriptor).first) == nil else { return }
        context.insert(SQWorkoutProcessedEntity(userId: userId, sourceId: sourceId))
        try? context.save()
    }

    /// Returns the set of all processed sourceIds.
    static func fetchProcessedSourceIds(userId: String, context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<SQWorkoutProcessedEntity>(
            predicate: #Predicate { $0.userId == userId }
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return Set(entities.map { $0.sourceId })
    }
}
