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
        var userId: String
        var anchorDayKey: String
        var date: Date
        var periodRaw: String
        var completedAt: Date

        init(userId: String, date: Date, period: SQMetricPeriod, completedAt: Date = .now) {
            let normalized = Calendar.current.startOfDay(for: date)
            let anchorDayKey = normalized.anchorDayKey()
            self.id = Self.storageId(userId: userId, anchorDayKey: anchorDayKey, period: period)
            self.userId = userId
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

    static func storageId(userId: String, anchorDayKey: String, period: SQMetricPeriod) -> String {
        "\(userId)/\(sessionId(anchorDayKey: anchorDayKey, period: period))"
    }

    static func upsert(
        userId: String,
        date: Date,
        period: SQMetricPeriod,
        completedAt: Date = .now,
        in context: ModelContext
    ) throws {
        let normalized = Calendar.current.startOfDay(for: date)
        let anchorDayKey = normalized.anchorDayKey()
        let id = storageId(userId: userId, anchorDayKey: anchorDayKey, period: period)

        let descriptor = FetchDescriptor<SQDailyCheckInSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.completedAt = completedAt
            existing.date = normalized
            existing.anchorDayKey = anchorDayKey
            existing.periodRaw = period.rawValue
        } else {
            context.insert(SQDailyCheckInSessionEntity(userId: userId, date: normalized, period: period, completedAt: completedAt))
        }

        try context.save()
    }

    static func exists(
        userId: String,
        for date: Date,
        period: SQMetricPeriod,
        context: ModelContext
    ) throws -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        let id = storageId(userId: userId, anchorDayKey: normalized.anchorDayKey(), period: period)
        let descriptor = FetchDescriptor<SQDailyCheckInSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first != nil
    }

    static func replaceCompletedPeriods(
        userId: String,
        anchorDayKey: String,
        date: Date,
        periods: Set<SQMetricPeriod>,
        context: ModelContext
    ) throws {
        try deleteAll(for: anchorDayKey, userId: userId, context: context)

        for period in periods where period != .unknown {
            context.insert(SQDailyCheckInSessionEntity(userId: userId, date: date, period: period))
        }

        try context.save()
    }

    static func deleteAll(for anchorDayKey: String, userId: String, context: ModelContext) throws {
        let descriptor = FetchDescriptor<SQDailyCheckInSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.anchorDayKey == anchorDayKey }
        )
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }

    static func deleteAll(for userId: String, context: ModelContext) throws {
        let descriptor = FetchDescriptor<SQDailyCheckInSessionEntity>(
            predicate: #Predicate { $0.userId == userId }
        )
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}
