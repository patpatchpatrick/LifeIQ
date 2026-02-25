//
//  SQNewWorkoutReviewState.swift
//  BeastFitness
//

import Foundation
import Observation
import Combine
import SwiftData
import BeastFitnessCore

@MainActor
@Observable
final class SQNewWorkoutReviewState {
    private let hub: EventHub
    private let workoutManager: SQWorkoutManaging
    private var cancellables = Set<AnyCancellable>()

    private(set) var queue: [SQWorkoutSessionable] = []
    var currentWorkout: SQWorkoutSessionable? { queue.first }
    var isPresented: Bool { currentWorkout != nil }
    var queueCount: Int { queue.count }

    init(hub: EventHub, workoutManager: SQWorkoutManaging = SQWorkoutManager.shared) {
        self.hub = hub
        self.workoutManager = workoutManager
        subscribeToEvents()
    }

    private func subscribeToEvents() {
        hub.workoutReviewEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsReadyForReview(let workouts):
                // Only update if queue is empty — don't disrupt an in-progress review
                guard queue.isEmpty else { return }
                queue = workouts
                SQLogger.shared.log(
                    "Workout review queue loaded with \(workouts.count) workout(s)",
                    .info,
                    context: .workoutManager
                )
            }
        }.store(in: &cancellables)
    }

    /// Marks the current (first) workout as processed and advances the queue.
    func markCurrentAsProcessed(context: ModelContext) {
        guard let workout = currentWorkout else { return }
        workoutManager.markWorkoutsAsProcessed([workout], context: context)
        queue.removeFirst()
    }

    /// Marks every workout in the queue as processed and clears it.
    func markAllAsProcessed(context: ModelContext) {
        workoutManager.markWorkoutsAsProcessed(queue, context: context)
        queue.removeAll()
    }
}
