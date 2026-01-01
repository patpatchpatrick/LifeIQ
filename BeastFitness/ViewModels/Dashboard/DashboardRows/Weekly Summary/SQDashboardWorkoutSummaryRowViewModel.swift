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
    private(set) var dailyCheckInSummarySectionViewModel: SQDashboardWorkoutSummaryDailyCheckInSectionViewModel? = nil
    private(set) var totalsSection: SQDashboardWorkoutSummaryTotalsSectionViewModel? = nil
    private(set) var workoutsSection: SQDashboardWorkoutSummaryWorkoutsSectionViewModel? = nil
    private(set) var workouts: [SQWorkoutSessionable] = []
    private(set) var priorWorkouts: [SQWorkoutSessionable] = []
    
    var isEmpty: Bool {
        totalsSection == nil && workoutsSection == nil
    }

    init(
        rowId: WorkoutSummaryRowId,
        config: SQDashboardWorkoutSummaryRowConfig,
        workouts: [SQWorkoutSessionable],
        priorWorkouts: [SQWorkoutSessionable]
    ) {
        super.init(rowId: rowId.dashboardRowId, rowType: .workoutSummary)
        refresh(config: config, workouts: workouts, priorWorkouts: priorWorkouts)
    }

    func refresh(
        config: SQDashboardWorkoutSummaryRowConfig,
        workouts: [SQWorkoutSessionable],
        priorWorkouts: [SQWorkoutSessionable]
    ) {
        self.dailyCheckInSummarySectionViewModel = config.dailyCheckInSummarySectionViewModel
        self.workouts = workouts
        self.priorWorkouts = priorWorkouts
        self.sectionTitle = config.timeRange.title
        if config.timeRange != .today && workouts.isEmpty {
            /// Don't show the workouts section if workouts are empty. However, we'll still show the workouts section if the time range is today and workouts are empty, because we'll display a CTA to start a workout in that case
            self.workoutsSection = nil
        } else {
            self.workoutsSection = .init(workouts: workouts)
        }
        self.totalsSection = workouts.isEmpty ? nil : .init(config: config, workouts: workouts, priorWorkouts: priorWorkouts)
    }
}

extension SQDashboardWorkoutSummaryRowViewModel {
    enum WorkoutSummaryRowId {
        case daily
        case weekly
        case yearly

        var dashboardRowId: SQDashboardRowIdentifier {
            switch self {
            case .daily:  .dailySummary
            case .weekly: .weeklySummary
            case .yearly: .yearlySummary
            }
        }

        var timeRange: SQTimeRange {
            switch self {
            case .daily:  .today
            case .weekly: .pastWeek
            case .yearly: .pastYear
            }
        }

        var priorTimeRange: SQTimeRange {
            switch self {
            case .daily:  .yesterday
            case .weekly: .weekBeforeLast
            case .yearly: .yearBeforeLast
            }
        }
    }
}

struct SQDashboardWorkoutSummaryRowConfig {
    let timeRange: SQTimeRange
    let priorTimeRange: SQTimeRange
    let dailyCheckInSummarySectionViewModel: SQDashboardWorkoutSummaryDailyCheckInSectionViewModel?

    init(
        timeRange: SQTimeRange,
        priorTimeRange: SQTimeRange,
        dailyCheckInSummarySectionViewModel: SQDashboardWorkoutSummaryDailyCheckInSectionViewModel? = nil
    ) {
        self.timeRange = timeRange
        self.priorTimeRange = priorTimeRange
        self.dailyCheckInSummarySectionViewModel = dailyCheckInSummarySectionViewModel
    }

    static let mock = SQDashboardWorkoutSummaryRowConfig(timeRange: .pastWeek, priorTimeRange: .weekBeforeLast)
}
