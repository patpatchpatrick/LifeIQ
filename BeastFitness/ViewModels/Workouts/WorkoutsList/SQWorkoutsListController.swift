//
//  SQWorkoutsListViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI
import Combine
import BeastFitnessCore

@MainActor
protocol SQWorkoutsListInterface {
}

@Observable @MainActor
final class SQWorkoutsListController: SQWorkoutsListInterface {
    private var cancellables = Set<AnyCancellable>()
    private(set) var hasLoadedUI = false
    private let hub: EventHub
    private(set) var rows: [SQWorkoutsListItemViewModel]
    
    init(eventHub: EventHub, workouts: [SQWorkoutSessionable] = []) {
        self.hub = eventHub
        self.rows = workouts
            .sorted(by: { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) })
            .map { .init(workout: $0) }
        handleEventSubscriptions(hub: eventHub)
    }
    
    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated(let workoutMap):
                rows.forEach { row in
                    if let updatedWorkout = workoutMap[row.workout.id] {
                        SQLogger.shared.log("Refreshing list workout with id: \(updatedWorkout.id) and title: \(String(describing: updatedWorkout.title))", .debug, context: .workoutList)
                        row.workout = updatedWorkout
                    }
                }
            case .workoutsDeleted(let workoutMap):
                rows = rows.filter { workoutMap[$0.workout.id] == nil }
            case .activeWorkoutUpdate:
                break
            }
        }.store(in: &cancellables)
    }
    
    func displayWorkoutSummary(for row: SQWorkoutsListItemViewModel) {
        hub.domainEvents.send(.pushDashboardRoute(.workoutSummary(controller: .init(workout: row.workout))))
    }
    
    func pushEditWorkoutView(for workout: SQWorkoutSessionable) {
        hub.domainEvents.send(.pushDashboardRoute(.editWorkout(workout: workout)))
    }
}
