//
//  SQDashboardSectionView.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-06.
//

import SwiftUI
import BeastFitnessCore

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
                    // Render column headers if provided
                    if let columnHeaders = section.columnHeaders {
                        SQColumnHeaderRow(
                            columns: columnHeaders.enumerated().map { index, title in
                                index == 0 ? .leading(title) : .trailing(title)
                            }
                        )
                    }

                    ForEach(Array(section.activeRows.enumerated()), id: \.offset) { offset, row in
                        
                        switch row.rowType {
                        case .metricStats:

                            if let metricStatsViewModel = row as? SQDashboardMetricStatsRowViewModel {
                                Button(action: {
                                    handleMetricRowTap(metricStatsViewModel)
                                }) {
                                    SQDashboardStatRow(data: .init(id: metricStatsViewModel.metricId, icon: metricStatsViewModel.icon, title: metricStatsViewModel.title, avgValue: metricStatsViewModel.avgValue, unit: metricStatsViewModel.unit, sparklineData: metricStatsViewModel.sparklineData, change14d: metricStatsViewModel.change14d))
                                }
                                .buttonStyle(.plain)
                            }

                        case .metricPerformance:
                            if let performanceViewModel = row as? SQDashboardMetricPerformanceRowViewModel {
                                Button(action: {
                                    handleMetricRowTap(performanceViewModel)
                                }) {
                                    SQDashboardPerformanceRow(
                                        data: .init(
                                            id: performanceViewModel.metricId,
                                            icon: performanceViewModel.icon,
                                            title: performanceViewModel.title,
                                            bestValue: performanceViewModel.bestValue,
                                            unit: performanceViewModel.unit,
                                            percentileRank: performanceViewModel.percentileRank
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
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

    private func handleMetricRowTap(_ viewModel: SQDashboardRowViewModel) {
        // Try to extract quantityType and activityType
        let quantityType: SQQuantityType?
        let activityType: HKWorkoutActivityType?
        let title: String

        if let statsViewModel = viewModel as? SQDashboardMetricStatsRowViewModel {
            quantityType = statsViewModel.quantityType
            activityType = statsViewModel.activityType
            title = statsViewModel.title
        } else if let performanceViewModel = viewModel as? SQDashboardMetricPerformanceRowViewModel {
            quantityType = performanceViewModel.quantityType
            activityType = performanceViewModel.activityType
            title = performanceViewModel.title
        } else {
            return
        }

        // Only performance metrics have quantityType and activityType
        guard let quantityType = quantityType,
              let activityType = activityType else {
            SQLogger.shared.log(
                "Cannot display leaderboard: metric '\(title)' does not have quantityType and activityType",
                .debug,
                context: .dashboard
            )
            return
        }

        SQLogger.shared.log(
            "Displaying leaderboard for \(quantityType.displayTitle) - \(activityType.name)",
            .debug,
            context: .dashboard
        )

        // Display leaderboard sheet
        SQAppState.shared.dashboardState.displayLeaderboardSheet(
            quantityType: quantityType,
            activityType: activityType
        )
    }
}
