//
//  SQInsightsService.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation
import BeastFitnessCore

@MainActor
protocol SQInsightsServicing {
    func dashboardInsights(
        checkIns: [SQDailyCheckInStats],
        workouts: [SQWorkoutSessionable],
        metricDefinitions: [SQMetricDefinition],
        timeRange: AppTimeRange
    ) -> SQInsightsResult
}

@MainActor
final class SQInsightsService: SQInsightsServicing {
    private let featureBuilder: SQInsightFeatureBuilding
    private let driverBuilder: SQInsightDriverBuilding
    private let analysisEngine: SQInsightAnalyzing
    private let relationshipRegistry: SQInsightRelationshipRegistry
    private let minimumAnalyzedDayCount = 10
    private let relevantMetricIds: Set<String>

    init(
        featureBuilder: SQInsightFeatureBuilding = SQInsightFeatureBuilder(),
        driverBuilder: SQInsightDriverBuilding = SQInsightDriverBuilder(),
        analysisEngine: SQInsightAnalyzing = SQInsightAnalysisEngine(),
        relationshipRegistry: SQInsightRelationshipRegistry = .init()
    ) {
        self.featureBuilder = featureBuilder
        self.driverBuilder = driverBuilder
        self.analysisEngine = analysisEngine
        self.relationshipRegistry = relationshipRegistry
        self.relevantMetricIds = relationshipRegistry.relevantSignalIds
    }

    func dashboardInsights(
        checkIns: [SQDailyCheckInStats],
        workouts: [SQWorkoutSessionable],
        metricDefinitions: [SQMetricDefinition],
        timeRange: AppTimeRange
    ) -> SQInsightsResult {
        let snapshots = featureBuilder.makeFeatureSnapshots(
            checkIns: checkIns,
            workouts: workouts,
            metricDefinitions: metricDefinitions
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
            surfaceIntent: timeRange.insightSurfaceIntent
        )
        let drivers = curatedDrivers(
            from: driverBuilder.buildDrivers(
                from: snapshots,
                surfaceIntent: timeRange.insightSurfaceIntent
            ),
            surfaceIntent: timeRange.insightSurfaceIntent
        )
        let generatedInsights = analysisOutput.generatedInsights
        let deduplicatedInsights = deduplicatedInsights(from: generatedInsights)
        let insights = curatedInsights(
            from: deduplicatedInsights,
            surfaceIntent: timeRange.insightSurfaceIntent
        )
        let readinessItems = analysisOutput.readinessItems

        if SQBuildOverrides.verboseLoggingEnabled {
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
        }

        let effectiveAnalyzedDayCount = max(analyzedDayCount, relevantDayCount)
        let state: SQInsightDataState
        if effectiveAnalyzedDayCount < minimumAnalyzedDayCount {
            state = .notEnoughData
        } else {
            state = insights.isEmpty ? .noPatterns : .ready
        }

        if SQBuildOverrides.verboseLoggingEnabled {
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
        let maximumCount: Int
        switch surfaceIntent {
        case .today:
            maximumCount = 3
        case .pastWeek:
            maximumCount = 4
        case .pastYear:
            maximumCount = 4
        }

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

}
