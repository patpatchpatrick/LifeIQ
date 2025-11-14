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
            ForEach(Array(viewModel.workoutGroupViewModels.enumerated()), id: \.1) { (index, workoutGroupViewModel) in
                
                SQDashboardWorkoutGroupView(viewModel: workoutGroupViewModel)
                    .padding(.top, index == 0 ? .SQSpace.s : 0)
                    .padding(.bottom, index == viewModel.workoutGroupViewModels.count - 1 ? .SQSpace.xl : 0)
                
                if index != viewModel.workoutGroupViewModels.count - 1 {
                    Divider()
                        .sqTintColor(.divider)
                        .padding(.top, .SQSpace.xl)
                        .padding(.bottom, .SQSpace.xl)
                }
            }
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            SQDashboardView.cardTitle(title: viewModel.sectionTitle)
                .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            
            workoutsStack
        }
    }
    
    var body: some View {
        mainStack
    }
}

#Preview {
    SQDashboardWeekSummaryTotalsSection(viewModel: .init(workouts: .mock, priorWeekWorkouts: .mock))
        .preferredColorScheme(.dark)
}
