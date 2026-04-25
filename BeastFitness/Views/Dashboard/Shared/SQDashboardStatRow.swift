//
//  SQStatRow.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQDashboardStatRow: View {
    let data: SQStatRowData

    // Detect if icon is emoji (single character) vs SF Symbol name
    private var isEmoji: Bool {
        data.icon.count == 1
    }

    private var changeTone: SQDashboardTrendTone {
        guard let pct = data.changePercent else { return .neutral }
        return pct >= 0 ? .positive : .negative
    }

    private var sparklineLineColor: Color {
        SQColor.dashboardGlowBlue.color.opacity(0.58)
    }

    @ViewBuilder
    private var trendColumn: some View {
        let hasSparkline = data.sparklineData.count >= 2
        VStack(alignment: .trailing, spacing: 4) {
            if hasSparkline {
                SparklineView(
                    dataPoints: data.sparklineData.map { SparklineView.DataPoint(value: $0) },
                    lineColor: sparklineLineColor
                )
                .frame(width: 55, height: 20)
            }

            if let pct = data.changePercent {
                SQDashboardTrendBadge(
                    text: String(format: "%.1f%%", abs(pct * 100)),
                    tone: changeTone,
                    symbol: pct >= 0 ? .arrowUp : .arrowDown
                )
            }
        }
        .frame(maxWidth: .infinity * 0.8, maxHeight: .infinity, alignment: .trailing)
    }

    var mainBody: some View {
        HStack(spacing: .SQSpace.l) {
            // Column 1: Icon + Title
            HStack(spacing: 8) {
                if !isEmoji {
                    if let symbol = SQImageSymbol(rawValue: data.icon) {
                        SQImageView(
                            image: .init(
                                symbol: symbol,
                                symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                            )
                        )
                        .frame(width: 16, height: 16)
                    }
                }

                Text(data.title)
                    .font(.sqFont(.body))
                    .sqForegroundColor(.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 2: Avg Value + Unit
            HStack(spacing: 4) {
                Text(data.avgValue)
                    .font(.sqFont(.bodySmallSemiBold))
                    .sqForegroundColor(.textPrimary)

                Text(data.unit)
                    .font(.sqFont(.bodyExtraSmall))
                    .sqForegroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: .trailing)

            // Column 3: Stacked sparkline + trend indicator
            trendColumn
                .padding(.leading, .SQSpace.m)
        }
        .padding(.vertical, .SQSpace.s)
    }

    var body: some View {
        mainBody
    }
}

struct SQDashboardTrendBadge: View {
    let text: String
    let tone: SQDashboardTrendTone
    let symbol: SQImageSymbol?

    private var fillColor: Color {
        switch tone {
        case .positive:
            return tone.accentColor.color.opacity(SQColor.isDarkMode ? 0.14 : 0.12)
        case .negative:
            return tone.accentColor.color.opacity(SQColor.isDarkMode ? 0.12 : 0.10)
        case .neutral:
            return SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.85 : 1)
        }
    }

    private var strokeColor: Color {
        switch tone {
        case .positive, .negative:
            return tone.accentColor.color.opacity(SQColor.isDarkMode ? 0.28 : 0.22)
        case .neutral:
            return SQColor.glassStroke.color
        }
    }

    private var textColor: SQColor {
        tone == .neutral ? .textSecondary : .textPrimary
    }

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                SQImageView(
                    image: .init(
                        symbol: symbol,
                        symbolStyle: .colorWithFont(tone.accentColor, font: .bodyExtraSmall)
                    )
                )
                .frame(width: 10, height: 10)
            }

            Text(text)
                .font(.sqFont(.bodyExtraSmall))
                .sqForegroundColor(textColor)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, .SQSpace.s)
        .background(
            Capsule(style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
    }
}

struct SQDashboardNewBadge: View {
    var text: String = "New"

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(SQColor.dashboardGlowBlueForeground.color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.sqFont(.bodyExtraSmall))
                .sqForegroundColor(.dashboardGlowBlueForeground)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, .SQSpace.s)
        .background(
            Capsule(style: .continuous)
                .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.88 : 0.72))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.62 : 0.44), lineWidth: 1)
        )
        .shadow(color: SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.20 : 0.10), radius: 10, x: 0, y: 4)
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

#Preview("No Prior Data") {
    VStack(spacing: 1) {
        SQDashboardStatRow(
            data: SQStatRowData(
                id: "mood-nodata",
                icon: "😊",
                title: "Mood (has sparkline)",
                avgValue: "4.2",
                unit: "/5",
                sparklineData: [3.5, 4.0, 4.2, 4.1, 4.5, 4.3, 4.2],
                changePercent: nil
            )
        )
        SQDashboardStatRow(
            data: SQStatRowData(
                id: "sleep-nodata",
                icon: "😴",
                title: "Sleep (no data)",
                avgValue: "7.2",
                unit: "hrs",
                sparklineData: [],
                changePercent: nil
            )
        )
    }
    .sqBackgroundColor(.backgroundSecondary)
}
