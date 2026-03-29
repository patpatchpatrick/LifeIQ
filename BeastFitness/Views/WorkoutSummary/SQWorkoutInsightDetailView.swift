//
//  SQWorkoutInsightDetailView.swift
//  BeastFitness
//

import SwiftUI

struct SQWorkoutInsightDetailView: View {
    @State var controller: SQWorkoutInsightDetailController

    private let scoreColumns = [
        GridItem(.adaptive(minimum: 150), spacing: .SQSpace.s, alignment: .leading)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.l) {
                heroCard

                if !controller.model.scoreCards.isEmpty {
                    scoreCardsSection
                }

                if !controller.model.components.isEmpty {
                    componentsSection
                }

                if !controller.model.examples.isEmpty {
                    examplesSection
                }

                if let footnote = controller.model.footnote {
                    footnoteCard(footnote)
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.model.title)
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            SQDashboardTrendBadge(
                text: "How It Works",
                tone: .neutral,
                symbol: nil
            )

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(controller.model.title)
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)

                Text(controller.model.subtitle)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(controller.model.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var scoreCardsSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Key Scores")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            LazyVGrid(columns: scoreColumns, alignment: .leading, spacing: .SQSpace.s) {
                ForEach(controller.model.scoreCards) { card in
                    detailScoreCard(card)
                }
            }
        }
    }

    private func detailScoreCard(_ card: SQWorkoutPremiumInsightDetailModel.ScoreCard) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(card.title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            Text(card.value)
                .sqFont(.title2)
                .sqForegroundColor(.textPrimary)

            Text(card.caption)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.m)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.78 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(card.accentColor.color.opacity(SQColor.isDarkMode ? 0.42 : 0.24), lineWidth: 1)
                }
        }
    }

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Breakdown")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(spacing: .SQSpace.s) {
                ForEach(controller.model.components) { component in
                    componentRow(component)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func componentRow(_ component: SQWorkoutPremiumInsightDetailModel.Component) -> some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            RoundedRectangle(cornerRadius: .SQCornerRadius.s, style: .continuous)
                .fill(component.accentColor.color.opacity(0.8))
                .frame(width: 6)

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                    Text(component.title)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)

                    Spacer(minLength: 0)

                    Text(component.value)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)
                }

                Text(component.detail)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .SQSpace.xs)
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Real-World Anchors")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(spacing: .SQSpace.s) {
                ForEach(controller.model.examples) { example in
                    exampleRow(example)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func exampleRow(_ example: SQWorkoutPremiumInsightDetailModel.Example) -> some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            Text(example.range)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.dashboardGlowBlue)
                .frame(width: 68, alignment: .leading)

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(example.title)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Text(example.detail)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .SQSpace.xs)
    }

    private func footnoteCard(_ footnote: String) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text("Note")
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            Text(footnote)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }
}
