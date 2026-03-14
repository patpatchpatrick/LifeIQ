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
            Circle()
                .sqForegroundColor(.backgroundSecondaryLight)
                .frame(width: 48, height: 48)

            if let emoji = viewModel.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 24))
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .sqForegroundColor(.textPrimary)
            }
        }
    }

    private var iconName: String {
        // Simple semantic mapping; easy to evolve later
        if viewModel.subtitle.lowercased().contains("scale") {
            return "slider.horizontal.3"
        } else if viewModel.subtitle.lowercased().contains("number") {
            return "number"
        } else if viewModel.subtitle.lowercased().contains("binary") {
            return "checkmark.circle"
        } else {
            return "circle.grid.2x2"
        }
    }

    // MARK: - Title + Subtitle

    @ViewBuilder
    var titleAndSubtitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.title)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)

            Text(viewModel.subtitle)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
    }

    // MARK: - Layout

    var body: some View {
        HStack(spacing: .SQSpace.l) {
            metricIcon

            titleAndSubtitle

            Spacer(minLength: .SQSpace.m)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.m)
        .background(SQColor.backgroundSheet.color)
        .contentShape(Rectangle())
    }
}
