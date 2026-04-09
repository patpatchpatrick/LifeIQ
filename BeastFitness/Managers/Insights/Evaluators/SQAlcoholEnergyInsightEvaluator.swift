//
//  SQAlcoholEnergyInsightEvaluator.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

struct SQAlcoholEnergyInsightEvaluator: SQInsightEvaluating {
    let id = "insight.alcohol.energy"
    let title = "Alcohol -> Energy"
    private let lowAlcoholUpperBound = 2.0
    private let minimumEffectMagnitude = 0.15

    func evaluate(snapshots: [SQInsightDailySnapshot]) -> SQInsightEvaluationResult {
        guard snapshots.count >= 2 else {
            return needsMoreData(summary: "Need at least 2 sequential logged days to compare alcohol to next-day energy.")
        }

        var energyAfterLowerAlcohol = [Double]()
        var energyAfterHigherAlcohol = [Double]()
        let calendar = Calendar.current

        for index in 0..<(snapshots.count - 1) {
            let current = snapshots[index]
            let next = snapshots[index + 1]
            let dayDelta = calendar.dateComponents([.day], from: current.date, to: next.date).day

            guard dayDelta == 1 else { continue }

            guard let alcohol = current.rawMetricValue(for: SQMetricId.alcohol),
                  let nextEnergy = next.normalizedMetricValue(for: SQMetricId.energy) else {
                continue
            }

            if alcohol <= lowAlcoholUpperBound {
                energyAfterLowerAlcohol.append(nextEnergy)
            } else {
                energyAfterHigherAlcohol.append(nextEnergy)
            }
        }

        guard energyAfterLowerAlcohol.count >= 2, energyAfterHigherAlcohol.count >= 2 else {
            let neededLowerAlcohol = max(0, 2 - energyAfterLowerAlcohol.count)
            let neededHigherAlcohol = max(0, 2 - energyAfterHigherAlcohol.count)
            return needsMoreData(
                summary: "Need \(neededLowerAlcohol) more lower-alcohol evening(s) (0-2) and \(neededHigherAlcohol) more higher-alcohol evening(s) (3+) with next-day energy logged."
            )
        }

        guard let lowerAlcoholAverage = average(of: energyAfterLowerAlcohol),
              let higherAlcoholAverage = average(of: energyAfterHigherAlcohol) else {
            return needsMoreData(summary: "Need more matched energy entries across lower- and higher-alcohol evenings.")
        }

        let difference = higherAlcoholAverage - lowerAlcoholAverage
        let effectMagnitude = abs(difference)
        guard difference <= (-minimumEffectMagnitude) else {
            return weakSignal(
                summary: "Enough matched days were found, but higher alcohol is only linked to a \(format(effectMagnitude)) point next-day energy drop so far."
            )
        }

        let sampleCount = energyAfterLowerAlcohol.count + energyAfterHigherAlcohol.count
        let confidence = insightConfidence(sampleCount: sampleCount, effectMagnitude: effectMagnitude)
        let isSubtle = effectMagnitude < 0.8

        return .insight(SQInsight(
            id: id,
            title: isSubtle ? "Higher alcohol may be slightly lowering energy" : "Higher alcohol is lowering next-day energy",
            summary: "Higher-alcohol evenings are associated with \(format(effectMagnitude)) points lower next-day energy.",
            evidenceText: "Next-day energy averaged \(format(higherAlcoholAverage)) after higher-alcohol evenings (3+) vs \(format(lowerAlcoholAverage)) after lower-alcohol evenings (0-2) across \(sampleCount) matched days.",
            actionText: isSubtle ? "Even a small energy drop can matter on training days. Keep alcohol lighter the night before." : "If energy matters the next day, keep alcohol lower on the nights before.",
            driverText: "Higher alcohol",
            outcomeText: "Lower energy",
            deltaText: "-\(format(effectMagnitude)) pts",
            category: .recovery,
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
