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
        SQAnalyticsManager.shared.track(.lifeScoreDetailOpened(
            viewModel: lifeScoreViewModel,
            sourceScreen: "dashboard"
        ))
        let controller = SQLifeScoreDetailController(viewModel: lifeScoreViewModel)
        state.hub.domainEvents.send(.pushDashboardRoute(.lifeScoreDetail(controller: controller)))
    }

    func handleRecoveryScoreInfoTap(row: SQDashboardBodyBatteryRowViewModel) {
        SQAnalyticsManager.shared.track(.dashboardItemOpened(
            itemType: "recovery_score",
            itemId: nil,
            sourceGroup: "recovery",
            score: row.score
        ))
        let controller = SQRecoveryScoreDetailController(viewModel: row)
        state.hub.domainEvents.send(.pushDashboardRoute(.recoveryScoreDetail(controller: controller)))
    }
}
