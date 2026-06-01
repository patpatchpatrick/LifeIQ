//
//  SQWorkoutSessionEntity.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

import SwiftData
import Foundation
import HealthKit
import SwiftUI
import BeastFitnessCore

extension SQLocalPersistenceSchemaV1 {
    @Model
    final class SQWorkoutSessionEntity {
    #Index<SQWorkoutSessionEntity>([\.hkWorkoutId])
    
    @Attribute(.unique) var storageId: String
    var userId: String
    var workoutId: String     // UUID string
    var hkWorkoutId: String?
    var sourceRaw: String?

    var title: String?
    
    /// Store rawValue for HKWorkoutActivityType since HKWorkoutActivityType isn't Codable.
    var activityTypeRaw: Int
    
    // Device
    var deviceRaw: String?   // adjust based on how SQWorkoutDevice is defined
    
    // Time
    var activeDuration: Double?
    var startDate: Date?
    var endDate: Date?
    
    // Summary
    var totalCalories: Double?
    var averageHeartRate: Double?
    
    // Details (v1: blob)
    var detailsData: Data?
    
    // Sync fields
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var syncStatusRaw: String?
    var remoteId: String?

    var reviewNotes: String?
    var ratingUserPerformance: Float?
    var ratingDifficulty: Float?
    var temperatureCelsius: Double?

    init(from session: SQWorkoutSessionable, userId: String) {
        self.storageId = Self.makeStorageId(userId: userId, workoutId: session.id)
        self.userId = userId
        self.workoutId = session.id
        self.title = session.title
        self.hkWorkoutId = session.hkWorkoutId
        self.sourceRaw = session.workoutSource.rawSource.rawValue
        self.activityTypeRaw = Int(session.activityType.rawValue)
        
        self.deviceRaw = session.device?.name
        
        self.activeDuration = session.activeDuration
        self.startDate = session.startDate
        self.endDate = session.endDate
        self.totalCalories = session.totalCalories
        self.averageHeartRate = session.averageHeartRate
        
        self.detailsData = Self.encodeDetails(session.details)
        
        self.createdAt = session.updateMetadata?.createdAt
        self.updatedAt = session.updateMetadata?.updatedAt
        self.deletedAt = session.updateMetadata?.deletedAt
        self.syncStatusRaw = session.updateMetadata?.syncStatus?.rawValue
        self.remoteId = session.updateMetadata?.remoteId

        self.reviewNotes = session.reviewNotes
        self.ratingUserPerformance = session.ratingUserPerformance
        self.ratingDifficulty = session.ratingDifficulty
        self.temperatureCelsius = session.temperatureCelsius
    }

    init(from document: SQWorkoutSyncDocument, userId: String) {
        self.storageId = Self.makeStorageId(userId: userId, workoutId: document.workoutId)
        self.userId = userId
        self.workoutId = document.workoutId
        self.hkWorkoutId = document.hkWorkoutId
        self.sourceRaw = document.sourceRaw
        self.title = document.title
        self.activityTypeRaw = document.activityTypeRaw
        self.deviceRaw = document.deviceRaw
        self.activeDuration = document.activeDuration
        self.startDate = document.startDate
        self.endDate = document.endDate
        self.totalCalories = document.totalCalories
        self.averageHeartRate = document.averageHeartRate
        self.detailsData = document.detailsData
        self.createdAt = document.createdAt
        self.updatedAt = document.updatedAt
        self.deletedAt = document.deletedAt
        self.syncStatusRaw = SQSyncStatus.synced.rawValue
        self.remoteId = document.remoteId
        self.reviewNotes = document.reviewNotes
        self.ratingUserPerformance = document.ratingUserPerformance
        self.ratingDifficulty = document.ratingDifficulty
        self.temperatureCelsius = document.temperatureCelsius
    }
    
    func update(from session: SQWorkoutSessionable) {
        hkWorkoutId = session.hkWorkoutId
        sourceRaw = session.workoutSource.rawSource.rawValue
        
        title = session.title
        activityTypeRaw = Int(session.activityType.rawValue)
        
        deviceRaw = session.device?.name
        
        activeDuration = session.activeDuration
        startDate = session.startDate
        endDate = session.endDate
        totalCalories = session.totalCalories
        averageHeartRate = session.averageHeartRate
        
        detailsData = Self.encodeDetails(session.details)
        
        if let metadata = session.updateMetadata {
            createdAt = metadata.createdAt
            updatedAt = metadata.updatedAt
            deletedAt = metadata.deletedAt
            syncStatusRaw = metadata.syncStatus?.rawValue
            remoteId = metadata.remoteId
        }

        reviewNotes = session.reviewNotes
        ratingUserPerformance = session.ratingUserPerformance
        ratingDifficulty = session.ratingDifficulty
        temperatureCelsius = session.temperatureCelsius
    }

