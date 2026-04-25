//
//  SQWorkoutManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

import SwiftData
import Foundation
import HealthKit
import BeastFitnessCore

@MainActor
protocol SQWorkoutManaging {
    func saveWorkout(workout: SQWorkoutSessionable, to modelContext: ModelContext, saveToCloud: Bool) async throws
    func deleteWorkout(workout: SQWorkoutSessionable, from modelContext: ModelContext) async throws
    func deletionTypeForWorkout(_ workout: any SQWorkoutSessionable) -> SQWorkoutManager.WorkoutDeletionType
    func getWorkout(withHkWorkoutId hkWorkoutId: String?, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> SQWorkoutSessionable?
    func getWorkouts(
        for timeRange: SQTimeRange,
        modelContext: ModelContext,
        includeHealthKitWorkouts: Bool
    ) async throws -> [SQWorkoutSessionable]
    func getWorkouts(for timeRange: SQTimeRange, modelContext: ModelContext) async throws -> [SQWorkoutSessionable]
    func markWorkoutsAsProcessed(_ workouts: [SQWorkoutSessionable], context: ModelContext)
    func fetchProcessedSourceIds(context: ModelContext) -> Set<String>
}

extension SQWorkoutManaging {
    func getWorkouts(for timeRange: SQTimeRange, modelContext: ModelContext) async throws -> [SQWorkoutSessionable] {
        try await getWorkouts(
            for: timeRange,
            modelContext: modelContext,
            includeHealthKitWorkouts: true
        )
    }
}

@MainActor
final class SQWorkoutManager: SQWorkoutManaging {
    static let shared = SQWorkoutManager()

    private let workoutService: SQWorkoutServicing.Type
    private let healthKitManager: SQHealthKitManaging
    private let userState: SQUserStating
    private var isSyncInProgress = false
    private var needsSyncAfterCurrentRun = false
    private var needsForcedSyncAfterCurrentRun = false

    init(
        workoutService: SQWorkoutServicing.Type = SQWorkoutService.self,
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        userState: SQUserStating = SQAppState.shared.userState
    ) {
        self.workoutService = workoutService
        self.healthKitManager = healthKitManager
        self.userState = userState
    }
    
    func getWorkouts(
        for timeRange: SQTimeRange,
        modelContext: ModelContext,
        includeHealthKitWorkouts: Bool
    ) async throws -> [any SQWorkoutSessionable] {
        if SQAdminConfig.useMockHealthData {
            guard includeHealthKitWorkouts else { return [] }
            return SQHealthKitManager.shared.mockHealthData
                .workoutSessions(for: timeRange)
                .compactMap { safeguardedWorkout(workout: $0) }
        }

        await syncWorkoutsIfNeeded(context: modelContext)

        var allWorkouts = [SQWorkoutSessionable]()
        var seenWorkoutIds = Set<String>()
        let userId = userState.loggedInUser?.id

        if includeHealthKitWorkouts {
            let healthKitWorkouts = try await healthKitManager.fetchWorkouts(timeRange)

            for hkWorkout in healthKitWorkouts {
                do {
                    let source = SQWorkoutSource.hkWorkout(.init(hkWorkout: hkWorkout))
                    let savedWorkout = try getWorkout(
                        withHkWorkoutId: hkWorkout.uuid.uuidString,
                        workoutSource: source,
                        modelContext: modelContext
                    )

                    if let savedWorkout {
                        if seenWorkoutIds.insert(savedWorkout.id).inserted {
                            allWorkouts.appendIfNotNil(safeguardedWorkout(workout: savedWorkout))
                        }
                    } else {
                        let sqHkWorkout = SQWorkoutSession(
                            workoutSource: source,
                            overrideData: nil,
                            hkWorkoutId: nil
                        )
                        if seenWorkoutIds.insert(sqHkWorkout.id).inserted {
                            allWorkouts.appendIfNotNil(safeguardedWorkout(workout: sqHkWorkout))
                        }
                    }

                } catch {
                    let workoutSource = SQWorkoutSource.hkWorkout(.init(hkWorkout: hkWorkout))
                    let sqHkWorkout = SQWorkoutSession(workoutSource: workoutSource, overrideData: nil, hkWorkoutId: nil)
                    if seenWorkoutIds.insert(sqHkWorkout.id).inserted {
                        allWorkouts.appendIfNotNil(safeguardedWorkout(workout: sqHkWorkout))
                    }
                }
            }
        }

        if let userId {
            do {
                let manualEntities = try SQWorkoutSessionEntity.getManualWorkouts(for: timeRange, userId: userId, context: modelContext)
                for entity in manualEntities {
                    let manualWorkout = try entity.toSession(workoutSource: nil)
                    if seenWorkoutIds.insert(manualWorkout.id).inserted {
                        allWorkouts.appendIfNotNil(safeguardedWorkout(workout: manualWorkout))
                    }
                }
            } catch {
                SQLogger.shared.log(
                    "Failed to load local manual workouts: \(error)",
                    .error,
                    context: .workoutManager
                )
            }
        }
        
        return allWorkouts.sorted {
            ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast)
        }
    }
    
