//
//  SQMetricEntryEntity.swift
//  BeastFitness
//

import Foundation
import SwiftData

/// SwiftData entity for persisting a single metric entry locally.
/// Mirrors `SQMetricEntry` — one row per metric value logged during a check-in.
extension SQLocalPersistenceSchemaV1 {
    @Model
    final class SQMetricEntryEntity {

        @Attribute(.unique) var storageId: String
        var userId: String
        var id: String
        /// References `SQMetricDefinition.id` — identifies which metric this value belongs to.
        var metricId: String
        /// UTC timestamp of when the user submitted this entry.
        var recordedAt: Date
        /// "YYYY-MM-DD" in the user's local timezone — groups entries into days.
        var anchorDayKey: String
        /// IANA timezone identifier at time of entry (e.g. "America/New_York").
        var timeZoneIdentifier: String
        /// Raw string for `SQMetricPeriod` — stored as String for SwiftData compatibility.
        var periodRaw: String
        /// Raw string for `SQMetricValueMode` — stored as String for SwiftData compatibility.
        var enteredModeRaw: String
        /// The value as entered by the user in their configured scale.
        var rawValue: Float
        var scaleValue: Float?
        var quantityValue: Float?
        /// `rawValue` normalized to 0–10 for the insight engine.
        var normalizedScore: Float

        init(entry: SQMetricEntry, userId: String) {
            self.storageId = Self.makeStorageId(userId: userId, entryId: entry.id)
            self.userId = userId
            self.id = entry.id
            self.metricId = entry.metricId
            self.recordedAt = entry.recordedAt
            self.anchorDayKey = entry.anchorDayKey
            self.timeZoneIdentifier = entry.timeZoneIdentifier
            self.periodRaw = entry.period.rawValue
            self.enteredModeRaw = entry.enteredMode.rawValue
            self.rawValue = entry.rawValue
            self.scaleValue = entry.scaleValue
            self.quantityValue = entry.quantityValue
            self.normalizedScore = entry.normalizedScore
        }
    }
}

typealias SQMetricEntryEntity = SQCurrentLocalSchema.SQMetricEntryEntity

// MARK: - Conversion

extension SQMetricEntryEntity {
    static func makeStorageId(userId: String, entryId: String) -> String {
        "\(userId)/\(entryId)"
    }

    var period: SQMetricPeriod { SQMetricPeriod(unfrozenRawValue: periodRaw) }
    var enteredMode: SQMetricValueMode { SQMetricValueMode(unfrozenRawValue: enteredModeRaw) }

    func toEntry() -> SQMetricEntry {
        SQMetricEntry(
            id: id,
            metricId: metricId,
            recordedAt: recordedAt,
            anchorDayKey: anchorDayKey,
            timeZoneIdentifier: timeZoneIdentifier,
            period: period,
            enteredMode: enteredMode,
            rawValue: rawValue,
            scaleValue: scaleValue,
            quantityValue: quantityValue,
            normalizedScore: normalizedScore
        )
    }

    /// Upserts a list of entries into the local store.
    /// Uses a stable deterministic ID (anchorDayKey/metricId/period) as the primary key.
    /// Also deletes any stale rows for the same (metricId, anchorDayKey, period) that have a
    /// different ID — handles cleanup of pre-stable-ID entries so buckets never contain duplicates.
    static func upsert(_ entries: [SQMetricEntry], userId: String, in context: ModelContext) throws {
        for entry in entries {
            let id = entry.id
            let descriptor = FetchDescriptor<SQMetricEntryEntity>(
                predicate: #Predicate { $0.userId == userId && $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.enteredModeRaw = entry.enteredMode.rawValue
                existing.rawValue = entry.rawValue
                existing.scaleValue = entry.scaleValue
                existing.quantityValue = entry.quantityValue
                existing.normalizedScore = entry.normalizedScore
                existing.periodRaw = entry.period.rawValue
                existing.recordedAt = entry.recordedAt
            } else {
                context.insert(SQMetricEntryEntity(entry: entry, userId: userId))
            }

            // Delete any stale rows for the same slot (different ID = pre-stable-ID data)
            let metricId = entry.metricId
            let anchorDayKey = entry.anchorDayKey
            let periodRaw = entry.period.rawValue
            let staleDescriptor = FetchDescriptor<SQMetricEntryEntity>(
                predicate: #Predicate {
                    $0.userId == userId &&
                    $0.metricId == metricId &&
                    $0.anchorDayKey == anchorDayKey &&
                    $0.periodRaw == periodRaw &&
                    $0.id != id
                }
            )
            let staleRows = try context.fetch(staleDescriptor)
            for stale in staleRows { context.delete(stale) }
        }
        try context.save()
    }

    /// Returns all entries for a given `anchorDayKey`, optionally filtered by period.
    static func getAll(
        for anchorDayKey: String,
        userId: String,
        period: SQMetricPeriod? = nil,
        context: ModelContext
    ) throws -> [SQMetricEntry] {
        let descriptor = FetchDescriptor<SQMetricEntryEntity>(
            predicate: #Predicate { $0.userId == userId && $0.anchorDayKey == anchorDayKey }
        )
        let entities = try context.fetch(descriptor)
        let filtered = period.map { p in entities.filter { $0.period == p } } ?? entities
        return filtered.map { $0.toEntry() }
    }

    /// Returns all entries with `recordedAt` after a given date (for incremental sync).
    static func getAll(after date: Date, userId: String, context: ModelContext) throws -> [SQMetricEntry] {
        let descriptor = FetchDescriptor<SQMetricEntryEntity>(
            predicate: #Predicate { $0.userId == userId && $0.recordedAt > date },
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        return try context.fetch(descriptor).map { $0.toEntry() }
    }

    static func getAll(from startDate: Date, to endDate: Date, userId: String, context: ModelContext) throws -> [SQMetricEntry] {
        let startKey = startDate.anchorDayKey()
        let endKey = endDate.anchorDayKey()
        let descriptor = FetchDescriptor<SQMetricEntryEntity>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.anchorDayKey >= startKey && $0.anchorDayKey <= endKey
            },
            sortBy: [SortDescriptor(\.recordedAt, order: .forward)]
        )
        return try context.fetch(descriptor).map { $0.toEntry() }
    }

    static func delete(
        for anchorDayKey: String,
        userId: String,
        metricIds: Set<String>,
        period: SQMetricPeriod,
        singleDailyMetricIds: Set<String>,
        keepMetricIds: Set<String>,
        in context: ModelContext
    ) throws {
        guard !metricIds.isEmpty else { return }

        let descriptor = FetchDescriptor<SQMetricEntryEntity>(
            predicate: #Predicate { $0.userId == userId && $0.anchorDayKey == anchorDayKey }
        )
        let entities = try context.fetch(descriptor)

        for entity in entities {
            guard metricIds.contains(entity.metricId) else { continue }
            guard !keepMetricIds.contains(entity.metricId) else { continue }

            if singleDailyMetricIds.contains(entity.metricId) || entity.period == period {
                context.delete(entity)
            }
        }

        try context.save()
    }
}
