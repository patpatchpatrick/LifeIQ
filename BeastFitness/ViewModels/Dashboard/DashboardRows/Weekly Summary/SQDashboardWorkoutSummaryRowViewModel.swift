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
    let totalsSectionConfig: TotalsSectionConfig
    let timeRange: SQTimeRange
    let priorTimeRange: SQTimeRange
    
    init(totalsSectionConfig: TotalsSectionConfig = TotalsSectionConfig(), timeRange: SQTimeRange, priorTimeRange: SQTimeRange) {
        self.totalsSectionConfig = totalsSectionConfig
        self.timeRange = timeRange
        self.priorTimeRange = priorTimeRange
    }
    
    struct TotalsSectionConfig {
        let callToAction: SQCallToActionViewModel?
        
        init(callToAction: SQCallToActionViewModel? = nil) {
            self.callToAction = callToAction
        }
    }
    
    static let mock = SQDashboardWorkoutSummaryRowConfig(totalsSectionConfig: .init(callToAction: .init(title: "Complete daily check-in", onTap: nil)), timeRange: .pastWeek, priorTimeRange: .weekBeforeLast)
}
