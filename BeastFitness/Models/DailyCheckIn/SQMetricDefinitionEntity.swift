//
//  SQMetricDefinitionEntity.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import Foundation
import SwiftData

@Model
final class SQMetricDefinitionEntity {
    @Attribute(.unique) var id: String

    var title: String
    var kindRaw: String
    var unitRaw: String
    var groupRaw: String

    var minValue: Float?
    var maxValue: Float?
    var stepValue: Float?

    var isPreset: Bool
    var isEnabled: Bool
    var sortOrder: Int
    var isArchived: Bool
    var emoji: String?
    /// Comma-separated SQMetricPeriod raw values (e.g. "morning", "evening", "morning,evening").
    /// Default "morning" allows lightweight migration of pre-existing rows.
    var periodRaw: String = "morning"
    var isDefault: Bool = false           // True if this metric is enabled by default for new users on first launch
    /// When true, one entry per calendar day shared across all check-in sessions (e.g. sleep, weight).
    /// Default false allows lightweight migration of pre-existing rows.
    var isSingleDailyValue: Bool = false

    // Optional: for Firestore sync later
    var updatedAt: Date

    init(
        id: String,
        title: String,
        kind: SQMetricKind,
        unit: SQMetricUnit,
        group: String,
        min: Float? = nil,
        max: Float? = nil,
        step: Float? = nil,
        isPreset: Bool,
        isEnabled: Bool,
        sortOrder: Int,
        isArchived: Bool,
        emoji: String? = nil,
        periods: Set<SQMetricPeriod> = [.morning],
        isSingleDailyValue: Bool = false,
        isDefault: Bool = false
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.unitRaw = unit.rawValue
        self.groupRaw = group
        self.minValue = min
        self.maxValue = max
        self.stepValue = step
        self.isPreset = isPreset
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.emoji = emoji
        self.periodRaw = Self.serialize(periods)
        self.isSingleDailyValue = isSingleDailyValue
        self.isDefault = isDefault
        self.updatedAt = .now
    }
}

extension SQMetricDefinitionEntity {
    var kind: SQMetricKind { SQMetricKind(unfrozenRawValue: kindRaw) }
    var unit: SQMetricUnit { SQMetricUnit(unfrozenRawValue: unitRaw) }

    /// Parses `periodRaw` (comma-separated) into a set of periods.
    /// Handles legacy single-value strings ("morning", "evening") and new multi-value strings.
    var periods: Set<SQMetricPeriod> {
        let parsed = Self.parse(periodRaw)
        return parsed.isEmpty ? [.morning] : parsed
    }

    /// Translates legacy enum raw values ("state", "habits", "custom") to current group names.
    var group: String {
        switch groupRaw {
        case "state":  return SQDefaultGroup.self_.rawValue   // was "Self" via old .personal alias
        case "habits": return SQDefaultGroup.habit.rawValue
        case "custom": return SQDefaultGroup.general.rawValue
        default:       return groupRaw
        }
    }

    func toDefinition() -> SQMetricDefinition {
        .init(
            id: id,
            title: title,
            kind: kind,
            unit: unit,
            group: group,
            min: minValue,
            max: maxValue,
            step: stepValue,
            isPreset: isPreset,
            isEnabled: isEnabled,
            isDefault: isDefault,
            sortOrder: sortOrder,
            isArchived: isArchived,
            emoji: emoji,
            periods: periods,
            isSingleDailyValue: isSingleDailyValue,
            updatedAt: updatedAt
        )
    }

    /// Apply a remote definition onto this entity, preserving its `updatedAt`.
    func apply(_ def: SQMetricDefinition) {
        title = def.title
        kindRaw = def.kind.rawValue
        unitRaw = def.unit.rawValue
        groupRaw = def.group
        minValue = def.min
        maxValue = def.max
        stepValue = def.step
        isPreset = def.isPreset
        isEnabled = def.isEnabled
        isDefault = def.isDefault
        sortOrder = def.sortOrder
        isArchived = def.isArchived
        emoji = def.emoji
        periodRaw = Self.serialize(def.periods)
        isSingleDailyValue = def.isSingleDailyValue
        updatedAt = def.updatedAt
    }

    // MARK: - Period Serialization

    /// Serializes a set of periods to a sorted comma-separated string for storage.
    static func serialize(_ periods: Set<SQMetricPeriod>) -> String {
        periods
            .filter { $0 != .unknown }
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }

    /// Parses a comma-separated period string back into a set.
    static func parse(_ raw: String) -> Set<SQMetricPeriod> {
        Set(raw.split(separator: ",").compactMap { segment in
            let p = SQMetricPeriod(unfrozenRawValue: String(segment))
            return p == .unknown ? nil : p
        })
    }
}
