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
        metricDefinitions: [SQMetricDefinition]
    ) -> SQInsightsResult
}

@MainActor
final class SQInsightsService: SQInsightsServicing {
    private let aggregator: SQInsightsAggregator
    private let evaluators: [SQInsightEvaluating]
    private let minimumAnalyzedDayCount = 10
    private let relevantMetricIds: Set<String>

    init(
        aggregator: SQInsightsAggregator = .init(),
        evaluators: [SQInsightEvaluating]? = nil
    ) {
        self.aggregator = aggregator
        let metricComparisonConfigs = Self.defaultMetricComparisonConfigs
        let defaultEvaluators: [SQInsightEvaluating] =
            metricComparisonConfigs.map { SQMetricComparisonInsightEvaluator(config: $0) }

        self.evaluators = evaluators ?? defaultEvaluators
        self.relevantMetricIds = Set(
            metricComparisonConfigs.flatMap {
                [$0.sourceMetricId, $0.outcomeMetricId] +
                [$0.outcomeDayControlMetricId].compactMap { $0 }
            } +
            [SQMetricId.sleepHours, SQInsightAnalysisMetricId.workoutPerformance]
        )
    }

    func dashboardInsights(
        checkIns: [SQDailyCheckInStats],
        workouts: [SQWorkoutSessionable],
        metricDefinitions: [SQMetricDefinition]
    ) -> SQInsightsResult {
        let snapshots = aggregator.makeSnapshots(
            checkIns: checkIns,
            workouts: workouts,
            metricDefinitions: metricDefinitions
        )

        let analyzedDayCount = snapshots.filter { snapshot in
            !snapshot.rawMetricValues.isEmpty || snapshot.hasWorkout
        }.count

        let relevantDayCount = snapshots.filter { snapshot in
            snapshot.hasWorkout ||
            relevantMetricIds.contains(where: { snapshot.rawMetricValue(for: $0) != nil })
        }.count

        let evaluationResults = evaluators.map { $0.evaluate(snapshots: snapshots) }
        let generatedInsights = evaluationResults.compactMap { result -> SQInsight? in
            guard case .insight(let insight) = result else { return nil }
            return insight
        }
        let insights = deduplicatedInsights(from: generatedInsights)
        let readinessItems = evaluationResults.compactMap { result -> SQInsightReadinessItem? in
            guard case .readiness(let item) = result else { return nil }
            return item
        }

        for readiness in readinessItems {
            SQLogger.shared.log(
                "Insight readiness [\(readiness.title)]: \(readiness.summary)",
                .debug,
                context: .dashboard
            )
        }

        for insight in generatedInsights.sorted(by: { sortInsightsForDisplay($0, $1) }) {
            SQLogger.shared.log(
                "Generated insight [\(insight.title)] family=\(insight.familyKey) priority=\(insight.variantPriority) sample=\(insight.sampleCount) delta=\(insight.deltaText) confidence=\(insight.confidence.badgeTitle)",
                .debug,
                context: .dashboard
            )
        }

        let effectiveAnalyzedDayCount = max(analyzedDayCount, relevantDayCount)
        let state: SQInsightDataState
        if effectiveAnalyzedDayCount < minimumAnalyzedDayCount {
            state = .notEnoughData
        } else {
            state = insights.isEmpty ? .noPatterns : .ready
        }

        SQLogger.shared.log(
            "Insights dashboard result: state=\(debugTitle(for: state)), analyzedDays=\(effectiveAnalyzedDayCount), insights=\(insights.count), readiness=\(readinessItems.count)",
            .debug,
            context: .dashboard
        )

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

    private static let defaultMetricComparisonConfigs: [SQMetricComparisonInsightConfig] = [
        viceInsightConfigSet(
            idBase: "insight.alcohol.sleep",
            sourceMetricId: SQMetricId.alcohol,
            sourceTitle: "Alcohol",
            outcomeMetricId: SQMetricId.sleepQuality,
            outcomeTitle: "Sleep Quality",
            category: .sleep,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower sleep",
            strongActionText: "Try cutting back on alcohol before recovery-focused or training-heavy days.",
            subtleActionText: "Even a small sleep dip can add up. Keep alcohol lighter before recovery-focused days."
        ),
        viceInsightConfigSet(
            idBase: "insight.alcohol.energy",
            sourceMetricId: SQMetricId.alcohol,
            sourceTitle: "Alcohol",
            outcomeMetricId: SQMetricId.energy,
            outcomeTitle: "Energy",
            category: .recovery,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower energy",
            strongActionText: "If energy matters the next day, keep alcohol lower on the nights before.",
            subtleActionText: "Even a small energy drop can matter on training days. Keep alcohol lighter the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.alcohol.mood",
            sourceMetricId: SQMetricId.alcohol,
            sourceTitle: "Alcohol",
            outcomeMetricId: SQMetricId.mood,
            outcomeTitle: "Mood",
            category: .habits,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower mood",
            strongActionText: "If mood matters the next day, keep alcohol lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.alcohol.motivation",
            sourceMetricId: SQMetricId.alcohol,
            sourceTitle: "Alcohol",
            outcomeMetricId: SQMetricId.motivation,
            outcomeTitle: "Motivation",
            category: .habits,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower motivation",
            strongActionText: "If motivation matters the next day, keep alcohol lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.caffeine.sleep",
            sourceMetricId: SQMetricId.caffeine,
            sourceTitle: "Caffeine",
            outcomeMetricId: SQMetricId.sleepQuality,
            outcomeTitle: "Sleep Quality",
            category: .sleep,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 3,
            highBucketLowerBound: 4,
            driverText: "Higher caffeine",
            outcomeText: "Lower sleep",
            strongActionText: "Try pulling caffeine earlier or lowering it on nights when sleep quality matters most.",
            subtleActionText: "Even a small sleep hit can accumulate. Try lowering caffeine on recovery-focused nights."
        ),
        viceInsightConfigSet(
            idBase: "insight.caffeine.energy",
            sourceMetricId: SQMetricId.caffeine,
            sourceTitle: "Caffeine",
            outcomeMetricId: SQMetricId.energy,
            outcomeTitle: "Energy",
            category: .recovery,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 3,
            highBucketLowerBound: 4,
            driverText: "Higher caffeine",
            outcomeText: "Lower energy",
            strongActionText: "If steadier next-day energy matters, keep caffeine lower later in the day."
        ),
        viceInsightConfigSet(
            idBase: "insight.nicotine.sleep",
            sourceMetricId: SQMetricId.nicotine,
            sourceTitle: "Nicotine",
            outcomeMetricId: SQMetricId.sleepQuality,
            outcomeTitle: "Sleep Quality",
            category: .sleep,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower sleep",
            strongActionText: "If sleep matters the next day, keep nicotine lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.nicotine.energy",
            sourceMetricId: SQMetricId.nicotine,
            sourceTitle: "Nicotine",
            outcomeMetricId: SQMetricId.energy,
            outcomeTitle: "Energy",
            category: .recovery,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower energy",
            strongActionText: "If energy matters the next day, keep nicotine lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.nicotine.mood",
            sourceMetricId: SQMetricId.nicotine,
            sourceTitle: "Nicotine",
            outcomeMetricId: SQMetricId.mood,
            outcomeTitle: "Mood",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower mood",
            strongActionText: "If mood matters the next day, keep nicotine lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.nicotine.motivation",
            sourceMetricId: SQMetricId.nicotine,
            sourceTitle: "Nicotine",
            outcomeMetricId: SQMetricId.motivation,
            outcomeTitle: "Motivation",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower motivation",
            strongActionText: "If motivation matters the next day, keep nicotine lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.weed.sleep",
            sourceMetricId: SQMetricId.weed,
            sourceTitle: "Weed",
            outcomeMetricId: SQMetricId.sleepQuality,
            outcomeTitle: "Sleep Quality",
            category: .sleep,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower sleep",
            strongActionText: "If sleep quality matters the next day, keep weed lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.weed.energy",
            sourceMetricId: SQMetricId.weed,
            sourceTitle: "Weed",
            outcomeMetricId: SQMetricId.energy,
            outcomeTitle: "Energy",
            category: .recovery,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower energy",
            strongActionText: "If energy matters the next day, keep weed lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.weed.mood",
            sourceMetricId: SQMetricId.weed,
            sourceTitle: "Weed",
            outcomeMetricId: SQMetricId.mood,
            outcomeTitle: "Mood",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower mood",
            strongActionText: "If mood matters the next day, keep weed lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.weed.motivation",
            sourceMetricId: SQMetricId.weed,
            sourceTitle: "Weed",
            outcomeMetricId: SQMetricId.motivation,
            outcomeTitle: "Motivation",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower motivation",
            strongActionText: "If motivation matters the next day, keep weed lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.porn.mood",
            sourceMetricId: SQMetricId.porn,
            sourceTitle: "Porn",
            outcomeMetricId: SQMetricId.mood,
            outcomeTitle: "Mood",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher porn",
            outcomeText: "Lower mood",
            strongActionText: "If mood matters the next day, keep porn use lower the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.porn.motivation",
            sourceMetricId: SQMetricId.porn,
            sourceTitle: "Porn",
            outcomeMetricId: SQMetricId.motivation,
            outcomeTitle: "Motivation",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher porn",
            outcomeText: "Lower motivation",
            strongActionText: "If motivation matters the next day, keep porn use lower the night before."
        ),
        workoutPerformanceConfig(
            id: "insight.sleep-quality.workout-performance",
            sourceMetricId: SQMetricId.sleepQuality,
            sourceTitle: "Sleep Quality",
            driverText: "Better sleep quality",
            lowBucketUpperBound: 5.5,
            highBucketLowerBound: 7,
            strongActionText: "Protect sleep quality before sessions where performance matters most.",
            subtleActionText: "Even small performance gains are worth protecting before key sessions."
        ),
        workoutPerformanceConfig(
            id: "insight.sleep-hours.workout-performance",
            sourceMetricId: SQMetricId.sleepHours,
            sourceTitle: "Sleep Hours",
            driverText: "More sleep",
            lowBucketUpperBound: 6.5,
            highBucketLowerBound: 7.5,
            strongActionText: "Aim for more sleep before sessions where performance matters most.",
            subtleActionText: "Even a modest sleep edge can help on important training days."
        ),
        viceInsightConfigSet(
            idBase: "insight.alcohol.workout-performance",
            sourceMetricId: SQMetricId.alcohol,
            sourceTitle: "Alcohol",
            outcomeMetricId: SQInsightAnalysisMetricId.workoutPerformance,
            outcomeTitle: "Workout Performance",
            category: .training,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters the next day, keep alcohol lower the night before.",
            subtleActionText: "Even a small performance dip can matter on important training days. Keep alcohol lighter the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.caffeine.workout-performance",
            sourceMetricId: SQMetricId.caffeine,
            sourceTitle: "Caffeine",
            outcomeMetricId: SQInsightAnalysisMetricId.workoutPerformance,
            outcomeTitle: "Workout Performance",
            category: .training,
            lowBucketUpperBound: 3,
            highBucketLowerBound: 4,
            driverText: "Higher caffeine",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters, keep caffeine at the level that supports better sessions."
        ),
        viceInsightConfigSet(
            idBase: "insight.nicotine.workout-performance",
            sourceMetricId: SQMetricId.nicotine,
            sourceTitle: "Nicotine",
            outcomeMetricId: SQInsightAnalysisMetricId.workoutPerformance,
            outcomeTitle: "Workout Performance",
            category: .training,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters, keep nicotine lower on training days and the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.weed.workout-performance",
            sourceMetricId: SQMetricId.weed,
            sourceTitle: "Weed",
            outcomeMetricId: SQInsightAnalysisMetricId.workoutPerformance,
            outcomeTitle: "Workout Performance",
            category: .training,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters, keep weed lower on training days and the night before."
        ),
        viceInsightConfigSet(
            idBase: "insight.porn.workout-performance",
            sourceMetricId: SQMetricId.porn,
            sourceTitle: "Porn",
            outcomeMetricId: SQInsightAnalysisMetricId.workoutPerformance,
            outcomeTitle: "Workout Performance",
            category: .training,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher porn",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters, keep porn use lower on training days and the night before."
        )
    ]
    .flatMap { $0 }

    private static func viceInsightConfigSet(
        idBase: String,
        sourceMetricId: String,
        sourceTitle: String,
        outcomeMetricId: String,
        outcomeTitle: String,
        category: SQInsightCategory,
        bucketUnitName: String = "days",
        lowBucketUpperBound: Double,
        highBucketLowerBound: Double,
        driverText: String,
        outcomeText: String,
        strongActionText: String,
        subtleActionText: String? = nil
    ) -> [SQMetricComparisonInsightConfig] {
        let familyKey = "\(sourceMetricId)->\(outcomeMetricId)"

        return [
            .init(
                id: "\(idBase).carryover-clean",
                familyKey: familyKey,
                variantPriority: 0,
                sourceMetricId: sourceMetricId,
                sourceTitle: sourceTitle,
                outcomeMetricId: outcomeMetricId,
                outcomeTitle: outcomeTitle,
                category: category,
                timing: .nextDay,
                outcomeDayControlMetricId: sourceMetricId,
                outcomeDayControlTitle: sourceTitle,
                outcomeDayControlRequirement: .absent,
                lowBucketUpperBound: lowBucketUpperBound,
                highBucketLowerBound: highBucketLowerBound,
                bucketUnitName: bucketUnitName,
                minimumBucketSampleCount: 2,
                minimumEffectMagnitude: 0.15,
                expectedEffect: .negative,
                driverText: driverText,
                outcomeText: outcomeText,
                strongActionText: strongActionText,
                subtleActionText: subtleActionText
            ),
            .init(
                id: "\(idBase).carryover-with-reuse",
                familyKey: familyKey,
                variantPriority: 1,
                sourceMetricId: sourceMetricId,
                sourceTitle: sourceTitle,
                outcomeMetricId: outcomeMetricId,
                outcomeTitle: outcomeTitle,
                category: category,
                timing: .nextDay,
                outcomeDayControlMetricId: sourceMetricId,
                outcomeDayControlTitle: sourceTitle,
                outcomeDayControlRequirement: .present,
                lowBucketUpperBound: lowBucketUpperBound,
                highBucketLowerBound: highBucketLowerBound,
                bucketUnitName: bucketUnitName,
                minimumBucketSampleCount: 2,
                minimumEffectMagnitude: 0.15,
                expectedEffect: .negative,
                driverText: driverText,
                outcomeText: outcomeText,
                strongActionText: strongActionText,
                subtleActionText: subtleActionText
            ),
            .init(
                id: "\(idBase).same-day",
                familyKey: familyKey,
                variantPriority: 2,
                sourceMetricId: sourceMetricId,
                sourceTitle: sourceTitle,
                outcomeMetricId: outcomeMetricId,
                outcomeTitle: outcomeTitle,
                category: category,
                timing: .sameDay,
                lowBucketUpperBound: lowBucketUpperBound,
                highBucketLowerBound: highBucketLowerBound,
                bucketUnitName: bucketUnitName,
                minimumBucketSampleCount: 2,
                minimumEffectMagnitude: 0.15,
                expectedEffect: .negative,
                driverText: driverText,
                outcomeText: outcomeText,
                strongActionText: strongActionText,
                subtleActionText: subtleActionText
            )
        ]
    }

    private static func workoutPerformanceConfig(
        id: String,
        sourceMetricId: String,
        sourceTitle: String,
        driverText: String,
        lowBucketUpperBound: Double,
        highBucketLowerBound: Double,
        strongActionText: String,
        subtleActionText: String? = nil
    ) -> [SQMetricComparisonInsightConfig] {
        [
            .init(
                id: id,
                familyKey: "\(sourceMetricId)->\(SQInsightAnalysisMetricId.workoutPerformance)",
                variantPriority: 0,
                sourceMetricId: sourceMetricId,
                sourceTitle: sourceTitle,
                outcomeMetricId: SQInsightAnalysisMetricId.workoutPerformance,
                outcomeTitle: "Workout Performance",
                category: .training,
                timing: .sameDay,
                lowBucketUpperBound: lowBucketUpperBound,
                highBucketLowerBound: highBucketLowerBound,
                bucketUnitName: "workout days",
                minimumBucketSampleCount: 2,
                minimumEffectMagnitude: 0.15,
                expectedEffect: .positive,
                driverText: driverText,
                outcomeText: "Better workouts",
                strongActionText: strongActionText,
                subtleActionText: subtleActionText
            )
        ]
    }

}
