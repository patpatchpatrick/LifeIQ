//
//  SQInsightDailySnapshot.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

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
        rawMetricValues[metricId]
    }

    func normalizedMetricValue(for metricId: String) -> Double? {
        normalizedMetricValues[metricId]
    }
}
