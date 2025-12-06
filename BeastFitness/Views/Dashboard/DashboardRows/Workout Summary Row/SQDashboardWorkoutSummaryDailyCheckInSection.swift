//
//  SQDashboardWorkoutSummaryDailyCheckInSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryDailyCheckInSection: View {
    @Bindable var viewModel: SQDashboardWorkoutSummaryDailyCheckInSectionViewModel
    
    @ViewBuilder
    func checkInStatsSummaryView(for checkInStatsSummaryConfig:  SQDashboardWorkoutSummaryDailyCheckInSectionViewModel.DailyCheckInStatsSummaryConfig) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            
            Text(checkInStatsSummaryConfig.subtitle)
               .sqFont(.body)
               .foregroundColor(SQColor.textSecondary.color)
               .multilineTextAlignment(.leading)
        }
    }
    
    var dailyCheckInTitle: some View {
        SQDashboardView.cardTitle(title: "Daily Check-In", icon: viewModel.dailyCheckInSummaryConfig?.icon)
            .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            if let onTap = viewModel.dailyCheckInSummaryConfig?.onTap {
                Button(action: onTap, label: { dailyCheckInTitle })
            } else {
                dailyCheckInTitle
            }
            
            if let callToActionViewModel = viewModel.callToAction {
                SQCallToAction(viewModel: callToActionViewModel)
                    .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            }
            
            if let checkInStatsSummaryConfig = viewModel.dailyCheckInSummaryConfig{
                checkInStatsSummaryView(for: checkInStatsSummaryConfig)
                    .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            }
        }
    }
    
    var body: some View {
        mainStack
    }
}

#Preview {
    SQDashboardWorkoutSummaryTotalsSection(viewModel: .init(config: .mock, workouts: .mock, priorWorkouts: .mock))
        .preferredColorScheme(.dark)
}
