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
    func appendExercises(_ exercises: [SQWorkoutSessionExerciseViewModel])
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
    private(set) var exercises: [SQWorkoutSessionExerciseViewModel] = []
    private(set) var titleTextField: SQTextFieldViewModel?
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func load(workout: SQWorkoutSessionable?) {
        baseWorkout = workout
        
        let titleTextField = SQTextFieldViewModel(
            font: .init(type: .title3),
            uiConfig: .standard,
            placeholder: "Saturday Morning Weight Training",
            keyboardType: .default,
            textAutoCap: .sentences,
            autoCorrectionEnabled: false,
            textChangeFormatter: .maxLength(SQWorkoutSession.titleMaxChars),
            errorHandler: { _ in nil }
        )
        if let title = workout?.title {
            titleTextField.initializeText(title)
        }
        self.titleTextField = titleTextField
        
        switch workout?.details {
        case .strength(let details):
            
            let exercises = details.exercises.map { SQWorkoutSessionExerciseViewModel(
                from: $0,
                onRemoveExercise: { [weak self] exerciseId in
                    self?.removeExercises(.init([exerciseId]))
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
    
    func appendExercises(_ exercises: [SQWorkoutSessionExerciseViewModel]) {
        self.exercises.append(contentsOf: exercises)
    }
    
    func removeExercises(_ exercises: Set<UUID>) {
        withAnimation {
            self.exercises.removeAll(where: { exercises.contains($0.id) })
        }
    }
    
    func workoutUpdated(workout: any SQWorkoutSessionable) {
        hub.workoutEvents.send(.workoutsUpdated([workout.id: workout]))
    }
}
