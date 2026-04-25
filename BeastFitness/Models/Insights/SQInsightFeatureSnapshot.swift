//
//  SQInsightFeatureSnapshot.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation
import HealthKit

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
    let workoutPerformanceActivityTypeRaw: UInt?
    let averageWorkoutDifficulty: Double?
    let workoutDifficultyActivityTypeRaw: UInt?

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

    func workoutActivityType(for signalId: String) -> HKWorkoutActivityType? {
        switch signalId {
        case SQInsightAnalysisMetricId.workoutPerformance:
            guard let workoutPerformanceActivityTypeRaw else { return nil }
            return HKWorkoutActivityType(rawValue: workoutPerformanceActivityTypeRaw)
        case SQInsightAnalysisMetricId.workoutDifficulty:
            guard let workoutDifficultyActivityTypeRaw else { return nil }
            return HKWorkoutActivityType(rawValue: workoutDifficultyActivityTypeRaw)
        default:
            return nil
        }
    }
}
