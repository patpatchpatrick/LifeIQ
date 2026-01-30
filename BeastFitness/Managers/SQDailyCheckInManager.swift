//
//  SQDailyCheckInManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftData
import Foundation
import BeastFitnessCore

enum SyncResult {
    case noSyncNeeded
    case fullSyncCompleted
    case incrementalSyncCompleted
    case refreshCompleted
}

protocol SQDailyCheckInManaging {
    /// Saves a daily check in locally and to the server
    func saveDailyCheckInStats(stats: SQDailyCheckInStats, to modelContext: ModelContext) async throws
    /// Gets daily check in stats.  This only checks locally right now, doesn't check Firebase.
    func getDailyCheckInStats(for date: Date, context: ModelContext) async throws -> SQDailyCheckInStats?
    /// Smart sync that checks Core Data first and only syncs from Firestore if needed
    func syncDailyCheckInsIfNeeded(for timeRange: SQTimeRange, context: ModelContext) async throws -> SyncResult
}

final class SQDailyCheckInManager: SQDailyCheckInManaging {
    private let dailyCheckInService: SQDailyCheckInServicing.Type
    
    init(dailyCheckInService: SQDailyCheckInServicing.Type = SQDailyCheckInService.self) {
        self.dailyCheckInService = dailyCheckInService
    }
    
    func saveDailyCheckInStats(stats: SQDailyCheckInStats, to modelContext: ModelContext) async throws {
        
        do {
            try SQDailyCheckInEntity.upsert(stats: stats, in: modelContext)
        } catch {
            SQLogger.shared.log(
                "Saving daily stats to SwiftData failed: \(error)",
                .error,
                context: .dailyCheckIn
            )
            
            throw error
        }
        
        do {
            try await dailyCheckInService.saveDailyCheckInStats(stats)
        } catch {
            
            SQLogger.shared.log("Submitting daily stats failed with error: \(error)", .debug, context: .dailyCheckIn)
            // TODO: PTD Error - throw check in error here and let the user know that failed to save to cloud... add a system to retry saving all failed daily check ins in the background in the future.
        }
    }
    
    func getDailyCheckInStats(for date: Date, context: ModelContext) async throws -> SQDailyCheckInStats? {
        return try SQDailyCheckInEntity.get(for: date, context: context)
    }

    // MARK: - Smart Sync

    @MainActor
    func syncDailyCheckInsIfNeeded(
        for timeRange: SQTimeRange,
        context: ModelContext
    ) async throws -> SyncResult {

        SQLogger.shared.log(
            "📊 Starting sync check for time range: \(timeRange) (\(timeRange.startDate.formatted()) to \(timeRange.endDate.formatted()))",
            .info,
            context: .dailyCheckIn,
            isPriority: true
        )

        // 1. Check what data we have locally
        let localData = try SQDailyCheckInEntity.getAll(
            from: timeRange.startDate,
            to: timeRange.endDate,
            context: context
        )

        SQLogger.shared.log(
            "📦 Found \(localData.count) local check-ins in SwiftData for this time range",
            .info,
            context: .dailyCheckIn,
            isPriority: true
        )

        // Check sync metadata
        let lastSync = getLastSyncDate(context: context)
        let lastSyncInfo = lastSync.map { "Last sync: \($0.formatted())" } ?? "Never synced"
        SQLogger.shared.log(
            "🕐 \(lastSyncInfo)",
            .info,
            context: .dailyCheckIn,
            isPriority: true
        )

        // 2. Determine sync strategy
        if localData.isEmpty {
            // No local data - need full sync
            SQLogger.shared.log(
                "⚠️ No local data found. Initiating full sync from Firestore...",
                .info,
                context: .dailyCheckIn,
                isPriority: true
            )
            try await performFullSync(for: timeRange, context: context)
            return .fullSyncCompleted

        } else if lastSync == nil {
            // Have local data but never synced - need full sync to ensure we have everything from Firestore
            SQLogger.shared.log(
                "⚠️ Local data exists but never synced. Initiating full sync from Firestore...",
                .info,
                context: .dailyCheckIn,
                isPriority: true
            )
            try await performFullSync(for: timeRange, context: context)
            return .fullSyncCompleted

        } else if shouldRefresh(context: context) {
            // Have local data and it's been >6h since last sync - do incremental refresh
            let hoursSinceSync = Date().timeIntervalSince(lastSync!) / 3600
            SQLogger.shared.log(
                "🔄 Local data exists but refresh needed (\(String(format: "%.1f", hoursSinceSync))h since last sync). Initiating incremental sync...",
                .info,
                context: .dailyCheckIn,
                isPriority: true
            )
            try await performIncrementalSync(context: context)
            return .refreshCompleted

        } else {
            // Local data is fresh - no sync needed
            let hoursSinceSync = Date().timeIntervalSince(lastSync!) / 3600
            SQLogger.shared.log(
                "✅ Local data is fresh (\(String(format: "%.1f", hoursSinceSync))h since last sync). No sync needed.",
                .info,
                context: .dailyCheckIn,
                isPriority: true
            )
            return .noSyncNeeded
        }
    }

