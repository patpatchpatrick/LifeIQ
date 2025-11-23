//
//  SQDashboardWeekSummaryRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardWeekSummaryRowViewModel: SQDashboardRowViewModel {
    let sectionTitle: String
    let totalsSection: SQDashboardWeekSummaryTotalsSectionViewModel
    let workoutsSection: SQDashboardWeekSummaryWorkoutsSectionViewModel
    
    init(timeRange: SQTimeRange, workouts: [SQWorkoutable], priorWorkouts: [SQWorkoutable]) {
        self.sectionTitle = timeRange.title
        self.totalsSection = .init(workouts: workouts, priorWorkouts: priorWorkouts)
        self.workoutsSection = .init(workouts: workouts)
        super.init(rowType: .weekSummary)
    }
}
