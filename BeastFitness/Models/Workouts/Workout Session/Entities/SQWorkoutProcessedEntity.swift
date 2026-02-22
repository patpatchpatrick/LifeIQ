//
//  SQWorkoutProcessedEntity.swift
//  BeastFitness
//

import SwiftData
import Foundation

/// Records that a workout has been reviewed by the user in the "New Workout" modal.
/// Keyed by `sourceId` (the stable HealthKit UUID for HK workouts, or workoutId for manual workouts).
@Model
final class SQWorkoutProcessedEntity {
    @Attribute(.unique) var sourceId: String
    var processedAt: Date

    init(sourceId: String, processedAt: Date = .now) {
        self.sourceId = sourceId
        self.processedAt = processedAt
    }
}

extension SQWorkoutProcessedEntity {

    /// Upserts a processed record for the given sourceId. No-op if already exists.
    static func markAsProcessed(sourceId: String, context: ModelContext) {
        let descriptor = FetchDescriptor<SQWorkoutProcessedEntity>(
            predicate: #Predicate { $0.sourceId == sourceId }
        )
        guard (try? context.fetch(descriptor).first) == nil else { return }
        context.insert(SQWorkoutProcessedEntity(sourceId: sourceId))
        try? context.save()
    }

    /// Returns the set of all processed sourceIds.
    static func fetchProcessedSourceIds(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<SQWorkoutProcessedEntity>()
        let entities = (try? context.fetch(descriptor)) ?? []
        return Set(entities.map { $0.sourceId })
    }
}
