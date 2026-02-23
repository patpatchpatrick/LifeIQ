//
//  SQStatRow.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardStatRow: View {
    let data: SQStatRowData

    // Detect if icon is emoji (single character) vs SF Symbol name
    private var isEmoji: Bool {
        data.icon.count == 1
    }

    // Color for change percentage based on positive/negative
    private var changeColor: SQColor {
        data.changePercent >= 0 ? .colorFadedGreen : .colorFadedRed
    }
    
    var mainBody: some View {
        HStack(spacing: 12) {
            // Column 1: Icon + Title (40%)
            HStack(spacing: 8) {
                Group {
                    if isEmoji {
                        Text(data.icon)
                            .font(.sqFont(.bodyLarge))
                    } else if let symbol = SQImageSymbol(rawValue: data.icon) {
                        SQImageView(
                            image: .init(
                                symbol: symbol,
                                symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                            )
                        )
                        .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "questionmark.circle")
                            .font(.sqFont(.bodySmall))
                            .sqForegroundColor(.textSecondary)
                    }
                }
                .frame(width: 24)

                Text(data.title)
                    .font(.sqFont(.body))
                    .sqForegroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 2: Avg Value + Unit (30%)
            HStack(spacing: 4) {
                Text(data.avgValue)
                    .font(.sqFont(.bodySmallSemiBold))
                    .sqForegroundColor(.textPrimary)

                Text(data.unit)
                    .font(.sqFont(.bodyExtraSmall))
                    .sqForegroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: .trailing)

            // Column 3: Sparkline + Change (30%)
            HStack(spacing: 8) {
                // Placeholder sparkline (will integrate CoolCharts later)
                SQSparkline(dataPoints: data.sparklineData, height: 20)
                    .sqForegroundColor(changeColor)
                    .frame(width: 40)

                // Change percentage
                Text(String(format: "%.1f%%", abs(data.changePercent * 100)))
                    .font(.sqFont(.bodyExtraSmall))
                    .sqForegroundColor(changeColor)
                    .frame(width: 40, alignment: .trailing)
            }
            .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
        }
    }

    var body: some View {
        mainBody
        .sqBackgroundColor(.backgroundSecondary)
    }
}

#Preview("With Emoji") {
    SQDashboardStatRow(
        data: SQStatRowData(
            id: "mood",
            icon: "😊",
            title: "Mood",
            avgValue: "4.2",
            unit: "/5",
            sparklineData: [3.5, 4.0, 4.2, 4.1, 4.5, 4.3, 4.2],
            changePercent: 12.5
        )
    )
    .sqBackgroundColor(.backgroundSecondary)
}

#Preview("With SF Symbol") {
    SQDashboardStatRow(
        data: SQStatRowData(
            id: "heart-rate",
            icon: "heart.fill",
            title: "Heart Rate",
            avgValue: "142",
            unit: "bpm",
            sparklineData: [138, 140, 142, 141, 145, 143, 142],
            changePercent: -3.2
        )
    )
    .sqBackgroundColor(.backgroundSecondary)
}

#Preview("Multiple Rows") {
    VStack(spacing: 1) {
        SQDashboardStatRow(
            data: SQStatRowData(
                id: "energy",
                icon: "⚡️",
                title: "Energy",
                avgValue: "3.8",
                unit: "/5",
                sparklineData: [3.2, 3.5, 3.8, 3.9, 4.0, 3.7, 3.8],
                changePercent: 8.3
            )
        )

        SQDashboardStatRow(
            data: SQStatRowData(
                id: "sleep",
                icon: "😴",
                title: "Sleep",
                avgValue: "7.2",
                unit: "hrs",
                sparklineData: [7.0, 7.5, 7.2, 6.8, 7.3, 7.1, 7.2],
                changePercent: -5.1
            )
        )

        SQDashboardStatRow(
            data: SQStatRowData(
                id: "recovery",
                icon: "🧘",
                title: "Recovery",
                avgValue: "4.5",
                unit: "/5",
                sparklineData: [4.0, 4.2, 4.5, 4.3, 4.6, 4.4, 4.5],
                changePercent: 15.7
            )
        )
    }
    .sqBackgroundColor(.backgroundSecondary)
}
