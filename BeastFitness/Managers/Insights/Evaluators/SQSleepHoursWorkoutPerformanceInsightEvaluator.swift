//
//  SQSleepHoursWorkoutPerformanceInsightEvaluator.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

struct SQSleepHoursWorkoutPerformanceInsightEvaluator: SQInsightEvaluating {
    let id = "insight.sleep-hours.workout-performance"
    let title = "Sleep Hours -> Workout Performance"
    private let lowerSleepHoursUpperBound = 6.5
    private let higherSleepHoursLowerBound = 7.5
    private let minimumEffectMagnitude = 0.2

    func evaluate(snapshots: [SQInsightDailySnapshot]) -> SQInsightEvaluationResult {
        var higherSleepPerformance = [Double]()
        var lowerSleepPerformance = [Double]()

        for snapshot in snapshots {
            guard let sleepHours = snapshot.rawMetricValue(for: SQMetricId.sleepHours),
                  let workoutPerformance = snapshot.averageWorkoutPerformance else {
                continue
            }

            if sleepHours >= higherSleepHoursLowerBound {
                higherSleepPerformance.append(workoutPerformance)
            } else if sleepHours <= lowerSleepHoursUpperBound {
                lowerSleepPerformance.append(workoutPerformance)
            }
        }

        guard higherSleepPerformance.count >= 2, lowerSleepPerformance.count >= 2 else {
            let neededHighSleep = max(0, 2 - higherSleepPerformance.count)
            let neededLowSleep = max(0, 2 - lowerSleepPerformance.count)
            return needsMoreData(
                summary: "Need \(neededHighSleep) more higher-sleep workout day(s) (7.5+ hours) and \(neededLowSleep) more lower-sleep workout day(s) (6.5 hours or less)."
            )
        }

        guard let higherSleepAverage = average(of: higherSleepPerformance),
              let lowerSleepAverage = average(of: lowerSleepPerformance) else {
            return needsMoreData(summary: "Need more workout days with both sleep hours and workout performance ratings logged.")
        }

        let difference = higherSleepAverage - lowerSleepAverage
        let effectMagnitude = abs(difference)
        guard difference >= minimumEffectMagnitude else {
            return weakSignal(
                summary: "Enough rated workout days were found, but sleep hours are only separating workout performance by \(format(effectMagnitude)) points so far."
            )
        }

        let sampleCount = higherSleepPerformance.count + lowerSleepPerformance.count
        let confidence = insightConfidence(sampleCount: sampleCount, effectMagnitude: effectMagnitude)
        let isSubtle = effectMagnitude < 0.8

        return .insight(SQInsight(
            id: id,
            title: isSubtle ? "More sleep may be slightly helping workouts" : "More sleep tends to support better workouts",
            summary: "On workout days after more sleep, your self-rated performance averaged \(format(effectMagnitude)) points higher.",
            evidenceText: "Workout performance averaged \(format(higherSleepAverage)) after 7.5+ hours of sleep vs \(format(lowerSleepAverage)) after 6.5 hours or less across \(sampleCount) matched workout days.",
            actionText: isSubtle ? "Even a modest sleep edge can help on important training days." : "Aim for more sleep before sessions where performance matters most.",
            driverText: "More sleep",
            outcomeText: "Better workouts",
            deltaText: "+\(format(effectMagnitude)) pts",
            category: .training,
            confidence: confidence,
            effect: .positive,
            sampleCount: sampleCount,
            rankingScore: insightRankingScore(
                sampleCount: sampleCount,
                effectMagnitude: effectMagnitude,
                confidence: confidence
            )
        ))
    }
}
