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
    var workoutStatsRows: [SQWorkoutSummaryStatRow] { get }
    
    func load(workout: SQWorkoutSessionable)
}

@MainActor
@Observable final class WorkoutSummaryState: WorkoutSummaryStating {
    private(set) var user: SQUser?
    private(set) var userFullName: String?
    private(set) var workoutStartDate: Date?
    private(set) var workoutTitle: String?
    private(set) var workoutStatsRows: [SQWorkoutSummaryStatRow] = []
    
    private let hub: EventHub
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func load(workout: any SQWorkoutSessionable) {
        user = SQUser.mock
        userFullName = SQUser.mock.name // PTD replace with user's name
        workoutStartDate = workout.startDate
        workoutTitle = workout.activityType.name
        
        let visibleStats = workout.visibleStats ?? []
        let visibleStatsChunks = visibleStats.chunked(into: 3)
        
        workoutStatsRows = visibleStatsChunks.map {
            .init(visibleStats: $0)
        }
    }
}

struct SQWorkoutSummaryStatRow: Identifiable {
    let id = UUID()
    let visibleStats: [SQWorkoutSessionVisibleStat]
}
