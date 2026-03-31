//
//  SQPerformanceRowData.swift
//  BeastFitness
//

import Foundation
import HealthKit

struct SQPerformanceRowData: Identifiable {
    let id: String
    let icon: String  // Emoji or SF Symbol name
    let title: String
    let bestValue: String
    let unit: String
    let percentileRank: Double?  // 0.0 to 1.0, nil if insufficient data
    let leaderboardMode: SQLeaderboardMode?
    let isPremiumLocked: Bool
    let scoreKind: SQWorkoutScoreKind?

    init(
        id: String,
        icon: String,
        title: String,
        bestValue: String,
        unit: String,
        percentileRank: Double?,
        leaderboardMode: SQLeaderboardMode? = nil,
        isPremiumLocked: Bool = false,
        scoreKind: SQWorkoutScoreKind? = nil
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.bestValue = bestValue
        self.unit = unit
        self.percentileRank = percentileRank
        self.leaderboardMode = leaderboardMode
        self.isPremiumLocked = isPremiumLocked
        self.scoreKind = scoreKind
    }
}
