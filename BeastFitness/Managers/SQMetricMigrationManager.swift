//
//  SQMetricMigrationManager.swift
//  BeastFitness
//

import SwiftData
import Foundation
import BeastFitnessCore

/// One-time migration from the legacy `SQDailyCheckInEntity` / `SQDailyCheckInStats` format
/// to the new `SQMetricEntryEntity` + `SQDailyNoteEntity` format.
///
/// The migration is idempotent and controlled by a flag in `SQSyncMetadataEntity`.
/// Set `forceReMigrate = true` during development to re-run.
@MainActor
final class SQMetricMigrationManager {

    /// Set to `true` to force the migration to re-run even if it has already completed.
    /// For development/debugging only.
    static var forceReMigrate = false

    private static let migrationKey = "metric-entry-migration-v1"

    // MARK: - Run Migration

    /// Runs the migration if it has not already been completed (or if `forceReMigrate` is true).
    static func runIfNeeded(
        context: ModelContext,
        metricsManager: SQMetricsManaging
    ) {
        guard !hasMigrated(context: context) || forceReMigrate else {
            SQLogger.shared.log("Migration already completed, skipping", .debug, context: .dailyCheckIn)
            return
        }

        SQLogger.shared.log("Starting metric entry migration...", .info, context: .dailyCheckIn, isPriority: true)
        do {
            let count = try migrate(context: context, metricsManager: metricsManager)
            markMigrated(context: context)
            SQLogger.shared.log("Migration complete: \(count) entries created", .info, context: .dailyCheckIn, isPriority: true)
        } catch {
            SQLogger.shared.log("Migration failed: \(error)", .error, context: .dailyCheckIn, isPriority: true)
        }
    }

    // MARK: - Private Migration Logic

    @discardableResult
    private static func migrate(
        context: ModelContext,
        metricsManager: SQMetricsManaging
    ) throws -> Int {

        // Load all legacy check-in entities
        let legacyDescriptor = FetchDescriptor<SQDailyCheckInEntity>()
        let legacyEntities = try context.fetch(legacyDescriptor)

        SQLogger.shared.log("Migrating \(legacyEntities.count) legacy check-in records", .info, context: .dailyCheckIn)

        // Build a lookup for metric definitions (to get period, min, max)
        let allMetrics = metricsManager.allMetrics(includeArchived: true)
        let metricById = Dictionary(uniqueKeysWithValues: allMetrics.map { ($0.id, $0) })

        var totalEntries = 0
        let tz = TimeZone.current

        for entity in legacyEntities {
            let stats = entity.toStats()
            let anchorDayKey = stats.date.anchorDayKey(in: tz)

            // Convert each metric value to a SQMetricEntry
            var entries: [SQMetricEntry] = []
            for (metricId, rawValue) in stats.values {
                let definition = metricById[metricId]
                let period = definition?.period ?? .morning
                let normalizedScore = definition.map {
                    SQMetricEntry.normalizedScore(for: rawValue, definition: $0)
                } ?? rawValue

                let entry = SQMetricEntry(
                    metricId: metricId,
                    recordedAt: stats.date,   // Start-of-day approximation for legacy data
                    anchorDayKey: anchorDayKey,
                    timeZoneIdentifier: tz.identifier,
                    period: period,
                    rawValue: rawValue,
                    normalizedScore: normalizedScore
                )
                entries.append(entry)
            }

            try SQMetricEntryEntity.upsert(entries, in: context)
            totalEntries += entries.count

            // Migrate notes
            if let notesText = stats.notes, !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let note = SQDailyNote(
                    anchorDayKey: anchorDayKey,
                    content: notesText,
                    updatedAt: stats.date
                )
                try SQDailyNoteEntity.upsert(note, in: context)
            }
        }

        return totalEntries
    }

    // MARK: - Migration Flag

    private static func hasMigrated(context: ModelContext) -> Bool {
        let key = migrationKey
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == key }
        )
        return (try? context.fetch(descriptor))?.first?.lastSyncDate != nil
    }

    private static func markMigrated(context: ModelContext) {
        let key = migrationKey
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == key }
        )
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = .now
            } else {
                let meta = SQSyncMetadataEntity(id: key)
                meta.lastSyncDate = .now
                context.insert(meta)
            }
            try context.save()
        } catch {
            SQLogger.shared.log("Failed to mark migration as complete: \(error)", .error, context: .dailyCheckIn)
        }
    }
}
