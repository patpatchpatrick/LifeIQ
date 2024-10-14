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
            workoutsByActivityType[workout.activityType ?? .other, default: []].append(workout)
        }
        return workoutsByActivityType
    }
    
    func filterDuplicates() -> [SQWorkout] {
        // TODO: - PTD filter workouts whose start date and end date are very similar
        return self
    }
}
