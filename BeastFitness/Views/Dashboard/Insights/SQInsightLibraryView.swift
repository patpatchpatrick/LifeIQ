//
//  SQInsightLibraryView.swift
//  BeastFitness
//
//  Created by Codex on 5/27/26.
//

import SwiftUI

struct SQInsightLibraryView: View {
    @Bindable var controller: SQInsightLibraryController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.l) {
                controls

                if controller.relationships.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: .SQSpace.m) {
                        ForEach(controller.relationships) { relationship in
                            Button {
                                controller.openExplorer(for: relationship)
                            } label: {
                                relationshipCard(relationship)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.vertical, .SQSpace.l)
        }
        .navigationTitle("Insight Library")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text("Relationships")
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(.textPrimary)

                Text("Ranked patterns from your logged habits, workouts, recovery, and sleep.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Range", selection: $controller.selectedRange) {
                ForEach(SQInsightExplorerRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            Picker("Sort", selection: $controller.selectedSort) {
                ForEach(SQInsightLibrarySort.allCases) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var emptyState: some View {
        Text("Log more overlapping metrics to build your library.")
            .sqFont(.bodySmall)
            .sqForegroundColor(.textSecondary)
            .padding(.SQSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func relationshipCard(_ relationship: SQInsightExplorerRelationshipResult) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(alignment: .top, spacing: .SQSpace.s) {
                HStack(spacing: .SQSpace.s) {
                    SQDashboardTrendBadge(
                        text: relationship.confidence.badgeTitle,
                        tone: tone(for: relationship.effect),
                        symbol: nil
                    )

                    SQDashboardTrendBadge(
                        text: "\(relationship.matchedDays) days",
                        tone: .neutral,
                        symbol: nil
                    )
                }

                Spacer(minLength: 0)

                HStack(spacing: .SQSpace.s) {
                    Text(relationship.range.rawValue)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)

                    SQImageView(
                        image: .init(
                            symbol: .infoCircle,
                            symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                        )
                    )
                    .frame(width: 18, height: 18)
                }
            }

            HStack(spacing: .SQSpace.s) {
                relationshipCapsule(text: relationship.driverTitle, color: relationshipSourceColor(for: relationship.effect))

                SQImageView(
                    image: .init(
                        symbol: .arrowRight,
                        symbolStyle: .colorWithFont(accentColor(for: relationship.effect), font: .bodySmallSemiBold)
                    )
                )
                .frame(width: 18, height: 18)

                relationshipCapsule(text: relationship.outcomeTitle, color: relationshipOutcomeColor(for: relationship.effect))
            }

            Text(relationship.effectSummary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(for: relationship.effect))
        .contentShape(Rectangle())
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

    private func cardBackground(for effect: SQInsightEffect) -> some View {
        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
            .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.98))
            .overlay {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .stroke(accentColor(for: effect).color.opacity(SQColor.isDarkMode ? 0.36 : 0.24), lineWidth: 1)
            }
    }

    private func accentColor(for effect: SQInsightEffect) -> SQColor {
        switch effect {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    private func relationshipSourceColor(for effect: SQInsightEffect) -> SQColor {
        switch effect {
        case .positive, .neutral:
            return .dashboardGlowBlue
        case .negative:
            return .dashboardTrendWarm
        }
    }

    private func relationshipOutcomeColor(for effect: SQInsightEffect) -> SQColor {
        switch effect {
        case .positive:
            return .dashboardGlowMint
        case .negative, .neutral:
            return .dashboardGlowBlue
        }
    }

    private func tone(for effect: SQInsightEffect) -> SQDashboardTrendTone {
        switch effect {
        case .positive:
            return .positive
        case .negative:
            return .negative
        case .neutral:
            return .neutral
        }
    }
}
