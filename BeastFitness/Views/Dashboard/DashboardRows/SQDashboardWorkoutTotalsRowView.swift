//
//  SQDashboardWorkoutTotalsRowView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//

import SwiftUI

struct SQDashboardWorkoutTotalsRowView: View {
    @Bindable var viewModel: SQDashboardWorkoutTotalsRowViewModel
    
    var totalValuesAndTrendsStack: some View {
        HStack(alignment: .center, spacing: .SQSpace.m) {
            SQDashboardWorkoutStatView(attributedTitle: viewModel.currentValueAndTrend.value)
            Text(viewModel.currentValueAndTrend.trend)
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {

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
