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

enum SQMetricGroup: String, Codable, CaseIterable {
    case state       // Physical/mental state: mood, energy, clarity, soreness, sleep
    case habits      // Behavioral tracking: alcohol, weed, porn, caffeine, meditation
    case custom      // User-created metrics
}

struct SQMetricDefinition: Identifiable, Codable, Hashable {
    let id: String               // stable preset IDs + UUIDs for custom
    var title: String            // "Mood", "Sleep Hours", "Alcohol", "Weed", "Custom X"
    var kind: SQMetricKind
    var unit: SQMetricUnit
    var group: SQMetricGroup     // category: state, habits, or custom
    var min: Float?              // for scale/number
    var max: Float?
    var step: Float?             // slider granularity
    var isPreset: Bool
    var isEnabled: Bool          // user chooses what they track
    var sortOrder: Int
    var isArchived: Bool
    var emoji: String?           // user-chosen emoji (single grapheme cluster)
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
