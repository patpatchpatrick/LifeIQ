//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

class SQWorkout {
    let workout: HKWorkout
    
    init(_ hkWorkout: HKWorkout) {
        self.workout = hkWorkout
    }
}

// MARK: - SQWorkouts
// Used to group workouts of the SAME type
class SQWorkouts {
    let workouts: [SQWorkout]
    var activityType: HKWorkoutActivityType? {
        workouts.first?.workout.workoutActivityType
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
        
        let firstWorkout = workouts.first?.workout
        
        workouts.forEach {
            if let coreOutputQuantityTypeId = $0.workout.coreOutputQuantityTypeId {
                totalOutput += $0.workout.sumOutputFor(coreOutputQuantityTypeId) ?? 0
            }
            let workoutDuration = $0.workout.duration ?? 0
            totalTime += workoutDuration
            totalCalories += $0.workout.sumOutputFor(.activeEnergyBurned) ?? 0
            totalAvgHeartRateTimesSeconds += ($0.workout.averageOutputFor(.heartRate) ?? 0) * workoutDuration
        }
        averageHeartRate = totalAvgHeartRateTimesSeconds / totalTime
        
        sumOutputString = "\(totalOutput.sqShortString) \(firstWorkout?.coreOutputUnit?.unitString ?? "")"
        timeString = SQDateFormatters.shared.durationFormatter.string(from: totalTime)
        caloriesString = "\(totalCalories.sqShortString) \(firstWorkout?.unitFor(.activeEnergyBurned)?.unitString ?? "")"
        heartRateString = "\(averageHeartRate.sqShortString) \(firstWorkout?.unitFor(.heartRate)?.unitString ?? "")"
    }
}
