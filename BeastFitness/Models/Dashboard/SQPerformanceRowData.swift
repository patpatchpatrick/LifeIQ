//
//  SQPerformanceRowData.swift
//  BeastFitness
//

import Foundation
import HealthKit

struct SQDashboardTrendDeltaViewModel {
    let delta: Double
    let valueText: String
    let comparisonText: String

    var isPositive: Bool {
        delta >= 0
    }

    var tone: SQDashboardTrendTone {
        isPositive ? .positive : .negative
    }

    var symbol: SQImageSymbol {
        isPositive ? .arrowUp : .arrowDown
    }

    init(delta: Double, valueText: String, comparisonText: String) {
        self.delta = delta
        self.valueText = valueText
        self.comparisonText = comparisonText
    }
}

struct SQPerformanceRowData: Identifiable {
    let id: String
    let icon: String  // Emoji or SF Symbol name
    let title: String
    let bestValue: String
    let unit: String
    let percentileRank: Double?  // 0.0 to 1.0, nil if insufficient data
    let leaderboardMode: SQLeaderboardMode?
    let isPremiumLocked: Bool
    let premiumLockText: String
    let scoreKind: SQWorkoutScoreKind?
    let trendDelta: SQDashboardTrendDeltaViewModel?

    init(
        id: String,
        icon: String,
        title: String,
        bestValue: String,
        unit: String,
        percentileRank: Double?,
        leaderboardMode: SQLeaderboardMode? = nil,
        isPremiumLocked: Bool = false,
        premiumLockText: String = "",
        scoreKind: SQWorkoutScoreKind? = nil,
        trendDelta: SQDashboardTrendDeltaViewModel? = nil
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.bestValue = bestValue
        self.unit = unit
        self.percentileRank = percentileRank
        self.leaderboardMode = leaderboardMode
        self.isPremiumLocked = isPremiumLocked
        self.premiumLockText = premiumLockText
        self.scoreKind = scoreKind
        self.trendDelta = trendDelta
    }
}
