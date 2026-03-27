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
                            ForEach(Array(section.visibleRows.enumerated()), id: \.offset) { offset, row in
                                switch row.rowType {
                                case .bodyBattery:
                                    if let vm = row as? SQDashboardBodyBatteryRowViewModel {
                                        SQDashboardBodyBatteryRowView(viewModel: vm)
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
            if let qt = statsViewModel.quantityType, let at = statsViewModel.activityType {
                SQLogger.shared.log(
                    "Displaying leaderboard for '\(statsViewModel.title)'",
                    .debug,
                    context: .dashboard
                )
                SQAppState.shared.dashboardState.displayLeaderboard(mode: .workoutQuantity(qt, at))
                return
            }

            let metricExists = SQMetricsManager.shared
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

private struct SQDashboardBodyBatteryRowView: View {
    @Bindable var viewModel: SQDashboardBodyBatteryRowViewModel

    private var accentColor: SQColor {
        switch viewModel.statusTone {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    private var statusSymbol: SQImageSymbol? {
        switch viewModel.statusTone {
        case .positive:
            return .arrowUp
        case .negative:
            return .arrowDown
        case .neutral:
            return nil
        }
    }

    private let driverColumns = [
        GridItem(.adaptive(minimum: 108), spacing: .SQSpace.s, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            HStack(alignment: .center, spacing: .SQSpace.xl) {
                SQBodyBatteryGauge(score: viewModel.score, accentColor: accentColor)

                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    SQDashboardTrendBadge(
                        text: viewModel.statusTitle,
                        tone: viewModel.statusTone,
                        symbol: statusSymbol
                    )

                    Text(viewModel.headline)
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)

                    Text(viewModel.summary)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: driverColumns, alignment: .leading, spacing: .SQSpace.s) {
                ForEach(viewModel.drivers) { driver in
                    SQBodyBatteryDriverCard(driver: driver)
                }
            }

            Text(viewModel.footer)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textDisabled)
        }
    }
}

private struct SQBodyBatteryGauge: View {
    let score: Int
    let accentColor: SQColor

    private let bodyWidth: CGFloat = 132
    private let bodyHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: .SQSpace.xs) {
            Capsule(style: .continuous)
                .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.55 : 0.32))
                .frame(width: 44, height: 8)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                    }

                GeometryReader { proxy in
                    let fillHeight = max(18, (proxy.size.height - 16) * CGFloat(score) / 100)

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.color.opacity(SQColor.isDarkMode ? 0.22 : 0.16),
                                    accentColor.color.opacity(SQColor.isDarkMode ? 0.86 : 0.58)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(SQColor.isDarkMode ? 0.18 : 0.30),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .frame(width: proxy.size.width - 18, height: fillHeight)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .allowsHitTesting(false)

                VStack(spacing: 2) {
                    Text("\(score)")
                        .sqFont(.title1)
                        .sqForegroundColor(.textPrimary)

                    Text("Current")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
                .padding(.horizontal, .SQSpace.m)
                .padding(.vertical, .SQSpace.s)
                .background {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.92 : 1))
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                        }
                }
            }
            .frame(width: bodyWidth, height: bodyHeight)
            .shadow(
                color: accentColor.color.opacity(SQColor.isDarkMode ? 0.18 : 0.10),
                radius: 18,
                x: 0,
                y: 10
            )
        }
    }
}

private struct SQBodyBatteryDriverCard: View {
    let driver: SQDashboardBodyBatteryRowViewModel.Driver

    private var accentColor: SQColor {
        switch driver.tone {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(driver.title.uppercased())
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            HStack(spacing: .SQSpace.xs) {
                if let symbol = driver.symbol {
                    SQImageView(
                        image: .init(
                            symbol: symbol,
                            symbolStyle: .colorWithFont(accentColor, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 10, height: 10)
                }

                Text(driver.valueText)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
            }

            Text(driver.detailText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.s)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.70 : 0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
        }
    }
}
