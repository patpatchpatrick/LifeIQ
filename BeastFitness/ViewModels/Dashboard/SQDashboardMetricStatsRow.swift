//
//  SQDashboardMetricStatsRow.swift
//  BeastFitness
//
//  Created by Claude on 2026-02-06.
//

import Foundation

/// View model representing a single metric stats row in the dashboard.
/// Displays daily check-in metric statistics with sparkline visualization.
struct SQDashboardMetricStatsRow: Identifiable {
    /// Unique identifier for the row
    let id: String

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

    init(
        id: String,
        icon: String,
        title: String,
        avgValue: String,
        unit: String,
        sparklineData: [Double],
        change14d: Double
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.avgValue = avgValue
        self.unit = unit
        self.sparklineData = sparklineData
        self.change14d = change14d
    }
}
