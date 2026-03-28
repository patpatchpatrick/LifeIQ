//
//  SQWorkoutsListItem.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutsListItem: View {
    let viewModel: SQWorkoutsListItemViewModel

    var body: some View {
        HStack(spacing: .SQSpace.m) {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.16 : 0.12))
                .frame(width: 46, height: 46)
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }
                .overlay {
                    if let symbol = viewModel.workoutImageSymbol {
                        SQImageView(
                            image: .init(
                                symbol: symbol,
                                symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodySmallSemiBold)
                            )
                        )
                        .frame(width: 18, height: 18)
                    }
                }

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(viewModel.title)
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle = viewModel.subtitle {
                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: .SQSpace.m)

            Circle()
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                .frame(width: 30, height: 30)
                .overlay {
                    Circle()
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
                .overlay {
                    SQImageView(
                        image: .init(
                            symbol: .chevronRight,
                            symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 8, height: 10)
                }
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }
}
