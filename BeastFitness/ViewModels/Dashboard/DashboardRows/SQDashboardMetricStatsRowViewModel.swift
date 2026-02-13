//
//  SQDashboardMetricStatsRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//

import SwiftUI
import HealthKit
import BeastFitnessCore

@Observable @MainActor
final class SQDashboardMetricStatsRowViewModel: SQDashboardRowViewModel {
    let metricId: String

    /// Emoji or SF Symbol name for the metric
    let icon: String

    /// Metric name (e.g., "Mood", "Energy")
    let title: String

    /// Average value as formatted string (e.g., "7.5")
    let avgValue: String

    /// Unit of measurement (e.g., "/10", "hrs")
    let unit: String

    /// Data points for sparkline chart visualization
    let sparklineData: [Double]

    /// 14-day percentage change (e.g., 0.15 for +15%)
    let change14d: Double

    /// Optional quantity type for performance metrics (used for leaderboard)
    let quantityType: SQQuantityType?

    /// Optional activity type for performance metrics (used for leaderboard)
    let activityType: HKWorkoutActivityType?


    init(
        metricId: String,
        icon: String,
        title: String,
        avgValue: String,
        unit: String,
        sparklineData: [Double],
        change14d: Double,
        quantityType: SQQuantityType? = nil,
        activityType: HKWorkoutActivityType? = nil
    ) {
        self.metricId = metricId
        self.icon = icon
        self.title = title
        self.avgValue = avgValue
        self.unit = unit
        self.sparklineData = sparklineData
        self.change14d = change14d
        self.quantityType = quantityType
        self.activityType = activityType

        super.init(rowId: .metricStats, rowType: .metricStats)
    }

}
