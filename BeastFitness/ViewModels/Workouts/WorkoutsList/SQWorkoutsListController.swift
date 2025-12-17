//
//  SQWorkoutsListViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI
import Combine

@MainActor
protocol SQWorkoutsListInterface {
}

@Observable @MainActor
final class SQWorkoutsListController: SQWorkoutsListInterface {
    var navigationPath = NavigationPath()
    private var cancellables = Set<AnyCancellable>()
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
        handleEventSubscriptions(hub: state.hub)
    }
    
    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated(let workoutMap):
                rows.forEach { row in
                    if let updatedWorkout = workoutMap[row.workout.id] {
                        SQLogger.shared.log("Refreshing list workout with id: \(updatedWorkout.id) and title: \(updatedWorkout.title)", .debug, context: .workoutList)
                        row.workout = updatedWorkout
                    }
                }
            case .workoutsDeleted(let workoutMap):
                rows = rows.filter { workoutMap[$0.workout.id] == nil }
            }
        }.store(in: &cancellables)
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
