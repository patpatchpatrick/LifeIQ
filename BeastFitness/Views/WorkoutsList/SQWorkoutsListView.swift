//
//  SQWorkoutsListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutsListView: View {
    @Bindable var controller: SQWorkoutsListController
    
    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xl) {
            ForEach(controller.rows) { row in
                Button(
                    action: { controller.displayWorkoutSummary(for: row) },
                    label: { SQWorkoutsListItem(viewModel: row) })
            }
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        ScrollView {
            mainStack
                .padding(.SQSpace.xl)
        }
    }
    
    var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.backgroundSecondary.color)
    }
    
    @ViewBuilder
    var navStack: some View {
        NavigationStack(path: $controller.navigationPath) {
            navView
                .navigationDestination(for: SQNavRoute.WorkoutsList.self) { route in
                    switch route {
                    case .workoutView(let workout):
                        SQWorkoutSummaryView(controller: .init(workout: workout))
                    }
                }
        }
    }

    var body: some View {
        navStack
    }
}
