//
//  SQDashboardInsightActionRowView.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

struct SQDashboardInsightActionRowView: View {
    let viewModel: SQDashboardInsightActionRowViewModel

    private var accentColor: SQColor {
        switch viewModel.model.tone {
        case .maintain:
            return .dashboardGlowMint
        case .improve:
            return .dashboardGlowBlue
        case .caution:
            return .dashboardTrendWarm
        }
    }

    private var badgeTone: SQDashboardTrendTone {
        switch viewModel.model.tone {
        case .maintain:
            return .positive
        case .improve, .caution:
            return .neutral
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                SQDashboardTrendBadge(
                    text: viewModel.model.title,
                    tone: badgeTone,
                    symbol: nil
                )

                Spacer(minLength: 0)
            }

            Text(viewModel.model.summary)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let context = viewModel.model.context {
                Text(context)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.m)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.96))
        }
    }
}
