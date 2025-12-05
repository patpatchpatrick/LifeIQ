//
//  SQDashboardWeekSummaryRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardWorkoutSummaryRowViewModel: SQDashboardRowViewModel {
    private(set) var sectionTitle: String = ""
    private(set) var totalsSection: SQDashboardWorkoutSummaryTotalsSectionViewModel? = nil
    let workoutsSection: SQDashboardWorkoutSummaryWorkoutsSectionViewModel
    
    let workouts: [SQWorkoutable]
    let priorWorkouts: [SQWorkoutable]
    
    init(rowId: WorkoutSummaryRowId, config: SQDashboardWorkoutSummaryRowConfig, workouts: [SQWorkoutable], priorWorkouts: [SQWorkoutable]) {
        self.workouts = workouts
        self.priorWorkouts = priorWorkouts
        self.workoutsSection = .init(workouts: workouts)
        super.init(rowId: rowId.dashboardRowId, rowType: .weekSummary)
        refreshConfig(config: config)
    }
    
    func refreshConfig(config: SQDashboardWorkoutSummaryRowConfig) {
        self.sectionTitle = config.timeRange.title
        self.totalsSection = .init(config: config, workouts: workouts, priorWorkouts: priorWorkouts)
    }
}

extension SQDashboardWorkoutSummaryRowViewModel {
    enum WorkoutSummaryRowId {
        case daily
        case weekly
        case yearly
        
        var dashboardRowId: SQDashboardRowIdentifier {
            switch self {
            case .daily:
                    .dailySummary
            case .weekly:
                    .weeklySummary
            case .yearly:
                    .yearlySummary
            }
        }
        
        var timeRange: SQTimeRange {
            switch self {
            case .daily:
                    .today
            case .weekly:
                    .pastWeek
            case .yearly:
                    .pastYear
            }
        }
        
        var priorTimeRange: SQTimeRange {
            switch self {
            case .daily:
                    .yesterday
            case .weekly:
                    .weekBeforeLast
            case .yearly:
                    .yearBeforeLast
            }
        }
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
        let dailyCheckInSummaryConfig: DailyCheckInStatsSummaryConfig?
        
        init(callToAction: SQCallToActionViewModel? = nil, dailyCheckInSummaryConfig: DailyCheckInStatsSummaryConfig? = nil) {
            self.callToAction = callToAction
            self.dailyCheckInSummaryConfig = dailyCheckInSummaryConfig
        }
    }
    
    struct DailyCheckInStatsSummaryConfig {
        let title: String
        let subtitle: String
        let icon: SQImageSymbol?
        let onTap: (() -> Void)?
        
        init(title: String, subtitle: String, icon: SQImageSymbol? = nil, onTap: (() -> Void)? = nil) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.onTap = onTap
        }
    }
    
    static let mock = SQDashboardWorkoutSummaryRowConfig(totalsSectionConfig: .init(callToAction: .init(title: "Complete daily check-in", onTap: nil)), timeRange: .pastWeek, priorTimeRange: .weekBeforeLast)
}
