//
//  SQDashboardWeekSummaryWorkoutsSectionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardWeekSummaryWorkoutsSectionViewModel {
    let sectionTitle: String
    let workoutGroupViewModels: [SQDashboardWorkoutGroupViewModel]
    
    init(workouts: [SQWorkoutable]) {
        self.sectionTitle = "Workouts"
        
        var workoutGroupViewModels = [SQDashboardWorkoutGroupViewModel]()
        for (activityType, workout) in workouts.workoutsByActivityType {
            workoutGroupViewModels.append(.init(workouts: .init(workouts: workouts)))
        }
        self.workoutGroupViewModels = workoutGroupViewModels
        
    }
}

@Observable @MainActor
final class SQDashboardWorkoutGroupViewModel: Identifiable {
    let id = UUID()
    let testTitle: String
    
    init(workouts: SQWorkouts) {
        testTitle = workouts.sumOutputString ?? "Hello"
    }
}
