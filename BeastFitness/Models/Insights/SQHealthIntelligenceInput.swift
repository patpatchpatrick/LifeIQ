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
    let restingHeartRateSummaries: [SQHeartRateDailySummary]
    let currentCheckInPromptPeriod: SQMetricPeriod?
    let hasCompletedCurrentPromptCheckIn: Bool
    let isLoggedIn: Bool

    init(
        referenceDate: Date,
        timeRange: AppTimeRange,
        metricDefinitions: [SQMetricDefinition],
        checkIns: [SQDailyCheckInStats],
        workouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        restingHeartRateSummaries: [SQHeartRateDailySummary] = [],
        currentCheckInPromptPeriod: SQMetricPeriod? = nil,
        hasCompletedCurrentPromptCheckIn: Bool = false,
        isLoggedIn: Bool
    ) {
        self.referenceDate = referenceDate
        self.timeRange = timeRange
        self.metricDefinitions = metricDefinitions
        self.checkIns = checkIns
        self.workouts = workouts
        self.sleepData = sleepData
        self.restingHeartRateSummaries = restingHeartRateSummaries
        self.currentCheckInPromptPeriod = currentCheckInPromptPeriod
        self.hasCompletedCurrentPromptCheckIn = hasCompletedCurrentPromptCheckIn
        self.isLoggedIn = isLoggedIn
    }
}
