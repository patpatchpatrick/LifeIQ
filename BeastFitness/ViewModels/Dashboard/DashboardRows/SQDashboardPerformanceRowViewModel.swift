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

    init(vo2MaxSamples: [SQVO2MaxSample]) {
        if let latestSample = vo2MaxSamples.last {
            // Build sparkline from historical data
            let sparklineData = Self.buildSparklineData(from: vo2MaxSamples)

            // Determine classification based on VO2 max value
            let classification = Self.classifyVO2Max(latestSample.value)

            self.vitalRow = .init(
                id: "vo2max",
                emoji: "❤️",
                title: "VO2 Max",
                value: String(format: "%.1f ml/kg/min • %@", latestSample.value, classification),
                sparklineData: sparklineData
            )
        } else {
            self.vitalRow = nil
        }

        super.init(rowId: .dailyPerformance, rowType: .performance)
    }

    // MARK: - Private Helpers

    private static func buildSparklineData(from samples: [SQVO2MaxSample]) -> [Double] {
        // Take the last 14 samples or pad with the earliest value if we have fewer
        let targetCount = 14
        let values = samples.map { $0.value }

        if values.count >= targetCount {
            return Array(values.suffix(targetCount))
        } else if !values.isEmpty {
            // Pad with the first value to reach 14 data points
            let padding = Array(repeating: values.first!, count: targetCount - values.count)
            return padding + values
        } else {
            return []
        }
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
