//
//  SQDashboardSleepScoreRowViewModel.swift
//  BeastFitness
//

import Foundation

@Observable @MainActor
final class SQDashboardSleepScoreRowViewModel: SQDashboardRowViewModel {
    struct Component: Identifiable {
        let id: String
        let title: String
        let score: Double
        let maxScore: Double
        let color: SQColor
    }

    let totalScore: Double
    let scoreLabel: String
    let components: [Component]
    let isSliceSelectionEnabled: Bool

    init(
        totalScore: Double,
        scoreLabel: String,
        components: [Component],
        isSliceSelectionEnabled: Bool = true
    ) {
        self.totalScore = totalScore
        self.scoreLabel = scoreLabel
        self.components = components
        self.isSliceSelectionEnabled = isSliceSelectionEnabled

        super.init(rowId: .sleepScore, rowType: .sleepScore)
    }
}
