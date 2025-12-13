//
//  SQWorkoutsListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutsListView: View {
    @State private var summaryControllers: [UUID: SQWorkoutSummaryController] = [:]
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
    
    private func summaryController(for workout: SQWorkoutSessionable) -> SQWorkoutSummaryController {
        if let existing = summaryControllers[workout.id] { return existing }
        let created = SQWorkoutSummaryController.default(workout: workout, onPushEditWorkoutView: { workout in
            self.controller.pushEditWorkoutView(for: workout)
        })
        summaryControllers[workout.id] = created
        return created
    }
    
    @ViewBuilder
    var navStack: some View {
        NavigationStack(path: $controller.navigationPath) {
            navView
                .navigationDestination(for: SQNavRoute.WorkoutsList.self) { route in
                    switch route {
                    case .workoutView(let workout):
                        SQWorkoutSummaryView(controller: summaryController(for: workout))
                    case .editWorkout(workout: let workout):
                        SQWorkoutSessionView(isBeingDisplayedWithinNavStack: true, controller: .default(for: workout))
                    }
                }
        }
    }

    var body: some View {
        navStack
    }
}
