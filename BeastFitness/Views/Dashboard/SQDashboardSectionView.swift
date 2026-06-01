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
                if let emptyState = section.emptyState {
                    SQSubsectionEmptyState(viewModel: emptyState)
                } else {
                    SQSubsectionEmptyState(message: "No data available")
                }
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
                            ForEach(section.visibleRows) { row in
                                switch row.rowType {
                                case .bodyBattery:
                                    if let vm = row as? SQDashboardBodyBatteryRowViewModel {
                                        SQDashboardBodyBatteryRowView(viewModel: vm)
                                    }

                                case .heartSummary:
                                    if let vm = row as? SQDashboardHeartSummaryRowViewModel {
                                        SQDashboardHeartSummaryRowView(viewModel: vm)
                                    }

                                case .insight:
                                    if let vm = row as? SQDashboardInsightRowViewModel {
                                        SQDashboardInsightRowView(viewModel: vm)
                                    }

                                case .insightExplorer:
                                    if let vm = row as? SQDashboardInsightExplorerRowViewModel {
                                        SQDashboardInsightExplorerRowView(viewModel: vm)
                                    }

                                case .insightChange:
                                    if let vm = row as? SQDashboardInsightChangeRowViewModel {
                                        SQDashboardInsightChangeRowView(viewModel: vm)
                                    }

                                case .insightAction:
                                    if let vm = row as? SQDashboardInsightActionRowViewModel {
                                        SQDashboardInsightActionRowView(viewModel: vm)
                                    }

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
                                                    percentileRank: vm.percentileRank,
                                                    leaderboardMode: vm.leaderboardMode,
                                                    isPremiumLocked: vm.isPremiumLocked,
                                                    premiumLockText: vm.premiumLockText,
                                                    scoreKind: vm.scoreKind,
                                                    trendDelta: vm.trendDelta
                                                )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                case .workoutTotals:
                                    if let vm = row as? SQDashboardWorkoutTotalsRowViewModel {
                                        SQDashboardWorkoutTotalsRowView(viewModel: vm)
                                    }

                                case .workoutPremiumInsights:
                                    if let vm = row as? SQDashboardWorkoutPremiumInsightRowViewModel {
                                        SQWorkoutPremiumInsightsView(
                                            model: vm.model,
                                            onScoreInfoTap: vm.onScoreInfoTap,
                                            onLockedTap: vm.onLockedTap
                                        )
                                    }

                                case .activityList:
                                    if let vm = row as? SQDashboardActivityRowViewModel {
                                        SQDashboardActivityListRowView(viewModel: vm)
                                    }

                                case .sleepScore:
                                    if let vm = row as? SQDashboardSleepScoreRowViewModel {
                                        SQDashboardSleepScoreRowView(viewModel: vm)
                                    }

                                case .sleepDuration:
                                    if let vm = row as? SQDashboardSleepDurationRowViewModel {
                                        SQDashboardSleepDurationRowView(viewModel: vm)
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
                                HStack(spacing: .SQSpace.s) {
                                    SQImageView(
                                        image: .init(
                                            symbol: .lockFill,
                                            symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodyExtraSmall)
                                        )
                                    )
                                    .frame(width: 12, height: 12)

                                    Text("Log in to unlock")
                                        .sqFont(.bodySmallSemiBold)
                                        .sqForegroundColor(.textPrimary)
                                }
                                .padding(.horizontal, .SQSpace.l)
                                .padding(.vertical, .SQSpace.m)
                                .background {
                                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                                        .fill(SQColor.sheetGradientMid.color.opacity(SQColor.isDarkMode ? 0.96 : 0.92))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                                                .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.28 : 0.58))
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                                                .stroke(SQColor.glassStrokeStrong.color.opacity(SQColor.isDarkMode ? 0.54 : 0.66), lineWidth: 1)
                                        }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .id("\(section.id)-\(section.activeFilter)")
                    .transition(.opacity)

                    if section.canToggleVisibleRows && !section.isLocked {
                        Button {
                            section.toggleShowingAllRows()
                        } label: {
                            HStack(spacing: .SQSpace.s) {
                                Text(section.seeMoreTitle)
                                    .sqFont(.bodySmallSemiBold)
                                    .sqForegroundColor(.textPrimary)

                                SQImageView(
                                    image: .init(
                                        symbol: section.isShowingAllRows ? .chevronUp : .chevronDown,
                                        symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                                    )
                                )
                                .frame(width: 10, height: 10)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, .SQSpace.xl)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func handleMetricRowTap(_ viewModel: SQDashboardRowViewModel) {
        if let statsViewModel = viewModel as? SQDashboardMetricStatsRowViewModel {
            if let onTap = statsViewModel.onTap {
                onTap()
                return
            }

            if let qt = statsViewModel.quantityType, let at = statsViewModel.activityType {
                SQLogger.shared.log(
                    "Displaying leaderboard for '\(statsViewModel.title)'",
                    .debug,
                    context: .dashboard
                )
                SQAppState.shared.dashboardState.displayLeaderboard(mode: .workoutQuantity(qt, at))
                return
            }

            let metricExists = SQMetricDefinitionManager.shared
                .allMetrics(includeArchived: true)
                .contains { $0.id == statsViewModel.metricId }

            guard metricExists else {
                SQLogger.shared.log(
                    "Cannot display metric detail: metric '\(statsViewModel.title)' was not found in the metric catalog",
                    .debug,
                    context: .dashboard
                )
                return
            }

            SQLogger.shared.log(
                "Displaying metric detail for '\(statsViewModel.title)'",
                .debug,
                context: .dashboard
            )
            SQAppState.shared.dashboardState.displayMetricDetail(metricId: statsViewModel.metricId)
            return
        }

        if let performanceViewModel = viewModel as? SQDashboardMetricPerformanceRowViewModel {
            if performanceViewModel.isPremiumLocked {
                SQSubscriptionManager.displaySubscriptionScreen(
                    source: "dashboard_performance_row",
                    feature: performanceViewModel.scoreKind?.rawValue ?? performanceViewModel.title.analyticsKey
                )
                return
            }

            guard let mode = performanceViewModel.leaderboardMode else {
                SQLogger.shared.log(
                    "Cannot display leaderboard: metric '\(performanceViewModel.title)' does not have a leaderboard mode",
                    .debug,
                    context: .dashboard
                )
                return
            }

            SQLogger.shared.log(
                "Displaying leaderboard for '\(performanceViewModel.title)'",
                .debug,
                context: .dashboard
            )
            SQAppState.shared.dashboardState.displayLeaderboard(mode: mode)
        }
    }
}
