//
//  SQDashboardWorkoutPremiumInsightRowViewModel.swift
//  BeastFitness
//

import Foundation

@Observable @MainActor
final class SQDashboardWorkoutPremiumInsightRowViewModel: SQDashboardRowViewModel {
    let model: SQWorkoutPremiumInsightsModel
    let onScoreInfoTap: (SQWorkoutPremiumInsightScore) -> Void

    init(
        model: SQWorkoutPremiumInsightsModel,
        onScoreInfoTap: @escaping (SQWorkoutPremiumInsightScore) -> Void
    ) {
        self.model = model
        self.onScoreInfoTap = onScoreInfoTap
        super.init(rowId: .workoutPremiumInsights, rowType: .workoutPremiumInsights)
    }
}
