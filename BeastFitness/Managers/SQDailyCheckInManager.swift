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

    func syncDailyCheckInsIfNeeded(
        for timeRange: SQTimeRange,
        context: ModelContext
    ) async throws -> SyncResult {

        SQLogger.shared.log(
            "Starting sync check for time range: \(timeRange)",
            .debug,
            context: .dailyCheckIn
        )

        // 1. Check what data we have locally
        let localData = try SQDailyCheckInEntity.getAll(
            from: timeRange.startDate,
            to: timeRange.endDate,
            context: context
        )

        SQLogger.shared.log(
            "Found \(localData.count) local check-ins in Core Data for time range",
            .debug,
            context: .dailyCheckIn
        )

        // 2. Determine sync strategy
        if localData.isEmpty {
            // No local data - need full sync
            SQLogger.shared.log(
                "No local data found. Initiating full sync from Firestore...",
                .info,
                context: .dailyCheckIn
            )
            try await performFullSync(for: timeRange, context: context)
            return .fullSyncCompleted

        } else {
            // Have local data - check if we should refresh
            if shouldRefresh(context: context) {
                SQLogger.shared.log(
                    "Local data exists but refresh needed (>6h since last sync). Initiating incremental sync...",
                    .info,
                    context: .dailyCheckIn
                )
                try await performIncrementalSync(context: context)
                return .refreshCompleted
            }

            SQLogger.shared.log(
                "Local data is fresh. No sync needed.",
                .debug,
                context: .dailyCheckIn
            )
            return .noSyncNeeded
        }
    }

    // MARK: - Private Sync Helpers

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

    private func shouldRefresh(context: ModelContext) -> Bool {
        guard let lastSync = getLastSyncDate(context: context) else {
            return true
        }

        // Refresh if >6 hours since last sync (catches multi-device updates)
        let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
        return hoursSinceSync > 6
    }

    // MARK: - Sync Metadata

    private func getLastSyncDate(context: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == "daily-check-in-sync" }
        )

        return try? context.fetch(descriptor).first?.lastSyncDate
    }

    private func updateLastSyncDate(to date: Date, context: ModelContext) {
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == "daily-check-in-sync" }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.lastSyncDate = date
        } else {
            let metadata = SQSyncMetadataEntity(id: "daily-check-in-sync")
            metadata.lastSyncDate = date
            context.insert(metadata)
        }

        try? context.save()
    }
}
