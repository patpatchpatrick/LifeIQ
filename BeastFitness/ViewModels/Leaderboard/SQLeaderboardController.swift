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
    let chartWidth: CGFloat = 350
    let chartHeight: CGFloat = 220
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
        hub.workoutEvents.sink { [weak self] event in
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
            let points: [CGPoint] = rows.compactMap { row in
                guard let startDate = row.workout.startDate else { return nil }
                return CGPoint(
                    x: startDate.timeIntervalSince1970,
                    y: row.metric.value
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

                SQLogger.shared.log(
                    "Created chart with \(points.count) data points",
                    .debug,
                    context: .workoutList
                )
            } else {
                chartModel = nil
                SQLogger.shared.log(
                    "Insufficient data for chart (\(points.count) points, need 2+)",
                    .debug,
                    context: .workoutList
                )
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
        let xLabelBuilder: @Sendable (CGFloat) -> String = { xValue in
            let date = Date(timeIntervalSince1970: TimeInterval(xValue))
            return date.formattedString(with: .medium)
        }

        let yLabelBuilder: @Sendable (CGFloat) -> String = { [quantityType] yValue in
            // Create a temporary metric to format the value properly
            let mockMetric = SQWorkoutMetric(
                quantityType: quantityType,
                displayName: "",
                unit: quantityType.unit ?? .count,
                value: Double(yValue)
            )
            return mockMetric.displayableValue(for: quantityType, value: Double(yValue))
        }

        let onFocus: @Sendable (CGPoint) -> Void = { [weak self] tappedPoint in
            guard let self else { return }
            Task { @MainActor in
                
                let timestamp = TimeInterval(tappedPoint.x)

                // Find the workout that matches this timestamp
                let focusedRow = self.rows.first { row in
                    print("PTD Focused Row 0", row.workout.startDate)
                    guard let startDate = row.workout.startDate else { return false }
                    print("PTD Focused Row 1", abs(startDate.timeIntervalSince1970 - timestamp) < 1.0)
                    return abs(startDate.timeIntervalSince1970 - timestamp) < 1.0 // Within 1 second tolerance
                }
                print("PTD Focused Row 2", focusedRow)
                self.focusedWorkoutId = focusedRow?.workout.id
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
