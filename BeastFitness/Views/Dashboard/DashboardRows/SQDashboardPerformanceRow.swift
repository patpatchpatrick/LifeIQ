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

    private var rankTone: SQDashboardTrendTone {
        guard let rank = data.percentileRank else {
            return .neutral
        }
        return rank >= 0.5 ? .positive : .negative
    }

    private var topPercentText: String {
        guard let rank = data.percentileRank else {
            return ""
        }
        let topPercent = Int((1.0 - rank) * 100)
        return "\(topPercent)%"
    }

    @ViewBuilder
    private var trailingColumns: some View {
        HStack(spacing: 12) {
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
            HStack(spacing: .SQSpace.xs) {
                if data.percentileRank != nil {
                    Text("Top")
                        .font(.sqFont(.bodyExtraSmall))
                        .sqForegroundColor(.textSecondary)

                    SQDashboardTrendBadge(
                        text: topPercentText,
                        tone: rankTone,
                        symbol: nil
                    )
                } else {
                    Text("N/A")
                        .font(.sqFont(.bodyExtraSmall))
                        .sqForegroundColor(.textTertiary)
                }
            }
            .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
        }
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
                    }
                }
                .frame(width: 24)

                Text(data.title)
                    .font(.sqFont(.body))
                    .sqForegroundColor(.textPrimary)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .trailing) {
                trailingColumns
                    .blur(radius: data.isPremiumLocked ? 5 : 0)

                if data.isPremiumLocked {
                    Text("Premium")
                        .font(.sqFont(.bodyExtraSmall))
                        .padding(.horizontal, .SQSpace.s)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.9 : 1))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(SQColor.glassStroke.color, lineWidth: 1)
                        )
                        .sqForegroundColor(.textPrimary)
                }
            }
        }
        .padding(.vertical, .SQSpace.s)
    }

    var body: some View {
        mainBody
    }
}
