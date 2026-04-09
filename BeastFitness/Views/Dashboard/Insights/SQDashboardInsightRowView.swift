//
//  SQDashboardInsightRowView.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import SwiftUI

struct SQDashboardInsightRowView: View {
    let viewModel: SQDashboardInsightRowViewModel

    private var effectTone: SQDashboardTrendTone {
        switch viewModel.model.effect {
        case .positive:
            return .positive
        case .negative:
            return .negative
        case .neutral:
            return .neutral
        }
    }

    private var accentColor: SQColor {
        switch viewModel.model.effect {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    private var relationshipSourceColor: SQColor {
        switch viewModel.model.effect {
        case .positive:
            return .dashboardGlowBlue
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    private var relationshipOutcomeColor: SQColor {
        switch viewModel.model.effect {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardGlowBlue
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    var body: some View {
        ZStack {
            cardBody
                .blur(radius: viewModel.isLocked ? 8 : 0)

            if viewModel.isLocked {
                lockOverlay
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            header
            relationshipRow
            metricRow

            Text(viewModel.model.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: .SQSpace.s) {
            HStack(spacing: .SQSpace.s) {
                SQDashboardTrendBadge(
                    text: viewModel.model.category.badgeTitle,
                    tone: .neutral,
                    symbol: nil
                )

                SQDashboardTrendBadge(
                    text: viewModel.model.confidence.badgeTitle,
                    tone: effectTone,
                    symbol: nil
                )
            }

            Spacer(minLength: 0)

            if let onInfoTap = viewModel.onInfoTap {
                Button(action: onInfoTap) {
                    SQImageView(
                        image: .init(
                            symbol: .infoCircle,
                            symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                        )
                    )
                    .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insight details")
            }
        }
    }

    private var relationshipRow: some View {
        HStack(spacing: .SQSpace.s) {
            relationshipCapsule(
                text: viewModel.model.driverText,
                color: relationshipSourceColor
            )

            SQImageView(
                image: .init(
                    symbol: .arrowRight,
                    symbolStyle: .colorWithFont(accentColor, font: .bodySmallSemiBold)
                )
            )
            .frame(width: 18, height: 18)

            relationshipCapsule(
                text: viewModel.model.outcomeText,
                color: relationshipOutcomeColor
            )
        }
    }

    private var metricRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
            Text(viewModel.model.deltaText)
                .sqFont(.title2)
                .sqForegroundColor(accentColor)

            Text("across \(viewModel.model.sampleCount) days")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
        }
    }

    private func relationshipCapsule(text: String, color: SQColor) -> some View {
        Text(text)
            .sqFont(.bodySmallSemiBold)
            .sqForegroundColor(.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, .SQSpace.m)
            .padding(.vertical, .SQSpace.s)
            .background {
                Capsule(style: .continuous)
                    .fill(color.color.opacity(SQColor.isDarkMode ? 0.18 : 0.12))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(color.color.opacity(SQColor.isDarkMode ? 0.34 : 0.24), lineWidth: 1)
                    }
            }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
            .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.98))
            .overlay {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .stroke(accentColor.color.opacity(SQColor.isDarkMode ? 0.36 : 0.24), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.color.opacity(SQColor.isDarkMode ? 0.14 : 0.10),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }

    private var lockOverlay: some View {
        VStack(spacing: .SQSpace.s) {
            Text("Unlock more insights")
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            Text("Go premium to see more patterns across your recovery, habits, and workouts.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, .SQSpace.xl)
        .padding(.vertical, .SQSpace.l)
        .background(
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.backgroundSheet.color.opacity(0.88))
        )
    }
}
