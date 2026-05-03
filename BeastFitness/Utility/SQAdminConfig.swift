//
//  SQAdminConfig.swift
//  BeastFitness
//
//  Created by Codex on 4/19/26.
//

import Foundation
import BeastFitnessCore

enum SQAdminConfig {
    #if DEBUG
    /// Debug performance kill switch for disabling every SQLogger log call at the
    /// logger boundary. Useful when attached to Xcode and investigating scroll lag.
    static var disableSQLoggerLogs = true {
        didSet {
            SQLogger.shared.isDisabled = disableSQLoggerLogs
        }
    }

    /// Temporary debug-time toggle for auth experiments. This is intentionally mutable
    /// so a future dev/admin menu can flip it without reworking the call sites.
    static var enforceEmailVerificationForEmailPasswordAccounts = true

    /// Temporary app-wide default while subscription plans are not wired up yet.
    /// Change this to `.free` to quickly exercise locked premium UI states.
    static var appDefaultSubscriptionLevel: SQSubscriptionLevel = .premium
    static var freeCustomMetricLimit = 1

    /// Debug-only toggle for rendering canned health data without requiring
    /// a populated HealthKit store on the current simulator or device.
    static var useMockDashboardHealthData = false
    static var useMockHealthData: Bool { useMockDashboardHealthData }
    static var verboseLoggingEnabled = false
    static var firestoreSafetyEnabled = true
    static var firestoreMaxReadsPerMinute = 10_000
    static var firestoreMaxWritesPerMinute = 1_000
    static var firestoreMaxRequestsPerMinutePerOperation = 1_000
    static var firestoreSafetyCooldownSeconds: TimeInterval = 300

    /// Gates the internal scenario/gallery lab used to QA dashboard and future view states.
    static var viewLabEnabled = true

    /// Forces weekly/yearly insight freshness UI for on-device testing without waiting for
    /// the real surfacing-memory conditions and cooldowns to line up.
    static var forceInsightFreshnessBadges = false

    /// Keeps personalized metric score adjustments off until custom metric scoring has
    /// been validated in View Lab and the metric setup UX can explain the setting.
    static var personalizedLifeScoreAdjustmentsEnabled = false

    /// Debug-only gate for exploratory custom relationship cards. Keep off until
    /// simulator output has been reviewed for noisy or causal-sounding patterns.
    static var enableCustomRelationshipInsights = false

    static func applyRuntimeSettings() {
        SQLogger.shared.isDisabled = disableSQLoggerLogs
    }
    #else
    static let disableSQLoggerLogs = false
    static let enforceEmailVerificationForEmailPasswordAccounts = true
    static let appDefaultSubscriptionLevel: SQSubscriptionLevel = .premium
    static let freeCustomMetricLimit = 1
    static let useMockDashboardHealthData = false
    static let useMockHealthData = false
    static let verboseLoggingEnabled = false
    static let firestoreSafetyEnabled = true
    static let firestoreMaxReadsPerMinute = 10_000
    static let firestoreMaxWritesPerMinute = 1_000
    static let firestoreMaxRequestsPerMinutePerOperation = 1_000
    static let firestoreSafetyCooldownSeconds: TimeInterval = 300
    static let viewLabEnabled = false
    static let forceInsightFreshnessBadges = false
    static let personalizedLifeScoreAdjustmentsEnabled = false
    static let enableCustomRelationshipInsights = false

    static func applyRuntimeSettings() {
        SQLogger.shared.isDisabled = disableSQLoggerLogs
    }
    #endif
}