    /// Checks if a workout can be shown
    private func safeguardedWorkout(workout: SQWorkoutSessionable) -> SQWorkoutSessionable? {
        guard !SQUserDefaults.shared.isWorkoutHidden(workout.workoutSource.sourcableData.sourceId) else {
            return nil
        }
        return workout
    }
    
    func saveWorkout(workout: SQWorkoutSessionable, to modelContext: ModelContext, saveToCloud: Bool = true) async throws {
        guard userState.isLoggedIn else {
            throw SQError.standard(withDescription: "Please log in to save workouts and workout reviews.")
        }
        guard let userId = userState.loggedInUser?.id else { throw SQError.notLoggedIn }

        if workout.hkWorkoutId == nil {
            do {
                SQLogger.shared.log("Attempting to save workout to HealthKit", .debug, context: .healthKit)
                let hkWorkout = try await healthKitManager.saveWorkout(workout: workout)
                workout.updateHkWorkoutId(hkWorkout?.uuid.uuidString)
                healthKitManager.invalidateCache()
                SQLogger.shared.log("Invalidated HK cache after saving workout", .debug, context: .workoutManager)
            } catch {
                throw SQError.standard(withDescription: "Could not save workout to HealthKit due to error: \(error.localizedDescription).")
            }
        }

        do {
            try SQWorkoutSessionEntity.upsert(session: workout, userId: userId, in: modelContext)
            try markWorkoutPendingUpload(workoutId: workout.id, userId: userId, context: modelContext)
            SQLogger.shared.log("Successfully saved workout: \(workout.prettyDescription)", .debug, context: .workoutManager)
        } catch {
            SQLogger.shared.log(
                "Saving workout to SwiftData failed: \(error)",
                .error,
                context: .workoutManager
            )
            throw error
        }

        if saveToCloud {
            await syncWorkoutsIfNeeded(context: modelContext)
        }

        await SQWorkoutSession.metadataManager.invalidate()
    }
    
    enum WorkoutDeletionType {
        case hiddenHealtKit
        case hiddenStrava
        case standard /// Deleted from data and HealthKit
    }
    
    func deletionTypeForWorkout(_ workout: any SQWorkoutSessionable) -> WorkoutDeletionType {
        switch workout.workoutSource {
        case .hkWorkout(let hkWorkout):
            let wasCreatedByThisApp = hkWorkout.hkWorkout.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier
            
            /// Can only delete workouts in HealthKit that were created by this app
            return wasCreatedByThisApp ? .standard : .hiddenHealtKit
            
        case .stravaWorkout:
            return .hiddenStrava
            
        case .manual:
            return .standard
        }
    }
    
