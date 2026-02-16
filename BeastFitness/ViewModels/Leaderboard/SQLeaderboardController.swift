//
//  SQLeaderboardController.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
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
    let chartWidth: CGFloat = 400
    let chartHeight: CGFloat = 300
    var navigationPath = NavigationPath()
    private var cancellables = Set<AnyCancellable>()
    let state: LeaderboardStating
    let workoutManager: SQWorkoutManaging
    private(set) var hasLoadedUI = false
    private(set) var isLoading = false

    let quantityType: SQQuantityType
    let activityType: HKWorkoutActivityType
    private(set) var rows: [SQLeaderboardRowViewModel] = []
    private(set) var chartModel: LineChartModel?
    private(set) var chartTitle: String?
    private(set) var chartSubtitle: String?
    var focusedWorkoutId: String?

    var title: String {
        "\(quantityType.displayTitle) Leaderboard"
    }

    @MainActor
    static let `default` = SQLeaderboardController(
        state: SQAppState.shared.leaderboardState,
        quantityType: .distanceWalkingRunning,
        activityType: .running
    )

    init(
        state: LeaderboardStating,
        quantityType: SQQuantityType,
        activityType: HKWorkoutActivityType,
        workoutManager: SQWorkoutManaging = SQWorkoutManager()
    ) {
        self.state = state
        self.quantityType = quantityType
        self.activityType = activityType
        self.workoutManager = workoutManager
        handleEventSubscriptions(hub: state.hub)
    }

    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { event in
            switch event {
            case .workoutsUpdated, .workoutsDeleted:
                // Reload data when workouts change
                // Note: We'd need to pass the context here in a real implementation
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
        guard !hasLoadedUI else { return }
        hasLoadedUI = true
        isLoading = true

        // Initialize mock rows for redacted loading state
        let mockMetric = SQWorkoutMetric.mock(for: quantityType)
        rows = (1...10).map { index in
            SQLeaderboardRowViewModel(
                rank: index,
                workout: SQWorkoutSession.mockRun,
                metric: mockMetric,
                quantityType: quantityType
            )
        }

        // Create mock chart for redacted loading state with unique IDs
        let mockPoints: [LineChartIdentifiablePoint] = (1...10).map { index in
            let timestamp = Date().addingTimeInterval(-Double(index) * 86400).timeIntervalSince1970 // Each day apart
            return LineChartIdentifiablePoint(
                id: "mock-chart-\(index)", // Unique ID for each mock point
                point: CGPoint(x: timestamp, y: mockMetric.value + Double(index) * 0.5)
            )
        }

        chartModel = LineChartModel(
            width: chartWidth,
            height: chartHeight,
            lineTitle: quantityType.displayTitle,
            uiConfig: buildChartUIConfig(),
            inputPoints: mockPoints,
            gridConfig: GridConfig(),
            focusConfig: buildFocusConfig()
        )

        chartTitle = quantityType.displayTitle
        chartSubtitle = "Loading..."

        SQLogger.shared.log(
            "Loading leaderboard for \(quantityType.displayTitle) - \(activityType.name)",
            .info,
            context: .workoutList
        )

        do {
            // Fetch all workouts for the activity type
            let allWorkouts = try await workoutManager.getWorkouts(
                for: .allTime,
                modelContext: context
            )

            // Filter by activity type
            let filteredWorkouts = allWorkouts.filter { $0.activityType == activityType }

            SQLogger.shared.log(
                "Found \(filteredWorkouts.count) workouts for \(activityType.name)",
                .debug,
                context: .workoutList
            )

            // Calculate metrics for each workout
            var workoutMetrics: [(workout: SQWorkoutSessionable, metric: SQWorkoutMetric)] = []

            for workout in filteredWorkouts {
                if let metric = await workout.getMetric(for: quantityType) {
                    workoutMetrics.append((workout, metric))
                }
            }

            SQLogger.shared.log(
                "Calculated metrics for \(workoutMetrics.count) workouts",
                .debug,
                context: .workoutList
            )

            // Sort based on aggregation type (minimum for pace, maximum for distance, etc.)
            let sortedMetrics: [(workout: SQWorkoutSessionable, metric: SQWorkoutMetric)]
            switch quantityType.dashboardAggregationType {
            case .minimum:
                // For pace - fastest (lowest) is best
                sortedMetrics = workoutMetrics.sorted { $0.metric.value < $1.metric.value }
            case .maximum:
                // For distance, etc. - highest is best
                sortedMetrics = workoutMetrics.sorted { $0.metric.value > $1.metric.value }
            case .sum, .average:
                // Default to descending for these types
                sortedMetrics = workoutMetrics.sorted { $0.metric.value > $1.metric.value }
            }

            // Create rows with rankings
            rows = sortedMetrics.enumerated().map { index, item in
                SQLeaderboardRowViewModel(
                    rank: index + 1,
                    workout: item.workout,
                    metric: item.metric,
                    quantityType: quantityType
                )
            }

            // Update chart header properties
            chartTitle = quantityType.displayTitle

            if let firstDate = rows.first?.workout.startDate,
               let lastDate = rows.last?.workout.startDate {
                let dateRange = "\(firstDate.formattedString(with: .medium)) - \(lastDate.formattedString(with: .medium))"
                chartSubtitle = "\(rows.count) workouts • \(dateRange)"
            } else {
                chartSubtitle = "\(rows.count) workouts"
            }

            SQLogger.shared.log(
                "✅ Leaderboard loaded with \(rows.count) ranked entries",
                .info,
                context: .workoutList,
                isPriority: true
            )

            // Build chart data from rows
            let points: [LineChartIdentifiablePoint] = rows.compactMap { row in
                guard let startDate = row.workout.startDate else {
                    return nil
                }
                return LineChartIdentifiablePoint(
                    id: row.id,
                    point: CGPoint(
                        x: startDate.timeIntervalSince1970,
                        y: row.metric.value
                    )
                )
            }

            // Only create chart if we have 2+ valid data points
            if points.count >= 2 {
                chartModel = LineChartModel(
                    width: chartWidth,
                    height: chartHeight,
                    lineTitle: quantityType.displayTitle,
                    uiConfig: buildChartUIConfig(),
                    inputPoints: points,
                    gridConfig: GridConfig(),
                    focusConfig: buildFocusConfig()
                )
            } else {
                chartModel = nil
            }

            isLoading = false
        } catch {
            SQLogger.shared.log(
                "Error loading leaderboard: \(error.localizedDescription)",
                .error,
                context: .workoutList
            )
            isLoading = false
        }
    }

    private func buildChartUIConfig() -> LineChartModel.UIConfig {
        let colorConfig = LineChartModel.ColorConfig(
            textPrimary: SQColor.textPrimary.color,
            textSecondary: SQColor.textSecondary.color,
            backgroundPrimary: SQColor.background.color,
            backgroundSecondary: SQColor.backgroundSecondary.color,
            lineColor: SQColor.accent(1).color
        )

        let fontConfig = LineChartModel.FontConfig(
            font: SQFont(type: .bodyExtraSmall).font,
            boldFont: SQFont(type: .bodySmallBold).font
        )

        return LineChartModel.UIConfig(
            colorConfig: colorConfig,
            fontConfig: fontConfig
        )
    }

    private func buildFocusConfig() -> FocusConfig {
        let xLabelBuilder: @Sendable (String, CGFloat) -> String = { id, xValue in
            let date = Date(timeIntervalSince1970: TimeInterval(xValue))
            return date.formattedString(with: .medium)
        }

        // Pre-capture formatted values (score + unit) to avoid accessing @MainActor properties in @Sendable closure
        // Use uniquingKeysWith to handle duplicate IDs (e.g., during mock loading state)
        let formattedValues: [String: String] = Dictionary(
            rows.map { ($0.id, $0.scoreAttributedString.stringValue) },
            uniquingKeysWith: { first, _ in first } // Keep first value if duplicate keys
        )

        let yLabelBuilder: @Sendable (String, CGFloat) -> String = { id, yValue in
            return formattedValues[id] ?? ""
        }

        let onFocus: @Sendable (LineChartIdentifiablePoint) -> Void = { [weak self] point in
            guard let self else { return }
            Task { @MainActor in
                // Simply set the focused workout ID from the point's ID
                self.focusedWorkoutId = point.id
            }
        }

        return FocusConfig(
            focusColor: SQColor.accent(1).color,
            xLabelBuilder: xLabelBuilder,
            yLabelBuilder: yLabelBuilder,
            onFocus: onFocus
        )
    }
}
