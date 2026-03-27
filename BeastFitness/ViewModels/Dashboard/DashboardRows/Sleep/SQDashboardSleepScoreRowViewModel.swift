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
    let components: [Component]
    let isSliceSelectionEnabled: Bool
    var selectedComponentId: String?

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
