//
//  SQDailyCheckInSegmentedControlRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

struct SQDailyCheckInSegmentedControl: View {
    @Bindable var viewModel: SQDailyCheckInRowSegmentedControlViewModel

    @ViewBuilder
    var circleRow: some View {
        HStack(spacing: .SQSpace.s) {
            ForEach(viewModel.segments) { segment in
                let isSelected = viewModel.selectedSegment?.id == segment.id
                Button {
                    viewModel.selectedSegment = isSelected ? nil : segment
                } label: {
                    Text(segment.title)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(isSelected ? .textPrimary : .textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .fill(
                                    isSelected
                                        ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.18 : 0.14)
                                        : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.95)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(
                                    isSelected
                                        ? SQColor.dashboardGlowBlue.color.opacity(0.42)
                                        : SQColor.glassStroke.color,
                                    lineWidth: 1
                                )
                        )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func scaleStack(scaleConfig: SQDailyCheckInRowSegmentedControlViewModel.ScaleConfig) -> some View {
        HStack {
            Text(scaleConfig.minText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            Spacer()

            Text(scaleConfig.maxText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
        }
        .opacity(0.72)
    }

    var body: some View {
        VStack(spacing: .SQSpace.s) {
            circleRow

            if let scaleConfig = viewModel.scaleConfig {
                scaleStack(scaleConfig: scaleConfig)
            }
        }
    }
}


//#Preview {
//    enum DailyCheckInSegment: String, CaseIterable, Hashable {
//        case terrible = "😡"
//        case bad      = "😕"
//        case okay     = "3"
//        case good     = "4"
//        case great    = "5"
//    }
//
//    // Map enum → SQSegmentedControlSegment
//    let segments: [SQSegmentedControlSegment] = DailyCheckInSegment.allCases.map {
//        SQSegmentedControlSegment(
//            id: $0.rawValue,
//            title: $0.rawValue   // or a nicer label if you want
//        )
//    }
//
//    let viewModel = SQDailyCheckInRowSegmentedControlViewModel(
//        title: "Mood",
//        number: "1",
//        scaleConfig: .init(minText: "Very low", maxText: "Very high"),
//        segments: segments
//    )
//
//    return SQDailyCheckInRow(viewModel: viewModel)
//        .padding()
//        .preferredColorScheme(.dark)
//}
