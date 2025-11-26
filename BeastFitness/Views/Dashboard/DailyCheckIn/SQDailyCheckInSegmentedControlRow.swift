//
//  SQDailyCheckInSegmentedControlRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

struct SQDailyCheckInSegmentedControlRow: View {
    @Bindable var viewModel: SQDailyCheckInRowSegmentedControlViewModel
    
    let circleBadgeHeight: CGFloat = 25
    
    @ViewBuilder
    var segmentedControl: some View {
        SQSegmentedControl(
            segments: viewModel.segments,
            selection: $viewModel.selectedSegment
        ) { segment in
            Text(segment.title)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)
        }
    }
    
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
    func scaleStack(scaleConfig: SQDailyCheckInRowSegmentedControlViewModel.ScaleConfig) -> some View {
        HStack(spacing: 0) {
            Text(scaleConfig.minText)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
            
            Spacer()
                .frame(height: 1)
                .sqBackgroundColor(.textSecondary)
                .opacity(0.5)
                .padding(.horizontal, .SQSpace.l)
            
            Text(scaleConfig.maxText)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    var vertStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            titleStack
            
            segmentedControl
            
            if let scaleConfig = viewModel.scaleConfig {
                scaleStack(scaleConfig: scaleConfig)
            }
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
            .cornerRadius(12)
            .sqBorder(
                viewModel.isCompleted ? .colorGreenDarkBorder : .backgroundSecondaryLight,
                width: 1,
                cornerRadius: 12
            )
    }
    
    var body: some View {
        borderedContainer
    }
}


#Preview {
    enum DailyCheckInSegment: String, CaseIterable, Hashable {
        case terrible = "😡"
        case bad      = "😕"
        case okay     = "3"
        case good     = "4"
        case great    = "5"
    }

    // Map enum → SQSegmentedControlSegment
    let segments: [SQSegmentedControlSegment] = DailyCheckInSegment.allCases.map {
        SQSegmentedControlSegment(
            id: $0.rawValue,
            title: $0.rawValue   // or a nicer label if you want
        )
    }

    let viewModel = SQDailyCheckInRowSegmentedControlViewModel(
        title: "Mood",
        number: "1",
        scaleConfig: .init(minText: "Very low", maxText: "Very high"),
        segments: segments
    )

    return SQDailyCheckInSegmentedControlRow(viewModel: viewModel)
        .padding()
        .preferredColorScheme(.dark)
}

