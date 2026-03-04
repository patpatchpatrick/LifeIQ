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
    let subtitle: String
    let components: [Component]

    init(
        totalScore: Double,
        scoreLabel: String,
        subtitle: String,
        components: [Component]
    ) {
        self.totalScore = totalScore
        self.scoreLabel = scoreLabel
        self.subtitle = subtitle
        self.components = components

        super.init(rowId: .sleepScore, rowType: .sleepScore)
    }
}
