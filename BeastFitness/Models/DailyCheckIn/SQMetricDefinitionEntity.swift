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

    var minValue: Float?
    var maxValue: Float?
    var stepValue: Float?

    var isPreset: Bool
    var isEnabled: Bool
    var sortOrder: Int
    var isArchived: Bool

    // Optional: for Firestore sync later
    var updatedAt: Date

    init(
        id: String,
        title: String,
        kind: SQMetricKind,
        unit: SQMetricUnit,
        min: Float? = nil,
        max: Float? = nil,
        step: Float? = nil,
        isPreset: Bool,
        isEnabled: Bool,
        sortOrder: Int,
        isArchived: Bool
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.unitRaw = unit.rawValue
        self.minValue = min
        self.maxValue = max
        self.stepValue = step
        self.isPreset = isPreset
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.updatedAt = .now
    }
}

extension SQMetricDefinitionEntity {
    var kind: SQMetricKind { SQMetricKind(rawValue: kindRaw) ?? .number }
    var unit: SQMetricUnit { SQMetricUnit(rawValue: unitRaw) ?? .none }

    func toDefinition() -> SQMetricDefinition {
        .init(
            id: id,
            title: title,
            kind: kind,
            unit: unit,
            min: minValue,
            max: maxValue,
            step: stepValue,
            isPreset: isPreset,
            isEnabled: isEnabled,
            sortOrder: sortOrder,
            isArchived: isArchived
        )
    }

    func apply(_ def: SQMetricDefinition) {
        title = def.title
        kindRaw = def.kind.rawValue
        unitRaw = def.unit.rawValue
        minValue = def.min
        maxValue = def.max
        stepValue = def.step
        isPreset = def.isPreset
        isEnabled = def.isEnabled
        sortOrder = def.sortOrder
        isArchived = def.isArchived
        updatedAt = .now
    }
}
