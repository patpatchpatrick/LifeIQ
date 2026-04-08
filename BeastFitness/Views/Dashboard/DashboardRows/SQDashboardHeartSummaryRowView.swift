//
//  SQDashboardHeartSummaryRowView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQDashboardHeartSummaryRowView: View {
    @Bindable var viewModel: SQDashboardHeartSummaryRowViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: .SQSpace.s, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: .SQSpace.s) {
                ForEach(viewModel.items) { item in
                    heartStatCard(item)
                }
            }

            if let chart = viewModel.trendChart {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    VStack(alignment: .leading, spacing: .SQSpace.xs) {
                        Text(chart.title)
                            .sqFont(.bodySemiBold)
                            .sqForegroundColor(.textPrimary)

                        Text(chart.subtitle)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }

                    GeometryReader { geo in
                        if let chartModel = viewModel.makeTrendChartModel(width: geo.size.width) {
                            LineChartView(model: chartModel)
                                .frame(width: geo.size.width, height: 164)
                        }
                    }
                    .frame(height: 164)
                }
                .padding(.horizontal, .SQSpace.m)
                .padding(.vertical, .SQSpace.m)
                .background {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.70 : 0.96))
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(SQColor.glassStroke.color, lineWidth: 1)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func heartStatCard(_ item: SQDashboardHeartSummaryRowViewModel.Item) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(item.title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(item.value)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                if item.value != "--" {
                    Text(item.unit)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }

            Text(item.detail)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.s)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.70 : 0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
        }
    }
}
