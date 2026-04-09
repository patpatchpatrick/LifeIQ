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
    private let relevantMetricIds: Set<String> = [
        SQMetricId.alcohol,
        SQMetricId.caffeine,
        SQMetricId.sleepQuality,
        SQMetricId.sleepHours,
        SQMetricId.energy
    ]

    init(
        aggregator: SQInsightsAggregator = .init(),
        evaluators: [SQInsightEvaluating]? = nil
    ) {
        self.aggregator = aggregator
        self.evaluators = evaluators ?? [
            SQAlcoholSleepInsightEvaluator(),
            SQAlcoholEnergyInsightEvaluator(),
            SQCaffeineSleepInsightEvaluator(),
            SQSleepWorkoutPerformanceInsightEvaluator(),
            SQSleepHoursWorkoutPerformanceInsightEvaluator()
        ]
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
        let insights = evaluationResults.compactMap { result -> SQInsight? in
            guard case .insight(let insight) = result else { return nil }
            return insight
        }
        .sorted { lhs, rhs in
                lhs.rankingScore > rhs.rankingScore
            }
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
}
