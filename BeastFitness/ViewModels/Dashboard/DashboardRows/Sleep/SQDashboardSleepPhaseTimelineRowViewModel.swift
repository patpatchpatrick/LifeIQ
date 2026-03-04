//
//  SQDashboardSleepPhaseTimelineRowViewModel.swift
//  BeastFitness
//

import Foundation
import CoolCharts

@Observable @MainActor
final class SQDashboardSleepPhaseTimelineRowViewModel: SQDashboardRowViewModel {
    let title: String
    let lanes: [TimelineChartLane]
    let segments: [TimelineChartSegment]
    let startDate: Date
    let endDate: Date

    init(
        title: String,
        lanes: [TimelineChartLane],
        segments: [TimelineChartSegment],
        startDate: Date,
        endDate: Date
    ) {
        self.title = title
        self.lanes = lanes
        self.segments = segments
        self.startDate = startDate
        self.endDate = endDate

        super.init(rowId: .sleepPhaseTimeline, rowType: .sleepPhaseTimeline)
    }
}
