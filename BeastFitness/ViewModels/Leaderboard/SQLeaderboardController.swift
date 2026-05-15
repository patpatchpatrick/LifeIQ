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
    let id = UUID().uuidString
    private(set) var containerWidth: CGFloat = 0
    var chartWidth: CGFloat {
        max(0, containerWidth - (.SQSpace.l * 4))
    }
    let chartHeight: CGFloat = 300
    var navigationPath = NavigationPath()
    private var cancellables = Set<AnyCancellable>()
    let workoutManager: SQWorkoutManaging
    let workoutScoreService: SQWorkoutScoreServicing
    private(set) var hasLoadedUI = false
    private(set) var isLoading = false
    private(set) var selectedTimeRange: AppTimeRange
    let timeRangeMenuViewModel: SQDropDownMenuViewModel
    private weak var modelContext: ModelContext?

    private let hub: EventHub
    let mode: SQLeaderboardMode
    private(set) var rows: [SQLeaderboardRowViewModel] = []
    private(set) var chartModel: LineChartModel?
    private(set) var chartTitle: String?
    private(set) var chartSubtitle: String?
    var focusedEntryId: String?
    private(set) var hasFreeWorkoutScorePreviewAccess = false
    private(set) var premiumLockedSubtitle = SQSubscriptionManager.weeklyScorePreviewLockedSubtitle

    var title: String {
        mode.title
    }

    var isPremiumLocked: Bool {
        mode.requiresPremium
            && !SQSubscriptionManager.hasPremiumAccess
            && !hasFreeWorkoutScorePreviewAccess
    }

    @MainActor
    static let `default` = SQLeaderboardController(
        hub: SQAppState.shared.hub,
        mode: .workoutQuantity(.distanceWalkingRunning, .running),
        initialTimeRange: .allTime
    )

    init(
        hub: EventHub,
        mode: SQLeaderboardMode,
        initialTimeRange: AppTimeRange = .allTime,
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared,
        workoutScoreService: SQWorkoutScoreServicing? = nil
    ) {
        self.hub = hub
        self.selectedTimeRange = initialTimeRange
        self.mode = mode
        self.workoutManager = workoutManager
        self.workoutScoreService = workoutScoreService ?? SQWorkoutScoreService()

        let items = AppTimeRange.allCases
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }

        self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: initialTimeRange.rawValue),
            items: items
        ) { _ in }

        handleEventSubscriptions(hub: hub)

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
        hasFreeWorkoutScorePreviewAccess = false
        premiumLockedSubtitle = SQSubscriptionManager.weeklyScorePreviewLockedSubtitle

        buildMockRows()

        let loadSucceeded: Bool

        switch mode {
        case .workoutQuantity(let quantityType, let activityType):
            loadSucceeded = await loadWorkoutQuantity(quantityType: quantityType, activityType: activityType, context: context)
        case .workoutScore(let kind, let activityType):
            loadSucceeded = await loadWorkoutScore(kind: kind, activityType: activityType, context: context)
        case .vo2Max:
            loadSucceeded = await loadVO2Max()
        }

        if loadSucceeded {
            isLoading = false
        }
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
                    percentileRank: nil
                )
            }
            buildMockChart(mockValue: mockMetric.value)

        case .workoutScore(let kind, _):
            let mockValue = kind == .performance ? 84.0 : 71.0
            rows = (1...10).map { index in
                SQLeaderboardRowViewModel(
                    id: "mock-row-\(index)",
                    rank: index,
                    title: "Loading...",
                    date: mockDate,
                    value: mockValue,
                    formattedScore: "\(Int(mockValue.rounded()))",
                    unitString: "/100",
                    percentileRank: nil
                )
            }
            buildMockChart(mockValue: mockValue)

        case .vo2Max:
            rows = (1...10).map { index in
                SQLeaderboardRowViewModel(
                    id: "mock-row-\(index)",
                    rank: index,
                    title: "VO₂ Max",
                    date: mockDate,
                    value: 45.0,
                    formattedScore: "45.0",
                    unitString: "mL/kg/min",
                    percentileRank: nil
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
            trendInputPoints: buildTrendInputPoints(from: mockPoints),
            gridConfig: buildGridConfig(),
            focusConfig: buildFocusConfig(),
            navigationConfig: NavigationConfig()
        )
    }

    // MARK: - Load: Workout Quantity

    /// Returns `true` on success, `false` if an error occurred and was shown.
    @discardableResult
    private func loadWorkoutQuantity(
        quantityType: SQQuantityType,
        activityType: HKWorkoutActivityType,
        context: ModelContext
    ) async -> Bool {
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
                    formattedScore: item.metric.displayableValue(for: quantityType, value: item.metric.displayValue),
                    unitString: item.metric.displayUnit.unitString ?? "",
                    warningText: item.metric.warningText,
                    percentileRank: SQPercentileCalculator.calculatePercentile(
                        currentBest: item.metric.value,
                        historicalValues: allTimeValues,
                        isLowerBetter: mode.isLowerBetter
                    ),
                    workout: item.workout
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
            return true
        } catch {
            SQLogger.shared.log(
                "Error loading leaderboard: \(error.localizedDescription)",
                .error,
                context: .workoutList
            )

            hub.alertEvents.send(.present(.init(
                SQError.standard(withDescription: "Error loading leaderboard: \(error.localizedDescription)"),
                handler: { [weak self] _ in
                    self?.hub.domainEvents.send(.popDashboardRoute)
                }
            )))
            return false
        }
    }

    @discardableResult
    private func loadWorkoutScore(
        kind: SQWorkoutScoreKind,
        activityType: HKWorkoutActivityType,
        context: ModelContext
    ) async -> Bool {
        SQLogger.shared.log(
            "Loading workout score leaderboard for \(kind.title) - \(activityType.name)",
            .info,
            context: .workoutList
        )

        do {
            let currentWorkouts = try await workoutManager.getWorkouts(
                for: selectedTimeRange.sqTimeRange,
                modelContext: context
            )
            let allTimeWorkouts = try await workoutManager.getWorkouts(
                for: .allTime,
                modelContext: context
            )

            rows = await workoutScoreService.leaderboardRows(
                for: kind,
                activityType: activityType,
                workouts: currentWorkouts,
                allTimeWorkouts: allTimeWorkouts
            )
            let isPremiumUnlocked = SQSubscriptionManager.hasPremiumAccess
            let previewState = SQSubscriptionManager.weeklyWorkoutScorePreviewState(
                candidates: rows.compactMap(\.workout),
                isPremiumUnlocked: isPremiumUnlocked
            )
            premiumLockedSubtitle = previewState.lockedSubtitle

            if !isPremiumUnlocked {
                if let unlockedWorkoutId = previewState.unlockedWorkoutId {
                    rows = rows.filter { $0.workout?.id == unlockedWorkoutId }
                    hasFreeWorkoutScorePreviewAccess = !rows.isEmpty
                } else {
                    hasFreeWorkoutScorePreviewAccess = false
                }
            }

            chartTitle = "\(activityType.name) \(kind.title)"

            let allDates = rows.map(\.date)
            if let earliest = allDates.min(), let latest = allDates.max() {
                chartSubtitle = "\(rows.count) workouts • \(earliest.formattedString(with: .medium)) - \(latest.formattedString(with: .medium)) • \(selectedTimeRange.rawValue)"
            } else {
                chartSubtitle = "\(rows.count) workouts • \(selectedTimeRange.rawValue)"
            }

            buildChart()
            return true
        } catch {
            SQLogger.shared.log(
                "Error loading workout score leaderboard: \(error.localizedDescription)",
                .error,
                context: .workoutList
            )

            hub.alertEvents.send(.present(.init(
                SQError.standard(withDescription: "Error loading leaderboard: \(error.localizedDescription)"),
                handler: { [weak self] _ in
                    self?.hub.domainEvents.send(.popDashboardRoute)
                }
            )))
            return false
        }
    }

    // MARK: - Load: VO2 Max

    /// Returns `true` on success, `false` if an error occurred and was shown.
    @discardableResult
    private func loadVO2Max() async -> Bool {
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
                    title: "VO₂ Max",
                    date: sample.startDate,
                    value: sample.value,
                    formattedScore: String(format: "%.1f", sample.value),
                    unitString: "mL/kg/min",
                    percentileRank: SQPercentileCalculator.calculatePercentile(
                        currentBest: sample.value,
                        historicalValues: allTimeValues,
                        isLowerBetter: false
                    )
                )
            }

            chartTitle = "VO₂ Max"

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
            return true
        } catch {
            SQLogger.shared.log(
                "Error loading VO2 Max leaderboard: \(error.localizedDescription)",
                .error,
                context: .healthKit
            )

            hub.alertEvents.send(.present(.init(
                SQError.standard(withDescription: "Error loading VO2 Max leaderboard: \(error.localizedDescription)"),
                handler: { [weak self] _ in
                    self?.hub.domainEvents.send(.popDashboardRoute)
                }
            )))
            return false
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
            trendInputPoints: buildTrendInputPoints(from: points),
            gridConfig: buildGridConfig(),
            focusConfig: buildFocusConfig(),
            navigationConfig: NavigationConfig()
        )
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
            focusColor: SQColor.dashboardGlowBlue.color,
            xLabelBuilder: xLabelBuilder,
            yLabelBuilder: yLabelBuilder,
            onFocus: onFocus
        )
    }

    private func buildTrendInputPoints(from inputPoints: [LineChartIdentifiablePoint]) -> [LineChartIdentifiablePoint]? {
        guard inputPoints.count >= 4 else { return nil }

        let alpha: CGFloat = inputPoints.count > 12 ? 0.20 : 0.26
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

    func rowTapped(row: SQLeaderboardRowViewModel) {
        focusChartPoint(with: row.id)
    }

    func navigateToWorkout(_ row: SQLeaderboardRowViewModel) {
        guard let workout = row.workout else { return }
        hub.domainEvents.send(.pushDashboardRoute(.workoutSummary(controller: .init(workout: workout, mode: .standard))))
    }

    func premiumOverlayTapped() {
        SQSubscriptionManager.displaySubscriptionScreen(
            source: "leaderboard_premium_overlay",
            feature: mode.title.analyticsKey
        )
    }

    private func focusChartPoint(with id: String) {
        self.chartModel?.focusCoordinateWith(id: id)
    }

    func updateLayout(containerWidth: CGFloat) {
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
            trendInputPoints: existing.trendInputPoints,
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
