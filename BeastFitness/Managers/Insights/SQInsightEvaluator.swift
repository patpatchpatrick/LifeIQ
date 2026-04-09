//
//  SQInsightEvaluator.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

enum SQInsightEvaluationResult {
    case insight(SQInsight)
    case readiness(SQInsightReadinessItem)
}

protocol SQInsightEvaluating {
    var id: String { get }
    var title: String { get }
    func evaluate(snapshots: [SQInsightDailySnapshot]) -> SQInsightEvaluationResult
}

extension SQInsightEvaluating {
    func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func format(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", value)
    }

    func insightConfidence(sampleCount: Int, effectMagnitude: Double) -> SQInsightConfidence {
        switch (sampleCount, effectMagnitude) {
        case (18..., 1.5...):
            return .high
        case (12..., 1.0...):
            return .medium
        default:
            return .low
        }
    }

    func insightRankingScore(
        sampleCount: Int,
        effectMagnitude: Double,
        confidence: SQInsightConfidence
    ) -> Double {
        let confidenceWeight: Double
        switch confidence {
        case .low:
            confidenceWeight = 1
        case .medium:
            confidenceWeight = 2
        case .high:
            confidenceWeight = 3
        }

        return (effectMagnitude * 10) + Double(sampleCount) + confidenceWeight
    }

    func needsMoreData(summary: String) -> SQInsightEvaluationResult {
        .readiness(.init(
            id: id,
            title: title,
            status: .needsMoreData,
            summary: summary
        ))
    }

    func weakSignal(summary: String) -> SQInsightEvaluationResult {
        .readiness(.init(
            id: id,
            title: title,
            status: .weakSignal,
            summary: summary
        ))
    }
}
