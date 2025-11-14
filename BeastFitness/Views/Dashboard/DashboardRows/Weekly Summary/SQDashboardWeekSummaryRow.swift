//
//  SQDashboardWeekSummaryRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWeekSummaryRow: View {
    @Bindable var viewModel: SQDashboardWeekSummaryRowViewModel
    
    var cardBody: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            SQDashboardWeekSummaryTotalsSection(viewModel: viewModel.totalsSection)
                .padding(.bottom, SQDashboardView.uiConfig.cardSectionSpacing)
            
            SQDashboardWeekSummaryWorkoutsSection(viewModel: viewModel.workoutsSection)
        }
    }
    
    var body: some View {
        Section(header:
                    SQDashboardView.sectionTitle(title: viewModel.sectionTitle)
        ) {
            SQDashboardView.card { cardBody }
        }
        .padding(.horizontal, SQDashboardView.uiConfig.sectionHorizPadding)
    }
}

#Preview {
    SQDashboardWeekSummaryRow(viewModel: .init(workouts: .mock, priorWeekWorkouts: .mock))
        .preferredColorScheme(.dark)
}
