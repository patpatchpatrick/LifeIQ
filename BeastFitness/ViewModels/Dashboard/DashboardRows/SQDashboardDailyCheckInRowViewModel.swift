//
//  SQDashboardDailyCheckInRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftUI
import SwiftData

@Observable @MainActor
final class SQDashboardDailyCheckInRowViewModel: SQDashboardRowViewModel {
    let callToAction: SQCallToActionViewModel?
    let context: ModelContext
    let canEditDailyStats: Bool
    let metricChips: [SQMetricChip.Model]?
    let vitalRows: [SQDailyCheckInVitalRow.Model]?
    let summaryText: String?

    init(dailyCheckInStats: SQDailyCheckInStats?, context: ModelContext) {
        self.context = context

        if let dailyCheckInStats {
            canEditDailyStats = true
            callToAction = nil
            metricChips = SQMetricChip.Model.chips(from: dailyCheckInStats)
            
            // Build vital rows from stats
            vitalRows = Self.buildVitalRows(from: dailyCheckInStats)
            summaryText = Self.buildSummaryText(from: dailyCheckInStats)
        } else {
            canEditDailyStats = false
            metricChips = nil
            vitalRows = nil
            summaryText = nil
            callToAction = .init(
                title: "Complete daily check-in",
                /// Don't use weak self here; controller can be temporary.
                onTap: {
                    Task { await SQDashboardController.default.displayDailyCheckInSheet(for: context) }
                }
            )
        }

        super.init(rowId: .dailyCheckInStats, rowType: .dailyCheckInStats)
    }

    func editDailyCheckInStats() async {
        await SQDashboardController.default.displayDailyCheckInSheet(for: context)
    }
    
    // MARK: - Private Helpers
    
    private static func buildVitalRows(from stats: SQDailyCheckInStats) -> [SQDailyCheckInVitalRow.Model] {
        var rows: [SQDailyCheckInVitalRow.Model] = []
        
        // Mood
        if let moodValue = stats.values[SQMetricId.mood] {
            rows.append(.init(
                id: SQMetricId.mood,
                emoji: "🙂",
                title: "Mood",
                value: "\(Int(moodValue)) / 10",
                sparklineData: generateMockSparkline(currentValue: Double(moodValue))
            ))
        }
        
        // Energy
        if let energyValue = stats.values[SQMetricId.energy] {
            rows.append(.init(
                id: SQMetricId.energy,
                emoji: "⚡️",
                title: "Energy",
                value: "\(Int(energyValue)) / 10",
                sparklineData: generateMockSparkline(currentValue: Double(energyValue))
            ))
        }
        
        // Mental Clarity (Focus)
        if let clarityValue = stats.values[SQMetricId.mentalClarity] {
            rows.append(.init(
                id: SQMetricId.mentalClarity,
                emoji: "🧠",
                title: "Focus",
                value: "\(Int(clarityValue)) / 10",
                sparklineData: generateMockSparkline(currentValue: Double(clarityValue))
            ))
        }
        
        // Soreness (inverted scale - 0=sore, 10=fresh)
        if let sorenessValue = stats.values[SQMetricId.soreness] {
            rows.append(.init(
                id: SQMetricId.soreness,
                emoji: "💪",
                title: "Recovery",
                value: "\(Int(sorenessValue)) / 10",
                sparklineData: generateMockSparkline(currentValue: Double(sorenessValue))
            ))
        }
        
        // Sleep
        if let sleepHours = stats.values[SQMetricId.sleepHours] {
            rows.append(.init(
                id: SQMetricId.sleepHours,
                emoji: "😴",
                title: "Sleep",
                value: String(format: "%.1f h", sleepHours),
                sparklineData: generateMockSparkline(currentValue: Double(sleepHours), range: 4...9)
            ))
        }
        
        // Alcohol (if tracked)
        if let alcoholValue = stats.values[SQMetricId.alcohol] {
            rows.append(.init(
                id: SQMetricId.alcohol,
                emoji: "🍷",
                title: "Alcohol",
                value: "\(Int(alcoholValue))",
                sparklineData: generateMockSparkline(currentValue: Double(alcoholValue), range: 0...5)
            ))
        }
        
        return rows
    }
    
    private static func buildSummaryText(from stats: SQDailyCheckInStats) -> String? {
        // Simple heuristic based on average of mood, energy, focus
        let mood = stats.values[SQMetricId.mood].map(Double.init) ?? 5
        let energy = stats.values[SQMetricId.energy].map(Double.init) ?? 5
        let focus = stats.values[SQMetricId.mentalClarity].map(Double.init) ?? 5
        
        let average = (mood + energy + focus) / 3
        
        if average >= 7.5 {
            return "Feeling strong today"
        } else if average >= 6 {
            return "Steady progress"
        } else if average >= 4 {
            return "Taking it easy"
        } else {
            return "Recovery mode"
        }
    }
    
    /// Generates mock sparkline data with realistic variation
    /// Last value will match currentValue
    private static func generateMockSparkline(currentValue: Double, range: ClosedRange<Double> = 0...10) -> [Double] {
        let days = 14
        var values: [Double] = []
        
        // Generate variation around current value
        for i in 0..<(days - 1) {
            let variation = Double.random(in: -1.5...1.5)
            let value = max(range.lowerBound, min(range.upperBound, currentValue + variation))
            values.append(value)
        }
        
        // Last value is current
        values.append(currentValue)
        
        return values
    }
}
