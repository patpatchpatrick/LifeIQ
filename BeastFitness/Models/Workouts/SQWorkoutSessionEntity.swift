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
        self.workoutId = session.id.uuidString
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
    
    func toSession(workoutSource: SQWorkoutSource) -> SQWorkoutSession {
        let activityType = HKWorkoutActivityType(rawValue: UInt(activityTypeRaw)) ?? .other
        
        let details = Self.decodeDetails(detailsData)
        
        return SQWorkoutSession(
            id: UUID(uuidString: workoutId) ?? UUID(),
            title: title,
            workoutSource: workoutSource,
            device: SQWorkoutDevice(name: deviceRaw ?? ""), // adjust init to your enum
            activityType: activityType,
            activeDuration: activeDuration,
            startDate: startDate,
            endDate: endDate,
            totalCalories: totalCalories,
            averageHeartRate: averageHeartRate,
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
    static func get(id: UUID, context: ModelContext, workoutSource: SQWorkoutSource) throws -> SQWorkoutSessionable? {
        let key = id.uuidString
        let descriptor = FetchDescriptor<SQWorkoutSessionEntity>(
            predicate: #Predicate { $0.workoutId == key }
        )
        return try context.fetch(descriptor).first?.toSession(workoutSource: workoutSource)
    }
    
    static func upsert(session: SQWorkoutSessionable, in context: ModelContext) throws {
        let key = session.id.uuidString
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
