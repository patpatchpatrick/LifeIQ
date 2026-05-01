//
//  SQHealthIntelligenceInput.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import Foundation
import BeastFitnessCore

struct SQHealthIntelligenceScoreContext {
    let score: Int?
    let stateTitle: String
    let scoreDeltaFromPreviousDay: Int?

    var isPressureState: Bool {
        let normalizedTitle = stateTitle.lowercased()
        return normalizedTitle == "under pressure" || normalizedTitle == "dipping"
    }
}

/// Shared raw-input shape for engine-backed health intelligence flows.
/// Insights and Life Score should read from the same domain inputs so their
/// outputs stay aligned even as the presentation layers evolve independently.
struct SQHealthIntelligenceInput {
    let referenceDate: Date
    let timeRange: AppTimeRange
    let metricDefinitions: [SQMetricDefinition]
    let checkIns: [SQDailyCheckInStats]
    let sleepCheckIns: [SQDailyCheckInStats]
    let workouts: [SQWorkoutSessionable]
    let sleepData: SQSleepDashboardData?
    let restingHeartRateSummaries: [SQHeartRateDailySummary]
    let currentCheckInPromptPeriod: SQMetricPeriod?
    let hasCompletedCurrentPromptCheckIn: Bool
    let isLoggedIn: Bool
    let scoreContext: SQHealthIntelligenceScoreContext?

    init(
        referenceDate: Date,
        timeRange: AppTimeRange,
        metricDefinitions: [SQMetricDefinition],
        checkIns: [SQDailyCheckInStats],
        sleepCheckIns: [SQDailyCheckInStats] = [],
        workouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        restingHeartRateSummaries: [SQHeartRateDailySummary] = [],
        currentCheckInPromptPeriod: SQMetricPeriod? = nil,
        hasCompletedCurrentPromptCheckIn: Bool = false,
        isLoggedIn: Bool,
        scoreContext: SQHealthIntelligenceScoreContext? = nil
    ) {
        self.referenceDate = referenceDate
        self.timeRange = timeRange
        self.metricDefinitions = metricDefinitions
        self.checkIns = checkIns
        self.sleepCheckIns = sleepCheckIns
        self.workouts = workouts
        self.sleepData = sleepData
        self.restingHeartRateSummaries = restingHeartRateSummaries
        self.currentCheckInPromptPeriod = currentCheckInPromptPeriod
        self.hasCompletedCurrentPromptCheckIn = hasCompletedCurrentPromptCheckIn
        self.isLoggedIn = isLoggedIn
        self.scoreContext = scoreContext
    }

    func withScoreContext(_ scoreContext: SQHealthIntelligenceScoreContext?) -> SQHealthIntelligenceInput {
        .init(
            referenceDate: referenceDate,
            timeRange: timeRange,
            metricDefinitions: metricDefinitions,
            checkIns: checkIns,
            sleepCheckIns: sleepCheckIns,
            workouts: workouts,
            sleepData: sleepData,
            restingHeartRateSummaries: restingHeartRateSummaries,
            currentCheckInPromptPeriod: currentCheckInPromptPeriod,
            hasCompletedCurrentPromptCheckIn: hasCompletedCurrentPromptCheckIn,
            isLoggedIn: isLoggedIn,
            scoreContext: scoreContext
        )
    }

    func withReferenceDate(_ referenceDate: Date) -> SQHealthIntelligenceInput {
        .init(
            referenceDate: referenceDate,
            timeRange: timeRange,
            metricDefinitions: metricDefinitions,
            checkIns: checkIns,
            sleepCheckIns: sleepCheckIns,
            workouts: workouts,
            sleepData: sleepData,
            restingHeartRateSummaries: restingHeartRateSummaries,
            currentCheckInPromptPeriod: currentCheckInPromptPeriod,
            hasCompletedCurrentPromptCheckIn: hasCompletedCurrentPromptCheckIn,
            isLoggedIn: isLoggedIn,
            scoreContext: nil
        )
    }
}
