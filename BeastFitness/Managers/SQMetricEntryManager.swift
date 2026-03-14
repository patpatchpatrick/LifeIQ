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

    /// Saves a set of metric entries and an optional note for the day to local storage and Firestore.
    func save(entries: [SQMetricEntry], note: SQDailyNote?, to context: ModelContext) async throws

    /// Returns all entries for a given calendar day (all periods).
    func getEntries(for anchorDayKey: String, context: ModelContext) throws -> [SQMetricEntry]

    /// Returns the note for a given calendar day, or nil if none exists.
    func getNote(for anchorDayKey: String, context: ModelContext) throws -> SQDailyNote?

    /// Syncs metric entries and notes from Firestore if needed.
    func syncIfNeeded(for timeRange: SQTimeRange, context: ModelContext) async throws -> SyncResult
}

// MARK: - Implementation

@MainActor
@Observable
final class SQMetricEntryManager: SQMetricEntryManaging {

    let hub: EventHub
    private let entryService: SQMetricEntryServicing.Type
    private let noteService: SQDailyNoteServicing.Type

    init(
        hub: EventHub,
        entryService: SQMetricEntryServicing.Type = SQMetricEntryService.self,
        noteService: SQDailyNoteServicing.Type = SQDailyNoteService.self
    ) {
        self.hub = hub
        self.entryService = entryService
        self.noteService = noteService
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

        // Push to Firestore (failures are logged but don't block the user)
        let user = SQAppState.shared.userState.loggedInUser
        for entry in entries {
            do {
                try await entryService.saveMetricEntry(entry, for: user)
            } catch {
                SQLogger.shared.log("Firestore push failed for entry \(entry.id): \(error)", .error, context: .dailyCheckIn)
            }
        }
        if let note {
            do {
                try await noteService.saveDailyNote(note, for: user)
            } catch {
                SQLogger.shared.log("Firestore push failed for note \(note.anchorDayKey): \(error)", .error, context: .dailyCheckIn)
            }
        }

        SQLogger.shared.log("Saved \(entries.count) entries", .info, context: .dailyCheckIn)
    }

    // MARK: - Read

    func getEntries(for anchorDayKey: String, context: ModelContext) throws -> [SQMetricEntry] {
        try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)
    }

    func getNote(for anchorDayKey: String, context: ModelContext) throws -> SQDailyNote? {
        try SQDailyNoteEntity.get(for: anchorDayKey, context: context)
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
        let user = SQAppState.shared.userState.loggedInUser
        let entries = try await entryService.fetchMetricEntries(for: user, afterDate: nil)
        let notes   = try await noteService.fetchDailyNotes(for: user, afterDate: nil)

        try SQMetricEntryEntity.upsert(entries, in: context)
        for note in notes { try SQDailyNoteEntity.upsert(note, in: context) }

        updateLastSyncDate(to: .now, context: context)
        Task { @MainActor in
            SQFirestoreMetricsManager.shared.recordReads(
                entries.count + notes.count,
                operation: "Full sync metric entries + notes"
            )
        }
        return entries.count + notes.count
    }

    private func performIncrementalSync(lastSync: Date?, context: ModelContext) async throws -> Int {
        let user = SQAppState.shared.userState.loggedInUser
        let entries = try await entryService.fetchMetricEntries(for: user, afterDate: lastSync)
        let notes   = try await noteService.fetchDailyNotes(for: user, afterDate: lastSync)

        try SQMetricEntryEntity.upsert(entries, in: context)
        for note in notes { try SQDailyNoteEntity.upsert(note, in: context) }

        updateLastSyncDate(to: .now, context: context)
        Task { @MainActor in
            SQFirestoreMetricsManager.shared.recordReads(
                entries.count + notes.count,
                operation: "Incremental sync metric entries + notes"
            )
        }
        return entries.count + notes.count
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
}
