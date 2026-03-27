//
//  SQDashboardHeartSummaryRowView.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardHeartSummaryRowView: View {
    @Bindable var viewModel: SQDashboardHeartSummaryRowViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: .SQSpace.s, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: .SQSpace.s) {
            ForEach(viewModel.items) { item in
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(item.title.uppercased())
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(item.value)
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textPrimary)

                        if item.value != "--" {
                            Text(item.unit)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                        }
                    }

                    Text(item.detail)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, .SQSpace.m)
                .padding(.vertical, .SQSpace.s)
                .background {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.70 : 0.96))
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(SQColor.glassStroke.color, lineWidth: 1)
                        }
                }
            }
        }
    }
}
