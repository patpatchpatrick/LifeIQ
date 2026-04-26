//
//  SQLifeScoreDetailController.swift
//  BeastFitness
//

import Foundation

@MainActor
@Observable final class SQLifeScoreDetailController: Identifiable {
    let id = UUID().uuidString
    let viewModel: SQLifeScoreViewModel

    init(viewModel: SQLifeScoreViewModel) {
        self.viewModel = viewModel
    }
}

@MainActor
@Observable final class SQRecoveryScoreDetailController: Identifiable {
    let id = UUID().uuidString
    let viewModel: SQDashboardBodyBatteryRowViewModel

    init(viewModel: SQDashboardBodyBatteryRowViewModel) {
        self.viewModel = viewModel
    }
}
