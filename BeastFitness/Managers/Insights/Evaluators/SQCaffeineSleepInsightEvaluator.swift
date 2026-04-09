//
//  SQCaffeineSleepInsightEvaluator.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

struct SQCaffeineSleepInsightEvaluator: SQInsightEvaluating {
    let id = "insight.caffeine.sleep"
    let title = "Caffeine -> Sleep"
    private let lowCaffeineUpperBound = 3.0
    private let minimumEffectMagnitude = 0.15

    func evaluate(snapshots: [SQInsightDailySnapshot]) -> SQInsightEvaluationResult {
        guard snapshots.count >= 2 else {
            return needsMoreData(summary: "Need at least 2 sequential logged days to compare caffeine to next-day sleep.")
        }

        var sleepAfterLowerCaffeine = [Double]()
        var sleepAfterHigherCaffeine = [Double]()
        let calendar = Calendar.current

        for index in 0..<(snapshots.count - 1) {
            let current = snapshots[index]
            let next = snapshots[index + 1]
            let dayDelta = calendar.dateComponents([.day], from: current.date, to: next.date).day

            guard dayDelta == 1 else { continue }

            guard let caffeine = current.rawMetricValue(for: SQMetricId.caffeine),
                  let nextSleepQuality = next.normalizedMetricValue(for: SQMetricId.sleepQuality) else {
                continue
            }

            if caffeine <= lowCaffeineUpperBound {
                sleepAfterLowerCaffeine.append(nextSleepQuality)
            } else {
                sleepAfterHigherCaffeine.append(nextSleepQuality)
            }
        }

        guard sleepAfterLowerCaffeine.count >= 2, sleepAfterHigherCaffeine.count >= 2 else {
            let neededLowerCaffeine = max(0, 2 - sleepAfterLowerCaffeine.count)
            let neededHigherCaffeine = max(0, 2 - sleepAfterHigherCaffeine.count)
            return needsMoreData(
                summary: "Need \(neededLowerCaffeine) more lower-caffeine evening(s) (0-3) and \(neededHigherCaffeine) more higher-caffeine evening(s) (4+) with next-day sleep logged."
            )
        }

        guard let lowerCaffeineAverage = average(of: sleepAfterLowerCaffeine),
              let higherCaffeineAverage = average(of: sleepAfterHigherCaffeine) else {
            return needsMoreData(summary: "Need more matched sleep-quality entries across lower- and higher-caffeine evenings.")
        }

        let difference = higherCaffeineAverage - lowerCaffeineAverage
        let effectMagnitude = abs(difference)
        guard difference <= (-minimumEffectMagnitude) else {
            return weakSignal(
                summary: "Enough matched days were found, but higher caffeine is only linked to a \(format(effectMagnitude)) point sleep-quality drop so far."
            )
        }

        let sampleCount = sleepAfterLowerCaffeine.count + sleepAfterHigherCaffeine.count
        let confidence = insightConfidence(sampleCount: sampleCount, effectMagnitude: effectMagnitude)
        let isSubtle = effectMagnitude < 0.8

        return .insight(SQInsight(
            id: id,
            title: isSubtle ? "Higher caffeine may be slightly lowering sleep" : "Higher caffeine is showing up in your sleep quality",
            summary: "Higher-caffeine evenings are associated with \(format(effectMagnitude)) points lower next-day sleep quality.",
            evidenceText: "Next-day sleep quality averaged \(format(higherCaffeineAverage)) after higher-caffeine evenings (4+) vs \(format(lowerCaffeineAverage)) after lower-caffeine evenings (0-3) across \(sampleCount) matched days.",
            actionText: isSubtle ? "Even a small sleep hit can accumulate. Try lowering caffeine on nights when recovery matters." : "Try pulling caffeine earlier or lowering it on nights when sleep quality matters most.",
            driverText: "Higher caffeine",
            outcomeText: "Lower sleep",
            deltaText: "-\(format(effectMagnitude)) pts",
            category: .sleep,
            confidence: confidence,
            effect: .negative,
            sampleCount: sampleCount,
            rankingScore: insightRankingScore(
                sampleCount: sampleCount,
                effectMagnitude: effectMagnitude,
                confidence: confidence
            )
        ))
    }
}
