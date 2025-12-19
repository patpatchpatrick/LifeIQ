//
//  WorkoutsSummaryState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//


import SwiftUI
import Combine
import BeastFitnessCore

@MainActor
protocol WorkoutSummaryStating: AnyObject {
    var hub: EventHub { get }
    var user: SQUser? { get }
    var userFullName: String? { get }
    var workoutStartDate: Date? { get }
    var workoutTitle: String? { get }
    var workoutStatsRows: [SQWorkoutSummaryStatRow] { get }
    var workoutStatRowColumnCount: Int { get }
    
    var currentWorkout: SQWorkoutSessionable? { get }
    func load(workout: SQWorkoutSessionable)
    func notifyAppOfWorkoutDeletion(workout: SQWorkoutSessionable)
}

@MainActor
@Observable final class WorkoutSummaryState: WorkoutSummaryStating {
    let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var currentWorkout: (any SQWorkoutSessionable)?
    private(set) var user: SQUser?
    private(set) var userFullName: String?
    private(set) var workoutStartDate: Date?
    private(set) var workoutTitle: String?
    private(set) var workoutStatsRows: [SQWorkoutSummaryStatRow] = []
    private(set) var workoutStatRowColumnCount: Int = 3
    
    init(hub: EventHub) {
        self.hub = hub
        handleEventSubscriptions()
    }
    
    private func handleEventSubscriptions() {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated(let workoutMap):
                if let currentWorkoutId = currentWorkout?.id, let updatedWorkout = workoutMap [currentWorkoutId] {
                    SQLogger.shared.log("Refreshing workout with id: \(updatedWorkout.id) and title: \(String(describing: updatedWorkout.title))", .debug, context: .workoutSummary)
                    self.load(workout: updatedWorkout)
                }
            case .workoutsDeleted:
                return
                // No-op
            }
            
        }.store(in: &cancellables)
    }
    
    func load(workout: any SQWorkoutSessionable) {
        SQLogger.shared.log("Refreshing workout 2 with id: \(workout.id) and title: \(String(describing: workout.title))", .debug, context: .workoutSummary)
        currentWorkout = workout
        user = SQUser.mock
        userFullName = SQUser.mock.name // PTD replace with user's name
        workoutStartDate = workout.startDate
        workoutTitle = workout.visibleTitle
        
        let visibleStats = workout.visibleStats ?? []
        let visibleStatsChunks = visibleStats.chunked(into: workoutStatRowColumnCount)
        
        workoutStatsRows = visibleStatsChunks.map {
            .init(visibleStats: $0)
        }
    }
    
    func notifyAppOfWorkoutDeletion(workout: SQWorkoutSessionable) {
        hub.workoutEvents.send(.workoutsDeleted([workout.id: workout]))
    }
}

struct SQWorkoutSummaryStatRow: Identifiable {
    let id = UUID()
    let visibleStats: [SQWorkoutSessionVisibleStat]
}
