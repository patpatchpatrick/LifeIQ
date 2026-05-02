//
//  SQMetricListController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import SwiftUI
import SwiftData
import Combine
import BeastFitnessCore

struct SQMetricsListSectionViewModel: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let rows: [SQMetricsListItemViewModel]
    let isTrackedSection: Bool

    var count: Int { rows.count }
}

@Observable @MainActor
final class SQMetricsListController {
    var searchText = "" {
        didSet { searchTextUpdated(searchText) }
    }

    var navigationPath = NavigationPath()
    let state: SQMetricsListStating

    let metricsManager: SQMetricDefinitionManaging
    private(set) var hasLoadedUI = false

    private(set) var rows: [SQMetricsListItemViewModel] = []
    private(set) var allRows: [SQMetricsListItemViewModel] = []
    private(set) var sections: [SQMetricsListSectionViewModel] = []
    private(set) var trackedCount: Int = 0
    private var collapsedSectionIds = Set<String>()

    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    private var hub: EventHub { SQAppState.shared.hub }

    /// Optional hook if you want the view/controller above to react
    private let onMetricSelected: ((SQMetricDefinition) -> Void)?

    @MainActor
    static func `default`(
        state: SQMetricsListStating,
        metricsManager: SQMetricDefinitionManaging,
        onMetricSelected: ((SQMetricDefinition) -> Void)? = nil
    ) -> SQMetricsListController {
        .init(state: state, metricsManager: metricsManager, onMetricSelected: onMetricSelected)
    }

    init(
        state: SQMetricsListStating,
        metricsManager: SQMetricDefinitionManaging,
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
        self.modelContext = context
        do {
            try metricsManager.loadIfNeeded(using: context)
            reloadRows(using: context)
            hasLoadedUI = true
            subscribeToMetricEvents()
        } catch {
            SQLogger.shared.log(
                "Failed to load metrics list: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn
            )
            presentError("Error loading metrics: \(error.localizedDescription)")
        }
    }

    private func subscribeToMetricEvents() {
        hub.metricEvents.sink { [weak self] event in
            guard let self, let context = self.modelContext else { return }
            switch event {
            case .metricsUpdated:
                self.reloadRows(using: context)
            case .metricEntriesUpdated, .lifeScoreInputsUpdated:
                break
            }
        }.store(in: &cancellables)
    }

    // MARK: - Rows

