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
    static var appDefaultSubscriptionLevel: SQSubscriptionLevel = .premium

    /// Debug-only toggle for rendering canned health data without requiring
    /// a populated HealthKit store on the current simulator or device.
    static var useMockDashboardHealthData = false
    static var useMockHealthData: Bool { useMockDashboardHealthData }
    static var verboseLoggingEnabled = false
    #else
    static let enforceEmailVerificationForEmailPasswordAccounts = true
    static let appDefaultSubscriptionLevel: SQSubscriptionLevel = .premium
    static let useMockDashboardHealthData = false
    static let useMockHealthData = false
    static let verboseLoggingEnabled = false
    #endif
}