    private func attemptToDeleteWorkoutFromHealthKit(_ workout: SQWorkoutSessionable) async {
        if let healthKitId = workout.hkWorkoutId {
            do {
                try await healthKitManager.deleteWorkout(with: healthKitId)
                SQLogger.shared.log("Successfully deleted workout from HealthKit: \(workout.id)-\(workout.visibleTitle)", .info, context: .workoutManager)
            } catch {
                // HealthKit deletion failures are expected to be rare here because we only attempt
                // this path for workouts we believe are app-owned. If this fails, log it and let
                // the caller decide whether to keep or hide the local workout state.
                SQLogger.shared.log("Could not delete workout from HealthKit: \(error)", .error, context: .workoutManager)
            }
        }
    }
    
    func deleteWorkout(workout: any SQWorkoutSessionable, from modelContext: ModelContext) async throws {
        guard let userId = userState.loggedInUser?.id else { throw SQError.notLoggedIn }
        
        let deletionType = deletionTypeForWorkout(workout)
        
        switch deletionType {
        case .hiddenHealtKit, .hiddenStrava:
            SQLogger.shared.log("Hiding workout: \(workout.id)-\(workout.visibleTitle)", .info, context: .workoutManager)
            SQUserDefaults.shared.hideWorkout(workout.workoutSource.sourcableData.sourceId)
            
        case .standard:
            await attemptToDeleteWorkoutFromHealthKit(workout)
            await healthKitManager.invalidateCache()
            SQLogger.shared.log("Invalidated HK cache after deleting workout", .debug, context: .workoutManager)

        }
        
        do {
            let deleteMode: SQWorkoutSessionEntity.DeleteMode = deletionType == .standard ? .soft : .hard
            try SQWorkoutSessionEntity.delete(workoutSession: workout, userId: userId, in: modelContext, mode: deleteMode)
            SQLogger.shared.log("Successfully deleted workout from SwiftData: \(workout.id)-\(workout.visibleTitle)", .info, context: .workoutManager)
        } catch {
            SQLogger.shared.log("Could not delete workout from SwiftData: \(error)", .error, context: .workoutManager)
        }

        if deletionType == .standard {
            await syncWorkoutsIfNeeded(context: modelContext)
        }

        await SQWorkoutSession.metadataManager.invalidate()
    }
    
