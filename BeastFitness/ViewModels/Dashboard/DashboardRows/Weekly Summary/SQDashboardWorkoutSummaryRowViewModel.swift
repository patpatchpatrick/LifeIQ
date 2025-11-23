//
//  SQDashboardWeekSummaryRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardWorkoutSummaryRowViewModel: SQDashboardRowViewModel {
    let sectionTitle: String
    let totalsSection: SQDashboardWorkoutSummaryTotalsSectionViewModel
    let workoutsSection: SQDashboardWorkoutSummaryWorkoutsSectionViewModel
    
    init(config: SQDashboardWorkoutSummaryRowConfig, workouts: [SQWorkoutable], priorWorkouts: [SQWorkoutable]) {
        self.sectionTitle = config.timeRange.title
        self.totalsSection = .init(config: config, workouts: workouts, priorWorkouts: priorWorkouts)
        self.workoutsSection = .init(workouts: workouts)
        super.init(rowType: .weekSummary)
    }
}

struct SQDashboardWorkoutSummaryRowConfig {
    let timeRange: SQTimeRange
    let priorTimeRange: SQTimeRange
    
    static let mock = SQDashboardWorkoutSummaryRowConfig(timeRange: .pastWeek, priorTimeRange: .weekBeforeLast)
}
