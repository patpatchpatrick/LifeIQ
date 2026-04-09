//
//  SQSleepWorkoutPerformanceInsightEvaluator.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

struct SQSleepWorkoutPerformanceInsightEvaluator: SQInsightEvaluating {
    let id = "insight.sleep.workout-performance"
    let title = "Sleep -> Workout Performance"
    private let minimumEffectMagnitude = 0.2

    func evaluate(snapshots: [SQInsightDailySnapshot]) -> SQInsightEvaluationResult {
        var higherSleepPerformance = [Double]()
        var lowerSleepPerformance = [Double]()

        for snapshot in snapshots {
            guard let sleepQuality = snapshot.normalizedMetricValue(for: SQMetricId.sleepQuality),
                  let workoutPerformance = snapshot.averageWorkoutPerformance else {
                continue
            }

            if sleepQuality >= 7 {
                higherSleepPerformance.append(workoutPerformance)
            } else if sleepQuality <= 5.5 {
                lowerSleepPerformance.append(workoutPerformance)
            }
        }

        guard higherSleepPerformance.count >= 2, lowerSleepPerformance.count >= 2 else {
            let neededHighSleep = max(0, 2 - higherSleepPerformance.count)
            let neededLowSleep = max(0, 2 - lowerSleepPerformance.count)
            return needsMoreData(
                summary: "Need \(neededHighSleep) more well-slept rated workout day(s) and \(neededLowSleep) more lower-sleep rated workout day(s)."
            )
        }

        guard let higherSleepAverage = average(of: higherSleepPerformance),
              let lowerSleepAverage = average(of: lowerSleepPerformance) else {
            return needsMoreData(summary: "Need more workout days with both sleep quality and workout performance ratings logged.")
        }

        let difference = higherSleepAverage - lowerSleepAverage
        let effectMagnitude = abs(difference)
        guard difference >= minimumEffectMagnitude else {
            return weakSignal(
                summary: "Enough rated workout days were found, but sleep quality is only separating workout performance by \(format(effectMagnitude)) points so far."
            )
        }

        let sampleCount = higherSleepPerformance.count + lowerSleepPerformance.count
        let confidence = insightConfidence(sampleCount: sampleCount, effectMagnitude: effectMagnitude)
        let isSubtle = effectMagnitude < 0.8

        return .insight(SQInsight(
            id: id,
            title: isSubtle ? "Better sleep quality may be slightly helping workouts" : "Better sleep tends to support better workouts",
            summary: "On workout days after better sleep quality, your self-rated performance averaged \(format(effectMagnitude)) points higher.",
            evidenceText: "Workout performance averaged \(format(higherSleepAverage)) after stronger sleep vs \(format(lowerSleepAverage)) after weaker sleep across \(sampleCount) matched workout days.",
            actionText: isSubtle ? "Even small performance gains are worth protecting before key sessions." : "Protect sleep before sessions where performance matters most.",
            driverText: "Better sleep",
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
