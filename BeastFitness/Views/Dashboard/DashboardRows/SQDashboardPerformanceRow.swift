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
        SQCollapsibleSectionHeader(
            title: "Performance",
            isExpanded: viewModel.isExpanded,
            action: { viewModel.toggleExpanded() }
        )
    }

    var mainStack: some View {
        LazyVStack(alignment: .leading, spacing: 0) {

            title

            if viewModel.isExpanded {
                if let vitalRow = viewModel.vitalRow {
                    SQDailyCheckInVitalRow(model: vitalRow) {
                        print("PTD VO2 Max Tapped")
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
