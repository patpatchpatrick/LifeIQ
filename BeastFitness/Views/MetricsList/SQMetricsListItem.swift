//
//  SQMetricsListItem.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import SwiftUI

struct SQMetricsListItem: View {
    let viewModel: SQMetricsListItemViewModel

    // MARK: - Icon

    @ViewBuilder
    var metricIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.86 : 0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
                .frame(width: 44, height: 44)

            if let emoji = viewModel.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 21))
            } else {
                SQImageView(
                    image: .init(
                        symbol: iconSymbol,
                        symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)
                    )
                )
                .frame(width: 18, height: 18)
            }
        }
    }

    private var iconSymbol: SQImageSymbol {
        // Simple semantic mapping; easy to evolve later
        if viewModel.subtitle.lowercased().contains("scale") {
            return .sliderHorizontal3
        } else if viewModel.subtitle.lowercased().contains("number") {
            return .number
        } else if viewModel.subtitle.lowercased().contains("binary") {
            return .checkmarkCircle
        } else {
            return .circleGrid2x2
        }
    }

    // MARK: - Title + Subtitle

    @ViewBuilder
    var titleAndSubtitle: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(viewModel.title)
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            Text(viewModel.subtitle)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
        }
    }

    // MARK: - Layout

    var body: some View {
        HStack(spacing: .SQSpace.l) {
            metricIcon

            titleAndSubtitle

            Spacer(minLength: .SQSpace.m)

            SQImageView(
                image: .init(
                    symbol: .chevronRight,
                    symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                )
            )
            .frame(width: 8, height: 12)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.l)
        .contentShape(Rectangle())
    }
}
