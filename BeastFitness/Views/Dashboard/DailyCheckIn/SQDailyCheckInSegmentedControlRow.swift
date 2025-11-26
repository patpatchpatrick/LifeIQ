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
    var fullSegmentedControlView: some View {
        VStack(spacing: .SQSpace.l) {
            segmentedControl
            
            if let scaleConfig = viewModel.scaleConfig {
                scaleStack(scaleConfig: scaleConfig)
            }
        }
    }
    
    var body: some View {
        fullSegmentedControlView
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

