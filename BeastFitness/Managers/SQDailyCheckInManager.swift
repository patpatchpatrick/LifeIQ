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

extension SyncResult {
    /// Shared logging for all sync services. Produces consistent output:
    ///   "Full sync: N documents for <service>"  (priority, with separators)
    ///   "Sync result: <case>"
    func logSync(documentCount: Int = 0, service: String, context: SQiOSLogContext) {
        switch self {
        case .fullSyncCompleted:
            SQLogger.shared.log("Full sync: \(documentCount) documents for \(service)", .info, context: context, isPriority: true)
        case .refreshCompleted, .incrementalSyncCompleted:
            SQLogger.shared.log("Incremental sync: \(documentCount) documents for \(service)", .info, context: context, isPriority: true)
        case .noSyncNeeded:
            break
        }
        SQLogger.shared.log("Sync result: \(self)", .debug, context: context)
    }
}

protocol SQDailyCheckInManaging {
    /// Transitional compatibility manager for legacy SQDailyCheckInStats-based UI flows.
    /// New sync and analytics code should prefer SQMetricEntryManager, while this manager
    /// continues to bridge older screens until SQDailyCheckInEntity is fully removed.

    /// Saves a daily check in locally and to the server.
    func saveDailyCheckInStats(stats: SQDailyCheckInStats, to modelContext: ModelContext) async throws
    /// Gets daily check in stats for a specific check-in period.
    /// - For `isSingleDailyValue` metrics: returns the shared daily entry regardless of session.
    /// - For periodic metrics: returns only entries recorded in the given period.
    /// Pass `period: nil` to return all entries for the day (used for completion checks).
    func getDailyCheckInStats(for date: Date, period: SQMetricPeriod?, context: ModelContext) async throws -> SQDailyCheckInStats?
    /// Returns whether the user has explicitly submitted the requested check-in session.
    func hasCompletedCheckIn(for date: Date, period: SQMetricPeriod, context: ModelContext) async throws -> Bool
    /// Smart sync that checks Core Data first and only syncs from Firestore if needed
    func syncDailyCheckInsIfNeeded(for timeRange: SQTimeRange, context: ModelContext) async throws -> SyncResult
}

final class SQDailyCheckInManager: SQDailyCheckInManaging {
    private let dailyCheckInService: SQDailyCheckInServicing.Type
    
    init(dailyCheckInService: SQDailyCheckInServicing.Type = SQDailyCheckInService.self) {
        self.dailyCheckInService = dailyCheckInService
    }
    
    func saveDailyCheckInStats(stats: SQDailyCheckInStats, to modelContext: ModelContext) async throws {

        // Write to legacy entity (dashboard reads from it until fully migrated)
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

        // Also write to new SQMetricEntry format
        let metricsManager = await SQMetricsManager.shared
        let allMetrics = await metricsManager.allMetrics(includeArchived: true)
        let metricById = Dictionary(uniqueKeysWithValues: allMetrics.map { ($0.id, $0) })
        let tz = TimeZone.current
        // anchorDayKey is derived from stats.date (the selected day), not Date.now,
        // so editing past dates writes to the correct day bucket.
        let anchorDayKey = stats.date.anchorDayKey(in: tz)
        let now = Date.now
        // Period comes from the stats model (set by the caller from the view model's
        // period, which is either the default time-of-day period or the one selected
        // via the date picker). Falls back to .morning if somehow nil.
        let submissionPeriod = stats.period ?? .morning

        var entries: [SQMetricEntry] = []
        for (metricId, rawValue) in stats.values {
            guard let definition = metricById[metricId] else { continue }
            let stableId = SQMetricEntry.stableEntryId(
                metricId: metricId,
                anchorDayKey: anchorDayKey,
                period: submissionPeriod,
                isSingleDailyValue: definition.isSingleDailyValue
            )
            let entry = SQMetricEntry(
                id: stableId,
                metricId: metricId,
                recordedAt: now,
                anchorDayKey: anchorDayKey,
                timeZoneIdentifier: tz.identifier,
                period: submissionPeriod,
                rawValue: rawValue,
                normalizedScore: SQMetricEntry.normalizedScore(for: rawValue, definition: definition)
            )
            entries.append(entry)
        }

        try SQMetricEntryEntity.upsert(entries, in: modelContext)
        let formMetricIds = Set(
            await metricsManager.dailyCheckInMetrics(for: submissionPeriod).map(\.id)
        )
        let singleDailyMetricIds = Set(
            formMetricIds.filter { metricById[$0]?.isSingleDailyValue == true }
        )
        try SQMetricEntryEntity.delete(
            for: anchorDayKey,
            metricIds: formMetricIds,
            period: submissionPeriod,
            singleDailyMetricIds: singleDailyMetricIds,
            keepMetricIds: Set(stats.values.keys),
            in: modelContext
        )
        // Record an explicit local completion marker for this session so the dashboard
        // can distinguish morning vs evening completion even when some metric values
        // are shared across both check-ins.
        try SQDailyCheckInSessionEntity.upsert(
            date: stats.date,
            period: submissionPeriod,
            completedAt: now,
            in: modelContext
        )

        if let notesText = stats.notes, !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let note = SQDailyNote(anchorDayKey: anchorDayKey, content: notesText)
            try SQDailyNoteEntity.upsert(note, in: modelContext)
        } else {
            try SQDailyNoteEntity.delete(for: anchorDayKey, in: modelContext)
        }

