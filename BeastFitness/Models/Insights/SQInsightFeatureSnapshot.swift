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
    static let restingHeartRate = "insight.restingHeartRate"
}

enum SQInsightSignalSource: String, Hashable, Codable {
    case userLogged
    case healthKitFallback
    case healthKitDerived
    case workoutDerived
}

struct SQInsightSignalFeature: Hashable {
    let signalId: String
    let title: String
    let rawValue: Double
    /// Normalized against metric min/max as 0...1 when available.
    let normalizedValue: Double?
    /// Goal-aware utility from 0...100 where 100 is best for that metric.
    let goalUtilityScore: Double?
    let signalRole: SQMetricSignalRole
    let lifeScoreImpact: SQMetricLifeScoreImpact
    let insightMode: SQMetricInsightMode
    let sensitivity: SQMetricSensitivity
    let source: SQInsightSignalSource
}

struct SQInsightFeatureSnapshot: Identifiable {
    let date: Date
    let anchorDayKey: String
    let rawSignalValues: [String: Double]
    let normalizedSignalValues: [String: Double]
    let signalFeatures: [String: SQInsightSignalFeature]
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
