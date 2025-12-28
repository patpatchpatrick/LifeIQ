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
    var searchText = "" {
        didSet {
            searchTextUpdated(searchText)
        }
    }
    var navigationPath = NavigationPath()
    let state: ExercisesListStating
    private(set) var hasLoadedUI = false
    private(set) var rows: [SQExercisesListItemViewModel]
    private(set) var allRows: [SQExercisesListItemViewModel]
    private(set) var onExerciseSelected: ((SQRawStrengthExercise) -> Void)? = nil
    
    @MainActor
    static let `default` = SQExercisesListController(state: AppState.shared.exercisesListState)
    
    init(state: ExercisesListStating, onExerciseSelected: ((SQRawStrengthExercise) -> Void)? = nil) {
        self.state = state
        let allRows: [SQExercisesListItemViewModel] = SQExercisesManager.shared.exercises
            .sorted { $0.name < $1.name }
            .map { .init(rawExercise: $0) }
        self.rows = allRows
        self.allRows = allRows
        self.onExerciseSelected = onExerciseSelected
    }
    
    private func searchTextUpdated(_ searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rows = allRows
            return
        }

        let tokens = trimmed
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        rows = allRows
            .filter { row in
                let searchableText = [
                    row.title,
                    row.subtitle
                ]
                    .joined(separator: " ")
                    .lowercased()
                
                // ✅ All tokens must be present somewhere
                return tokens.allSatisfy { searchableText.contains($0) }
            }
            .sorted {
                $0.title < $1.title
            }
    }
    
    func exerciseSelected(_ exercise: SQRawStrengthExercise) {
        onExerciseSelected?(exercise)
    }
}
