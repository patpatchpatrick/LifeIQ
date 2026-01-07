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

@Model
final class SQWorkoutSessionEntity {
    #Index<SQWorkoutSessionEntity>([\.hkWorkoutId])
    
    @Attribute(.unique) var workoutId: String     // UUID string
    var hkWorkoutId: String?

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
    
    init(from session: SQWorkoutSessionable) {
        self.workoutId = session.id
        self.title = session.title
        self.hkWorkoutId = session.hkWorkoutId
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
    }
    
    func update(from session: SQWorkoutSessionable) {
        hkWorkoutId = session.hkWorkoutId
        
        title = session.visibleTitle
        activityTypeRaw = Int(session.activityType.rawValue)
        
        deviceRaw = session.device?.name
        
        activeDuration = session.activeDuration
        startDate = session.startDate
        endDate = session.endDate
        totalCalories = session.totalCalories
        averageHeartRate = session.averageHeartRate
        
        detailsData = Self.encodeDetails(session.details)
        
        createdAt = session.updateMetadata?.createdAt
        updatedAt = session.updateMetadata?.updatedAt
        deletedAt = session.updateMetadata?.deletedAt
        syncStatusRaw = session.updateMetadata?.syncStatus?.rawValue
        remoteId = session.updateMetadata?.remoteId
    }
    
    func toSession(workoutSource: SQWorkoutSource?) throws -> SQWorkoutSession {
        let activityType = HKWorkoutActivityType(rawValue: UInt(activityTypeRaw)) ?? .other
        
        let device = SQWorkoutDevice(name: deviceRaw ?? "")
        let details = Self.decodeDetails(detailsData)
        
        var workoutSource = workoutSource
        
        if workoutSource == nil {
            guard let details else {
                /// If we aren't given the 3rd party workout source data, then we expect the workout to have manual details saved. If both are missing, then something went wrong.
                SQLogger.shared.log("Missing both workout source and details when attempting to decode workout.", .error, context: .workoutSession)
                throw SQError.standard
            }
            
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
        
        return SQWorkoutSession(
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
    }
}

extension SQWorkoutSessionEntity {
    
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
    
    static func get(id: String, context: ModelContext, workoutSource: SQWorkoutSource) throws -> SQWorkoutSessionable? {
        let key = id
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.workoutId == key && $0.deletedAt == nil }
        )
        
        let firstItem = try context.fetch(descriptor).first
        
        let workoutSession = try firstItem?.toSession(workoutSource: workoutSource)
        
        return workoutSession
    }
    
    /// Fetch the workout using the HealthKit workout
    static func getFromHkWorkout(
        source: SQWorkoutSource,
        hkWorkoutId: String?,
        context: ModelContext
    ) throws -> SQWorkoutSessionable? {
        
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
                predicate: #Predicate<SQWorkoutSessionEntity> {
                    $0.hkWorkoutId == hkWorkoutId
                    && $0.deletedAt == nil
                }
            )
        
        let firstItem = try context.fetch(descriptor).first
        
        let workoutSession = try firstItem?.toSession(workoutSource: source)
        
        return workoutSession
    }
    
    static func upsert(session: SQWorkoutSessionable, in context: ModelContext) throws {
        let key = session.id
        
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.workoutId == key }
        )
        
        if let existing = try context.fetch(descriptor).first {
            SQLogger.shared.log("Updating Existing Workout with session: \(session.prettyDescription)", .debug, context: .workoutSession)
            existing.update(from: session)
        } else {
            context.insert(SQWorkoutSessionEntity(from: session))
        }
        
        try context.save()
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
        in context: ModelContext,
        mode: DeleteMode = .soft
    ) throws {
        try delete(workoutId: workoutSession.id, in: context, mode: mode)
    }

    /// Deletes (soft or hard) by workoutId.
    static func delete(
        workoutId: String,
        in context: ModelContext,
        mode: DeleteMode = .soft
    ) throws {
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.workoutId == workoutId }
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
        in context: ModelContext,
        mode: DeleteMode = .soft
    ) throws {
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate<SQWorkoutSessionEntity> { $0.hkWorkoutId == hkWorkoutId }
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

