//
//  SQMetricEntryManager.swift
//  BeastFitness
//

import SwiftData
import Foundation
import BeastFitnessCore

// MARK: - Protocol

@MainActor
protocol SQMetricEntryManaging: AnyObject {
    var hub: EventHub { get }

    /// Primary manager for canonical daily check-in value, note, and completion storage.

    /// Saves a set of metric entries and an optional note for the day to local storage and Firestore.
    func save(entries: [SQMetricEntry], note: SQDailyNote?, to context: ModelContext) async throws
    func saveDailyCheckInStats(stats: SQDailyCheckInStats, to context: ModelContext) async throws

    /// Returns all entries for a given calendar day (all periods).
    func getEntries(for anchorDayKey: String, context: ModelContext) throws -> [SQMetricEntry]

    /// Returns the note for a given calendar day, or nil if none exists.
    func getNote(for anchorDayKey: String, context: ModelContext) throws -> SQDailyNote?
    func getDailyCheckInStats(for date: Date, period: SQMetricPeriod?, context: ModelContext) async throws -> SQDailyCheckInStats?
    func hasCompletedCheckIn(for date: Date, period: SQMetricPeriod, context: ModelContext) async throws -> Bool

    /// Syncs metric entries and notes from Firestore if needed.
    func syncIfNeeded(for timeRange: SQTimeRange, context: ModelContext) async throws -> SyncResult

    /// Builds per-day dashboard stats from the canonical metric entry store for a date range.
    func getDailyCheckInStats(from startDate: Date, to endDate: Date, context: ModelContext) async throws -> [SQDailyCheckInStats]
}

// MARK: - Implementation

@MainActor
@Observable
final class SQMetricEntryManager: SQMetricEntryManaging {

    let hub: EventHub
    private let entryService: SQMetricEntryServicing.Type

    init(
        hub: EventHub,
        entryService: SQMetricEntryServicing.Type = SQMetricEntryService.self
    ) {
        self.hub = hub
        self.entryService = entryService
    }

    // MARK: - Save

    func save(entries: [SQMetricEntry], note: SQDailyNote?, to context: ModelContext) async throws {
        // Save entries locally
        do {
            try SQMetricEntryEntity.upsert(entries, in: context)
        } catch {
            SQLogger.shared.log("Failed to save entries to SwiftData: \(error)", .error, context: .dailyCheckIn)
            throw error
        }

        // Save note locally if present
        if let note {
            do {
                try SQDailyNoteEntity.upsert(note, in: context)
            } catch {
                SQLogger.shared.log("Failed to save note to SwiftData: \(error)", .error, context: .dailyCheckIn)
                throw error
            }
        }

        // Build daily buckets and push to Firestore.
        // Fetch ALL entries for each affected anchorDayKey so morning + evening are merged into one bucket.
        // The note is embedded in the bucket — no separate daily-notes write needed.
        guard let user = SQAppState.shared.userState.loggedInUser else { return }
        var affectedDays = Set(entries.map { $0.anchorDayKey })
        if let noteDay = note?.anchorDayKey { affectedDays.insert(noteDay) }

        for dayKey in affectedDays {
            do {
                let allDayEntries = try SQMetricEntryEntity.getAll(for: dayKey, context: context)
                let noteContent = try SQDailyNoteEntity.get(for: dayKey, context: context)?.content
                let bucket = SQMetricEntryBucket(anchorDayKey: dayKey, entries: allDayEntries, note: noteContent)
                try await entryService.saveEntryBucket(bucket, for: user)
            } catch {
                SQLogger.shared.log("Firestore bucket push failed for \(dayKey): \(error)", .error, context: .dailyCheckIn)
            }
        }

        SQLogger.shared.log("Saved \(entries.count) entries in \(affectedDays.count) day bucket(s)", .info, context: .dailyCheckIn)
    }

