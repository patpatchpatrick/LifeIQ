//
//  SQInsightsService.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation
import BeastFitnessCore

struct SQInsightSurfacingNoveltyState {
    let currentStreak: Int
    let shownCountLast7: Int
    let daysSinceLastShown: Int?

    func penalty(for insight: SQInsight) -> Double {
        var penalty = (Double(currentStreak) * 4) + (Double(max(0, shownCountLast7 - 1)) * 1.5)

        if insight.insightClass == .risk || insight.insightClass == .opportunity {
            penalty *= 0.6
        }

        if insight.confidence == .high {
            penalty *= 0.75
        }

        return penalty
    }
}

protocol SQInsightSurfacingMemoryStoring {
    func noveltyState(
        for familyKey: String,
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightSurfacingNoveltyState

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

    func recordShownFamilyKeys(
        _ familyKeys: [String],
        referenceDate: Date,
        scopeKey: String,
        surfaceIntent: SQInsightSurfaceIntent
    ) {}
}

final class SQPersistedInsightSurfacingMemoryStore: SQInsightSurfacingMemoryStoring {
    private struct Record: Codable {
        var shownDayKeys: [String]
    }

    private static let storageKey = "insights.today.surfacing-memory.v1"

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

        let record = allRecords()[scopeKey]?[familyKey]
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

        var records = allRecords()
        var scopeRecords = records[scopeKey] ?? [:]

        for familyKey in Set(familyKeys) {
            var record = scopeRecords[familyKey] ?? .init(shownDayKeys: [])

            if !record.shownDayKeys.contains(todayKey) {
                record.shownDayKeys.append(todayKey)
            }

            record.shownDayKeys = Array(
                Set(record.shownDayKeys.filter { $0 >= minimumDayKey })
            )
            .sorted()
            scopeRecords[familyKey] = record
        }

        records[scopeKey] = scopeRecords
        save(records)
    }

    private func allRecords() -> [String: [String: Record]] {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: [String: Record]].self, from: data)) ?? [:]
    }

    private func save(_ records: [String: [String: Record]]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
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
            metricDefinitions: input.metricDefinitions
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
        let insights = curatedInsights(
            from: noveltyAdjustedInsights,
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
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsight] {
        switch surfaceIntent {
        case .today:
            return curatedTodayInsights(from: deduplicatedInsights)
        case .pastWeek:
            return curatedWeeklyInsights(from: deduplicatedInsights)
        case .pastYear:
            return curatedYearlyInsights(from: deduplicatedInsights)
        }
    }

    // `Today` should read like a briefing: one current-state card, one recent-change card,
    // and then the strongest remaining pattern instead of a flat list of similar cards.
    private func curatedTodayInsights(from deduplicatedInsights: [SQInsight]) -> [SQInsight] {
        curateInsights(
            from: deduplicatedInsights,
            preferredBuckets: [
                [.risk, .opportunity],
                [.followUp, .trend, .baselineChange],
                [.relationship]
            ],
            maximumCount: 4
        )
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
