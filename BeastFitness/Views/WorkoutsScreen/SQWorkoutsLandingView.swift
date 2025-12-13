//
//  SQWorkoutsLandingView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI

struct SQWorkoutsLandingView: View {
    @Bindable var controller: SQWorkoutsLandingController
    
    var startWorkoutButton: some View {
        Button("Start Workout", action: { Task { await controller.displayWorkoutSessionSheet() } })
    }
    
    var body: some View {
        startWorkoutButton
            .sheet(isPresented: .init(
                get: { controller.state.isWorkoutSessionSheetVisible},
                set: { isVisible in controller.state.toggleWorkoutSessionSheetVisibility(isVisible) })) {
                    if let workoutSessionViewModel = controller.state.workoutSessionViewModel {
                        SQWorkoutSessionView(isBeingDisplayedWithinNavStack: false, controller: workoutSessionViewModel)
                    }
                }
    }
}
