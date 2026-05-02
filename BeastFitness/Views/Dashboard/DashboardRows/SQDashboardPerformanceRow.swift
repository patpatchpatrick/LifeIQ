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

    private var premiumAccentColor: SQColor? {
        data.scoreKind?.accentColor
    }

    private var isPremiumFeature: Bool {
        data.scoreKind != nil
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
                                symbolStyle: .colorWithFont(premiumAccentColor ?? .textSecondary, font: .bodySmall)
                            )
                        )
                        .frame(width: 16, height: 16)
                    }
                }
                .frame(width: 24)

                Text(data.title)
                    .font(.sqFont(.body))
                    .sqForegroundColor(.textPrimary)

                if isPremiumFeature {
                    Text("Premium")
                        .font(.sqFont(.bodyExtraSmall))
                        .padding(.horizontal, .SQSpace.s)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill((premiumAccentColor ?? .dashboardGlowBlue).color.opacity(SQColor.isDarkMode ? 0.22 : 0.12))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke((premiumAccentColor ?? .dashboardGlowBlue).color.opacity(0.4), lineWidth: 1)
                        )
                        .sqForegroundColor(.textPrimary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .trailing) {
                trailingColumns
                    .blur(radius: data.isPremiumLocked ? 5 : 0)

                if data.isPremiumLocked {
                    Text(data.premiumLockText.isEmpty ? SQSubscriptionManager.weeklyScorePreviewCompactText : data.premiumLockText)
                        .font(.sqFont(.bodyExtraSmall))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
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
            .padding(.horizontal, isPremiumFeature ? .SQSpace.m : 0)
            .padding(.vertical, isPremiumFeature ? .SQSpace.xs : 0)
            .background {
                if let premiumAccentColor {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.18 : 0.92))
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(premiumAccentColor.color.opacity(SQColor.isDarkMode ? 0.45 : 0.28), lineWidth: 1)
                        }
                        .overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            premiumAccentColor.color.opacity(SQColor.isDarkMode ? 0.18 : 0.10),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                }
            }
    }
}
