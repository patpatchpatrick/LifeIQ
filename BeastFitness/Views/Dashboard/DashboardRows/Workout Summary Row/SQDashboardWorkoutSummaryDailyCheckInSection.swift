//
//  SQDashboardWorkoutSummaryDailyCheckInSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryDailyCheckInRow: View {
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
            
            // Summary text
            if let summaryText = viewModel.summaryText {
                Text(summaryText)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(SQColor.textTertiary)
                    .padding(.bottom, .SQSpace.m)
            }
            
            // Vertical vitals list
            if let vitalRows = viewModel.vitalRows {
                LazyVStack(alignment: .leading, spacing: .SQSpace.s) {
                    ForEach(vitalRows) { row in
                        SQDailyCheckInVitalRow(model: row) {
                            print("PTD Vital Row Tapped:", row.title)
                        }
                        
                        // Divider between rows
                        if row.id != vitalRows.last?.id {
                            Divider()
                                .sqBackgroundColor(SQColor.border)
                                .padding(.vertical, .SQSpace.xs)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    var body: some View {
        SQDashboardView.card { mainStack }
    }
}
