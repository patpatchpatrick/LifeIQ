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
        List {
            ForEach(Array(controller.rows.enumerated()), id: \.1) { (index, row) in
                
                VStack(spacing: 0) {
                    Button(
                        action: { controller.displayWorkoutSummary(for: row) },
                        label: { SQWorkoutsListItem(viewModel: row) })
                    
                    if index != controller.rows.count - 1 {
                        Divider()
                            .sqTintColor(.divider)
                            .padding(.top, .SQSpace.xl)
                            .padding(.bottom, .SQSpace.xl)
                            .background(SQColor.background.color)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.background.color)
    }
    
    private func buildController(for workout: SQWorkoutSessionable) -> SQWorkoutSummaryController {
        let controller = SQWorkoutSummaryController.default
        controller.load(workout: workout)
        return controller
    }
    
    @ViewBuilder
    var navStack: some View {
        NavigationStack(path: $controller.navigationPath) {
            navView
                .navigationDestination(for: SQNavRoute.WorkoutsList.self) { route in
                    switch route {
                    case .workoutView(let workout):
                        SQWorkoutSummaryView(controller: buildController(for: workout))
                    }
                }
        }
    }

    var body: some View {
        navStack
    }
}
