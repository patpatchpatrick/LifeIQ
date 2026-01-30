//
//  SQDashboardPerformanceRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import SwiftUI

struct SQDashboardPerformanceRow: View {
    @Bindable var viewModel: SQDashboardDailyPerformanceRowViewModel
    
    var title: some View {
        Button(action: { viewModel.toggleExpanded() }) {
            HStack {
                SQDashboardView.cardTitle(title: "Performance", icon: nil)
                Spacer()
                Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                    .sqForegroundColor(.textTertiary)
            }
        }
        .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
    }
    
    var mainStack: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            
            title
            
            if viewModel.isExpanded {
                SQMetricChipStrip(
                    chips: [
                    viewModel.metricChipModel],
                    onTap: { _ in
                        print("PTD Vo2 Max Tapped")
                    })
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    var body: some View {
        SQDashboardView.card { mainStack }
    }
}
