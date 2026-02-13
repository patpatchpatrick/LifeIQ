//
//  SQLeaderboardRowViewModel.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI
import BeastFitnessCore

@Observable @MainActor
final class SQLeaderboardRowViewModel: Identifiable {
    let id: String
    let rank: Int
    let workout: SQWorkoutSessionable
    let metric: SQWorkoutMetric
    let quantityType: SQQuantityType

    var workoutTitle: String {
        workout.title ?? "Workout"
    }

    var workoutDate: String {
        guard let startDate = workout.startDate else { return "Unknown date" }
        return startDate.formattedString(with: .medium)
    }

    var formattedScore: String {
        metric.displayableValue(for: quantityType, value: metric.value)
    }

    var unitString: String {
        metric.unit.unitString ?? ""
    }

    init(rank: Int, workout: SQWorkoutSessionable, metric: SQWorkoutMetric, quantityType: SQQuantityType) {
        self.id = workout.id
        self.rank = rank
        self.workout = workout
        self.metric = metric
        self.quantityType = quantityType
    }
}