    func update(from document: SQWorkoutSyncDocument) {
        hkWorkoutId = document.hkWorkoutId
        sourceRaw = document.sourceRaw
        title = document.title
        activityTypeRaw = document.activityTypeRaw
        deviceRaw = document.deviceRaw
        activeDuration = document.activeDuration
        startDate = document.startDate
        endDate = document.endDate
        totalCalories = document.totalCalories
        averageHeartRate = document.averageHeartRate
        detailsData = document.detailsData
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        deletedAt = document.deletedAt
        syncStatusRaw = SQSyncStatus.synced.rawValue
        remoteId = document.remoteId
        reviewNotes = document.reviewNotes
        ratingUserPerformance = document.ratingUserPerformance
        ratingDifficulty = document.ratingDifficulty
        temperatureCelsius = document.temperatureCelsius
    }

    func toSession(workoutSource: SQWorkoutSource?) throws -> SQWorkoutSession {
        let activityType = HKWorkoutActivityType(rawValue: UInt(activityTypeRaw)) ?? .other
        
        let device = SQWorkoutDevice(name: deviceRaw ?? "")
        let details = Self.decodeDetails(detailsData)
        
        var workoutSource = workoutSource
        
        if workoutSource == nil {
            if inferredSourceRaw == .manual {
                workoutSource = .manual(.init(
                    sourceId: workoutId,
                    activityType: activityType,
                    device: device,
                    startDate: startDate,
                    endDate: endDate,
                    activeDuration: activeDuration,
                    averageHeartRate: averageHeartRate,
                    totalCalories: totalCalories,
                    details: details))
            } else {
                SQLogger.shared.log(
                    "Missing source workout when attempting to decode non-manual workout \(workoutId)",
                    .error,
                    context: .workoutSession
                )
                throw SQError.standard
            }
        }
        
        guard let workoutSource else {
            assertionFailure("We always expect a workout source here. Something went wrong.")
            SQLogger.shared.log("Workout source required to get workout", .error, context: .workoutSession)
            throw SQError.standard
        }
        
        var syncStatus: SQSyncStatus?
        if let rawSyncData = self.syncStatusRaw {
            syncStatus = .init(rawValue: rawSyncData)
        }
        
        let session = SQWorkoutSession(
            id: workoutId,
            workoutSource: workoutSource,
            overrideData: SQConcreteWorkoutSessionOverridableData(
                title: title,
                details: details),
            hkWorkoutId: hkWorkoutId,
            updateMetadata: .init(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                remoteId: remoteId)
        )

        session.setReviewData(
            notes: reviewNotes,
            ratingUserPerformance: ratingUserPerformance,
            ratingDifficulty: ratingDifficulty,
            temperature: temperatureCelsius
        )

        return session
    }

    var inferredSourceRaw: SQWorkoutSourceRaw {
        if let sourceRaw, let raw = SQWorkoutSourceRaw(rawValue: sourceRaw) {
            return raw
        }
        if hkWorkoutId != nil {
            return .hkWorkout
        }
        return .manual
    }

    var syncStatus: SQSyncStatus? {
        guard let syncStatusRaw else { return nil }
        return SQSyncStatus(rawValue: syncStatusRaw)
    }

    func markPendingUpload(now: Date = .now) {
        if createdAt == nil {
            createdAt = now
        }
        updatedAt = now
        deletedAt = nil
        syncStatusRaw = SQSyncStatus.pendingUpload.rawValue
        remoteId = remoteId ?? workoutId
    }

    func markPendingDelete(now: Date = .now) {
        if createdAt == nil {
            createdAt = now
        }
        updatedAt = now
        deletedAt = now
        syncStatusRaw = SQSyncStatus.pendingDelete.rawValue
        remoteId = remoteId ?? workoutId
    }

    func markSynced(remoteId: String? = nil, updatedAt: Date? = nil) {
        syncStatusRaw = SQSyncStatus.synced.rawValue
        self.remoteId = remoteId ?? self.remoteId ?? workoutId
        if let updatedAt {
            self.updatedAt = updatedAt
        }
        if createdAt == nil {
            createdAt = self.updatedAt ?? .now
        }
    }

    func shouldMergeRemoteDocument(_ document: SQWorkoutSyncDocument) -> Bool {
        switch syncStatus {
        case .pendingUpload, .pendingDelete, .failed:
            return false
        case .synced, .unknown, .none:
            guard let localUpdatedAt = updatedAt else { return true }
            return document.updatedAt >= localUpdatedAt
        }
    }

