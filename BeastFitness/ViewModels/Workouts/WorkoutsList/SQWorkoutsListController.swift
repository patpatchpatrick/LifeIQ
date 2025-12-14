//
//  SQWorkoutsListViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

@MainActor
protocol SQWorkoutsListInterface {
}

@Observable @MainActor
final class SQWorkoutsListController: SQWorkoutsListInterface {
    var navigationPath = NavigationPath()
    let state: WorkoutsListStating
    private(set) var hasLoadedUI = false
    private(set) var rows: [SQWorkoutsListItemViewModel]
    
    @MainActor
    static let `default` = SQWorkoutsListController(state: AppState.shared.workoutsListState)
    
    init(state: WorkoutsListStating, workouts: [SQWorkoutSessionable] = []) {
        self.state = state
        self.rows = workouts
            .sorted(by: { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) })
            .map { .init(workout: $0) }
    }
    
    func displayWorkoutSummary(for row: SQWorkoutsListItemViewModel) {
        navigationPath.append(SQNavRoute.WorkoutsList.workoutView(workout: row.workout))
    }
    
    func pushEditWorkoutView(for workout: SQWorkoutSessionable) {
        navigationPath.append(SQNavRoute.WorkoutsList.editWorkout(workout: workout))
    }
    
    func popView() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}
