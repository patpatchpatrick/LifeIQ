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
    var periodRaw: String = "morning"  // Stores SQMetricPeriod.rawValue — default allows lightweight migration of existing rows
    var isDefault: Bool = false        // True if this metric is enabled by default for new users on first launch

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
        period: SQMetricPeriod = .morning,
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
        self.periodRaw = period.rawValue
        self.isDefault = isDefault
        self.updatedAt = .now
    }
}

extension SQMetricDefinitionEntity {
    var kind: SQMetricKind { SQMetricKind(unfrozenRawValue: kindRaw) }
    var unit: SQMetricUnit { SQMetricUnit(unfrozenRawValue: unitRaw) }
    var period: SQMetricPeriod { SQMetricPeriod(unfrozenRawValue: periodRaw) }
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
            period: period,
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
        periodRaw = def.period.rawValue
        updatedAt = def.updatedAt
    }
}
