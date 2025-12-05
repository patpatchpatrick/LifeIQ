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
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            SQDashboardView.cardTitle(title: "Daily Check-In")
                .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            
            if let callToActionViewModel = viewModel.callToAction {
                SQCallToAction(viewModel: callToActionViewModel)
                    .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            }
            
            if let icon = viewModel.dailyCheckInSummaryConfig?.icon {
                SQImageView(image: .init(symbol: icon, symbolStyle: .colorWithFont(.accent(1), font: .body)))
                    .frame(width: 20)
            }
            
            if let checkInStatsSummaryConfig = viewModel.dailyCheckInSummaryConfig{
                if let onTap = checkInStatsSummaryConfig.onTap {
                    Button(
                        action: {
                            onTap()
                        },
                        label: { checkInStatsSummaryView(for: checkInStatsSummaryConfig) })
                        .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
                } else {
                    checkInStatsSummaryView(for: checkInStatsSummaryConfig)
                        .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
                }
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
