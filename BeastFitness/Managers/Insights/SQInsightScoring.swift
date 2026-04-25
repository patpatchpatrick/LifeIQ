//
//  SQInsightScoring.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation

enum SQInsightScoring {
    static func confidence(sampleCount: Int, effectMagnitude: Double) -> SQInsightConfidence {
        switch (sampleCount, effectMagnitude) {
        case (18..., 1.5...):
            return .high
        case (12..., 1.0...):
            return .medium
        default:
            return .low
        }
    }

    static func rankingScore(
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
}
