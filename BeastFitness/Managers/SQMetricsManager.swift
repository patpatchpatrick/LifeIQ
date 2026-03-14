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
    func dailyCheckInMetrics(for period: SQMetricPeriod) -> [SQMetricDefinition]
    func allMetrics(includeArchived: Bool) -> [SQMetricDefinition]
    func trackedMetrics() -> [SQMetricDefinition]
    func isMetricTracked(id: String) -> Bool

    // Mutations (persisted)
    func enableMetric(id: String, using context: ModelContext) throws
    func disableMetric(id: String, using context: ModelContext) throws
    func archiveMetric(id: String, using context: ModelContext) throws
    func setSortOrder(_ sortOrder: Int, for id: String, using context: ModelContext) throws
    func createMetric(definition: SQMetricDefinition, using context: ModelContext) throws
    func updateMetric(id: String, title: String, emoji: String?, group: String, using context: ModelContext) throws

    // Sync
    func syncMetricsIfNeeded(using context: ModelContext) async throws -> SyncResult
}

// MARK: - Concrete Manager

@MainActor
final class SQMetricsManager: SQMetricsManaging {
    static let shared: SQMetricsManaging = SQMetricsManager()

    private var hub: EventHub { SQAppState.shared.hub }
    private let metricService: SQMetricDefinitionServicing.Type = SQMetricDefinitionService.self

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
                        group: def.group,
                        min: def.min,
                        max: def.max,
                        step: def.step,
                        isPreset: def.isPreset,
                        isEnabled: def.isEnabled,
                        sortOrder: def.sortOrder,
                        isArchived: def.isArchived,
                        emoji: def.emoji,
                        period: def.period,
                        isDefault: def.isDefault
                    )
                )
            }

            // ✅ Save + reload + notify once
            try saveContextAndNotify(context)

            SQLogger.shared.log("Metrics are empty, loading from presets", .debug, context: .metricsManager)
        } else {
            metrics = stored.map { $0.toDefinition() }

            // Migration: add new preset metrics if they don't exist
            try? migrateNewPresets(context: context)

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

    func dailyCheckInMetrics(for period: SQMetricPeriod) -> [SQMetricDefinition] {
        metrics
            .filter { $0.isEnabled && !$0.isArchived && $0.period == period }
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

        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) { pushMetricToFirestore(updated) }
    }

    func disableMetric(id: String, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.isEnabled = false
        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) { pushMetricToFirestore(updated) }
    }

    func archiveMetric(id: String, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.isArchived = true
        entity.isEnabled = false
        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) { pushMetricToFirestore(updated) }
    }

    func setSortOrder(_ sortOrder: Int, for id: String, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.sortOrder = sortOrder
        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) { pushMetricToFirestore(updated) }
    }

    func createMetric(definition: SQMetricDefinition, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        let maxOrder = dailyCheckInMetrics().map(\.sortOrder).max() ?? 0

        context.insert(
            SQMetricDefinitionEntity(
                id: definition.id,
                title: definition.title,
                kind: definition.kind,
                unit: definition.unit,
                group: definition.group,
                min: definition.min,
                max: definition.max,
                step: definition.step,
                isPreset: false,
                isEnabled: true,
                sortOrder: maxOrder + 1,
                isArchived: false,
                emoji: definition.emoji,
                period: definition.period,
                isDefault: false
            )
        )

        try saveContextAndNotify(context)
        if let created = metrics.first(where: { $0.id == definition.id }) { pushMetricToFirestore(created) }
        SQLogger.shared.log("Created custom metric: \(definition.id)", .debug, context: .metricsManager)
    }

    func updateMetric(id: String, title: String, emoji: String?, group: String, using context: ModelContext) throws {
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.title = title
        entity.emoji = emoji
        entity.groupRaw = group
        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) { pushMetricToFirestore(updated) }
    }

    // MARK: - Reload (protocol requires public)

    func reload(using context: ModelContext) throws {
        let descriptor = FetchDescriptor<SQMetricDefinitionEntity>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        metrics = try context.fetch(descriptor).map { $0.toDefinition() }
    }

    // MARK: - Sync

    func syncMetricsIfNeeded(using context: ModelContext) async throws -> SyncResult {
        try loadIfNeeded(using: context)
        await bootstrapPushIfNeeded(context: context)

        guard let lastSync = getMetricSyncDate(context: context) else {
            SQLogger.shared.log("Metric definitions: never synced — full sync", .info, context: .metricsManager)
            let count = try await performFullMetricSync(context: context)
            SyncResult.fullSyncCompleted.logSync(documentCount: count, service: "metric definitions", context: .metricsManager)
            return .fullSyncCompleted
        }

        let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
        if hoursSinceSync > 6 {
            SQLogger.shared.log("Metric definitions: stale (\(String(format: "%.1f", hoursSinceSync))h) — incremental sync", .info, context: .metricsManager)
            let count = try await performIncrementalMetricSync(lastSync: lastSync, context: context)
            SyncResult.refreshCompleted.logSync(documentCount: count, service: "metric definitions", context: .metricsManager)
            return .refreshCompleted
        }

        SQLogger.shared.log("Metric definitions: cache fresh", .debug, context: .metricsManager)
        SyncResult.noSyncNeeded.logSync(service: "metric definitions", context: .metricsManager)
        return .noSyncNeeded
    }

    /// One-time push of all local metrics that existed before the per-mutation push
    /// system was added. Gated by a metadata flag so it runs exactly once.
    private func bootstrapPushIfNeeded(context: ModelContext) async {
        let key = "metric-definitions-bootstrap"
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == key }
        )
        guard (try? context.fetch(descriptor))?.first == nil else { return }

        let allEntities = (try? context.fetch(FetchDescriptor<SQMetricDefinitionEntity>())) ?? []
        let allDefinitions = allEntities.map { $0.toDefinition() }

        SQLogger.shared.log(
            "Metric definitions: bootstrapping \(allDefinitions.count) metrics to Firestore",
            .info,
            context: .metricsManager,
            isPriority: true
        )

        for definition in allDefinitions {
            do {
                try await metricService.saveMetricDefinition(definition)
            } catch {
                SQLogger.shared.log(
                    "Bootstrap push failed for \(definition.id): \(error)",
                    .error,
                    context: .metricsManager
                )
            }
        }

        let metadata = SQSyncMetadataEntity(id: key)
        metadata.lastSyncDate = .now
        context.insert(metadata)
        try? context.save()

        SQLogger.shared.log(
            "Metric definitions: bootstrap push complete (\(allDefinitions.count) metrics)",
            .info,
            context: .metricsManager,
            isPriority: true
        )
    }

    private func performFullMetricSync(context: ModelContext) async throws -> Int {
        let user = SQAppState.shared.userState.loggedInUser
        let definitions = try await metricService.fetchAllMetricDefinitions(for: user, afterDate: nil)

        try upsertMetrics(definitions, into: context, fullSync: true)
        updateMetricSyncDate(to: .now, context: context)
        try saveContextAndNotify(context)
        return definitions.count
    }

    private func performIncrementalMetricSync(lastSync: Date, context: ModelContext) async throws -> Int {
        let user = SQAppState.shared.userState.loggedInUser
        let definitions = try await metricService.fetchAllMetricDefinitions(for: user, afterDate: lastSync)

        try upsertMetrics(definitions, into: context, fullSync: false)
        updateMetricSyncDate(to: .now, context: context)
        try saveContextAndNotify(context)
        return definitions.count
    }

    private func upsertMetrics(_ definitions: [SQMetricDefinition], into context: ModelContext, fullSync: Bool) throws {
        for def in definitions {
            if let existing = try fetchEntity(id: def.id, using: context) {
                if fullSync || def.updatedAt > existing.updatedAt {
                    existing.apply(def)
                }
            } else {
                let entity = SQMetricDefinitionEntity(
                    id: def.id,
                    title: def.title,
                    kind: def.kind,
                    unit: def.unit,
                    group: def.group,
                    min: def.min,
                    max: def.max,
                    step: def.step,
                    isPreset: def.isPreset,
                    isEnabled: def.isEnabled,
                    sortOrder: def.sortOrder,
                    isArchived: def.isArchived,
                    emoji: def.emoji,
                    period: def.period,
                    isDefault: def.isDefault
                )
                entity.updatedAt = def.updatedAt
                context.insert(entity)
            }
        }
    }

    // MARK: - Firestore Push

    private func pushMetricToFirestore(_ definition: SQMetricDefinition) {
        Task {
            do {
                try await metricService.saveMetricDefinition(definition)
            } catch {
                SQLogger.shared.log("Failed to push metric \(definition.id) to Firestore: \(error)", .error, context: .metricsManager)
            }
        }
    }

    // MARK: - Sync Metadata

    private func getMetricSyncDate(context: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == "metric-definitions-sync" }
        )
        return (try? context.fetch(descriptor))?.first?.lastSyncDate
    }

    private func updateMetricSyncDate(to date: Date, context: ModelContext) {
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == "metric-definitions-sync" }
        )
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = date
            } else {
                let metadata = SQSyncMetadataEntity(id: "metric-definitions-sync")
                metadata.lastSyncDate = date
                context.insert(metadata)
            }
        } catch {
            SQLogger.shared.log("Failed to update metric sync metadata: \(error)", .error, context: .metricsManager)
        }
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

    // MARK: - Migration

    /// Migrates the preset catalog:
    /// 1. Inserts any new preset metrics that don't exist in the database.
    /// 2. For existing preset entities, applies period, isDefault, and binary→scale conversion.
    private func migrateNewPresets(context: ModelContext) throws {
        let allPresets = Self.presetMetrics()
        let existingIds = Set(metrics.map { $0.id })

        var added = 0
        var updated = 0

        for preset in allPresets {
            if !existingIds.contains(preset.id) {
                // New preset — insert with all fields
                context.insert(
                    SQMetricDefinitionEntity(
                        id: preset.id,
                        title: preset.title,
                        kind: preset.kind,
                        unit: preset.unit,
                        group: preset.group,
                        min: preset.min,
                        max: preset.max,
                        step: preset.step,
                        isPreset: preset.isPreset,
                        isEnabled: preset.isEnabled,
                        sortOrder: preset.sortOrder,
                        isArchived: preset.isArchived,
                        emoji: preset.emoji,
                        period: preset.period,
                        isDefault: preset.isDefault
                    )
                )
                added += 1
            } else if let entity = try? fetchEntity(id: preset.id, using: context) {
                // Existing preset — apply period, isDefault, and binary→scale upgrade
                var didChange = false

                if entity.periodRaw != preset.period.rawValue {
                    entity.periodRaw = preset.period.rawValue
                    didChange = true
                }
                if entity.isDefault != preset.isDefault {
                    entity.isDefault = preset.isDefault
                    didChange = true
                }
                // Upgrade legacy binary metrics to scale 0–10
                if entity.kindRaw == SQMetricKind.binary.rawValue {
                    entity.kindRaw = SQMetricKind.scale.rawValue
                    entity.minValue = preset.min
                    entity.maxValue = preset.max
                    entity.stepValue = preset.step
                    didChange = true
                }
                // Migrate SleepQuality from 1–5 to 0–10 scale
                if preset.id == SQMetricId.sleepQuality,
                   entity.minValue == 1, entity.maxValue == 5 {
                    entity.minValue = preset.min
                    entity.maxValue = preset.max
                    didChange = true
                }
                // Migrate group from legacy raw values to new group names
                let migratedGroup = entity.group  // uses the computed migration property
                if entity.groupRaw != migratedGroup {
                    entity.groupRaw = migratedGroup
                    didChange = true
                }

                if didChange {
                    entity.updatedAt = .now
                    updated += 1
                }
            }
        }

        if added > 0 || updated > 0 {
            try saveContextAndNotify(context)
            SQLogger.shared.log(
                "Migration: Added \(added) new preset(s), updated \(updated) existing preset(s)",
                .info, context: .metricsManager, isPriority: true
            )
        }
    }

    // MARK: - Presets

    private static func presetMetrics() -> [SQMetricDefinition] {
        var order = 0
        func next() -> Int { defer { order += 1 }; return order }

        return [
            // MARK: Stats — one-time or infrequent physical measurements
            .init(id: SQMetricId.weight, title: "Weight", kind: .number, unit: .pounds,
                  group: SQDefaultGroup.stats.rawValue, min: 0, max: 1000, step: 0.1,
                  isPreset: true, isEnabled: true, isDefault: false, sortOrder: next(),
                  emoji: "⚖️", period: .morning),

            // MARK: Self — daily mental/physical state; all default-enabled
            .init(id: SQMetricId.mood, title: "Mood", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "😊", period: .morning),

            .init(id: SQMetricId.mentalClarity, title: "Mental Clarity", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "🧠", period: .morning),

            .init(id: SQMetricId.energy, title: "Energy Level", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "⚡", period: .morning),

            .init(id: SQMetricId.soreness, title: "Soreness / Recovery", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "💪", period: .morning),

            // MARK: Sleep — logged in the morning, reflecting the prior night
            .init(id: SQMetricId.sleepQuality, title: "Sleep Quality", kind: .scale, unit: .none,
                  group: SQDefaultGroup.sleep.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: false, sortOrder: next(),
                  emoji: "😴", period: .morning),

            .init(id: SQMetricId.sleepHours, title: "Sleep Hours", kind: .number, unit: .hours,
                  group: SQDefaultGroup.sleep.rawValue, min: 0, max: 24, step: 0.5,
                  isPreset: true, isEnabled: true, isDefault: false, sortOrder: next(),
                  emoji: "🌙", period: .morning),

            // MARK: Positive Habits — behaviors to build; logged in the evening
            .init(id: SQMetricId.nutrition, title: "Nutrition", kind: .scale, unit: .none,
                  group: SQDefaultGroup.positiveHabits.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "🥗", period: .evening),

            .init(id: SQMetricId.meditation, title: "Meditation", kind: .scale, unit: .none,
                  group: SQDefaultGroup.positiveHabits.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🧘", period: .evening),

            // MARK: Vices — behaviors to monitor; logged in the evening
            .init(id: SQMetricId.alcohol, title: "Alcohol", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "🍺", period: .evening),

            .init(id: SQMetricId.caffeine, title: "Caffeine", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "☕", period: .evening),

            .init(id: SQMetricId.weed, title: "Weed", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🌿", period: .evening),

            .init(id: SQMetricId.porn, title: "Porn", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  period: .evening),

            .init(id: SQMetricId.nicotine, title: "Nicotine", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🚬", period: .evening),
        ]
    }
}
