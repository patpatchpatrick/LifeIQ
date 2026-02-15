//
//  SQPercentileCalculator.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-15.
//

import Foundation

struct SQPercentileCalculator {
    /// Calculate percentile rank for a value against historical data
    ///
    /// - Parameters:
    ///   - currentBest: The best value from the current time period
    ///   - historicalValues: All historical values to compare against
    ///   - isLowerBetter: True for metrics where lower is better (e.g., pace), false for higher is better (e.g., VO2 max)
    ///
    /// - Returns: Percentile as decimal (0.0 to 1.0), or nil if insufficient data
    ///
    /// - Note: Returns nil if there are fewer than 2 historical values
    static func calculatePercentile(
        currentBest: Double,
        historicalValues: [Double],
        isLowerBetter: Bool
    ) -> Double? {
        // Need at least 2 data points to calculate percentile
        guard historicalValues.count >= 2 else { return nil }

        let betterCount: Int
        if isLowerBetter {
            // For pace: count how many historical values are slower (higher)
            betterCount = historicalValues.filter { $0 > currentBest }.count
        } else {
            // For VO2/distance: count how many historical values are lower
            betterCount = historicalValues.filter { $0 < currentBest }.count
        }

        // Calculate percentile (0.0 = worst, 1.0 = best)
        let percentile = Double(betterCount) / Double(historicalValues.count)
        return percentile
    }
}
