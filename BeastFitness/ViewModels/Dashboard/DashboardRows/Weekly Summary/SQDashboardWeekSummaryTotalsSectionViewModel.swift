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
    
    init(workouts: [SQWorkoutable], priorWorkouts: [SQWorkoutable]) {
        self.sectionTitle = "Totals"
        

        let totalSeconds = workouts.reduce(0) { $0 + ($1.activeDuration ?? 0) }
        let totalSecondsPriorWeek = priorWorkouts.reduce(0) { $0 + ($1.activeDuration ?? 0) }
        
        let totalKilocalories = workouts.reduce(0) { $0 + ($1.totalCalories ?? 0) }
        let totalKilocaloriesPriorWeek = priorWorkouts.reduce(0) { $0 + ($1.totalCalories ?? 0) }

        let totalTimeValue = Self.formatDuration(seconds: totalSeconds)
        let totalTimeTrend = Self.buildTrend(
            currentSeconds: totalSeconds,
            previousSeconds: totalSecondsPriorWeek
        )
        
        let totalKilocaloriesValue = Self.formatKilocalories(totalKilocalories: totalKilocalories)
        let totalKilocaliresTrend = Self.buildTrend(
            currentSeconds: totalKilocalories,
            previousSeconds: totalKilocaloriesPriorWeek
        )
         
         self.totalValuesAndTrends = [
            TotalValueAndTrend(value: totalTimeValue, trend: totalTimeTrend),
            TotalValueAndTrend(value: totalKilocaloriesValue, trend: totalKilocaliresTrend)
         ]
    }
}

// MARK: - Formatting

private extension SQDashboardWeekSummaryTotalsSectionViewModel {
    static func formatDuration(seconds: Double) -> AttributedString {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        
        var parts: [AttributedString] = []
        if hours > 0 {
            parts.append(numberUnit(number: hours, unit: "hr"))
        }
        if minutes > 0 || hours == 0 {
            parts.append(numberUnit(number: minutes, unit: "min"))
        }
        
        // Styled spacer so it doesn't pull in default line metrics
        let spacer = AttributedString.build(
            with: " ",
            font: SQFont(type: .bodySmall).font,
            color: SQColor.textSecondary.color
        )
        
        return parts.reduce(AttributedString(), { acc, next in
            if acc.characters.isEmpty { return next }
            var result = acc
            result.append(spacer)
            result.append(next)
            return result
        })
    }
    
    static func formatKilocalories(totalKilocalories: Double) -> AttributedString {
        let kcal = max(0, Int(totalKilocalories.rounded())) // guard negatives
        
        // Reuse numberUnit for consistent styling: "500 kcal"
        return numberUnit(number: kcal, unit: "kcal")
    }
    
    static func numberUnit(number: Int, unit: String) -> AttributedString {
        var result = AttributedString()
        
        // Bold white number
        let numberStr = AttributedString.build(
            with: "\(number)",
            font: SQFont(type: .bodySmallBold).font,
            color: SQColor.textPrimary.color
        )
        // Regular gray unit (prefixed with space)
        let unitStr = AttributedString.build(
            with: " \(unit)",
            font: SQFont(type: .bodySmall).font,
            color: SQColor.textSecondary.color
        )
        
        result.append(numberStr)
        result.append(unitStr)
        return result
    }
    
    static func buildTrend(
        currentSeconds: Double,
        previousSeconds: Double
    ) -> AttributedString {
        // No prior data
        guard previousSeconds > 0 else {
            return AttributedString.build(
                with: "No data from last week",
                font: SQFont(type: .bodySmall).font,
                color: SQColor.textSecondary.color
            )
        }

        let delta = currentSeconds - previousSeconds
        let ratio = delta / previousSeconds           // e.g. 0.52 for +52%
        let percent = ratio

        // If basically flat
        if abs(percent) < 0.01 {
            return AttributedString.build(
                with: "About the same as last week",
                font: SQFont(type: .bodySmall).font,
                color: SQColor.textSecondary.color
            )
        }

        let direction = percent > 0 ? "Up" : "Down"
        let percentString = abs(percent).toPercentageString() // e.g. "52.0%"

        // Colors/fonts
        let baseFont = SQFont(type: .bodySmall).font
        let baseColor = SQColor.textPrimary.color
        let pctColor = SQColor.colorGreenRed(percent: percent * 4).color
        let pctFont = SQFont(type: .bodySmallBold).font

        // Build pieces: "Up " + "52%" + " from last week"
        var result = AttributedString()

        let prefix = AttributedString.build(
            with: "\(direction) ",
            font: baseFont,
            color: baseColor
        )

        let percentAttr = AttributedString.build(
            with: percentString,            // already includes "%"
            font: pctFont,
            color: pctColor
        )

        let suffix = AttributedString.build(
            with: " from last week",
            font: baseFont,
            color: baseColor
        )

        result.append(prefix)
        result.append(percentAttr)
        result.append(suffix)

        return result
    }
}
