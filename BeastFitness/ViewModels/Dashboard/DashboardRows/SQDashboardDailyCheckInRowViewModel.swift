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

    /// Ordered list of metric groups with their vital rows.
    let groups: [VitalGroup]

    /// Groups the user has collapsed; all others are expanded by default.
    var collapsedGroups: Set<String> = []

    /// Only show the section if there's actual data to display
    var shouldShow: Bool {
        !groups.isEmpty
    }

    func isExpanded(_ group: String) -> Bool {
        !collapsedGroups.contains(group)
    }

    func toggleGroup(_ group: String) {
        if collapsedGroups.contains(group) {
            collapsedGroups.remove(group)
        } else {
            collapsedGroups.insert(group)
        }
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

            self.groups = Self.buildVitalGroups(
                from: statsToUse,
                historicalStats: historicalStats,
                showAverages: shouldShowAverages
            )
        } else {
            canEditDailyStats = false
            self.groups = []
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

    // MARK: - Types

    struct VitalGroup: Identifiable {
        let id: String   // group name (e.g. "Self", "Habit")
        var name: String { id }
        let rows: [SQDailyCheckInVitalRow.Model]
    }

    // MARK: - Private Helpers

    private static func buildVitalGroups(
        from stats: [SQDailyCheckInStats],
        historicalStats: [SQDailyCheckInStats],
        showAverages: Bool
    ) -> [VitalGroup] {
        let definitions = SQMetricsManager.shared.dailyCheckInMetrics()

        var groupedRows: [String: [SQDailyCheckInVitalRow.Model]] = [:]
        var groupOrder: [String] = []   // preserve first-appearance order

        for def in definitions {
            let values = stats.compactMap { $0.values[def.id] }
            guard !values.isEmpty else { continue }

            let avgValue = values.reduce(0, +) / Float(values.count)
            let displayValue = showAverages ? avgValue : values.last!

            let row = SQDailyCheckInVitalRow.Model(
                id: def.id,
                emoji: def.emoji ?? fallbackEmoji(for: def),
                title: def.title,
                value: formatValue(
                    display: displayValue,
                    avg: avgValue,
                    definition: def,
                    showAverage: showAverages
                ),
                subtitle: showAverages ? "avg" : nil,
                sparklineData: buildSparkline(
                    for: def.id,
                    from: historicalStats,
                    currentValue: avgValue
                )
            )

            if groupedRows[def.group] == nil {
                groupedRows[def.group] = []
                groupOrder.append(def.group)
            }
            groupedRows[def.group]!.append(row)
        }

        return groupOrder.compactMap { group in
            guard let rows = groupedRows[group], !rows.isEmpty else { return nil }
            return VitalGroup(id: group, rows: rows)
        }
    }

    private static func formatValue(display: Float, avg: Float, definition: SQMetricDefinition, showAverage: Bool) -> String {
        switch definition.kind {
        case .binary:
            return showAverage
                ? String(format: "%.1f", avg)
                : "\(Int(display))"

        case .scale:
            let maxVal = definition.max.map { "\(Int($0))" } ?? "10"
            return showAverage
                ? String(format: "%.1f / \(maxVal)", avg)
                : "\(Int(display)) / \(maxVal)"

        case .number:
            let suffix = unitSuffix(for: definition.unit)
            let numStr: String
            if showAverage {
                numStr = String(format: "%.1f", avg)
            } else {
                numStr = display.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(display))"
                    : String(format: "%.1f", display)
            }
            return suffix.isEmpty ? numStr : "\(numStr) \(suffix)"
        }
    }

    private static func unitSuffix(for unit: SQMetricUnit) -> String {
        switch unit {
        case .hours:     return "h"
        case .pounds:    return "lbs"
        case .kilograms: return "kg"
        case .percent:   return "%"
        case .count, .none: return ""
        }
    }

    private static func fallbackEmoji(for def: SQMetricDefinition) -> String {
        switch def.kind {
        case .binary: return "✓"
        case .scale:  return "📊"
        case .number: return "🔢"
        }
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
