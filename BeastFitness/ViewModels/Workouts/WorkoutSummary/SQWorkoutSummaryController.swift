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
    func pushEditWorkoutView()
}

@Observable @MainActor
final class SQWorkoutSummaryController: SQWorkoutSummaryInterface {
    let state: WorkoutSummaryStating
    var onPushEditWorkoutView: (SQWorkoutSessionable) -> Void
    
    @MainActor
    static func `default`(workout: any SQWorkoutSessionable, onPushEditWorkoutView: @escaping (SQWorkoutSessionable) -> Void) -> SQWorkoutSummaryController {
        Self.default.onPushEditWorkoutView = onPushEditWorkoutView
        Self.default.load(workout: workout)
        return Self.default
    }
    
    @MainActor
    static let `default`: SQWorkoutSummaryController = SQWorkoutSummaryController(state: AppState.shared.workoutSummaryState, onPushEditWorkoutView: { _ in })

    init(state: WorkoutSummaryStating, onPushEditWorkoutView: @escaping (SQWorkoutSessionable) -> Void) {
        self.state = state
        self.onPushEditWorkoutView = onPushEditWorkoutView
    }
    
    func load(workout: any SQWorkoutSessionable) {
        state.load(workout: workout)
    }
    
    func pushEditWorkoutView() {
        guard let baseWorkout = state.currentWorkout else {
            SQLogger.shared.log("Workout missing. Can't push edit workout screen.", .error, context: .workoutSummary)
            return
        }
        
        print("PTD Push Edit Workout View", onPushEditWorkoutView)
        onPushEditWorkoutView(baseWorkout)
    }
}
