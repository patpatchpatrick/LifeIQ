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

    var body: some View {
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
                VStack(spacing: 0) {
                    // Render column headers if provided, outside the rows VStack
                    // so rowSpacing only applies between data rows
                    if let columnHeaders = section.columnHeaders {
                        SQColumnHeaderRow(
                            columns: columnHeaders.enumerated().map { index, title in
                                index == 0 ? .leading(title) : .trailing(title)
                            }
                        )
                        .padding(.bottom, .SQSpace.l)
                    }

                    ZStack(alignment: .center) {
                        VStack(spacing: section.rowSpacing ?? SQDashboardView.uiConfig.sectionRowSpacing) {
                            ForEach(Array(section.activeRows.enumerated()), id: \.offset) { offset, row in
                                switch row.rowType {
                                case .metricStats:
                                    if let vm = row as? SQDashboardMetricStatsRowViewModel {
                                        Button(action: { handleMetricRowTap(vm) }) {
                                            SQDashboardStatRow(data: .init(id: vm.metricId, icon: vm.icon, title: vm.title, avgValue: vm.avgValue, unit: vm.unit, sparklineData: vm.sparklineData, changePercent: vm.changePercent))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                case .metricPerformance:
                                    if let vm = row as? SQDashboardMetricPerformanceRowViewModel {
                                        Button(action: { handleMetricRowTap(vm) }) {
                                            SQDashboardPerformanceRow(
                                                data: .init(
                                                    id: vm.metricId,
                                                    icon: vm.icon,
                                                    title: vm.title,
                                                    bestValue: vm.bestValue,
                                                    unit: vm.unit,
                                                    percentileRank: vm.percentileRank
                                                )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                case .workoutTotals:
                                    if let vm = row as? SQDashboardWorkoutTotalsRowViewModel {
                                        SQDashboardWorkoutTotalsRowView(viewModel: vm)
                                    }

                                case .activityList:
                                    if let vm = row as? SQDashboardActivityRowViewModel {
                                        SQDashboardActivityListRowView(viewModel: vm)
                                    }

                                case .sleepScore:
                                    if let vm = row as? SQDashboardSleepScoreRowViewModel {
                                        SQDashboardSleepScoreRowView(viewModel: vm)
                                    }

                                case .sleepPhaseTimeline:
                                    if let vm = row as? SQDashboardSleepPhaseTimelineRowViewModel {
                                        SQDashboardSleepPhaseTimelineRowView(viewModel: vm)
                                    }

                                case .sleepSummary:
                                    if let vm = row as? SQDashboardSleepSummaryRowViewModel {
                                        SQDashboardSleepSummaryRowView(viewModel: vm)
                                    }
                                }
                            }
                        }
                        .blur(radius: section.isLocked ? 6 : 0)

                        if section.isLocked {
                            Button(action: { section.onLockedTap?() }) {
                                Text("Log in to unlock your stats")
                                    .sqFont(.body)
                                    .foregroundStyle(SQColor.textPrimary.color)
                                    .padding(.horizontal, .SQSpace.xl)
                                    .padding(.vertical, .SQSpace.m)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .id(section.activeFilter)
                    .transition(.opacity)
                }
            }
        }
    }

    private func handleMetricRowTap(_ viewModel: SQDashboardRowViewModel) {
        let mode: SQLeaderboardMode?
        let title: String

        if let statsViewModel = viewModel as? SQDashboardMetricStatsRowViewModel {
            // Stats rows carry separate quantityType/activityType — construct mode inline
            if let qt = statsViewModel.quantityType, let at = statsViewModel.activityType {
                mode = .workoutQuantity(qt, at)
            } else {
                mode = nil
            }
            title = statsViewModel.title
        } else if let performanceViewModel = viewModel as? SQDashboardMetricPerformanceRowViewModel {
            mode = performanceViewModel.leaderboardMode
            title = performanceViewModel.title
        } else {
            return
        }

        guard let mode else {
            SQLogger.shared.log(
                "Cannot display leaderboard: metric '\(title)' does not have a leaderboard mode",
                .debug,
                context: .dashboard
            )
            return
        }

        SQLogger.shared.log(
            "Displaying leaderboard for '\(title)'",
            .debug,
            context: .dashboard
        )

        SQAppState.shared.dashboardState.displayLeaderboard(mode: mode)
    }
}
