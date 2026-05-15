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
    private let onPhaseSelected: ((SQSleepPhase) -> Void)?

    init(
        title: String,
        lanes: [TimelineChartLane],
        segments: [TimelineChartSegment],
        startDate: Date,
        endDate: Date,
        onPhaseSelected: ((SQSleepPhase) -> Void)? = nil
    ) {
        self.title = title
        self.lanes = lanes
        self.segments = segments
        self.startDate = startDate
        self.endDate = endDate
        self.onPhaseSelected = onPhaseSelected

        super.init(rowId: .sleepPhaseTimeline, rowType: .sleepPhaseTimeline)
    }

    func selectPhase(with id: String) {
        guard let phase = SQSleepPhase(rawValue: id) else { return }
        onPhaseSelected?(phase)
    }
}