        // Legacy Firestore push
        do {
            try await dailyCheckInService.saveDailyCheckInStats(stats)
        } catch {
            SQLogger.shared.log("Legacy Firestore push failed: \(error)", .debug, context: .dailyCheckIn)
        }

        // Push metric entries + note to Firestore as a single daily bucket document.
        // Always use anchorDayKey (from stats.date) so editing past dates writes to
        // the correct bucket, not today's.
        guard let user = await SQAppState.shared.userState.loggedInUser else { return }
        do {
            let allDayEntries = try SQMetricEntryEntity.getAll(for: anchorDayKey, context: modelContext)
            let noteForDay = try? SQDailyNoteEntity.get(for: anchorDayKey, context: modelContext)
            let bucket = SQMetricEntryBucket(anchorDayKey: anchorDayKey, entries: allDayEntries, note: noteForDay?.content)
            try await SQMetricEntryService.saveEntryBucket(bucket, for: user)
        } catch {
            SQLogger.shared.log("Entry bucket Firestore push failed for \(anchorDayKey): \(error)", .error, context: .dailyCheckIn)
        }
    }

    func getDailyCheckInStats(for date: Date, period: SQMetricPeriod?, context: ModelContext) async throws -> SQDailyCheckInStats? {
        let anchorDayKey = date.anchorDayKey()
        let entries = try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)

        if entries.isEmpty {
            // Fall back to legacy entity during transition period.
            // Treat completely empty legacy rows as no saved check-in payload.
            let legacyStats = try SQDailyCheckInEntity.get(for: date, context: context)
            return normalizedStatsOrNil(legacyStats)
        }

        // Build SQDailyCheckInStats from new-format entries, respecting session period.
        // For single-daily-value metrics, include any entry for that metric (shared across sessions).
        // For periodic metrics, include only entries matching the requested period.
        let metricsManager = SQMetricsManager.shared
        let metricById = await Dictionary(
            uniqueKeysWithValues: metricsManager.allMetrics(includeArchived: true).map { ($0.id, $0) }
        )

        var values: [String: Float] = [:]
        for entry in entries {
            let isSingleDaily = metricById[entry.metricId]?.isSingleDailyValue ?? false
            if isSingleDaily || period == nil || entry.period == period {
                values[entry.metricId] = entry.rawValue
            }
        }
        let note = try SQDailyNoteEntity.get(for: anchorDayKey, context: context)
        return normalizedStatsOrNil(
            SQDailyCheckInStats(date: date, period: period, values: values, notes: note?.content)
        )
    }

    func hasCompletedCheckIn(for date: Date, period: SQMetricPeriod, context: ModelContext) async throws -> Bool {
        // Prefer the explicit local completion marker. Fallbacks only exist so older
        // local data continues to behave until the user submits again on the new model.
        if try SQDailyCheckInSessionEntity.exists(for: date, period: period, context: context) {
            return true
        }

        let anchorDayKey = date.anchorDayKey()
        let entries = try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)
        if !entries.isEmpty {
            return entries.contains(where: { $0.period == period })
        }

        return try SQDailyCheckInEntity.get(for: date, context: context) != nil
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
            let count = try await performFullSync(for: timeRange, context: context)
            SyncResult.fullSyncCompleted.logSync(documentCount: count, service: "\(timeRange)", context: .dailyCheckIn)
            return .fullSyncCompleted

        } else if lastSync == nil {
            // Have local data but never synced this time range - need full sync to ensure we have everything from Firestore
            SQLogger.shared.log(
                "Never synced \(timeRange) - full sync",
                .info,
                context: .dailyCheckIn
            )
            let count = try await performFullSync(for: timeRange, context: context)
            SyncResult.fullSyncCompleted.logSync(documentCount: count, service: "\(timeRange)", context: .dailyCheckIn)
            return .fullSyncCompleted

        } else if shouldRefresh(for: timeRange, context: context) {
            // Have local data and it's been >6h since last sync - do incremental refresh
            let hoursSinceSync = Date().timeIntervalSince(lastSync!) / 3600
            SQLogger.shared.log(
                "Refresh needed for \(timeRange) (\(String(format: "%.1f", hoursSinceSync))h) - incremental sync",
                .info,
                context: .dailyCheckIn
            )
            let count = try await performIncrementalSync(for: timeRange, context: context)
            SyncResult.refreshCompleted.logSync(documentCount: count, service: "\(timeRange)", context: .dailyCheckIn)
            return .refreshCompleted

        } else {
            // Local data is fresh - no sync needed
            SQLogger.shared.log(
                "Using cached data for \(timeRange)",
                .debug,
                context: .dailyCheckIn
            )
            SyncResult.noSyncNeeded.logSync(service: "\(timeRange)", context: .dailyCheckIn)
            return .noSyncNeeded
        }
    }

    // MARK: - Private Sync Helpers

    @MainActor
    private func performFullSync(
        for timeRange: SQTimeRange,
        context: ModelContext
    ) async throws -> Int {
        guard let user = SQAppState.shared.userState.loggedInUser else { throw SQError.notLoggedIn }

        let stats = try await dailyCheckInService.fetchAllDailyCheckIns(
            for: user,
            afterDate: timeRange.startDate
        )

        for stat in stats {
            try SQDailyCheckInEntity.upsert(stats: stat, in: context)
        }

        updateLastSyncDate(to: Date(), for: timeRange, context: context)
        return stats.count
    }

    @MainActor
    private func performIncrementalSync(
        for timeRange: SQTimeRange,
        context: ModelContext
    ) async throws -> Int {
        guard let user = SQAppState.shared.userState.loggedInUser else { throw SQError.notLoggedIn }
        let lastSync = getLastSyncDate(for: timeRange, context: context)

        let stats = try await dailyCheckInService.fetchAllDailyCheckIns(
            for: user,
            afterDate: lastSync
        )

        for stat in stats {
            try SQDailyCheckInEntity.upsert(stats: stat, in: context)
        }

        updateLastSyncDate(to: Date(), for: timeRange, context: context)
        return stats.count
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

private extension SQDailyCheckInManager {
    func normalizedStatsOrNil(_ stats: SQDailyCheckInStats?) -> SQDailyCheckInStats? {
        guard let stats else { return nil }

        let normalizedNotes = stats.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !stats.values.isEmpty || normalizedNotes?.isEmpty == false else {
            return nil
        }

        return SQDailyCheckInStats(
            date: stats.date,
            period: stats.period,
            values: stats.values,
            notes: normalizedNotes?.isEmpty == false ? normalizedNotes : nil
        )
    }
}
