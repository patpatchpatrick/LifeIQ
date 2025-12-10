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
    var isAddExerciseListSheetVisible: Bool { get }
    var exercises: [SQWorkoutSessionExerciseViewModel] { get }
    
    func toggleAddExerciseListSheetVisibility(_ isVisible: Bool)
    func displayAddExerciseListSheet()
    func updateExercises(to exercises: [SQWorkoutSessionExerciseViewModel])
    func appendExercises(_ exercises: [SQWorkoutSessionExerciseViewModel])
    func removeExercises(_ exercises: [SQWorkoutSessionExerciseViewModel])
}

@MainActor
@Observable final class WorkoutSessionState: WorkoutSessionStating {
    private let hub: EventHub
    private(set) var isAddExerciseListSheetVisible: Bool = false
    private(set) var exercises: [SQWorkoutSessionExerciseViewModel] = []
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func toggleAddExerciseListSheetVisibility(_ isVisible: Bool) {
        isAddExerciseListSheetVisible = isVisible
    }
    
    func displayAddExerciseListSheet() {
        isAddExerciseListSheetVisible = true
    }
    
    func updateExercises(to exercises: [SQWorkoutSessionExerciseViewModel]) {
        self.exercises = exercises
    }
    
    func appendExercises(_ exercises: [SQWorkoutSessionExerciseViewModel]) {
        self.exercises.append(contentsOf: exercises)
    }
    
    func removeExercises(_ exercises: [SQWorkoutSessionExerciseViewModel]) {
        let exerciseIdSet = Set(exercises.map { $0.id })
        self.exercises.removeAll(where: { exerciseIdSet.contains($0.id) })
    }
}
