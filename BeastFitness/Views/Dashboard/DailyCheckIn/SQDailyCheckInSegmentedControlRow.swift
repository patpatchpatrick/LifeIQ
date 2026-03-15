//
//  SQDailyCheckInSegmentedControlRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

struct SQDailyCheckInSegmentedControl: View {
    @Bindable var viewModel: SQDailyCheckInRowSegmentedControlViewModel

    private let circleSize: CGFloat = 26

    @ViewBuilder
    var circleRow: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.segments) { segment in
                let isSelected = viewModel.selectedSegment?.id == segment.id
                Button {
                    viewModel.selectedSegment = segment
                } label: {
                    Group {
                        if isSelected {
                            Text(segment.title)
                                .sqFont(.bodySemiBold)
                                .sqForegroundColor(.colorGreenPct(percent: 1.0))
                        } else {
                            Circle()
                                .strokeBorder(SQColor.textPrimary.color.opacity(0.4), lineWidth: 1.5)
                                .frame(width: circleSize, height: circleSize)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
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
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)

            Spacer()

            Text(scaleConfig.maxText)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
        .opacity(0.6)
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

