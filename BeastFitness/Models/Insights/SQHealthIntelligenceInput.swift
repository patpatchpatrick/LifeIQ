//
//  SQHealthIntelligenceInput.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import Foundation
import BeastFitnessCore

/// Shared raw-input shape for engine-backed health intelligence flows.
/// Insights and Life Score should read from the same domain inputs so their
/// outputs stay aligned even as the presentation layers evolve independently.
struct SQHealthIntelligenceInput {
    let referenceDate: Date
    let timeRange: AppTimeRange
    let metricDefinitions: [SQMetricDefinition]
    let checkIns: [SQDailyCheckInStats]
    let workouts: [SQWorkoutSessionable]
    let sleepData: SQSleepDashboardData?
    let isLoggedIn: Bool
}
