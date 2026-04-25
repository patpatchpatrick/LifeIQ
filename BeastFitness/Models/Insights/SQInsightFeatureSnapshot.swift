//
//  SQInsightFeatureSnapshot.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation

enum SQInsightAnalysisMetricId {
    static let workoutPerformance = "insight.workoutPerformance"
    static let workoutDifficulty = "insight.workoutDifficulty"
}

struct SQInsightFeatureSnapshot: Identifiable {
    let date: Date
    let anchorDayKey: String
    let rawSignalValues: [String: Double]
    let normalizedSignalValues: [String: Double]
    let workoutCount: Int
    let averageWorkoutPerformance: Double?
    let averageWorkoutDifficulty: Double?

    var id: String { anchorDayKey }

    var hasWorkout: Bool {
        workoutCount > 0
    }

    func rawSignalValue(for signalId: String) -> Double? {
        switch signalId {
        case SQInsightAnalysisMetricId.workoutPerformance:
            return averageWorkoutPerformance
        case SQInsightAnalysisMetricId.workoutDifficulty:
            return averageWorkoutDifficulty
        default:
            return rawSignalValues[signalId]
        }
    }

    func normalizedSignalValue(for signalId: String) -> Double? {
        switch signalId {
        case SQInsightAnalysisMetricId.workoutPerformance:
            return averageWorkoutPerformance
        case SQInsightAnalysisMetricId.workoutDifficulty:
            return averageWorkoutDifficulty
        default:
            return normalizedSignalValues[signalId]
        }
    }
}