    func toSyncDocument() -> SQWorkoutSyncDocument? {
        guard let createdAt, let updatedAt else { return nil }

        return SQWorkoutSyncDocument(
            workoutId: workoutId,
            remoteId: remoteId ?? workoutId,
            hkWorkoutId: hkWorkoutId,
            sourceRaw: inferredSourceRaw.rawValue,
            title: title,
            activityTypeRaw: activityTypeRaw,
            deviceRaw: deviceRaw,
            activeDuration: activeDuration,
            startDate: startDate,
            endDate: endDate,
            totalCalories: totalCalories,
            averageHeartRate: averageHeartRate,
            detailsData: detailsData,
            reviewNotes: reviewNotes,
            ratingUserPerformance: ratingUserPerformance,
            ratingDifficulty: ratingDifficulty,
            temperatureCelsius: temperatureCelsius,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
    }
}

typealias SQWorkoutSessionEntity = SQCurrentLocalSchema.SQWorkoutSessionEntity

extension SQWorkoutSessionEntity {
    static func makeStorageId(userId: String, workoutId: String) -> String {
        "\(userId)/\(workoutId)"
    }
    
    private static func encodeDetails(_ details: SQWorkoutActivityDetails?) -> Data? {
        guard let details else { return nil }
        do { return try JSONEncoder().encode(details) }
        catch { return nil }
    }

    
    private static func decodeDetails(_ data: Data?) -> SQWorkoutActivityDetails? {
        guard let data else { return nil }
        do { return try JSONDecoder().decode(SQWorkoutActivityDetails.self, from: data) }
        catch { return nil }
    }
}

extension SQWorkoutSessionEntity {
    
    static func get(id: String, userId: String, context: ModelContext, workoutSource: SQWorkoutSource) throws -> SQWorkoutSessionable? {
        let key = id
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.workoutId == key && $0.deletedAt == nil }
        )
        
        let firstItem = try context.fetch(descriptor).first
        
        let workoutSession = try firstItem?.toSession(workoutSource: workoutSource)
        
        return workoutSession
    }
    
