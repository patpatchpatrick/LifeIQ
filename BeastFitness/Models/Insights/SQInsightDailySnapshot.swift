//
//  SQInsightDailySnapshot.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

enum SQInsightAnalysisMetricId {
    static let workoutPerformance = "insight.workoutPerformance"
    static let workoutDifficulty = "insight.workoutDifficulty"
}

struct SQInsightDailySnapshot: Identifiable {
    let date: Date
    let anchorDayKey: String
    let rawMetricValues: [String: Double]
    let normalizedMetricValues: [String: Double]
    let workoutCount: Int
    let averageWorkoutPerformance: Double?
    let averageWorkoutDifficulty: Double?

    var id: String { anchorDayKey }

    var hasWorkout: Bool {
        workoutCount > 0
    }

    func rawMetricValue(for metricId: String) -> Double? {
        switch metricId {
        case SQInsightAnalysisMetricId.workoutPerformance:
            return averageWorkoutPerformance
        case SQInsightAnalysisMetricId.workoutDifficulty:
            return averageWorkoutDifficulty
        default:
            break
        }

        return rawMetricValues[metricId]
    }

    func normalizedMetricValue(for metricId: String) -> Double? {
        switch metricId {
        case SQInsightAnalysisMetricId.workoutPerformance:
            return averageWorkoutPerformance
        case SQInsightAnalysisMetricId.workoutDifficulty:
            return averageWorkoutDifficulty
        default:
            break
        }

        return normalizedMetricValues[metricId]
    }
}
