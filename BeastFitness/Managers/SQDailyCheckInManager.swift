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
            "Checking sync for \(timeRange)",
            .debug,
            context: .dailyCheckIn
        )

        // 1. Check what data we have locally
        let localData = try SQDailyCheckInEntity.getAll(
            from: timeRange.startDate,
            to: timeRange.endDate,
            context: context
        )

        // Check sync metadata for this specific time range
        let lastSync = getLastSyncDate(for: timeRange, context: context)

        // 2. Determine sync strategy
        if localData.isEmpty {
            // No local data - need full sync
            SQLogger.shared.log(
                "No local data for \(timeRange) - full sync",
                .info,
                context: .dailyCheckIn
            )
            try await performFullSync(for: timeRange, context: context)
            return .fullSyncCompleted

        } else if lastSync == nil {
            // Have local data but never synced this time range - need full sync to ensure we have everything from Firestore
            SQLogger.shared.log(
                "Never synced \(timeRange) - full sync",
                .info,
                context: .dailyCheckIn
            )
            try await performFullSync(for: timeRange, context: context)
            return .fullSyncCompleted

        } else if shouldRefresh(for: timeRange, context: context) {
            // Have local data and it's been >6h since last sync - do incremental refresh
            let hoursSinceSync = Date().timeIntervalSince(lastSync!) / 3600
            SQLogger.shared.log(
                "Refresh needed for \(timeRange) (\(String(format: "%.1f", hoursSinceSync))h) - incremental sync",
                .info,
                context: .dailyCheckIn
            )
            try await performIncrementalSync(for: timeRange, context: context)
            return .refreshCompleted

        } else {
            // Local data is fresh - no sync needed
            SQLogger.shared.log(
                "Using cached data for \(timeRange)",
                .debug,
                context: .dailyCheckIn
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
        let user = SQAppState.shared.userState.loggedInUser

        let stats = try await dailyCheckInService.fetchAllDailyCheckIns(
            for: user,
            afterDate: timeRange.startDate
        )

        SQLogger.shared.log(
            "Full sync: \(stats.count) documents for \(timeRange)",
            .info,
            context: .dailyCheckIn,
            isPriority: true
        )

        for stat in stats {
            try SQDailyCheckInEntity.upsert(stats: stat, in: context)
        }

        updateLastSyncDate(to: Date(), for: timeRange, context: context)
    }

    @MainActor
    private func performIncrementalSync(
        for timeRange: SQTimeRange,
        context: ModelContext
    ) async throws {
        let user = SQAppState.shared.userState.loggedInUser
        let lastSync = getLastSyncDate(for: timeRange, context: context)

        let stats = try await dailyCheckInService.fetchAllDailyCheckIns(
            for: user,
            afterDate: lastSync
        )

        SQLogger.shared.log(
            "Incremental sync: \(stats.count) documents for \(timeRange)",
            .info,
            context: .dailyCheckIn,
            isPriority: true
        )

        for stat in stats {
            try SQDailyCheckInEntity.upsert(stats: stat, in: context)
        }

        updateLastSyncDate(to: Date(), for: timeRange, context: context)
    }

    @MainActor
    private func shouldRefresh(for timeRange: SQTimeRange, context: ModelContext) -> Bool {
        guard let lastSync = getLastSyncDate(for: timeRange, context: context) else {
            return true
        }

        // Refresh if >6 hours since last sync (catches multi-device updates)
        let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
        return hoursSinceSync > 6
    }

    // MARK: - Sync Metadata

    @MainActor
    private func getLastSyncDate(for timeRange: SQTimeRange, context: ModelContext) -> Date? {
        let syncId = "daily-check-in-sync-\(timeRange.rawValue)"
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == syncId }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first?.lastSyncDate
        } catch {
            SQLogger.shared.log(
                "Error fetching sync metadata: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn
            )
            return nil
        }
    }

    @MainActor
    private func updateLastSyncDate(to date: Date, for timeRange: SQTimeRange, context: ModelContext) {
        let syncId = "daily-check-in-sync-\(timeRange.rawValue)"
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == syncId }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = date
            } else {
                let metadata = SQSyncMetadataEntity(id: syncId)
                metadata.lastSyncDate = date
                context.insert(metadata)
            }

            try context.save()
        } catch {
            SQLogger.shared.log(
                "Failed to save sync metadata: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn,
                isPriority: true
            )
        }
    }
}
