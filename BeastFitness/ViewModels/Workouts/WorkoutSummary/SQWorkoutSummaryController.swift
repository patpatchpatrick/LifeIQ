//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

@MainActor
protocol SQWorkoutSummaryInterface {
    func load(workout: SQWorkoutSessionable)
}

@Observable @MainActor
final class SQWorkoutSummaryController: SQWorkoutSummaryInterface {
    let state: WorkoutSummaryStating
    
    @MainActor
    static var `default` = SQWorkoutSummaryController(state: AppState.shared.workoutSummaryState)

    init(state: WorkoutSummaryStating) {
        self.state = state
    }
    
    func load(workout: any SQWorkoutSessionable) {
        state.load(workout: workout)
    }
}
