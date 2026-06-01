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
        let detailText: AttributedString
    }

    let totalScore: Double
    let scoreLabel: String
    let scoreValueLabel: String
    let components: [Component]
    let isSliceSelectionEnabled: Bool
    let trendDelta: SQDashboardTrendDeltaViewModel?
    var selectedComponentId: String?

    init(
        totalScore: Double,
        scoreLabel: String,
        scoreValueLabel: String = "Sleep Score",
        components: [Component],
        isSliceSelectionEnabled: Bool = true,
        trendDelta: SQDashboardTrendDeltaViewModel? = nil
    ) {
        self.totalScore = totalScore
        self.scoreLabel = scoreLabel
        self.scoreValueLabel = scoreValueLabel
        self.components = components
        self.isSliceSelectionEnabled = isSliceSelectionEnabled
        self.trendDelta = trendDelta
        self.selectedComponentId = nil

        super.init(rowId: .sleepScore, rowType: .sleepScore)
    }

    func toggleSelection(for componentId: String?) {
        guard isSliceSelectionEnabled else { return }
        if selectedComponentId == componentId {
            selectedComponentId = nil
        } else {
            selectedComponentId = componentId
        }
    }
}
