//
//  SQDashboardPerformanceRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardDailyPerformanceRowViewModel: SQDashboardRowViewModel {
    let vitalRow: SQDailyCheckInVitalRow.Model?

    var isExpanded: Bool = true
    func toggleExpanded() {
        isExpanded.toggle()
    }

    init(
        vo2MaxSamples: [SQVO2MaxSample],
        timeRange: DashboardTimeRange = .today
    ) {
        if !vo2MaxSamples.isEmpty {
            // Calculate value (latest or average based on time range)
            let shouldShowAverage = timeRange != .today
            let displayValue: Double?
            let subtitle: String?

            if shouldShowAverage {
                // Calculate average for multi-day ranges
                let sum = vo2MaxSamples.reduce(0.0) { $0 + $1.value }
                displayValue = sum / Double(vo2MaxSamples.count)
                subtitle = "avg"
            } else {
                // Use latest value for today
                displayValue = vo2MaxSamples.last?.value
                subtitle = nil
            }

            // Build sparkline from historical data
            let sparklineData = Self.buildSparklineData(from: vo2MaxSamples)

            if let value = displayValue {
                // Determine classification based on VO2 max value
                let classification = Self.classifyVO2Max(value)

                self.vitalRow = .init(
                    id: "vo2max",
                    emoji: "❤️",
                    title: "VO2 Max",
                    value: String(format: "%.1f ml/kg/min • %@", value, classification),
                    subtitle: subtitle,
                    sparklineData: sparklineData
                )
            } else {
                self.vitalRow = nil
            }
        } else {
            self.vitalRow = nil
        }

        super.init(rowId: .dailyPerformance, rowType: .performance)
    }

    // MARK: - Private Helpers

    private static func buildSparklineData(from samples: [SQVO2MaxSample]) -> [Double] {
        // Return actual sample values for sparkline
        return samples.map { $0.value }
    }

    private static func classifyVO2Max(_ value: Double) -> String {
        // General VO2 max classifications (simplified, could be age/gender adjusted)
        // Source: American Heart Association guidelines
        if value >= 45 {
            return "Excellent"
        } else if value >= 38 {
            return "Good"
        } else if value >= 32 {
            return "Average"
        } else if value >= 26 {
            return "Below Average"
        } else {
            return "Poor"
        }
    }
}
