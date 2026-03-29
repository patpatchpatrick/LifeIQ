//
//  SQDashboardWorkoutPremiumInsightRowViewModel.swift
//  BeastFitness
//

import Foundation

@Observable @MainActor
final class SQDashboardWorkoutPremiumInsightRowViewModel: SQDashboardRowViewModel {
    let model: SQWorkoutPremiumInsightsModel

    init(model: SQWorkoutPremiumInsightsModel) {
        self.model = model
        super.init(rowId: .workoutPremiumInsights, rowType: .workoutPremiumInsights)
    }
}
