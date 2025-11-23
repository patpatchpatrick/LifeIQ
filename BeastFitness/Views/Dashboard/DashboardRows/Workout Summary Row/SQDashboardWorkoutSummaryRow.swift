//
//  SQDashboardWorkoutSummaryRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryRow: View {
    @Bindable var viewModel: SQDashboardWorkoutSummaryRowViewModel
    
    var cardBody: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            SQDashboardWorkoutSummaryTotalsSection(viewModel: viewModel.totalsSection)
                .padding(.bottom, SQDashboardView.uiConfig.cardSectionSpacing)
            
            SQDashboardWorkoutSummaryWorkoutsSection(viewModel: viewModel.workoutsSection)
        }
    }
    
    var body: some View {
        Section(header:
                    SQDashboardView.sectionTitle(title: viewModel.sectionTitle)
        ) {
            SQDashboardView.card { cardBody }
                .padding(.bottom, .SQSpace.xxl)
        }
        .padding(.horizontal, SQDashboardView.uiConfig.sectionHorizPadding)
    }
}

#Preview {
    SQDashboardWorkoutSummaryRow(viewModel: .init(config: .mock, workouts: .mock, priorWorkouts: .mock))
        .preferredColorScheme(.dark)
}
