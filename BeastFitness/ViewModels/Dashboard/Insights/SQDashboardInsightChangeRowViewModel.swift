//
//  SQDashboardInsightChangeRowViewModel.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

@Observable @MainActor
final class SQDashboardInsightChangeRowViewModel: SQDashboardRowViewModel {
    let model: SQInsightChange

    init(model: SQInsightChange) {
        self.model = model
        super.init(rowId: .insightChange, rowType: .insightChange)
    }
}
