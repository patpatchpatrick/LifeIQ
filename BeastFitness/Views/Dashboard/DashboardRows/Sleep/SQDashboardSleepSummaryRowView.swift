//
//  SQDashboardSleepSummaryRowView.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardSleepSummaryRowView: View {
    @Bindable var viewModel: SQDashboardSleepSummaryRowViewModel

    var body: some View {
        HStack(alignment: .top, spacing: .SQSpace.s) {
            ForEach(viewModel.items) { item in
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(item.title.uppercased())
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textSecondary)

                    Text(item.value)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .SQSpace.m)
                .padding(.horizontal, .SQSpace.m)
                .background(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.65 : 0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
            }
        }
    }
}
