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
                    Text(item.title)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)

                    Text(item.value)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.SQSpace.m)
                .sqBackgroundColor(.backgroundTertiaryLight)
                .cornerRadius(.SQCornerRadius.s)
            }
        }
    }
}
