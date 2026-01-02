//
//  SQMetricListController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import SwiftUI
import SwiftData
import BeastFitnessCore

@Observable @MainActor
final class SQMetricsListController {
    var searchText = "" {
        didSet { searchTextUpdated(searchText) }
    }

    var navigationPath = NavigationPath()
    let state: SQMetricsListStating

    private let metricsManager: SQMetricsManaging
    private(set) var hasLoadedUI = false

    private(set) var rows: [SQMetricsListItemViewModel] = []
    private(set) var allRows: [SQMetricsListItemViewModel] = []

    /// Optional hook if you want the view/controller above to react
    private let onMetricSelected: ((SQMetricDefinition) -> Void)?

    @MainActor
    static func `default`(
        state: SQMetricsListStating,
        metricsManager: SQMetricsManaging,
        onMetricSelected: ((SQMetricDefinition) -> Void)? = nil
    ) -> SQMetricsListController {
        .init(state: state, metricsManager: metricsManager, onMetricSelected: onMetricSelected)
    }

    init(
        state: SQMetricsListStating,
        metricsManager: SQMetricsManaging,
        onMetricSelected: ((SQMetricDefinition) -> Void)? = nil
    ) {
        self.state = state
        self.metricsManager = metricsManager
        self.onMetricSelected = onMetricSelected
    }

    // MARK: - Lifecycle

    /// Call from the view's `.task`/`.onAppear` (since we need ModelContext)
    func loadUI(using context: ModelContext) {
        guard !hasLoadedUI else { return }
        do {
            try metricsManager.loadIfNeeded(using: context)
            reloadRows(using: context)
            hasLoadedUI = true
        } catch {
            // If you have eventHub alerts on this screen, emit one here
            // For now, fail silently
        }
    }

    // MARK: - Rows

    func reloadRows(using context: ModelContext) {
        do {
            try metricsManager.loadIfNeeded(using: context)

            let allMetrics = metricsManager
                .allMetrics(includeArchived: false)
                .sorted { $0.sortOrder < $1.sortOrder }
            
            print("PTD Reload All Metrics", allMetrics.first(where: { $0.id == SQMetricId.soreness }))

            let built: [SQMetricsListItemViewModel] = allMetrics.map { metric in
                // ✅ IMPORTANT: don't force disable on tracked if we want toggle-to-untrack
                // If you want to keep your VM's init that sets isDisabled = isTracked,
                // we can override below.
                let vm = SQMetricsListItemViewModel(metric: metric, isTracked: metricsManager.isMetricTracked(id: metric.id))

                return vm
            }

            self.allRows = built
            self.rows = built
            searchTextUpdated(searchText)
        } catch {
            // swallow for now, or emit alert
        }
    }

    private func searchTextUpdated(_ searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rows = allRows
            return
        }

        let tokens = trimmed
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        rows = allRows
            .filter { row in
                let searchableText = [
                    row.title,
                    row.subtitle
                ]
                .joined(separator: " ")
                .lowercased()

                return tokens.allSatisfy { searchableText.contains($0) }
            }
            .sorted { $0.title < $1.title }
    }

    // MARK: - Actions

    /// Toggle tracking state when tapped: tracked -> untrack, untracked -> track
    func metricTapped(_ row: SQMetricsListItemViewModel, using context: ModelContext) {
        do {
            try metricsManager.loadIfNeeded(using: context)

            if metricsManager.isMetricTracked(id: row.metricId) {
                print("PTD Disabling Metric", row.metricId)
                try metricsManager.disableMetric(id: row.metricId, using: context)
            } else {
                print("PTD Enabling Metric", row.metricId)
                try metricsManager.enableMetric(id: row.metricId, using: context)

                if let metric = metricsManager.allMetrics(includeArchived: false).first(where: { $0.id == row.metricId }) {
                    onMetricSelected?(metric)
                }
            }
            
            print("PTD after toggle, isTracked:", metricsManager.isMetricTracked(id: row.metricId))


            reloadRows(using: context)
        } catch {
            // emit alert if desired
        }
    }
}


private extension Float {
    var clean: String {
        if self.rounded() == self { return "\(Int(self))" }
        return String(format: "%.1f", Double(self))
    }
}
