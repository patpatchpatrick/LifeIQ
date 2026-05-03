//
//  SQInsightInfoSheetView.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import SwiftUI

struct SQInsightInfoSheetView: View {
    let model: SQInsight
    let explorerController: SQInsightExplorerController?

    private var effectTone: SQDashboardTrendTone {
        switch model.effect {
        case .positive:
            return .positive
        case .negative:
            return .negative
        case .neutral:
            return .neutral
        }
    }

    private var accentColor: SQColor {
        switch model.effect {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    private var canExplorePattern: Bool {
        model.inputSignalId != nil && model.outputSignalId != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .SQSpace.l) {
                    HStack(spacing: .SQSpace.s) {
                        SQDashboardTrendBadge(
                            text: model.category.badgeTitle,
                            tone: .neutral,
                            symbol: nil
                        )

                        SQDashboardTrendBadge(
                            text: model.confidence.badgeTitle,
                            tone: effectTone,
                            symbol: nil
                        )

                        SQDashboardTrendBadge(
                            text: "\(model.sampleCount) days",
                            tone: .neutral,
                            symbol: nil
                        )
                    }

                    VStack(alignment: .leading, spacing: .SQSpace.s) {
                        Text(model.title)
                            .sqFont(.title3)
                            .sqForegroundColor(.textPrimary)

                        Text(model.summary)
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    infoSection(title: "What LifeIQ noticed", text: model.evidenceText)
                    infoSection(title: "Suggested takeaway", text: model.actionText)

                    if canExplorePattern {
                        Button {
                            if let explorerController {
                                SQAppState.shared.hub.domainEvents.send(
                                    .pushDashboardRoute(.insightExplorer(controller: explorerController))
                                )
                            } else {
                                SQSubscriptionManager.displaySubscriptionScreen(
                                    source: "insight_detail_explore_pattern",
                                    feature: "insight_explorer"
                                )
                            }
                        } label: {
                            Text(explorerController == nil ? "Unlock Insight Explorer" : "Explore this pattern")
                                .sqFont(.bodySmallSemiBold)
                                .sqForegroundColor(.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, .SQSpace.m)
                                .background(
                                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                        .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.22 : 0.14))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                        .stroke(accentColor.color.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, .SQSpace.l)
                .padding(.vertical, .SQSpace.l)
            }
            .navigationTitle("Insight")
            .navigationBarTitleDisplayMode(.inline)
            .background {
                SQSheetBackground()
            }
        }
        .tint(accentColor.color)
    }

    private func infoSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            Text(text)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, .SQSpace.m)
                .padding(.vertical, .SQSpace.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.98))
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                                .stroke(accentColor.color.opacity(SQColor.isDarkMode ? 0.30 : 0.20), lineWidth: 1)
                        }
                }
        }
    }
}
