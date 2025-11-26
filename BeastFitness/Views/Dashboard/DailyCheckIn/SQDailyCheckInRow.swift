//
//  SQDailyCheckInRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

import SwiftUI

struct SQDailyCheckInRow: View {
    @Bindable var viewModel: SQDailyCheckInRowViewModel
    
    let circleBadgeHeight: CGFloat = 25
    
    @ViewBuilder
    var titleStack: some View {
        HStack(spacing: .SQSpace.s) {
            Circle()
                .sqForegroundColor(.colorErrorRed)
                .frame(width: circleBadgeHeight, height: circleBadgeHeight)
                .overlay {
                    Text(viewModel.number)
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)
                }
         
            Text(viewModel.title)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)
            
            Spacer()
            
            if viewModel.isCompleted {
                Circle()
                    .sqForegroundColor(.colorGreenDarkBorder)
                    .frame(width: circleBadgeHeight, height: circleBadgeHeight)
                    .overlay {
                        SQImageView(
                            image: .init(
                                symbol: .checkmark,
                                symbolStyle: .colorWithFont(.textPrimary, font: .bodyBold)
                            )
                        )
                        .frame(width: 12)
                    }
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
            .sqBackgroundColor(
                .colorGreenPct(percent: 1, base: .background),
                opacity: viewModel.isCompleted ? 0.1 : 0
            )
            .cornerRadius(.SQCornerRadius.l)
            .sqBorder(
                viewModel.isCompleted ? .colorGreenDarkBorder : .backgroundSecondaryLight,
                width: 1,
                cornerRadius: .SQCornerRadius.l
            )
    }
    
    var body: some View {
        borderedContainer
    }
}
