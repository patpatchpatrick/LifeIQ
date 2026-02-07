//
//  SQDashboardActivityListRowView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//

import SwiftUI

struct SQDashboardActivityListRowView: View {
    @Bindable var viewModel: SQDashboardActivityRowViewModel
    
    var workoutsStack: some View {
        VStack(spacing: .SQSpace.m) {
            ForEach(Array(viewModel.workoutGroupViewModels.enumerated()), id: \.1) { (index, workoutGroupViewModel) in
                
                
                SQDashboardWorkoutGroupView(viewModel: workoutGroupViewModel)
                    .padding(.top, index == 0 ? .SQSpace.s : 0)
                    .padding(.bottom, index == viewModel.workoutGroupViewModels.count - 1 ? .SQSpace.xl : 0)
                
                if index != viewModel.workoutGroupViewModels.count - 1 {
                    Divider()
                        .sqTintColor(.divider(1))
                        .padding(.top, .SQSpace.xl)
                        .padding(.bottom, .SQSpace.xl)
                }
            }
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {

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
