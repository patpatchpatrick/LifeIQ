//
//  SQDashboardMetricPerformanceRowViewModel.swift
//  BeastFitness
//

import SwiftUI
import BeastFitnessCore

@Observable @MainActor
final class SQDashboardMetricPerformanceRowViewModel: SQDashboardRowViewModel {
    let metricId: String
    let icon: String
    let title: String
    let bestValue: String
    let unit: String
    let valueUnitLabel: String
    let percentileRank: Double?
    let leaderboardMode: SQLeaderboardMode?
    let isPremiumLocked: Bool
    let premiumLockText: String
    let scoreKind: SQWorkoutScoreKind?
    let trendDelta: SQDashboardTrendDeltaViewModel?

    init(
        metricId: String,
        icon: String,
        title: String,
        bestValue: String,
        unit: String,
        valueUnitLabel: String? = nil,
        percentileRank: Double?,
        leaderboardMode: SQLeaderboardMode? = nil,
        isPremiumLocked: Bool = false,
        premiumLockText: String = "",
        scoreKind: SQWorkoutScoreKind? = nil,
        trendDelta: SQDashboardTrendDeltaViewModel? = nil
    ) {
        self.metricId = metricId
        self.icon = icon
        self.title = title
        self.bestValue = bestValue
        self.unit = unit
        self.valueUnitLabel = valueUnitLabel ?? unit
        self.percentileRank = percentileRank
        self.leaderboardMode = leaderboardMode
        self.isPremiumLocked = isPremiumLocked
        self.premiumLockText = premiumLockText
        self.scoreKind = scoreKind
        self.trendDelta = trendDelta

        super.init(rowId: .metricPerformance, rowType: .metricPerformance)
    }
}
