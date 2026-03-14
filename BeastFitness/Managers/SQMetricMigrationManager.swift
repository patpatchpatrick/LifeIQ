//
//  SQMetricMigrationManager.swift
//  BeastFitness
//

//import SwiftData
//import Foundation
//import BeastFitnessCore
//
///// One-time migration from the legacy `SQDailyCheckInEntity` / `SQDailyCheckInStats` format
///// to the new `SQMetricEntryEntity` + `SQDailyNoteEntity` format.
/////
///// The migration is idempotent and controlled by a flag in `SQSyncMetadataEntity`.
///// Set `forceReMigrate = true` during development to re-run.
//@MainActor
//final class SQMetricMigrationManager {
//
//    /// Set to `true` to force the migration to re-run even if it has already completed.
//    /// For development/debugging only.
//    static var forceReMigrate = false
//
//    private static let migrationKey = "metric-entry-migration-v2"
//
//    // MARK: - Run Migration
//
//    /// Runs the migration if it has not already been completed (or if `forceReMigrate` is true).
//    /// Writes entries and notes to SwiftData first, then syncs all migrated data to Firestore.
//    static func runIfNeeded(
//        context: ModelContext,
//        metricsManager: SQMetricsManaging
//    ) async {
//        guard !hasMigrated(context: context) || forceReMigrate else {
//            SQLogger.shared.log("Migration already completed, skipping", .debug, context: .dailyCheckIn)
//            return
//        }
//
//        SQLogger.shared.log("Starting metric entry migration...", .info, context: .dailyCheckIn, isPriority: true)
//        do {
//            let (entries, notes) = try migrate(context: context, metricsManager: metricsManager)
//            markMigrated(context: context)
//            SQLogger.shared.log(
//                "Migration local write complete: \(entries.count) entries, \(notes.count) notes",
//                .info, context: .dailyCheckIn, isPriority: true
//            )
//
//            await pushToFirestore(entries: entries, notes: notes)
//        } catch {
//            SQLogger.shared.log("Migration failed: \(error)", .error, context: .dailyCheckIn, isPriority: true)
//        }
//    }
//
//    // MARK: - Private Migration Logic
//
//    /// Migrates legacy check-in data to SwiftData. Returns all entries and notes created.
//    private static func migrate(
//        context: ModelContext,
//        metricsManager: SQMetricsManaging
//    ) throws -> (entries: [SQMetricEntry], notes: [SQDailyNote]) {
//
//        // Load all legacy check-in entities
//        let legacyDescriptor = FetchDescriptor<SQDailyCheckInEntity>()
//        let legacyEntities = try context.fetch(legacyDescriptor)
//
//        SQLogger.shared.log("Migrating \(legacyEntities.count) legacy check-in records", .info, context: .dailyCheckIn)
//
//        // Build a lookup for metric definitions (to get period, min, max)
//        let allMetrics = metricsManager.allMetrics(includeArchived: true)
//        let metricById = Dictionary(uniqueKeysWithValues: allMetrics.map { ($0.id, $0) })
//
//        var allEntries: [SQMetricEntry] = []
//        var allNotes: [SQDailyNote] = []
//        let tz = TimeZone.current
//
//        for entity in legacyEntities {
//            let stats = entity.toStats()
//            let anchorDayKey = stats.date.anchorDayKey(in: tz)
//
//            // Convert each metric value to a SQMetricEntry
//            var entries: [SQMetricEntry] = []
//            for (metricId, rawValue) in stats.values {
//                let definition = metricById[metricId]
//                let period = definition?.period ?? .morning
//                let normalizedScore = definition.map {
//                    SQMetricEntry.normalizedScore(for: rawValue, definition: $0)
//                } ?? rawValue
//
//                let isSingleDaily = metricById[metricId]?.isSingleDailyValue ?? false
//                let entry = SQMetricEntry(
//                    id: SQMetricEntry.stableEntryId(metricId: metricId, anchorDayKey: anchorDayKey, period: period, isSingleDailyValue: isSingleDaily),
//                    metricId: metricId,
//                    recordedAt: stats.date,   // Start-of-day approximation for legacy data
//                    anchorDayKey: anchorDayKey,
//                    timeZoneIdentifier: tz.identifier,
//                    period: period,
//                    rawValue: rawValue,
//                    normalizedScore: normalizedScore
//                )
//                entries.append(entry)
//            }
//
//            try SQMetricEntryEntity.upsert(entries, in: context)
//            allEntries.append(contentsOf: entries)
//
//            // Migrate notes
//            if let notesText = stats.notes, !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
//                let note = SQDailyNote(
//                    anchorDayKey: anchorDayKey,
//                    content: notesText,
//                    updatedAt: stats.date
//                )
//                try SQDailyNoteEntity.upsert(note, in: context)
//                allNotes.append(note)
//            }
//        }
//
//        return (allEntries, allNotes)
//    }
//
//    // MARK: - Firestore Push
//
//    /// Pushes all migrated entries and notes to Firestore using daily bucket documents.
//    private static func pushToFirestore(entries: [SQMetricEntry], notes: [SQDailyNote]) async {
//        let user = SQAppState.shared.userState.loggedInUser
//
//        // Group entries by anchorDayKey → one Firestore document per day
//        let buckets = Dictionary(grouping: entries, by: { $0.anchorDayKey })
//            .map { dayKey, dayEntries in
//                SQMetricEntryBucket(anchorDayKey: dayKey, entries: dayEntries)
//            }
//
//        SQLogger.shared.log(
//            "Pushing \(buckets.count) migrated day buckets (\(entries.count) entries) and \(notes.count) notes to Firestore...",
//            .info, context: .dailyCheckIn
//        )
//
//        var pushFailures = 0
//
//        for bucket in buckets {
//            do {
//                try await SQMetricEntryService.saveEntryBucket(bucket, for: user)
//            } catch {
//                pushFailures += 1
//                SQLogger.shared.log(
//                    "Migration Firestore push failed for bucket \(bucket.anchorDayKey): \(error)",
//                    .error, context: .dailyCheckIn
//                )
//            }
//        }
//
//        for note in notes {
//            do {
//                try await SQDailyNoteService.saveDailyNote(note, for: user)
//            } catch {
//                pushFailures += 1
//                SQLogger.shared.log(
//                    "Migration Firestore push failed for note \(note.anchorDayKey): \(error)",
//                    .error, context: .dailyCheckIn
//                )
//            }
//        }
//
//        let totalDocs = buckets.count + notes.count
//        let successCount = totalDocs - pushFailures
//        SQLogger.shared.log(
//            "Migration Firestore sync complete: \(successCount)/\(totalDocs) documents pushed (\(pushFailures) failures)",
//            .info, context: .dailyCheckIn, isPriority: true
//        )
//    }
//
//    // MARK: - Migration Flag
//
//    private static func hasMigrated(context: ModelContext) -> Bool {
//        let key = migrationKey
//        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
//            predicate: #Predicate { $0.id == key }
//        )
//        return (try? context.fetch(descriptor))?.first?.lastSyncDate != nil
//    }
//
//    private static func markMigrated(context: ModelContext) {
//        let key = migrationKey
//        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
//            predicate: #Predicate { $0.id == key }
//        )
//        do {
//            if let existing = try context.fetch(descriptor).first {
//                existing.lastSyncDate = .now
//            } else {
//                let meta = SQSyncMetadataEntity(id: key)
//                meta.lastSyncDate = .now
//                context.insert(meta)
//            }
//            try context.save()
//        } catch {
//            SQLogger.shared.log("Failed to mark migration as complete: \(error)", .error, context: .dailyCheckIn)
//        }
//    }
//}
