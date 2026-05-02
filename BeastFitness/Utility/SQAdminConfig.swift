//
//  SQAdminConfig.swift
//  BeastFitness
//
//  Created by Codex on 4/19/26.
//

import Foundation

enum SQAdminConfig {
    #if DEBUG
    /// Temporary debug-time toggle for auth experiments. This is intentionally mutable
    /// so a future dev/admin menu can flip it without reworking the call sites.
    static var enforceEmailVerificationForEmailPasswordAccounts = true

    /// Temporary app-wide default while subscription plans are not wired up yet.
    /// Change this to `.free` to quickly exercise locked premium UI states.
    static var appDefaultSubscriptionLevel: SQSubscriptionLevel = .free

    /// Debug-only toggle for rendering canned health data without requiring
    /// a populated HealthKit store on the current simulator or device.
    static var useMockDashboardHealthData = false
    static var useMockHealthData: Bool { useMockDashboardHealthData }
    static var verboseLoggingEnabled = false

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
    #else
    static let enforceEmailVerificationForEmailPasswordAccounts = true
    static let appDefaultSubscriptionLevel: SQSubscriptionLevel = .premium
    static let useMockDashboardHealthData = false
    static let useMockHealthData = false
    static let verboseLoggingEnabled = false
    static let viewLabEnabled = false
    static let forceInsightFreshnessBadges = false
    static let personalizedLifeScoreAdjustmentsEnabled = false
    static let enableCustomRelationshipInsights = false
    #endif
}
