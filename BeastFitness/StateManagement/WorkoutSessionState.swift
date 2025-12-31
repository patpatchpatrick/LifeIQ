//
//  WorkoutSessionState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//


import SwiftUI
import Combine

@MainActor
protocol WorkoutSessionStating: AnyObject {
    var hub: EventHub { get }
    var isAddExerciseListSheetVisible: Bool { get }
    var isRestTimerSheetVisible: Bool { get }
    var baseWorkout: SQWorkoutSessionable? { get }
    var exercises: [SQWorkoutSessionExerciseViewModel] { get }
    
    var titleTextField: SQTextFieldViewModel? { get }
    
    func toggleAddExerciseListSheetVisibility(_ isVisible: Bool)
    func displayAddExerciseListSheet()
    func toggleRestTimerSheetVisibility(_ isVisible: Bool)
    func displayRestTimerSheet()
    func updateExercises(to exercises: [SQWorkoutSessionExerciseViewModel])
    func appendExercises(_ exercises: [SQRawStrengthExercise])
    func removeExercises(_ exercises: Set<UUID>)
    
    func load(workout: SQWorkoutSessionable?)
    func workoutUpdated(workout: SQWorkoutSessionable)
}

@MainActor
@Observable final class WorkoutSessionState: WorkoutSessionStating {
    let hub: EventHub

    private(set) var baseWorkout: SQWorkoutSessionable?
    
    private(set) var isAddExerciseListSheetVisible: Bool = false
    private(set) var isRestTimerSheetVisible: Bool = false
    private(set) var exercises: [SQWorkoutSessionExerciseViewModel] = [] {
        didSet {
            workoutChanged()
        }
    }
    private(set) var titleTextField: SQTextFieldViewModel?
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func load(workout: SQWorkoutSessionable?) {
        baseWorkout = workout
        let placeholderTitle = "\(Date.now.dayAndTimeTitle()) Weight Training"
        let initialText = workout?.title ?? placeholderTitle
        
        let titleTextField = SQTextFieldViewModel(
            font: .init(type: .title3),
            uiConfig: .standard,
            placeholder: placeholderTitle,
            keyboardType: .default,
            textAutoCap: .sentences,
            autoCorrectionEnabled: false,
            textChangeFormatter: .maxLength(SQWorkoutSession.titleMaxChars),
            errorHandler: { _ in nil }
        )
    
        titleTextField.initializeText(initialText)
    
        self.titleTextField = titleTextField
        
        switch workout?.details {
        case .strength(let details):
            
            let exercises = details.exercises.map { SQWorkoutSessionExerciseViewModel(
                from: $0,
                onRemoveExercise: { [weak self] exerciseId in
                    self?.removeExercises(.init([exerciseId]))
                },
                onChanged: { [weak self] in
                    self?.workoutChanged()
                }) }
            self.updateExercises(to: exercises)
            
        case .none:
            self.updateExercises(to: [])
            break
        }
    }
    
    func toggleAddExerciseListSheetVisibility(_ isVisible: Bool) {
        isAddExerciseListSheetVisible = isVisible
    }
    
    func displayAddExerciseListSheet() {
        isAddExerciseListSheetVisible = true
    }
    
    func toggleRestTimerSheetVisibility(_ isVisible: Bool) {
        isRestTimerSheetVisible = isVisible
    }
    
    func displayRestTimerSheet() {
        isRestTimerSheetVisible = true
    }
    
    func updateExercises(to exercises: [SQWorkoutSessionExerciseViewModel]) {
        self.exercises = exercises
    }
    
    func appendExercises(_ exercises: [SQRawStrengthExercise]) {
        
        let viewModels = exercises.map { rawExercise in
            return SQWorkoutSessionExerciseViewModel(
                name: rawExercise.name,
                rawExerciseId: rawExercise.id,
                muscleGroup: rawExercise.primaryMuscles.first ?? .unknown,
                onRemoveExercise: { [weak self] exerciseId in
                    self?.removeExercises([exerciseId])
                },
                onChanged: {
                    [weak self] in
                    self?.workoutChanged()
                }
            )
        }
        
        self.exercises.append(contentsOf: viewModels)
    }
    
    func removeExercises(_ exercises: Set<UUID>) {
        withAnimation {
            self.exercises.removeAll(where: { exercises.contains($0.id) })
        }
    }
    
    private func workoutChanged() {

        let current = exercises
            .compactMap { exercise -> (SQWorkoutSessionExerciseViewModel, Int)? in
                guard let idx = exercise.sets.firstIndex(where: { !$0.isCompleted }) else {
                    return nil
                }
                return (exercise, idx)
            }
            .first

        let exercise = current?.0
        let setIndex = current?.1

        hub.workoutEvents.send(
            .activeWorkoutUpdate(
                .init(
                    activeExercise: exercise,
                    activeSetIndex: setIndex
                )
            )
        )
    }

    
    func workoutUpdated(workout: any SQWorkoutSessionable) {
        hub.workoutEvents.send(.workoutsUpdated([workout.id: workout]))
    }
}
