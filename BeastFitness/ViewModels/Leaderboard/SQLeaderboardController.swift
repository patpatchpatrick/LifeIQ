//
//  SQLeaderboardController.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI
import Combine
import BeastFitnessCore
import HealthKit

@MainActor
protocol SQLeaderboardInterface {
}

@Observable @MainActor
final class SQLeaderboardController: SQLeaderboardInterface {
    var navigationPath = NavigationPath()
    private var cancellables = Set<AnyCancellable>()
    let state: LeaderboardStating
    private(set) var hasLoadedUI = false

    let quantityType: SQQuantityType
    let activityType: HKWorkoutActivityType
    private(set) var workouts: [SQWorkoutSessionable]

    @MainActor
    static let `default` = SQLeaderboardController(
        state: SQAppState.shared.leaderboardState,
        quantityType: .distanceWalkingRunning,
        activityType: .running,
        workouts: []
    )

    init(
        state: LeaderboardStating,
        quantityType: SQQuantityType,
        activityType: HKWorkoutActivityType,
        workouts: [SQWorkoutSessionable] = []
    ) {
        self.state = state
        self.quantityType = quantityType
        self.activityType = activityType
        self.workouts = workouts
        handleEventSubscriptions(hub: state.hub)
    }

    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated(let workoutMap):
                // Update workouts if they've changed
                workouts = workouts.compactMap { workout in
                    workoutMap[workout.id] ?? workout
                }
            case .workoutsDeleted(let workoutMap):
                // Remove deleted workouts
                workouts = workouts.filter { workoutMap[$0.id] == nil }
            case .activeWorkoutUpdate:
                break
            }
        }.store(in: &cancellables)
    }
}
