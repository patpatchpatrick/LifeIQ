//
//  SQMetric.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import Foundation

enum SQMetricKind: String, Codable, CaseIterable {
    case binary      // 0/1
    case scale       // slider
    case number      // numeric input (hours, lbs, etc.)
}

enum SQMetricUnit: String, Codable, CaseIterable {
    case none
    case hours
    case count
    case pounds
    case kilograms
    case percent
}

/// Well-known default group names. Users may also create arbitrary group strings;
/// these are just the ones that ship with presets and appear in the picker by default.
enum SQDefaultGroup: String, CaseIterable {
    case personal = "Self"
    case habit    = "Habit"
    case general  = "General"
}

struct SQMetricDefinition: Identifiable, Codable, Hashable {
    let id: String               // stable preset IDs + UUIDs for custom
    var title: String            // "Mood", "Sleep Hours", "Alcohol", "Weed", "Custom X"
    var kind: SQMetricKind
    var unit: SQMetricUnit
    var group: String            // user-facing group name (e.g. "Self", "Habit", "General")
    var min: Float?              // for scale/number
    var max: Float?
    var step: Float?             // slider granularity
    var isPreset: Bool
    var isEnabled: Bool          // user chooses what they track
    var sortOrder: Int
    var isArchived: Bool
    var emoji: String?           // user-chosen emoji (single grapheme cluster)
    var updatedAt: Date = .now   // last modification timestamp; used for Firestore sync

    // MARK: - Manual Init (non-decoder)
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
        isEnabled: Bool = true,
        sortOrder: Int,
        isArchived: Bool = false,
        emoji: String? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.unit = unit
        self.group = group
        self.min = min
        self.max = max
        self.step = step
        self.isPreset = isPreset
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.emoji = emoji
        self.updatedAt = updatedAt
    }

    // MARK: - Custom Decoder
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try  c.decode(String.self,          forKey: .id)
        title       = try  c.decode(String.self,          forKey: .title)
        kind        = try  c.decode(SQMetricKind.self,    forKey: .kind)
        unit        = try  c.decode(SQMetricUnit.self,    forKey: .unit)
        group       = try  c.decode(String.self,           forKey: .group)
        min         = try  c.decodeIfPresent(Float.self,  forKey: .min)
        max         = try  c.decodeIfPresent(Float.self,  forKey: .max)
        step        = try  c.decodeIfPresent(Float.self,  forKey: .step)
        isPreset    = try  c.decode(Bool.self,            forKey: .isPreset)
        isEnabled   = try  c.decode(Bool.self,            forKey: .isEnabled)
        sortOrder   = try  c.decode(Int.self,             forKey: .sortOrder)
        isArchived  = try  c.decode(Bool.self,            forKey: .isArchived)
        emoji       = try  c.decodeIfPresent(String.self, forKey: .emoji)
        updatedAt   = try  c.decodeIfPresent(Date.self,   forKey: .updatedAt) ?? .now
    }
}


enum SQMetricId {
    // MARK: - Core Daily Metrics (enabled by default)

    static let mood = "metric.mood"                    // 0–10
    static let mentalClarity = "metric.mentalClarity"  // 0–10
    static let energy = "metric.energy"                // 0–10
    static let soreness = "metric.soreness"            // 0–10
    static let sleepHours = "metric.sleepHours"        // 0–24
    static let sleepQuality = "metric.sleepQuality"    // 1–5

    // MARK: - Optional Preset Metrics (disabled by default)

    static let alcohol = "metric.alcohol"              // binary
    static let weed = "metric.weed"                    // binary
    static let porn = "metric.porn"                    // binary
    static let caffeine = "metric.caffeine"            // binary
    static let meditation = "metric.meditation"        // binary

    // MARK: - Future-proofing

    /// Helper for generating custom metric IDs
    static func custom(_ uuid: UUID = UUID()) -> String {
        "metric.custom.\(uuid.uuidString.lowercased())"
    }
}
