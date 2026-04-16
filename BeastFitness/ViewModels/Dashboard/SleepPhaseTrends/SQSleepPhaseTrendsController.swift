//
//  SQSleepPhaseTrendsController.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts
import BeastFitnessCore

@MainActor
protocol SQSleepPhaseTrendsInterface {
    func loadUI() async
}

struct SQSleepPhaseTrendRowViewModel: Identifiable {
    let id: String
    let phase: SQSleepPhase
    let title: String
    let color: Color
    let averageText: String
    let deltaText: String
    let deltaColor: Color
    let detailText: String
}

@Observable @MainActor
final class SQSleepPhaseTrendsController: SQSleepPhaseTrendsInterface {
    let id = UUID().uuidString
    private(set) var containerWidth: CGFloat = 0
    var chartWidth: CGFloat {
        max(0, containerWidth - (.SQSpace.l * 4))
    }
    let chartHeight: CGFloat = 300
    private(set) var hasLoadedUI = false
    private(set) var isLoading = false
    private(set) var selectedTimeRange: AppTimeRange
    private(set) var chartModel: MultiLineChartModel?
    private(set) var trendRows: [SQSleepPhaseTrendRowViewModel] = []
    private(set) var emptyMessage: String?
    private(set) var focusedPhase: SQSleepPhase?
    let timeRangeMenuViewModel: SQDropDownMenuViewModel

    private let initialFocusedPhase: SQSleepPhase?
    private let healthKitManager: SQHealthKitManaging
    private let sleepAggregationService: SQSleepAggregationService
    private let userState: SQUserStating
    private var chartSeries: [MultiLineChartSeries] = []
    private var focusPointIDByPhase: [SQSleepPhase: String] = [:]

    var title: String {
        "Sleep Phase Trends"
    }

    var chartTitle: String {
        "Sleep phases over time"
    }

    var chartSubtitle: String {
        "Completed nights • \(selectedTimeRange.rawValue)"
    }

    init(
        initialTimeRange: AppTimeRange,
        focusedPhase: SQSleepPhase? = nil,
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        sleepAggregationService: SQSleepAggregationService = SQSleepAggregationService(),
        userState: SQUserStating = SQAppState.shared.userState
    ) {
        let resolvedInitialRange = initialTimeRange == .today ? AppTimeRange.pastSevenDays : initialTimeRange
        self.selectedTimeRange = resolvedInitialRange
        self.initialFocusedPhase = focusedPhase
        self.focusedPhase = focusedPhase
        self.healthKitManager = healthKitManager
        self.sleepAggregationService = sleepAggregationService
        self.userState = userState

        let items = AppTimeRange.allCases
            .filter { $0 != .today }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }

