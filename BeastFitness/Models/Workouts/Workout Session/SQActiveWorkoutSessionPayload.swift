//
//  SQActiveWorkoutSessionPayload.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/30/25.
//

/// Used as a payload to pass data whenever a workout's active data is changed. When changed, it will be synced across the iOS and Watch app
struct SQActiveWorkoutSessionPayload {
    let activeExercise: SQWorkoutSessionExerciseViewModel?
    let activeSetIndex: Int?
}
