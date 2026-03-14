//
//  SQMetric.swift
//  BeastFitness

import Foundation
import BeastFitnessCore

// MARK: - SQMetricKind

enum SQMetricKind: String, Codable, CaseIterable, UnfrozenEnum {
    case binary      // Legacy 0/1 — no longer used for new metrics; kept for backward-compatibility decoding
    case scale       // Segmented control (min–max by step)
    case number      // Free-form numeric input (hours, lbs, etc.)
    case unknown     // Fallback for unrecognized values from Firestore
}

// MARK: - SQMetricUnit

enum SQMetricUnit: String, Codable, CaseIterable, UnfrozenEnum {
    case none
    case hours
    case count
    case pounds
    case kilograms
    case percent
    case unknown     // Fallback for unrecognized values from Firestore
}

// MARK: - SQMetricPeriod

/// Determines which check-in screen a metric appears on.
enum SQMetricPeriod: String, Codable, CaseIterable, Hashable, UnfrozenEnum {
    case morning   // Appears on the morning check-in screen (logged before noon)
    case evening   // Appears on the evening check-in screen (logged at noon or later)
    case unknown   // Fallback for unrecognized values from Firestore
}

// MARK: - SQDefaultGroup

/// Well-known default group names. Users may also create arbitrary group strings;
/// these are just the ones that ship with presets and appear in the picker by default.
enum SQDefaultGroup: String, CaseIterable, UnfrozenEnum {
    case stats          = "Stats"            // One-time or infrequent physical measurements (e.g. weight)
    case self_          = "Self"             // Daily mental/physical state metrics
    case sleep          = "Sleep"            // Sleep tracking metrics
    case positiveHabits = "Positive Habits"  // Behaviors to build (nutrition, meditation)
    case vices          = "Vices"            // Behaviors to monitor (alcohol, caffeine, etc.)
    case general        = "General"          // Fallback for user-created metrics
    case unknown        = "unknown"          // Fallback for unrecognized values from Firestore
    case habit          = "Habit"            // Legacy — retained for migration read path only
    case personal       = "Self_legacy"      // Legacy alias for .self_ — used only during migration
}

// MARK: - SQMetricDefinition

