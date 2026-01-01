//
//  SQDashboardWorkoutSummaryWorkoutsSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryWorkoutsSection: View {
    let viewModel: SQDashboardWorkoutSummaryWorkoutsSectionViewModel
    
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
            
            if let ctaViewModel = viewModel.ctaViewModel {
                SQCallToAction(viewModel: ctaViewModel)
            }
        }
    }
    
    var body: some View {
        mainStack
    }
}

#Preview {
    SQDashboardWorkoutSummaryTotalsSection(viewModel: .init(config: .mock, workouts: .mock, priorWorkouts: .mock))
        .preferredColorScheme(.dark)
}
