//
//  SQDailyCheckInRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

import SwiftUI

struct SQDailyCheckInRow: View {
    @Bindable var viewModel: SQDailyCheckInRowViewModel

    @ViewBuilder
    private var numberBadge: some View {
        if !viewModel.number.isEmpty {
            Text(viewModel.number)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.85 : 1))
                )
                .overlay(
                    Circle()
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    var titleStack: some View {
        HStack(spacing: .SQSpace.s) {
            numberBadge

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(viewModel.title)
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let attributedSubtitle = viewModel.attributedSubtitle {
                    Text(attributedSubtitle)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let subtitle = viewModel.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let accentSubtitle = viewModel.accentSubtitle, !accentSubtitle.isEmpty {
                    Text(accentSubtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.dashboardGlowBlue)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if viewModel.isCompleted {
                ZStack {
                    Circle()
                        .fill(SQColor.dashboardGlowMint.color.opacity(0.16))

                    Circle()
                        .stroke(SQColor.dashboardGlowMint.color.opacity(0.45), lineWidth: 1)

                    SQImageView(
                        image: .init(
                            symbol: .checkmark,
                            symbolStyle: .colorWithFont(.textPrimary, font: .headerSmall)
                        )
                    )
                    .frame(width: 10, height: 10)
                }
                .frame(width: 22, height: 22)
            }
        }
    }
    
    @ViewBuilder
    var customInputField: some View {
        if let segmentedControlViewModel = viewModel as? SQDailyCheckInRowSegmentedControlViewModel {
            SQDailyCheckInSegmentedControl(viewModel: segmentedControlViewModel)
        }
        else if let textFieldViewModel = viewModel as? SQDailyCheckInTextEntryViewModel {
            SQTextField(viewModel: textFieldViewModel.textFieldViewModel)
        }
    }
    
    @ViewBuilder
    var vertStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            titleStack

            customInputField
        }
    }
    
    @ViewBuilder
    var borderedContainer: some View {
        vertStack
            .padding(.SQSpace.l)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl, showsShadow: false)
    }
    
    var body: some View {
        borderedContainer
    }
}
