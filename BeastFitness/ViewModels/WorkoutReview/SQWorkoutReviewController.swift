//
//  SQWorkoutReviewController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/25/26.
//


import Foundation
import Observation
import Combine
import SwiftData
import BeastFitnessCore

@MainActor
@Observable
final class SQWorkoutReviewController {
    private let hub: EventHub
    private let workoutManager: SQWorkoutManaging

    private(set) var queue: [SQWorkoutSessionable] = []
    var currentWorkout: SQWorkoutSessionable? { queue.first }
    var isPresented: Bool { currentWorkout != nil }
    var queueCount: Int { queue.count }

    init(hub: EventHub, workoutManager: SQWorkoutManaging = SQWorkoutManager.shared, workouts: [SQWorkoutSessionable]) {
        self.hub = hub
        self.workoutManager = workoutManager
        queue = workouts
    }

    /// Marks the current (first) workout as processed and advances the queue.
    func markCurrentAsProcessed(context: ModelContext) {
        guard let workout = currentWorkout else { return }
        workoutManager.markWorkoutsAsProcessed([workout], context: context)
        queue.removeFirst()
        if queue.isEmpty {
            dismiss()
        }
    }

    /// Marks every workout in the queue as processed and clears it.
    func markAllAsProcessed(context: ModelContext) {
        workoutManager.markWorkoutsAsProcessed(queue, context: context)
        queue.removeAll()
        dismiss()
    }
    
    private func dismiss() {
        hub.domainEvents.send(.popDashboardRoute)
    }
}
