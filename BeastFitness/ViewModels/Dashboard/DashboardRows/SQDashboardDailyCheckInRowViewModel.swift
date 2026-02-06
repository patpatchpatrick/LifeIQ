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

    init(
        dailyCheckInStats: SQDailyCheckInStats?,
        historicalStats: [SQDailyCheckInStats] = [],
        context: ModelContext
    ) {
        self.context = context

        if let dailyCheckInStats {
            canEditDailyStats = true
            callToAction = nil
            metricChips = SQMetricChip.Model.chips(from: dailyCheckInStats)

            // Build vital rows from stats with real sparklines from historical data
            let rows = Self.buildVitalRows(
                from: dailyCheckInStats,
                historicalStats: historicalStats
            )
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

    private static func buildVitalRows(
        from stats: SQDailyCheckInStats,
        historicalStats: [SQDailyCheckInStats]
    ) -> VitalRowGroups {
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
                sparklineData: buildSparkline(
                    for: SQMetricId.mood,
                    from: historicalStats,
                    currentValue: moodValue
                )
            ))
        }

        // Energy
        if let energyValue = stats.values[SQMetricId.energy] {
            stateRows.append(.init(
                id: SQMetricId.energy,
                emoji: "⚡️",
                title: "Energy",
                value: "\(Int(energyValue)) / 10",
                sparklineData: buildSparkline(
                    for: SQMetricId.energy,
                    from: historicalStats,
                    currentValue: energyValue
                )
            ))
        }

        // Mental Clarity (Focus)
        if let clarityValue = stats.values[SQMetricId.mentalClarity] {
            stateRows.append(.init(
                id: SQMetricId.mentalClarity,
                emoji: "🧠",
                title: "Focus",
                value: "\(Int(clarityValue)) / 10",
                sparklineData: buildSparkline(
                    for: SQMetricId.mentalClarity,
                    from: historicalStats,
                    currentValue: clarityValue
                )
            ))
        }

        // Soreness (inverted scale - 0=sore, 10=fresh)
        if let sorenessValue = stats.values[SQMetricId.soreness] {
            stateRows.append(.init(
                id: SQMetricId.soreness,
                emoji: "💪",
                title: "Recovery",
                value: "\(Int(sorenessValue)) / 10",
                sparklineData: buildSparkline(
                    for: SQMetricId.soreness,
                    from: historicalStats,
                    currentValue: sorenessValue
                )
            ))
        }

        // Sleep
        if let sleepHours = stats.values[SQMetricId.sleepHours] {
            stateRows.append(.init(
                id: SQMetricId.sleepHours,
                emoji: "😴",
                title: "Sleep",
                value: String(format: "%.1f h", sleepHours),
                sparklineData: buildSparkline(
                    for: SQMetricId.sleepHours,
                    from: historicalStats,
                    currentValue: sleepHours
                )
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
                sparklineData: buildSparkline(
                    for: SQMetricId.alcohol,
                    from: historicalStats,
                    currentValue: alcoholValue
                )
            ))
        }

        // Weed
        if let weedValue = stats.values[SQMetricId.weed] {
            habitRows.append(.init(
                id: SQMetricId.weed,
                emoji: "🌿",
                title: "Weed",
                value: "\(Int(weedValue))",
                sparklineData: buildSparkline(
                    for: SQMetricId.weed,
                    from: historicalStats,
                    currentValue: weedValue
                )
            ))
        }

        // Porn
        if let pornValue = stats.values[SQMetricId.porn] {
            habitRows.append(.init(
                id: SQMetricId.porn,
                emoji: "📵",
                title: "Porn",
                value: "\(Int(pornValue))",
                sparklineData: buildSparkline(
                    for: SQMetricId.porn,
                    from: historicalStats,
                    currentValue: pornValue
                )
            ))
        }

        // Caffeine
        if let caffeineValue = stats.values[SQMetricId.caffeine] {
            habitRows.append(.init(
                id: SQMetricId.caffeine,
                emoji: "☕️",
                title: "Caffeine",
                value: "\(Int(caffeineValue))",
                sparklineData: buildSparkline(
                    for: SQMetricId.caffeine,
                    from: historicalStats,
                    currentValue: caffeineValue
                )
            ))
        }

        return VitalRowGroups(state: stateRows, habits: habitRows)
    }
    
    /// Builds real sparkline data from historical check-ins
    /// Returns the last 14 days of values for the specified metric
    private static func buildSparkline(
        for metricId: String,
        from historicalStats: [SQDailyCheckInStats],
        currentValue: Float
    ) -> [Double] {
        // Sort by date ascending (oldest to newest)
        let sortedStats = historicalStats.sorted { $0.date < $1.date }

        // Take last 14 days (or less if not enough data)
        let recentStats = sortedStats.suffix(14)

        // Extract values for this metric
        let values = recentStats.compactMap { stat -> Double? in
            guard let value = stat.values[metricId] else { return nil }
            return Double(value)
        }

        // If we have data, return it
        if !values.isEmpty {
            return values
        }

        // Fallback: if no historical data, just return current value
        return [Double(currentValue)]
    }
}
