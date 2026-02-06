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
        timeRange: DashboardTimeRange = .today,
        context: ModelContext
    ) {
        self.context = context

        // For multi-day ranges, use historical data to show averages
        let shouldShowAverages = timeRange != .today
        let statsToUse = shouldShowAverages ? historicalStats : (dailyCheckInStats.map { [$0] } ?? [])

        if !statsToUse.isEmpty {
            canEditDailyStats = timeRange == .today && dailyCheckInStats != nil
            callToAction = nil

            // Build vital rows from stats with real sparklines from historical data
            let rows = Self.buildVitalRows(
                from: statsToUse,
                historicalStats: historicalStats,
                showAverages: shouldShowAverages
            )
            stateRows = rows.state
            habitRows = rows.habits
        } else {
            canEditDailyStats = false
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
        from stats: [SQDailyCheckInStats],
        historicalStats: [SQDailyCheckInStats],
        showAverages: Bool
    ) -> VitalRowGroups {
        var stateRows: [SQDailyCheckInVitalRow.Model] = []
        var habitRows: [SQDailyCheckInVitalRow.Model] = []

        // Helper to get value and formatted string
        func getValue(for metricId: String) -> (value: Float, formatted: String)? {
            let values = stats.compactMap { $0.values[metricId] }
            guard !values.isEmpty else { return nil }

            let avgValue = values.reduce(0, +) / Float(values.count)
            let formatted = showAverages
                ? String(format: "%.1f / 10", avgValue)
                : "\(Int(values.last!)) / 10"
            return (avgValue, formatted)
        }

        // State metrics
        // Mood
        if let result = getValue(for: SQMetricId.mood) {
            stateRows.append(.init(
                id: SQMetricId.mood,
                emoji: "🙂",
                title: "Mood",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.mood,
                    from: historicalStats,
                    currentValue: result.value
                )
            ))
        }

        // Energy
        if let result = getValue(for: SQMetricId.energy) {
            stateRows.append(.init(
                id: SQMetricId.energy,
                emoji: "⚡️",
                title: "Energy",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.energy,
                    from: historicalStats,
                    currentValue: result.value
                )
            ))
        }

        // Mental Clarity (Focus)
        if let result = getValue(for: SQMetricId.mentalClarity) {
            stateRows.append(.init(
                id: SQMetricId.mentalClarity,
                emoji: "🧠",
                title: "Focus",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.mentalClarity,
                    from: historicalStats,
                    currentValue: result.value
                )
            ))
        }

        // Soreness (inverted scale - 0=sore, 10=fresh)
        if let result = getValue(for: SQMetricId.soreness) {
            stateRows.append(.init(
                id: SQMetricId.soreness,
                emoji: "💪",
                title: "Recovery",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.soreness,
                    from: historicalStats,
                    currentValue: result.value
                )
            ))
        }

        // Sleep - special formatting
        func getSleepValue() -> (value: Float, formatted: String)? {
            let values = stats.compactMap { $0.values[SQMetricId.sleepHours] }
            guard !values.isEmpty else { return nil }

            let avgValue = values.reduce(0, +) / Float(values.count)
            let displayValue = showAverages ? avgValue : values.last!
            return (avgValue, String(format: "%.1f h", displayValue))
        }

        if let result = getSleepValue() {
            stateRows.append(.init(
                id: SQMetricId.sleepHours,
                emoji: "😴",
                title: "Sleep",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.sleepHours,
                    from: historicalStats,
                    currentValue: result.value
                )
            ))
        }

        // Habit metrics - 0/1 values
        func getHabitValue(for metricId: String) -> (value: Float, formatted: String)? {
            let values = stats.compactMap { $0.values[metricId] }
            guard !values.isEmpty else { return nil }

            let avgValue = values.reduce(0, +) / Float(values.count)
            let formatted = showAverages
                ? String(format: "%.1f", avgValue)
                : "\(Int(values.last!))"
            return (avgValue, formatted)
        }

        // Alcohol
        if let result = getHabitValue(for: SQMetricId.alcohol) {
            habitRows.append(.init(
                id: SQMetricId.alcohol,
                emoji: "🍷",
                title: "Alcohol",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.alcohol,
                    from: historicalStats,
                    currentValue: result.value
                )
            ))
        }

        // Weed
        if let result = getHabitValue(for: SQMetricId.weed) {
            habitRows.append(.init(
                id: SQMetricId.weed,
                emoji: "🌿",
                title: "Weed",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.weed,
                    from: historicalStats,
                    currentValue: result.value
                )
            ))
        }

        // Porn
        if let result = getHabitValue(for: SQMetricId.porn) {
            habitRows.append(.init(
                id: SQMetricId.porn,
                emoji: "📵",
                title: "Porn",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.porn,
                    from: historicalStats,
                    currentValue: result.value
                )
            ))
        }

        // Caffeine
        if let result = getHabitValue(for: SQMetricId.caffeine) {
            habitRows.append(.init(
                id: SQMetricId.caffeine,
                emoji: "☕️",
                title: "Caffeine",
                value: result.formatted,
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: SQMetricId.caffeine,
                    from: historicalStats,
                    currentValue: result.value
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
