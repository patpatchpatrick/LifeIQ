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
    
    func toggleAddExerciseListSheetVisibility(_ isVisible: Bool)
    func displayAddExerciseListSheet()
}

@MainActor
@Observable final class WorkoutSessionState: WorkoutSessionStating {
    private let hub: EventHub
    private(set) var isAddExerciseListSheetVisible: Bool = false
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func toggleAddExerciseListSheetVisibility(_ isVisible: Bool) {
        isAddExerciseListSheetVisible = isVisible
    }
    
    func displayAddExerciseListSheet() {
        isAddExerciseListSheetVisible = true
    }
}
