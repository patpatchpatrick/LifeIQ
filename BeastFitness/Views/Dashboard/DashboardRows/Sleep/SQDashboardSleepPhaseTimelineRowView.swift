//
//  SQDashboardSleepPhaseTimelineRowView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQDashboardSleepPhaseTimelineRowView: View {
    @Bindable var viewModel: SQDashboardSleepPhaseTimelineRowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            TimelineChartView(
                lanes: viewModel.lanes,
                segments: viewModel.segments,
                startDate: viewModel.startDate,
                endDate: viewModel.endDate,
                laneLabelWidth: 56,
                laneSpacing: 22,
                laneHeight: 12,
                visualStyle: .glass,
                onSegmentSelected: { segment in
                    viewModel.selectPhase(with: segment.laneId)
                },
                onLaneSelected: { lane in
                    viewModel.selectPhase(with: lane.id)
                }
            )
            .frame(height: 150)
            .padding(.top, .SQSpace.s)
        }
    }
}
