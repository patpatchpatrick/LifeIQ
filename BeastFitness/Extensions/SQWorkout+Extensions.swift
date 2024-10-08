//
//  HKWorkout+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import HealthKit

extension [SQWorkout] {
    
    var workoutsByActivityType: [HKWorkoutActivityType : [SQWorkout]] {
        var workoutsByActivityType = [HKWorkoutActivityType : [SQWorkout]]()
        for workout in self {
            workoutsByActivityType[workout.workout.workoutActivityType, default: []].append(workout)
        }
        return workoutsByActivityType
    }
}
