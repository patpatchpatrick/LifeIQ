//
//  SQInsightTrendAnalyzer.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

struct SQInsightTrendAnalyzer {
    private struct SignalObservation {
        let date: Date
        let value: Double
    }

    func analyze(
        snapshots: [SQInsightFeatureSnapshot],
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition,
        surfaceIntent: SQInsightSurfaceIntent,
        surfacingPolicy: SQInsightSurfacingPolicy
    ) -> SQInsightAnalysisResult {
        let observations = signalObservations(
            from: snapshots,
            signalId: relationship.inputSignalId
        )

        let recentCount = relationship.recentWindowDayCount
        let priorCount = relationship.comparisonWindowDayCount
        let minimumRequired = max(relationship.minimumBucketSampleCount, 2)

        guard observations.count >= max(recentCount + priorCount, minimumRequired * 2) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Trend",
                status: .needsMoreData,
                summary: "Need more logged \(relationship.bucketUnitName) with \(relationship.inputTitle.lowercased()) data to measure a recent trend."
            ))
        }

        let recentValues = Array(observations.suffix(recentCount))
        let priorValues = Array(observations.dropLast(recentCount).suffix(priorCount))

        guard recentValues.count >= minimumRequired,
              priorValues.count >= minimumRequired,
              let recentAverage = average(of: recentValues.map(\.value)),
              let priorAverage = average(of: priorValues.map(\.value)) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Trend",
                status: .needsMoreData,
                summary: "Need at least \(minimumRequired) logged \(relationship.bucketUnitName) in both the recent and prior windows for \(relationship.inputTitle.lowercased())."
            ))
        }

        let delta = recentAverage - priorAverage
        let effectMagnitude = abs(delta)

        guard effectMagnitude >= relationship.minimumEffectMagnitude else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Trend",
                status: .weakSignal,
                summary: "\(relationship.inputTitle) has only shifted by \(format(effectMagnitude)) so far, which is too small to surface confidently."
            ))
        }

        let effect = directionalEffect(
            delta: delta,
            expectedEffect: relationship.expectedEffect
        )
        let sampleCount = recentValues.count + priorValues.count
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

        let directionText = delta >= 0 ? "up" : "down"
        let recentLabel = recentWindowLabel(for: recentValues, fallbackCount: recentCount)
        let priorLabel = priorWindowLabel(for: priorValues, fallbackCount: priorCount)

        return .insight(
            SQInsight(
                id: variant.id,
                familyKey: relationship.familyKey,
                insightClass: relationship.insightClass,
                variantPriority: variant.priority,
                title: trendTitle(
                    relationship: relationship,
                    effect: effect,
                    delta: delta
                ),
                summary: "\(relationship.inputTitle) has been trending \(directionText) by \(format(effectMagnitude)) versus \(priorLabel).",
                evidenceText: "Recent \(relationship.inputTitle.lowercased()) averaged \(format(recentAverage)) across \(recentLabel) vs \(format(priorAverage)) across \(priorLabel).",
                actionText: trendActionText(
                    relationship: relationship,
                    effect: effect
                ),
                driverText: "Recent \(relationship.inputTitle)",
                outcomeText: delta >= 0 ? "Trending Higher" : "Trending Lower",
                deltaText: signedDeltaText(delta),
                category: relationship.category,
                confidence: confidence,
                effect: effect,
                sampleCount: sampleCount,
                rankingScore: rankingScore
            )
        )
    }

    private func signalObservations(
        from snapshots: [SQInsightFeatureSnapshot],
        signalId: String
    ) -> [SignalObservation] {
        snapshots.compactMap { snapshot in
            guard let value = snapshot.rawSignalValue(for: signalId) else { return nil }
            return .init(date: snapshot.date, value: value)
        }
        .sorted { $0.date < $1.date }
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

    private func trendTitle(
        relationship: SQInsightRelationshipDefinition,
        effect: SQInsightEffect,
        delta: Double
    ) -> String {
        switch effect {
        case .positive:
            return delta >= 0
                ? "\(relationship.inputTitle) is trending in a better direction"
                : "\(relationship.inputTitle) is easing back toward a better range"
        case .negative:
            return delta >= 0
                ? "\(relationship.inputTitle) has been moving the wrong way recently"
                : "\(relationship.inputTitle) is slipping recently"
        case .neutral:
            return "\(relationship.inputTitle) has been shifting recently"
        }
    }

    private func trendActionText(
        relationship: SQInsightRelationshipDefinition,
        effect: SQInsightEffect
    ) -> String {
        switch effect {
        case .positive:
            return "This recent shift looks favorable. Keep the pattern steady and see if it holds."
        case .negative:
            return relationship.strongActionText
        case .neutral:
            return relationship.subtleActionText
        }
    }

    private func recentWindowLabel(
        for observations: [SignalObservation],
        fallbackCount: Int
    ) -> String {
        if let start = observations.first?.date, let end = observations.last?.date, observations.count > 1 {
            let dayCount = Calendar.current.dateComponents([.day], from: start, to: end).day ?? (observations.count - 1)
            return "the last \(max(dayCount + 1, observations.count)) logged day\(max(dayCount + 1, observations.count) == 1 ? "" : "s")"
        }

        return "the last \(fallbackCount) logged day\(fallbackCount == 1 ? "" : "s")"
    }

    private func priorWindowLabel(
        for observations: [SignalObservation],
        fallbackCount: Int
    ) -> String {
        "the prior \(max(observations.count, fallbackCount)) logged day\(max(observations.count, fallbackCount) == 1 ? "" : "s")"
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
