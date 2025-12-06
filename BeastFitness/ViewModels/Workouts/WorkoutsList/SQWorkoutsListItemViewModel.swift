//
//  SQWorkoutsListItemViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

@Observable @MainActor
final class SQWorkoutsListItemViewModel: Identifiable, Hashable, Equatable {
    let id = UUID()
    let title: String
    let workoutImageSymbol: SQImageSymbol
    let workoutStatsString: AttributedString
    
    init(workout: SQWorkoutSessionable) {
        let activityType = workout.activityType
        title = "\(activityType.name)"
        workoutImageSymbol = activityType.imageSymbol
        
        self.workoutStatsString = .init("Hello here goes the summary")
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: SQWorkoutsListItemViewModel, rhs: SQWorkoutsListItemViewModel) -> Bool {
        lhs.id == rhs.id
    }
}
