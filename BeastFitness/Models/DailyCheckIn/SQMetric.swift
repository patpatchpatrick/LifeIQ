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
    case minutes
    case hours
    case count
    case milligrams
    case grams
    case milliliters
    case liters
    case fluidOunces
    case pounds
    case kilograms
    case percent
    case dollars
    case unknown     // Fallback for unrecognized values from Firestore
}

enum SQMetricValueMode: String, Codable, CaseIterable, UnfrozenEnum {
    case scale
    case quantity
    case unknown
}

enum SQMetricHealthKitType: String, Codable, CaseIterable, UnfrozenEnum {
    case none
    case bodyMass
    case dietaryWater
    case dietaryCaffeine
    case numberOfAlcoholicBeverages
    case unknown

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .bodyMass:
            return "Weight"
        case .dietaryWater:
            return "Water"
        case .dietaryCaffeine:
            return "Caffeine"
        case .numberOfAlcoholicBeverages:
            return "Alcoholic Beverages"
        case .unknown:
            return "Unknown"
        }
    }

    var recommendedUnit: SQMetricUnit {
        switch self {
        case .bodyMass:
            return .pounds
        case .dietaryWater:
            return .milliliters
        case .dietaryCaffeine:
            return .milligrams
        case .numberOfAlcoholicBeverages:
            return .count
        case .none, .unknown:
            return .none
        }
    }

    var supportsWrite: Bool {
        switch self {
        case .bodyMass, .dietaryWater, .dietaryCaffeine, .numberOfAlcoholicBeverages:
            return true
        case .none, .unknown:
            return false
        }
    }

    var requiresSingleDailyValue: Bool {
        switch self {
        case .bodyMass, .dietaryWater, .dietaryCaffeine, .numberOfAlcoholicBeverages:
            return true
        case .none, .unknown:
            return false
        }
    }

    var aggregationStyle: SQMetricHealthKitAggregationStyle {
        switch self {
        case .bodyMass:
            return .latestSamplePerDay
        case .dietaryWater, .dietaryCaffeine, .numberOfAlcoholicBeverages:
            return .cumulativeDailyTotal
        case .none, .unknown:
            return .cumulativeDailyTotal
        }
    }
}

enum SQMetricHealthKitAggregationStyle {
    case cumulativeDailyTotal
    case latestSamplePerDay
}

struct SQMetricScaleQuantityMapping: Codable, Hashable {
    var quantityUnit: SQMetricUnit
    var maxQuantityValue: Float
    /// Optional UI-only label when the visual wording should differ from the canonical unit.
    /// Example: canonical unit `count`, label override "drink count".
    var quantityLabelOverride: String?

    init(
        quantityUnit: SQMetricUnit,
        maxQuantityValue: Float,
        quantityLabelOverride: String? = nil
    ) {
        self.quantityUnit = quantityUnit
        self.maxQuantityValue = maxQuantityValue
        self.quantityLabelOverride = quantityLabelOverride
    }
}

// MARK: - SQMetricGoalStyle

enum SQMetricGoalStyle: String, Codable, CaseIterable, UnfrozenEnum {
    case justTrack
    case buildUp
    case keepLow
    case avoidIt
    case stayInRange
    case unknown
}

// MARK: - SQMetricBodyBatteryEffect

/// Optional user-defined contribution to the Body Battery score.
/// Preset recovery signals are handled separately in the scoring service;
/// this config is primarily for custom metrics that should nudge the score.
enum SQMetricBodyBatteryEffect: String, Codable, CaseIterable, UnfrozenEnum {
    case none
    case boostsWhenHigh
    case drainsWhenHigh
    case unknown
}

// MARK: - SQMetric Algorithm Semantics

enum SQMetricSignalRole: String, Codable, CaseIterable, Hashable, UnfrozenEnum {
    case automatic
    case behavior
    case outcome
    case symptom
    case bodyStat
    case context
    case unknown
}

enum SQMetricLifeScoreImpact: String, Codable, CaseIterable, Hashable, UnfrozenEnum {
    case automatic
    case none
    case light
    case standard
    case unknown
}