        self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: resolvedInitialRange.rawValue),
            items: items,
            itemSelectionHandler: { _ in }
        )

        self.timeRangeMenuViewModel.itemSelectionHandler = { [weak self] selectedTitle in
            guard let self,
                  let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }),
                  selectedRange != .today else {
                return
            }

            self.selectedTimeRange = selectedRange
            Task { @MainActor in
                await self.reloadUI()
            }
        }
    }

    func loadUI() async {
        guard !hasLoadedUI else { return }
        hasLoadedUI = true
        await loadSelectedRange()
    }

    func updateLayout(containerWidth: CGFloat) {
        let rounded = (containerWidth * 2).rounded() / 2
        guard abs(self.containerWidth - rounded) > 0.5 else { return }
        self.containerWidth = rounded
        rebuildChartModelForCurrentState()
    }

    private func reloadUI() async {
        await loadSelectedRange()
    }

    private func loadSelectedRange() async {
        isLoading = true
        emptyMessage = nil

        do {
            guard let data = try await buildSleepDashboardData(for: selectedTimeRange) else {
                chartSeries = []
                trendRows = []
                chartModel = nil
                emptyMessage = "Track a few nights of sleep to see phase trends."
                isLoading = false
                return
            }

            chartSeries = buildChartSeries(from: data)
            trendRows = buildTrendRows(from: data)
            rebuildChartModelForCurrentState()

            if chartSeries.isEmpty {
                emptyMessage = "Track at least two completed nights to see phase trends."
            }
        } catch {
            SQLogger.shared.log(
                "Failed to load sleep phase trends: \(error.localizedDescription)",
                .error,
                context: .dashboard
            )
            chartSeries = []
            trendRows = []
            chartModel = nil
            emptyMessage = "Sleep phase trends are unavailable right now."
        }

        isLoading = false
    }

    private func buildSleepDashboardData(for timeRange: AppTimeRange) async throws -> SQSleepDashboardData? {
        let sleepSchedule = userState.loggedInUser?.sleepSchedule
        let window = sleepAggregationService.makeDashboardWindow(
            for: timeRange,
            sleepSchedule: sleepSchedule
        )
        let sleepSegments = try await healthKitManager.fetchSleepSegments(
            from: window.fetchStartDate,
            to: window.fetchEndDate
        )
        let dashboardData = sleepAggregationService.buildDashboardData(
            segments: sleepSegments,
            window: window,
            sleepSchedule: sleepSchedule
        )

        return dashboardData.currentNights.isEmpty ? nil : dashboardData
    }

    private func buildChartSeries(from data: SQSleepDashboardData) -> [MultiLineChartSeries] {
        let nights = data.currentNights.sorted { $0.wakeDay < $1.wakeDay }
        guard nights.count >= 2 else { return [] }

        focusPointIDByPhase = [:]

        return phaseOrder.map { phase in
            let points = nights.map { night in
                LineChartIdentifiablePoint(
                    id: night.id,
                    point: CGPoint(
                        x: night.wakeDay.timeIntervalSince1970,
                        y: night.phaseDuration(for: phase) / 3600.0
                    )
                )
            }

            focusPointIDByPhase[phase] = nights.last?.id

            return MultiLineChartSeries(
                id: phase.rawValue,
                title: phase.title,
                color: color(for: phase),
                inputPoints: points
            )
        }
    }

    private func buildTrendRows(from data: SQSleepDashboardData) -> [SQSleepPhaseTrendRowViewModel] {
        phaseOrder.compactMap { phase in
            guard let aggregate = data.phaseAggregates.first(where: { $0.phase == phase }) else { return nil }
            let delta = aggregate.priorAverageDuration.map { aggregate.averageDuration - $0 }

            return SQSleepPhaseTrendRowViewModel(
                id: phase.rawValue,
                phase: phase,
                title: phase.title,
                color: color(for: phase),
                averageText: formattedDuration(aggregate.averageDuration),
                deltaText: formattedDelta(delta),
                deltaColor: deltaColor(for: delta, phase: phase),
                detailText: "Avg over \(selectedTimeRange.rawValue)"
            )
        }
    }

    private func rebuildChartModelForCurrentState() {
        guard chartWidth > 0, !chartSeries.isEmpty else {
            chartModel = nil
            return
        }

        chartModel = MultiLineChartModel(
            width: chartWidth,
            height: chartHeight,
            series: chartSeries,
            uiConfig: buildChartUIConfig(),
            gridConfig: buildGridConfig(),
            focusConfig: buildFocusConfig()
        )

        focusInitialPointIfNeeded()
    }

    private func focusInitialPointIfNeeded() {
        let phaseToFocus = focusedPhase ?? initialFocusedPhase ?? .rem
        guard let pointID = focusPointIDByPhase[phaseToFocus] else { return }
        chartModel?.focusCoordinateWith(seriesID: phaseToFocus.rawValue, pointID: pointID)
    }

    private func buildChartUIConfig() -> LineChartModel.UIConfig {
        let colorConfig = LineChartModel.ColorConfig(
            textPrimary: SQColor.textPrimary.color,
            textSecondary: SQColor.textSecondary.color,
            backgroundPrimary: SQColor.glassCardTint.color,
            backgroundSecondary: SQColor.glassPopoverTint.color,
            lineColor: SQColor.dashboardGlowBlue.color,
            trendLineColor: nil
        )
        let fontConfig = LineChartModel.FontConfig(
            font: SQFont(type: .bodyExtraSmall).font,
            boldFont: SQFont(type: .bodySmallBold).font
        )
        return LineChartModel.UIConfig(colorConfig: colorConfig, fontConfig: fontConfig)
    }

    private func buildGridConfig() -> GridConfig {
        GridConfig(
            lineColor: SQColor.glassStroke.color.opacity(SQColor.isDarkMode ? 0.9 : 0.55)
        )
    }

    private func buildFocusConfig() -> MultiLineChartFocusConfig {
        let xLabelBuilder: @Sendable (String, CGFloat) -> String = { _, xValue in
            let date = Date(timeIntervalSince1970: TimeInterval(xValue))
            return date.formattedString(with: .medium)
        }

        let yLabelBuilder: @Sendable (String, String, CGFloat) -> String = { _, _, yValue in
            Self.formatDuration(yValue * 3600.0)
        }

        let onFocus: @Sendable (MultiLineChartFocusedPoint) -> Void = { [weak self] point in
            guard let self else { return }
            Task { @MainActor in
                self.focusedPhase = SQSleepPhase(rawValue: point.seriesID)
            }
        }

        return MultiLineChartFocusConfig(
            focusColor: SQColor.dashboardGlowBlue.color,
            xLabelBuilder: xLabelBuilder,
            yLabelBuilder: yLabelBuilder,
            onFocus: onFocus
        )
    }

    private var phaseOrder: [SQSleepPhase] {
        [.rem, .deep, .core, .awake]
    }

    private func color(for phase: SQSleepPhase) -> Color {
        switch phase {
        case .awake:
            return SQColor.dashboardTrendWarm.color
        case .rem:
            return SQColor.dashboardGlowBlue.color
        case .core:
            return Color.white.opacity(SQColor.isDarkMode ? 0.88 : 0.72)
        case .deep:
            return SQColor.dashboardGlowMint.color
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        Self.formatDuration(duration)
    }

    nonisolated private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60.0).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func formattedDelta(_ delta: TimeInterval?) -> String {
        guard let delta else { return "No prior data" }
        let totalMinutes = Int((delta / 60.0).rounded())
        guard totalMinutes != 0 else { return "No change" }

        let prefix = totalMinutes > 0 ? "+" : "-"
        let absMinutes = abs(totalMinutes)
        let hours = absMinutes / 60
        let minutes = absMinutes % 60

        if hours > 0 {
            return "\(prefix)\(hours)h \(minutes)m"
        }

        return "\(prefix)\(minutes)m"
    }

    private func deltaColor(for delta: TimeInterval?, phase: SQSleepPhase) -> Color {
        guard let delta, abs(delta) >= 60 else {
            return SQColor.textSecondary.color
        }

        switch phase {
        case .awake:
            return delta > 0 ? SQColor.dashboardTrendWarm.color : SQColor.dashboardGlowMint.color
        case .rem, .deep:
            return delta > 0 ? SQColor.dashboardGlowMint.color : SQColor.dashboardTrendWarm.color
        case .core:
            return SQColor.textPrimary.color
        }
    }
}
