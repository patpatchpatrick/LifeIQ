//
//  SQMetricDefinitionManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import Foundation
import SwiftData
import BeastFitnessCore

// MARK: - Protocol

@MainActor
protocol SQMetricDefinitionManaging: AnyObject {
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
    func updateMetric(definition: SQMetricDefinition, using context: ModelContext) throws

    // Sync
    /// Syncs both the metric catalog and the user's logged metric entry data from Firestore.
    func syncMetricsIfNeeded(using context: ModelContext) async throws -> SyncResult
    func reset()
}

// MARK: - Concrete Manager

@MainActor
final class SQMetricDefinitionManager: SQMetricDefinitionManaging {
    static let shared: SQMetricDefinitionManaging = SQMetricDefinitionManager()

    private var hub: EventHub { SQAppState.shared.hub }
    private let metricService: SQMetricDefinitionServicing.Type = SQMetricDefinitionService.self

    private(set) var metrics: [SQMetricDefinition] = []
    private var hasLoaded = false
    private var loadedScopeUserId: String?

    private init() {}

    // MARK: - Load / Seed

    func loadIfNeeded(using context: ModelContext) throws {
        let currentUserId = currentLocalUserId()
        guard !hasLoaded || loadedScopeUserId != currentUserId else { return }

        let descriptor = FetchDescriptor<SQMetricDefinitionEntity>(
            predicate: #Predicate { $0.userId == currentUserId && $0.isArchived == false },
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )

        let stored = try context.fetch(descriptor)

        if stored.isEmpty {
            // First launch: seed presets
            let presets = Self.presetMetrics()
            for def in presets {
                context.insert(
                    SQMetricDefinitionEntity(
                        userId: currentUserId,
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
                        periods: def.periods,
                        isSingleDailyValue: def.isSingleDailyValue,
                        goalStyle: def.goalStyle,
                        targetValue: def.targetValue,
                        targetRangeMin: def.targetRangeMin,
                        targetRangeMax: def.targetRangeMax,
                        bodyBatteryEffect: def.bodyBatteryEffect,
                        scaleQuantityMapping: def.scaleQuantityMapping,
                        healthKitType: def.healthKitType,
                        healthKitReadEnabled: def.healthKitReadEnabled,
                        healthKitWriteEnabled: def.healthKitWriteEnabled,
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
        loadedScopeUserId = currentUserId
    }

    // MARK: - Public Accessors

    func dailyCheckInMetrics() -> [SQMetricDefinition] {
        metrics
            .filter { $0.isEnabled && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func dailyCheckInMetrics(for period: SQMetricPeriod) -> [SQMetricDefinition] {
        metrics
            .filter { $0.isEnabled && !$0.isArchived && $0.periods.contains(period) }
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
        try assertServerWritesEnabledIfNeeded()
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.isEnabled = true
        entity.isArchived = false

        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) {
            SQAnalyticsManager.shared.track(.metricTrackingChanged(isEnabled: true, definition: updated))
            pushMetricToFirestore(updated)
        }
    }

    func disableMetric(id: String, using context: ModelContext) throws {
        try assertServerWritesEnabledIfNeeded()
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.isEnabled = false
        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) {
            SQAnalyticsManager.shared.track(.metricTrackingChanged(isEnabled: false, definition: updated))
            pushMetricToFirestore(updated)
        }
    }

    func archiveMetric(id: String, using context: ModelContext) throws {
        try assertServerWritesEnabledIfNeeded()
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.isArchived = true
        entity.isEnabled = false
        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) {
            SQAnalyticsManager.shared.track(.metricArchived(definition: updated))
            pushMetricToFirestore(updated)
        }
    }

    func setSortOrder(_ sortOrder: Int, for id: String, using context: ModelContext) throws {
        try assertServerWritesEnabledIfNeeded()
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: id, using: context) else { return }
        entity.sortOrder = sortOrder
        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == id }) { pushMetricToFirestore(updated) }
    }