enum SQMetricInsightMode: String, Codable, CaseIterable, Hashable, UnfrozenEnum {
    case automatic
    case off
    case trendsOnly
    case exploratoryRelationships
    case curatedRelationships
    case unknown
}

enum SQMetricSensitivity: String, Codable, CaseIterable, Hashable, UnfrozenEnum {
    case normal
    case sensitive
    case medicationLike
    case unknown
}

struct SQMetricSemanticResolver {
    func signalRole(for definition: SQMetricDefinition) -> SQMetricSignalRole {
        if definition.signalRole != .automatic && definition.signalRole != .unknown {
            return definition.signalRole
        }
        return SQMetricSemanticDefaults.signalRole(forMetricId: definition.id, isPreset: definition.isPreset)
    }

    func lifeScoreImpact(for definition: SQMetricDefinition) -> SQMetricLifeScoreImpact {
        if definition.lifeScoreImpact != .automatic && definition.lifeScoreImpact != .unknown {
            return definition.lifeScoreImpact
        }
        return SQMetricSemanticDefaults.lifeScoreImpact(forMetricId: definition.id, isPreset: definition.isPreset)
    }

    func insightMode(for definition: SQMetricDefinition) -> SQMetricInsightMode {
        if definition.insightMode != .automatic && definition.insightMode != .unknown {
            return definition.insightMode
        }
        return SQMetricSemanticDefaults.insightMode(forMetricId: definition.id, isPreset: definition.isPreset)
    }

    func sensitivity(for definition: SQMetricDefinition) -> SQMetricSensitivity {
        if definition.sensitivity != .unknown {
            return definition.sensitivity
        }
        return SQMetricSemanticDefaults.sensitivity(forMetricId: definition.id, isPreset: definition.isPreset)
    }
}

enum SQMetricSemanticDefaults {
    static func signalRole(forMetricId metricId: String, isPreset: Bool) -> SQMetricSignalRole {
        guard isPreset else { return .automatic }

        switch metricId {
        case SQMetricId.weight,
             SQMetricId.sleepQuality,
             SQMetricId.sleepHours:
            return .bodyStat
        case SQMetricId.stress,
             SQMetricId.anxiety,
             SQMetricId.sickness,
             SQMetricId.pain,
             SQMetricId.cravings,
             SQMetricId.digestion,
             SQMetricId.soreness:
            return .symptom
        case SQMetricId.mood,
             SQMetricId.energy,
             SQMetricId.mentalClarity,
             SQMetricId.motivation,
             SQMetricId.productivity,
             SQMetricId.socialConnection:
            return .outcome
        case SQMetricId.nutrition,
             SQMetricId.hydration,
             SQMetricId.meditation,
             SQMetricId.alcohol,
             SQMetricId.caffeine,
             SQMetricId.weed,
             SQMetricId.porn,
             SQMetricId.nicotine,
             SQMetricId.gambling,
             SQMetricId.gaming,
             SQMetricId.screenTime:
            return .behavior
        default:
            return .automatic
        }
    }

    static func lifeScoreImpact(forMetricId metricId: String, isPreset: Bool) -> SQMetricLifeScoreImpact {
        guard isPreset else { return .none }

        switch metricId {
        case SQMetricId.weight,
             SQMetricId.weed,
             SQMetricId.porn,
             SQMetricId.nicotine,
             SQMetricId.gambling,
             SQMetricId.gaming,
             SQMetricId.screenTime:
            return .none
        default:
            return .automatic
        }
    }

    static func insightMode(forMetricId metricId: String, isPreset: Bool) -> SQMetricInsightMode {
        guard isPreset else { return .exploratoryRelationships }

        switch metricId {
        case SQMetricId.weight:
            return .trendsOnly
        default:
            return .curatedRelationships
        }
    }

