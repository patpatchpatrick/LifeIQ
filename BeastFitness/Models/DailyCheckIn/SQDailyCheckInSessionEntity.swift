//
//  SQDailyCheckInSessionEntity.swift
//  BeastFitness
//

import SwiftData
import Foundation

extension SQLocalPersistenceSchemaV1 {
    @Model
    final class SQDailyCheckInSessionEntity {
        /// Local-only completion marker for a specific day + check-in period.
        ///
        /// This remains separate from metric-entry analytics storage:
        /// - shared single-daily metrics can appear in both morning/evening views
        /// - notes-only submissions may not create metric entries
        ///
        /// The dashboard CTA and date picker use this to determine whether a user
        /// explicitly completed the morning or evening session.
        @Attribute(.unique) var id: String
        var anchorDayKey: String
        var date: Date
        var periodRaw: String
        var completedAt: Date

        init(date: Date, period: SQMetricPeriod, completedAt: Date = .now) {
            let normalized = Calendar.current.startOfDay(for: date)
            let anchorDayKey = normalized.anchorDayKey()
            self.id = Self.sessionId(anchorDayKey: anchorDayKey, period: period)
            self.anchorDayKey = anchorDayKey
            self.date = normalized
            self.periodRaw = period.rawValue
            self.completedAt = completedAt
        }
    }
}

typealias SQDailyCheckInSessionEntity = SQCurrentLocalSchema.SQDailyCheckInSessionEntity

extension SQDailyCheckInSessionEntity {
    var period: SQMetricPeriod {
        SQMetricPeriod(unfrozenRawValue: periodRaw)
    }

    static func sessionId(anchorDayKey: String, period: SQMetricPeriod) -> String {
        "\(anchorDayKey)/\(period.rawValue)"
    }

    static func upsert(
        date: Date,
        period: SQMetricPeriod,
        completedAt: Date = .now,
        in context: ModelContext
    ) throws {
        let normalized = Calendar.current.startOfDay(for: date)
        let anchorDayKey = normalized.anchorDayKey()
        let id = sessionId(anchorDayKey: anchorDayKey, period: period)

        let descriptor = FetchDescriptor<SQDailyCheckInSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.completedAt = completedAt
            existing.date = normalized
            existing.anchorDayKey = anchorDayKey
            existing.periodRaw = period.rawValue
        } else {
            context.insert(SQDailyCheckInSessionEntity(date: normalized, period: period, completedAt: completedAt))
        }

        try context.save()
    }

    static func exists(
        for date: Date,
        period: SQMetricPeriod,
        context: ModelContext
    ) throws -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        let id = sessionId(anchorDayKey: normalized.anchorDayKey(), period: period)
        let descriptor = FetchDescriptor<SQDailyCheckInSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first != nil
    }
}
