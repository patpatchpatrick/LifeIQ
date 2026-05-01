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

enum SQInsightSupportiveReadinessGate {
    private enum AbsoluteThreshold {
        case minimum(Double)
        case maximum(Double)
    }

    static func allowsSupportiveSignal(
        signalId: String,
        recentAverage: Double
    ) -> Bool {
        guard let threshold = supportiveAbsoluteThreshold(for: signalId) else {
            return true
        }

        switch threshold {
        case .minimum(let minimumValue):
            return recentAverage >= minimumValue
        case .maximum(let maximumValue):
            return recentAverage <= maximumValue
        }
    }

    private static func supportiveAbsoluteThreshold(for signalId: String) -> AbsoluteThreshold? {
        switch signalId {
        case SQMetricId.sleepHours:
            return .minimum(6.75)
        case SQMetricId.sleepQuality:
            return .minimum(7.2)
        case SQMetricId.energy, SQMetricId.mood, SQMetricId.mentalClarity, SQMetricId.motivation, SQMetricId.soreness:
            return .minimum(6)
        case SQMetricId.stress, SQMetricId.anxiety:
            return .maximum(4.5)
        default:
            return nil
        }
    }
}
