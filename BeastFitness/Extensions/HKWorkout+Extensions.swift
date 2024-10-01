//
//  HKWorkout+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import HealthKit

extension [HKWorkout] {
    
    var workoutsByActivityType: [HKWorkoutActivityType : [HKWorkout]] {
        var workoutsByActivityType = [HKWorkoutActivityType : [HKWorkout]]()
        for workout in self {
            workoutsByActivityType[workout.workoutActivityType, default: []].append(workout)
        }
        return workoutsByActivityType
    }
}
