//
//  SQMetricEntry.swift
//  BeastFitness
//

import Foundation

/// A single metric value logged by the user during a check-in.
/// This is the canonical analytics storage unit — one entry per metric per check-in submission.
struct SQMetricEntry: Identifiable, Codable, Hashable {

    // MARK: - Identity

    var id: String
    /// References `SQMetricDefinition.id` — identifies which metric was logged.
    var metricId: String

    // MARK: - Timing

    /// UTC timestamp of when the user submitted this entry.
    var recordedAt: Date
    /// "YYYY-MM-DD" in the user's local timezone at time of entry.
    /// Used to group entries into calendar days for display and insights, handles travel correctly.
    var anchorDayKey: String
    /// IANA timezone identifier (e.g. "America/New_York") at time of entry.
    /// Stored for auditability and to allow recomputing `anchorDayKey` if needed.
    var timeZoneIdentifier: String

    // MARK: - Period

    /// The check-in period this entry was logged in (morning or evening).
    var period: SQMetricPeriod

    // MARK: - Value

    /// The UI mode the user used when logging this value.
    var enteredMode: SQMetricValueMode
    /// The value as entered by the user in `enteredMode`.
    var rawValue: Float
    /// When available, the entry converted onto the metric's scale range.
    var scaleValue: Float?
    /// When available, the entry converted into the metric's canonical quantity unit.
    var quantityValue: Float?
    /// `rawValue` converted to a 0–10 score for the insight engine.
    /// Allows comparing mapped-scale metrics regardless of the UI mode the user entered.
    var normalizedScore: Float

    // MARK: - Init

    init(
        id: String = UUID().uuidString,
        metricId: String,
        recordedAt: Date = .now,
        anchorDayKey: String,
        timeZoneIdentifier: String,
        period: SQMetricPeriod,
        enteredMode: SQMetricValueMode,
        rawValue: Float,
        scaleValue: Float?,
        quantityValue: Float?,
        normalizedScore: Float
    ) {
        self.id = id
        self.metricId = metricId
        self.recordedAt = recordedAt
        self.anchorDayKey = anchorDayKey
        self.timeZoneIdentifier = timeZoneIdentifier
        self.period = period
        self.enteredMode = enteredMode
        self.rawValue = rawValue
        self.scaleValue = scaleValue
        self.quantityValue = quantityValue
        self.normalizedScore = normalizedScore
    }
}

struct SQMetricLoggedValue: Codable, Hashable {
    var enteredMode: SQMetricValueMode
    var rawValue: Float
    var scaleValue: Float?
    var quantityValue: Float?

    var displayValue: Float {
        switch enteredMode {
        case .scale:
            return scaleValue ?? rawValue
        case .quantity:
            return quantityValue ?? rawValue
        case .unknown:
            return rawValue
        }
    }

    func value(for definition: SQMetricDefinition) -> Float {
        switch definition.defaultEntryMode {
        case .scale:
            return scaleValue ?? displayValue
        case .quantity:
            return quantityValue ?? displayValue
        case .unknown:
            return displayValue
        }
    }
}

// MARK: - Normalization Helper

extension SQMetricEntry {
    static func normalizedScaleScore(for scaleValue: Float, definition: SQMetricDefinition) -> Float {
        let min = definition.scaleMinValue
        let max = definition.scaleMaxValue
        guard max > min else { return scaleValue }
        let normalized = (scaleValue - min) / (max - min) * 10
        return Swift.min(Float(10), Swift.max(Float(0), normalized))
    }

    /// Computes `normalizedScore` from a raw value and metric definition bounds.
    /// - Scale metrics: `(rawValue - min) / (max - min) * 10`, clamped to 0–10.
    /// - Number metrics: returns `rawValue` unchanged (unbounded, insight engine uses raw).
    static func normalizedScore(for rawValue: Float, definition: SQMetricDefinition) -> Float {
        switch definition.kind {
        case .scale, .binary:
            return normalizedScaleScore(for: rawValue, definition: definition)
        case .number, .unknown:
            return rawValue
        }
    }

    static func normalizedScore(
        scaleValue: Float?,
        quantityValue: Float?,
        rawValue: Float,
        definition: SQMetricDefinition
    ) -> Float {
        if let scaleValue {
            return normalizedScaleScore(for: scaleValue, definition: definition)
        }

        if let quantityValue {
            return normalizedScore(for: quantityValue, definition: definition)
        }

        return normalizedScore(for: rawValue, definition: definition)
    }

