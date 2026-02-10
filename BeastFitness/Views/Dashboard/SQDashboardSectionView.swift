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

    var mainBody: some View {
        SQDashboardSubsection(
            title: section.title,
            isCollapsed: $section.isCollapsed,
            dropdownMenu: section.dropDownViewModel.map { viewModel in
                SQDropDownMenu(menuViewModel: viewModel, isDisabled: false)
            },
            titleButton: section.titleButton
        ) {
            if section.activeRows.isEmpty {
                SQSubsectionEmptyState(message: "No data available")
            } else {
                VStack(spacing: SQDashboardView.uiConfig.sectionRowSpacing) {
                    ForEach(Array(section.activeRows.enumerated()), id: \.offset) { offset, row in
                        
                        switch row.rowType {
                        case .metricStats:
                            
                            if let metricStatsViewModel = row as? SQDashboardMetricStatsRowViewModel {
                                SQDashboardStatRow(data: .init(id: metricStatsViewModel.metricId, icon: metricStatsViewModel.icon, title: metricStatsViewModel.title, avgValue: metricStatsViewModel.avgValue, unit: metricStatsViewModel.unit, sparklineData: metricStatsViewModel.sparklineData, change14d: metricStatsViewModel.change14d))
                            }
                            
                        case .workoutTotals:
                            
                            if let workoutTotalsViewModel = row as? SQDashboardWorkoutTotalsRowViewModel {
                                SQDashboardWorkoutTotalsRowView(viewModel: workoutTotalsViewModel)
                            }
                            
                        case .activityList:
                            
                            if let activityListViewModel = row as? SQDashboardActivityRowViewModel {
                                SQDashboardActivityListRowView(viewModel: activityListViewModel)
                            }
                        }
                    }
                }
            }
        }

    }
    
    var body: some View {
        mainBody
    }
}
