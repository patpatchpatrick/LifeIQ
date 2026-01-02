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
                .frame(width: 40)

            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .sqForegroundColor(.textPrimary)
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
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text(viewModel.title)
                .sqFont(.bodyBold)
                .sqForegroundColor(.textPrimary)

            Text(viewModel.subtitle)
                .sqFont(.body)
                .sqForegroundColor(.textSecondary)
        }
    }

    // MARK: - Trailing Accessory

    @ViewBuilder
    var trailingAccessory: some View {
        if viewModel.isTracked {
            Text("Tracked")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .padding(.horizontal, .SQSpace.m)
                .padding(.vertical, .SQSpace.s)
                .background(
                    Capsule()
                        .fill(SQColor.textPrimary.color.opacity(0.10))
                )
        } else {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .sqForegroundColor(.textSecondary)
        }
    }

    // MARK: - Layout

    var mainHStack: some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            metricIcon

            titleAndSubtitle

            Spacer()

            trailingAccessory
        }
    }

    var body: some View {
        mainHStack
            .background(SQColor.background.color)
            .contentShape(Rectangle())
    }
}