    static func sensitivity(forMetricId metricId: String, isPreset: Bool) -> SQMetricSensitivity {
        guard isPreset else { return .normal }

        switch metricId {
        case SQMetricId.weight,
             SQMetricId.alcohol,
             SQMetricId.weed,
             SQMetricId.porn,
             SQMetricId.nicotine,
             SQMetricId.gambling:
            return .sensitive
        default:
            return .normal
        }
    }
}

// MARK: - SQMetricGoalEvaluator

struct SQMetricGoalEvaluation: Hashable {
    let metricId: String
    let rawValue: Double
    /// Normalized against the metric's configured min/max as 0...1 when bounds are valid.
    let normalizedValue: Double?
    /// 0...100 where 100 means best for the metric's configured goal style.
    let goalUtilityScore: Double?
    let effect: SQLifeScoreSignalEffect?
    let reason: String
}

struct SQMetricGoalEvaluator {
    func evaluate(
        value: Double,
        definition: SQMetricDefinition
    ) -> SQMetricGoalEvaluation? {
        let normalizedValue = normalizedMetricValue(value, definition: definition)

        switch definition.goalStyle {
        case .justTrack:
            return .init(
                metricId: definition.id,
                rawValue: value,
                normalizedValue: normalizedValue,
                goalUtilityScore: nil,
                effect: nil,
                reason: "justTrack"
            )

        case .buildUp:
            let utilityScore: Double?
            let reason: String
            if let target = definition.targetValue, target > 0 {
                utilityScore = clamp((value / Double(target)) * 100, min: 0, max: 100)
                reason = "buildUpTarget"
            } else {
                utilityScore = normalizedValue.map { $0 * 100 }
                reason = "buildUpNormalized"
            }

            return makeEvaluation(
                value: value,
                definition: definition,
                normalizedValue: normalizedValue,
                utilityScore: utilityScore,
                reason: reason,
                positiveThreshold: 85,
                negativeThreshold: 50
            )

        case .keepLow:
            let utilityScore: Double?
            let reason: String
            if let target = definition.targetValue {
                utilityScore = inverseScore(
                    value: value,
                    target: Double(target),
                    upperBound: keepLowUpperBound(for: definition, target: Double(target))
                )
                reason = "keepLowTarget"
            } else {
                utilityScore = normalizedValue.map { (1 - $0) * 100 }
                reason = "keepLowNormalized"
            }

            let targetMet = definition.targetValue.map { value <= Double($0) } ?? false
            return makeEvaluation(
                value: value,
                definition: definition,
                normalizedValue: normalizedValue,
                utilityScore: utilityScore,
                reason: reason,
                forcedEffect: targetMet ? .positive : nil,
                positiveThreshold: 85,
                negativeThreshold: 50
            )

        case .avoidIt:
            if value <= 0 {
                return .init(
                    metricId: definition.id,
                    rawValue: value,
                    normalizedValue: normalizedValue,
                    goalUtilityScore: 100,
                    effect: .neutral,
                    reason: "avoidItAbsent"
                )
            }

            let upperBound = max(Double(definition.max ?? 0), 1)
            let utilityScore = clamp((1 - (value / upperBound)) * 100, min: 0, max: 100)
            return makeEvaluation(
                value: value,
                definition: definition,
                normalizedValue: normalizedValue,
                utilityScore: utilityScore,
                reason: "avoidItPresent",
                positiveThreshold: 95,
                negativeThreshold: 65
            )

        case .stayInRange:
            guard
                let rangeMin = definition.targetRangeMin.map(Double.init),
                let rangeMax = definition.targetRangeMax.map(Double.init),
                rangeMax >= rangeMin
            else {
                return .init(
                    metricId: definition.id,
                    rawValue: value,
                    normalizedValue: normalizedValue,
                    goalUtilityScore: nil,
                    effect: nil,
                    reason: "stayInRangeMissingTarget"
                )
            }

            if value >= rangeMin && value <= rangeMax {
                return .init(
                    metricId: definition.id,
                    rawValue: value,
                    normalizedValue: normalizedValue,
                    goalUtilityScore: 100,
                    effect: .positive,
                    reason: "stayInRangeWithinTarget"
                )
            }

            let distance: Double
            let toleranceSpan: Double
            if value < rangeMin {
                distance = rangeMin - value
                toleranceSpan = max(rangeMin - Double(definition.min ?? 0), rangeMax - rangeMin, 1)
            } else {
                distance = value - rangeMax
                toleranceSpan = max(Double(definition.max ?? Float(rangeMax)) - rangeMax, rangeMax - rangeMin, 1)
            }

            let utilityScore = clamp((1 - (distance / toleranceSpan)) * 100, min: 0, max: 100)
            return makeEvaluation(
                value: value,
                definition: definition,
                normalizedValue: normalizedValue,
                utilityScore: utilityScore,
                reason: "stayInRangeOutsideTarget",
                positiveThreshold: 90,
                negativeThreshold: 60
            )

        case .unknown:
            return .init(
                metricId: definition.id,
                rawValue: value,
                normalizedValue: normalizedValue,
                goalUtilityScore: nil,
                effect: nil,
                reason: "unknownGoal"
            )
        }
    }