    func createMetric(definition: SQMetricDefinition, using context: ModelContext) throws {
        try assertServerWritesEnabledIfNeeded()
        try loadIfNeeded(using: context)
        let userId = currentLocalUserId()

        let maxOrder = dailyCheckInMetrics().map(\.sortOrder).max() ?? 0

        context.insert(
            SQMetricDefinitionEntity(
                userId: userId,
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
                periods: definition.periods,
                isSingleDailyValue: definition.isSingleDailyValue,
                goalStyle: definition.goalStyle,
                targetValue: definition.targetValue,
                targetRangeMin: definition.targetRangeMin,
                targetRangeMax: definition.targetRangeMax,
                bodyBatteryEffect: definition.bodyBatteryEffect,
                scaleQuantityMapping: definition.scaleQuantityMapping,
                healthKitType: definition.healthKitType,
                healthKitReadEnabled: definition.healthKitReadEnabled,
                healthKitWriteEnabled: definition.healthKitWriteEnabled,
                isDefault: false
            )
        )

        try saveContextAndNotify(context)
        if let created = metrics.first(where: { $0.id == definition.id }) {
            SQAnalyticsManager.shared.track(.metricSaved(action: .create, definition: created))
            pushMetricToFirestore(created)
        }
        SQLogger.shared.log("Created custom metric: \(definition.id)", .debug, context: .metricsManager)
    }

    func updateMetric(definition: SQMetricDefinition, using context: ModelContext) throws {
        try assertServerWritesEnabledIfNeeded()
        try loadIfNeeded(using: context)

        guard let entity = try fetchEntity(id: definition.id, using: context) else { return }
        entity.apply(definition)
        entity.updatedAt = .now
        try saveContextAndNotify(context)
        if let updated = metrics.first(where: { $0.id == definition.id }) {
            SQAnalyticsManager.shared.track(.metricSaved(action: .edit, definition: updated))
            pushMetricToFirestore(updated)
        }
    }

    // MARK: - Reload (protocol requires public)

    func reload(using context: ModelContext) throws {
        let userId = currentLocalUserId()
        let descriptor = FetchDescriptor<SQMetricDefinitionEntity>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        metrics = try context.fetch(descriptor).map { $0.toDefinition() }
        loadedScopeUserId = userId
        hasLoaded = true
    }

    // MARK: - Sync

    func syncMetricsIfNeeded(using context: ModelContext) async throws -> SyncResult {
        try loadIfNeeded(using: context)

        guard SQAppState.shared.userState.loggedInUser != nil else {
            SQLogger.shared.log("[Sync - Metric Definition] Skipping cloud sync while logged out", .debug, context: .metricsManager)
            return .noSyncNeeded
        }

        // Keep metric entry values/notes and metric definitions in sync from one entrypoint.
        _ = try await SQAppState.shared.metricEntryManager.syncIfNeeded(
            for: .allTime,
            context: context
        )

        guard let lastSync = getMetricSyncDate(context: context) else {
            SQLogger.shared.log("[Sync - Metric Definition] Never synced, running full sync", .info, context: .metricsManager)
            let count = try await performFullMetricSync(context: context)
            // Important: reconcile from Firestore before any bootstrap push so a freshly
            // seeded local catalog on a new install cannot overwrite the user's cloud-tracked
            // metric order / enabled state.
            await bootstrapPushIfNeeded(context: context)
            SyncResult.fullSyncCompleted.logSync(documentCount: count, service: "Metric Definition", context: .metricsManager)
            return .fullSyncCompleted
        }

        let count = try await performIncrementalMetricSync(lastSync: lastSync, context: context)
        // After an incremental pull the local catalog reflects the latest remote state, so any
        // one-time bootstrap push is safe to run without clobbering cloud-tracked settings.
        await bootstrapPushIfNeeded(context: context)
        SyncResult.refreshCompleted.logSync(documentCount: count, service: "Metric Definition", context: .metricsManager)
        return .refreshCompleted
    }

    func reset() {
        metrics = []
        hasLoaded = false
        loadedScopeUserId = nil
    }