    func getWorkout(withHkWorkoutId hkWorkoutId: String?, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> (any SQWorkoutSessionable)? {
        if SQAdminConfig.useMockHealthData {
            return SQHealthKitManager.shared.mockHealthData.workoutSession(withHkWorkoutId: hkWorkoutId)
                ?? SQHealthKitManager.shared.mockHealthData.workoutSession(sourceId: workoutSource.sourcableData.sourceId)
        }

        guard let userId = userState.loggedInUser?.id else { return nil }
        if let workout = try SQWorkoutSessionEntity.getFromHkWorkout(
            source: workoutSource,
            hkWorkoutId: hkWorkoutId,
            userId: userId,
            context: modelContext
        ) {
            return workout
        }

        return try SQWorkoutSessionEntity.get(
            id: workoutSource.sourcableData.sourceId,
            userId: userId,
            context: modelContext,
            workoutSource: workoutSource
        )
    }

    func markWorkoutsAsProcessed(_ workouts: [SQWorkoutSessionable], context: ModelContext) {
        guard let userId = userState.loggedInUser?.id else { return }
        for workout in workouts {
            let sourceId = workout.workoutSource.sourcableData.sourceId
            SQWorkoutProcessedEntity.markAsProcessed(sourceId: sourceId, userId: userId, context: context)
        }
        SQLogger.shared.log(
            "Marked \(workouts.count) workout(s) as processed",
            .debug,
            context: .workoutManager
        )
    }

    func fetchProcessedSourceIds(context: ModelContext) -> Set<String> {
        guard let userId = userState.loggedInUser?.id else { return [] }
        return SQWorkoutProcessedEntity.fetchProcessedSourceIds(userId: userId, context: context)
    }

    func syncWorkoutsIfNeeded(context: ModelContext, force: Bool = false) async {
        guard !SQAdminConfig.useMockHealthData else { return }
        guard SQAppState.shared.userState.loggedInUser != nil else { return }

        if isSyncInProgress {
            needsSyncAfterCurrentRun = true
            needsForcedSyncAfterCurrentRun = needsForcedSyncAfterCurrentRun || force
            return
        }

        isSyncInProgress = true
        defer {
            isSyncInProgress = false
        }

        var shouldForceCurrentRun = force

        while true {
            await flushPendingWorkoutSync(context: context)

            let lastSync = getLastSyncDate(context: context)
            let shouldFetchRemote = shouldForceCurrentRun || lastSync == nil || shouldRefresh(lastSync: lastSync)

            if shouldFetchRemote {
                do {
                    guard let user = SQAppState.shared.userState.loggedInUser else { return }
                    let documents = try await workoutService.fetchWorkouts(
                        for: user,
                        afterDate: shouldForceCurrentRun ? nil : lastSync
                    )
                    for document in documents {
                        try SQWorkoutSessionEntity.upsert(remoteDocument: document, userId: user.id, in: context)
                    }
                    updateLastSyncDate(to: .now, context: context)
                    let result: SyncResult = lastSync == nil || shouldForceCurrentRun ? .fullSyncCompleted : .refreshCompleted
                    result.logSync(documentCount: documents.count, service: "Workout", context: .workoutManager)
                } catch {
                    SQLogger.shared.log(
                        "[Sync - Workout] Metadata sync failed: \(error)",
                        .error,
                        context: .workoutManager
                    )
                }
            }

            guard needsSyncAfterCurrentRun else { break }
            shouldForceCurrentRun = needsForcedSyncAfterCurrentRun
            needsSyncAfterCurrentRun = false
            needsForcedSyncAfterCurrentRun = false
        }
    }

    private func flushPendingWorkoutSync(context: ModelContext) async {
        guard let user = SQAppState.shared.userState.loggedInUser else { return }

        do {
            let pendingEntities = try SQWorkoutSessionEntity.getPendingSyncEntities(userId: user.id, context: context)
            guard !pendingEntities.isEmpty else { return }

            for entity in pendingEntities {
                guard let document = entity.toSyncDocument() else {
                    SQLogger.shared.log(
                        "[Sync - Workout] Skipping upload for \(entity.workoutId) due to missing metadata timestamps",
                        .warning,
                        context: .workoutManager
                    )
                    continue
                }

                do {
                    try await workoutService.saveWorkout(document, for: user)
                    entity.markSynced(remoteId: document.remoteId, updatedAt: document.updatedAt)
                    try context.save()
                } catch {
                    SQLogger.shared.log(
                        "Workout metadata upload failed for \(entity.workoutId): \(error)",
                        .debug,
                        context: .workoutManager
                    )
                }
            }
        } catch {
            SQLogger.shared.log(
                "[Sync - Workout] Failed to fetch pending sync entities: \(error)",
                .error,
                context: .workoutManager
            )
        }
    }

    private func markWorkoutPendingUpload(workoutId: String, userId: String, context: ModelContext) throws {
        guard let entity = try SQWorkoutSessionEntity.getEntity(workoutId: workoutId, userId: userId, context: context) else {
            return
        }
        entity.markPendingUpload()
        try context.save()
    }

    private func shouldRefresh(lastSync: Date?) -> Bool {
        guard let lastSync else { return true }
        return Date().timeIntervalSince(lastSync) / 3600 > 6
    }

    private func syncMetadataId() -> String {
        if let userId = SQAppState.shared.userState.loggedInUser?.id {
            return "workouts-sync-\(userId)"
        }
        return "workouts-sync-guest"
    }

    private func getLastSyncDate(context: ModelContext) -> Date? {
        let id = syncMetadataId()
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first?.lastSyncDate
    }

    private func updateLastSyncDate(to date: Date, context: ModelContext) {
        let id = syncMetadataId()
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = date
            } else {
                let metadata = SQSyncMetadataEntity(id: id)
                metadata.lastSyncDate = date
                context.insert(metadata)
            }
            try context.save()
        } catch {
            SQLogger.shared.log(
                "[Sync - Workout] Failed to update sync metadata: \(error)",
                .error,
                context: .workoutManager
            )
        }
    }
}
