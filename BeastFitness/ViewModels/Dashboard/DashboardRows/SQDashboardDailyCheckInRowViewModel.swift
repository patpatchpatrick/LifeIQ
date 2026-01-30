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
    let stateRows: [SQDailyCheckInVitalRow.Model]?
    let habitRows: [SQDailyCheckInVitalRow.Model]?

    var isStateExpanded: Bool = true
    var isHabitsExpanded: Bool = true

    /// Only show the section if there's actual data to display
    var shouldShow: Bool {
        (stateRows?.isEmpty == false) || (habitRows?.isEmpty == false)
    }

    func toggleStateExpanded() {
        isStateExpanded.toggle()
    }

    func toggleHabitsExpanded() {
        isHabitsExpanded.toggle()
    }

    init(dailyCheckInStats: SQDailyCheckInStats?, context: ModelContext) {
        self.context = context

        if let dailyCheckInStats {
            canEditDailyStats = true
            callToAction = nil
            metricChips = SQMetricChip.Model.chips(from: dailyCheckInStats)

            // Build vital rows from stats, separated by group
            let rows = Self.buildVitalRows(from: dailyCheckInStats)
            stateRows = rows.state
            habitRows = rows.habits
        } else {
            canEditDailyStats = false
            metricChips = nil
            stateRows = nil
            habitRows = nil
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

    private struct VitalRowGroups {
        let state: [SQDailyCheckInVitalRow.Model]
        let habits: [SQDailyCheckInVitalRow.Model]
    }

    private static func buildVitalRows(from stats: SQDailyCheckInStats) -> VitalRowGroups {
        var stateRows: [SQDailyCheckInVitalRow.Model] = []
        var habitRows: [SQDailyCheckInVitalRow.Model] = []

        // State metrics
        // Mood
        if let moodValue = stats.values[SQMetricId.mood] {
            stateRows.append(.init(
                id: SQMetricId.mood,
                emoji: "🙂",
                title: "Mood",
                value: "\(Int(moodValue)) / 10",
                sparklineData: generateMockSparkline(currentValue: Double(moodValue))
            ))
        }

        // Energy
        if let energyValue = stats.values[SQMetricId.energy] {
            stateRows.append(.init(
                id: SQMetricId.energy,
                emoji: "⚡️",
                title: "Energy",
                value: "\(Int(energyValue)) / 10",
                sparklineData: generateMockSparkline(currentValue: Double(energyValue))
            ))
        }

        // Mental Clarity (Focus)
        if let clarityValue = stats.values[SQMetricId.mentalClarity] {
            stateRows.append(.init(
                id: SQMetricId.mentalClarity,
                emoji: "🧠",
                title: "Focus",
                value: "\(Int(clarityValue)) / 10",
                sparklineData: generateMockSparkline(currentValue: Double(clarityValue))
            ))
        }

        // Soreness (inverted scale - 0=sore, 10=fresh)
        if let sorenessValue = stats.values[SQMetricId.soreness] {
            stateRows.append(.init(
                id: SQMetricId.soreness,
                emoji: "💪",
                title: "Recovery",
                value: "\(Int(sorenessValue)) / 10",
                sparklineData: generateMockSparkline(currentValue: Double(sorenessValue))
            ))
        }

        // Sleep
        if let sleepHours = stats.values[SQMetricId.sleepHours] {
            stateRows.append(.init(
                id: SQMetricId.sleepHours,
                emoji: "😴",
                title: "Sleep",
                value: String(format: "%.1f h", sleepHours),
                sparklineData: generateMockSparkline(currentValue: Double(sleepHours), range: 4...9)
            ))
        }

        // Habit metrics
        // Alcohol
        if let alcoholValue = stats.values[SQMetricId.alcohol] {
            habitRows.append(.init(
                id: SQMetricId.alcohol,
                emoji: "🍷",
                title: "Alcohol",
                value: "\(Int(alcoholValue))",
                sparklineData: generateMockSparkline(currentValue: Double(alcoholValue), range: 0...1)
            ))
        }

        // Weed
        if let weedValue = stats.values[SQMetricId.weed] {
            habitRows.append(.init(
                id: SQMetricId.weed,
                emoji: "🌿",
                title: "Weed",
                value: "\(Int(weedValue))",
                sparklineData: generateMockSparkline(currentValue: Double(weedValue), range: 0...1)
            ))
        }

        // Porn
        if let pornValue = stats.values[SQMetricId.porn] {
            habitRows.append(.init(
                id: SQMetricId.porn,
                emoji: "📵",
                title: "Porn",
                value: "\(Int(pornValue))",
                sparklineData: generateMockSparkline(currentValue: Double(pornValue), range: 0...1)
            ))
        }

        // Caffeine
        if let caffeineValue = stats.values[SQMetricId.caffeine] {
            habitRows.append(.init(
                id: SQMetricId.caffeine,
                emoji: "☕️",
                title: "Caffeine",
                value: "\(Int(caffeineValue))",
                sparklineData: generateMockSparkline(currentValue: Double(caffeineValue), range: 0...1)
            ))
        }

        return VitalRowGroups(state: stateRows, habits: habitRows)
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