    /// Fetch the workout using the HealthKit workout
    static func getFromHkWorkout(
        source: SQWorkoutSource,
        hkWorkoutId: String?,
        userId: String,
        context: ModelContext
    ) throws -> SQWorkoutSessionable? {
        
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
                predicate: #Predicate<SQWorkoutSessionEntity> {
                    $0.userId == userId
                    &&
                    $0.hkWorkoutId == hkWorkoutId
                    && $0.deletedAt == nil
                }
            )
        
        let firstItem = try context.fetch(descriptor).first
        
        let workoutSession = try firstItem?.toSession(workoutSource: source)
        
        return workoutSession
    }
    
    static func upsert(session: SQWorkoutSessionable, userId: String, in context: ModelContext) throws {
        let key = session.id
        
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.workoutId == key }
        )
        
        if let existing = try context.fetch(descriptor).first {
            SQLogger.shared.log("Updating Existing Workout with session: \(session.prettyDescription)", .debug, context: .workoutSession)
            existing.update(from: session)
        } else {
            context.insert(SQWorkoutSessionEntity(from: session, userId: userId))
        }
        
        try context.save()
    }

    static func upsert(remoteDocument: SQWorkoutSyncDocument, userId: String, in context: ModelContext) throws {
        let key = remoteDocument.workoutId
        let workoutIdDescriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.workoutId == key }
        )
        let existingByWorkoutId = try context.fetch(workoutIdDescriptor).first

        let existing: SQWorkoutSessionEntity?
        if let existingByWorkoutId {
            existing = existingByWorkoutId
        } else if let hkWorkoutId = remoteDocument.hkWorkoutId {
            let hkDescriptor = FetchDescriptor<SQWorkoutSessionEntity>(
                predicate: #Predicate { $0.userId == userId && $0.hkWorkoutId == hkWorkoutId }
            )
            existing = try context.fetch(hkDescriptor).first
        } else {
            existing = nil
        }

        if let existing {
            guard existing.shouldMergeRemoteDocument(remoteDocument) else {
                return
            }
            if existing.workoutId != remoteDocument.workoutId {
                existing.workoutId = remoteDocument.workoutId
                existing.storageId = makeStorageId(userId: userId, workoutId: remoteDocument.workoutId)
            }
            existing.update(from: remoteDocument)
        } else {
            context.insert(SQWorkoutSessionEntity(from: remoteDocument, userId: userId))
        }

        try context.save()
    }

    static func getEntity(workoutId: String, userId: String, context: ModelContext) throws -> SQWorkoutSessionEntity? {
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.workoutId == workoutId }
        )
        return try context.fetch(descriptor).first
    }

    static func getEntity(hkWorkoutId: String, userId: String, context: ModelContext) throws -> SQWorkoutSessionEntity? {
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.hkWorkoutId == hkWorkoutId }
        )
        return try context.fetch(descriptor).first
    }

    static func getDeletedHealthKitEntity(
        hkWorkoutId: String?,
        workoutId: String,
        userId: String,
        context: ModelContext
    ) throws -> SQWorkoutSessionEntity? {
        let workoutDescriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.workoutId == workoutId &&
                $0.deletedAt != nil
            }
        )

        if let entity = try context.fetch(workoutDescriptor).first {
            return entity
        }

        guard let hkWorkoutId else { return nil }

        let healthKitDescriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.hkWorkoutId == hkWorkoutId &&
                $0.deletedAt != nil
            }
        )

        return try context.fetch(healthKitDescriptor).first
    }

    static func getPendingSyncEntities(userId: String, context: ModelContext) throws -> [SQWorkoutSessionEntity] {
        let pendingUpload = SQSyncStatus.pendingUpload.rawValue
        let pendingDelete = SQSyncStatus.pendingDelete.rawValue
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate {
                $0.userId == userId &&
                ($0.syncStatusRaw == pendingUpload || $0.syncStatusRaw == pendingDelete)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    static func getManualWorkouts(
        for timeRange: SQTimeRange,
        userId: String,
        context: ModelContext
    ) throws -> [SQWorkoutSessionEntity] {
        let manual = SQWorkoutSourceRaw.manual.rawValue
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.deletedAt == nil
                    && $0.sourceRaw == manual
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try context.fetch(descriptor).filter { entity in
            guard let startDate = entity.startDate else { return false }
            return startDate >= timeRange.startDate && startDate <= timeRange.endDate
        }
    }
}

// MARK: - Deletion

extension SQWorkoutSessionEntity {

    enum DeleteMode {
        /// Keeps the entity for syncing; marks deletedAt + syncStatus = deleted
        case soft
        /// Removes the row from SwiftData immediately
        case hard
    }

    /// Deletes (soft or hard) by domain model.
    static func delete(
        workoutSession: SQWorkoutSessionable,
        userId: String,
        in context: ModelContext,
        mode: DeleteMode = .soft
    ) throws {
        if try getEntity(workoutId: workoutSession.id, userId: userId, context: context) != nil {
            try delete(workoutId: workoutSession.id, userId: userId, in: context, mode: mode)
            return
        }

        if let hkWorkoutId = workoutSession.hkWorkoutId,
           let existing = try getEntity(hkWorkoutId: hkWorkoutId, userId: userId, context: context) {
            try delete(workoutId: existing.workoutId, userId: userId, in: context, mode: mode)
            return
        }

        guard mode == .soft else { return }

        let now = Date()
        let tombstone = SQWorkoutSessionEntity(from: workoutSession, userId: userId)
        tombstone.createdAt = tombstone.createdAt ?? now
        tombstone.updatedAt = now
        tombstone.deletedAt = now
        tombstone.syncStatusRaw = SQSyncStatus.pendingDelete.rawValue
        tombstone.remoteId = tombstone.remoteId ?? workoutSession.id

        context.insert(tombstone)
        try context.save()
    }

    /// Deletes (soft or hard) by workoutId.
    static func delete(
        workoutId: String,
        userId: String,
        in context: ModelContext,
        mode: DeleteMode = .soft
    ) throws {
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.workoutId == workoutId }
        )

        guard let existing = try context.fetch(descriptor).first else {
            return // nothing to delete
        }

        switch mode {
        case .soft:
            let now = Date()
            existing.deletedAt = now
            existing.updatedAt = now

            // Mark as deleted for your sync pipeline.
            // If SQSyncStatus is optional, write its raw value as a String.
            existing.syncStatusRaw = SQSyncStatus.pendingDelete.rawValue

        case .hard:
            context.delete(existing)
        }

        try context.save()
    }

    /// Convenience: delete by hkWorkoutId (useful when you delete from HealthKit first)
    static func deleteFromHkWorkoutId(
        _ hkWorkoutId: String,
        userId: String,
        in context: ModelContext,
        mode: DeleteMode = .soft
    ) throws {
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate<SQWorkoutSessionEntity> { $0.userId == userId && $0.hkWorkoutId == hkWorkoutId }
        )

        guard let existing = try context.fetch(descriptor).first else {
            return
        }

        switch mode {
        case .soft:
            let now = Date()
            existing.deletedAt = now
            existing.updatedAt = now
            existing.syncStatusRaw = SQSyncStatus.pendingDelete.rawValue
        case .hard:
            context.delete(existing)
        }

        try context.save()
    }
}
