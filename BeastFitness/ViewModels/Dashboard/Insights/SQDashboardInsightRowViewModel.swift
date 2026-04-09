//
//  SQDashboardInsightRowViewModel.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

@Observable @MainActor
final class SQDashboardInsightRowViewModel: SQDashboardRowViewModel {
    let model: SQInsight
    let isLocked: Bool
    let onInfoTap: (() -> Void)?

    init(
        model: SQInsight,
        isLocked: Bool = false,
        onInfoTap: (() -> Void)? = nil
    ) {
        self.model = model
        self.isLocked = isLocked
        self.onInfoTap = onInfoTap
        super.init(rowId: .insight, rowType: .insight)
    }
}
