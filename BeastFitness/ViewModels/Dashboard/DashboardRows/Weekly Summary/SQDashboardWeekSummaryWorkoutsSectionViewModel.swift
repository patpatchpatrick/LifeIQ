//
//  SQDashboardWeekSummaryWorkoutsSectionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI
import HealthKit

@Observable @MainActor
final class SQDashboardWeekSummaryWorkoutsSectionViewModel {
    let sectionTitle: String
    let workoutGroupViewModels: [SQDashboardWorkoutGroupViewModel]
    
    init(workouts: [SQWorkoutable]) {
        self.sectionTitle = "Workouts"
        
        var workoutGroupViewModels = [SQDashboardWorkoutGroupViewModel]()
        for (activityType, workouts) in workouts.workoutsByActivityType.sorted(by: { $0.value.count > $1.value.count }) {
            workoutGroupViewModels.append(.init(activityType: activityType, workouts: .init(workouts: workouts)))
        }
        self.workoutGroupViewModels = workoutGroupViewModels
        
    }
}

@Observable @MainActor
final class SQDashboardWorkoutGroupViewModel: Identifiable, Hashable, Equatable {
    let id = UUID()
    let title: String
    let workoutImageSymbol: SQImageSymbol
    
    init(activityType: HKWorkoutActivityType, workouts: SQWorkouts) {
        title = "\(workouts.workouts.count) \(activityType.name)"
        workoutImageSymbol = workouts.workouts.compactMap { $0.activityType.imageSymbol }.first ?? .questionmarkCircle
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: SQDashboardWorkoutGroupViewModel, rhs: SQDashboardWorkoutGroupViewModel) -> Bool {
        lhs.id == rhs.id
    }
}
