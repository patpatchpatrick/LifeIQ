//
//  SQInsightBaselineAnalyzer.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

struct SQInsightBaselineAnalyzer {
    private struct SignalObservation {
        let value: Double
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
            return .init(value: value)
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

        let recentValues = Array(observations.suffix(recentCount))
        let baselineValues = Array(observations.dropLast(recentCount).suffix(baselineCount))

        guard recentValues.count >= minimumRequired,
              baselineValues.count >= minimumRequired,
              let recentAverage = average(of: recentValues.map(\.value)),
              let baselineAverage = average(of: baselineValues.map(\.value)) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) vs Baseline",
                status: .needsMoreData,
                summary: "Need at least \(minimumRequired) logged \(relationship.bucketUnitName) in both the recent and baseline windows for \(relationship.inputTitle.lowercased())."
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
                title: baselineTitle(
                    relationship: relationship,
                    effect: effect,
                    delta: delta
                ),
                summary: "\(relationship.inputTitle) is \(delta >= 0 ? "running above" : "sitting below") your recent baseline by \(format(effectMagnitude)).",
                evidenceText: "Recent \(relationship.inputTitle.lowercased()) averaged \(format(recentAverage)) vs a baseline average of \(format(baselineAverage)) across the prior \(baselineValues.count) logged \(relationship.bucketUnitName).",
                actionText: baselineActionText(
                    relationship: relationship,
                    effect: effect
                ),
                driverText: relationship.inputTitle,
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
        relationship: SQInsightRelationshipDefinition,
        effect: SQInsightEffect,
        delta: Double
    ) -> String {
        switch effect {
        case .positive:
            return delta >= 0
                ? "\(relationship.inputTitle) is stronger than your baseline"
                : "\(relationship.inputTitle) is pulling back into a better range"
        case .negative:
            return delta >= 0
                ? "\(relationship.inputTitle) is running worse than your baseline"
                : "\(relationship.inputTitle) is below your usual baseline"
        case .neutral:
            return "\(relationship.inputTitle) has moved away from baseline"
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
}
