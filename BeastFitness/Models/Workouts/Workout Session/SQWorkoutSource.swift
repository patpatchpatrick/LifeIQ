//
//  SQWorkoutSource.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import Foundation
import HealthKit

protocol SQWorkoutSourcable {
    var sourceId: String { get }
    var activityType: HKWorkoutActivityType { get }
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    var activeDuration: Double? { get } /// Seconds
    var totalCalories: Double? { get }
    var startDate: Date? { get }
    var endDate: Date? { get }
    var device: SQWorkoutDevice? { get }
    var details: SQWorkoutActivityDetails? { get }
}

extension SQWorkoutSourcable {
    
    var totalCalories: Double? {
        sumOutputFor(.activeKilocaloriesBurned)
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
    
    func buildWorkout(withOverrideData overrideData: SQWorkoutSessionOverridableData?) -> SQWorkoutSessionable {
        SQWorkoutSession(workoutSource: self, overrideData: overrideData)
    }
}

enum SQWorkoutSourceProvider: String, UnfrozenEnum {
    case hkWorkout
    case stravaWorkout
    case manual
    case unknown
}
