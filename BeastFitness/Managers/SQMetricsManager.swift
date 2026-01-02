//
//  SQMetricsManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import Foundation
import SwiftData
import BeastFitnessCore

// MARK: - Protocol

@MainActor
protocol SQMetricsManaging: AnyObject {
    var metrics: [SQMetricDefinition] { get }

    // Load / Seed
    func loadIfNeeded(using context: ModelContext) throws
    func reload(using context: ModelContext) throws

    // Accessors
    func dailyCheckInMetrics() -> [SQMetricDefinition]
    func allMetrics(includeArchived: Bool) -> [SQMetricDefinition]
    func trackedMetrics() -> [SQMetricDefinition]
    func isMetricTracked(id: String) -> Bool

    // Mutations (persisted)
    func enableMetric(id: String, using context: ModelContext) throws
    func disableMetric(id: String, using context: ModelContext) throws
    func archiveMetric(id: String, using context: ModelContext) throws
    func setSortOrder(_ sortOrder: Int, for id: String, using context: ModelContext) throws
}

// MARK: - Concrete Manager

@MainActor
final class SQMetricsManager: SQMetricsManaging {
    static let shared: SQMetricsManaging = SQMetricsManager()

    private var hub: EventHub { SQAppState.shared.hub }

    private(set) var metrics: [SQMetricDefinition] = []
    private var hasLoaded = false

    private init() {}

    // MARK: - Load / Seed

    func loadIfNeeded(using context: ModelContext) throws {
        guard !hasLoaded else { return }

        let descriptor = FetchDescriptor<SQMetricDefinitionEntity>(
            predicate: #Predicate { $0.isArchived == false },
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )

        let stored = try context.fetch(descriptor)

        if stored.isEmpty {
            // First launch: seed presets
            let presets = Self.presetMetrics()
            for def in presets {
                context.insert(
                    SQMetricDefinitionEntity(
                        id: def.id,
                        title: def.title,
                        kind: def.kind,
                        unit: def.unit,
                        min: def.min,
                        max: def.max,
                        step: def.step,
                        isPreset: def.isPreset,
                        isEnabled: def.isEnabled,
                        sortOrder: def.sortOrder,
                        isArchived: def.isArchived
                    )
                )
            }

            // ✅ Save + reload + notify once
            try saveContextAndNotify(context)

            SQLogger.shared.log("Metrics are empty, loading from presets", .debug, context: .metricsManager)
        } else {
            metrics = stored.map { $0.toDefinition() }
            SQLogger.shared.log("Metrics loaded from SwiftData. Total Count: \(metrics.count)", .debug, context: .metricsManager)
        }

        hasLoaded = true
    }

    // MARK: - Public Accessors

    func dailyCheckInMetrics() -> [SQMetricDefinition] {
        metrics
            .filter { $0.isEnabled && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func allMetrics(includeArchived: Bool = false) -> [SQMetricDefinition] {
        metrics
            .filter { includeArchived ? true : !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func trackedMetrics() -> [SQMetricDefinition] {
        dailyCheckInMetrics()
    }

    func isMetricTracked(id: String) -> Bool {
        metrics.first(where: { $0.id == id })?.isEnabled == true
    }

    // MARK: - Mutations (persisted)

    func enableMetric(id: String, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.isEnabled = true
        entity.isArchived = false

        // Put newly-enabled metrics at end of tracked list (optional UX)
        let maxTracked = dailyCheckInMetrics().map(\.sortOrder).max() ?? 0
        if entity.sortOrder <= maxTracked { entity.sortOrder = maxTracked + 1 }

        entity.updatedAt = .now
        try saveContextAndNotify(context)
    }

    func disableMetric(id: String, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.isEnabled = false
        entity.updatedAt = .now
        try saveContextAndNotify(context)
    }

    func archiveMetric(id: String, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.isArchived = true
        entity.isEnabled = false
        entity.updatedAt = .now
        try saveContextAndNotify(context)
    }

    func setSortOrder(_ sortOrder: Int, for id: String, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.sortOrder = sortOrder
        entity.updatedAt = .now
        try saveContextAndNotify(context)
    }

    // MARK: - Reload (protocol requires public)

    func reload(using context: ModelContext) throws {
        let descriptor = FetchDescriptor<SQMetricDefinitionEntity>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        metrics = try context.fetch(descriptor).map { $0.toDefinition() }
    }

    // MARK: - Persistence + Event

    /// Centralized "commit" path so we never forget:
    /// 1) save changes
    /// 2) reload in-memory cache
    /// 3) emit metricsUpdated
    private func saveContextAndNotify(_ context: ModelContext) throws {
        try context.save()
        try reload(using: context)
        hub.metricEvents.send(.metricsUpdated)
    }

    // MARK: - Helpers

    private func fetchEntity(id: String, using context: ModelContext) throws -> SQMetricDefinitionEntity? {
        let descriptor = FetchDescriptor<SQMetricDefinitionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    // MARK: - Presets

    private static func presetMetrics() -> [SQMetricDefinition] {
        var order = 0
        func next() -> Int { defer { order += 1 }; return order }

        return [
            // Core defaults (enabled)
            .init(id: SQMetricId.mood, title: "Mood", kind: .scale, unit: .none,
                  min: 0, max: 10, step: 1, isPreset: true, isEnabled: true, sortOrder: next(), isArchived: false),

            .init(id: SQMetricId.mentalClarity, title: "Mental Clarity", kind: .scale, unit: .none,
                  min: 0, max: 10, step: 1, isPreset: true, isEnabled: true, sortOrder: next(), isArchived: false),

            .init(id: SQMetricId.energy, title: "Energy Level", kind: .scale, unit: .none,
                  min: 0, max: 10, step: 1, isPreset: true, isEnabled: true, sortOrder: next(), isArchived: false),

            .init(id: SQMetricId.soreness, title: "Soreness / Recovery", kind: .scale, unit: .none,
                  min: 0, max: 10, step: 1, isPreset: true, isEnabled: true, sortOrder: next(), isArchived: false),

            .init(id: SQMetricId.sleepHours, title: "Sleep (hours)", kind: .number, unit: .hours,
                  min: 0, max: 24, step: 0.5, isPreset: true, isEnabled: true, sortOrder: next(), isArchived: false),

            .init(id: SQMetricId.sleepQuality, title: "Sleep Quality", kind: .scale, unit: .none,
                  min: 1, max: 5, step: 1, isPreset: true, isEnabled: true, sortOrder: next(), isArchived: false),

            // Optional presets (disabled)
            .init(id: SQMetricId.alcohol, title: "Alcohol", kind: .binary, unit: .none,
                  min: 0, max: 1, step: 1, isPreset: true, isEnabled: false, sortOrder: next(), isArchived: false),

            .init(id: SQMetricId.weed, title: "Weed", kind: .binary, unit: .none,
                  min: 0, max: 1, step: 1, isPreset: true, isEnabled: false, sortOrder: next(), isArchived: false),

            .init(id: SQMetricId.porn, title: "Porn", kind: .binary, unit: .none,
                  min: 0, max: 1, step: 1, isPreset: true, isEnabled: false, sortOrder: next(), isArchived: false),
        ]
    }
}
