//
//  SQInsightCurrentStateAnalyzer.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

struct SQInsightCurrentStateAnalyzer {
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

        guard observations.count >= max(recentCount + baselineCount, minimumRequired + recentCount) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .needsMoreData,
                summary: "Need more logged \(relationship.bucketUnitName) with \(relationship.inputTitle.lowercased()) data before surfacing a current-state read."
            ))
        }

        let recentValues = Array(observations.suffix(recentCount))
        let baselineValues = Array(observations.dropLast(recentCount).suffix(baselineCount))

        guard recentValues.count >= recentCount,
              baselineValues.count >= minimumRequired,
              let recentAverage = average(of: recentValues.map(\.value)),
              let baselineAverage = average(of: baselineValues.map(\.value)) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .needsMoreData,
                summary: "Need a recent \(relationship.inputTitle.lowercased()) read plus at least \(minimumRequired) baseline \(relationship.bucketUnitName) to assess today."
            ))
        }

        let delta = recentAverage - baselineAverage
        let effectMagnitude = abs(delta)

        guard effectMagnitude >= relationship.minimumEffectMagnitude else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .weakSignal,
                summary: "\(relationship.inputTitle) is still close to baseline, so there is not a strong current-state signal to surface yet."
            ))
        }

        let effect = directionalEffect(
            delta: delta,
            expectedEffect: relationship.expectedEffect
        )

        guard shouldSurface(effect: effect, for: relationship.insightClass) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .weakSignal,
                summary: "\(relationship.inputTitle) moved, but not in the direction needed for a \(relationship.insightClass == .opportunity ? "today opportunity" : "today risk") insight."
            ))
        }

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

        return .insight(
            SQInsight(
                id: variant.id,
                familyKey: relationship.familyKey,
                insightClass: relationship.insightClass,
                variantPriority: variant.priority,
                title: currentStateTitle(
                    relationship: relationship,
                    effectMagnitude: effectMagnitude
                ),
                summary: currentStateSummary(
                    relationship: relationship,
                    delta: delta,
                    effectMagnitude: effectMagnitude
                ),
                evidenceText: "Recent \(relationship.inputTitle.lowercased()) averaged \(format(recentAverage)) vs a baseline average of \(format(baselineAverage)) across the prior \(baselineValues.count) logged \(relationship.bucketUnitName).",
                actionText: currentStateActionText(for: relationship),
                driverText: relationship.driverText,
                outcomeText: relationship.outcomeText,
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

    private func shouldSurface(
        effect: SQInsightEffect,
        for insightClass: SQInsightClass
    ) -> Bool {
        switch insightClass {
        case .opportunity:
            return effect == .positive
        case .risk:
            return effect == .negative
        default:
            return false
        }
    }

    private func currentStateTitle(
        relationship: SQInsightRelationshipDefinition,
        effectMagnitude: Double
    ) -> String {
        switch relationship.insightClass {
        case .opportunity:
            return "\(relationship.inputTitle) is supporting today"
        case .risk:
            return "\(relationship.inputTitle) is putting pressure on today"
        default:
            return "\(relationship.inputTitle) stands out today"
        }
    }

    private func currentStateSummary(
        relationship: SQInsightRelationshipDefinition,
        delta: Double,
        effectMagnitude: Double
    ) -> String {
        let directionText = delta >= 0 ? "above" : "below"

        switch relationship.insightClass {
        case .opportunity:
            return "\(relationship.inputTitle) is \(directionText) baseline by \(format(effectMagnitude)), which looks supportive right now."
        case .risk:
            return "\(relationship.inputTitle) is \(directionText) baseline by \(format(effectMagnitude)), which looks like a current drag."
        default:
            return "\(relationship.inputTitle) is \(directionText) baseline by \(format(effectMagnitude))."
        }
    }

    private func currentStateActionText(
        for relationship: SQInsightRelationshipDefinition
    ) -> String {
        switch relationship.insightClass {
        case .opportunity:
            return "This looks supportive right now. Lean into it while it holds and see if the rest of the day follows."
        case .risk:
            return relationship.strongActionText
        default:
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
