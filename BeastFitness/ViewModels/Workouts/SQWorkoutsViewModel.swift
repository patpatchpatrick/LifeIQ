//
//  SQWorkoutsViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI

@MainActor
protocol SQWorkoutsScreenInterface {
    func displayWorkoutSessionSheet() async
}

@Observable @MainActor
final class SQWorkoutsScreenController: SQWorkoutsScreenInterface {
    
    @MainActor
    static var `default` = SQWorkoutsScreenController(state: AppState.shared.workoutScreenState)
    let state: WorkoutsScreenStating
    
    init(state: WorkoutsScreenStating) {
        self.state = state
    }
    
    func displayWorkoutSessionSheet() async {
        state.displayWorkoutSessionSheet()
    }
}
