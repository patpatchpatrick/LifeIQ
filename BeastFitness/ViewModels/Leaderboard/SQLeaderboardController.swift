//
//  SQLeaderboardController.swift
//  BeastFitness
//

import SwiftUI
import SwiftData
import Combine
import BeastFitnessCore
import HealthKit
import CoolCharts

@MainActor
protocol SQLeaderboardInterface {
    func loadUI(for context: ModelContext) async
}

@Observable @MainActor
final class SQLeaderboardController: SQLeaderboardInterface {
    private(set) var containerWidth: CGFloat = 0
    var chartWidth: CGFloat {
        max(0, containerWidth * 0.95)
    }
    let chartHeight: CGFloat = 300
    var navigationPath = NavigationPath()
    private var cancellables = Set<AnyCancellable>()
    let state: LeaderboardStating
    let workoutManager: SQWorkoutManaging
    private(set) var hasLoadedUI = false
    private(set) var isLoading = false
    private(set) var selectedTimeRange: AppTimeRange
    let timeRangeMenuViewModel: SQDropDownMenuViewModel
    private weak var modelContext: ModelContext?

    let mode: SQLeaderboardMode
    private(set) var rows: [SQLeaderboardRowViewModel] = []
    private(set) var chartModel: LineChartModel?
    private(set) var chartTitle: String?
    private(set) var chartSubtitle: String?
    var focusedEntryId: String?

    var title: String {
        mode.title
    }

    @MainActor
    static let `default` = SQLeaderboardController(
        state: SQAppState.shared.leaderboardState,
        mode: .workoutQuantity(.distanceWalkingRunning, .running),
        initialTimeRange: .allTime
    )

    init(
        state: LeaderboardStating,
        mode: SQLeaderboardMode,
        initialTimeRange: AppTimeRange = .allTime,
        workoutManager: SQWorkoutManaging = SQWorkoutManager()
    ) {
        self.selectedTimeRange = initialTimeRange
        self.state = state
        self.mode = mode
        self.workoutManager = workoutManager

        let items = AppTimeRange.allCases
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }

