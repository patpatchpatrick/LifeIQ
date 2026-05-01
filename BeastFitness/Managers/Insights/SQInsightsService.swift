//
//  SQInsightsService.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation
import BeastFitnessCore

private struct SQInsightSurfacingNoveltyRecord: Codable {
    var shownDayKeys: [String]
}

private struct SQInsightFreshnessSurfaceRecord: Codable {
    var lastSeenFamilyKeys: [String]
    var pendingFamilyKey: String?
    var lastPromotedDayKey: String?
    var surfacedDayKeysByFamily: [String: [String]]
}

private struct SQInsightSurfacingMemoryStorage: Codable {
    var noveltyRecordsByScope: [String: [String: SQInsightSurfacingNoveltyRecord]]
    var freshnessRecordsByScope: [String: [String: SQInsightFreshnessSurfaceRecord]]
}

struct SQInsightSurfacingNoveltyState {
    let currentStreak: Int
    let shownCountLast7: Int
    let daysSinceLastShown: Int?

    func penalty(for insight: SQInsight) -> Double {
        var penalty = (Double(currentStreak) * 6) + (Double(max(0, shownCountLast7 - 1)) * 2.5)

        if isHabitDrivenInsight(insight) {
            switch insight.insightClass {
            case .trend:
                penalty *= 1.5
            case .baselineChange, .followUp:
                penalty *= 1.25
            case .relationship, .risk, .opportunity:
                penalty *= 1.1
            case .populationBenchmark, .cohort:
                break
            }

            if insight.effect == .positive {
                penalty *= 1.15
            }
        }

        if insight.insightClass == .risk || insight.insightClass == .opportunity {
            penalty *= 0.6
        }

        if insight.confidence == .high {
            penalty *= 0.75
        }

        return penalty
    }

    private func isHabitDrivenInsight(_ insight: SQInsight) -> Bool {
        let habitSignalIds: Set<String> = [
            SQMetricId.alcohol,
            SQMetricId.caffeine,
            SQMetricId.weed,
            SQMetricId.nicotine,
            SQMetricId.porn
        ]

        return habitSignalIds.contains(insight.inputSignalId ?? "")
        || habitSignalIds.contains(insight.outputSignalId ?? "")
    }
}

