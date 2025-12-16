//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

/// These are the manual entry fields that can be added on top of any workout (HK, strava, manual, etc...)
protocol SQWorkoutSessionOverridableData {
    var title: String? { get }
    var details: SQWorkoutActivityDetails? { get }
}

struct SQConcreteWorkoutSessionOverridableData: SQWorkoutSessionOverridableData {
    let title: String?
    let details: SQWorkoutActivityDetails?
}

protocol SQWorkoutSessionable: SQWorkoutSessionOverridableData {
    var id: String { get }
    
    /// Identifying / display
    var visibleTitle: String { get }
    var workoutSource: SQWorkoutSource { get }
    var activityType: HKWorkoutActivityType { get }
    var coreMetric: SQWorkoutMetric? { get }
    var device: SQWorkoutDevice? { get }
    
    /// Time
    var activeDuration: Double? { get }
    var startDate: Date? { get }
    var endDate: Date? { get }
    
    /// Summary
    var totalCalories: Double? { get }
    var averageHeartRate: Double? { get }
    
    /// Details
    func getMetric(for quantityType: SQQuantityType) -> SQWorkoutMetric?
    
    var updateMetadata: SQWorkoutUpdateMetadata? { get }
}

struct SQWorkoutUpdateMetadata: Codable {
    /// 🔥 Firestore sync fields
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var syncStatus: SQSyncStatus?
    var remoteId: String?
}

struct SQWorkoutSession: SQWorkoutSessionable {
    let id: String
    let title: String?
    let coreMetric: SQWorkoutMetric?
    let workoutSource: SQWorkoutSource
    let device: SQWorkoutDevice?
    
    let activityType: HKWorkoutActivityType
    
    let activeDuration: Double?
    let startDate: Date?
    let endDate: Date?
    let totalCalories: Double?
    let averageHeartRate: Double?
    var details: SQWorkoutActivityDetails?
    
    let updateMetadata: SQWorkoutUpdateMetadata?
    
    init(
        title: String?,
        workoutSource: SQWorkoutSource,
        device: SQWorkoutDevice?,
        activityType: HKWorkoutActivityType,
        activeDuration: Double?,
        startDate: Date?,
        endDate: Date?,
        totalCalories: Double?,
        averageHeartRate: Double?,
        details: SQWorkoutActivityDetails?,
        updateMetadata: SQWorkoutUpdateMetadata?
    ) {
        self.id = workoutSource.sourcableData.sourceId
        self.title = title
        self.workoutSource = workoutSource
        self.device = device
        self.activityType = activityType
        self.activeDuration = activeDuration
        self.startDate = startDate
        self.endDate = endDate
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.details = details ?? workoutSource.sourcableData.details
        self.updateMetadata = updateMetadata
        
        if let coreOutputQuantityTypeId = activityType.coreOutputQuantityTypeId {
            self.coreMetric = Self.getMetric(for: coreOutputQuantityTypeId, workoutSource: workoutSource)
        } else {
            self.coreMetric = nil
        }
    }
    
    init(workoutSource: SQWorkoutSource, overrideData: SQWorkoutSessionOverridableData?, updateMetadata: SQWorkoutUpdateMetadata? = nil) {
        let data = workoutSource.sourcableData
        self.init(
            title: overrideData?.title,
            workoutSource: workoutSource,
            device: data.device,
            activityType: data.activityType,
            activeDuration: data.activeDuration,
            startDate: data.startDate,
            endDate: data.endDate,
            totalCalories: data.sumOutputFor(.activeKilocaloriesBurned),
            averageHeartRate: data.avgOutputFor(.heartRate),
            details: overrideData?.details ?? data.details,
            updateMetadata: updateMetadata
        )
    }
    
    var visibleTitle: String { title ?? activityType.name }
    
    func getMetric(for quantityType: SQQuantityType) -> SQWorkoutMetric? {
        Self.getMetric(for: quantityType, workoutSource: workoutSource)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SQWorkoutSession, rhs: SQWorkoutSession) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Workout Session Limits

extension SQWorkoutSession {
    /// Limits
    static let titleMaxChars: Int = 500
}