    private func makeEvaluation(
        value: Double,
        definition: SQMetricDefinition,
        normalizedValue: Double?,
        utilityScore: Double?,
        reason: String,
        forcedEffect: SQLifeScoreSignalEffect? = nil,
        positiveThreshold: Double,
        negativeThreshold: Double
    ) -> SQMetricGoalEvaluation {
        .init(
            metricId: definition.id,
            rawValue: value,
            normalizedValue: normalizedValue,
            goalUtilityScore: utilityScore,
            effect: forcedEffect ?? effect(for: utilityScore, positiveThreshold: positiveThreshold, negativeThreshold: negativeThreshold),
            reason: reason
        )
    }

    private func effect(
        for utilityScore: Double?,
        positiveThreshold: Double,
        negativeThreshold: Double
    ) -> SQLifeScoreSignalEffect? {
        guard let utilityScore else { return nil }

        if utilityScore >= positiveThreshold {
            return .positive
        }

        if utilityScore < negativeThreshold {
            return .negative
        }

        return .neutral
    }

    private func inverseScore(value: Double, target: Double, upperBound: Double) -> Double {
        guard upperBound > target else {
            return value <= target ? 100 : 0
        }

        if value <= target {
            return 100
        }

        return clamp((1 - ((value - target) / (upperBound - target))) * 100, min: 0, max: 100)
    }

    private func normalizedMetricValue(_ value: Double, definition: SQMetricDefinition) -> Double? {
        guard
            let min = definition.min.map(Double.init),
            let max = definition.max.map(Double.init),
            max > min
        else {
            return nil
        }

        return clamp((value - min) / (max - min), min: 0, max: 1)
    }

