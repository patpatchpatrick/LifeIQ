//
//  SQWorkoutSessionEntity.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

import SwiftData
import Foundation
import HealthKit

@Model
final class SQWorkoutSessionEntity {
    @Attribute(.unique) var workoutId: String     // UUID string
    var title: String
    
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
    var syncStatusRaw: String
    var remoteId: String?
    
    init(from session: SQWorkoutSessionable) {
        self.workoutId = session.id
        self.title = session.title
        self.activityTypeRaw = Int(session.activityType.rawValue)
        
        self.deviceRaw = session.device?.name
        
        self.activeDuration = session.activeDuration
        self.startDate = session.startDate
        self.endDate = session.endDate
        self.totalCalories = session.totalCalories
        self.averageHeartRate = session.averageHeartRate
        
        self.detailsData = Self.encodeDetails(session.details)
        
        self.createdAt = session.createdAt
        self.updatedAt = session.updatedAt
        self.deletedAt = session.deletedAt
        self.syncStatusRaw = session.syncStatus.rawValue
        self.remoteId = session.remoteId
    }
    
    func update(from session: SQWorkoutSessionable) {
        title = session.title
        activityTypeRaw = Int(session.activityType.rawValue)
        
        deviceRaw = session.device?.name
        
        activeDuration = session.activeDuration
        startDate = session.startDate
        endDate = session.endDate
        totalCalories = session.totalCalories
        averageHeartRate = session.averageHeartRate
        
        detailsData = Self.encodeDetails(session.details)
        
        createdAt = session.createdAt
        updatedAt = session.updatedAt
        deletedAt = session.deletedAt
        syncStatusRaw = session.syncStatus.rawValue
        remoteId = session.remoteId
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
                throw SQStandardError.standard
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
            throw SQStandardError.standard
        }
        
        return SQWorkoutSession(
            title: title,
            workoutSource: workoutSource,
            device: device,
            activityType: activityType,
            activeDuration: activeDuration,
            startDate: startDate,
            endDate: endDate,
            totalCalories: totalCalories,
            averageHeartRate: averageHeartRate,
            details: details,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            syncStatus: SQSyncStatus(rawValue: syncStatusRaw) ?? .pendingUpload,
            remoteId: remoteId
        )
    }
}

extension SQWorkoutSessionEntity {
    private static func encodeDetails(_ details: SQWorkoutDetails?) -> Data? {
        guard let details else { return nil }
        do { return try JSONEncoder().encode(details) }
        catch { return nil }
    }

    private static func decodeDetails(_ data: Data?) -> SQWorkoutDetails? {
        guard let data else { return nil }
        do { return try JSONDecoder().decode(SQWorkoutDetails.self, from: data) }
        catch { return nil }
    }
}


extension SQWorkoutSessionEntity {
    static func get(id: String, context: ModelContext, workoutSource: SQWorkoutSource) throws -> SQWorkoutSessionable? {
        let key = id
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.workoutId == key }
        )
        
        let firstItem = try context.fetch(descriptor).first
        
        let workoutSession = try firstItem?.toSession(workoutSource: workoutSource)
        
        return workoutSession
    }
    
    static func upsert(session: SQWorkoutSessionable, in context: ModelContext) throws {
        let key = session.id
        
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.workoutId == key }
        )
        
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: session)
        } else {
            context.insert(SQWorkoutSessionEntity(from: session))
        }
        
        try context.save()
    }
}