    /// One-time push of all local metrics for schema/bootstrap migrations.
    /// Bumping the key forces a single backfill for existing users when new fields
    /// need to be written to Firestore.
    private func bootstrapPushIfNeeded(context: ModelContext) async {
        guard SQAppState.shared.userState.isLoggedIn, !SQRemoteConfigManager.shared.snapshot.writesDisabled else {
            return
        }

        let userId = currentLocalUserId()
        let key = "metric-definitions-bootstrap-v5-healthkit-metrics-\(userId)"
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == key }
        )

        guard (try? context.fetch(descriptor))?.first == nil else { return }

        let allEntities = (try? context.fetch(FetchDescriptor<SQMetricDefinitionEntity>(
            predicate: #Predicate { $0.userId == userId }
        ))) ?? []
        let allDefinitions = allEntities.map { $0.toDefinition() }

        SQLogger.shared.log(
            "[Sync - Metric Definition] Bootstrapping \(allDefinitions.count) metrics to Firestore",
            .info,
            context: .metricsManager,
            isPriority: true
        )

        for definition in allDefinitions {
            do {
                try await metricService.saveMetricDefinition(definition)
            } catch {
                SQLogger.shared.log(
                    "[Sync - Metric Definition] Bootstrap push failed for \(definition.id): \(error)",
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
            "[Sync - Metric Definition] Bootstrap push complete (\(allDefinitions.count) metrics)",
            .info,
            context: .metricsManager,
            isPriority: true
        )
    }

    private func performFullMetricSync(context: ModelContext) async throws -> Int {
        guard let user = SQAppState.shared.userState.loggedInUser else { throw SQError.notLoggedIn }
        let definitions = try await metricService.fetchAllMetricDefinitions(for: user, afterDate: nil)

        try upsertMetrics(definitions, into: context, fullSync: true)
        updateMetricSyncDate(to: .now, context: context)
        try saveContextAndNotify(context)
        return definitions.count
    }

    private func performIncrementalMetricSync(lastSync: Date, context: ModelContext) async throws -> Int {
        guard let user = SQAppState.shared.userState.loggedInUser else { throw SQError.notLoggedIn }
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
                    userId: currentLocalUserId(),
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
                    periods: def.periods,
                    isSingleDailyValue: def.isSingleDailyValue,
                    goalStyle: def.goalStyle,
                    targetValue: def.targetValue,
                    targetRangeMin: def.targetRangeMin,
                    targetRangeMax: def.targetRangeMax,
                    bodyBatteryEffect: def.bodyBatteryEffect,
                    scaleQuantityMapping: def.scaleQuantityMapping,
                    healthKitType: def.healthKitType,
                    healthKitReadEnabled: def.healthKitReadEnabled,
                    healthKitWriteEnabled: def.healthKitWriteEnabled,
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
        let id = metricSyncMetadataId()
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first?.lastSyncDate
    }

    private func updateMetricSyncDate(to date: Date, context: ModelContext) {
        let id = metricSyncMetadataId()
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = date
            } else {
                let metadata = SQSyncMetadataEntity(id: id)
                metadata.lastSyncDate = date
                context.insert(metadata)
            }
        } catch {
            SQLogger.shared.log("[Sync - Metric Definition] Failed to update sync metadata: \(error)", .error, context: .metricsManager)
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

    private func assertServerWritesEnabledIfNeeded() throws {
        guard SQAppState.shared.userState.isLoggedIn else { throw SQError.notLoggedIn }
        try SQRemoteConfigManager.shared.assertServerWritesEnabled()
    }

    // MARK: - Helpers

    private func fetchEntity(id: String, using context: ModelContext) throws -> SQMetricDefinitionEntity? {
        let userId = currentLocalUserId()
        let descriptor = FetchDescriptor<SQMetricDefinitionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.id == id }
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
        var changedPresetIds: [String] = []

        for preset in allPresets {
            if !existingIds.contains(preset.id) {
                // New preset — insert with all fields
                context.insert(
                    SQMetricDefinitionEntity(
                        userId: currentLocalUserId(),
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
                        periods: preset.periods,
                        isSingleDailyValue: preset.isSingleDailyValue,
                        goalStyle: preset.goalStyle,
                        targetValue: preset.targetValue,
                        targetRangeMin: preset.targetRangeMin,
                        targetRangeMax: preset.targetRangeMax,
                        bodyBatteryEffect: preset.bodyBatteryEffect,
                        scaleQuantityMapping: preset.scaleQuantityMapping,
                        healthKitType: preset.healthKitType,
                        healthKitReadEnabled: preset.healthKitReadEnabled,
                        healthKitWriteEnabled: preset.healthKitWriteEnabled,
                        isDefault: preset.isDefault
                    )
                )
                added += 1
            } else if let entity = try? fetchEntity(id: preset.id, using: context) {
                // Existing preset — apply period, isDefault, and binary→scale upgrade
                var didChange = false

                if entity.title != preset.title {
                    entity.title = preset.title
                    didChange = true
                }
                let serializedPeriods = SQMetricDefinitionEntity.serialize(preset.periods)
                if entity.periodRaw != serializedPeriods {
                    entity.periodRaw = serializedPeriods
                    didChange = true
                }
                if entity.isSingleDailyValue != preset.isSingleDailyValue {
                    entity.isSingleDailyValue = preset.isSingleDailyValue
                    didChange = true
                }
                if entity.isDefault != preset.isDefault {
                    entity.isDefault = preset.isDefault
                    didChange = true
                }
                if entity.kindRaw != preset.kind.rawValue {
                    entity.kindRaw = preset.kind.rawValue
                    didChange = true
                }
                if entity.unitRaw != preset.unit.rawValue {
                    entity.unitRaw = preset.unit.rawValue
                    didChange = true
                }
                if entity.minValue != preset.min {
                    entity.minValue = preset.min
                    didChange = true
                }
                if entity.maxValue != preset.max {
                    entity.maxValue = preset.max
                    didChange = true
                }
                if entity.stepValue != preset.step {
                    entity.stepValue = preset.step
                    didChange = true
                }
                if entity.goalStyleRaw != preset.goalStyle.rawValue {
                    entity.goalStyleRaw = preset.goalStyle.rawValue
                    didChange = true
                }
                if entity.targetValue != preset.targetValue {
                    entity.targetValue = preset.targetValue
                    didChange = true
                }
                if entity.targetRangeMinValue != preset.targetRangeMin {
                    entity.targetRangeMinValue = preset.targetRangeMin
                    didChange = true
                }
                if entity.targetRangeMaxValue != preset.targetRangeMax {
                    entity.targetRangeMaxValue = preset.targetRangeMax
                    didChange = true
                }
                if entity.bodyBatteryEffectRaw != preset.bodyBatteryEffect.rawValue {
                    entity.bodyBatteryEffectRaw = preset.bodyBatteryEffect.rawValue
                    didChange = true
                }
                if entity.scaleQuantityUnitRaw == nil,
                   entity.scaleQuantityUnitRaw != preset.scaleQuantityMapping?.quantityUnit.rawValue {
                    entity.scaleQuantityUnitRaw = preset.scaleQuantityMapping?.quantityUnit.rawValue
                    didChange = true
                }
                if entity.scaleQuantityMaxValue == nil,
                   entity.scaleQuantityMaxValue != preset.scaleQuantityMapping?.maxQuantityValue {
                    entity.scaleQuantityMaxValue = preset.scaleQuantityMapping?.maxQuantityValue
                    didChange = true
                }
                if entity.scaleQuantityLabelOverride == nil,
                   entity.scaleQuantityLabelOverride != preset.scaleQuantityMapping?.quantityLabelOverride {
                    entity.scaleQuantityLabelOverride = preset.scaleQuantityMapping?.quantityLabelOverride
                    didChange = true
                }
                if entity.healthKitTypeRaw == SQMetricHealthKitType.none.rawValue,
                   entity.healthKitTypeRaw != preset.healthKitType.rawValue {
                    entity.healthKitTypeRaw = preset.healthKitType.rawValue
                    didChange = true
                }
                if entity.healthKitReadEnabled != preset.healthKitReadEnabled {
                    entity.healthKitReadEnabled = preset.healthKitReadEnabled
                    didChange = true
                }
                if entity.healthKitWriteEnabled != preset.healthKitWriteEnabled {
                    entity.healthKitWriteEnabled = preset.healthKitWriteEnabled
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
                    changedPresetIds.append(preset.id)
                }
            }
        }

        if added > 0 || updated > 0 {
            try saveContextAndNotify(context)
            let changedDefinitions = metrics.filter { changedPresetIds.contains($0.id) }
            changedDefinitions.forEach { pushMetricToFirestore($0) }
            SQLogger.shared.log(
                "Migration: Added \(added) new preset(s), updated \(updated) existing preset(s)",
                .info, context: .metricsManager, isPriority: true
            )
        }
    }

    private func currentLocalUserId() -> String {
        SQAppState.shared.userState.loggedInUser?.id ?? SQLocalPersistenceScope.guestUserId
    }

    private func metricSyncMetadataId() -> String {
        "metric-definitions-sync-\(currentLocalUserId())"
    }

    // MARK: - Presets

    private static func presetMetrics() -> [SQMetricDefinition] {
        var order = 0
        func next() -> Int { defer { order += 1 }; return order }
        let both: Set<SQMetricPeriod> = [.morning, .evening]
        let eveningOnly: Set<SQMetricPeriod> = [.evening]

        return [
            // MARK: Stats — single daily value; appears in both sessions so it can be entered any time
            .init(id: SQMetricId.weight, title: "Weight", kind: .number, unit: .pounds,
                  group: SQDefaultGroup.stats.rawValue, min: 0, max: 1000, step: 0.1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "⚖️", periods: both, isSingleDailyValue: true, goalStyle: .justTrack,
                  healthKitType: .bodyMass, healthKitReadEnabled: true, healthKitWriteEnabled: true),

            // MARK: Mind & Body — independent morning + evening values
            .init(id: SQMetricId.mood, title: "Mood", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "😊", periods: both, goalStyle: .justTrack),

            .init(id: SQMetricId.mentalClarity, title: "Mental Clarity", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "🧠", periods: both, goalStyle: .justTrack),

            .init(id: SQMetricId.energy, title: "Energy", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "⚡", periods: both, goalStyle: .justTrack, bodyBatteryEffect: .boostsWhenHigh),

            .init(id: SQMetricId.soreness, title: "Recovery", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "💪", periods: both, goalStyle: .justTrack, bodyBatteryEffect: .boostsWhenHigh),

            .init(id: SQMetricId.stress, title: "Stress", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "😵", periods: both, goalStyle: .keepLow),

            .init(id: SQMetricId.motivation, title: "Motivation", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🎯", periods: both, goalStyle: .buildUp, targetValue: 7),

            .init(id: SQMetricId.anxiety, title: "Anxiety", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "😬", periods: both, goalStyle: .keepLow),

            .init(id: SQMetricId.sickness, title: "Sickness", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🤒", periods: both, goalStyle: .keepLow),

            .init(id: SQMetricId.pain, title: "Pain", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🩹", periods: both, goalStyle: .keepLow),

            .init(id: SQMetricId.productivity, title: "Productivity", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "📈", periods: both, goalStyle: .buildUp, targetValue: 7),

            .init(id: SQMetricId.socialConnection, title: "Social Connection", kind: .scale, unit: .none,
                  group: SQDefaultGroup.self_.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🤝", periods: both, goalStyle: .buildUp, targetValue: 7),

            // MARK: Sleep — single daily value for last night's sleep; editable from either session
            .init(id: SQMetricId.sleepQuality, title: "Sleep Quality", kind: .scale, unit: .none,
                  group: SQDefaultGroup.sleep.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "😴", periods: both, isSingleDailyValue: true, goalStyle: .justTrack),

            .init(id: SQMetricId.sleepHours, title: "Sleep Duration", kind: .number, unit: .hours,
                  group: SQDefaultGroup.sleep.rawValue, min: 0, max: 24, step: 0.1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "🌙", periods: both, isSingleDailyValue: true, goalStyle: .justTrack),

            // MARK: Nutrition & Recovery — independent morning + evening tracking
            .init(id: SQMetricId.nutrition, title: "Nutrition", kind: .scale, unit: .none,
                  group: SQDefaultGroup.positiveHabits.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "🥗", periods: eveningOnly, goalStyle: .buildUp, targetValue: 1, bodyBatteryEffect: .boostsWhenHigh),

            .init(id: SQMetricId.hydration, title: "Hydration", kind: .scale, unit: .none,
                  group: SQDefaultGroup.positiveHabits.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "💧", periods: both, isSingleDailyValue: true, goalStyle: .buildUp, targetValue: 7,
                  scaleQuantityMapping: .init(quantityUnit: .milliliters, maxQuantityValue: 3000),
                  healthKitType: .dietaryWater, healthKitReadEnabled: true, healthKitWriteEnabled: true),

            .init(id: SQMetricId.digestion, title: "Digestion", kind: .scale, unit: .none,
                  group: SQDefaultGroup.positiveHabits.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🍽️", periods: both, goalStyle: .buildUp, targetValue: 7),

            .init(id: SQMetricId.meditation, title: "Meditation", kind: .scale, unit: .none,
                  group: SQDefaultGroup.otherHabits.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🧘", periods: both, goalStyle: .buildUp, targetValue: 1),

            // MARK: Vices — independent morning + evening tracking
            .init(id: SQMetricId.alcohol, title: "Alcohol", kind: .number, unit: .count,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 0.1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "🍺", periods: both, isSingleDailyValue: true, goalStyle: .avoidIt, bodyBatteryEffect: .drainsWhenHigh,
                  scaleQuantityMapping: .init(quantityUnit: .count, maxQuantityValue: 10, quantityLabelOverride: "drink count"),
                  healthKitType: .numberOfAlcoholicBeverages, healthKitReadEnabled: true, healthKitWriteEnabled: true),

            .init(id: SQMetricId.caffeine, title: "Caffeine", kind: .number, unit: .milligrams,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 1000, step: 0.1,
                  isPreset: true, isEnabled: true, isDefault: true, sortOrder: next(),
                  emoji: "☕", periods: both, isSingleDailyValue: true, goalStyle: .avoidIt, bodyBatteryEffect: .drainsWhenHigh,
                  scaleQuantityMapping: .init(quantityUnit: .milligrams, maxQuantityValue: 200),
                  healthKitType: .dietaryCaffeine, healthKitReadEnabled: true, healthKitWriteEnabled: true),

            .init(id: SQMetricId.weed, title: "Weed", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🌿", periods: both, goalStyle: .avoidIt),

            .init(id: SQMetricId.porn, title: "Porn", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  periods: both, goalStyle: .avoidIt),

            .init(id: SQMetricId.nicotine, title: "Nicotine", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🚬", periods: both, goalStyle: .avoidIt,
                  scaleQuantityMapping: .init(quantityUnit: .count, maxQuantityValue: 10, quantityLabelOverride: "count")),

            .init(id: SQMetricId.gambling, title: "Gambling", kind: .number, unit: .dollars,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10_000, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🎲", periods: both, isSingleDailyValue: true, goalStyle: .avoidIt),

            .init(id: SQMetricId.gaming, title: "Gaming", kind: .number, unit: .minutes,
                  group: SQDefaultGroup.otherHabits.rawValue, min: 0, max: 1440, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🎮", periods: both, isSingleDailyValue: true, goalStyle: .justTrack),

            .init(id: SQMetricId.cravings, title: "Cravings", kind: .scale, unit: .none,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 10, step: 1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "🍬", periods: both, goalStyle: .keepLow),

            .init(id: SQMetricId.screenTime, title: "Screen Time", kind: .number, unit: .hours,
                  group: SQDefaultGroup.vices.rawValue, min: 0, max: 24, step: 0.1,
                  isPreset: true, isEnabled: false, isDefault: false, sortOrder: next(),
                  emoji: "📱", periods: both, isSingleDailyValue: true, goalStyle: .keepLow),
        ]
    }
}