    private func keepLowUpperBound(for definition: SQMetricDefinition, target: Double) -> Double {
        let maxValue = Double(definition.max ?? Float(target + 1))
        return max(maxValue, target + 1)
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

// MARK: - SQMetricPeriod

/// Determines which check-in screen a metric appears on.
enum SQMetricPeriod: String, Codable, CaseIterable, Hashable, UnfrozenEnum {
    case morning   // Appears on the morning check-in screen
    case evening   // Appears on the evening check-in screen
    case unknown   // Fallback for unrecognized values from Firestore
}

// MARK: - SQDefaultGroup

/// Well-known default group names. Users may also create arbitrary group strings;
/// these are just the ones that ship with presets and appear in the picker by default.
enum SQDefaultGroup: String, CaseIterable, UnfrozenEnum {
    case stats          = "Stats"            // One-time or infrequent physical measurements (e.g. weight)
    case self_          = "Mind & Body"      // Daily mental/physical state metrics
    case sleep          = "Sleep"            // Sleep tracking metrics
    case positiveHabits = "Nutrition & Recovery"  // Nutrition, hydration, digestion, etc.
    case otherHabits    = "Other Habits"     // Meditation and other supportive routines
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
    /// User-configured success semantics for detail screens, streaks, and future insights.
    var goalStyle: SQMetricGoalStyle
    /// Threshold used by single-value goal styles such as `.buildUp` and `.keepLow`.
    var targetValue: Float?
    /// Lower bound used by `.stayInRange`.
    var targetRangeMin: Float?
    /// Upper bound used by `.stayInRange`.
    var targetRangeMax: Float?
    /// Optional custom contribution to Body Battery. This is aggressively capped
    /// inside the scoring service so many custom metrics cannot overwhelm the score.
    var bodyBatteryEffect: SQMetricBodyBatteryEffect
    /// Algorithm-facing semantic role used by future Life Score and Insights logic.
    var signalRole: SQMetricSignalRole
    /// Whether this metric should affect Life Score once contributor-based scoring is enabled.
    var lifeScoreImpact: SQMetricLifeScoreImpact
    /// How this metric should participate in insight generation.
    var insightMode: SQMetricInsightMode
    /// Safety classification for copy, surfacing, and future action recommendations.
    var sensitivity: SQMetricSensitivity
    /// Optional linear mapping between the metric's scale range and a real quantity.
    /// This allows a metric to be entered as either a scale or a number while preserving
    /// canonical quantity units for import/export and downstream analysis.
    var scaleQuantityMapping: SQMetricScaleQuantityMapping?
    /// Optional HealthKit quantity type to use as a fallback data source and sync target.
    var healthKitType: SQMetricHealthKitType
    /// When true, HealthKit values can fill this metric when the user has not logged it in LifeIQ.
    var healthKitReadEnabled: Bool
    /// When true, LifeIQ writes this metric back to HealthKit when the user logs a value.
    var healthKitWriteEnabled: Bool
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
        goalStyle: SQMetricGoalStyle = .justTrack,
        targetValue: Float? = nil,
        targetRangeMin: Float? = nil,
        targetRangeMax: Float? = nil,
        bodyBatteryEffect: SQMetricBodyBatteryEffect = .none,
        signalRole: SQMetricSignalRole? = nil,
        lifeScoreImpact: SQMetricLifeScoreImpact? = nil,
        insightMode: SQMetricInsightMode? = nil,
        sensitivity: SQMetricSensitivity? = nil,
        scaleQuantityMapping: SQMetricScaleQuantityMapping? = nil,
        healthKitType: SQMetricHealthKitType = .none,
        healthKitReadEnabled: Bool = false,
        healthKitWriteEnabled: Bool = false,
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
        self.goalStyle = goalStyle
        self.targetValue = targetValue
        self.targetRangeMin = targetRangeMin
        self.targetRangeMax = targetRangeMax
        self.bodyBatteryEffect = bodyBatteryEffect
        self.signalRole = signalRole ?? SQMetricSemanticDefaults.signalRole(forMetricId: id, isPreset: isPreset)
        self.lifeScoreImpact = lifeScoreImpact ?? SQMetricSemanticDefaults.lifeScoreImpact(forMetricId: id, isPreset: isPreset)
        self.insightMode = insightMode ?? SQMetricSemanticDefaults.insightMode(forMetricId: id, isPreset: isPreset)
        self.sensitivity = sensitivity ?? SQMetricSemanticDefaults.sensitivity(forMetricId: id, isPreset: isPreset)
        self.scaleQuantityMapping = scaleQuantityMapping
        self.healthKitType = healthKitType
        self.healthKitReadEnabled = healthKitReadEnabled
        self.healthKitWriteEnabled = healthKitWriteEnabled
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
        goalStyle         = (try c.decodeIfPresent(SQMetricGoalStyle.self, forKey: .goalStyle)) ?? .justTrack
        targetValue       = try  c.decodeIfPresent(Float.self,     forKey: .targetValue)
        targetRangeMin    = try  c.decodeIfPresent(Float.self,     forKey: .targetRangeMin)
        targetRangeMax    = try  c.decodeIfPresent(Float.self,     forKey: .targetRangeMax)
        bodyBatteryEffect = (try c.decodeIfPresent(SQMetricBodyBatteryEffect.self, forKey: .bodyBatteryEffect)) ?? .none
        signalRole = (try c.decodeIfPresent(SQMetricSignalRole.self, forKey: .signalRole))
            ?? SQMetricSemanticDefaults.signalRole(forMetricId: id, isPreset: isPreset)
        lifeScoreImpact = (try c.decodeIfPresent(SQMetricLifeScoreImpact.self, forKey: .lifeScoreImpact))
            ?? SQMetricSemanticDefaults.lifeScoreImpact(forMetricId: id, isPreset: isPreset)
        insightMode = (try c.decodeIfPresent(SQMetricInsightMode.self, forKey: .insightMode))
            ?? SQMetricSemanticDefaults.insightMode(forMetricId: id, isPreset: isPreset)
        sensitivity = (try c.decodeIfPresent(SQMetricSensitivity.self, forKey: .sensitivity))
            ?? SQMetricSemanticDefaults.sensitivity(forMetricId: id, isPreset: isPreset)
        scaleQuantityMapping = try c.decodeIfPresent(SQMetricScaleQuantityMapping.self, forKey: .scaleQuantityMapping)
        healthKitType = (try c.decodeIfPresent(SQMetricHealthKitType.self, forKey: .healthKitType)) ?? .none
        healthKitReadEnabled = (try c.decodeIfPresent(Bool.self, forKey: .healthKitReadEnabled)) ?? false
        healthKitWriteEnabled = (try c.decodeIfPresent(Bool.self, forKey: .healthKitWriteEnabled)) ?? false
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
        try c.encode(goalStyle,         forKey: .goalStyle)
        try c.encodeIfPresent(targetValue, forKey: .targetValue)
        try c.encodeIfPresent(targetRangeMin, forKey: .targetRangeMin)
        try c.encodeIfPresent(targetRangeMax, forKey: .targetRangeMax)
        try c.encode(bodyBatteryEffect, forKey: .bodyBatteryEffect)
        try c.encode(signalRole, forKey: .signalRole)
        try c.encode(lifeScoreImpact, forKey: .lifeScoreImpact)
        try c.encode(insightMode, forKey: .insightMode)
        try c.encode(sensitivity, forKey: .sensitivity)
        try c.encodeIfPresent(scaleQuantityMapping, forKey: .scaleQuantityMapping)
        try c.encode(healthKitType, forKey: .healthKitType)
        try c.encode(healthKitReadEnabled, forKey: .healthKitReadEnabled)
        try c.encode(healthKitWriteEnabled, forKey: .healthKitWriteEnabled)
        try c.encode(updatedAt,         forKey: .updatedAt)
        // Encode periods as a sorted array for deterministic output
        try c.encode(periods.filter { $0 != .unknown }.map(\.rawValue).sorted(), forKey: .periods)
    }

    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case id, title, kind, unit, group, min, max, step
        case isPreset, isEnabled, isDefault, sortOrder, isArchived, emoji, updatedAt
        case isSingleDailyValue
        case goalStyle, targetValue, targetRangeMin, targetRangeMax
        case bodyBatteryEffect
        case signalRole, lifeScoreImpact, insightMode, sensitivity
        case scaleQuantityMapping
        case healthKitType, healthKitReadEnabled, healthKitWriteEnabled
        case periods   // new format: array (encode + decode)
        case period    // legacy format: single string (decode only)
    }
}

