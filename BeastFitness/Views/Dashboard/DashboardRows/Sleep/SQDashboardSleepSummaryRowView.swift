//
//  SQDashboardSleepSummaryRowView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQDashboardSleepSummaryRowView: View {
    @Bindable var viewModel: SQDashboardSleepSummaryRowViewModel

    var body: some View {
        HStack(alignment: .top, spacing: .SQSpace.s) {
            ForEach(viewModel.items) { item in
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(item.title.uppercased())
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textSecondary)

                    Text(item.value)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .SQSpace.m)
                .padding(.horizontal, .SQSpace.m)
                .background(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.65 : 0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
            }
        }
    }
}

struct SQDashboardSleepDurationRowView: View {
    @Bindable var viewModel: SQDashboardSleepDurationRowViewModel

    var body: some View {
        BarChartView(
            dataPoints: viewModel.bars.map {
                .init(
                    id: $0.id,
                    label: $0.label,
                    value: $0.valueHours,
                    color: $0.color,
                    focusTitle: $0.focusTitle
                )
            },
            maxHeight: 108,
            barSpacing: viewModel.barSpacing,
            barCornerRadius: 4,
            minimumBarWidth: viewModel.minimumBarWidth,
            maximumBarWidth: viewModel.maximumBarWidth,
            labelFont: SQFont(type: .bodyExtraSmall).font,
            labelColor: SQColor.textSecondary.color,
            visualStyle: .glass,
            referenceLines: [
                .init(
                    value: viewModel.averageDurationHours,
                    label: viewModel.averageLabel,
                    color: SQColor.dashboardGlowMint.color.opacity(0.82),
                    lineWidth: 1,
                    dash: [3, 4]
                )
            ],
            focusConfig: .init(
                valueLabelBuilder: { value in
                    let totalMinutes = Int((value * 60).rounded())
                    let hours = totalMinutes / 60
                    let minutes = totalMinutes % 60
                    return "\(hours)h \(minutes)m"
                }
            )
        )
    }
}
