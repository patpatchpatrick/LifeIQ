//
//  SQDashboardSleepPhaseTimelineRowView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQDashboardSleepPhaseTimelineRowView: View {
    @Bindable var viewModel: SQDashboardSleepPhaseTimelineRowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(viewModel.title)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)

            TimelineChartView(
                lanes: viewModel.lanes,
                segments: viewModel.segments,
                startDate: viewModel.startDate,
                endDate: viewModel.endDate
            )
            .frame(height: 120)
        }
    }
}
