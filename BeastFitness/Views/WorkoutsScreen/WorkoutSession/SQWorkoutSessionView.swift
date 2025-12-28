//
//  SQWorkoutSessionView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI
import SwiftData

struct SQWorkoutSessionView: View {
    let isBeingDisplayedWithinNavStack: Bool
    @Bindable var controller: SQWorkoutSessionController
    @Environment(\.modelContext) private var modelContext
    @State private var isRestTimerPresented: Bool = false

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
            VStack(spacing: .SQSpace.xl) {
                ForEach(controller.state.exercises) { exerciseVM in
                    SQWorkoutSessionExerciseRow(viewModel: exerciseVM)
                }
            }
        }
    }

    @ViewBuilder
    private var addExerciseRow: some View {
        SQButton(
            style: .secondary,
            shouldHugContent: false,
            title: "Add Exercise",
            icon: .plus
        ) {
            controller.state.displayAddExerciseListSheet()
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
        Task {
            await controller.saveWorkout(to: modelContext)
        }
    }
    
    @ViewBuilder
    var scrollContent: some View {
        VStack(spacing: 0) {
            
            workoutHeaderSection
                .padding(.bottom, .SQSpace.xl)
            
            exercisesSection
                .padding(.bottom, .SQSpace.xl)
            
            addExerciseRow
            
            Spacer()
        }
        .padding(.horizontal, .SQSpace.xl)
    }

    // MARK: - Body
    
    private var mainList: some View {
        ScrollView {
            scrollContent
        }
        .scrollContentBackground(.hidden)
        .sqBackgroundColor(.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(
            controller.navBarTimeString
        )
        .navigationBarTitleDisplayMode(.inline)
        .background(SQColor.backgroundSecondary.color)
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 0) {
                    if controller.displayDiscardButton {
                        Button {
                            controller.discardWorkout()
                        } label: {
                            Image(systemName: SQImageSymbol.xCircle.rawValue)
                        }
                    }
                    
                    Button {
                        finishWorkout()
                    } label: {
                        Image(systemName: SQImageSymbol.checkmark.rawValue)
                    }
                }
            }

            if controller.workoutMode.shouldDisplayTimer {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 0) {
                        Button {
                            controller.timerViewModel.workoutTimerButtonConfig.action()
                        } label: {
                            Image(systemName: controller.timerViewModel.workoutTimerButtonConfig.icon?.rawValue ?? "")
                        }
                        
                        Button {
                            controller.state.displayRestTimerSheet()
                        } label: {
                            Text("Rest")
                        }
                    }
                }
            }
        }
        .onAppear {
            controller.onAppear()
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
        .sheet(isPresented: .init(
            get: { controller.state.isRestTimerSheetVisible },
            set: { isVisible in
                controller.state.toggleRestTimerSheetVisibility(isVisible)
            }
        )) {
            SQRestTimerView(viewModel: controller.restTimerViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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

private struct SQRestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SQWorkoutSessionRestTimerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.remainingString)
                .font(.headline)
                .monospacedDigit()

            Button(viewModel.buttonConfig.text) {
                viewModel.buttonConfig.action()
            }

            Button("Close") { dismiss() }
        }
        .frame(width: 260, height: 260)
        .background(SQColor.background.color)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
