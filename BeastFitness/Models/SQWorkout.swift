//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

protocol SQWorkoutable {
    var activityType: HKWorkoutActivityType { get }
    var coreOutputQuantityTypeId: SQQuantityType? { get }
    var coreOutputUnit: SQUnit? { get }
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    var activeDuration: Double? { get } /// Seconds
    var startDate: Date? { get }
    var endDate: Date? { get }
}

enum SQWorkoutType {
    case hkWorkout(SQHKWorkout)
    case stravaWorkout(SQStravaWorkout)
    
    var workoutable: SQWorkoutable {
        switch self {
        case .hkWorkout(let workout):
            return workout
        case .stravaWorkout(let workout):
            return workout
        }
    }
}

final class SQWorkout: SQWorkoutable {
    let workoutType: SQWorkoutType
    
    // MARK: - Init
    
    init(_ workoutType: SQWorkoutType) {
        self.workoutType = workoutType
    }
    
    var activityType: HKWorkoutActivityType {
        workoutType.workoutable.activityType
    }
    
    var coreOutputQuantityTypeId: SQQuantityType? {
        workoutType.workoutable.activityType.coreOutputQuantityTypeId
    }
    
    var coreOutputUnit: SQUnit? {
        workoutType.workoutable.activityType.coreOutputUnit
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        workoutType.workoutable.sumOutputFor(quantityTypeIdentifier)
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        workoutType.workoutable.avgOutputFor(quantityTypeIdentifier)
    }
    
    var activeDuration: Double? {
        workoutType.workoutable.activeDuration
    }
    
    var startDate: Date? {
        workoutType.workoutable.startDate
    }
    
    var endDate: Date? {
        workoutType.workoutable.endDate
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
    
    init(workouts: [SQWorkout]) {
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
        caloriesString = "\(totalCalories.sqShortString) \(SQWorkoutConfig.shared.unitFor(.activeEnergyBurned)?.unitString ?? "")"
        heartRateString = "\(averageHeartRate.sqShortString) \(SQWorkoutConfig.shared.unitFor(.heartRate)?.unitString ?? "")"
    }
}