protocol SQInsightSurfacingMemoryStoring {
    func noveltyState(
        for familyKey: String,
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightSurfacingNoveltyState

    func newInsightFamilyKey(
        from surfacedInsights: [SQInsight],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> String?

    func markInsightsSeen(
        _ insights: [SQInsight],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    )

    func hasUnseenNewInsights(
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Bool

    func recordShownFamilyKeys(
        _ familyKeys: [String],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    )
}

final class SQNoOpInsightSurfacingMemoryStore: SQInsightSurfacingMemoryStoring {
    func noveltyState(
        for familyKey: String,
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightSurfacingNoveltyState {
        .init(currentStreak: 0, shownCountLast7: 0, daysSinceLastShown: nil)
    }

    func newInsightFamilyKey(
        from surfacedInsights: [SQInsight],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> String? {
        nil
    }

    func markInsightsSeen(
        _ insights: [SQInsight],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) {}

    func hasUnseenNewInsights(
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Bool {
        false
    }

    func recordShownFamilyKeys(
        _ familyKeys: [String],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) {}
}

final class SQInMemoryInsightSurfacingMemoryStore: SQInsightSurfacingMemoryStoring {
    private var storage: SQInsightSurfacingMemoryStorage
    private let calendar: Calendar

    init(
        calendar: Calendar = .current
    ) {
        self.storage = .init(
            noveltyRecordsByScope: [:],
            freshnessRecordsByScope: [:]
        )
        self.calendar = calendar
    }

    func noveltyState(
        for familyKey: String,
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightSurfacingNoveltyState {
        guard surfaceIntent == .today else {
            return .init(currentStreak: 0, shownCountLast7: 0, daysSinceLastShown: nil)
        }

        let record = storage.noveltyRecordsByScope[scopeKey]?[familyKey]
        let shownDayKeys = Set(record?.shownDayKeys ?? [])
        let referenceDay = calendar.startOfDay(for: referenceDate)

        var streak = 0
        var cursor = calendar.date(byAdding: .day, value: -1, to: referenceDay)
        while let currentCursor = cursor, shownDayKeys.contains(dayKey(for: currentCursor)) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: currentCursor)
        }

        let shownCountLast7 = (1...7).reduce(into: 0) { partialResult, offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else { return }
            if shownDayKeys.contains(dayKey(for: date)) {
                partialResult += 1
            }
        }

        let daysSinceLastShown = (1...30).first(where: { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else { return false }
            return shownDayKeys.contains(dayKey(for: date))
        })

        return .init(
            currentStreak: streak,
            shownCountLast7: shownCountLast7,
            daysSinceLastShown: daysSinceLastShown
        )
    }

    func newInsightFamilyKey(
        from surfacedInsights: [SQInsight],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> String? {
        guard supportsFreshness(for: surfaceIntent) else { return nil }

        let todayKey = dayKey(for: referenceDate)
        let visibleInsights = surfacedInsights.filter { $0.confidence != .low }
        let visibleFamilyKeys = visibleInsights.map(\.familyKey)

        var freshnessRecords = storage.freshnessRecordsByScope[scopeKey] ?? [:]
        var surfaceRecord = freshnessRecords[freshnessKey(for: surfaceIntent)] ?? .init(
            lastSeenFamilyKeys: [],
            pendingFamilyKey: nil,
            lastPromotedDayKey: nil,
            surfacedDayKeysByFamily: [:]
        )

        let minimumDayKey = dayKey(
            for: calendar.date(
                byAdding: .day,
                value: -historyRetentionDays(for: surfaceIntent),
                to: calendar.startOfDay(for: referenceDate)
            ) ?? referenceDate
        )

        for familyKey in Set(visibleFamilyKeys) {
            var dayKeys = surfaceRecord.surfacedDayKeysByFamily[familyKey] ?? []
            if !dayKeys.contains(todayKey) {
                dayKeys.append(todayKey)
            }
            surfaceRecord.surfacedDayKeysByFamily[familyKey] = Array(
                Set(dayKeys.filter { $0 >= minimumDayKey })
            ).sorted()
        }

        surfaceRecord.surfacedDayKeysByFamily = surfaceRecord.surfacedDayKeysByFamily
            .filter { !$0.value.isEmpty }

        var activeNewFamilyKey: String?

        if let pendingFamilyKey = surfaceRecord.pendingFamilyKey {
            if visibleFamilyKeys.contains(pendingFamilyKey) {
                activeNewFamilyKey = pendingFamilyKey
            } else {
                surfaceRecord.pendingFamilyKey = nil
            }
        }

        if activeNewFamilyKey == nil,
           cooldownSatisfied(
                lastPromotedDayKey: surfaceRecord.lastPromotedDayKey,
                referenceDate: referenceDate,
                minimumDayGap: minimumDaysBetweenNewInsights(for: surfaceIntent)
           ) {
            let seenFamilyKeys = Set(surfaceRecord.lastSeenFamilyKeys)

            if let candidate = visibleInsights.first(where: { insight in
                !seenFamilyKeys.contains(insight.familyKey)
                && stableSurfacingDayCount(
                    for: insight.familyKey,
                    in: surfaceRecord
                ) >= minimumStableDayCount(for: surfaceIntent)
            }) {
                surfaceRecord.pendingFamilyKey = candidate.familyKey
                surfaceRecord.lastPromotedDayKey = todayKey
                activeNewFamilyKey = candidate.familyKey
            }
        }

        freshnessRecords[freshnessKey(for: surfaceIntent)] = surfaceRecord
        storage.freshnessRecordsByScope[scopeKey] = freshnessRecords

        return activeNewFamilyKey
    }

    func markInsightsSeen(
        _ insights: [SQInsight],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) {
        guard supportsFreshness(for: surfaceIntent) else { return }
        guard !insights.isEmpty else { return }

        var freshnessRecords = storage.freshnessRecordsByScope[scopeKey] ?? [:]
        var surfaceRecord = freshnessRecords[freshnessKey(for: surfaceIntent)] ?? .init(
            lastSeenFamilyKeys: [],
            pendingFamilyKey: nil,
            lastPromotedDayKey: nil,
            surfacedDayKeysByFamily: [:]
        )

        let visibleFamilyKeys = Array(Set(insights.map(\.familyKey))).sorted()
        surfaceRecord.lastSeenFamilyKeys = visibleFamilyKeys

        if let pendingFamilyKey = surfaceRecord.pendingFamilyKey,
           visibleFamilyKeys.contains(pendingFamilyKey) {
            surfaceRecord.pendingFamilyKey = nil
        }

        freshnessRecords[freshnessKey(for: surfaceIntent)] = surfaceRecord
        storage.freshnessRecordsByScope[scopeKey] = freshnessRecords
    }

    func hasUnseenNewInsights(
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Bool {
        guard supportsFreshness(for: surfaceIntent) else { return false }

        return storage
            .freshnessRecordsByScope[scopeKey]?[freshnessKey(for: surfaceIntent)]?
            .pendingFamilyKey != nil
    }

    func recordShownFamilyKeys(
        _ familyKeys: [String],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) {
        guard surfaceIntent == .today else { return }
        guard !familyKeys.isEmpty else { return }

        let todayKey = dayKey(for: referenceDate)
        let minimumDay = calendar.date(byAdding: .day, value: -21, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        let minimumDayKey = dayKey(for: minimumDay)

        var noveltyRecords = storage.noveltyRecordsByScope[scopeKey] ?? [:]

        for familyKey in Set(familyKeys) {
            var record = noveltyRecords[familyKey] ?? .init(shownDayKeys: [])

            if !record.shownDayKeys.contains(todayKey) {
                record.shownDayKeys.append(todayKey)
            }

            record.shownDayKeys = Array(
                Set(record.shownDayKeys.filter { $0 >= minimumDayKey })
            )
            .sorted()
            noveltyRecords[familyKey] = record
        }

        storage.noveltyRecordsByScope[scopeKey] = noveltyRecords
    }

    private func supportsFreshness(for surfaceIntent: SQInsightSurfaceIntent) -> Bool {
        switch surfaceIntent {
        case .today:
            return false
        case .pastWeek, .pastYear:
            return true
        }
    }

    private func minimumDaysBetweenNewInsights(for surfaceIntent: SQInsightSurfaceIntent) -> Int {
        switch surfaceIntent {
        case .today:
            return 0
        case .pastWeek:
            return 2
        case .pastYear:
            return 10
        }
    }

    private func minimumStableDayCount(for surfaceIntent: SQInsightSurfaceIntent) -> Int {
        switch surfaceIntent {
        case .today:
            return 1
        case .pastWeek, .pastYear:
            return 2
        }
    }

    private func historyRetentionDays(for surfaceIntent: SQInsightSurfaceIntent) -> Int {
        switch surfaceIntent {
        case .today:
            return 30
        case .pastWeek:
            return 45
        case .pastYear:
            return 400
        }
    }

    private func stableSurfacingDayCount(
        for familyKey: String,
        in surfaceRecord: SQInsightFreshnessSurfaceRecord
    ) -> Int {
        Set(surfaceRecord.surfacedDayKeysByFamily[familyKey] ?? []).count
    }

    private func cooldownSatisfied(
        lastPromotedDayKey: String?,
        referenceDate: Date,
        minimumDayGap: Int
    ) -> Bool {
        guard minimumDayGap > 0 else { return true }
        guard let lastPromotedDayKey,
              let lastPromotedDate = date(fromDayKey: lastPromotedDayKey) else {
            return true
        }

        let referenceDay = calendar.startOfDay(for: referenceDate)
        let components = calendar.dateComponents([.day], from: lastPromotedDate, to: referenceDay)
        let elapsedDays = components.day ?? minimumDayGap
        return elapsedDays >= minimumDayGap
    }

    private func freshnessKey(for surfaceIntent: SQInsightSurfaceIntent) -> String {
        switch surfaceIntent {
        case .today:
            return "today"
        case .pastWeek:
            return "pastWeek"
        case .pastYear:
            return "pastYear"
        }
    }

    private func date(fromDayKey dayKey: String) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        return calendar.date(from: DateComponents(
            year: parts[0],
            month: parts[1],
            day: parts[2]
        ))
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

final class SQPersistedInsightSurfacingMemoryStore: SQInsightSurfacingMemoryStoring {
    private static let storageKey = "insights.surfacing-memory.v2"

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func noveltyState(
        for familyKey: String,
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightSurfacingNoveltyState {
        guard surfaceIntent == .today else {
            return .init(currentStreak: 0, shownCountLast7: 0, daysSinceLastShown: nil)
        }

        let record = storage().noveltyRecordsByScope[scopeKey]?[familyKey]
        let shownDayKeys = Set(record?.shownDayKeys ?? [])
        let referenceDay = calendar.startOfDay(for: referenceDate)

        var streak = 0
        var cursor = calendar.date(byAdding: .day, value: -1, to: referenceDay)
        while let currentCursor = cursor, shownDayKeys.contains(dayKey(for: currentCursor)) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: currentCursor)
        }

        let shownCountLast7 = (1...7).reduce(into: 0) { partialResult, offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else { return }
            if shownDayKeys.contains(dayKey(for: date)) {
                partialResult += 1
            }
        }

        let daysSinceLastShown = (1...30).first(where: { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else { return false }
            return shownDayKeys.contains(dayKey(for: date))
        })

        return .init(
            currentStreak: streak,
            shownCountLast7: shownCountLast7,
            daysSinceLastShown: daysSinceLastShown
        )
    }

    func newInsightFamilyKey(
        from surfacedInsights: [SQInsight],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> String? {
        guard supportsFreshness(for: surfaceIntent) else { return nil }

        let todayKey = dayKey(for: referenceDate)
        let visibleInsights = surfacedInsights.filter { $0.confidence != .low }
        let visibleFamilyKeys = visibleInsights.map(\.familyKey)

        var storage = storage()
        var freshnessRecords = storage.freshnessRecordsByScope[scopeKey] ?? [:]
        var surfaceRecord = freshnessRecords[freshnessKey(for: surfaceIntent)] ?? .init(
            lastSeenFamilyKeys: [],
            pendingFamilyKey: nil,
            lastPromotedDayKey: nil,
            surfacedDayKeysByFamily: [:]
        )

        let minimumDayKey = dayKey(
            for: calendar.date(
                byAdding: .day,
                value: -historyRetentionDays(for: surfaceIntent),
                to: calendar.startOfDay(for: referenceDate)
            ) ?? referenceDate
        )

        for familyKey in Set(visibleFamilyKeys) {
            var dayKeys = surfaceRecord.surfacedDayKeysByFamily[familyKey] ?? []
            if !dayKeys.contains(todayKey) {
                dayKeys.append(todayKey)
            }
            surfaceRecord.surfacedDayKeysByFamily[familyKey] = Array(
                Set(dayKeys.filter { $0 >= minimumDayKey })
            ).sorted()
        }

        surfaceRecord.surfacedDayKeysByFamily = surfaceRecord.surfacedDayKeysByFamily
            .filter { !$0.value.isEmpty }

        var activeNewFamilyKey: String?

        if let pendingFamilyKey = surfaceRecord.pendingFamilyKey {
            if visibleFamilyKeys.contains(pendingFamilyKey) {
                activeNewFamilyKey = pendingFamilyKey
            } else {
                surfaceRecord.pendingFamilyKey = nil
            }
        }

        if activeNewFamilyKey == nil,
           cooldownSatisfied(
                lastPromotedDayKey: surfaceRecord.lastPromotedDayKey,
                referenceDate: referenceDate,
                minimumDayGap: minimumDaysBetweenNewInsights(for: surfaceIntent)
           ) {
            let seenFamilyKeys = Set(surfaceRecord.lastSeenFamilyKeys)

            if let candidate = visibleInsights.first(where: { insight in
                !seenFamilyKeys.contains(insight.familyKey)
                && stableSurfacingDayCount(
                    for: insight.familyKey,
                    in: surfaceRecord
                ) >= minimumStableDayCount(for: surfaceIntent)
            }) {
                surfaceRecord.pendingFamilyKey = candidate.familyKey
                surfaceRecord.lastPromotedDayKey = todayKey
                activeNewFamilyKey = candidate.familyKey
            }
        }

        freshnessRecords[freshnessKey(for: surfaceIntent)] = surfaceRecord
        storage.freshnessRecordsByScope[scopeKey] = freshnessRecords
        save(storage)

        return activeNewFamilyKey
    }

    func markInsightsSeen(
        _ insights: [SQInsight],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) {
        guard supportsFreshness(for: surfaceIntent) else { return }
        guard !insights.isEmpty else { return }

        var storage = storage()
        var freshnessRecords = storage.freshnessRecordsByScope[scopeKey] ?? [:]
        var surfaceRecord = freshnessRecords[freshnessKey(for: surfaceIntent)] ?? .init(
            lastSeenFamilyKeys: [],
            pendingFamilyKey: nil,
            lastPromotedDayKey: nil,
            surfacedDayKeysByFamily: [:]
        )

        let visibleFamilyKeys = Array(Set(insights.map(\.familyKey))).sorted()
        surfaceRecord.lastSeenFamilyKeys = visibleFamilyKeys

        if let pendingFamilyKey = surfaceRecord.pendingFamilyKey,
           visibleFamilyKeys.contains(pendingFamilyKey) {
            surfaceRecord.pendingFamilyKey = nil
        }

        freshnessRecords[freshnessKey(for: surfaceIntent)] = surfaceRecord
        storage.freshnessRecordsByScope[scopeKey] = freshnessRecords
        save(storage)
    }

    func hasUnseenNewInsights(
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Bool {
        guard supportsFreshness(for: surfaceIntent) else { return false }

        return storage()
            .freshnessRecordsByScope[scopeKey]?[freshnessKey(for: surfaceIntent)]?
            .pendingFamilyKey != nil
    }

    func recordShownFamilyKeys(
        _ familyKeys: [String],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) {
        guard surfaceIntent == .today else { return }
        guard !familyKeys.isEmpty else { return }

        let todayKey = dayKey(for: referenceDate)
        let minimumDay = calendar.date(byAdding: .day, value: -21, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        let minimumDayKey = dayKey(for: minimumDay)

        var storage = storage()
        var noveltyRecords = storage.noveltyRecordsByScope[scopeKey] ?? [:]

        for familyKey in Set(familyKeys) {
            var record = noveltyRecords[familyKey] ?? .init(shownDayKeys: [])

            if !record.shownDayKeys.contains(todayKey) {
                record.shownDayKeys.append(todayKey)
            }

            record.shownDayKeys = Array(
                Set(record.shownDayKeys.filter { $0 >= minimumDayKey })
            )
            .sorted()
            noveltyRecords[familyKey] = record
        }

        storage.noveltyRecordsByScope[scopeKey] = noveltyRecords
        save(storage)
    }

    private func storage() -> SQInsightSurfacingMemoryStorage {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .init(noveltyRecordsByScope: [:], freshnessRecordsByScope: [:])
        }

        return (try? JSONDecoder().decode(SQInsightSurfacingMemoryStorage.self, from: data))
        ?? .init(noveltyRecordsByScope: [:], freshnessRecordsByScope: [:])
    }

    private func save(_ storage: SQInsightSurfacingMemoryStorage) {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func supportsFreshness(for surfaceIntent: SQInsightSurfaceIntent) -> Bool {
        switch surfaceIntent {
        case .today:
            return false
        case .pastWeek, .pastYear:
            return true
        }
    }

    private func minimumDaysBetweenNewInsights(for surfaceIntent: SQInsightSurfaceIntent) -> Int {
        switch surfaceIntent {
        case .today:
            return 0
        case .pastWeek:
            return 2
        case .pastYear:
            return 10
        }
    }

    private func minimumStableDayCount(for surfaceIntent: SQInsightSurfaceIntent) -> Int {
        switch surfaceIntent {
        case .today:
            return 1
        case .pastWeek, .pastYear:
            return 2
        }
    }

    private func historyRetentionDays(for surfaceIntent: SQInsightSurfaceIntent) -> Int {
        switch surfaceIntent {
        case .today:
            return 30
        case .pastWeek:
            return 45
        case .pastYear:
            return 400
        }
    }

    private func stableSurfacingDayCount(
        for familyKey: String,
        in surfaceRecord: SQInsightFreshnessSurfaceRecord
    ) -> Int {
        Set(surfaceRecord.surfacedDayKeysByFamily[familyKey] ?? []).count
    }

    private func cooldownSatisfied(
        lastPromotedDayKey: String?,
        referenceDate: Date,
        minimumDayGap: Int
    ) -> Bool {
        guard minimumDayGap > 0 else { return true }
        guard let lastPromotedDayKey,
              let lastPromotedDate = date(fromDayKey: lastPromotedDayKey) else {
            return true
        }

        let referenceDay = calendar.startOfDay(for: referenceDate)
        let components = calendar.dateComponents([.day], from: lastPromotedDate, to: referenceDay)
        let elapsedDays = components.day ?? minimumDayGap
        return elapsedDays >= minimumDayGap
    }

    private func freshnessKey(for surfaceIntent: SQInsightSurfaceIntent) -> String {
        switch surfaceIntent {
        case .today:
            return "today"
        case .pastWeek:
            return "pastWeek"
        case .pastYear:
            return "pastYear"
        }
    }

    private func date(fromDayKey dayKey: String) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        return calendar.date(from: DateComponents(
            year: parts[0],
            month: parts[1],
            day: parts[2]
        ))
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

@MainActor
protocol SQInsightsServicing {
    func dashboardInsights(input: SQHealthIntelligenceInput) -> SQInsightsResult
    func markVisibleInsightsSeenIfNeeded(
        _ insights: [SQInsight],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    )
    func hasUnseenNewInsights(surfaceIntent: SQInsightSurfaceIntent) -> Bool
}

@MainActor
final class SQInsightsService: SQInsightsServicing {
    private let featureBuilder: SQInsightFeatureBuilding
    private let driverBuilder: SQInsightDriverBuilding
    private let changeBuilder: SQInsightChangeBuilding
    private let actionBuilder: SQInsightActionBuilding
    private let analysisEngine: SQInsightAnalyzing
    private let relationshipRegistry: SQInsightRelationshipRegistry
    private let surfacingMemoryStore: SQInsightSurfacingMemoryStoring
    private let dynamicMetricInsightBuilder = SQDynamicMetricInsightBuilder()
    private let customRelationshipInsightBuilder = SQCustomRelationshipInsightBuilder()
    private let minimumAnalyzedDayCount = 10
    private let relevantMetricIds: Set<String>

    init(
        featureBuilder: SQInsightFeatureBuilding = SQInsightFeatureBuilder(),
        driverBuilder: SQInsightDriverBuilding = SQInsightDriverBuilder(),
        changeBuilder: SQInsightChangeBuilding = SQInsightChangeBuilder(),
        actionBuilder: SQInsightActionBuilding = SQInsightActionBuilder(),
        analysisEngine: SQInsightAnalyzing = SQInsightAnalysisEngine(),
        relationshipRegistry: SQInsightRelationshipRegistry = .init(),
        surfacingMemoryStore: SQInsightSurfacingMemoryStoring = SQPersistedInsightSurfacingMemoryStore()
    ) {
        self.featureBuilder = featureBuilder
        self.driverBuilder = driverBuilder
        self.changeBuilder = changeBuilder
        self.actionBuilder = actionBuilder
        self.analysisEngine = analysisEngine
        self.relationshipRegistry = relationshipRegistry
        self.surfacingMemoryStore = surfacingMemoryStore
        self.relevantMetricIds = relationshipRegistry.relevantSignalIds
    }

    func dashboardInsights(input: SQHealthIntelligenceInput) -> SQInsightsResult {
        let snapshots = featureBuilder.makeFeatureSnapshots(
            checkIns: input.checkIns,
            workouts: input.workouts,
            metricDefinitions: input.metricDefinitions,
            sleepData: input.sleepData,
            restingHeartRateSummaries: input.restingHeartRateSummaries
        )
        let customMetricIds = Set(input.metricDefinitions.filter { !$0.isPreset }.map(\.id))
        let surfaceIntent = input.timeRange.insightSurfaceIntent

        let analyzedDayCount = snapshots.filter { snapshot in
            !snapshot.rawSignalValues.isEmpty || snapshot.hasWorkout
        }.count

        let relevantDayCount = snapshots.filter { snapshot in
            snapshot.hasWorkout ||
            relevantMetricIds.contains(where: { snapshot.rawSignalValue(for: $0) != nil })
        }.count

        let analysisOutput = analysisEngine.analyze(
            snapshots: snapshots,
            relationships: relationshipRegistry.activeRelationships,
            surfaceIntent: surfaceIntent,
            referenceDate: input.referenceDate
        )
        let drivers = curatedDrivers(
            from: driverBuilder.buildDrivers(
                from: snapshots,
                surfaceIntent: surfaceIntent,
                referenceDate: input.referenceDate
            ),
            surfaceIntent: surfaceIntent
        )
        let changes = todayRelevantChanges(
            from: changeBuilder.buildChanges(
                from: snapshots,
                surfaceIntent: surfaceIntent
            ),
            snapshots: snapshots,
            referenceDate: input.referenceDate,
            surfaceIntent: surfaceIntent,
            selectedDrivers: drivers
        )
        let dynamicMetricInsights = dynamicMetricInsightBuilder.buildInsights(
            from: snapshots,
            metricDefinitions: input.metricDefinitions,
            surfaceIntent: surfaceIntent,
            referenceDate: input.referenceDate
        )
        let customRelationshipInsights = SQAdminConfig.enableCustomRelationshipInsights
            ? customRelationshipInsightBuilder.buildInsights(
                from: snapshots,
                metricDefinitions: input.metricDefinitions,
                surfaceIntent: surfaceIntent,
                referenceDate: input.referenceDate
            )
            : []
        let generatedInsights = todayRelevantInsights(
            from: analysisOutput.generatedInsights + dynamicMetricInsights + customRelationshipInsights,
            snapshots: snapshots,
            referenceDate: input.referenceDate,
            surfaceIntent: surfaceIntent
        )
        let deduplicatedInsights = deduplicatedInsights(from: generatedInsights)
        let noveltyAdjustedInsights = noveltyAdjustedInsights(
            from: deduplicatedInsights,
            referenceDate: input.referenceDate,
            surfaceIntent: surfaceIntent
        )
        let relationshipAdjustedInsights = relationshipFamilyAdjustedInsights(
            from: noveltyAdjustedInsights,
            snapshots: snapshots,
            referenceDate: input.referenceDate,
            surfaceIntent: surfaceIntent,
            drivers: drivers,
            changes: changes
        )
        let currentPressureContext = pressureContext(
            snapshots: snapshots,
            referenceDate: input.referenceDate
        )
        let contextAdjustedInsights = contextAdjustedCurrentStateInsights(
            from: relationshipAdjustedInsights,
            pressureContext: currentPressureContext,
            drivers: drivers,
            changes: changes,
            surfaceIntent: surfaceIntent
        )
        let curatedInsights = curatedInsights(
            from: contextAdjustedInsights,
            referenceDate: input.referenceDate,
            surfaceIntent: surfaceIntent,
            drivers: drivers,
            changes: changes,
            pressureContext: currentPressureContext,
            customMetricIds: customMetricIds
        )
        let insights = freshnessAdjustedInsights(
            from: curatedInsights,
            referenceDate: input.referenceDate,
            surfaceIntent: surfaceIntent
        )
        let actions = curatedActions(
            from: actionBuilder.buildActions(
                insights: insights,
                drivers: drivers,
                changes: changes,
                surfaceIntent: surfaceIntent
            ),
            surfaceIntent: surfaceIntent
        )
        let readinessItems = analysisOutput.readinessItems

        if SQAdminConfig.verboseLoggingEnabled {
            for readiness in readinessItems {
                SQLogger.shared.log(
                    "Insight readiness [\(readiness.title)]: \(readiness.summary)",
                    .debug,
                    context: .dashboard
                )
            }

            for insight in generatedInsights.sorted(by: { sortInsightsForDisplay($0, $1) }) {
                SQLogger.shared.log(
                    "Generated candidate insight [\(insight.title)] family=\(insight.familyKey) priority=\(insight.variantPriority) sample=\(insight.sampleCount) delta=\(insight.deltaText) confidence=\(insight.confidence.badgeTitle)",
                    .debug,
                    context: .dashboard
                )
            }

            for insight in insights {
                SQLogger.shared.log(
                    "Surfaced insight [\(insight.title)] family=\(insight.familyKey) priority=\(insight.variantPriority) sample=\(insight.sampleCount) delta=\(insight.deltaText) confidence=\(insight.confidence.badgeTitle)",
                    .debug,
                    context: .dashboard
                )
            }

            for driver in drivers {
                SQLogger.shared.log(
                    "Surfaced driver [\(driver.title)] direction=\(driver.direction == .supportive ? "supportive" : "drag") delta=\(driver.deltaText) rank=\(String(format: "%.1f", driver.rankingScore))",
                    .debug,
                    context: .dashboard
                )
            }

            for change in changes {
                SQLogger.shared.log(
                    "Surfaced change [\(change.title)] direction=\(change.direction == .improved ? "improved" : "worsened") delta=\(change.deltaText) rank=\(String(format: "%.1f", change.rankingScore))",
                    .debug,
                    context: .dashboard
                )
            }

            for action in actions {
                SQLogger.shared.log(
                    "Surfaced action [\(action.title)] summary=\(action.summary)",
                    .debug,
                    context: .dashboard
                )
            }
        }

        let effectiveAnalyzedDayCount = max(analyzedDayCount, relevantDayCount)
        let state: SQInsightDataState
        if effectiveAnalyzedDayCount < minimumAnalyzedDayCount {
            state = .notEnoughData
        } else {
            state = insights.isEmpty ? .noPatterns : .ready
        }

        if state == .ready {
            recordSurfacedTodayItemsIfNeeded(
                insights: insights,
                changes: changes,
                referenceDate: input.referenceDate,
                surfaceIntent: surfaceIntent
            )
        }

        if SQAdminConfig.verboseLoggingEnabled {
            SQLogger.shared.log(
                "Insights dashboard result: state=\(debugTitle(for: state)), analyzedDays=\(effectiveAnalyzedDayCount), insights=\(insights.count), readiness=\(readinessItems.count)",
                .debug,
                context: .dashboard
            )
        }

        return .init(
            state: state,
            insights: insights,
            drivers: drivers,
            changes: changes,
            actions: actions,
            readinessItems: readinessItems,
            analyzedDayCount: effectiveAnalyzedDayCount,
            requiredMinimumDayCount: minimumAnalyzedDayCount
        )
    }

    func markVisibleInsightsSeenIfNeeded(
        _ insights: [SQInsight],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) {
        guard !SQAdminConfig.forceInsightFreshnessBadges else { return }
        guard surfaceIntent != .today else { return }
        guard !insights.isEmpty else { return }

        surfacingMemoryStore.markInsightsSeen(
            insights,
            referenceDate: referenceDate,
            scopeKey: noveltyScopeKey,
            surfaceIntent: surfaceIntent
        )
    }

    func hasUnseenNewInsights(surfaceIntent: SQInsightSurfaceIntent) -> Bool {
        if SQAdminConfig.forceInsightFreshnessBadges {
            return surfaceIntent != .today
        }

        return surfacingMemoryStore.hasUnseenNewInsights(
            scopeKey: noveltyScopeKey,
            surfaceIntent: surfaceIntent
        )
    }

    private func debugTitle(for state: SQInsightDataState) -> String {
        switch state {
        case .ready:
            return "ready"
        case .notEnoughData:
            return "notEnoughData"
        case .noPatterns:
            return "noPatterns"
        }
    }

    private func todayRelevantInsights(
        from insights: [SQInsight],
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsight] {
        guard surfaceIntent == .today else { return insights }

        return insights.filter { insight in
            guard let signalId = insight.inputSignalId,
                  isHabitSignalId(signalId),
                  isHabitCurrentRelevanceRequired(for: insight) else {
                return true
            }

            return hasFreshNonZeroSignal(
                signalId,
                snapshots: snapshots,
                referenceDate: referenceDate
            )
        }
    }

    private func todayRelevantChanges(
        from changes: [SQInsightChange],
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent,
        selectedDrivers: [SQInsightDriver]
    ) -> [SQInsightChange] {
        let rankedChanges = diversityAdjustedChanges(
            from: changes,
            referenceDate: referenceDate,
            surfaceIntent: surfaceIntent,
            selectedDrivers: selectedDrivers
        )
        let curated = curatedChanges(
            from: rankedChanges,
            surfaceIntent: surfaceIntent,
            selectedDrivers: selectedDrivers
        )

        guard surfaceIntent == .today else { return curated }

        return curated.filter { change in
            guard isHabitSignalId(change.signalId) else { return true }

            return hasFreshNonZeroSignal(
                change.signalId,
                snapshots: snapshots,
                referenceDate: referenceDate
            )
        }
    }

    private func diversityAdjustedChanges(
        from changes: [SQInsightChange],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent,
        selectedDrivers: [SQInsightDriver]
    ) -> [SQInsightChange] {
        guard surfaceIntent == .today else { return changes }

        return changes
            .map { change in
                let noveltyState = surfacingMemoryStore.noveltyState(
                    for: changeNoveltyKey(for: change.signalId),
                    referenceDate: referenceDate,
                    scopeKey: noveltyScopeKey,
                    surfaceIntent: surfaceIntent
                )
                let penalty = changeDiversityPenalty(
                    for: change,
                    noveltyState: noveltyState
                )
                let boost = changeRelevanceBoost(
                    for: change,
                    selectedDrivers: selectedDrivers
                )
                return change.withRankingScore(change.rankingScore - penalty + boost)
            }
            .sorted {
                if $0.rankingScore != $1.rankingScore {
                    return $0.rankingScore > $1.rankingScore
                }

                return $0.effectMagnitude > $1.effectMagnitude
            }
    }

    private func changeDiversityPenalty(
        for change: SQInsightChange,
        noveltyState: SQInsightSurfacingNoveltyState
    ) -> Double {
        var penalty = (Double(noveltyState.currentStreak) * 7)
            + (Double(max(0, noveltyState.shownCountLast7 - 1)) * 3)

        if isHighFrequencyBehaviorSignalId(change.signalId) {
            penalty *= 1.7

            if let daysSinceLastShown = noveltyState.daysSinceLastShown,
               daysSinceLastShown < 2 {
                penalty += 10
            }

            if change.effectMagnitude < 1.1 {
                penalty += 4
            }
        }

        if change.signalId == SQMetricId.caffeine {
            penalty += 5

            if noveltyState.shownCountLast7 >= 2 {
                penalty += 6
            }

            if change.effectMagnitude < 1.3 {
                penalty += 8
            }
        }

        return penalty
    }

    private func changeRelevanceBoost(
        for change: SQInsightChange,
        selectedDrivers: [SQInsightDriver]
    ) -> Double {
        let driverSignalIds = Set(selectedDrivers.map(\.signalId))

        if driverSignalIds.contains(change.signalId) {
            return 8
        }

        if isTrainingSignalId(change.signalId),
           selectedDrivers.contains(where: { isTrainingSignalId($0.signalId) || $0.signalId == SQMetricId.soreness }) {
            return 7
        }

        if isSleepSignalId(change.signalId),
           selectedDrivers.contains(where: { isSleepSignalId($0.signalId) || $0.signalId == SQInsightAnalysisMetricId.restingHeartRate }) {
            return 6
        }

        if change.signalId == SQMetricId.alcohol,
           selectedDrivers.contains(where: { isSleepSignalId($0.signalId) || $0.signalId == SQInsightAnalysisMetricId.restingHeartRate }) {
            return 5
        }

        if [SQMetricId.stress, SQMetricId.anxiety, SQMetricId.soreness].contains(change.signalId),
           selectedDrivers.contains(where: { $0.direction == .drag }) {
            return 4
        }

        return 0
    }

    private func isHabitCurrentRelevanceRequired(for insight: SQInsight) -> Bool {
        switch insight.insightClass {
        case .relationship, .trend, .baselineChange, .followUp:
            return true
        case .risk, .opportunity, .populationBenchmark, .cohort:
            return false
        }
    }

    private func hasFreshNonZeroSignal(
        _ signalId: String,
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date
    ) -> Bool {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let latestObservation = snapshots
            .compactMap { snapshot -> (date: Date, value: Double)? in
                guard let value = snapshot.rawSignalValue(for: signalId) else { return nil }
                return (date: snapshot.date, value: value)
            }
            .max { lhs, rhs in lhs.date < rhs.date }

        guard let latestObservation else { return false }

        let latestDay = calendar.startOfDay(for: latestObservation.date)
        let daysSinceLatest = calendar.dateComponents([.day], from: latestDay, to: referenceDay).day ?? 0
        return daysSinceLatest <= 1 && latestObservation.value > 0
    }

    private func deduplicatedInsights(from generatedInsights: [SQInsight]) -> [SQInsight] {
        let grouped = Dictionary(grouping: generatedInsights, by: \.familyKey)
        for (familyKey, familyInsights) in grouped where familyInsights.count > 1 {
            let selected = familyInsights.sorted(by: { sortInsightsForSelection($0, $1) }).first
            let selectedId = selected?.id ?? "none"
            let rejectedIds = familyInsights
                .filter { $0.id != selectedId }
                .map(\.id)
                .sorted()
                .joined(separator: ", ")

            SQLogger.shared.log(
                "Insight family selection [\(familyKey)]: selected=\(selectedId) rejected=\(rejectedIds)",
                .debug,
                context: .dashboard
            )
        }

        return grouped.values
            .compactMap { familyInsights in
                familyInsights.sorted(by: { sortInsightsForSelection($0, $1) }).first
            }
            .sorted(by: { sortInsightsForDisplay($0, $1) })
    }

    private func sortInsightsForSelection(_ lhs: SQInsight, _ rhs: SQInsight) -> Bool {
        if lhs.variantPriority != rhs.variantPriority {
            return lhs.variantPriority < rhs.variantPriority
        }

        if lhs.rankingScore != rhs.rankingScore {
            return lhs.rankingScore > rhs.rankingScore
        }

        return lhs.sampleCount > rhs.sampleCount
    }

    private func sortInsightsForDisplay(_ lhs: SQInsight, _ rhs: SQInsight) -> Bool {
        if lhs.rankingScore != rhs.rankingScore {
            return lhs.rankingScore > rhs.rankingScore
        }

        if lhs.variantPriority != rhs.variantPriority {
            return lhs.variantPriority < rhs.variantPriority
        }

        return lhs.sampleCount > rhs.sampleCount
    }

    private func curatedInsights(
        from deduplicatedInsights: [SQInsight],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        pressureContext: CurrentPressureContext,
        customMetricIds: Set<String>
    ) -> [SQInsight] {
        switch surfaceIntent {
        case .today:
            return curatedTodayInsights(
                from: deduplicatedInsights,
                referenceDate: referenceDate,
                drivers: drivers,
                changes: changes,
                pressureContext: pressureContext,
                customMetricIds: customMetricIds
            )
        case .pastWeek:
            return curatedWeeklyInsights(from: deduplicatedInsights)
        case .pastYear:
            return curatedYearlyInsights(from: deduplicatedInsights)
        }
    }

    // `Today` should read like a briefing: one current-state card, one recent-change card,
    // and then the strongest remaining pattern instead of a flat list of similar cards.
    private func curatedTodayInsights(
        from deduplicatedInsights: [SQInsight],
        referenceDate: Date,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        pressureContext: CurrentPressureContext,
        customMetricIds: Set<String>
    ) -> [SQInsight] {
        let nonCustomInsights = deduplicatedInsights.filter {
            !isCustomMetricInsight($0, customMetricIds: customMetricIds)
        }
        let heroInsight = todayHeroInsight(
            from: nonCustomInsights,
            drivers: drivers,
            changes: changes,
            pressureContext: pressureContext
        )

        let remainingInsights = deduplicatedInsights.filter { $0.id != heroInsight?.id }
        let customRelationshipInsight = protectedCustomRelationshipSupportingInsight(
            from: remainingInsights,
            referenceDate: referenceDate,
            surfaceIntent: .today
        )
        let customInsight = protectedCustomMetricSupportingInsight(
            from: remainingInsights.filter { $0.id != customRelationshipInsight?.id },
            customMetricIds: customMetricIds,
            referenceDate: referenceDate,
            surfaceIntent: .today
        )
        let nonCustomRemainingInsights = remainingInsights.filter {
            !isCustomMetricInsight($0, customMetricIds: customMetricIds)
        }

        var selected = [SQInsight]()
        var usedIds = Set<String>()

        func appendIfAvailable(_ insight: SQInsight?) {
            guard let insight, !usedIds.contains(insight.id), selected.count < 4 else { return }
            selected.append(insight)
            usedIds.insert(insight.id)
        }

        appendIfAvailable(heroInsight)
        appendIfAvailable(todaySlotInsight(
            from: nonCustomRemainingInsights,
            usedIds: usedIds,
            slot: .recentChange
        ))
        appendIfAvailable(todaySlotInsight(
            from: nonCustomRemainingInsights,
            usedIds: usedIds,
            slot: .relationship
        ))
        if let customInsight {
            appendIfAvailable(customInsight)
        }
        if let customRelationshipInsight {
            appendIfAvailable(customRelationshipInsight)
        }

        if selected.count < 4 {
            for candidate in nonCustomRemainingInsights where !usedIds.contains(candidate.id) {
                guard selected.count < 4 else { break }
                selected.append(candidate)
                usedIds.insert(candidate.id)
            }
        }

        return hardGatedTodayInsights(
            from: selected,
            pressureContext: pressureContext,
            drivers: drivers,
            changes: changes
        )
    }

    private enum TodayInsightSlot {
        case recentChange
        case relationship
    }

    private func todaySlotInsight(
        from insights: [SQInsight],
        usedIds: Set<String>,
        slot: TodayInsightSlot
    ) -> SQInsight? {
        insights.first { insight in
            guard !usedIds.contains(insight.id) else { return false }

            switch slot {
            case .recentChange:
                switch insight.insightClass {
                case .followUp, .trend, .baselineChange:
                    return true
                case .risk, .opportunity, .relationship, .populationBenchmark, .cohort:
                    return false
                }
            case .relationship:
                return insight.insightClass == .relationship
            }
        }
    }

    private func protectedCustomRelationshipSupportingInsight(
        from insights: [SQInsight],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsight? {
        insights
            .filter(isCustomRelationshipInsight)
            .filter {
                customInsightCooldownAllows(
                    $0,
                    referenceDate: referenceDate,
                    surfaceIntent: surfaceIntent
                )
            }
            .filter { $0.confidence == .medium || $0.confidence == .high }
            .sorted(by: { sortInsightsForDisplay($0, $1) })
            .first
    }

    private func protectedCustomMetricSupportingInsight(
        from insights: [SQInsight],
        customMetricIds: Set<String>,
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsight? {
        insights
            .filter { isCustomMetricInsight($0, customMetricIds: customMetricIds) }
            .filter { !isCustomRelationshipInsight($0) }
            .filter {
                customInsightCooldownAllows(
                    $0,
                    referenceDate: referenceDate,
                    surfaceIntent: surfaceIntent
                )
            }
            .filter { $0.rankingScore >= 24 || $0.confidence == .medium || $0.confidence == .high }
            .sorted(by: { sortInsightsForDisplay($0, $1) })
            .first
    }

    private func hardGatedTodayInsights(
        from insights: [SQInsight],
        pressureContext: CurrentPressureContext,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> [SQInsight] {
        guard isUnderPressureContext(
            drivers: drivers,
            changes: changes,
            pressureContext: pressureContext
        ) else {
            return insights
        }

        return insights.compactMap { insight in
            guard isPositiveCurrentStateInsight(insight) else {
                return insight
            }

            if isDominantBrightSpot(
                insight,
                drivers: drivers,
                pressureContext: pressureContext
            ) {
                return brightSpotInsight(from: insight)
            }

            return nil
        }
    }

    private func customInsightCooldownAllows(
        _ insight: SQInsight,
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Bool {
        guard surfaceIntent == .today else { return true }
        let cooldownDays = isCustomRelationshipInsight(insight) ? 10 : 6
        let highSeverity = isHighSeverityCustomInsight(insight)
        let noveltyState = surfacingMemoryStore.noveltyState(
            for: insight.familyKey,
            referenceDate: referenceDate,
            scopeKey: noveltyScopeKey,
            surfaceIntent: surfaceIntent
        )

        guard let daysSinceLastShown = noveltyState.daysSinceLastShown else {
            return customMetricAggregateCooldownAllows(
                insight,
                referenceDate: referenceDate,
                surfaceIntent: surfaceIntent,
                highSeverity: highSeverity
            )
        }

        guard daysSinceLastShown >= cooldownDays || highSeverity else {
            return false
        }

        return customMetricAggregateCooldownAllows(
            insight,
            referenceDate: referenceDate,
            surfaceIntent: surfaceIntent,
            highSeverity: highSeverity
        )
    }

    private func customMetricAggregateCooldownAllows(
        _ insight: SQInsight,
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent,
        highSeverity: Bool
    ) -> Bool {
        guard insight.familyKey.hasPrefix("customMetric."),
              let metricId = insight.inputSignalId else {
            return true
        }

        let noveltyState = surfacingMemoryStore.noveltyState(
            for: customMetricAggregateNoveltyKey(for: metricId),
            referenceDate: referenceDate,
            scopeKey: noveltyScopeKey,
            surfaceIntent: surfaceIntent
        )
        guard let daysSinceLastShown = noveltyState.daysSinceLastShown else {
            return true
        }

        return daysSinceLastShown >= 5 || highSeverity
    }

    private func isHighSeverityCustomInsight(_ insight: SQInsight) -> Bool {
        insight.confidence == .high || (insight.effect == .negative && insight.rankingScore >= 34)
    }

    private func isCustomMetricInsight(
        _ insight: SQInsight,
        customMetricIds: Set<String>
    ) -> Bool {
        guard !customMetricIds.isEmpty else { return false }
        if insight.familyKey.hasPrefix("customMetric.") {
            return true
        }

        let signalIds = [insight.inputSignalId, insight.outputSignalId].compactMap { $0 }
        return signalIds.contains { customMetricIds.contains($0) }
    }

    private func isCustomRelationshipInsight(_ insight: SQInsight) -> Bool {
        insight.familyKey.hasPrefix("customRelationship.")
    }

    private func contextAdjustedCurrentStateInsights(
        from insights: [SQInsight],
        pressureContext: CurrentPressureContext,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsight] {
        guard surfaceIntent == .today else { return insights }
        guard isUnderPressureContext(
            drivers: drivers,
            changes: changes,
            pressureContext: pressureContext
        ) else {
            return insights
        }

        return insights.compactMap { insight in
            guard isPositiveCurrentStateInsight(insight) else {
                return insight
            }

            if isDominantBrightSpot(
                insight,
                drivers: drivers,
                pressureContext: pressureContext
            ) {
                return brightSpotInsight(from: insight)
            }

            return nil
        }
    }

    private func isUnderPressureContext(
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        pressureContext: CurrentPressureContext
    ) -> Bool {
        let supportiveDrivers = drivers.filter { $0.direction == .supportive }
        let dragDrivers = drivers.filter { $0.direction == .drag }
        let supportiveScore = supportiveDrivers.prefix(3).map(\.rankingScore).reduce(0, +)
        let dragScore = dragDrivers.prefix(3).map(\.rankingScore).reduce(0, +)
        let worseningStateChangeCount = changes.filter {
            isStateSignalId($0.signalId) && $0.direction == .worsened
        }
        .count

        return pressureContext.isPressured
            || dragScore >= supportiveScore + 4
            || (dragDrivers.count >= 2 && dragScore >= supportiveScore)
            || (worseningStateChangeCount >= 2 && dragScore >= supportiveScore - 2)
    }

    private struct CurrentPressureContext {
        let isPressured: Bool
        let negativeSignalCount: Int
        let supportiveSignalCount: Int
        let strongestSupportiveSignalIds: Set<String>
    }

    private func pressureContext(
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date
    ) -> CurrentPressureContext {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)
        guard let snapshot = snapshots
            .filter({ $0.date <= referenceDate || calendar.isDate($0.date, inSameDayAs: referenceDay) })
            .max(by: { $0.date < $1.date }) else {
            return .init(
                isPressured: false,
                negativeSignalCount: 0,
                supportiveSignalCount: 0,
                strongestSupportiveSignalIds: []
            )
        }

        var negativeSignals = Set<String>()
        var supportiveSignals = Set<String>()

        for feature in snapshot.signalFeatures.values {
            if let utilityScore = feature.goalUtilityScore {
                if utilityScore <= 58 {
                    negativeSignals.insert(feature.signalId)
                } else if utilityScore >= 80 {
                    supportiveSignals.insert(feature.signalId)
                }
                continue
            }

            let rawValue = feature.rawValue
            switch feature.signalId {
            case SQMetricId.sleepHours:
                if rawValue < 6.25 || rawValue > 9.25 {
                    negativeSignals.insert(feature.signalId)
                } else if rawValue >= 7.0 && rawValue <= 8.6 {
                    supportiveSignals.insert(feature.signalId)
                }
            case SQMetricId.sleepQuality,
                 SQMetricId.energy,
                 SQMetricId.mood,
                 SQMetricId.mentalClarity,
                 SQMetricId.motivation,
                 SQInsightAnalysisMetricId.workoutPerformance:
                if rawValue <= 5.5 {
                    negativeSignals.insert(feature.signalId)
                } else if rawValue >= 7.3 {
                    supportiveSignals.insert(feature.signalId)
                }
            case SQMetricId.stress,
                 SQMetricId.anxiety,
                 SQMetricId.soreness,
                 SQInsightAnalysisMetricId.workoutDifficulty:
                if rawValue >= 6.5 {
                    negativeSignals.insert(feature.signalId)
                } else if rawValue <= 3.2 {
                    supportiveSignals.insert(feature.signalId)
                }
            default:
                break
            }
        }

        if snapshot.averageWorkoutDifficulty.map({ $0 >= 7.5 }) == true {
            negativeSignals.insert(SQInsightAnalysisMetricId.workoutDifficulty)
        }

        if snapshot.averageWorkoutPerformance.map({ $0 >= 7.4 }) == true {
            supportiveSignals.insert(SQInsightAnalysisMetricId.workoutPerformance)
        } else if snapshot.averageWorkoutPerformance.map({ $0 <= 5.5 }) == true {
            negativeSignals.insert(SQInsightAnalysisMetricId.workoutPerformance)
        }

        let isPressured = negativeSignals.count >= 2
            || (negativeSignals.count >= 1 && negativeSignals.count > supportiveSignals.count)

        return .init(
            isPressured: isPressured,
            negativeSignalCount: negativeSignals.count,
            supportiveSignalCount: supportiveSignals.count,
            strongestSupportiveSignalIds: supportiveSignals
        )
    }

    private func isPositiveCurrentStateInsight(_ insight: SQInsight) -> Bool {
        guard insight.insightClass == .opportunity,
              insight.effect == .positive else {
            return false
        }

        let signalIds = [insight.inputSignalId, insight.outputSignalId].compactMap { $0 }
        guard signalIds.contains(where: isStateSignalId) else {
            return false
        }

        return [
            "You're well recovered today",
            "Your body looks ready to handle more",
            "You're in a good position to train today",
            "You're in a good position today",
            "Things are lining up for a solid day",
            "The day should feel relatively smooth"
        ].contains(insight.title)
    }

    private func isDominantBrightSpot(
        _ insight: SQInsight,
        drivers: [SQInsightDriver],
        pressureContext: CurrentPressureContext
    ) -> Bool {
        let supportiveDrivers = drivers.filter { $0.direction == .supportive }
        let dragDrivers = drivers.filter { $0.direction == .drag }
        guard let strongestSupportiveDriver = supportiveDrivers.first else { return false }

        let signalIds = Set([insight.inputSignalId, insight.outputSignalId].compactMap { $0 })
        guard signalIds.contains(strongestSupportiveDriver.signalId) else {
            return false
        }

        let supportiveScore = supportiveDrivers.prefix(2).map(\.rankingScore).reduce(0, +)
        let dragScore = dragDrivers.prefix(2).map(\.rankingScore).reduce(0, +)
        let snapshotSupportsInsight = pressureContext.strongestSupportiveSignalIds.isEmpty
            || !signalIds.isDisjoint(with: pressureContext.strongestSupportiveSignalIds)

        return snapshotSupportsInsight
            && strongestSupportiveDriver.rankingScore >= 13
            && supportiveScore >= max(12, dragScore * 0.9)
            && pressureContext.supportiveSignalCount >= max(1, pressureContext.negativeSignalCount)
    }

    private func brightSpotInsight(from insight: SQInsight) -> SQInsight {
        let signalIds = Set([insight.inputSignalId, insight.outputSignalId].compactMap { $0 })
        let title: String
        let summary: String

        if signalIds.contains(SQMetricId.sleepHours) || signalIds.contains(SQMetricId.sleepQuality) {
            title = "Sleep is helping, but other signals are still dragging"
            summary = "Sleep looks supportive, but the overall day still has pressure from other signals."
        } else if signalIds.contains(SQInsightAnalysisMetricId.restingHeartRate) {
            title = "Recovery is one bright spot today"
            summary = "Recovery looks supportive, but the overall day still has pressure from other signals."
        } else if signalIds.contains(SQMetricId.soreness)
                    || signalIds.contains(SQInsightAnalysisMetricId.workoutDifficulty)
                    || signalIds.contains(SQInsightAnalysisMetricId.workoutPerformance) {
            title = "Readiness is one bright spot today"
            summary = "Training readiness looks supportive, but the overall day still has pressure from other signals."
        } else {
            title = "\(insight.driverText) is one bright spot today"
            summary = "\(insight.driverText) looks supportive, but the overall day still has pressure from other signals."
        }

        return insight.withPresentation(
            title: title,
            summary: summary,
            actionText: "Use the supportive signal, but keep the rest of the day low-friction."
        )
    }

    private func todayHeroInsight(
        from insights: [SQInsight],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        pressureContext: CurrentPressureContext
    ) -> SQInsight? {
        if let stateHeroInsight = stateDrivenTodayHeroInsight(
            from: drivers,
            changes: changes,
            insights: insights,
            pressureContext: pressureContext
        ) {
            return stateHeroInsight
        }

        let filteredInsights: [SQInsight]
        let hasAlternativeCandidate = insights.contains {
            !isPositiveCleanupHabitHeroCandidate($0)
                && !isHabitTrendHeroCandidate($0)
        }

        if hasAlternativeCandidate {
            filteredInsights = insights.filter {
                !isPositiveCleanupHabitHeroCandidate($0)
                    && !isHabitTrendHeroCandidate($0)
            }
        } else {
            filteredInsights = insights
        }

        return filteredInsights.max { lhs, rhs in
            let lhsScore = todayHeroPriorityScore(
                for: lhs,
                drivers: drivers,
                changes: changes
            )
            let rhsScore = todayHeroPriorityScore(
                for: rhs,
                drivers: drivers,
                changes: changes
            )

            if lhsScore != rhsScore {
                return lhsScore < rhsScore
            }

            return !sortInsightsForDisplay(lhs, rhs)
        }
    }

    private func stateDrivenTodayHeroInsight(
        from drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        insights: [SQInsight],
        pressureContext: CurrentPressureContext
    ) -> SQInsight? {
        let stateDrivers = drivers
            .filter { isStateSignalId($0.signalId) }
            .sorted { $0.rankingScore > $1.rankingScore }

        guard !stateDrivers.isEmpty else { return nil }

        let supportiveDrivers = stateDrivers.filter { $0.direction == .supportive }
        let dragDrivers = stateDrivers.filter { $0.direction == .drag }

        let supportiveScore = supportiveDrivers.prefix(2).map(\.rankingScore).reduce(0, +)
        let dragScore = dragDrivers.prefix(2).map(\.rankingScore).reduce(0, +)

        let selectedDirection: SQInsightDriverDirection
        let selectedDrivers: [SQInsightDriver]

        if supportiveScore >= dragScore + 1.5, let strongestSupportiveDriver = supportiveDrivers.first {
            selectedDirection = .supportive
            selectedDrivers = uniqueThemeDrivers(
                from: Array(supportiveDrivers.prefix(3)),
                primaryDriver: strongestSupportiveDriver
            )
        } else if dragScore >= supportiveScore + 1.5, let strongestDragDriver = dragDrivers.first {
            selectedDirection = .drag
            selectedDrivers = uniqueThemeDrivers(
                from: Array(dragDrivers.prefix(3)),
                primaryDriver: strongestDragDriver
            )
        } else if let strongestStateDriver = stateDrivers.first, strongestStateDriver.rankingScore >= 9 {
            selectedDirection = strongestStateDriver.direction
            selectedDrivers = uniqueThemeDrivers(
                from: Array(stateDrivers.filter { $0.direction == strongestStateDriver.direction }.prefix(3)),
                primaryDriver: strongestStateDriver
            )
        } else {
            return nil
        }

        guard let primaryDriver = selectedDrivers.first else { return nil }

        let primaryTheme = stateTheme(for: primaryDriver.signalId)
        let secondaryTheme = selectedDrivers.dropFirst().first.map { stateTheme(for: $0.signalId) }
        let shouldUseBrightSpotFraming = selectedDirection == .supportive
            && (
                pressureContext.isPressured
                || (dragScore > 0 && dragScore >= supportiveScore * 0.5)
            )
        let title = shouldUseBrightSpotFraming
            ? stateBrightSpotTitle(primaryTheme: primaryTheme)
            : stateHeroTitle(
                direction: selectedDirection,
                primaryTheme: primaryTheme,
                secondaryTheme: secondaryTheme
            )
        let summary = stateHeroSummary(
            title: title,
            drivers: selectedDrivers
        )
        let actionText = shouldUseBrightSpotFraming
            ? "Use the supportive signal, but keep the rest of the day low-friction."
            : (selectedDirection == .supportive ? "Use this window for a strong workout." : "Make recovery the priority today.")

        let syntheticHeroInsight = SQInsight(
            id: "today-state-\(selectedDirection == .supportive ? "supportive" : "drag")-\(primaryTheme.key)-\(secondaryTheme?.key ?? "solo")",
            familyKey: "today.state.\(selectedDirection == .supportive ? "supportive" : "drag").\(primaryTheme.key).\(secondaryTheme?.key ?? "solo")",
            insightClass: selectedDirection == .supportive ? .opportunity : .risk,
            variantPriority: 0,
            inputSignalId: primaryTheme.preferredSignalId,
            outputSignalId: primaryTheme.preferredSignalId,
            recommendationFamily: stateRecommendationFamily(
                for: primaryTheme,
                direction: selectedDirection
            ),
            title: title,
            summary: summary,
            evidenceText: selectedDrivers.map(\.summary).joined(separator: " "),
            actionText: actionText,
            driverText: primaryTheme.displayTitle,
            outcomeText: "today",
            deltaText: primaryDriver.deltaText,
            category: primaryDriver.category,
            confidence: selectedDrivers.count > 1 ? .high : .medium,
            effect: selectedDirection == .supportive ? .positive : .negative,
            sampleCount: max(1, selectedDrivers.count),
            rankingScore: selectedDrivers.map(\.rankingScore).reduce(0, +) + 24
        )

        if selectedDirection == .drag,
           let explanatoryTrend = explanatoryNegativeHabitHeroInsight(
                from: insights,
                dragStrength: dragScore,
                changes: changes
           ) {
            return explanatoryTrend
        }

        return syntheticHeroInsight
    }

    private func isStateDrivenHeroCandidate(_ insight: SQInsight) -> Bool {
        let inputSignalId = insight.inputSignalId ?? ""
        let outputSignalId = insight.outputSignalId ?? ""
        return isStateSignalId(inputSignalId) || isStateSignalId(outputSignalId)
    }

    private func isPositiveCleanupHabitHeroCandidate(_ insight: SQInsight) -> Bool {
        let inputSignalId = insight.inputSignalId ?? ""
        let outputSignalId = insight.outputSignalId ?? ""
        let isHabitSignal = isHabitSignalId(inputSignalId) || isHabitSignalId(outputSignalId)

        guard isHabitSignal else { return false }
        guard insight.effect == .positive else { return false }

        switch insight.insightClass {
        case .trend, .baselineChange, .followUp:
            return true
        case .relationship, .risk, .opportunity, .populationBenchmark, .cohort:
            return false
        }
    }

    private func isHabitTrendHeroCandidate(_ insight: SQInsight) -> Bool {
        let inputSignalId = insight.inputSignalId ?? ""
        let outputSignalId = insight.outputSignalId ?? ""
        let isHabitSignal = isHabitSignalId(inputSignalId) || isHabitSignalId(outputSignalId)

        return isHabitSignal && insight.insightClass == .trend
    }

    private func todayHeroPriorityScore(
        for insight: SQInsight,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> Double {
        let inputSignalId = insight.inputSignalId ?? ""
        let outputSignalId = insight.outputSignalId ?? ""
        let isStateSignal = isStateSignalId(inputSignalId) || isStateSignalId(outputSignalId)
        let isHabitSignal = isHabitSignalId(inputSignalId) || isHabitSignalId(outputSignalId)
        let hasStatePressure = drivers.contains {
            isStateSignalId($0.signalId) && $0.direction == .drag
        } || changes.contains {
            isStateSignalId($0.signalId) && $0.direction == .worsened
        }
        let hasSupportiveState = drivers.contains {
            isStateSignalId($0.signalId) && $0.direction == .supportive
        } || changes.contains {
            isStateSignalId($0.signalId) && $0.direction == .improved
        }

        var score = insight.rankingScore

        switch insight.insightClass {
        case .risk, .opportunity:
            score += 10
        case .baselineChange:
            score += isStateSignal ? 7 : 3
        case .followUp:
            score += 5
        case .relationship:
            score += isStateSignal ? 3 : 1
        case .trend:
            if isStateSignal {
                score += 4
            } else if isHabitSignal {
                if insight.effect == .negative {
                    score -= hasStatePressure ? 6 : 16
                } else {
                    score -= 30
                }
            }
        case .populationBenchmark, .cohort:
            score -= 4
        }

        if isStateSignal {
            switch insight.effect {
            case .positive:
                if hasSupportiveState {
                    score += 4
                }
                score += 2
            case .negative:
                if hasStatePressure {
                    score += 4
                }
                score += 3
            case .neutral:
                break
            }
        }

        if isHabitSignal {
            switch insight.effect {
            case .positive:
                score -= hasStatePressure ? 18 : 40
            case .negative:
                score -= insight.insightClass == .trend ? 16 : (hasStatePressure ? 0 : 8)
            case .neutral:
                score -= 6
            }
        }

        return score
    }

    private func explanatoryNegativeHabitHeroInsight(
        from insights: [SQInsight],
        dragStrength: Double,
        changes: [SQInsightChange]
    ) -> SQInsight? {
        let candidates = insights.filter { insight in
            let inputSignalId = insight.inputSignalId ?? ""
            let outputSignalId = insight.outputSignalId ?? ""
            let isHabitSignal = isHabitSignalId(inputSignalId) || isHabitSignalId(outputSignalId)

            guard isHabitSignal else { return false }
            guard insight.effect == .negative else { return false }

            let allowedClass: Bool
            switch insight.insightClass {
            case .baselineChange, .followUp, .relationship, .risk:
                allowedClass = true
            case .trend, .opportunity, .populationBenchmark, .cohort:
                allowedClass = false
            }

            return allowedClass
        }
        .sorted(by: { sortInsightsForDisplay($0, $1) })

        guard let bestCandidate = candidates.first else { return nil }

        let habitSignalId = bestCandidate.inputSignalId ?? bestCandidate.outputSignalId ?? ""
        let relatedWorseningChange = changes.contains { change in
            habitSignalId == change.signalId && change.direction == .worsened
        }

        if bestCandidate.rankingScore >= dragStrength + 10 || relatedWorseningChange {
            return bestCandidate
        }

        return nil
    }

    private func isStateSignalId(_ signalId: String) -> Bool {
        let stateSignalIds: Set<String> = [
            SQMetricId.sleepHours,
            SQMetricId.sleepQuality,
            SQInsightAnalysisMetricId.restingHeartRate,
            SQMetricId.energy,
            SQMetricId.mood,
            SQMetricId.mentalClarity,
            SQMetricId.motivation,
            SQMetricId.stress,
            SQMetricId.anxiety,
            SQMetricId.soreness,
            SQInsightAnalysisMetricId.workoutDifficulty,
            SQInsightAnalysisMetricId.workoutPerformance
        ]

        return stateSignalIds.contains(signalId)
    }

    private func isHabitSignalId(_ signalId: String) -> Bool {
        let habitSignalIds: Set<String> = [
            SQMetricId.alcohol,
            SQMetricId.caffeine,
            SQMetricId.weed,
            SQMetricId.nicotine,
            SQMetricId.porn
        ]

        return habitSignalIds.contains(signalId)
    }

    private func isHighFrequencyBehaviorSignalId(_ signalId: String) -> Bool {
        [
            SQMetricId.caffeine,
            SQMetricId.nicotine,
            SQMetricId.weed,
            SQMetricId.porn
        ].contains(signalId)
    }

    private func isSleepSignalId(_ signalId: String) -> Bool {
        [
            SQMetricId.sleepHours,
            SQMetricId.sleepQuality
        ].contains(signalId)
    }

    private func isTrainingSignalId(_ signalId: String) -> Bool {
        [
            SQMetricId.soreness,
            SQInsightAnalysisMetricId.workoutDifficulty,
            SQInsightAnalysisMetricId.workoutPerformance
        ].contains(signalId)
    }

    private func isStressOrMoodPressureSignalId(_ signalId: String) -> Bool {
        [
            SQMetricId.stress,
            SQMetricId.anxiety,
            SQMetricId.energy,
            SQMetricId.mood,
            SQMetricId.mentalClarity,
            SQMetricId.motivation
        ].contains(signalId)
    }

    private struct StateTheme {
        let key: String
        let displayTitle: String
        let preferredSignalId: String
    }

    private func stateTheme(for signalId: String) -> StateTheme {
        switch signalId {
        case SQMetricId.sleepHours, SQMetricId.sleepQuality:
            return .init(key: "sleep", displayTitle: "Sleep", preferredSignalId: SQMetricId.sleepQuality)
        case SQInsightAnalysisMetricId.restingHeartRate:
            return .init(key: "recovery", displayTitle: "Recovery", preferredSignalId: SQInsightAnalysisMetricId.restingHeartRate)
        case SQMetricId.energy:
            return .init(key: "energy", displayTitle: "Energy", preferredSignalId: SQMetricId.energy)
        case SQMetricId.mood:
            return .init(key: "mood", displayTitle: "Mood", preferredSignalId: SQMetricId.mood)
        case SQMetricId.mentalClarity:
            return .init(key: "mentalClarity", displayTitle: "Mental clarity", preferredSignalId: SQMetricId.mentalClarity)
        case SQMetricId.motivation:
            return .init(key: "motivation", displayTitle: "Motivation", preferredSignalId: SQMetricId.motivation)
        case SQMetricId.stress:
            return .init(key: "stress", displayTitle: "Stress", preferredSignalId: SQMetricId.stress)
        case SQMetricId.anxiety:
            return .init(key: "anxiety", displayTitle: "Anxiety", preferredSignalId: SQMetricId.anxiety)
        case SQMetricId.soreness:
            return .init(key: "soreness", displayTitle: "Soreness", preferredSignalId: SQMetricId.soreness)
        case SQInsightAnalysisMetricId.workoutDifficulty:
            return .init(key: "strain", displayTitle: "Training load", preferredSignalId: SQInsightAnalysisMetricId.workoutDifficulty)
        case SQInsightAnalysisMetricId.workoutPerformance:
            return .init(key: "performance", displayTitle: "Performance", preferredSignalId: SQInsightAnalysisMetricId.workoutPerformance)
        default:
            return .init(key: signalId, displayTitle: signalId, preferredSignalId: signalId)
        }
    }

    private func uniqueThemeDrivers(
        from drivers: [SQInsightDriver],
        primaryDriver: SQInsightDriver
    ) -> [SQInsightDriver] {
        let primaryThemeKey = stateTheme(for: primaryDriver.signalId).key
        let secondaryDriver = drivers.first {
            stateTheme(for: $0.signalId).key != primaryThemeKey
            && abs($0.rankingScore - primaryDriver.rankingScore) <= 2.5
        }

        return [primaryDriver, secondaryDriver].compactMap { $0 }
    }

    private func stateHeroTitle(
        direction: SQInsightDriverDirection,
        primaryTheme: StateTheme,
        secondaryTheme: StateTheme?
    ) -> String {
        if let secondaryTheme {
            switch (direction, primaryTheme.key, secondaryTheme.key) {
            case (.drag, "stress", "anxiety"), (.drag, "anxiety", "stress"):
                return "The day may feel heavier than usual"
            case (.supportive, "sleep", "recovery"), (.supportive, "recovery", "sleep"):
                return "You're well recovered today"
            case (.supportive, "stress", "anxiety"), (.supportive, "anxiety", "stress"):
                return "The day should feel relatively smooth"
            case (.supportive, "soreness", "strain"), (.supportive, "strain", "soreness"):
                return "You're in a good position to train today"
            default:
                return direction == .supportive
                    ? "Things are lining up for a solid day"
                    : "Several signals are dragging you down"
            }
        }

        switch (direction, primaryTheme.key) {
        case (.supportive, "stress"):
            return "The day should feel relatively smooth"
        case (.supportive, "anxiety"):
            return "The day should feel relatively smooth"
        case (.supportive, "soreness"):
            return "Your body looks ready to handle more"
        case (.supportive, "strain"):
            return "You're in a good position to train today"
        case (.supportive, "sleep"), (.supportive, "recovery"):
            return "You're well recovered today"
        case (.drag, "stress"):
            return "The day may feel heavier than usual"
        case (.drag, "anxiety"):
            return "The day may feel heavier than usual"
        case (.drag, "strain"):
            return "Training load is catching up with you"
        case (.drag, "recovery"):
            return "Recovery isn't fully keeping up"
        default:
            return direction == .supportive
                ? "You're in a good position today"
                : "Some signals are starting to slip"
        }
    }

    private func stateBrightSpotTitle(primaryTheme: StateTheme) -> String {
        switch primaryTheme.key {
        case "sleep":
            return "Sleep is helping, but other signals are still dragging"
        case "recovery":
            return "Recovery is one bright spot today"
        case "soreness", "strain", "performance":
            return "Readiness is one bright spot today"
        default:
            return "\(primaryTheme.displayTitle) is one bright spot today"
        }
    }

    private func stateHeroSummary(
        title: String,
        drivers: [SQInsightDriver]
    ) -> String {
        let driverSummaries = drivers.map(\.summary).joined(separator: " ")
        guard !driverSummaries.isEmpty else { return title }
        return "\(title). \(driverSummaries)"
    }

    private func stateRecommendationFamily(
        for theme: StateTheme,
        direction: SQInsightDriverDirection
    ) -> SQInsightRecommendationFamily {
        switch theme.key {
        case "sleep", "recovery", "energy":
            return .protectRecovery
        case "strain", "soreness", "performance":
            return .moderateStrain
        case "stress", "anxiety", "mentalClarity", "mood", "motivation":
            return .keepConsistent
        default:
            return direction == .supportive ? .keepConsistent : .observeAndCompare
        }
    }

    private func curatedWeeklyInsights(from deduplicatedInsights: [SQInsight]) -> [SQInsight] {
        curateInsights(
            from: deduplicatedInsights,
            preferredBuckets: [
                [.trend, .baselineChange],
                [.followUp, .risk, .opportunity],
                [.relationship]
            ],
            maximumCount: 6
        )
    }

    private func curatedYearlyInsights(from deduplicatedInsights: [SQInsight]) -> [SQInsight] {
        curateInsights(
            from: deduplicatedInsights,
            preferredBuckets: [
                [.relationship],
                [.baselineChange],
                [.trend, .followUp]
            ],
            maximumCount: 5
        )
    }

    private func curateInsights(
        from insights: [SQInsight],
        preferredBuckets: [Set<SQInsightClass>],
        maximumCount: Int
    ) -> [SQInsight] {
        var selected = [SQInsight]()
        var usedIds = Set<String>()

        for bucket in preferredBuckets {
            guard let candidate = insights.first(where: { bucket.contains($0.insightClass) && !usedIds.contains($0.id) }) else {
                continue
            }

            selected.append(candidate)
            usedIds.insert(candidate.id)
        }

        for candidate in insights where !usedIds.contains(candidate.id) {
            guard selected.count < maximumCount else { break }
            selected.append(candidate)
            usedIds.insert(candidate.id)
        }

        return selected
    }

    private func curatedDrivers(
        from drivers: [SQInsightDriver],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightDriver] {
        switch surfaceIntent {
        case .today:
            return curatedTodayDrivers(from: drivers)
        case .pastWeek:
            return curatedStandardDrivers(from: drivers, maximumCount: 4)
        case .pastYear:
            return curatedStandardDrivers(from: drivers, maximumCount: 4)
        }
    }

    private func curatedChanges(
        from changes: [SQInsightChange],
        surfaceIntent: SQInsightSurfaceIntent,
        selectedDrivers: [SQInsightDriver]
    ) -> [SQInsightChange] {
        switch surfaceIntent {
        case .today:
            return curatedTodayChanges(
                from: changes,
                selectedDrivers: selectedDrivers
            )
        case .pastWeek:
            return curatedStandardChanges(from: changes, maximumCount: 3)
        case .pastYear:
            return curatedStandardChanges(from: changes, maximumCount: 3)
        }
    }

    private func curatedTodayDrivers(from drivers: [SQInsightDriver]) -> [SQInsightDriver] {
        let preferredSignalIds: Set<String> = [
            SQMetricId.sleepHours,
            SQMetricId.sleepQuality,
            SQInsightAnalysisMetricId.restingHeartRate,
            SQMetricId.energy,
            SQMetricId.mood,
            SQMetricId.mentalClarity,
            SQMetricId.motivation,
            SQMetricId.stress,
            SQMetricId.anxiety,
            SQMetricId.soreness,
            SQMetricId.alcohol,
            SQMetricId.caffeine,
            SQMetricId.weed,
            SQMetricId.nicotine,
            SQMetricId.porn,
            SQInsightAnalysisMetricId.workoutPerformance,
            SQInsightAnalysisMetricId.workoutDifficulty
        ]

        let preferredDrivers = drivers.filter { preferredSignalIds.contains($0.signalId) }
        let sortedDrivers = preferredDrivers.sorted { lhs, rhs in
            let lhsScore = calibratedTodayDriverScore(lhs, allDrivers: preferredDrivers)
            let rhsScore = calibratedTodayDriverScore(rhs, allDrivers: preferredDrivers)

            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            return lhs.rankingScore > rhs.rankingScore
        }

        return Array(sortedDrivers.prefix(3))
    }

    private func calibratedTodayDriverScore(
        _ driver: SQInsightDriver,
        allDrivers: [SQInsightDriver]
    ) -> Double {
        var score = driver.rankingScore
        let hasCompetingDrag = allDrivers.contains { candidate in
            candidate.signalId != driver.signalId
                && candidate.direction == .drag
                && (
                    isSleepSignalId(candidate.signalId)
                    || isTrainingSignalId(candidate.signalId)
                    || isStressOrMoodPressureSignalId(candidate.signalId)
                    || isHabitSignalId(candidate.signalId)
                )
        }

        if driver.signalId == SQInsightAnalysisMetricId.restingHeartRate {
            if hasCompetingDrag {
                score -= 16
            }

            if driver.effectMagnitude < 4 {
                score -= 8
            }

            if driver.direction == .supportive,
               allDrivers.contains(where: { $0.direction == .drag }) {
                score -= 6
            }
        }

        if driver.direction == .drag {
            if isStressOrMoodPressureSignalId(driver.signalId) {
                score += 13
            }

            if isTrainingSignalId(driver.signalId) || driver.signalId == SQMetricId.soreness {
                score += 12
            }

            if isSleepSignalId(driver.signalId) {
                score += 9
            }

            if driver.signalId == SQMetricId.alcohol {
                score += 13
            } else if [SQMetricId.weed, SQMetricId.nicotine, SQMetricId.porn].contains(driver.signalId) {
                score += 10
            } else if driver.signalId == SQMetricId.caffeine {
                score += 4
            }
        }

        if driver.direction == .supportive {
            if isStressOrMoodPressureSignalId(driver.signalId)
                || isTrainingSignalId(driver.signalId)
                || isSleepSignalId(driver.signalId) {
                score += 3
            }
        }

        return score
    }

    private func curatedStandardDrivers(
        from drivers: [SQInsightDriver],
        maximumCount: Int
    ) -> [SQInsightDriver] {
        var selected = [SQInsightDriver]()
        var usedDirections = Set<SQInsightDriverDirection>()

        for driver in drivers {
            if usedDirections.count < 2, !usedDirections.contains(driver.direction) {
                selected.append(driver)
                usedDirections.insert(driver.direction)
            }

            if selected.count >= maximumCount {
                return selected
            }
        }

        for driver in drivers where !selected.contains(driver) {
            guard selected.count < maximumCount else { break }
            selected.append(driver)
        }

        return selected
    }

    private func curatedTodayChanges(
        from changes: [SQInsightChange],
        selectedDrivers: [SQInsightDriver]
    ) -> [SQInsightChange] {
        let driverSignalIds = Set(selectedDrivers.map(\.signalId))
        let prioritized = changes.filter { !driverSignalIds.contains($0.signalId) }
            + changes.filter { driverSignalIds.contains($0.signalId) }

        var selected = [SQInsightChange]()
        for change in prioritized {
            guard selected.count < 2 else { break }

            if selected.contains(where: { $0.signalId == change.signalId }) {
                continue
            }

            if let first = selected.first,
               first.category == change.category,
               first.direction == change.direction,
               prioritized.contains(where: { $0.category != first.category }) {
                continue
            }

            selected.append(change)
        }

        if selected.count < 2 {
            for change in prioritized where !selected.contains(change) {
                guard selected.count < 2 else { break }
                selected.append(change)
            }
        }

        return selected
    }

    private func curatedStandardChanges(
        from changes: [SQInsightChange],
        maximumCount: Int
    ) -> [SQInsightChange] {
        var selected = [SQInsightChange]()
        var usedDirections = Set<SQInsightChangeDirection>()

        for change in changes {
            if usedDirections.count < 2, !usedDirections.contains(change.direction) {
                selected.append(change)
                usedDirections.insert(change.direction)
            }

            if selected.count >= maximumCount {
                return selected
            }
        }

        for change in changes where !selected.contains(change) {
            guard selected.count < maximumCount else { break }
            selected.append(change)
        }

        return selected
    }

    private func curatedActions(
        from actions: [SQInsightAction],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightAction] {
        let maximumCount: Int
        switch surfaceIntent {
        case .today:
            maximumCount = 1
        case .pastWeek, .pastYear:
            maximumCount = 2
        }

        return Array(actions.prefix(maximumCount))
    }

    private func noveltyAdjustedInsights(
        from insights: [SQInsight],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsight] {
        guard surfaceIntent == .today else { return insights }

        return insights
            .map { insight in
                let noveltyState = surfacingMemoryStore.noveltyState(
                    for: insight.familyKey,
                    referenceDate: referenceDate,
                    scopeKey: noveltyScopeKey,
                    surfaceIntent: surfaceIntent
                )
                let adjustedScore = insight.rankingScore - noveltyState.penalty(for: insight)

                if SQAdminConfig.verboseLoggingEnabled, noveltyState.currentStreak > 0 {
                    SQLogger.shared.log(
                        "Applied novelty penalty to [\(insight.title)] family=\(insight.familyKey) streak=\(noveltyState.currentStreak) last7=\(noveltyState.shownCountLast7) adjustedScore=\(String(format: "%.1f", adjustedScore))",
                        .debug,
                        context: .dashboard
                    )
                }

                return insight.withRankingScore(adjustedScore)
            }
            .sorted(by: { sortInsightsForDisplay($0, $1) })
    }

    private func relationshipFamilyAdjustedInsights(
        from insights: [SQInsight],
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> [SQInsight] {
        guard surfaceIntent == .today else { return insights }

        return insights
            .compactMap { insight -> SQInsight? in
                guard let familyKey = relationshipFamilyNoveltyKey(for: insight) else {
                    return insight
                }

                let noveltyState = surfacingMemoryStore.noveltyState(
                    for: familyKey,
                    referenceDate: referenceDate,
                    scopeKey: noveltyScopeKey,
                    surfaceIntent: surfaceIntent
                )

                if shouldSuppressRepeatedRelationshipFamily(
                    insight,
                    noveltyState: noveltyState
                ) {
                    if SQAdminConfig.verboseLoggingEnabled {
                        SQLogger.shared.log(
                            "Suppressed repeated relationship family [\(insight.title)] family=\(familyKey) streak=\(noveltyState.currentStreak) last7=\(noveltyState.shownCountLast7)",
                            .debug,
                            context: .dashboard
                        )
                    }
                    return nil
                }

                let penalty = relationshipFamilyPenalty(
                    for: insight,
                    noveltyState: noveltyState
                )
                let boost = relationshipContextRelevanceBoost(
                    for: insight,
                    snapshots: snapshots,
                    referenceDate: referenceDate,
                    drivers: drivers,
                    changes: changes
                )
                let adjustedScore = insight.rankingScore - penalty + boost

                if SQAdminConfig.verboseLoggingEnabled, penalty > 0 || boost > 0 {
                    SQLogger.shared.log(
                        "Adjusted relationship family [\(insight.title)] family=\(familyKey) penalty=\(String(format: "%.1f", penalty)) boost=\(String(format: "%.1f", boost)) adjustedScore=\(String(format: "%.1f", adjustedScore))",
                        .debug,
                        context: .dashboard
                    )
                }

                return insight.withRankingScore(adjustedScore)
            }
            .sorted(by: { sortInsightsForDisplay($0, $1) })
    }

    private func shouldSuppressRepeatedRelationshipFamily(
        _ insight: SQInsight,
        noveltyState: SQInsightSurfacingNoveltyState
    ) -> Bool {
        guard insight.insightClass == .relationship else { return false }
        guard !isHighSeverityNegativeRelationship(insight) else { return false }

        if noveltyState.currentStreak >= 1 && noveltyState.shownCountLast7 >= 2 {
            return true
        }

        if let daysSinceLastShown = noveltyState.daysSinceLastShown,
           daysSinceLastShown <= 2,
           noveltyState.shownCountLast7 >= 1 {
            return true
        }

        return false
    }

    private func relationshipFamilyPenalty(
        for insight: SQInsight,
        noveltyState: SQInsightSurfacingNoveltyState
    ) -> Double {
        guard insight.insightClass == .relationship else { return 0 }
        guard !isHighSeverityNegativeRelationship(insight) else {
            return Double(noveltyState.currentStreak) * 3
        }

        var penalty = (Double(noveltyState.currentStreak) * 12)
            + (Double(max(0, noveltyState.shownCountLast7 - 1)) * 10)

        if let daysSinceLastShown = noveltyState.daysSinceLastShown {
            if daysSinceLastShown <= 3 {
                penalty += 12
            } else if daysSinceLastShown <= 6 {
                penalty += 5
            }
        }

        if insight.effect == .positive {
            penalty *= 1.12
        }

        if insight.confidence == .high {
            penalty *= 0.75
        }

        return penalty
    }

    private func relationshipContextRelevanceBoost(
        for insight: SQInsight,
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> Double {
        let signalIds = Set([insight.inputSignalId, insight.outputSignalId].compactMap { $0 })
        guard !signalIds.isEmpty else { return 0 }

        let driverIds = Set(drivers.map(\.signalId))
        let changeIds = Set(changes.map(\.signalId))
        let latestSnapshot = latestSnapshot(
            from: snapshots,
            referenceDate: referenceDate
        )

        var boost: Double = 0

        if !signalIds.isDisjoint(with: driverIds) {
            boost += 5
        }

        if !signalIds.isDisjoint(with: changeIds) {
            boost += 3
        }

        if hasHabitPressure(in: latestSnapshot, drivers: drivers, changes: changes),
           signalIds.contains(where: isHabitSignalId) {
            boost += 7
        }

        if hasTrainingPressure(in: latestSnapshot, drivers: drivers, changes: changes),
           signalIds.contains(where: isTrainingSignalId) || signalIds.contains(SQMetricId.soreness) {
            boost += 7
        }

        if hasStressPressure(in: latestSnapshot, drivers: drivers, changes: changes),
           signalIds.contains(where: isStressOrMoodPressureSignalId) {
            boost += 6
        }

        if hasSleepPressure(in: latestSnapshot, drivers: drivers, changes: changes),
           signalIds.contains(where: isSleepSignalId) {
            boost += 4
        }

        return boost
    }

    private func isHighSeverityNegativeRelationship(_ insight: SQInsight) -> Bool {
        insight.insightClass == .relationship
            && insight.effect == .negative
            && (insight.confidence == .high || insight.rankingScore >= 40)
    }

    private func latestSnapshot(
        from snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date
    ) -> SQInsightFeatureSnapshot? {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return snapshots
            .filter { $0.date <= referenceDate || calendar.isDate($0.date, inSameDayAs: referenceDay) }
            .max { $0.date < $1.date }
    }

    private func hasHabitPressure(
        in snapshot: SQInsightFeatureSnapshot?,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> Bool {
        let habitIds: Set<String> = [
            SQMetricId.alcohol,
            SQMetricId.caffeine,
            SQMetricId.weed,
            SQMetricId.nicotine,
            SQMetricId.porn
        ]

        if drivers.contains(where: { habitIds.contains($0.signalId) && $0.direction == .drag }) {
            return true
        }

        if changes.contains(where: { habitIds.contains($0.signalId) && $0.direction == .worsened }) {
            return true
        }

        guard let snapshot else { return false }
        let alcohol = snapshot.rawSignalValue(for: SQMetricId.alcohol) ?? 0
        let caffeine = snapshot.rawSignalValue(for: SQMetricId.caffeine) ?? 0
        let weed = snapshot.rawSignalValue(for: SQMetricId.weed) ?? 0
        let nicotine = snapshot.rawSignalValue(for: SQMetricId.nicotine) ?? 0

        return alcohol >= 2
            || caffeine >= 240
            || weed >= 2
            || nicotine >= 2
    }

    private func hasTrainingPressure(
        in snapshot: SQInsightFeatureSnapshot?,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> Bool {
        if drivers.contains(where: { (isTrainingSignalId($0.signalId) || $0.signalId == SQMetricId.soreness) && $0.direction == .drag }) {
            return true
        }

        if changes.contains(where: { (isTrainingSignalId($0.signalId) || $0.signalId == SQMetricId.soreness) && $0.direction == .worsened }) {
            return true
        }

        guard let snapshot else { return false }
        let soreness = snapshot.rawSignalValue(for: SQMetricId.soreness) ?? 0
        let difficulty = snapshot.averageWorkoutDifficulty ?? 0
        return soreness >= 6.2 || difficulty >= 7.2
    }

    private func hasStressPressure(
        in snapshot: SQInsightFeatureSnapshot?,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> Bool {
        if drivers.contains(where: { isStressOrMoodPressureSignalId($0.signalId) && $0.direction == .drag }) {
            return true
        }

        if changes.contains(where: { isStressOrMoodPressureSignalId($0.signalId) && $0.direction == .worsened }) {
            return true
        }

        guard let snapshot else { return false }
        let stress = snapshot.rawSignalValue(for: SQMetricId.stress) ?? 0
        let anxiety = snapshot.rawSignalValue(for: SQMetricId.anxiety) ?? 0
        let energy = snapshot.rawSignalValue(for: SQMetricId.energy) ?? 10
        let mood = snapshot.rawSignalValue(for: SQMetricId.mood) ?? 10
        let mentalClarity = snapshot.rawSignalValue(for: SQMetricId.mentalClarity) ?? 10

        return stress >= 6.2
            || anxiety >= 6.0
            || energy <= 5.0
            || mood <= 5.0
            || mentalClarity <= 5.0
    }

    private func hasSleepPressure(
        in snapshot: SQInsightFeatureSnapshot?,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> Bool {
        if drivers.contains(where: { isSleepSignalId($0.signalId) && $0.direction == .drag }) {
            return true
        }

        if changes.contains(where: { isSleepSignalId($0.signalId) && $0.direction == .worsened }) {
            return true
        }

        guard let snapshot else { return false }
        let sleepHours = snapshot.rawSignalValue(for: SQMetricId.sleepHours) ?? 8
        let sleepQuality = snapshot.rawSignalValue(for: SQMetricId.sleepQuality) ?? 8
        return sleepHours < 6.4 || sleepQuality < 5.8
    }

    private func freshnessAdjustedInsights(
        from insights: [SQInsight],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsight] {
        guard surfaceIntent != .today else { return insights }

        if SQAdminConfig.forceInsightFreshnessBadges {
            guard let firstInsight = insights.first else { return insights }
            return insights.map { $0.withIsNew($0.id == firstInsight.id) }
        }

        guard let newFamilyKey = surfacingMemoryStore.newInsightFamilyKey(
            from: insights,
            referenceDate: referenceDate,
            scopeKey: noveltyScopeKey,
            surfaceIntent: surfaceIntent
        ) else {
            return insights
        }

        return insights
            .map { $0.withIsNew($0.familyKey == newFamilyKey) }
            .sorted { lhs, rhs in
                if lhs.isNew != rhs.isNew {
                    return lhs.isNew && !rhs.isNew
                }

                return sortInsightsForDisplay(lhs, rhs)
            }
    }

    private func recordSurfacedTodayItemsIfNeeded(
        insights: [SQInsight],
        changes: [SQInsightChange],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) {
        guard surfaceIntent == .today else { return }
        var familyKeys = [String]()

        if let primaryInsight = insights.first {
            familyKeys.append(primaryInsight.familyKey)
        }

        familyKeys.append(
            contentsOf: insights.compactMap(relationshipFamilyNoveltyKey)
        )

        familyKeys.append(
            contentsOf: insights
                .filter { $0.familyKey.hasPrefix("customMetric.") || $0.familyKey.hasPrefix("customRelationship.") }
                .map(\.familyKey)
        )
        familyKeys.append(
            contentsOf: insights.compactMap { insight in
                guard insight.familyKey.hasPrefix("customMetric."),
                      let metricId = insight.inputSignalId else {
                    return nil
                }

                return customMetricAggregateNoveltyKey(for: metricId)
            }
        )

        if let primaryChange = changes.first {
            familyKeys.append(changeNoveltyKey(for: primaryChange.signalId))
        }

        let uniqueFamilyKeys = Array(Set(familyKeys)).sorted()
        guard !uniqueFamilyKeys.isEmpty else { return }

        surfacingMemoryStore.recordShownFamilyKeys(
            uniqueFamilyKeys,
            referenceDate: referenceDate,
            scopeKey: noveltyScopeKey,
            surfaceIntent: surfaceIntent
        )
    }

    private func changeNoveltyKey(for signalId: String) -> String {
        "change.\(signalId)"
    }

    private func customMetricAggregateNoveltyKey(for metricId: String) -> String {
        "customMetric.\(metricId).any"
    }

    private func relationshipFamilyNoveltyKey(for insight: SQInsight) -> String? {
        guard insight.insightClass == .relationship,
              let inputSignalId = insight.inputSignalId,
              let outputSignalId = insight.outputSignalId else {
            return nil
        }

        return "relationshipFamily.\(inputSignalId)->\(outputSignalId)"
    }

    private var noveltyScopeKey: String {
        if let userId = SQAppState.shared.userState.loggedInUser?.id, !userId.isEmpty {
            return userId
        }

        return "guest"
    }

}