extension SQMetricDefinition {
    var defaultEntryMode: SQMetricValueMode {
        switch kind {
        case .scale, .binary:
            return .scale
        case .number:
            return .quantity
        case .unknown:
            return .unknown
        }
    }

    var supportsScaleEntry: Bool {
        switch kind {
        case .scale, .binary:
            return true
        case .number:
            return scaleQuantityMapping != nil
        case .unknown:
            return false
        }
    }

    var supportsQuantityEntry: Bool {
        switch kind {
        case .number:
            return true
        case .scale, .binary:
            return scaleQuantityMapping != nil
        case .unknown:
            return false
        }
    }

    var allowsAlternateEntryMode: Bool {
        supportsScaleEntry && supportsQuantityEntry
    }

    var hasHealthKitLink: Bool {
        healthKitType != .none && healthKitType != .unknown
    }

    var isHealthKitReadEnabledEffective: Bool {
        hasHealthKitLink && healthKitReadEnabled
    }

    var isHealthKitWriteEnabledEffective: Bool {
        hasHealthKitLink && healthKitWriteEnabled && healthKitType.supportsWrite
    }

    var quantityUnit: SQMetricUnit {
        scaleQuantityMapping?.quantityUnit ?? unit
    }

    var quantityLabel: String {
        scaleQuantityMapping?.quantityLabelOverride ?? quantityUnit.shortDisplayName
    }

