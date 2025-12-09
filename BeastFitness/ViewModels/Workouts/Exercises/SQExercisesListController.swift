//
//  SQExercisesListViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

@MainActor
protocol SQExercisesListInterface {
}

@Observable @MainActor
final class SQExercisesListController: SQExercisesListInterface {
    var navigationPath = NavigationPath()
    let state: ExercisesListStating
    private(set) var hasLoadedUI = false
    private(set) var rows: [SQExercisesListItemViewModel]
    
    @MainActor
    static var `default` = SQWorkoutsListController(state: AppState.shared.workoutsListState)
    
    init(state: ExercisesListStating) {
        self.state = state
        self.rows = SQExercisesManager.shared.exercises.map { .init(rawExercise: $0) }
    }
}
