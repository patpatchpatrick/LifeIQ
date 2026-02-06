//
//  SQStatRow.swift
//  BeastFitness
//

import SwiftUI

struct SQStatRow: View {
    let data: SQStatRowData

    // Detect if icon is emoji (single character) vs SF Symbol name
    private var isEmoji: Bool {
        data.icon.count == 1
    }

    // Color for change percentage based on positive/negative
    private var changeColor: SQColor {
        data.change14d >= 0 ? .colorFadedGreen : .colorFadedRed
    }

    var body: some View {
        HStack(spacing: 12) {
            // Column 1: Icon + Title (40%)
            HStack(spacing: 8) {
                if isEmoji {
                    Text(data.icon)
                        .font(.sqFont(.bodyLarge))
                } else {
                    // SF Symbol - will be added in Task 13
                    // For now, use a placeholder since symbols might not exist yet
                    if let symbol = SQImageSymbol(rawValue: data.icon) {
                        SQImageView(
                            image: .init(
                                symbol: symbol,
                                symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                            )
                        )
                        .frame(width: 16, height: 16)
                    } else {
                        // Fallback for missing symbols
                        Image(systemName: "questionmark.circle")
                            .font(.sqFont(.bodySmall))
                            .sqForegroundColor(.textSecondary)
                    }
                }

                Text(data.title)
                    .font(.sqFont(.body))
                    .sqForegroundColor(.textPrimary)

                Spacer()
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
                Rectangle()
                    .sqForegroundColor(changeColor)
                    .frame(width: 40, height: 20)
                    .cornerRadius(4)

                // Change percentage
                Text(String(format: "%.1f%%", abs(data.change14d)))
                    .font(.sqFont(.bodyExtraSmall))
                    .sqForegroundColor(changeColor)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .sqBackgroundColor(.background)
    }
}

#Preview("With Emoji") {
    SQStatRow(
        data: SQStatRowData(
            id: "mood",
            icon: "😊",
            title: "Mood",
            avgValue: "4.2",
            unit: "/5",
            sparklineData: [3.5, 4.0, 4.2, 4.1, 4.5, 4.3, 4.2],
            change14d: 12.5
        )
    )
    .sqBackgroundColor(.backgroundSecondary)
}

#Preview("With SF Symbol") {
    SQStatRow(
        data: SQStatRowData(
            id: "heart-rate",
            icon: "heart.fill",
            title: "Heart Rate",
            avgValue: "142",
            unit: "bpm",
            sparklineData: [138, 140, 142, 141, 145, 143, 142],
            change14d: -3.2
        )
    )
    .sqBackgroundColor(.backgroundSecondary)
}

#Preview("Multiple Rows") {
    VStack(spacing: 1) {
        SQStatRow(
            data: SQStatRowData(
                id: "energy",
                icon: "⚡️",
                title: "Energy",
                avgValue: "3.8",
                unit: "/5",
                sparklineData: [3.2, 3.5, 3.8, 3.9, 4.0, 3.7, 3.8],
                change14d: 8.3
            )
        )

        SQStatRow(
            data: SQStatRowData(
                id: "sleep",
                icon: "😴",
                title: "Sleep",
                avgValue: "7.2",
                unit: "hrs",
                sparklineData: [7.0, 7.5, 7.2, 6.8, 7.3, 7.1, 7.2],
                change14d: -5.1
            )
        )

        SQStatRow(
            data: SQStatRowData(
                id: "recovery",
                icon: "🧘",
                title: "Recovery",
                avgValue: "4.5",
                unit: "/5",
                sparklineData: [4.0, 4.2, 4.5, 4.3, 4.6, 4.4, 4.5],
                change14d: 15.7
            )
        )
    }
    .sqBackgroundColor(.backgroundSecondary)
}
