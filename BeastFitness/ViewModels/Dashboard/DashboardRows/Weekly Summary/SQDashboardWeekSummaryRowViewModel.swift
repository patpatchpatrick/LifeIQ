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
    
    init(workouts: [SQWorkoutable]) {
        self.sectionTitle = "This Week"
        self.totalsSection = .init(workouts: workouts)
        self.workoutsSection = .init(workouts: workouts)
        super.init(rowType: .weekSummary)
    }
}
