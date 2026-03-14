//
//  SQMetricEntry.swift
//  BeastFitness
//

import Foundation
import BeastFitnessCore

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

    /// The value as entered by the user, in their configured scale (e.g. 0–5 if they set a 5-point scale).
    var rawValue: Float
    /// `rawValue` converted to a 0–10 score for the insight engine.
    /// Allows comparing all metrics regardless of their individual scales.
    /// Formula: `(rawValue - min) / (max - min) * 10` for scale metrics; `rawValue` for number metrics.
    var normalizedScore: Float

    // MARK: - Init

    init(
        id: String = UUID().uuidString,
        metricId: String,
        recordedAt: Date = .now,
        anchorDayKey: String,
        timeZoneIdentifier: String,
        period: SQMetricPeriod,
        rawValue: Float,
        normalizedScore: Float
    ) {
        self.id = id
        self.metricId = metricId
        self.recordedAt = recordedAt
        self.anchorDayKey = anchorDayKey
        self.timeZoneIdentifier = timeZoneIdentifier
        self.period = period
        self.rawValue = rawValue
        self.normalizedScore = normalizedScore
    }
}

// MARK: - Normalization Helper

extension SQMetricEntry {

    /// Computes `normalizedScore` from a raw value and metric definition bounds.
    /// - Scale metrics: `(rawValue - min) / (max - min) * 10`, clamped to 0–10.
    /// - Number metrics: returns `rawValue` unchanged (unbounded, insight engine uses raw).
    static func normalizedScore(for rawValue: Float, definition: SQMetricDefinition) -> Float {
        switch definition.kind {
        case .scale, .binary:
            let min = definition.min ?? 0
            let max = definition.max ?? 10
            guard max > min else { return rawValue }
            let normalized = (rawValue - min) / (max - min) * 10
            return Swift.min(10, Swift.max(0, normalized))
        case .number, .unknown:
            return rawValue
        }
    }

    /// Builds a `SQMetricEntry` from a raw value, metric definition, and current device context.
    static func make(
        metricId: String,
        rawValue: Float,
        definition: SQMetricDefinition,
        recordedAt: Date = .now
    ) -> SQMetricEntry {
        let tz = TimeZone.current
        let anchorDayKey = recordedAt.anchorDayKey(in: tz)
        return SQMetricEntry(
            metricId: metricId,
            recordedAt: recordedAt,
            anchorDayKey: anchorDayKey,
            timeZoneIdentifier: tz.identifier,
            period: definition.period,
            rawValue: rawValue,
            normalizedScore: normalizedScore(for: rawValue, definition: definition)
        )
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
