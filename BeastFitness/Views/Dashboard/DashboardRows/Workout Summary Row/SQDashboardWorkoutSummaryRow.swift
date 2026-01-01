//
//  SQDashboardWorkoutSummaryRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryRow: View {
    @Bindable var viewModel: SQDashboardWorkoutSummaryRowViewModel

    private var cardBody: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if let vm = viewModel.dailyCheckInSummarySectionViewModel {
                SQDashboardWorkoutSummaryDailyCheckInSection(viewModel: vm)
            }
            if let totals = viewModel.totalsSection {
                SQDashboardWorkoutSummaryTotalsSection(viewModel: totals)
                    .padding(.bottom, SQDashboardView.uiConfig.cardSectionSpacing)
            }
            if let workouts = viewModel.workoutsSection {
                SQDashboardWorkoutSummaryWorkoutsSection(viewModel: workouts)
            }
        }
    }

    var body: some View {
        SQDashboardView.card { cardBody }
    }
}


#Preview {
    SQDashboardWorkoutSummaryRow(viewModel: .init(rowId: .daily, config: .mock, workouts: .mock, priorWorkouts: .mock))
        .preferredColorScheme(.dark)
}
