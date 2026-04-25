//
//  SQDashboardInsightActionRowViewModel.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

@Observable
@MainActor
final class SQDashboardInsightActionRowViewModel: SQDashboardRowViewModel {
    let model: SQInsightAction

    init(model: SQInsightAction) {
        self.model = model
        super.init(rowId: .insightAction, rowType: .insightAction)
    }
}
