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
            restingHeartRateSummaries: input.restingHeartRateSummaries
        )

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
            surfaceIntent: input.timeRange.insightSurfaceIntent
        )
        let drivers = curatedDrivers(
            from: driverBuilder.buildDrivers(
                from: snapshots,
                surfaceIntent: input.timeRange.insightSurfaceIntent
            ),
            surfaceIntent: input.timeRange.insightSurfaceIntent
        )
        let changes = curatedChanges(
            from: changeBuilder.buildChanges(
                from: snapshots,
                surfaceIntent: input.timeRange.insightSurfaceIntent
            ),
            surfaceIntent: input.timeRange.insightSurfaceIntent,
            selectedDrivers: drivers
        )
        let generatedInsights = analysisOutput.generatedInsights
        let deduplicatedInsights = deduplicatedInsights(from: generatedInsights)
        let noveltyAdjustedInsights = noveltyAdjustedInsights(
            from: deduplicatedInsights,
            referenceDate: input.referenceDate,
            surfaceIntent: input.timeRange.insightSurfaceIntent
        )
        let curatedInsights = curatedInsights(
            from: noveltyAdjustedInsights,
            surfaceIntent: input.timeRange.insightSurfaceIntent,
            drivers: drivers,
            changes: changes
        )
        let insights = freshnessAdjustedInsights(
            from: curatedInsights,
            referenceDate: input.referenceDate,
            surfaceIntent: input.timeRange.insightSurfaceIntent
        )
        let actions = curatedActions(
            from: actionBuilder.buildActions(
                insights: insights,
                drivers: drivers,
                changes: changes,
                surfaceIntent: input.timeRange.insightSurfaceIntent
            ),
            surfaceIntent: input.timeRange.insightSurfaceIntent
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
            recordSurfacedInsightsIfNeeded(
                insights,
                referenceDate: input.referenceDate,
                surfaceIntent: input.timeRange.insightSurfaceIntent
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
        surfaceIntent: SQInsightSurfaceIntent,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> [SQInsight] {
        switch surfaceIntent {
        case .today:
            return curatedTodayInsights(
                from: deduplicatedInsights,
                drivers: drivers,
                changes: changes
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
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> [SQInsight] {
        let heroInsight = todayHeroInsight(
            from: deduplicatedInsights,
            drivers: drivers,
            changes: changes
        )

        let remainingInsights = deduplicatedInsights.filter { $0.id != heroInsight?.id }
        let supportingInsights = curateInsights(
            from: remainingInsights,
            preferredBuckets: [
                [.risk, .opportunity],
                [.followUp, .trend, .baselineChange],
                [.relationship]
            ],
            maximumCount: heroInsight == nil ? 4 : 3
        )

        if let heroInsight {
            return [heroInsight] + supportingInsights
        }

        return supportingInsights
    }

    private func todayHeroInsight(
        from insights: [SQInsight],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> SQInsight? {
        if let stateHeroInsight = stateDrivenTodayHeroInsight(
            from: drivers,
            changes: changes,
            insights: insights
        ) {
            return stateHeroInsight
        }

        let filteredInsights: [SQInsight]
        let hasAlternativeCandidate = insights.contains { !isPositiveCleanupHabitHeroCandidate($0) }

        if hasAlternativeCandidate {
            filteredInsights = insights.filter { !isPositiveCleanupHabitHeroCandidate($0) }
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
        insights: [SQInsight]
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
        let title = stateHeroTitle(
            direction: selectedDirection,
            primaryTheme: primaryTheme,
            secondaryTheme: secondaryTheme
        )
        let summary = stateHeroSummary(
            title: title,
            drivers: selectedDrivers
        )

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
            actionText: selectedDirection == .supportive ? "Good day to push training." : "Protect recovery today.",
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
                    score += hasStatePressure ? 6 : 1
                } else {
                    score -= 10
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
                score += hasStatePressure ? 4 : 0
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
            case .trend, .baselineChange, .followUp, .relationship, .risk:
                allowedClass = true
            case .opportunity, .populationBenchmark, .cohort:
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

        if bestCandidate.rankingScore >= dragStrength + 5 || relatedWorseningChange {
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
                return "Stress and anxiety are driving the day"
            case (.supportive, "sleep", "recovery"), (.supportive, "recovery", "sleep"):
                return "Sleep and recovery are helping today"
            default:
                let verb = direction == .supportive ? "are helping today" : "are under pressure today"
                return "\(primaryTheme.displayTitle) and \(secondaryTheme.displayTitle.lowercased()) \(verb)"
            }
        }

        switch (direction, primaryTheme.key) {
        case (.supportive, "stress"):
            return "Stress looks manageable today"
        case (.supportive, "anxiety"):
            return "Anxiety looks manageable today"
        case (.supportive, "soreness"):
            return "Soreness looks manageable today"
        case (.supportive, "strain"):
            return "Training load looks manageable today"
        case (.drag, "stress"):
            return "Stress is weighing on the day"
        case (.drag, "anxiety"):
            return "Anxiety is weighing on the day"
        case (.drag, "strain"):
            return "Training load is catching up with you"
        case (.drag, "recovery"):
            return "Recovery is under pressure today"
        default:
            let verb = direction == .supportive ? "is helping today" : "is under pressure today"
            return "\(primaryTheme.displayTitle) \(verb)"
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
            return direction == .supportive ? .keepConsistent : .protectRecovery
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
            SQInsightAnalysisMetricId.workoutPerformance,
            SQInsightAnalysisMetricId.workoutDifficulty
        ]

        let preferredDrivers = drivers.filter { preferredSignalIds.contains($0.signalId) }
        return Array(preferredDrivers.prefix(3))
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
        let preferredSignalIds: Set<String> = [
            SQMetricId.alcohol,
            SQMetricId.caffeine,
            SQMetricId.weed,
            SQMetricId.nicotine,
            SQMetricId.porn,
            SQInsightAnalysisMetricId.workoutPerformance,
            SQInsightAnalysisMetricId.workoutDifficulty
        ]

        let preferredNonOverlapping = changes.filter {
            preferredSignalIds.contains($0.signalId) && !driverSignalIds.contains($0.signalId)
        }
        let preferredOverlapping = changes.filter {
            preferredSignalIds.contains($0.signalId) && driverSignalIds.contains($0.signalId)
        }
        let fallbackNonOverlapping = changes.filter {
            !preferredSignalIds.contains($0.signalId) && !driverSignalIds.contains($0.signalId)
        }
        let fallbackOverlapping = changes.filter {
            !preferredSignalIds.contains($0.signalId) && driverSignalIds.contains($0.signalId)
        }

        let prioritized = preferredNonOverlapping + preferredOverlapping
        if prioritized.count >= 2 {
            return Array(prioritized.prefix(2))
        }

        return Array((prioritized + fallbackNonOverlapping + fallbackOverlapping).prefix(2))
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

    private func recordSurfacedInsightsIfNeeded(
        _ insights: [SQInsight],
        referenceDate: Date,
        surfaceIntent: SQInsightSurfaceIntent
    ) {
        guard surfaceIntent == .today else { return }
        guard let primaryInsight = insights.first else { return }

        surfacingMemoryStore.recordShownFamilyKeys(
            [primaryInsight.familyKey],
            referenceDate: referenceDate,
            scopeKey: noveltyScopeKey,
            surfaceIntent: surfaceIntent
        )
    }

    private var noveltyScopeKey: String {
        if let userId = SQAppState.shared.userState.loggedInUser?.id, !userId.isEmpty {
            return userId
        }

        return "guest"
    }

}