    var scaleMinValue: Float {
        switch kind {
        case .binary:
            return 0
        case .number:
            return scaleQuantityMapping == nil ? (min ?? 0) : 0
        case .scale:
            return min ?? 0
        case .unknown:
            return min ?? 0
        }
    }

    var scaleMaxValue: Float {
        switch kind {
        case .binary:
            return 1
        case .number:
            return scaleQuantityMapping == nil ? (max ?? 10) : 10
        case .scale:
            return max ?? 10
        case .unknown:
            return max ?? 10
        }
    }

    var scaleStepValue: Float {
        switch kind {
        case .binary:
            return 1
        case .number:
            return scaleQuantityMapping == nil ? (step ?? 1) : 1
        case .scale:
            return step ?? 1
        case .unknown:
            return step ?? 1
        }
    }

    func quantityValue(forScaleValue scaleValue: Float) -> Float? {
        guard let mapping = scaleQuantityMapping else { return nil }
        let minScale = scaleMinValue
        let maxScale = scaleMaxValue
        guard maxScale > minScale, mapping.maxQuantityValue > 0 else { return nil }
        let normalized = (scaleValue - minScale) / (maxScale - minScale)
        return Swift.max(Float(0), normalized) * mapping.maxQuantityValue
    }

    func scaleValue(forQuantityValue quantityValue: Float) -> Float? {
        guard let mapping = scaleQuantityMapping else { return nil }
        let minScale = scaleMinValue
        let maxScale = scaleMaxValue
        guard maxScale > minScale, mapping.maxQuantityValue > 0 else { return nil }
        let normalized = quantityValue / mapping.maxQuantityValue
        let clamped = Swift.min(Float(1), Swift.max(Float(0), normalized))
        return minScale + ((maxScale - minScale) * clamped)
    }

    func displayUnit(for unitSystem: SQUnitSystem) -> SQMetricUnit {
        quantityUnit.displayUnit(for: unitSystem)
    }

    func displayQuantityValue(_ quantityValue: Float, for unitSystem: SQUnitSystem) -> Float {
        quantityUnit.convert(quantityValue, to: displayUnit(for: unitSystem)) ?? quantityValue
    }

    func canonicalQuantityValue(fromDisplayValue value: Float, unitSystem: SQUnitSystem) -> Float {
        displayUnit(for: unitSystem).convert(value, to: quantityUnit) ?? value
    }
}

extension SQMetricUnit {
    var sqUnit: SQUnit? {
        switch self {
        case .minutes:
            return .minute
        case .hours:
            return .hour
        case .count:
            return .count
        case .milligrams:
            return .milligram
        case .grams:
            return .gram
        case .milliliters:
            return .milliliter
        case .liters:
            return .liter
        case .fluidOunces:
            return .fluidOunce
        case .pounds:
            return .pound
        case .kilograms:
            return .kilogram
        case .percent:
            return .percent
        case .none, .dollars, .unknown:
            return nil
        }
    }

    func convert(_ value: Float, to unit: SQMetricUnit) -> Float? {
        guard let fromUnit = sqUnit, let toUnit = unit.sqUnit else {
            return self == unit ? value : nil
        }

        guard let converted = fromUnit.convert(Double(value), to: toUnit) else { return nil }
        return Float(converted)
    }

