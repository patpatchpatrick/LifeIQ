//
//  SQWorkoutSessionView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI

import SwiftUI

struct SQWorkoutSessionView: View {
    @Bindable var viewModel: SQWorkoutSessionViewModel
    
    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xl) {
            if viewModel.exercises.isEmpty {
                Text("Add an exercise to get started.")
                    .sqFont(.body)
                    .sqForegroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, .SQSpace.xl)
            } else {
                ForEach(viewModel.exercises) { exerciseVM in
                    SQWorkoutSessionExerciseRow(viewModel: exerciseVM)
                }
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
    
    var body: some View {
        NavigationStack {
            mainScroll
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Workout")
                .navigationBarTitleDisplayMode(.inline)
                .background(SQColor.backgroundSecondary.color)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // PTD add back addExercise() functionality
//                            viewModel.addExercise()
                            viewModel.state.displayAddExerciseListSheet()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: .init(
                    get: { viewModel.state.isAddExerciseListSheetVisible },
                    set: { isVisible in viewModel.state.toggleAddExerciseListSheetVisibility(isVisible)})) {
                        SQExercisesListView(controller: .init(state: AppState.shared.exercisesListState))
                    }
        }
    }
}

