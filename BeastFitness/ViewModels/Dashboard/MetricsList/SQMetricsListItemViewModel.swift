//
//  SQMetricsListItemViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import Foundation

struct SQMetricsListItemViewModel: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let groupTitle: String
    let metricId: String
    let isTracked: Bool
    let emoji: String?
    let sortOrder: Int

    init(metric: SQMetricDefinition, isTracked: Bool) {
        self.id = metric.id
        self.metricId = metric.id
        self.title = metric.title
        self.subtitle = Self.buildSubtitle(for: metric)
        self.groupTitle = metric.group
        self.isTracked = isTracked
        self.emoji = metric.emoji
        self.sortOrder = metric.sortOrder
    }

    private static func buildSubtitle(for metric: SQMetricDefinition) -> String {
        let periodLabel: String
        let hasMorning = metric.periods.contains(.morning)
        let hasEvening = metric.periods.contains(.evening)
        if hasMorning && hasEvening {
            periodLabel = metric.isSingleDailyValue ? "Morning & Evening (Shared)" : "Morning & Evening"
        } else if hasEvening {
            periodLabel = "Evening"
        } else {
            periodLabel = "Morning"
        }

        let kindLabel = metric.kind == .number ? "Number" : "Scale 0–\(Int(metric.max ?? 10))"
        let unit = metric.quantityUnit

        if unit != .none {
            return "\(periodLabel) • \(kindLabel) • \(unit.displayName)"
        } else {
            return "\(periodLabel) • \(kindLabel)"
        }
    }
}


private extension Float {
    var clean: String {
        if self.rounded() == self { return "\(Int(self))" }
        return String(format: "%.1f", Double(self))
    }
}