struct SQMetricDefinition: Identifiable, Codable, Hashable {
    let id: String               // Stable preset IDs or UUIDs for custom metrics
    var title: String            // Display name e.g. "Mood", "Sleep Hours", "Alcohol"
    var kind: SQMetricKind       // How the value is entered (scale, number, etc.)
    var unit: SQMetricUnit       // Unit for display purposes (e.g. pounds, hours)
    var group: String            // User-facing group name (e.g. "Self", "Vices") — any string is valid
    var min: Float?              // Minimum value for scale/number entry
    var max: Float?              // Maximum value for scale/number entry
    var step: Float?             // Step granularity for scale segmented control
    var isPreset: Bool                  // True if this metric ships with the app
    var isEnabled: Bool                 // True if the user is actively tracking this metric
    var isDefault: Bool                 // True if this metric is enabled by default for new users on first launch
    var sortOrder: Int                  // Display order within the check-in form
    var isArchived: Bool                // Soft-deleted; hidden from all lists but preserved in history
    var emoji: String?                  // Optional single-grapheme emoji chosen by the user
    var periods: Set<SQMetricPeriod>    // Which check-in screen(s) this metric appears on
    /// When `true`, only one entry per calendar day is stored — the same slot is pre-filled
    /// and overwritten regardless of which session (morning/evening) the user edits it from.
    /// Use for measurements that represent a single daily fact (e.g. sleep hours, weight).
    /// When `false`, morning and evening sessions each write to their own independent entry.
    var isSingleDailyValue: Bool
    var updatedAt: Date                 // UTC timestamp of last modification; used for incremental Firestore sync

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
        isDefault: Bool = false,
        sortOrder: Int,
        isArchived: Bool = false,
        emoji: String? = nil,
        periods: Set<SQMetricPeriod> = [.morning],
        isSingleDailyValue: Bool = false,
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
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.emoji = emoji
        self.periods = periods
        self.isSingleDailyValue = isSingleDailyValue
        self.updatedAt = updatedAt
    }

    // MARK: - Custom Decoder (handles missing fields from older Firestore documents)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try  c.decode(String.self,             forKey: .id)
        title             = try  c.decode(String.self,             forKey: .title)
        kind              = try  c.decode(SQMetricKind.self,       forKey: .kind)
        unit              = try  c.decode(SQMetricUnit.self,       forKey: .unit)
        group             = try  c.decode(String.self,             forKey: .group)
        min               = try  c.decodeIfPresent(Float.self,     forKey: .min)
        max               = try  c.decodeIfPresent(Float.self,     forKey: .max)
        step              = try  c.decodeIfPresent(Float.self,     forKey: .step)
        isPreset          = try  c.decode(Bool.self,               forKey: .isPreset)
        isEnabled         = try  c.decode(Bool.self,               forKey: .isEnabled)
        isDefault         = (try c.decodeIfPresent(Bool.self,      forKey: .isDefault)) ?? false
        sortOrder         = try  c.decode(Int.self,                forKey: .sortOrder)
        isArchived        = try  c.decode(Bool.self,               forKey: .isArchived)
        emoji             = try  c.decodeIfPresent(String.self,    forKey: .emoji)
        isSingleDailyValue = (try c.decodeIfPresent(Bool.self,     forKey: .isSingleDailyValue)) ?? false
        updatedAt         = (try c.decodeIfPresent(Date.self,      forKey: .updatedAt)) ?? .now

        // Decode periods: try new array format first, then fall back to legacy single-period field
        if let periodsArray = try c.decodeIfPresent([SQMetricPeriod].self, forKey: .periods) {
            periods = Set(periodsArray.filter { $0 != .unknown })
        } else if let legacyPeriod = try c.decodeIfPresent(SQMetricPeriod.self, forKey: .period) {
            periods = legacyPeriod == .unknown ? [.morning] : [legacyPeriod]
        } else {
            periods = [.morning]
        }
        if periods.isEmpty { periods = [.morning] }
    }

    // MARK: - Custom Encoder
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                forKey: .id)
        try c.encode(title,             forKey: .title)
        try c.encode(kind,              forKey: .kind)
        try c.encode(unit,              forKey: .unit)
        try c.encode(group,             forKey: .group)
        try c.encodeIfPresent(min,      forKey: .min)
        try c.encodeIfPresent(max,      forKey: .max)
        try c.encodeIfPresent(step,     forKey: .step)
        try c.encode(isPreset,          forKey: .isPreset)
        try c.encode(isEnabled,         forKey: .isEnabled)
        try c.encode(isDefault,         forKey: .isDefault)
        try c.encode(sortOrder,         forKey: .sortOrder)
        try c.encode(isArchived,        forKey: .isArchived)
        try c.encodeIfPresent(emoji,    forKey: .emoji)
        try c.encode(isSingleDailyValue, forKey: .isSingleDailyValue)
        try c.encode(updatedAt,         forKey: .updatedAt)
        // Encode periods as a sorted array for deterministic output
        try c.encode(periods.filter { $0 != .unknown }.map(\.rawValue).sorted(), forKey: .periods)
    }

    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case id, title, kind, unit, group, min, max, step
        case isPreset, isEnabled, isDefault, sortOrder, isArchived, emoji, updatedAt
        case isSingleDailyValue
        case periods   // new format: array (encode + decode)
        case period    // legacy format: single string (decode only)
    }
}

// MARK: - SQMetricId

/// Stable string identifiers for all preset metrics.
enum SQMetricId {

    // MARK: Stats
    static let weight        = "metric.weight"          // number (pounds); morning + evening

    // MARK: Self — enabled by default
    static let mood          = "metric.mood"            // scale 0–10; morning + evening
    static let mentalClarity = "metric.mentalClarity"   // scale 0–10; morning + evening
    static let energy        = "metric.energy"          // scale 0–10; morning + evening
    static let soreness      = "metric.soreness"        // scale 0–10; morning + evening

    // MARK: Sleep
    static let sleepQuality  = "metric.sleepQuality"   // scale 0–10; morning + evening
    static let sleepHours    = "metric.sleepHours"     // number 0–24 hrs; morning + evening

    // MARK: Positive Habits
    static let meditation    = "metric.meditation"     // scale 0–10; evening
    static let nutrition     = "metric.nutrition"      // scale 0–10; evening — NEW

    // MARK: Vices — alcohol and caffeine enabled by default
    static let alcohol       = "metric.alcohol"        // scale 0–10; evening
    static let caffeine      = "metric.caffeine"       // scale 0–10; evening
    static let weed          = "metric.weed"           // scale 0–10; evening
    static let porn          = "metric.porn"           // scale 0–10; evening
    static let nicotine      = "metric.nicotine"       // scale 0–10; evening — NEW

    // MARK: - Custom metric ID generator
    static func custom(_ uuid: UUID = UUID()) -> String {
        "metric.custom.\(uuid.uuidString.lowercased())"
    }
}
