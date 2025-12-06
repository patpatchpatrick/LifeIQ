//
//  SQWorkoutsViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI

@MainActor
protocol SQWorkoutsLandingInterface {
    func displayWorkoutSessionSheet() async
}

@Observable @MainActor
final class SQWorkoutsLandingController: SQWorkoutsLandingInterface {
    
    @MainActor
    static var `default` = SQWorkoutsLandingController(state: AppState.shared.workoutScreenState)
    let state: WorkoutsLandingStating
    
    init(state: WorkoutsLandingStating) {
        self.state = state
    }
    
    func displayWorkoutSessionSheet() async {
        state.displayWorkoutSessionSheet()
    }
}
