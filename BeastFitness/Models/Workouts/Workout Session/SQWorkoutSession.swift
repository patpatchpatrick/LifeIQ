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
    /// The app's internal stable identifier for this workout session.
    ///
    /// For **HealthKit workouts**: defaults to `workoutSource.sourcableData.sourceId`
    /// (the HK UUID), so `id == sourceId` for all HK workouts whether or not they've
    /// been saved to SwiftData. The SwiftData entity stores this as its primary key.
    ///
    /// For **manual workouts**: a UUID generated at creation time. Also equals
    /// `sourceId` since the convenience init defaults `id` to `sourceId`.
    var id: String { get }

    /// The HealthKit `HKWorkout.uuid.uuidString` for this workout.
    ///
    /// - For workouts **fetched from HealthKit**: equals `id` and `sourceId` (all three
    ///   are the same HK UUID).
    /// - For **manual workouts saved to HealthKit**: differs from `id`/`sourceId`
    ///   (which are the app's internal UUID). `hkWorkoutId` is assigned by HealthKit
    ///   after the workout is saved and may be nil until then.
    var hkWorkoutId: String? { get }
    func updateHkWorkoutId(_ hkWorkoutId: String?)
    
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
    func getMetric(for quantityType: SQQuantityType) async -> SQWorkoutMetric?

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

class SQWorkoutSession: SQWorkoutSessionable {
    static let metadataManager = SQWorkoutSessionMetadataManager.shared

    let id: String
    let title: String?
    var coreMetric: SQWorkoutMetric?
    private(set) var hkWorkoutId: String?
    func updateHkWorkoutId(_ hkWorkoutId: String?) {
        self.hkWorkoutId = hkWorkoutId
    }
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
        id: String,
        title: String?,
        hkWorkoutId: String?,
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
        self.id = id
        self.hkWorkoutId = hkWorkoutId
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
        
        self.coreMetric = nil
        
        // TODO: - PTD Update this 
        Task {
            if let coreOutputQuantityTypeId = activityType.coreOutputQuantityTypeId {
                self.coreMetric = await Self.getMetric(for: coreOutputQuantityTypeId, workoutSource: workoutSource)
            } else {
                self.coreMetric = nil
            }
        }
    }
    
    convenience init(id: String? = nil, workoutSource: SQWorkoutSource, overrideData: SQWorkoutSessionOverridableData?, hkWorkoutId: String?, updateMetadata: SQWorkoutUpdateMetadata? = nil) {
        let data = workoutSource.sourcableData
        self.init(
            id: id ?? workoutSource.sourcableData.sourceId,
            title: overrideData?.title,
            hkWorkoutId: hkWorkoutId ?? workoutSource.hkWorkoutId,
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
    
    var visibleTitle: String {
        var backupName = activityType.name
        if let date = startDate {
            backupName = "\(date.dayAndTimeTitle()) \(backupName)"
        }
        guard title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return backupName
        }
        
        return title ?? backupName
    }
    
    func getMetric(for quantityType: SQQuantityType) async -> SQWorkoutMetric? {
        // TODO: - PTD persist this data so we don't need to re-calculate it every time the app dies
        if let cached = Self.metadataManager.cachedMetric(for: quantityType, sourceId: id) {
            return cached
        }
        let result = await Self.getMetric(for: quantityType, workoutSource: workoutSource)
        if let result {
            Self.metadataManager.cacheMetric(result, for: quantityType, sourceId: id)
        }
        return result
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
