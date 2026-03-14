//
//  SQMetricEntryEntity.swift
//  BeastFitness
//

import Foundation
import SwiftData

/// SwiftData entity for persisting a single metric entry locally.
/// Mirrors `SQMetricEntry` — one row per metric value logged during a check-in.
@Model
final class SQMetricEntryEntity {

    @Attribute(.unique) var id: String
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
    /// The value as entered by the user in their configured scale.
    var rawValue: Float
    /// `rawValue` normalized to 0–10 for the insight engine.
    var normalizedScore: Float

    init(entry: SQMetricEntry) {
        self.id = entry.id
        self.metricId = entry.metricId
        self.recordedAt = entry.recordedAt
        self.anchorDayKey = entry.anchorDayKey
        self.timeZoneIdentifier = entry.timeZoneIdentifier
        self.periodRaw = entry.period.rawValue
        self.rawValue = entry.rawValue
        self.normalizedScore = entry.normalizedScore
    }
}

// MARK: - Conversion

extension SQMetricEntryEntity {

    var period: SQMetricPeriod { SQMetricPeriod(unfrozenRawValue: periodRaw) }

    func toEntry() -> SQMetricEntry {
        SQMetricEntry(
            id: id,
            metricId: metricId,
            recordedAt: recordedAt,
            anchorDayKey: anchorDayKey,
            timeZoneIdentifier: timeZoneIdentifier,
            period: period,
            rawValue: rawValue,
            normalizedScore: normalizedScore
        )
    }

    /// Upserts a list of entries into the local store.
    /// Uses a stable deterministic ID (anchorDayKey/metricId/period) as the primary key.
    /// Also deletes any stale rows for the same (metricId, anchorDayKey, period) that have a
    /// different ID — handles cleanup of pre-stable-ID entries so buckets never contain duplicates.
    static func upsert(_ entries: [SQMetricEntry], in context: ModelContext) throws {
        for entry in entries {
            let id = entry.id
            let descriptor = FetchDescriptor<SQMetricEntryEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.rawValue = entry.rawValue
                existing.normalizedScore = entry.normalizedScore
                existing.periodRaw = entry.period.rawValue
                existing.recordedAt = entry.recordedAt
            } else {
                context.insert(SQMetricEntryEntity(entry: entry))
            }

            // Delete any stale rows for the same slot (different ID = pre-stable-ID data)
            let metricId = entry.metricId
            let anchorDayKey = entry.anchorDayKey
            let periodRaw = entry.period.rawValue
            let staleDescriptor = FetchDescriptor<SQMetricEntryEntity>(
                predicate: #Predicate {
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
        period: SQMetricPeriod? = nil,
        context: ModelContext
    ) throws -> [SQMetricEntry] {
        let descriptor = FetchDescriptor<SQMetricEntryEntity>(
            predicate: #Predicate { $0.anchorDayKey == anchorDayKey }
        )
        let entities = try context.fetch(descriptor)
        let filtered = period.map { p in entities.filter { $0.period == p } } ?? entities
        return filtered.map { $0.toEntry() }
    }

    /// Returns all entries with `recordedAt` after a given date (for incremental sync).
    static func getAll(after date: Date, context: ModelContext) throws -> [SQMetricEntry] {
        let descriptor = FetchDescriptor<SQMetricEntryEntity>(
            predicate: #Predicate { $0.recordedAt > date },
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        return try context.fetch(descriptor).map { $0.toEntry() }
    }
}
