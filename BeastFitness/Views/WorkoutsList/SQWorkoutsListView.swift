//
//  SQWorkoutsListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutsListView: View {
    @Bindable var controller: SQWorkoutsListController
    @State private var summaryControllerCache: [String: SQWorkoutSummaryController] = [:]
    
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
    
    private func cachedSummaryController(
            for workout: SQWorkoutSessionable
        ) -> SQWorkoutSummaryController {
            let key = workout.id

            if let cached = summaryControllerCache[key] {
                return cached
            }

            print("PTD Build Controller (view cache miss): \(key)")

            let created = SQWorkoutSummaryController.default(
                workout: workout,
                onPushEditWorkoutView: { workout in
                    controller.pushEditWorkoutView(for: workout)
                }
            )

            summaryControllerCache[key] = created
            return created
        }
    
    @ViewBuilder
    var navStack: some View {
        NavigationStack(path: $controller.navigationPath) {
            navView
                .navigationDestination(for: SQNavRoute.WorkoutsList.self) { route in
                    switch route {
                    case .workoutView(let workout):
                        SQWorkoutSummaryView(controller: cachedSummaryController(for: workout))
                    case .editWorkout(workout: let workout):
                        SQWorkoutSessionView(isBeingDisplayedWithinNavStack: true, controller: .default(for: workout, onDismiss: { self.controller.popView() }))
                    }
                }
        }
    }

    var body: some View {
        navStack
    }
}
