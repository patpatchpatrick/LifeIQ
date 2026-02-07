//
//  SQDashboardWorkoutSummaryRowConfig.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//

struct SQDashboardWorkoutSummaryRowConfig {
    let timeRange: SQTimeRange
    let priorTimeRange: SQTimeRange

    init(
        timeRange: SQTimeRange,
        priorTimeRange: SQTimeRange
    ) {
        self.timeRange = timeRange
        self.priorTimeRange = priorTimeRange
    }

    static let mock = SQDashboardWorkoutSummaryRowConfig(timeRange: .pastWeek, priorTimeRange: .weekBeforeLast)
}
