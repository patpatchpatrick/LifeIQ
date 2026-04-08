//
//  SQDashboardHeartSummaryRowViewModel.swift
//  BeastFitness
//

import Foundation
import SwiftUI
import CoolCharts

@Observable @MainActor
final class SQDashboardHeartSummaryRowViewModel: SQDashboardRowViewModel {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: String
        let unit: String
        let detail: String
    }

    struct TrendChart {
        let title: String
        let subtitle: String
        let points: [LineChartIdentifiablePoint]
        let trendPoints: [LineChartIdentifiablePoint]?
        let rangeLabelSuffix: String
        let averageValue: Double
        let averageLabel: String
    }

    let items: [Item]
    let trendChart: TrendChart?

    init(items: [Item], trendChart: TrendChart? = nil) {
        self.items = items
        self.trendChart = trendChart
        super.init(rowId: .heartSummary, rowType: .heartSummary)
    }

    func makeTrendChartModel(width: CGFloat) -> LineChartModel? {
        guard let trendChart else { return nil }

        let chartWidth = max(width, 140)
        let rangeLabelSuffix = trendChart.rangeLabelSuffix
        let averageValue = trendChart.averageValue
        let averageLabel = trendChart.averageLabel
        let colorConfig = LineChartModel.ColorConfig(
            textPrimary: SQColor.textPrimary.color,
            textSecondary: SQColor.textSecondary.color,
            backgroundPrimary: SQColor.glassCardTint.color,
            backgroundSecondary: SQColor.glassPopoverTint.color,
            lineColor: SQColor.dashboardGlowBlue.color,
            trendLineColor: SQColor.dashboardGlowMint.color
        )
        let fontConfig = LineChartModel.FontConfig(
            font: SQFont(type: .bodyExtraSmall).font,
            boldFont: SQFont(type: .bodySmallBold).font
        )

        return LineChartModel(
            width: chartWidth,
            height: 164,
            lineTitle: trendChart.title,
            uiConfig: .init(colorConfig: colorConfig, fontConfig: fontConfig),
            inputPoints: trendChart.points,
            trendInputPoints: trendChart.trendPoints,
            gridConfig: GridConfig(
                numberOfHorizontalLines: 3,
                numberOfVerticalLines: 3,
                lineColor: SQColor.glassStroke.color.opacity(SQColor.isDarkMode ? 0.9 : 0.55),
                showRangeLabels: true,
                rangeLabelBuilder: { value in
                    "\(Int(value.rounded())) \(rangeLabelSuffix)"
                },
                referenceLines: [
                    .init(
                        value: CGFloat(averageValue),
                        label: averageLabel,
                        lineColor: SQColor.dashboardGlowMint.color.opacity(0.8),
                        labelColor: SQColor.dashboardGlowMint.color,
                        lineWidth: 1,
                        dash: [3, 4]
                    )
                ]
            ),
            focusConfig: FocusConfig(
                focusColor: SQColor.dashboardGlowBlue.color,
                xLabelBuilder: { _, xValue in
                    let date = Date(timeIntervalSince1970: TimeInterval(xValue))
                    return date.formattedString(with: .medium)
                },
                yLabelBuilder: { _, yValue in
                    "\(Int(yValue.rounded())) \(rangeLabelSuffix)"
                }
            )
        )
    }
}
