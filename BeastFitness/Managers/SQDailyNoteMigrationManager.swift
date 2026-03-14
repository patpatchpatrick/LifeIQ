//
//  SQDailyNoteMigrationManager.swift
//  BeastFitness
//

import SwiftData
import Foundation
import BeastFitnessCore

/// One-time migration: reads all `daily-notes` documents from Firestore and
/// re-saves each day's `metric-entries` bucket with the note embedded.
/// After this runs, the `daily-notes` collection is no longer written to or read from.
@MainActor
final class SQDailyNoteMigrationManager {

    /// Set to `true` to force the migration to re-run even if already completed.
    static var forceReMigrate = false

    private static let migrationKey = "daily-note-consolidation-v1"

    // MARK: - Run Migration

    static func runIfNeeded(context: ModelContext) async {
        guard !hasMigrated(context: context) || forceReMigrate else {
            SQLogger.shared.log("Daily note consolidation already completed, skipping", .debug, context: .dailyCheckIn)
            return
        }

        SQLogger.shared.log("Starting daily note consolidation migration...", .info, context: .dailyCheckIn, isPriority: true)

        let user = SQAppState.shared.userState.loggedInUser

        do {
            // Fetch all notes from the legacy daily-notes Firestore collection
            let notes = try await SQDailyNoteService.fetchDailyNotes(for: user, afterDate: nil)

            guard !notes.isEmpty else {
                SQLogger.shared.log("No daily notes found — marking migration complete", .info, context: .dailyCheckIn)
                markMigrated(context: context)
                return
            }

            SQLogger.shared.log("Migrating \(notes.count) daily notes into metric-entry buckets...", .info, context: .dailyCheckIn)

            var failures = 0

            for note in notes {
                do {
                    // Load all local entries for this day so we build a complete bucket
                    let entries = try SQMetricEntryEntity.getAll(for: note.anchorDayKey, context: context)
                    let bucket = SQMetricEntryBucket(anchorDayKey: note.anchorDayKey, entries: entries, note: note.content)
                    try await SQMetricEntryService.saveEntryBucket(bucket, for: user)

                    // Keep local note entity in sync
                    try SQDailyNoteEntity.upsert(note, in: context)
                } catch {
                    failures += 1
                    SQLogger.shared.log(
                        "Migration failed for note \(note.anchorDayKey): \(error)",
                        .error, context: .dailyCheckIn
                    )
                }
            }

            if failures == 0 {
                markMigrated(context: context)
                SQLogger.shared.log(
                    "✅ Daily note consolidation complete: \(notes.count) notes migrated into metric-entry buckets",
                    .info, context: .dailyCheckIn, isPriority: true
                )
            } else {
                SQLogger.shared.log(
                    "Daily note consolidation finished with \(failures)/\(notes.count) failures — will retry next launch",
                    .error, context: .dailyCheckIn, isPriority: true
                )
            }
        } catch {
            SQLogger.shared.log("Daily note consolidation failed: \(error)", .error, context: .dailyCheckIn, isPriority: true)
        }
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
            SQLogger.shared.log("Failed to mark daily note migration as complete: \(error)", .error, context: .dailyCheckIn)
        }
    }
}