    // MARK: - Private Sync Helpers

    @MainActor
    private func performFullSync(
        for timeRange: SQTimeRange,
        context: ModelContext
    ) async throws {
        let user = await SQAppState.shared.userState.loggedInUser

        SQLogger.shared.log(
            "Fetching all daily check-ins from Firestore for user: \(user.id)",
            .info,
            context: .dailyCheckIn
        )

        let stats = try await dailyCheckInService.fetchAllDailyCheckIns(
            for: user,
            afterDate: timeRange.startDate
        )

        SQLogger.shared.log(
            "✅ Full sync completed: Fetched \(stats.count) documents from Firestore",
            .info,
            context: .dailyCheckIn,
            isPriority: true
        )

        for stat in stats {
            try SQDailyCheckInEntity.upsert(stats: stat, in: context)
        }

        updateLastSyncDate(to: Date(), context: context)

        SQLogger.shared.log(
            "Saved \(stats.count) check-ins to Core Data",
            .debug,
            context: .dailyCheckIn
        )
    }

    @MainActor
    private func performIncrementalSync(
        context: ModelContext
    ) async throws {
        let user = await SQAppState.shared.userState.loggedInUser
        let lastSync = getLastSyncDate(context: context)

        let lastSyncInfo = lastSync.map { "since \($0.formatted())" } ?? "all time"
        SQLogger.shared.log(
            "Fetching incremental updates from Firestore \(lastSyncInfo)",
            .info,
            context: .dailyCheckIn
        )

        let stats = try await dailyCheckInService.fetchAllDailyCheckIns(
            for: user,
            afterDate: lastSync
        )

        SQLogger.shared.log(
            "✅ Incremental sync completed: Fetched \(stats.count) documents from Firestore",
            .info,
            context: .dailyCheckIn,
            isPriority: true
        )

        for stat in stats {
            try SQDailyCheckInEntity.upsert(stats: stat, in: context)
        }

        updateLastSyncDate(to: Date(), context: context)

        SQLogger.shared.log(
            "Updated \(stats.count) check-ins in Core Data",
            .debug,
            context: .dailyCheckIn
        )
    }

    @MainActor
    private func shouldRefresh(context: ModelContext) -> Bool {
        guard let lastSync = getLastSyncDate(context: context) else {
            return true
        }

        // Refresh if >6 hours since last sync (catches multi-device updates)
        let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
        return hoursSinceSync > 6
    }

    // MARK: - Sync Metadata

    @MainActor
    private func getLastSyncDate(context: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == "daily-check-in-sync" }
        )

        do {
            let results = try context.fetch(descriptor)
            SQLogger.shared.log(
                "🔍 Fetched \(results.count) sync metadata records",
                .debug,
                context: .dailyCheckIn
            )

            if let metadata = results.first {
                SQLogger.shared.log(
                    "📅 Found sync metadata: lastSyncDate = \(metadata.lastSyncDate?.formatted() ?? "nil")",
                    .debug,
                    context: .dailyCheckIn
                )
                return metadata.lastSyncDate
            } else {
                SQLogger.shared.log(
                    "⚠️ No sync metadata found in database",
                    .debug,
                    context: .dailyCheckIn
                )
                return nil
            }
        } catch {
            SQLogger.shared.log(
                "❌ Error fetching sync metadata: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn
            )
            return nil
        }
    }

    @MainActor
    private func updateLastSyncDate(to date: Date, context: ModelContext) {
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == "daily-check-in-sync" }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = date
                SQLogger.shared.log(
                    "💾 Updating existing sync metadata: lastSyncDate = \(date.formatted())",
                    .info,
                    context: .dailyCheckIn,
                    isPriority: true
                )
            } else {
                let metadata = SQSyncMetadataEntity(id: "daily-check-in-sync")
                metadata.lastSyncDate = date
                context.insert(metadata)
                SQLogger.shared.log(
                    "💾 Creating new sync metadata: lastSyncDate = \(date.formatted())",
                    .info,
                    context: .dailyCheckIn,
                    isPriority: true
                )
            }

            try context.save()
            SQLogger.shared.log(
                "✅ Sync metadata saved to SwiftData successfully",
                .info,
                context: .dailyCheckIn,
                isPriority: true
            )

            // Verify it was saved by fetching it again
            let verification = try context.fetch(descriptor)
            if let verified = verification.first {
                SQLogger.shared.log(
                    "✓ Verified sync metadata in database: \(verified.lastSyncDate?.formatted() ?? "nil")",
                    .info,
                    context: .dailyCheckIn,
                    isPriority: true
                )
            } else {
                SQLogger.shared.log(
                    "⚠️ WARNING: Sync metadata not found after save!",
                    .error,
                    context: .dailyCheckIn,
                    isPriority: true
                )
            }
        } catch {
            SQLogger.shared.log(
                "❌ Failed to save sync metadata: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn,
                isPriority: true
            )
        }
    }
}
