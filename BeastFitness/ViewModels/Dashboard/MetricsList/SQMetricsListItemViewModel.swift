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
        let kind = metric.kind.rawValue.capitalized
        let unit = metric.unit == .none ? "No unit" : metric.unit.rawValue.capitalized
        if let min = metric.min, let max = metric.max {
            return "\(kind) • \(unit) • \(min.clean)–\(max.clean)"
        } else {
            return "\(kind) • \(unit)"
        }
    }
}


private extension Float {
    var clean: String {
        if self.rounded() == self { return "\(Int(self))" }
        return String(format: "%.1f", Double(self))
    }
}
