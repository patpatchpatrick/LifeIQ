//
//  SQDashboardWeekSummaryTotalsSectionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardWeekSummaryTotalsSectionViewModel {
    let sectionTitle: String
    let totalValuesAndTrends: [TotalValueAndTrend]
    
    struct TotalValueAndTrend: Identifiable {
        let id = UUID()
        let value: AttributedString
        let trend: AttributedString
    }
    
    init(workouts: [SQWorkoutable]) {
        self.sectionTitle = "Totals"
        
        let totalSeconds = workouts.reduce(0) { partial, workout in
            partial + (workout.activeDuration ?? 0)
        }
        
         let value = Self.formatDuration(seconds: totalSeconds)
         
         let trend = AttributedString.build(
             with: "Up 52% from last week",
             font: .caption,
             color: .gray
         )
         
         self.totalValuesAndTrends = [TotalValueAndTrend(value: value, trend: trend)]
    }
}

// MARK: - Formatting

private extension SQDashboardWeekSummaryTotalsSectionViewModel {
    static func formatDuration(seconds: Double) -> AttributedString {
        let total = max(0, Int(seconds.rounded())) // guard negatives
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        
        var parts: [AttributedString] = []
        if hours > 0 {
            parts.append(numberUnit(number: hours, unit: "hr"))
        }
        // Show minutes if any, or if hours == 0 (e.g. 0 hr 15 min -> "15 min")
        if minutes > 0 || hours == 0 {
            parts.append(numberUnit(number: minutes, unit: "min"))
        }
        
        // Join with single space
        return parts.reduce(AttributedString(), { acc, next in
            if acc.characters.isEmpty { return next }
            var spaced = AttributedString(" ")
            spaced.append(next)
            var result = acc
            result.append(spaced)
            return result
        })
    }
    
    static func numberUnit(number: Int, unit: String) -> AttributedString {
        var result = AttributedString()
        
        // Bold white number
        let numberStr = AttributedString.build(
            with: "\(number)",
            font: .body.weight(.semibold),
            color: .white
        )
        // Regular gray unit (prefixed with space)
        let unitStr = AttributedString.build(
            with: " \(unit)",
            font: .body,
            color: .gray
        )
        
        result.append(numberStr)
        result.append(unitStr)
        return result
    }
}
