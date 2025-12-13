//
//  SQWorkoutService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

protocol SQWorkoutServicing {
    static func saveWorkout(_ session: SQWorkoutSessionable) async throws
}

final class SQWorkoutService: SQNetworkService, SQWorkoutServicing {
    static func saveWorkout(_ session: any SQWorkoutSessionable) async throws {
        print("PTD Save Workout - TODO")
    }
}
