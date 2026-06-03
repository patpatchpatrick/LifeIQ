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
    static var disableSQLoggerLogs = false {
        didSet {
            SQLogger.shared.isDisabled = disableSQLoggerLogs
        }
    }

    /// Temporary debug-time toggle for auth experiments. This is intentionally mutable
    /// so a future dev/admin menu can flip it without reworking the call sites.
    static var enforceEmailVerificationForEmailPasswordAccounts = false

    /// Stored-profile fallback for new users and admin/debug mirrors. Runtime entitlement
    /// checks should use Apple's StoreKit state through SQSubscriptionManager.
    static var appDefaultSubscriptionLevel: SQSubscriptionLevel = .free

    /// Debug-only local override for testing subscription states. When non-nil, this wins
    /// over the user's stored Firestore subscription level without changing that record.
    static var subscriptionLevelOverride: SQSubscriptionLevel? = nil
    static var freeCustomMetricLimit = 1

    /// Debug-only toggle for rendering canned health data without requiring
    /// a populated HealthKit store on the current simulator or device.
    static var useMockDashboardHealthData = false
    static var useMockHealthData: Bool { useMockDashboardHealthData }

    /// Debug-only visual QA switch. When enabled, the dashboard presents the
    /// workout review sheet for the latest available workouts even if they were
    /// already marked processed or included in the review baseline.
    static var forceWorkoutReviewSheet = false

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

    /// Temporary App Store screenshot guard. Keeps sensitive habit insights out of the
    /// default dashboard presentation without changing the underlying insight engine.
    static var hideScreenshotSensitiveInsights = false

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
    static let appDefaultSubscriptionLevel: SQSubscriptionLevel = .free
    static let subscriptionLevelOverride: SQSubscriptionLevel? = nil
    static let freeCustomMetricLimit = 1
    static let useMockDashboardHealthData = false
    static let useMockHealthData = false
    static let forceWorkoutReviewSheet = false
    static let verboseLoggingEnabled = false
    static let firestoreSafetyEnabled = true
    static let firestoreMaxReadsPerMinute = 10_000
    static let firestoreMaxWritesPerMinute = 1_000
    static let firestoreMaxRequestsPerMinutePerOperation = 1_000
    static let firestoreSafetyCooldownSeconds: TimeInterval = 300
    static let viewLabEnabled = false
    static let forceInsightFreshnessBadges = false
    static let hideScreenshotSensitiveInsights = false
    static let personalizedLifeScoreAdjustmentsEnabled = false
    static let enableCustomRelationshipInsights = false

    static func applyRuntimeSettings() {
        SQLogger.shared.isDisabled = disableSQLoggerLogs
    }
    #endif
}
