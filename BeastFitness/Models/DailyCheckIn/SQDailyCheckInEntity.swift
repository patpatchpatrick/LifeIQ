//
//  SQDailyCheckInEntity.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/2/25.
//

import SwiftData
import Foundation

@Model
final class SQDailyCheckInEntity {
    @Attribute(.unique) var dateKey: String
    var date: Date
    var notes: String?

    /// Persist daily values reliably (instead of a dictionary)
    @Relationship(deleteRule: .cascade)
    var metricValues: [SQDailyMetricValueEntity] = []

    // MARK: - Init

    init(from stats: SQDailyCheckInStats) {
        let normalized = Calendar.current.startOfDay(for: stats.date)

        self.dateKey = SQDailyCheckInStats.getUniqueDateKey(for: normalized)
        self.date = normalized
        self.notes = stats.notes

        self.metricValues = stats.values.map { (metricId, value) in
            SQDailyMetricValueEntity(metricId: metricId, value: value)
        }
    }

    // MARK: - Mapping

    func toStats() -> SQDailyCheckInStats {
        let valuesDict: [String: Float] = Dictionary(
            uniqueKeysWithValues: metricValues.compactMap { entry in
                guard let v = entry.value else { return nil }
                return (entry.metricId, v)
            }
        )

        return SQDailyCheckInStats(
            date: date,
            values: valuesDict,
            notes: notes
        )
    }

    func update(from stats: SQDailyCheckInStats) {
        let normalized = Calendar.current.startOfDay(for: stats.date)

        self.date = normalized
        self.dateKey = SQDailyCheckInStats.getUniqueDateKey(for: normalized)
        self.notes = stats.notes

        applyMetricValues(stats.values)
    }

    // MARK: - Private

    /// Overwrite this day's metric values to match `incoming`.
    /// - Adds new metricIds
    /// - Updates existing metricIds
    /// - Removes metricIds not present in incoming (keeps model clean)
    private func applyMetricValues(_ incoming: [String: Float]) {
        // Index existing by metricId
        var existingById: [String: SQDailyMetricValueEntity] =
            Dictionary(uniqueKeysWithValues: metricValues.map { ($0.metricId, $0) })

        // Update/add
        for (metricId, value) in incoming {
            if let existing = existingById[metricId] {
                existing.value = value
            } else {
                metricValues.append(.init(metricId: metricId, value: value))
            }
        }

        // Remove ones not present anymore
        if incoming.isEmpty {
            metricValues.removeAll()
        } else {
            metricValues.removeAll { incoming.keys.contains($0.metricId) == false }
        }
    }
}

@Model
final class SQDailyMetricValueEntity {
    /// Metric definition id (e.g. "metric.mood", "metric.alcohol", "metric.custom.<uuid>")
    var metricId: String

    /// Stored as Float for everything (binary uses 0/1)
    var value: Float?

    init(metricId: String, value: Float?) {
        self.metricId = metricId
        self.value = value
    }
}


extension SQDailyCheckInEntity {

    static func get(for date: Date, context: ModelContext) throws -> SQDailyCheckInStats? {
        let normalized = Calendar.current.startOfDay(for: date)
        let dateKey = SQDailyCheckInStats.getUniqueDateKey(for: normalized)

        let descriptor = FetchDescriptor<SQDailyCheckInEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )

        return try context.fetch(descriptor).first?.toStats()
    }

    /// Fetches all daily check-in stats within a date range
    static func getAll(
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) throws -> [SQDailyCheckInStats] {
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd = Calendar.current.startOfDay(for: endDate)

        let descriptor = FetchDescriptor<SQDailyCheckInEntity>(
            predicate: #Predicate { entity in
                entity.date >= normalizedStart && entity.date <= normalizedEnd
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        return try context.fetch(descriptor).map { $0.toStats() }
    }

    static func upsert(
        stats: SQDailyCheckInStats,
        in context: ModelContext
    ) throws {
        let normalized = Calendar.current.startOfDay(for: stats.date)
        let dateKey = SQDailyCheckInStats.getUniqueDateKey(for: normalized)

        let descriptor = FetchDescriptor<SQDailyCheckInEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )

        if let existing = try context.fetch(descriptor).first {
            // Ensure stored dateKey/date are normalized and values match
            existing.update(from: stats)
        } else {
            let entity = SQDailyCheckInEntity(from: stats)
            context.insert(entity)
        }

        try context.save()
    }
}
