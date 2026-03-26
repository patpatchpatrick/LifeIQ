//
//  SQMetricDetailController.swift
//  BeastFitness
//

import SwiftUI
import SwiftData
import CoolCharts
import BeastFitnessCore

@MainActor
protocol SQMetricDetailInterface {
    func loadUI(for context: ModelContext) async
}

@Observable @MainActor
final class SQMetricDetailController: SQMetricDetailInterface {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: String
        let detail: String?
        let valueColor: SQColor

        init(
            id: String,
            title: String,
            value: String,
            detail: String? = nil,
            valueColor: SQColor = .textPrimary
        ) {
            self.id = id
            self.title = title
            self.value = value
            self.detail = detail
            self.valueColor = valueColor
        }
    }

    struct Section: Identifiable {
        let id: String
        let title: String
        let items: [Item]
    }

    private struct DayValuePoint: Identifiable {
        let id: String
        let date: Date
        let value: Double
    }

    private struct TrendSummary {
        let value: String
        let color: SQColor
    }

    private struct AvoidanceWindow {
        let startDate: Date
        let endDate: Date
        let dayCount: Int
    }

    let id = UUID().uuidString
    private(set) var containerWidth: CGFloat = 0
    var chartWidth: CGFloat {
        max(0, containerWidth - (.SQSpace.l * 4))
    }
    let chartHeight: CGFloat = 300

    private let hub: EventHub
    private let metricId: String
    private let metricsManager: SQMetricsManaging
    private let metricEntryManager: SQMetricEntryManaging
    private weak var modelContext: ModelContext?

    private(set) var hasLoadedUI = false
    private(set) var isLoading = false
    private(set) var selectedTimeRange: AppTimeRange
    let timeRangeMenuViewModel: SQDropDownMenuViewModel

    private(set) var metricDefinition: SQMetricDefinition?
    private(set) var chartModel: LineChartModel?
    private(set) var chartTitle: String?
    private(set) var chartSubtitle: String?
    private(set) var sections: [Section] = []

    var title: String {
        metricDefinition?.title ?? "Metric"
    }

    init(
        hub: EventHub,
        metricId: String,
        initialTimeRange: AppTimeRange,
        metricsManager: SQMetricsManaging = SQMetricsManager.shared,
        metricEntryManager: SQMetricEntryManaging = SQAppState.shared.metricEntryManager
    ) {
        self.hub = hub
        self.metricId = metricId
        self.selectedTimeRange = initialTimeRange
        self.metricsManager = metricsManager
        self.metricEntryManager = metricEntryManager

        let items = AppTimeRange.allCases
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }

        self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: initialTimeRange.rawValue),
            items: items
        ) { _ in }

        self.timeRangeMenuViewModel.itemSelectionHandler = { [weak self] selectedTitle in
            guard let self else { return }
            if let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }) {
                self.selectedTimeRange = selectedRange
                Task { @MainActor in
                    await self.reloadUI()
                }
            }
        }
    }

    func loadUI(for context: ModelContext) async {
        if modelContext == nil {
            modelContext = context
        }

        guard !hasLoadedUI else { return }
        hasLoadedUI = true
        isLoading = true

        buildMockContent()

        do {
            try metricsManager.loadIfNeeded(using: context)

            guard let definition = metricsManager.allMetrics(includeArchived: true).first(where: { $0.id == metricId }) else {
                presentErrorAndDismiss("Metric could not be found.")
                return
            }

            metricDefinition = definition
            try await loadMetricData(definition: definition, context: context)
            isLoading = false
        } catch {
            presentErrorAndDismiss("Error loading metric details: \(error.localizedDescription)")
        }
    }

    func updateLayout(containerWidth: CGFloat) {
        let rounded = (containerWidth * 2).rounded() / 2
        guard abs(self.containerWidth - rounded) > 0.5 else { return }
        self.containerWidth = rounded
        rebuildChartModelForCurrentState()
    }

    private func reloadUI() async {
        guard let context = modelContext else { return }
        hasLoadedUI = false
        await loadUI(for: context)
    }

    private func loadMetricData(definition: SQMetricDefinition, context: ModelContext) async throws {
        let currentStats = try await metricEntryManager.getDailyCheckInStats(
            from: selectedTimeRange.sqTimeRange.startDate,
            to: selectedTimeRange.sqTimeRange.endDate,
            context: context
        )

        let priorStats: [SQDailyCheckInStats]
        if let priorRange = selectedTimeRange.previousSqTimeRange {
            priorStats = try await metricEntryManager.getDailyCheckInStats(
                from: priorRange.startDate,
                to: priorRange.endDate,
                context: context
            )
        } else {
            priorStats = []
        }

        let allTimeStats: [SQDailyCheckInStats]
        if selectedTimeRange == .allTime {
            allTimeStats = currentStats
        } else {
            allTimeStats = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.allTime.startDate,
                to: SQTimeRange.allTime.endDate,
                context: context
            )
        }

        let points = buildPoints(from: currentStats)
        let allTimePoints = buildPoints(from: allTimeStats)

        let priorValues = priorStats.compactMap { $0.values[metricId].map(Double.init) }

        chartTitle = definition.title
        chartSubtitle = buildChartSubtitle(for: points)
        sections = buildSections(
            definition: definition,
            points: points,
            allTimePoints: allTimePoints,
            priorValues: priorValues
        )
        buildChart(points: points, definition: definition)
    }

    private func buildChartSubtitle(for points: [DayValuePoint]) -> String {
        if let earliest = points.first?.date, let latest = points.last?.date {
            return "\(points.count) logged days • \(earliest.formattedString(with: .medium)) - \(latest.formattedString(with: .medium)) • \(selectedTimeRange.rawValue)"
        }

        return "No logged days • \(selectedTimeRange.rawValue)"
    }

    private func buildSections(
        definition: SQMetricDefinition,
        points: [DayValuePoint],
        allTimePoints: [DayValuePoint],
        priorValues: [Double]
    ) -> [Section] {
        guard !points.isEmpty else { return [] }

        let values = points.map(\.value)
        let average = values.average ?? 0
        let median = values.median ?? average
        let trendSummary = buildTrendSummary(currentValues: values, priorValues: priorValues)

        let rangeValue: String = {
            guard let min = values.min(), let max = values.max() else { return "—" }
            return "\(Self.formatMetricValue(min, definition: definition)) - \(Self.formatMetricValue(max, definition: definition))"
        }()

        let overview = Section(
            id: "overview",
            title: "Overview",
            items: [
                .init(id: "overview-average", title: "Average", value: Self.formatMetricValue(average, definition: definition), detail: nil, valueColor: .textPrimary),
                .init(id: "overview-median", title: "Median", value: Self.formatMetricValue(median, definition: definition), detail: nil, valueColor: .textPrimary),
                .init(id: "overview-trend", title: "Trend", value: trendSummary.value, detail: nil, valueColor: trendSummary.color),
                .init(id: "overview-range", title: "Range", value: rangeValue, detail: nil, valueColor: .textPrimary)
            ]
        )

        let daysLogged = points.count
        let windowDays = max(1, dayCountForWindow(points: points))
        let loggingRate = Double(daysLogged) / Double(windowDays)
        let allTimeLoggedDates = allTimePoints.map(\.date)
        let consistency = Section(
            id: "consistency",
            title: "Consistency",
            items: [
                .init(id: "consistency-days-logged", title: "Days Logged", value: "\(daysLogged)", detail: nil, valueColor: .textPrimary),
                .init(id: "consistency-logging-rate", title: "Logging Rate", value: String(format: "%.0f%%", loggingRate * 100), detail: nil, valueColor: .textPrimary),
                .init(
                    id: "consistency-log-streak",
                    title: "Log Streak",
                    value: "\(currentConsecutiveDayCount(for: allTimeLoggedDates)) days",
                    detail: selectedTimeRange == .allTime ? nil : "All time",
                    valueColor: .textPrimary
                ),
                .init(
                    id: "consistency-last-logged",
                    title: "Last Logged",
                    value: allTimePoints.last?.date.formattedString(with: .medium) ?? "—",
                    detail: selectedTimeRange == .allTime ? nil : "All time",
                    valueColor: .textPrimary
                )
            ]
        )

        var builtSections = [overview, consistency]
        if definition.goalStyle != .justTrack {
            builtSections.append(
                buildGoalSection(
                    definition: definition,
                    points: points,
                    allTimePoints: allTimePoints
                )
            )
        }
        return builtSections
    }

    private func buildGoalSection(
        definition: SQMetricDefinition,
        points: [DayValuePoint],
        allTimePoints: [DayValuePoint]
    ) -> Section {
        let successPoints = points.filter { isSuccessful(value: $0.value, definition: definition) }
        let successRate = points.isEmpty ? 0 : Double(successPoints.count) / Double(points.count)
        let allTimeSuccessPoints = allTimePoints.filter { isSuccessful(value: $0.value, definition: definition) }
        let allTimeFailures = allTimePoints.filter { !isSuccessful(value: $0.value, definition: definition) }

        let currentStreakTitle: String
        let bestStreakTitle: String
        let successRateTitle: String
        let lastFailureTitle: String
        let currentStreakValue: String
        let bestStreakValue: String
        let currentStreakDetail: String?
        let bestStreakDetail: String?

        switch definition.goalStyle {
        case .avoidIt:
            let currentAvoidance = currentAvoidanceWindow(for: allTimePoints)
            let bestAvoidance = bestAvoidanceWindow(for: allTimePoints)
            currentStreakTitle = "Days Avoided"
            bestStreakTitle = "Best Avoidance"
            successRateTitle = "Zero Days"
            lastFailureTitle = "Last Non-Zero"
            currentStreakValue = "\(currentAvoidance?.dayCount ?? 0) days"
            bestStreakValue = "\(bestAvoidance?.dayCount ?? 0) days"
            currentStreakDetail = currentAvoidance.map { "Started \($0.startDate.formattedString(with: .short))" }
            bestStreakDetail = bestAvoidance.map {
                "\($0.startDate.formattedString(with: .short)) - \($0.endDate.formattedString(with: .short))"
            }
        default:
            currentStreakTitle = "Current Streak"
            bestStreakTitle = "Best Streak"
            successRateTitle = "Success Rate"
            lastFailureTitle = "Last Miss"
            currentStreakValue = "\(currentSuccessStreak(for: allTimePoints, definition: definition)) days"
            bestStreakValue = "\(longestConsecutiveDayCount(for: allTimeSuccessPoints.map(\.date))) days"
            currentStreakDetail = selectedTimeRange == .allTime ? nil : "All time"
            bestStreakDetail = selectedTimeRange == .allTime ? nil : "All time"
        }

        return Section(
            id: "streaks",
            title: "Streaks",
            items: [
                .init(id: "streaks-current", title: currentStreakTitle, value: currentStreakValue, detail: currentStreakDetail, valueColor: .textPrimary),
                .init(id: "streaks-best", title: bestStreakTitle, value: bestStreakValue, detail: bestStreakDetail, valueColor: .textPrimary),
                .init(id: "streaks-rate", title: successRateTitle, value: String(format: "%.0f%%", successRate * 100), detail: nil, valueColor: .textPrimary),
                .init(
                    id: "streaks-last-failure",
                    title: lastFailureTitle,
                    value: allTimeFailures.last?.date.formattedString(with: .medium) ?? "Never",
                    detail: selectedTimeRange == .allTime ? nil : "All time",
                    valueColor: .textPrimary
                )
            ]
        )
    }

    private func buildChart(points: [DayValuePoint], definition: SQMetricDefinition) {
        let chartPoints = points.map {
            LineChartIdentifiablePoint(
                id: $0.id,
                point: CGPoint(x: $0.date.timeIntervalSince1970, y: $0.value)
            )
        }

        guard chartPoints.count >= 2 else {
            chartModel = nil
            return
        }

        chartModel = LineChartModel(
            width: chartWidth,
            height: chartHeight,
            lineTitle: definition.title,
            uiConfig: buildChartUIConfig(),
            inputPoints: chartPoints,
            trendInputPoints: buildTrendInputPoints(from: chartPoints),
            gridConfig: buildGridConfig(),
            focusConfig: buildFocusConfig(definition: definition),
            navigationConfig: NavigationConfig()
        )
    }

    private func rebuildChartModelForCurrentState() {
        guard let existing = chartModel else { return }
        chartModel = LineChartModel(
            width: chartWidth,
            height: chartHeight,
            lineTitle: existing.lineTitle,
            uiConfig: existing.uiConfig,
            inputPoints: existing.inputPoints,
            trendInputPoints: existing.trendInputPoints,
            gridConfig: existing.gridConfig,
            focusConfig: existing.focusConfig,
            navigationConfig: existing.navigationConfig
        )
    }

    private func buildMockContent() {
        let mockDefinition = metricDefinition ?? SQMetricDefinition(
            id: metricId,
            title: "Metric",
            kind: .scale,
            unit: .none,
            group: SQDefaultGroup.general.rawValue,
            min: 0,
            max: 10,
            step: 1,
            isPreset: false,
            sortOrder: 0
        )

        let mockPoints: [LineChartIdentifiablePoint] = (0..<7).map { offset in
            let timestamp = Date().addingTimeInterval(Double(offset - 6) * 86400).timeIntervalSince1970
            return .init(
                id: "mock-\(offset)",
                point: CGPoint(x: timestamp, y: 5 + Double(offset % 3))
            )
        }

        chartModel = LineChartModel(
            width: chartWidth,
            height: chartHeight,
            lineTitle: mockDefinition.title,
            uiConfig: buildChartUIConfig(),
            inputPoints: mockPoints,
            trendInputPoints: buildTrendInputPoints(from: mockPoints),
            gridConfig: buildGridConfig(),
            focusConfig: buildFocusConfig(definition: mockDefinition),
            navigationConfig: NavigationConfig()
        )
        chartTitle = mockDefinition.title
        chartSubtitle = "Loading..."
        sections = [
            .init(
                id: "mock-overview",
                title: "Overview",
                items: [
                    .init(id: "mock-avg", title: "Average", value: "5.0"),
                    .init(id: "mock-med", title: "Median", value: "5.0"),
                    .init(id: "mock-trend", title: "Trend", value: "+0.0%"),
                    .init(id: "mock-range", title: "Range", value: "4.0 - 6.0")
                ]
            ),
            .init(
                id: "mock-consistency",
                title: "Consistency",
                items: [
                    .init(id: "mock-days", title: "Days Logged", value: "7"),
                    .init(id: "mock-rate", title: "Logging Rate", value: "100%"),
                    .init(id: "mock-streak", title: "Log Streak", value: "7 days"),
                    .init(id: "mock-last", title: "Last Logged", value: "Loading...")
                ]
            )
        ]
    }

    private func buildChartUIConfig() -> LineChartModel.UIConfig {
        let colorConfig = LineChartModel.ColorConfig(
            textPrimary: SQColor.textPrimary.color,
            textSecondary: SQColor.textSecondary.color,
            backgroundPrimary: SQColor.glassCardTint.color,
            backgroundSecondary: SQColor.glassPopoverTint.color,
            lineColor: SQColor.dashboardGlowBlue.color,
            trendLineColor: SQColor.dashboardGlowMint.color
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

    private func buildFocusConfig(definition: SQMetricDefinition) -> FocusConfig {
        let xLabelBuilder: @Sendable (String, CGFloat) -> String = { _, xValue in
            let date = Date(timeIntervalSince1970: TimeInterval(xValue))
            return date.formattedString(with: .medium)
        }

        let yLabelBuilder: @Sendable (String, CGFloat) -> String = { [weak self] _, value in
            guard let self else { return "" }
            return Self.formatMetricValue(Double(value), definition: definition)
        }

        return FocusConfig(
            focusColor: SQColor.dashboardGlowBlue.color,
            xLabelBuilder: xLabelBuilder,
            yLabelBuilder: yLabelBuilder,
            onFocus: { _ in }
        )
    }

    private nonisolated static func formatMetricValue(_ value: Double, definition: SQMetricDefinition) -> String {
        let raw = value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)

        switch definition.unit {
        case .hours:
            return "\(raw) hrs"
        case .pounds:
            return "\(raw) lbs"
        case .kilograms:
            return "\(raw) kg"
        case .percent:
            return "\(raw)%"
        case .none, .count, .unknown:
            if definition.kind == .scale, let max = definition.max {
                return "\(raw)/\(Int(max))"
            }
            return raw
        }
    }

    private func isSuccessful(value: Double, definition: SQMetricDefinition) -> Bool {
        switch definition.goalStyle {
        case .justTrack:
            return true
        case .buildUp:
            return value >= Double(definition.targetValue ?? 0)
        case .keepLow:
            return value <= Double(definition.targetValue ?? 0)
        case .avoidIt:
            return value == 0
        case .stayInRange:
            guard let min = definition.targetRangeMin, let max = definition.targetRangeMax else { return false }
            return value >= Double(min) && value <= Double(max)
        case .unknown:
            return false
        }
    }

    private func currentConsecutiveDayCount(for dates: [Date]) -> Int {
        let sorted = normalizedUniqueDates(dates)
        guard !sorted.isEmpty else { return 0 }
        guard sorted.count > 1 else { return 1 }

        var streak = 1
        for index in stride(from: sorted.count - 1, to: 0, by: -1) {
            let current = sorted[index]
            let previous = sorted[index - 1]
            if Calendar.current.dateComponents([.day], from: previous, to: current).day == 1 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func longestConsecutiveDayCount(for dates: [Date]) -> Int {
        let sorted = normalizedUniqueDates(dates)
        guard !sorted.isEmpty else { return 0 }
        guard sorted.count > 1 else { return 1 }

        var best = 1
        var current = 1

        for index in 1..<sorted.count {
            if Calendar.current.dateComponents([.day], from: sorted[index - 1], to: sorted[index]).day == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }

        return best
    }

    private func currentSuccessStreak(for points: [DayValuePoint], definition: SQMetricDefinition) -> Int {
        guard let last = points.last, isSuccessful(value: last.value, definition: definition) else {
            return 0
        }

        var streak = 1
        guard points.count > 1 else { return streak }

        for index in stride(from: points.count - 1, to: 0, by: -1) {
            let current = Calendar.current.startOfDay(for: points[index].date)
            let previousPoint = points[index - 1]
            let previous = Calendar.current.startOfDay(for: previousPoint.date)

            guard isSuccessful(value: previousPoint.value, definition: definition) else {
                break
            }

            if Calendar.current.dateComponents([.day], from: previous, to: current).day == 1 {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    private func buildTrendSummary(currentValues: [Double], priorValues: [Double]) -> TrendSummary {
        guard
            let currentAverage = currentValues.average,
            let priorAverage = priorValues.average,
            priorAverage != 0
        else {
            return .init(value: "—", color: .textSecondary)
        }

        let percent = ((currentAverage - priorAverage) / priorAverage) * 100
        let color: SQColor = percent >= 0 ? .dashboardGlowBlue : .dashboardTrendWarm
        return .init(
            value: String(format: "%@%.1f%%", percent >= 0 ? "+" : "", percent),
            color: color
        )
    }

    private func buildPoints(from stats: [SQDailyCheckInStats]) -> [DayValuePoint] {
        stats
            .compactMap { stat -> DayValuePoint? in
                guard let value = stat.values[metricId] else { return nil }
                return .init(id: stat.uniqueDateKey, date: stat.date, value: Double(value))
            }
            .sorted { $0.date < $1.date }
    }

    private func buildTrendInputPoints(from inputPoints: [LineChartIdentifiablePoint]) -> [LineChartIdentifiablePoint]? {
        guard inputPoints.count >= 4 else { return nil }

        let alpha: CGFloat = inputPoints.count > 12 ? 0.18 : 0.24
        var smoothedY = inputPoints[0].point.y

        let smoothedPoints = inputPoints.enumerated().map { index, point in
            if index == 0 {
                return point
            }

            smoothedY = (alpha * point.point.y) + ((1 - alpha) * smoothedY)
            return LineChartIdentifiablePoint(
                id: point.id,
                point: CGPoint(x: point.point.x, y: smoothedY)
            )
        }

        let anchorCount = inputPoints.count >= 9 ? 4 : 3
        let anchorIndices = buildTrendAnchorIndices(totalCount: smoothedPoints.count, anchorCount: anchorCount)
        return anchorIndices.map { smoothedPoints[$0] }
    }

    private func buildTrendAnchorIndices(totalCount: Int, anchorCount: Int) -> [Int] {
        guard totalCount > 0 else { return [] }
        guard anchorCount > 1 else { return [0] }

        let lastIndex = totalCount - 1
        let denominator = max(1, anchorCount - 1)
        let indices = (0..<anchorCount).map { anchorIndex in
            Int(round((Double(anchorIndex) / Double(denominator)) * Double(lastIndex)))
        }

        return indices.reduce(into: [Int]()) { result, index in
            if result.last != index {
                result.append(index)
            }
        }
    }

    private func currentAvoidanceWindow(for points: [DayValuePoint]) -> AvoidanceWindow? {
        let sorted = points.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        guard last.value == 0 else { return nil }

        let calendar = Calendar.current
        let lastDate = calendar.startOfDay(for: last.date)

        if let lastNonZero = sorted.dropLast().last(where: { $0.value != 0 }) {
            let lastNonZeroDate = calendar.startOfDay(for: lastNonZero.date)
            let dayCount = calendar.dateComponents([.day], from: lastNonZeroDate, to: lastDate).day ?? 0
            let startDate = calendar.date(byAdding: .day, value: 1, to: lastNonZeroDate) ?? lastDate
            return .init(startDate: startDate, endDate: lastDate, dayCount: dayCount)
        }

        let firstDate = calendar.startOfDay(for: first.date)
        let dayCount = (calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0) + 1
        return .init(startDate: firstDate, endDate: lastDate, dayCount: dayCount)
    }

    private func bestAvoidanceWindow(for points: [DayValuePoint]) -> AvoidanceWindow? {
        let sorted = points.sorted { $0.date < $1.date }
        guard let first = sorted.first else { return nil }

        let calendar = Calendar.current
        let firstDate = calendar.startOfDay(for: first.date)
        var bestWindow: AvoidanceWindow?
        var lastNonZeroDate: Date? = nil

        for point in sorted {
            let currentDate = calendar.startOfDay(for: point.date)
            if point.value == 0 {
                let window: AvoidanceWindow
                if let lastNonZeroDate {
                    let dayCount = calendar.dateComponents([.day], from: lastNonZeroDate, to: currentDate).day ?? 0
                    let startDate = calendar.date(byAdding: .day, value: 1, to: lastNonZeroDate) ?? currentDate
                    window = .init(startDate: startDate, endDate: currentDate, dayCount: dayCount)
                } else {
                    let dayCount = (calendar.dateComponents([.day], from: firstDate, to: currentDate).day ?? 0) + 1
                    window = .init(startDate: firstDate, endDate: currentDate, dayCount: dayCount)
                }

                if bestWindow == nil || window.dayCount > (bestWindow?.dayCount ?? 0) {
                    bestWindow = window
                }
            } else {
                lastNonZeroDate = currentDate
            }
        }

        return bestWindow
    }

    private func normalizedUniqueDates(_ dates: [Date]) -> [Date] {
        let normalized = Set(dates.map { Calendar.current.startOfDay(for: $0) })
        return normalized.sorted()
    }

    private func dayCountForWindow(points: [DayValuePoint]) -> Int {
        switch selectedTimeRange {
        case .today:
            return 1
        case .pastSevenDays:
            return 7
        case .past30Days:
            return 30
        case .pastYear:
            return 365
        case .allTime:
            guard let first = points.first?.date, let last = points.last?.date else { return 0 }
            let start = Calendar.current.startOfDay(for: first)
            let end = Calendar.current.startOfDay(for: last)
            return (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        }
    }

    private func presentErrorAndDismiss(_ message: String) {
        SQLogger.shared.log(message, .error, context: .dashboard)
        hub.alertEvents.send(.present(.init(
            SQError.standard(withDescription: message),
            handler: { [weak self] _ in
                self?.hub.domainEvents.send(.popDashboardRoute)
            }
        )))
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }

    var median: Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
