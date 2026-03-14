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
    let metricId: String
    let isTracked: Bool
    let emoji: String?

    init(metric: SQMetricDefinition, isTracked: Bool) {
        self.id = metric.id
        self.metricId = metric.id
        self.title = metric.title
        self.subtitle = Self.buildSubtitle(for: metric)
        self.isTracked = isTracked
        self.emoji = metric.emoji
    }

    private static func buildSubtitle(for metric: SQMetricDefinition) -> String {
        let periodLabel = metric.period == .morning ? "Morning" : "Evening"
        let kindLabel = metric.kind == .number ? "Number" : "Scale 0–\(Int(metric.max ?? 10))"

        if metric.unit != .none {
            return "\(periodLabel) • \(kindLabel) • \(metric.unit.rawValue.capitalized)"
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