    func saveDailyCheckInStats(stats: SQDailyCheckInStats, to context: ModelContext) async throws {
        try SQMetricDefinitionManager.shared.loadIfNeeded(using: context)

        let allMetrics = SQMetricDefinitionManager.shared.allMetrics(includeArchived: true)
        let metricById = Dictionary(uniqueKeysWithValues: allMetrics.map { ($0.id, $0) })
        let timeZone = TimeZone.current
        let anchorDayKey = stats.date.anchorDayKey(in: timeZone)
        let submissionPeriod = stats.period ?? .morning
        let recordedAt = Date.now

        let entries: [SQMetricEntry] = stats.values.compactMap { metricId, rawValue in
            guard let definition = metricById[metricId] else { return nil }

            return SQMetricEntry(
                id: SQMetricEntry.stableEntryId(
                    metricId: metricId,
                    anchorDayKey: anchorDayKey,
                    period: submissionPeriod,
                    isSingleDailyValue: definition.isSingleDailyValue
                ),
                metricId: metricId,
                recordedAt: recordedAt,
                anchorDayKey: anchorDayKey,
                timeZoneIdentifier: timeZone.identifier,
                period: submissionPeriod,
                rawValue: rawValue,
                normalizedScore: SQMetricEntry.normalizedScore(for: rawValue, definition: definition)
            )
        }

        try SQMetricEntryEntity.upsert(entries, in: context)

        let formMetricIds = Set(SQMetricDefinitionManager.shared.dailyCheckInMetrics(for: submissionPeriod).map(\.id))
        let singleDailyMetricIds = Set(
            formMetricIds.filter { metricById[$0]?.isSingleDailyValue == true }
        )

        /// Deletes metrics that were removed from the check in form by the user
        try SQMetricEntryEntity.delete(
            for: anchorDayKey,
            metricIds: formMetricIds,
            period: submissionPeriod,
            singleDailyMetricIds: singleDailyMetricIds,
            keepMetricIds: Set(stats.values.keys),
            in: context
        )

        try SQDailyCheckInSessionEntity.upsert(
            date: stats.date,
            period: submissionPeriod,
            completedAt: recordedAt,
            in: context
        )

        let normalizedNotes = stats.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedNotes, !normalizedNotes.isEmpty {
            try SQDailyNoteEntity.upsert(
                SQDailyNote(
                    anchorDayKey: anchorDayKey,
                    content: normalizedNotes,
                    updatedAt: recordedAt
                ),
                in: context
            )
        } else {
            try SQDailyNoteEntity.delete(for: anchorDayKey, in: context)
        }

        guard let user = SQAppState.shared.userState.loggedInUser else { return }

        let allDayEntries = try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)
        let noteForDay = try SQDailyNoteEntity.get(for: anchorDayKey, context: context)
        let bucket = SQMetricEntryBucket(
            anchorDayKey: anchorDayKey,
            entries: allDayEntries,
            note: noteForDay?.content,
            updatedAt: recordedAt
        )
        try await entryService.saveEntryBucket(bucket, for: user)

