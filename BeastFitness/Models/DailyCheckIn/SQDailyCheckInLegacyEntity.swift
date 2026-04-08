//
//  SQDailyCheckInLegacyEntity.swift
//  BeastFitness
//

import SwiftData
import Foundation

/// Compatibility-only legacy daily check-in model.
/// This remains in the schema so existing local stores can continue opening
/// while the app logic uses `SQMetricEntryEntity` and `SQDailyNoteEntity`
/// as the canonical source of truth.
@Model
final class SQDailyCheckInEntity {
    @Attribute(.unique) var dateKey: String
    var date: Date
    var notes: String?

    @Relationship(deleteRule: .cascade)
    var metricValues: [SQDailyMetricValueEntity] = []

    init(
        dateKey: String,
        date: Date,
        notes: String? = nil,
        metricValues: [SQDailyMetricValueEntity] = []
    ) {
        self.dateKey = dateKey
        self.date = date
        self.notes = notes
        self.metricValues = metricValues
    }
}

@Model
final class SQDailyMetricValueEntity {
    var metricId: String
    var value: Float?

    init(metricId: String, value: Float?) {
        self.metricId = metricId
        self.value = value
    }
}