    func reloadRows(using context: ModelContext) {
        do {
            try metricsManager.loadIfNeeded(using: context)

            let allMetrics = metricsManager
                .allMetrics(includeArchived: false)
                .sorted {
                    if $0.sortOrder == $1.sortOrder {
                        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                    return $0.sortOrder < $1.sortOrder
                }

            let built: [SQMetricsListItemViewModel] = allMetrics.map { metric in
                SQMetricsListItemViewModel(
                    metric: metric,
                    isTracked: metricsManager.isMetricTracked(id: metric.id)
                )
            }

            self.allRows = built
            self.rows = built
            self.trackedCount = built.filter(\.isTracked).count
            searchTextUpdated(searchText)
        } catch {
            SQLogger.shared.log(
                "Failed to refresh metrics list: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn
            )
            presentError("Error refreshing metrics: \(error.localizedDescription)")
        }
    }

    private func searchTextUpdated(_ searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rows = allRows
            sections = buildSections(from: allRows)
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
                    row.subtitle,
                    row.groupTitle
                ]
                .joined(separator: " ")
                .lowercased()

                return tokens.allSatisfy { searchableText.contains($0) }
            }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.sortOrder < $1.sortOrder
            }

        sections = buildSections(from: rows)
    }

    // MARK: - Navigation

    func createMetricTapped() {
        navigationPath.append(SQMetricNavTarget.create)
    }

    func editMetricTapped(_ metricId: String) {
        navigationPath.append(SQMetricNavTarget.edit(metricId))
    }

    /// Look up a metric definition by ID for the edit form
    func metricDefinition(for id: String) -> SQMetricDefinition? {
        metricsManager.allMetrics(includeArchived: false).first(where: { $0.id == id })
    }

    // MARK: - Actions

    /// Toggle tracking state when tapped: tracked -> untrack, untracked -> track
    func metricTapped(_ row: SQMetricsListItemViewModel, using context: ModelContext) {
        do {
            try metricsManager.loadIfNeeded(using: context)

            if metricsManager.isMetricTracked(id: row.metricId) {
                try metricsManager.disableMetric(id: row.metricId, using: context)
            } else {
                try metricsManager.enableMetric(id: row.metricId, using: context)

                if let metric = metricsManager.allMetrics(includeArchived: false).first(where: { $0.id == row.metricId }) {
                    onMetricSelected?(metric)
                }
            }

            reloadRows(using: context)
        } catch {
            SQLogger.shared.log(
                "Failed to update metric tracking: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn
            )
            presentError("Error updating metric tracking: \(error.localizedDescription)")
        }
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func isSectionCollapsed(_ sectionId: String) -> Bool {
        !isSearching && collapsedSectionIds.contains(sectionId)
    }

    func toggleSection(_ sectionId: String) {
        if collapsedSectionIds.contains(sectionId) {
            collapsedSectionIds.remove(sectionId)
        } else {
            collapsedSectionIds.insert(sectionId)
        }
    }

    private func presentError(_ message: String) {
        hub.alertEvents.send(
            .present(.init(SQError.standard(withDescription: message)))
        )
    }

    private func buildSections(from rows: [SQMetricsListItemViewModel]) -> [SQMetricsListSectionViewModel] {
        var builtSections: [SQMetricsListSectionViewModel] = []

        let trackedRows = rows
            .filter(\.isTracked)
            .sorted(by: sortRows)

        if !trackedRows.isEmpty {
            builtSections.append(
                .init(
                    id: "tracked",
                    title: "Currently Tracking",
                    subtitle: "\(trackedRows.count) active metric\(trackedRows.count == 1 ? "" : "s")",
                    rows: trackedRows,
                    isTrackedSection: true
                )
            )
        }

        let untrackedRows = rows.filter { !$0.isTracked }
        let groupedRows = Dictionary(grouping: untrackedRows, by: \.groupTitle)
        let orderedGroupTitles = groupedRows.keys.sorted(by: sortGroups)

        for groupTitle in orderedGroupTitles {
            let groupRows = (groupedRows[groupTitle] ?? []).sorted(by: sortRows)
            guard !groupRows.isEmpty else { continue }

            builtSections.append(
                .init(
                    id: "group.\(groupTitle.lowercased())",
                    title: groupTitle,
                    subtitle: sectionSubtitle(for: groupTitle, count: groupRows.count),
                    rows: groupRows,
                    isTrackedSection: false
                )
            )
        }

        return builtSections
    }

    private func sortRows(_ lhs: SQMetricsListItemViewModel, _ rhs: SQMetricsListItemViewModel) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        return lhs.sortOrder < rhs.sortOrder
    }

    private func sortGroups(_ lhs: String, _ rhs: String) -> Bool {
        let lhsPriority = groupPriority(for: lhs)
        let rhsPriority = groupPriority(for: rhs)

        if lhsPriority == rhsPriority {
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return lhsPriority < rhsPriority
    }

    private func groupPriority(for title: String) -> Int {
        switch title {
        case SQDefaultGroup.stats.rawValue:
            return 10
        case SQDefaultGroup.self_.rawValue:
            return 20
        case SQDefaultGroup.sleep.rawValue:
            return 30
        case SQDefaultGroup.positiveHabits.rawValue:
            return 40
        case SQDefaultGroup.vices.rawValue:
            return 50
        case SQDefaultGroup.otherHabits.rawValue:
            return 60
        case SQDefaultGroup.general.rawValue:
            return 70
        default:
            return 80
        }
    }

    private func sectionSubtitle(for groupTitle: String, count: Int) -> String? {
        let countText = "\(count) metric\(count == 1 ? "" : "s")"

        switch groupTitle {
        case SQDefaultGroup.self_.rawValue:
            return "\(countText) for mood, readiness, and symptoms."
        case SQDefaultGroup.sleep.rawValue:
            return "\(countText) related to how you slept."
        case SQDefaultGroup.positiveHabits.rawValue:
            return "\(countText) for nutrition, hydration, and recovery habits."
        case SQDefaultGroup.vices.rawValue:
            return "\(countText) to monitor behaviors you may want to limit."
        case SQDefaultGroup.otherHabits.rawValue:
            return "\(countText) for supportive routines you want to build."
        case SQDefaultGroup.stats.rawValue:
            return "\(countText) for simple body measurements."
        default:
            return countText
        }
    }
}


private extension Float {
    var clean: String {
        if self.rounded() == self { return "\(Int(self))" }
        return String(format: "%.1f", Double(self))
    }
}
