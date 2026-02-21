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
    let percentileRank: Double?
    let leaderboardMode: SQLeaderboardMode?

    init(
        metricId: String,
        icon: String,
        title: String,
        bestValue: String,
        unit: String,
        percentileRank: Double?,
        leaderboardMode: SQLeaderboardMode? = nil
    ) {
        self.metricId = metricId
        self.icon = icon
        self.title = title
        self.bestValue = bestValue
        self.unit = unit
        self.percentileRank = percentileRank
        self.leaderboardMode = leaderboardMode

        super.init(rowId: .metricPerformance, rowType: .metricPerformance)
    }
}
