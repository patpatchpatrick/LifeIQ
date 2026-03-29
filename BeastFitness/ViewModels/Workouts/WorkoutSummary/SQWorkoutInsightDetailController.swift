//
//  SQWorkoutInsightDetailController.swift
//  BeastFitness
//

import Foundation

@MainActor
@Observable final class SQWorkoutInsightDetailController: Identifiable {
    let id = UUID().uuidString
    let model: SQWorkoutPremiumInsightDetailModel

    init(model: SQWorkoutPremiumInsightDetailModel) {
        self.model = model
    }
}
