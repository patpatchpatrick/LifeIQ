//
//  WorkoutsSummaryState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//


import SwiftUI

@MainActor
protocol WorkoutSummaryStating: AnyObject {
    var user: SQUser? { get }
    var userFullName: String? { get }
    var workoutStartDate: Date? { get }
    var workoutTitle: String? { get }
    
    func load(workout: SQWorkoutSessionable)
}

@MainActor
@Observable final class WorkoutSummaryState: WorkoutSummaryStating {
    private(set) var user: SQUser?
    private(set) var userFullName: String?
    private(set) var workoutStartDate: Date?
    private(set) var workoutTitle: String?
    
    private let hub: EventHub
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func load(workout: any SQWorkoutSessionable) {
        user = SQUser.mock
        userFullName = SQUser.mock.name // PTD replace with user's name
        workoutStartDate = workout.startDate
        workoutTitle = workout.activityType.name
    }
}
