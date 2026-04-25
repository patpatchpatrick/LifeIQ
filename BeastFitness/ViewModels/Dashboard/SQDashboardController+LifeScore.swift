//
//  SQDashboardController+LifeScore.swift
//  BeastFitness
//

import Foundation

extension SQDashboardController {
    func handleLifeScoreTap() {
        guard let lifeScoreViewModel else { return }
        SQAnalyticsManager.shared.track(.dashboardItemOpened(
            itemType: "life_score",
            itemId: nil,
            sourceGroup: "daily_stats",
            score: lifeScoreViewModel.score
        ))
        let controller = SQLifeScoreDetailController(viewModel: lifeScoreViewModel)
        state.hub.domainEvents.send(.pushDashboardRoute(.lifeScoreDetail(controller: controller)))
    }
}
