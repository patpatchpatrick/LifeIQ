//
//  SQDashboardWorkoutSummaryRowTotalsSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryTotalsSection: View {
    @Bindable var viewModel: SQDashboardWorkoutSummaryTotalsSectionViewModel
    
    var totalValuesAndTrendsStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            ForEach(viewModel.totalValuesAndTrends) { valueAndTrend in
                HStack(alignment: .center, spacing: .SQSpace.m) {
                    SQDashboardWorkoutStatView(attributedTitle: valueAndTrend.value)
                    Text(valueAndTrend.trend)
                }
            }
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            SQDashboardView.cardTitle(title: viewModel.sectionTitle)
                .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            
            totalValuesAndTrendsStack
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
