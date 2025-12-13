//
//  SQWorkoutSessionView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI

struct SQWorkoutSessionView: View {
    let isBeingDisplayedWithinNavStack: Bool
    @Bindable var controller: SQWorkoutSessionController

    // MARK: - Sections

    @ViewBuilder
    private var workoutHeaderSection: some View {
        if let titleTextField = controller.state.titleTextField {
            SQTextField(viewModel: titleTextField)
                .listRowInsets(EdgeInsets(
                    top: .SQSpace.m,
                    leading: .SQSpace.xl,
                    bottom: .SQSpace.m,
                    trailing: .SQSpace.xl
                ))
                .listRowBackground(SQColor.background.color)
        }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        if controller.state.exercises.isEmpty {
            Text("Add an exercise to get started.")
                .sqFont(.body)
                .sqForegroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, .SQSpace.xl)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } else {
            ForEach(controller.state.exercises) { exerciseVM in
                SQWorkoutSessionExerciseRow(viewModel: exerciseVM)
            }
        }
    }

    @ViewBuilder
    private var addExerciseRow: some View {
        HStack {
            SQButton(
                style: .secondary,
                shouldHugContent: false,
                title: "Add Exercise",
                icon: .plus
            ) {
                controller.state.displayAddExerciseListSheet()
            }

            Spacer(minLength: 0)
        }
        .listRowInsets(EdgeInsets(
            top: .SQSpace.m,
            leading: .SQSpace.xl,
            bottom: .SQSpace.m,
            trailing: .SQSpace.xl
        ))
        .listRowBackground(SQColor.background.color)
    }

    // MARK: - Actions

    private func finishWorkout() {
        print("PTD Funish workout")
        // PTD: Save workout to CoreData + Firestore later
    }

    // MARK: - Body
    
    private var mainList: some View {
        List {
            workoutHeaderSection
            exercisesSection
            addExerciseRow // bottom of list
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sqBackgroundColor(.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .background(SQColor.backgroundSecondary.color)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    finishWorkout()
                } label: {
                    Image(systemName: "checkmark")
                }
            }
        }
        .sheet(isPresented: .init(
            get: { controller.state.isAddExerciseListSheetVisible },
            set: { isVisible in
                controller.state.toggleAddExerciseListSheetVisibility(isVisible)
            }
        )) {
            SQExercisesListView(controller: .init(
                state: AppState.shared.exercisesListState,
                onExerciseSelected: { rawExercise in
                    controller.addExercise(rawExercise: rawExercise)
                    controller.state.toggleAddExerciseListSheetVisibility(false)
                }
            ))
        }
    }

    var body: some View {
        /// We're already within a nav stack, so we can't wrap the list in another nav stack
        if isBeingDisplayedWithinNavStack {
            mainList
        } else {
            NavigationStack {
                mainList
            }
        }
    }
}
