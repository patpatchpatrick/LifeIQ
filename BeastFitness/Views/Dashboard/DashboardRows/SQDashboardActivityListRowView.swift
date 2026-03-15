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

//
//  SQDashboardWorkoutGroupView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWorkoutGroupView: View {
    let viewModel: SQDashboardWorkoutGroupViewModel
    
    @ViewBuilder
    var workoutImage: some View {
        ZStack {
            Circle()
                .sqForegroundColor(.backgroundSecondaryLight)
                .frame(width: 40)
            
            SQImageView(image: .init(symbol: viewModel.workoutImageSymbol, symbolStyle: .colorWithFont(.textPrimary, font: .body)))
                .frame(width: 20)
        }
    }
    
    @ViewBuilder
    var workoutTitleAndDescription: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text(viewModel.title)
                .sqFont(.bodyBold)
                .sqForegroundColor(.textPrimary)
            
            if let subtitle = viewModel.subtitle {
                Text(subtitle)
                    .sqFont(.body)
                    .sqForegroundColor(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Text(viewModel.workoutStatsString)
        }
    }
    
    var mainHStack: some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            
            workoutImage
            
            workoutTitleAndDescription
            
            Spacer()
        }
    }
    
    var body: some View {
        Button(
            action: viewModel.displayWorkoutsSheet,
            label: { mainHStack })
    }
}

#Preview {
    SQDashboardWorkoutGroupView(viewModel: .init(activityType: .running, workouts: .init(workouts: .mock)))
        .preferredColorScheme(.dark)
}
