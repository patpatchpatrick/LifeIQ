//
//  SQBuildOverrides.swift
//  BeastFitness
//
//  Created by Codex on 4/19/26.
//

import Foundation

enum SQBuildOverrides {
    #if DEBUG
    /// Temporary debug-time toggle for auth experiments. This is intentionally mutable
    /// so a future dev/admin menu can flip it without reworking the call sites.
    static var enforceEmailVerificationForEmailPasswordAccounts = true

    /// Debug-only toggle for rendering canned dashboard health data without requiring
    /// a populated HealthKit store on the current simulator or device.
    static var useMockDashboardHealthData = false
    #else
    static let enforceEmailVerificationForEmailPasswordAccounts = true
    static let useMockDashboardHealthData = false
    #endif
}