    func displayUnit(for unitSystem: SQUnitSystem) -> SQMetricUnit {
        switch self {
        case .kilograms, .pounds:
            return unitSystem == .metric ? .kilograms : .pounds
        case .milliliters, .liters, .fluidOunces:
            return unitSystem == .metric ? .milliliters : .fluidOunces
        default:
            return self
        }
    }

    var shortDisplayName: String {
        switch self {
        case .none:
            return ""
        case .minutes:
            return "min"
        case .hours:
            return "hrs"
        case .count:
            return "count"
        case .milligrams:
            return "mg"
        case .grams:
            return "g"
        case .milliliters:
            return "mL"
        case .liters:
            return "L"
        case .fluidOunces:
            return "fl oz"
        case .pounds:
            return "lbs"
        case .kilograms:
            return "kg"
        case .percent:
            return "%"
        case .dollars:
            return "$"
        case .unknown:
            return ""
        }
    }

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .minutes:
            return "Minutes"
        case .hours:
            return "Hours"
        case .count:
            return "Count"
        case .milligrams:
            return "Milligrams (mg)"
        case .grams:
            return "Grams (g)"
        case .milliliters:
            return "Milliliters (mL)"
        case .liters:
            return "Liters (L)"
        case .fluidOunces:
            return "Fluid Ounces (fl oz)"
        case .pounds:
            return "Pounds (lbs)"
        case .kilograms:
            return "Kilograms (kg)"
        case .percent:
            return "Percent (%)"
        case .dollars:
            return "Dollars ($)"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - SQMetricId

/// Stable string identifiers for all preset metrics.
enum SQMetricId {

    // MARK: Stats
    static let weight        = "metric.weight"          // number (pounds); morning + evening

    // MARK: Mind & Body — core daily readiness signals
    static let mood          = "metric.mood"            // scale 0–10; morning + evening
    static let mentalClarity = "metric.mentalClarity"   // scale 0–10; morning + evening
    static let energy        = "metric.energy"          // scale 0–10; morning + evening
    static let soreness      = "metric.soreness"        // Legacy id; now product-facing Soreness, scale 0–10 where lower is better.
    static let stress        = "metric.stress"          // scale 0–10; morning + evening
    static let motivation    = "metric.motivation"      // scale 0–10; morning + evening
    static let anxiety       = "metric.anxiety"         // scale 0–10; morning + evening
    static let sickness      = "metric.sickness"        // scale 0–10; morning + evening
    static let pain          = "metric.pain"            // scale 0–10; morning + evening
    static let productivity  = "metric.productivity"    // scale 0–10; morning + evening
    static let socialConnection = "metric.socialConnection" // scale 0–10; morning + evening

    // MARK: Sleep
    static let sleepQuality  = "metric.sleepQuality"   // scale 0–10; morning + evening
    static let sleepHours    = "metric.sleepHours"     // number 0–24 hrs; morning + evening

    // MARK: Nutrition & Recovery
    static let hydration     = "metric.hydration"      // scale 0–10; morning + evening
    static let digestion     = "metric.digestion"      // scale 0–10; morning + evening
    static let meditation    = "metric.meditation"     // scale 0–10; evening
    static let nutrition     = "metric.nutrition"      // scale 0–10; evening

    // MARK: Vices — alcohol and caffeine enabled by default
    static let alcohol       = "metric.alcohol"        // scale 0–10; evening
    static let caffeine      = "metric.caffeine"       // scale 0–10; evening
    static let weed          = "metric.weed"           // scale 0–10; evening
    static let porn          = "metric.porn"           // scale 0–10; evening
    static let nicotine      = "metric.nicotine"       // scale 0–10; evening
    static let gambling      = "metric.gambling"       // number 0+ dollars; morning + evening
    static let gaming        = "metric.gaming"         // number 0–1440 minutes; morning + evening
    static let cravings      = "metric.cravings"       // scale 0–10; morning + evening
    static let screenTime    = "metric.screenTime"     // number 0–24 hrs; morning + evening

    // MARK: - Custom metric ID generator
    static func custom(_ uuid: UUID = UUID()) -> String {
        "metric.custom.\(uuid.uuidString.lowercased())"
    }
}
