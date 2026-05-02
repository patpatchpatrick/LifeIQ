//
//  SQDashboardWorkoutPremiumInsightRowViewModel.swift
//  BeastFitness
//

import Foundation

@Observable @MainActor
final class SQDashboardWorkoutPremiumInsightRowViewModel: SQDashboardRowViewModel {
    let model: SQWorkoutPremiumInsightsModel
    let onScoreInfoTap: (SQWorkoutPremiumInsightScore) -> Void
    let onLockedTap: (() -> Void)?

    init(
        model: SQWorkoutPremiumInsightsModel,
        onScoreInfoTap: @escaping (SQWorkoutPremiumInsightScore) -> Void,
        onLockedTap: (() -> Void)? = nil
    ) {
        self.model = model
        self.onScoreInfoTap = onScoreInfoTap
        self.onLockedTap = onLockedTap
        super.init(rowId: .workoutPremiumInsights, rowType: .workoutPremiumInsights)
    }
}
