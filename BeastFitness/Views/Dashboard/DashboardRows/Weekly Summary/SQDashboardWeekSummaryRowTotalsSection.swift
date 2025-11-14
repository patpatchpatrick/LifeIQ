//
//  SQDashboardWeekSummaryRowTotalsSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWeekSummaryRowTotalsSection: View {
    let viewModel: SQDashboardWeekSummaryTotalsSectionViewModel
    
    var totalValuesAndTrendsStack: some View {
        VStack(spacing: .SQSpace.m) {
            ForEach(viewModel.totalValuesAndTrends) { valueAndTrend in
                HStack(alignment: .bottom, spacing: .SQSpace.m) {
                    Text(valueAndTrend.value)
                    Text(valueAndTrend.trend)
                }
            }
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            
            SQDashboardView.cardTitle(title: viewModel.sectionTitle)
            
            totalValuesAndTrendsStack
        }
    }
    
    var body: some View {
        mainStack
    }
}

#Preview {
    SQDashboardWeekSummaryRowTotalsSection(viewModel: .init(workouts: [SQMockWorkout.mockRun, SQMockWorkout.mockRun]))
        .preferredColorScheme(.dark)
}
