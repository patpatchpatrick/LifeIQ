//
//  HKWorkout+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import HealthKit

extension [SQWorkoutSession] {
    
    var workoutsByActivityType: [HKWorkoutActivityType : [SQWorkoutSession]] {
        var workoutsByActivityType = [HKWorkoutActivityType : [SQWorkoutSession]]()
        for workout in self {
            workoutsByActivityType[workout.activityType, default: []].append(workout)
        }
        return workoutsByActivityType
    }
}

extension [SQWorkoutSessionable] {
    
    var workoutsByActivityType: [HKWorkoutActivityType : [SQWorkoutSessionable]] {
        var workoutsByActivityType = [HKWorkoutActivityType : [SQWorkoutSessionable]]()
        for workout in self {
            workoutsByActivityType[workout.activityType, default: []].append(workout)
        }
        return workoutsByActivityType
    }
}
