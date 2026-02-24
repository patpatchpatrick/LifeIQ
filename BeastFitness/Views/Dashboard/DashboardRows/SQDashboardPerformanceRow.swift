//
//  SQDashboardPerformanceRow.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-15.
//

import SwiftUI

struct SQDashboardPerformanceRow: View {
    let data: SQPerformanceRowData

    // Detect if icon is emoji (single character) vs SF Symbol name
    private var isEmoji: Bool {
        data.icon.count == 1
    }

    // Color for percentile rank based on performance
    private var rankColor: SQColor {
        guard let rank = data.percentileRank else {
            return .textSecondary
        }
        // Top quartile (< 0.25 percentile, meaning top 75%+) gets green
        return rank > 0.75 ? .colorFadedGreen : .textSecondary
    }

    // Format percentile as "Top X%"
    private var percentileText: String {
        guard let rank = data.percentileRank else {
            return "N/A"
        }
        let topPercent = Int((1.0 - rank) * 100)
        return "Top \(topPercent)%"
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

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 2: Best Value + Unit (30%)
            HStack(spacing: 4) {
                Text(data.bestValue)
                    .font(.sqFont(.bodySmallSemiBold))
                    .sqForegroundColor(.textPrimary)

                Text(data.unit)
                    .font(.sqFont(.bodyExtraSmall))
                    .sqForegroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: .trailing)

            // Column 3: Percentile Rank (30%)
            HStack(spacing: 8) {
                Text(percentileText)
                    .font(.sqFont(.bodyExtraSmall))
                    .sqForegroundColor(rankColor)
            }
            .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
        }
    }

    var body: some View {
        mainBody
        .sqBackgroundColor(.backgroundSecondary)
    }
}
