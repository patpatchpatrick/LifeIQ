//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI
import SwiftData
import BeastFitnessCore

@MainActor
protocol SQWorkoutSummaryInterface {
    func load(workout: SQWorkoutSessionable)
    func pushEditWorkoutView()
}

@Observable @MainActor
final class SQWorkoutSummaryController: SQWorkoutSummaryInterface {
    let state: WorkoutSummaryStating
    private let workoutManager: SQWorkoutManaging
    var onPushEditWorkoutView: (SQWorkoutSessionable) -> Void
    var onDismiss: () -> Void
    
    @MainActor
    static func `default`(workout: any SQWorkoutSessionable, onPushEditWorkoutView: @escaping (SQWorkoutSessionable) -> Void, onDismiss: @escaping () -> Void) -> SQWorkoutSummaryController {
        Self.default.onPushEditWorkoutView = onPushEditWorkoutView
        Self.default.onDismiss = onDismiss
        Self.default.load(workout: workout)
        return Self.default
    }
    
    @MainActor
    static let `default`: SQWorkoutSummaryController = SQWorkoutSummaryController(state: SQAppState.shared.workoutSummaryState, onPushEditWorkoutView: { _ in }, onDismiss: {})

    init(state: WorkoutSummaryStating, workoutManager: SQWorkoutManaging = SQWorkoutManager(), onPushEditWorkoutView: @escaping (SQWorkoutSessionable) -> Void, onDismiss: @escaping () -> Void) {
        self.state = state
        self.workoutManager = workoutManager
        self.onPushEditWorkoutView = onPushEditWorkoutView
        self.onDismiss = onDismiss
    }
    
    func load(workout: any SQWorkoutSessionable) {
        state.load(workout: workout)
    }
    
    func pushEditWorkoutView() {
        guard let baseWorkout = state.currentWorkout else {
            SQLogger.shared.log("Workout missing. Can't push edit workout screen.", .error, context: .workoutSummary)
            return
        }
        
        onPushEditWorkoutView(baseWorkout)
    }
    
    func deleteWorkout(from modelContext: ModelContext) async {
        guard let baseWorkout = state.currentWorkout else {
            SQLogger.shared.log("Workout missing. Can't delete workout.", .error, context: .workoutSummary)
            return
        }
        
        let deletionType = workoutManager.deletionTypeForWorkout(baseWorkout)
        let title: String = "Delete workout?"
        let subtitle: String
        
        switch deletionType {
        case .hiddenHealtKit:
            subtitle = "This workout can't be deleted from HealthKit since it wasn't created by this app. But it will be hidden. Go to Settings to unhide workouts."
        case .hiddenStrava:
            subtitle = "This workout can't be deleted from Strava since it wasn't created by this app. But it will be hidden. Go to Settings to unhide workouts."
        case .standard:
            subtitle = "This workout will be deleted from both HealthKit and this app."
        }
        
        
        state.hub.alertEvents.send(.present(.init(
            title: title,
            subtitle: subtitle,
            primary: .init(title: "Delete workout?", handler: { _ in
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await workoutManager.deleteWorkout(workout: baseWorkout, from: modelContext)
                        state.notifyAppOfWorkoutDeletion(workout: baseWorkout)
                        onDismiss()
                    } catch {
                        state.hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
                    }
                }
            }),
            secondary: .init(title: "Cancel", role: .cancel))))
    }
}
