//
//  SQDashboardWorkoutTotalsRowView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//

import SwiftUI

struct SQDashboardWorkoutTotalsRowView: View {
    @Bindable var viewModel: SQDashboardWorkoutTotalsRowViewModel

    private var chartDataPoints: [SQActivityBarChart.DataPoint] {
        let maxValue = viewModel.currentChartDataPoints.map(\.value).max() ?? 1
        let latestIndex = max(0, viewModel.currentChartDataPoints.count - 1)

        return viewModel.currentChartDataPoints.enumerated().map { index, point in
            let normalizedValue = maxValue > 0 ? point.value / maxValue : 0
            let baseOpacity = 0.20 + (normalizedValue * 0.40)
            let isLatest = index == latestIndex
            let color = isLatest
                ? SQColor.dashboardGlowBlue.color.opacity(0.95)
                : Color.white.opacity(baseOpacity)

            return SQActivityBarChart.DataPoint(
                label: point.label,
                value: point.value,
                color: color
            )
        }
    }
    
    var totalValuesAndTrendsStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            SQDashboardWorkoutStatView(attributedTitle: viewModel.currentValueAndTrend.value)

            if let trend = viewModel.currentValueAndTrend.trend {
                trendSummaryView(trend)
            }
        }
    }

    @ViewBuilder
    private func trendSummaryView(_ trend: SQDashboardWorkoutTotalsRowViewModel.TrendSummary) -> some View {
        if let emphasizedValue = trend.emphasizedValue {
            HStack(spacing: .SQSpace.xs) {
                Text(trend.prefix)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)

                SQDashboardTrendBadge(
                    text: emphasizedValue,
                    tone: trend.tone,
                    symbol: trend.tone == .neutral ? nil : (trend.tone == .positive ? .arrowUp : .arrowDown)
                )

                Text(trend.suffix)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
            }
        } else {
            Text("\(trend.prefix) \(trend.suffix)")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Activity bar chart
            if !viewModel.currentChartDataPoints.isEmpty && viewModel.currentChartDataPoints.count > 1 {
                SQActivityBarChart(
                    dataPoints: chartDataPoints,
                    maxHeight: 64,
                    barSpacing: 6,
                    barCornerRadius: 7,
                    labelColor: SQColor.textDisabled.color,
                    visualStyle: .glass
                )
                .padding(.bottom, .SQSpace.xl)
            }
            
            totalValuesAndTrendsStack
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    var body: some View {
        mainStack
    }
}

import SwiftUI

struct SQDashboardWorkoutStatView: View {
    let attributedTitle: AttributedString
    
    var body: some View {
        Text(attributedTitle)
            .padding(.top, .SQSpace.m)
            .padding(.bottom, .SQSpace.m)
            .padding(.horizontal, .SQSpace.l)
            .background(
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.8 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .stroke(SQColor.glassStroke.color, lineWidth: 1)
            )
    }
}

#Preview {
    SQDashboardWorkoutStatView(attributedTitle: .init("Test"))
        .preferredColorScheme(.dark)
}
