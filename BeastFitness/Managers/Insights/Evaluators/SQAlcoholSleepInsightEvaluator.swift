//
//  SQAlcoholSleepInsightEvaluator.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

struct SQAlcoholSleepInsightEvaluator: SQInsightEvaluating {
    let id = "insight.alcohol.sleep"
    let title = "Alcohol -> Sleep"
    private let lowAlcoholUpperBound = 2.0
    private let minimumEffectMagnitude = 0.15

    func evaluate(snapshots: [SQInsightDailySnapshot]) -> SQInsightEvaluationResult {
        guard snapshots.count >= 2 else {
            return needsMoreData(summary: "Need at least 2 sequential logged days to compare alcohol to next-day sleep.")
        }

        var sleepAfterLowerAlcohol = [Double]()
        var sleepAfterHigherAlcohol = [Double]()
        let calendar = Calendar.current

        for index in 0..<(snapshots.count - 1) {
            let current = snapshots[index]
            let next = snapshots[index + 1]
            let dayDelta = calendar.dateComponents([.day], from: current.date, to: next.date).day

            guard dayDelta == 1 else { continue }

            guard let alcohol = current.rawMetricValue(for: SQMetricId.alcohol),
                  let nextSleepQuality = next.normalizedMetricValue(for: SQMetricId.sleepQuality) else {
                continue
            }

            if alcohol <= lowAlcoholUpperBound {
                sleepAfterLowerAlcohol.append(nextSleepQuality)
            } else {
                sleepAfterHigherAlcohol.append(nextSleepQuality)
            }
        }

        guard sleepAfterLowerAlcohol.count >= 2, sleepAfterHigherAlcohol.count >= 2 else {
            let neededLowerAlcohol = max(0, 2 - sleepAfterLowerAlcohol.count)
            let neededHigherAlcohol = max(0, 2 - sleepAfterHigherAlcohol.count)
            return needsMoreData(
                summary: "Need \(neededLowerAlcohol) more lower-alcohol evening(s) (0-2) and \(neededHigherAlcohol) more higher-alcohol evening(s) (3+) with next-day sleep logged."
            )
        }

        guard let lowerAlcoholAverage = average(of: sleepAfterLowerAlcohol),
              let higherAlcoholAverage = average(of: sleepAfterHigherAlcohol) else {
            return needsMoreData(summary: "Need more matched sleep-quality entries across lower- and higher-alcohol evenings.")
        }

        let difference = higherAlcoholAverage - lowerAlcoholAverage
        let effectMagnitude = abs(difference)
        guard difference <= (-minimumEffectMagnitude) else {
            return weakSignal(
                summary: "Enough matched days were found, but higher alcohol is only linked to a \(format(effectMagnitude)) point sleep-quality drop so far."
            )
        }

        let sampleCount = sleepAfterLowerAlcohol.count + sleepAfterHigherAlcohol.count
        let confidence = insightConfidence(sampleCount: sampleCount, effectMagnitude: effectMagnitude)
        let isSubtle = effectMagnitude < 0.8

        return .insight(SQInsight(
            id: id,
            title: isSubtle ? "Higher alcohol may be slightly lowering sleep" : "Higher alcohol is dragging your next-day sleep",
            summary: "Higher-alcohol evenings are associated with \(format(effectMagnitude)) points lower next-day sleep quality.",
            evidenceText: "Next-day sleep quality averaged \(format(higherAlcoholAverage)) after higher-alcohol evenings (3+) vs \(format(lowerAlcoholAverage)) after lower-alcohol evenings (0-2) across \(sampleCount) matched days.",
            actionText: isSubtle ? "Even a small dip can add up. Keep alcohol lighter before recovery-focused days." : "Try cutting back on alcohol before recovery-focused or training-heavy days.",
            driverText: "Higher alcohol",
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
