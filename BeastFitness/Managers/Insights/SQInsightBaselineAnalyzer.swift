//
//  SQInsightBaselineAnalyzer.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation
import HealthKit

struct SQInsightBaselineAnalyzer {
    private struct SignalObservation {
        let value: Double
        let activityType: HKWorkoutActivityType?
    }

    func analyze(
        snapshots: [SQInsightFeatureSnapshot],
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition,
        surfaceIntent: SQInsightSurfaceIntent,
        surfacingPolicy: SQInsightSurfacingPolicy
    ) -> SQInsightAnalysisResult {
        let observations = snapshots.compactMap { snapshot -> SignalObservation? in
            guard let value = snapshot.rawSignalValue(for: relationship.inputSignalId) else { return nil }
            return .init(
                value: value,
                activityType: snapshot.workoutActivityType(for: relationship.inputSignalId)
            )
        }

        let recentCount = relationship.recentWindowDayCount
        let baselineCount = relationship.baselineWindowDayCount
        let minimumRequired = max(relationship.minimumBucketSampleCount, 2)

        guard observations.count >= max(recentCount + baselineCount, minimumRequired * 2) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) vs Baseline",
                status: .needsMoreData,
                summary: "Need more logged \(relationship.bucketUnitName) with \(relationship.inputTitle.lowercased()) data before comparing against your baseline."
            ))
        }

        var recentValues = Array(observations.suffix(recentCount))
        var baselineValues = Array(observations.dropLast(recentCount).suffix(baselineCount))
        var inputTitle = relationship.inputTitle

        if relationship.inputSignalId == SQInsightAnalysisMetricId.workoutPerformance,
           let recentActivityType = dominantActivityType(in: recentValues) {
            recentValues = recentValues.filter { $0.activityType == recentActivityType }
            baselineValues = baselineValues.filter { $0.activityType == recentActivityType }
            inputTitle = "\(recentActivityType.name) Performance"
        }

        guard recentValues.count >= minimumRequired,
              baselineValues.count >= minimumRequired,
              let recentAverage = average(of: recentValues.map(\.value)),
              let baselineAverage = average(of: baselineValues.map(\.value)) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(inputTitle) vs Baseline",
                status: .needsMoreData,
                summary: "Need at least \(minimumRequired) logged \(relationship.bucketUnitName) in both the recent and baseline windows for \(inputTitle.lowercased())."
            ))
        }

        let delta = recentAverage - baselineAverage
        let effectMagnitude = abs(delta)

        guard effectMagnitude >= relationship.minimumEffectMagnitude else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) vs Baseline",
                status: .weakSignal,
                summary: "\(relationship.inputTitle) is still close to your baseline, with only a \(format(effectMagnitude)) point gap so far."
            ))
        }

        let effect = directionalEffect(
            delta: delta,
            expectedEffect: relationship.expectedEffect
        )
        let sampleCount = recentValues.count + baselineValues.count
        let confidence = SQInsightScoring.confidence(
            sampleCount: sampleCount,
            effectMagnitude: effectMagnitude
        )
        let baseRankingScore = SQInsightScoring.rankingScore(
            sampleCount: sampleCount,
            effectMagnitude: effectMagnitude,
            confidence: confidence
        )
        let rankingScore = surfacingPolicy.adjustedRankingScore(
            baseScore: baseRankingScore,
            relationship: relationship,
            variant: variant,
            surfaceIntent: surfaceIntent
        )

        let statusText = delta >= 0 ? "Above Baseline" : "Below Baseline"

        return .insight(
            SQInsight(
                id: variant.id,
                familyKey: relationship.familyKey,
                insightClass: relationship.insightClass,
                variantPriority: variant.priority,
                inputSignalId: relationship.inputSignalId,
                outputSignalId: relationship.outputSignalId,
                recommendationFamily: relationship.recommendationFamily,
                title: baselineTitle(
                    inputTitle: inputTitle,
                    effect: effect,
                    delta: delta
                ),
                summary: baselineSummary(
                    inputTitle: inputTitle,
                    effect: effect,
                    delta: delta,
                    effectMagnitude: effectMagnitude
                ),
                evidenceText: "Recent \(inputTitle.lowercased()) averaged \(format(recentAverage)) vs a baseline average of \(format(baselineAverage)) across the prior \(baselineValues.count) logged \(relationship.bucketUnitName).",
                actionText: baselineActionText(
                    relationship: relationship,
                    effect: effect
                ),
                driverText: inputTitle,
                outcomeText: statusText,
                deltaText: signedDeltaText(delta),
                category: relationship.category,
                confidence: confidence,
                effect: effect,
                sampleCount: sampleCount,
                rankingScore: rankingScore
            )
        )
    }

    private func directionalEffect(
        delta: Double,
        expectedEffect: SQInsightEffect
    ) -> SQInsightEffect {
        switch expectedEffect {
        case .positive:
            return delta >= 0 ? .positive : .negative
        case .negative:
            return delta >= 0 ? .negative : .positive
        case .neutral:
            return .neutral
        }
    }

    private func baselineTitle(
        inputTitle: String,
        effect: SQInsightEffect,
        delta: Double
    ) -> String {
        switch effect {
        case .positive:
            return delta >= 0
                ? "\(inputTitle) is stronger than your baseline"
                : "\(inputTitle) is pulling back into a better range"
        case .negative:
            return delta >= 0
                ? "\(inputTitle) is running worse than your baseline"
                : "\(inputTitle) is below your usual baseline"
        case .neutral:
            return "\(inputTitle) has moved away from baseline"
        }
    }

    private func baselineSummary(
        inputTitle: String,
        effect: SQInsightEffect,
        delta: Double,
        effectMagnitude: Double
    ) -> String {
        switch effect {
        case .positive:
            return delta >= 0
                ? "\(inputTitle) is higher than usual today by \(format(effectMagnitude))."
                : "\(inputTitle) is a bit lower than usual today by \(format(effectMagnitude))."
        case .negative:
            return delta >= 0
                ? "\(inputTitle) is higher than usual today by \(format(effectMagnitude))."
                : "\(inputTitle) is lower than usual today by \(format(effectMagnitude))."
        case .neutral:
            return "\(inputTitle) has shifted by \(format(effectMagnitude)) versus your usual baseline."
        }
    }

    private func baselineActionText(
        relationship: SQInsightRelationshipDefinition,
        effect: SQInsightEffect
    ) -> String {
        switch effect {
        case .positive:
            return "This is better than your usual baseline. Keep the recent pattern steady and watch whether it persists."
        case .negative:
            return relationship.strongActionText
        case .neutral:
            return relationship.subtleActionText
        }
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }

    private func signedDeltaText(_ value: Double) -> String {
        let magnitude = format(abs(value))
        return value >= 0 ? "+\(magnitude)" : "-\(magnitude)"
    }

    private func dominantActivityType(
        in observations: [SignalObservation]
    ) -> HKWorkoutActivityType? {
        let counts = observations.reduce(into: [HKWorkoutActivityType: Int]()) { partialResult, observation in
            guard let activityType = observation.activityType else { return }
            partialResult[activityType, default: 0] += 1
        }

        return counts.max(by: { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value < rhs.value
        })?.key
    }
}