        self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: initialTimeRange.rawValue),
            items: items
        ) { _ in }

        handleEventSubscriptions(hub: state.hub)

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

    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { event in
            switch event {
            case .workoutsUpdated, .workoutsDeleted:
                SQLogger.shared.log(
                    "Workouts updated, leaderboard should reload",
                    .debug,
                    context: .workoutList
                )
            case .activeWorkoutUpdate:
                break
            }
        }.store(in: &cancellables)
    }

    func loadUI(for context: ModelContext) async {
        if self.modelContext == nil {
            self.modelContext = context
        }

        guard !hasLoadedUI else { return }
        hasLoadedUI = true
        isLoading = true

        buildMockRows()

        switch mode {
        case .workoutQuantity(let quantityType, let activityType):
            await loadWorkoutQuantity(quantityType: quantityType, activityType: activityType, context: context)
        case .vo2Max:
            await loadVO2Max()
        }

        isLoading = false
    }

    // MARK: - Mock Loading State

    private func buildMockRows() {
        let mockDate = Date()
        switch mode {
        case .workoutQuantity(let quantityType, _):
            let mockMetric = SQWorkoutMetric.mock(for: quantityType)
            rows = (1...10).map { index in
                SQLeaderboardRowViewModel(
                    id: "mock-row-\(index)",
                    rank: index,
                    title: "Loading...",
                    date: mockDate,
                    value: mockMetric.value,
                    formattedScore: mockMetric.displayableValue(for: quantityType, value: mockMetric.value),
                    unitString: mockMetric.unit.unitString ?? "",
                    allTimeRank: index,
                    allTimeTotal: 10,
                    state: state
                )
            }
            buildMockChart(mockValue: mockMetric.value)

        case .vo2Max:
            rows = (1...10).map { index in
                SQLeaderboardRowViewModel(
                    id: "mock-row-\(index)",
                    rank: index,
                    title: "VO2 Max",
                    date: mockDate,
                    value: 45.0,
                    formattedScore: "45.0",
                    unitString: "mL/kg/min",
                    allTimeRank: index,
                    allTimeTotal: 10,
                    state: state
                )
            }
            buildMockChart(mockValue: 45.0)
        }

        chartTitle = mode.chartLineTitle
        chartSubtitle = "Loading..."
    }

    private func buildMockChart(mockValue: Double) {
        let mockPoints: [LineChartIdentifiablePoint] = (1...10).map { index in
            let timestamp = Date().addingTimeInterval(-Double(index) * 86400).timeIntervalSince1970
            return LineChartIdentifiablePoint(
                id: "mock-chart-\(index)",
                point: CGPoint(x: timestamp, y: mockValue + Double(index) * 0.5)
            )
        }

        chartModel = LineChartModel(
            width: chartWidth,
            height: chartHeight,
            lineTitle: mode.chartLineTitle,
            uiConfig: buildChartUIConfig(),
            inputPoints: mockPoints,
            gridConfig: GridConfig(),
            focusConfig: buildFocusConfig(),
            navigationConfig: NavigationConfig()
        )
    }

    // MARK: - Load: Workout Quantity

    private func loadWorkoutQuantity(
        quantityType: SQQuantityType,
        activityType: HKWorkoutActivityType,
        context: ModelContext
    ) async {
        SQLogger.shared.log(
            "Loading leaderboard for \(quantityType.displayTitle) - \(activityType.name)",
            .info,
            context: .workoutList
        )

        do {
            let allWorkouts = try await workoutManager.getWorkouts(
                for: selectedTimeRange.sqTimeRange,
                modelContext: context
            )
            let filteredWorkouts = allWorkouts.filter { $0.activityType == activityType }

            SQLogger.shared.log(
                "Found \(filteredWorkouts.count) workouts for \(activityType.name)",
                .debug,
                context: .workoutList
            )

            var workoutMetrics: [(workout: SQWorkoutSessionable, metric: SQWorkoutMetric)] = []
            for workout in filteredWorkouts {
                if let metric = await workout.getMetric(for: quantityType) {
                    workoutMetrics.append((workout, metric))
                }
            }

            let sortedMetrics = mode.isLowerBetter
                ? workoutMetrics.sorted { $0.metric.value < $1.metric.value }
                : workoutMetrics.sorted { $0.metric.value > $1.metric.value }

            // Load all-time values for percentile ranking. When already on all-time,
            // reuse the values already in hand to avoid a redundant fetch.
            let allTimeValues: [Double]
            if selectedTimeRange == .allTime {
                allTimeValues = sortedMetrics.map { $0.metric.value }
            } else {
                allTimeValues = await fetchAllTimeWorkoutMetricValues(
                    quantityType: quantityType,
                    activityType: activityType,
                    context: context
                )
            }

            rows = sortedMetrics.enumerated().map { index, item in
                SQLeaderboardRowViewModel(
                    id: item.workout.id,
                    rank: index + 1,
                    title: item.workout.title ?? "Workout",
                    date: item.workout.startDate ?? Date(),
                    value: item.metric.value,
                    formattedScore: item.metric.displayableValue(for: quantityType, value: item.metric.value),
                    unitString: item.metric.unit.unitString ?? "",
                    warningText: item.metric.warningText,
                    allTimeRank: computeAllTimeRank(value: item.metric.value, allTimeValues: allTimeValues, isLowerBetter: mode.isLowerBetter),
                    allTimeTotal: allTimeValues.count,
                    state: state
                )
            }

            chartTitle = quantityType.displayTitle

            let allDates = rows.map { $0.date }
            if let earliest = allDates.min(), let latest = allDates.max() {
                chartSubtitle = "\(rows.count) workouts • \(earliest.formattedString(with: .medium)) - \(latest.formattedString(with: .medium)) • \(selectedTimeRange.rawValue)"
            } else {
                chartSubtitle = "\(rows.count) workouts • \(selectedTimeRange.rawValue)"
            }

            SQLogger.shared.log(
                "✅ Leaderboard loaded with \(rows.count) ranked entries",
                .info,
                context: .workoutList,
                isPriority: true
            )

            buildChart()
        } catch {
            SQLogger.shared.log(
                "Error loading leaderboard: \(error.localizedDescription)",
                .error,
                context: .workoutList
            )
        }
    }

    // MARK: - Load: VO2 Max

    private func loadVO2Max() async {
        SQLogger.shared.log(
            "Loading VO2 Max leaderboard",
            .info,
            context: .healthKit
        )

        do {
            let samples = try await SQHealthKitManager.shared.fetchVO2MaxSamples(selectedTimeRange.sqTimeRange)

            // Group by calendar day, keep highest value per day
            let calendar = Calendar.current
            var byDay: [Date: SQVO2MaxSample] = [:]
            for sample in samples {
                let dayStart = calendar.startOfDay(for: sample.startDate)
                if let existing = byDay[dayStart] {
                    if sample.value > existing.value {
                        byDay[dayStart] = sample
                    }
                } else {
                    byDay[dayStart] = sample
                }
            }

            // Sort descending (highest VO2 max = rank #1)
            let sorted = byDay.values.sorted { $0.value > $1.value }

            // Load all-time values for percentile ranking.
            let allTimeValues: [Double]
            if selectedTimeRange == .allTime {
                allTimeValues = sorted.map { $0.value }
            } else {
                allTimeValues = await fetchAllTimeVO2MaxValues()
            }

            rows = sorted.enumerated().map { index, sample in
                SQLeaderboardRowViewModel(
                    id: sample.healthKitId ?? UUID().uuidString,
                    rank: index + 1,
                    title: "VO2 Max",
                    date: sample.startDate,
                    value: sample.value,
                    formattedScore: String(format: "%.1f", sample.value),
                    unitString: "mL/kg/min",
                    allTimeRank: computeAllTimeRank(value: sample.value, allTimeValues: allTimeValues, isLowerBetter: false),
                    allTimeTotal: allTimeValues.count,
                    state: state
                )
            }

            chartTitle = "VO2 Max"

            let allDates = rows.map { $0.date }
            if let earliest = allDates.min(), let latest = allDates.max() {
                chartSubtitle = "\(rows.count) measurements • \(earliest.formattedString(with: .medium)) - \(latest.formattedString(with: .medium)) • \(selectedTimeRange.rawValue)"
            } else {
                chartSubtitle = "\(rows.count) measurements • \(selectedTimeRange.rawValue)"
            }

            SQLogger.shared.log(
                "✅ VO2 Max leaderboard loaded with \(rows.count) entries",
                .info,
                context: .healthKit,
                isPriority: true
            )

            buildChart()
        } catch {
            SQLogger.shared.log(
                "Error loading VO2 Max leaderboard: \(error.localizedDescription)",
                .error,
                context: .healthKit
            )
        }
    }

    // MARK: - All-Time Percentile Helpers

    /// Returns the rank of `value` within `allTimeValues` (1 = best).
    /// Rank is the number of all-time entries that are strictly better, plus 1.
    private func computeAllTimeRank(value: Double, allTimeValues: [Double], isLowerBetter: Bool) -> Int {
        if isLowerBetter {
            return allTimeValues.filter { $0 < value }.count + 1
        } else {
            return allTimeValues.filter { $0 > value }.count + 1
        }
    }

    /// Loads all-time metric values for a given activity type, used for percentile calculation
    /// when the current leaderboard is filtered to a sub-range.
    private func fetchAllTimeWorkoutMetricValues(
        quantityType: SQQuantityType,
        activityType: HKWorkoutActivityType,
        context: ModelContext
    ) async -> [Double] {
        guard let allWorkouts = try? await workoutManager.getWorkouts(
            for: AppTimeRange.allTime.sqTimeRange,
            modelContext: context
        ) else { return [] }

        var values: [Double] = []
        for workout in allWorkouts where workout.activityType == activityType {
            if let metric = await workout.getMetric(for: quantityType) {
                values.append(metric.value)
            }
        }
        return values
    }

    /// Loads all-time VO2 max values (deduplicated by day), used for percentile calculation
    /// when the current leaderboard is filtered to a sub-range.
    private func fetchAllTimeVO2MaxValues() async -> [Double] {
        guard let samples = try? await SQHealthKitManager.shared.fetchVO2MaxSamples(.allTime) else {
            return []
        }
        let calendar = Calendar.current
        var bestByDay: [Date: Double] = [:]
        for sample in samples {
            let dayStart = calendar.startOfDay(for: sample.startDate)
            bestByDay[dayStart] = max(bestByDay[dayStart] ?? 0, sample.value)
        }
        return Array(bestByDay.values)
    }

    // MARK: - Chart

    private func buildChart() {
        let points: [LineChartIdentifiablePoint] = rows.map { row in
            LineChartIdentifiablePoint(
                id: row.id,
                point: CGPoint(x: row.date.timeIntervalSince1970, y: row.value)
            )
        }

        guard points.count >= 2 else {
            chartModel = nil
            return
        }

        chartModel = LineChartModel(
            width: chartWidth,
            height: chartHeight,
            lineTitle: mode.chartLineTitle,
            uiConfig: buildChartUIConfig(),
            inputPoints: points,
            gridConfig: GridConfig(),
            focusConfig: buildFocusConfig(),
            navigationConfig: NavigationConfig()
        )
    }

    private func buildChartUIConfig() -> LineChartModel.UIConfig {
        let colorConfig = LineChartModel.ColorConfig(
            textPrimary: SQColor.textPrimary.color,
            textSecondary: SQColor.textSecondary.color,
            backgroundPrimary: SQColor.backgroundSheet.color,
            backgroundSecondary: SQColor.backgroundSecondary.color,
            lineColor: SQColor.accent(1).color
        )
        let fontConfig = LineChartModel.FontConfig(
            font: SQFont(type: .bodyExtraSmall).font,
            boldFont: SQFont(type: .bodySmallBold).font
        )
        return LineChartModel.UIConfig(colorConfig: colorConfig, fontConfig: fontConfig)
    }

    private func buildFocusConfig() -> FocusConfig {
        let xLabelBuilder: @Sendable (String, CGFloat) -> String = { _, xValue in
            let date = Date(timeIntervalSince1970: TimeInterval(xValue))
            return date.formattedString(with: .medium)
        }

        let formattedValues: [String: String] = Dictionary(
            rows.map { ($0.id, $0.scoreAttributedString.stringValue) },
            uniquingKeysWith: { first, _ in first }
        )

        let yLabelBuilder: @Sendable (String, CGFloat) -> String = { id, _ in
            return formattedValues[id] ?? ""
        }

        let onFocus: @Sendable (LineChartIdentifiablePoint) -> Void = { [weak self] point in
            guard let self else { return }
            Task { @MainActor in
                self.focusedEntryId = point.id
            }
        }

        return FocusConfig(
            focusColor: SQColor.accent(1).color,
            xLabelBuilder: xLabelBuilder,
            yLabelBuilder: yLabelBuilder,
            onFocus: onFocus
        )
    }

    func rowTapped(row: SQLeaderboardRowViewModel) {
        focusChartPoint(with: row.id)
    }

    private func focusChartPoint(with id: String) {
        self.chartModel?.focusCoordinateWith(id: id)
    }

    func updateLayout(containerWidth: CGFloat) {
        print("PTD Updating Container Width", containerWidth)
        let rounded = (containerWidth * 2).rounded() / 2
        guard abs(self.containerWidth - rounded) > 0.5 else { return }
        self.containerWidth = rounded
        rebuildChartModelForCurrentState()
    }

    private func rebuildChartModelForCurrentState() {
        guard let existing = chartModel else { return }
        chartModel = LineChartModel(
            width: chartWidth,
            height: chartHeight,
            lineTitle: existing.lineTitle,
            uiConfig: existing.uiConfig,
            inputPoints: existing.inputPoints,
            gridConfig: existing.gridConfig,
            focusConfig: existing.focusConfig,
            navigationConfig: existing.navigationConfig
        )
    }

    // MARK: - Reload

    private func reloadUI() async {
        guard let context = modelContext else {
            SQLogger.shared.log(
                "Cannot reload leaderboard: ModelContext not available",
                .error,
                context: .workoutList
            )
            return
        }
        hasLoadedUI = false
        await loadUI(for: context)
    }
}