        SQLogger.shared.log(
            "Saved daily check-in for \(anchorDayKey) (\(submissionPeriod.rawValue)) with \(entries.count) entries",
            .info,
            context: .dailyCheckIn
        )
    }

    // MARK: - Read

    func getEntries(for anchorDayKey: String, context: ModelContext) throws -> [SQMetricEntry] {
        try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)
    }

    func getNote(for anchorDayKey: String, context: ModelContext) throws -> SQDailyNote? {
        try SQDailyNoteEntity.get(for: anchorDayKey, context: context)
    }

    func getDailyCheckInStats(for date: Date, period: SQMetricPeriod?, context: ModelContext) async throws -> SQDailyCheckInStats? {
        try SQMetricDefinitionManager.shared.loadIfNeeded(using: context)

        let anchorDayKey = date.anchorDayKey()
        let entries = try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)
        let note = try SQDailyNoteEntity.get(for: anchorDayKey, context: context)

        guard !entries.isEmpty || note != nil else { return nil }

        let metricById = Dictionary(
            uniqueKeysWithValues: SQMetricDefinitionManager.shared.allMetrics(includeArchived: true).map { ($0.id, $0) }
        )

        var values: [String: Float] = [:]
        for entry in entries {
            let isSingleDaily = metricById[entry.metricId]?.isSingleDailyValue ?? false
            if isSingleDaily || period == nil || entry.period == period {
                values[entry.metricId] = entry.rawValue
            }
        }

        return normalizedStatsOrNil(
            SQDailyCheckInStats(
                date: date,
                period: period,
                values: values,
                notes: note?.content
            )
        )
    }

    func hasCompletedCheckIn(for date: Date, period: SQMetricPeriod, context: ModelContext) async throws -> Bool {
        if try SQDailyCheckInSessionEntity.exists(for: date, period: period, context: context) {
            return true
        }

        let anchorDayKey = date.anchorDayKey()
        let entries = try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)
        return entries.contains(where: { $0.period == period })
    }

    func getDailyCheckInStats(from startDate: Date, to endDate: Date, context: ModelContext) async throws -> [SQDailyCheckInStats] {
        let entries = try SQMetricEntryEntity.getAll(from: startDate, to: endDate, context: context)
        let notes = try SQDailyNoteEntity.getAll(from: startDate, to: endDate, context: context)

        var valuesByDay = [String: [String: SQMetricEntry]]()
        for entry in entries {
            var metricMap = valuesByDay[entry.anchorDayKey, default: [:]]
            if let existing = metricMap[entry.metricId] {
                if entry.recordedAt > existing.recordedAt {
                    metricMap[entry.metricId] = entry
                }
            } else {
                metricMap[entry.metricId] = entry
            }
            valuesByDay[entry.anchorDayKey] = metricMap
        }

        let notesByDay = Dictionary(uniqueKeysWithValues: notes.map { ($0.anchorDayKey, $0.content) })
        let dayKeys = Set(valuesByDay.keys).union(notesByDay.keys).sorted()

        return dayKeys.compactMap { dayKey in
            let dayDate = SQDateFormatters.shared.date(from: dayKey, preferredStyle: .firebaseDayKey)
            guard let dayDate else { return nil }

            let values = valuesByDay[dayKey, default: [:]].mapValues(\.rawValue)
            guard !values.isEmpty || notesByDay[dayKey] != nil else { return nil }

            return SQDailyCheckInStats(
                date: dayDate,
                period: nil,
                values: values,
                notes: notesByDay[dayKey]
            )
        }
    }

    // MARK: - Sync

    func syncIfNeeded(for timeRange: SQTimeRange, context: ModelContext) async throws -> SyncResult {
        SQLogger.shared.log("Checking entry sync for \(timeRange)", .debug, context: .dailyCheckIn)

        let localEntries = try SQMetricEntryEntity.getAll(after: timeRange.startDate, context: context)
        let lastSync = getLastSyncDate(context: context)

        if localEntries.isEmpty || lastSync == nil {
            let count = try await performFullSync(context: context)
            SyncResult.fullSyncCompleted.logSync(documentCount: count, service: "MetricEntries", context: .dailyCheckIn)
            return .fullSyncCompleted
        } else if shouldRefresh(lastSync: lastSync) {
            let count = try await performIncrementalSync(lastSync: lastSync, context: context)
            SyncResult.refreshCompleted.logSync(documentCount: count, service: "MetricEntries", context: .dailyCheckIn)
            return .refreshCompleted
        } else {
            SyncResult.noSyncNeeded.logSync(service: "MetricEntries", context: .dailyCheckIn)
            return .noSyncNeeded
        }
    }

    // MARK: - Private Sync Helpers
    private func performFullSync(context: ModelContext) async throws -> Int {
        guard let user = SQAppState.shared.userState.loggedInUser else { throw SQError.notLoggedIn }
        let buckets = try await entryService.fetchEntryBuckets(for: user, afterDate: nil)

        let entries = buckets.flatMap { $0.entries }
        try SQMetricEntryEntity.upsert(entries, in: context)
        try upsertNotes(from: buckets, in: context)

        updateLastSyncDate(to: .now, context: context)
        Task { @MainActor in
            SQFirestoreMetricsManager.shared.recordReads(
                buckets.count,
                operation: "Full sync metric buckets"
            )
        }
        return buckets.count
    }

    private func performIncrementalSync(lastSync: Date?, context: ModelContext) async throws -> Int {
        guard let user = SQAppState.shared.userState.loggedInUser else { throw SQError.notLoggedIn }
        let buckets = try await entryService.fetchEntryBuckets(for: user, afterDate: lastSync)

        let entries = buckets.flatMap { $0.entries }
        try SQMetricEntryEntity.upsert(entries, in: context)
        try upsertNotes(from: buckets, in: context)

        updateLastSyncDate(to: .now, context: context)
        Task { @MainActor in
            SQFirestoreMetricsManager.shared.recordReads(
                buckets.count,
                operation: "Incremental sync metric buckets"
            )
        }
        return buckets.count
    }

    /// Extracts notes embedded in buckets and upserts them into local SwiftData storage.
    private func upsertNotes(from buckets: [SQMetricEntryBucket], in context: ModelContext) throws {
        for bucket in buckets {
            let normalizedContent = bucket.note?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let normalizedContent, !normalizedContent.isEmpty {
                let note = SQDailyNote(
                    anchorDayKey: bucket.anchorDayKey,
                    content: normalizedContent,
                    updatedAt: bucket.updatedAt
                )
                try SQDailyNoteEntity.upsert(note, in: context)
            } else {
                try SQDailyNoteEntity.delete(for: bucket.anchorDayKey, in: context)
            }
        }
    }

    private func shouldRefresh(lastSync: Date?) -> Bool {
        guard let lastSync else { return true }
        return Date().timeIntervalSince(lastSync) / 3600 > 6
    }

    // MARK: - Sync Metadata

    private let syncMetadataId = "metric-entries-sync"

    private func getLastSyncDate(context: ModelContext) -> Date? {
        let id = syncMetadataId
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first?.lastSyncDate
    }

    private func updateLastSyncDate(to date: Date, context: ModelContext) {
        let id = syncMetadataId
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = date
            } else {
                let meta = SQSyncMetadataEntity(id: id)
                meta.lastSyncDate = date
                context.insert(meta)
            }
            try context.save()
        } catch {
            SQLogger.shared.log("Failed to save entry sync metadata: \(error)", .error, context: .dailyCheckIn)
        }
    }

    private func normalizedStatsOrNil(_ stats: SQDailyCheckInStats?) -> SQDailyCheckInStats? {
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