    static func loggedValue(
        rawValue: Float,
        enteredMode: SQMetricValueMode,
        definition: SQMetricDefinition
    ) -> SQMetricLoggedValue {
        switch enteredMode {
        case .scale:
            return .init(
                enteredMode: .scale,
                rawValue: rawValue,
                scaleValue: rawValue,
                quantityValue: definition.quantityValue(forScaleValue: rawValue)
            )
        case .quantity:
            let unitSystem = SQUserDefaults.shared.preferredUnitSystem ?? .defaultForCurrentLocale
            let canonicalQuantity = definition.canonicalQuantityValue(
                fromDisplayValue: rawValue,
                unitSystem: unitSystem
            )
            return .init(
                enteredMode: .quantity,
                rawValue: rawValue,
                scaleValue: definition.scaleValue(forQuantityValue: canonicalQuantity),
                quantityValue: canonicalQuantity
            )
        case .unknown:
            return .init(
                enteredMode: definition.defaultEntryMode,
                rawValue: rawValue,
                scaleValue: definition.defaultEntryMode == .scale ? rawValue : nil,
                quantityValue: definition.defaultEntryMode == .quantity ? rawValue : nil
            )
        }
    }

    /// Builds a `SQMetricEntry` from a raw value, metric definition, and current device context.
    /// Uses a stable deterministic ID so that re-submitting always overwrites the correct entry:
    /// - `isSingleDailyValue` metrics: `{anchorDayKey}/{metricId}` — one slot per day regardless of session
    /// - Periodic metrics: `{anchorDayKey}/{metricId}/{period}` — one slot per period per day
    static func make(
        metricId: String,
        rawValue: Float,
        enteredMode: SQMetricValueMode,
        definition: SQMetricDefinition,
        recordedAt: Date = .now
    ) -> SQMetricEntry {
        let tz = TimeZone.current
        let anchorDayKey = recordedAt.anchorDayKey(in: tz)
        let hour = Calendar.current.component(.hour, from: recordedAt)
        let submissionPeriod: SQMetricPeriod = hour < 16 ? .morning : .evening
        let stableId = stableEntryId(
            metricId: metricId,
            anchorDayKey: anchorDayKey,
            period: submissionPeriod,
            isSingleDailyValue: definition.isSingleDailyValue
        )
        let loggedValue = loggedValue(rawValue: rawValue, enteredMode: enteredMode, definition: definition)
        return SQMetricEntry(
            id: stableId,
            metricId: metricId,
            recordedAt: recordedAt,
            anchorDayKey: anchorDayKey,
            timeZoneIdentifier: tz.identifier,
            period: submissionPeriod,
            enteredMode: loggedValue.enteredMode,
            rawValue: rawValue,
            scaleValue: loggedValue.scaleValue,
            quantityValue: loggedValue.quantityValue,
            normalizedScore: normalizedScore(
                scaleValue: loggedValue.scaleValue,
                quantityValue: loggedValue.quantityValue,
                rawValue: rawValue,
                definition: definition
            )
        )
    }

    /// Deterministic entry ID.
    /// - `isSingleDailyValue`: `{anchorDayKey}/{metricId}` — shared across morning/evening sessions
    /// - Periodic: `{anchorDayKey}/{metricId}/{period.rawValue}` — one per session per day
    static func stableEntryId(
        metricId: String,
        anchorDayKey: String,
        period: SQMetricPeriod,
        isSingleDailyValue: Bool
    ) -> String {
        isSingleDailyValue
            ? "\(anchorDayKey)/\(metricId)"
            : "\(anchorDayKey)/\(metricId)/\(period.rawValue)"
    }
}

// MARK: - Daily Bucket

/// A day's worth of metric entries grouped into a single Firestore document.
/// Stored at: `users/{userId}/metric-entries/{anchorDayKey}`
/// One document per calendar day (vs. one per entry) reduces Firestore reads/writes ~14×.
/// Also stores the day's free-form note, eliminating the separate `daily-notes` collection.
struct SQMetricEntryBucket: Identifiable, Codable {
    /// "YYYY-MM-DD" — also the Firestore document ID.
    var anchorDayKey: String
    var entries: [SQMetricEntry]
    /// The user's free-form note for this day. Nil if no note was written.
    var note: String?
    /// Updated whenever any entry or the note in this bucket changes — used for incremental sync queries.
    var updatedAt: Date

    var id: String { anchorDayKey }

    init(anchorDayKey: String, entries: [SQMetricEntry], note: String? = nil, updatedAt: Date = .now) {
        self.anchorDayKey = anchorDayKey
        self.entries = entries
        self.note = note
        self.updatedAt = updatedAt
    }
}

// MARK: - Date Extension

extension Date {
    /// Returns "YYYY-MM-DD" formatted in the given timezone — used as the stable day grouping key.
    func anchorDayKey(in timeZone: TimeZone = .current) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        let year  = components.year  ?? 0
        let month = components.month ?? 0
        let day   = components.day   ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
