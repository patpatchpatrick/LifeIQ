//
//  SQDashboardWeekSummaryWorkoutsSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWeekSummaryWorkoutsSection: View {
    let viewModel: SQDashboardWeekSummaryWorkoutsSectionViewModel
    
    var workoutsStack: some View {
        VStack(spacing: .SQSpace.m) {
            ForEach(viewModel.workoutGroupViewModels) { workoutGroupViewModel in
                SQDashboardWorkoutGroupView(viewModel: workoutGroupViewModel)
            }
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            
            SQDashboardView.cardTitle(title: viewModel.sectionTitle)
            
            workoutsStack
        }
    }
    
    var body: some View {
        mainStack
    }
}

struct SQDashboardWorkoutGroupView: View {
    let viewModel: SQDashboardWorkoutGroupViewModel
    
    var body: some View {
        Text(viewModel.testTitle)
    }
}

#Preview {
    SQDashboardWeekSummaryRowTotalsSection(viewModel: .init(workouts: [SQMockWorkout.mockRun, SQMockWorkout.mockRun]))
        .preferredColorScheme(.dark)
}
