//
//  SQDashboardWeekSummaryRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardWeekSummaryRowViewModel: SQDashboardRowViewModel {
    let sectionTitle: String
    let workoutViewModels: [SQDashboardWorkoutViewModel]
    
    init(workouts: [SQWorkout]) {
        self.sectionTitle = "This Week"
        self.workoutViewModels = workouts.map { .init(workout: $0) }
        super.init(rowType: .weekSummary)
    }
}

@Observable @MainActor
final class SQDashboardWorkoutViewModel: Identifiable {
    let id = UUID()
    let testTitle: String
    
    init(workout: SQWorkout) {
        var testTitle: String = ""
        testTitle = "\(workout.activityType.name)"
        if let startDate = workout.startDate {
            testTitle += "-\(SQDateFormatters.shared.dateShortFormatter.string(from: startDate))"
        } else {
            testTitle += "-NoDate"
        }
        testTitle += "-\(workout.outputString ?? "")"
        self.testTitle = testTitle
    }
}
