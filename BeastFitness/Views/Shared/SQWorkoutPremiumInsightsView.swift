//
//  SQWorkoutPremiumInsightsView.swift
//  BeastFitness
//

import SwiftUI

struct SQWorkoutPremiumInsightsView: View {
    let model: SQWorkoutPremiumInsightsModel
    let onScoreInfoTap: ((SQWorkoutPremiumInsightScore) -> Void)?

    private let scoreColumns = [
        GridItem(.adaptive(minimum: 150), spacing: .SQSpace.s, alignment: .leading)
    ]

    init(
        model: SQWorkoutPremiumInsightsModel,
        onScoreInfoTap: ((SQWorkoutPremiumInsightScore) -> Void)? = nil
    ) {
        self.model = model
        self.onScoreInfoTap = onScoreInfoTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            header

            ZStack {
                VStack(alignment: .leading, spacing: .SQSpace.l) {
                    LazyVGrid(columns: scoreColumns, alignment: .leading, spacing: .SQSpace.s) {
                        ForEach(model.scores) { score in
                            scoreCard(score)
                        }
                    }

                    Text(model.footer)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .blur(radius: model.availability == .locked ? 8 : 0)

                if model.availability == .locked {
                    lockOverlay
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(spacing: .SQSpace.s) {
                SQDashboardTrendBadge(
                    text: model.badgeTitle,
                    tone: .neutral,
                    symbol: nil
                )

                Spacer(minLength: 0)
            }

            Text(model.title)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)

            Text(model.subtitle)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func scoreCard(_ score: SQWorkoutPremiumInsightScore) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .top, spacing: .SQSpace.s) {
                Text(score.title.uppercased())
                    .sqFont(.headerSmall)
                    .sqForegroundColor(.textSecondary)

                Spacer(minLength: 0)

                if let onScoreInfoTap {
                    Button {
                        onScoreInfoTap(score)
                    } label: {
                        SQImageView(
                            image: .init(
                                symbol: .questionmarkCircle,
                                symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                            )
                        )
                        .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(score.value)")
                    .sqFont(.title1)
                    .sqForegroundColor(.textPrimary)

                Text("/100")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            SQDashboardTrendBadge(
                text: score.headline,
                tone: .neutral,
                symbol: nil
            )

            Text(score.detail)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.m)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(score.accentColor.color.opacity(SQColor.isDarkMode ? 0.42 : 0.28), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    score.accentColor.color.opacity(SQColor.isDarkMode ? 0.16 : 0.10),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
    }

    private var lockOverlay: some View {
        VStack(spacing: .SQSpace.s) {
            Text(model.lockedTitle ?? "Premium insights")
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            if let lockedSubtitle = model.lockedSubtitle {
                Text(lockedSubtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, .SQSpace.xl)
        .padding(.vertical, .SQSpace.l)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous))
    }
}
