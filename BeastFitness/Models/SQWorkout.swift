//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

protocol SQWorkoutable {
    var activityType: HKWorkoutActivityType? { get }
    var coreOutputQuantityTypeId: SQQuantityType? { get }
    var coreOutputUnit: SQUnit? { get }
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    func unitFor(_ quantityTypeIdentifier: SQQuantityType) -> SQUnit?
    var activeDuration: Double? { get } /// Seconds
}

enum SQWorkoutType {
    case hkWorkout(HKWorkout)
    case stravaWorkout(SQStravaWorkout)
    
    var activityType: HKWorkoutActivityType {
        switch self {
        case .hkWorkout(let workout):
            workout.workoutActivityType
        case .stravaWorkout(let workout):
            workout.sport_type.activityType
        }
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        switch self {
        case .hkWorkout(let workout):
            workout.sumOutputFor(quantityTypeIdentifier)
        case .stravaWorkout(let workout):
            workout.sumOutputFor(quantityTypeIdentifier)
        }
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        switch self {
        case .hkWorkout(let workout):
            workout.avgOutputFor(quantityTypeIdentifier)
        case .stravaWorkout(let workout):
            workout.avgOutputFor(quantityTypeIdentifier)
        }
    }
    
    // TODO: - PTD, should this be active or total duration?
    var activeDuration: Double? {
        switch self {
        case .hkWorkout(let workout):
            workout.duration
        case .stravaWorkout(let workout):
            workout.activeDuration
        }
    }
}

final class SQWorkout: SQWorkoutable {
    let workoutType: SQWorkoutType
    
    // MARK: - Init
    
    init(_ workoutType: SQWorkoutType) {
        self.workoutType = workoutType
    }
    
    var activityType: HKWorkoutActivityType? {
        workoutType.activityType
    }
    
    var coreOutputQuantityTypeId: SQQuantityType? {
        workoutType.activityType.coreOutputQuantityTypeId
    }
    
    var coreOutputUnit: SQUnit? {
        workoutType.activityType.coreOutputUnit
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        workoutType.sumOutputFor(quantityTypeIdentifier)
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        workoutType.avgOutputFor(quantityTypeIdentifier)
    }
    
    var activeDuration: Double? {
        workoutType.activeDuration
    }
    
    func unitFor(_ quantityTypeIdentifier: SQQuantityType) -> SQUnit? {
        switch quantityTypeIdentifier {
        case .distanceWalkingRunning, .distanceCycling:
            return .mile
        case .activeEnergyBurned:
            return .kilocalorie
        case .heartRate:
            return .countPerMinute
        }
    }
}

// MARK: - SQWorkouts
// Used to group workouts of the SAME type
final class SQWorkouts {
    let workouts: [SQWorkoutable]
    var activityType: HKWorkoutActivityType? {
        workouts.first?.activityType
    }
    
    let sumOutputString: String?
    let timeString: String?
    let caloriesString: String?
    let heartRateString: String?
    
    init(workouts: [SQWorkoutable]) {
        self.workouts = workouts
        
        var totalOutput = 0.0
        var totalTime: TimeInterval = 0.0
        var totalCalories = 0.0
        var totalAvgHeartRateTimesSeconds = 0.0
        var averageHeartRate = 0.0
        
        let firstWorkout = workouts.first
        
        workouts.forEach {
            if let coreOutputQuantityTypeId = $0.coreOutputQuantityTypeId {
                totalOutput += $0.sumOutputFor(coreOutputQuantityTypeId) ?? 0
            }
            let workoutDuration = $0.activeDuration ?? 0
            totalTime += workoutDuration
            totalCalories += $0.sumOutputFor(.activeEnergyBurned) ?? 0
            totalAvgHeartRateTimesSeconds += ($0.avgOutputFor(.heartRate) ?? 0) * workoutDuration
        }
        averageHeartRate = totalAvgHeartRateTimesSeconds / totalTime
        
        sumOutputString = "\(totalOutput.sqShortString) \(firstWorkout?.coreOutputUnit?.unitString ?? "")"
        timeString = SQDateFormatters.shared.durationFormatter.string(from: totalTime)
        caloriesString = "\(totalCalories.sqShortString) \(firstWorkout?.unitFor(.activeEnergyBurned)?.unitString ?? "")"
        heartRateString = "\(averageHeartRate.sqShortString) \(firstWorkout?.unitFor(.heartRate)?.unitString ?? "")"
    }
}
