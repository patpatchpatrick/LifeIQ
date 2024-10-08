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
    
    init(workouts: [SQWorkout]) {
        self.workouts = workouts
        
        var totalOutput = 0.0
        var totalTime: TimeInterval = 0.0
        
        workouts.forEach {
            totalOutput += $0.workout.output ?? 0
            totalTime += $0.workout.duration ?? 0
        }
        
        sumOutputString = "\(totalOutput.sqShortString) \(workouts.first?.workout.unit?.unitString ?? "")"
        timeString = SQDateFormatters.shared.durationFormatter.string(from: totalTime)
    }
}

extension HKWorkout {
    
    // TODO: - PTD finish with all activities
    var output: Double? {
        switch self.workoutActivityType {
        case .running:
            guard let quantityType: HKQuantityType = .quantityType(forIdentifier: .distanceWalkingRunning), let unit else {
                return nil
            }
            return self.allStatistics[quantityType]?.sumQuantity()?.doubleValue(for: unit)
        default:
            return nil
        }
    }
    
    var duration: TimeInterval? {
        switch self.workoutActivityType {
        case .running:
            guard let quantityType: HKQuantityType = .quantityType(forIdentifier: .activeEnergyBurned) else {
                return nil
            }
            
            guard let startDate = self.allStatistics[quantityType]?.startDate, let endDate = self.allStatistics[quantityType]?.endDate else {
                return nil
            }
            
            return abs(endDate.distance(to: startDate))
        default:
            return nil
        }
    }
    
    var unit: HKUnit? {
        switch self.workoutActivityType {
        case .running:
            return .mile()
        default:
            return nil
        }
    }
    
    var outputString: String? {
        switch self.workoutActivityType {
        case .running:
            return "\(output.sqShortString) \(unit?.unitString ?? "")"
        default:
            return nil
        }
    }
}
