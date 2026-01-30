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
        HStack(alignment: .center, spacing: .SQSpace.m) {
            SQDashboardWorkoutStatView(attributedTitle: viewModel.currentValueAndTrend.value)
            Text(viewModel.currentValueAndTrend.trend)
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack {
                SQDashboardView.cardTitle(title: viewModel.sectionTitle)
                Spacer()
                SQDropDownMenu(
                    menuViewModel: viewModel.metricDropdownViewModel,
                    isDisabled: false
                )
            }
            .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            
            // Activity bar chart
            if !viewModel.currentChartDataPoints.isEmpty {
                SQActivityBarChart(
                    dataPoints: viewModel.currentChartDataPoints.map { point in
                        SQActivityBarChart.DataPoint(
                            label: point.label,
                            value: point.value,
                            color: SQColor.accent(1).color
                        )
                    },
                    maxHeight: 60
                )
                .padding(.bottom, .SQSpace.xl)
            }
            
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
