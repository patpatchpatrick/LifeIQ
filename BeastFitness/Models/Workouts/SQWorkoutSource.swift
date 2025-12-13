//
//  SQWorkoutSource.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import Foundation
import HealthKit

protocol SQWorkoutSourcable {
    var activityType: HKWorkoutActivityType { get }
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    var activeDuration: Double? { get } /// Seconds
    var totalCalories: Double? { get }
    var startDate: Date? { get }
    var endDate: Date? { get }
    var device: SQWorkoutDevice? { get }
    var details: SQWorkoutDetails? { get }
}

extension SQWorkoutSourcable {
    
    var totalCalories: Double? {
        sumOutputFor(.activeKilocaloriesBurned)
    }
    
    // Default mapper: sourcable → session (source-agnostic)
    func buildWorkout(id: UUID = UUID(), source: SQWorkoutSource) -> SQWorkoutSessionable {
        SQWorkoutSession(
            id: id,
            title: nil,
            workoutSource: source,
            device: device,
            activityType: activityType,
            activeDuration: activeDuration,
            startDate: startDate,
            endDate: endDate,
            totalCalories: sumOutputFor(.activeKilocaloriesBurned),
            averageHeartRate: avgOutputFor(.heartRate)
        )
    }
}

enum SQWorkoutSource {
    case hkWorkout(SQHKWorkout)
    case stravaWorkout(SQStravaWorkout)
    case manual(SQManualWorkout)
    
    var sourcableData: SQWorkoutSourcable {
        switch self {
        case .hkWorkout(let workout):
            return workout
        case .stravaWorkout(let workout):
            return workout
        case .manual(let workout):
            return workout
        }
    }
    
    func buildWorkout(id: UUID = UUID()) -> SQWorkoutSessionable {
        sourcableData.buildWorkout(id: id, source: self)
    }
}

