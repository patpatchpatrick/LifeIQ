//
//  SQDashboardWorkoutSummaryDailyCheckInSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryDailyCheckInSection: View {
    @Bindable var viewModel: SQDashboardDailyCheckInRowViewModel
    
    var dailyCheckInTitle: some View {
        SQDashboardView.cardTitle(title: "Daily Check-In", icon: viewModel.canEditDailyStats ? .edit : nil)
            .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
    }
    
    var mainStack: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            
            if viewModel.canEditDailyStats {
                Button(
                    action: { Task { await viewModel.editDailyCheckInStats() } },
                    label: { dailyCheckInTitle })
            } else {
                dailyCheckInTitle
            }
            
            if let callToActionViewModel = viewModel.callToAction {
                SQCallToAction(viewModel: callToActionViewModel)
            }
            
            if let metricChips = viewModel.metricChips {
                SQMetricChipStrip(chips: metricChips, onTap: { chip in
                    print("PTD Chip Tapped", chip)
                })
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    var body: some View {
        SQDashboardView.card { mainStack }
    }
}

#Preview {
    SQDashboardWorkoutSummaryTotalsSection(viewModel: .init(config: .mock, workouts: .mock, priorWorkouts: .mock))
        .preferredColorScheme(.dark)
}
