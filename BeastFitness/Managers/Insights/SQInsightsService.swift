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
    private let analysisEngine: SQInsightAnalyzing
    private let relationshipRegistry: SQInsightRelationshipRegistry
    private let minimumAnalyzedDayCount = 10
    private let relevantMetricIds: Set<String>

    init(
        featureBuilder: SQInsightFeatureBuilding = SQInsightFeatureBuilder(),
        analysisEngine: SQInsightAnalyzing = SQInsightAnalysisEngine(),
        relationshipRegistry: SQInsightRelationshipRegistry = .init()
    ) {
        self.featureBuilder = featureBuilder
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
        let generatedInsights = analysisOutput.generatedInsights
        let insights = deduplicatedInsights(from: generatedInsights)
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

}
