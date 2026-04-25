//
//  SQDashboardInsightChangeRowView.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

struct SQDashboardInsightChangeRowView: View {
    let viewModel: SQDashboardInsightChangeRowViewModel

    private var accentColor: SQColor {
        switch viewModel.model.direction {
        case .improved:
            return .dashboardGlowMint
        case .worsened:
            return .colorErrorRed
        }
    }

    private var directionLabel: String {
        switch viewModel.model.direction {
        case .improved:
            return "Improved"
        case .worsened:
            return "Worsened"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .top, spacing: .SQSpace.s) {
                SQDashboardTrendBadge(
                    text: directionLabel,
                    tone: viewModel.model.direction == .improved ? .positive : .negative,
                    symbol: nil
                )

                Spacer(minLength: 0)

                Text(viewModel.model.deltaText)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(accentColor)
            }

            Text(viewModel.model.title)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)

            Text(viewModel.model.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(accentColor.color.opacity(SQColor.isDarkMode ? 0.34 : 0.22), lineWidth: 1)
                }
        }
    }
}
