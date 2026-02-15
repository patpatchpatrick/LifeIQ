//
//  SQDashboardMetricPerformanceRowViewModel.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-15.
//

import SwiftUI
import HealthKit
import BeastFitnessCore

@Observable @MainActor
final class SQDashboardMetricPerformanceRowViewModel: SQDashboardRowViewModel {
    let metricId: String

    /// Emoji or SF Symbol name for the metric
    let icon: String

    /// Metric name (e.g., "VO2 Max", "Pace")
    let title: String

    /// Best value as formatted string (e.g., "7:30", "45.3")
    let bestValue: String

    /// Unit of measurement (e.g., "/mi", "mL/kg/min")
    let unit: String

    /// Percentile rank (0.0 to 1.0), nil if insufficient data
    let percentileRank: Double?

    /// Optional quantity type for performance metrics (used for leaderboard)
    let quantityType: SQQuantityType?

    /// Optional activity type for performance metrics (used for leaderboard)
    let activityType: HKWorkoutActivityType?

    init(
        metricId: String,
        icon: String,
        title: String,
        bestValue: String,
        unit: String,
        percentileRank: Double?,
        quantityType: SQQuantityType? = nil,
        activityType: HKWorkoutActivityType? = nil
    ) {
        self.metricId = metricId
        self.icon = icon
        self.title = title
        self.bestValue = bestValue
        self.unit = unit
        self.percentileRank = percentileRank
        self.quantityType = quantityType
        self.activityType = activityType

        super.init(rowId: .metricPerformance, rowType: .metricPerformance)
    }
}
