//
//  SQDashboardSectionView.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-06.
//

import SwiftUI

/// A view that renders a dashboard subsection with optional filtering and collapsible content.
///
/// This view wraps `SQDashboardSubsection` to display a section title, optional dropdown filter,
/// and a list of rows. It handles empty states and delegates row rendering to appropriate
/// row view components based on row type.
struct SQDashboardSectionView: View {
    @Bindable var section: SQDashboardSubsectionViewModel

    var body: some View {
        SQDashboardSubsection(
            title: section.title,
            isCollapsed: $section.isCollapsed,
            dropdownMenu: section.dropDownViewModel.map { viewModel in
                SQDropDownMenu(menuViewModel: viewModel, isDisabled: false)
            }
        ) {
            if section.activeRows.isEmpty {
                SQSubsectionEmptyState(message: "No data available")
            } else {
                ForEach(Array(section.activeRows.enumerated()), id: \.offset) { offset, row in
                    // Dispatch to appropriate row view based on row type
                    if let metricRow = row as? SQDashboardMetricStatsRow {
                        // Metric stats, performance stats, totals stats, activity stats
                        SQStatRow(
                            data: SQStatRowData(
                                id: metricRow.id,
                                icon: metricRow.icon,
                                title: metricRow.title,
                                avgValue: metricRow.avgValue,
                                unit: metricRow.unit,
                                sparklineData: metricRow.sparklineData,
                                change14d: metricRow.change14d
                            )
                        )
                    } else {
                        // Fallback for other row types (workoutSummary, checkInSummary, etc.)
                        // These will be added in future iterations
                        EmptyView()
                    }
                }
            }
        }
    }
}
