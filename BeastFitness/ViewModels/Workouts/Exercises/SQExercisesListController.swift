//
//  SQExercisesListViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI
import Foundation

@MainActor
protocol SQExercisesListInterface {
}

// MARK: - Controller

@Observable @MainActor
final class SQExercisesListController: SQExercisesListInterface {
    var searchText = "" {
        didSet { searchTextUpdated(searchText) }
    }

    var navigationPath = NavigationPath()
    let state: ExercisesListStating
    private(set) var hasLoadedUI = false

    // Publicly consumed by the View
    private(set) var recentRows: [SQExercisesListItemViewModel] = []
    private(set) var otherRows: [SQExercisesListItemViewModel] = []

    // Backing stores (no “recent subtitle” applied)
    private(set) var allExercisesAlphabetical: [SQRawStrengthExercise] = []
    private(set) var onExerciseSelected: ((SQRawStrengthExercise) -> Void)? = nil

    @MainActor
    static let `default` = SQExercisesListController(state: SQAppState.shared.exercisesListState)

    init(
        state: ExercisesListStating,
        onExerciseSelected: ((SQRawStrengthExercise) -> Void)? = nil
    ) {
        self.state = state
        self.onExerciseSelected = onExerciseSelected

        self.allExercisesAlphabetical = SQExercisesManager.shared.exercises
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        rebuildSections(searchText: "")
    }

    // MARK: - Search

    private func searchTextUpdated(_ searchText: String) {
        rebuildSections(searchText: searchText)
    }

    // MARK: - Build sections

    private func rebuildSections(searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pull recents from manager (id -> Date)
        let recentMap = SQExercisesManager.shared.recentUsageById()

        // Filter first (search), then section into recents/others.
        let filteredExercises: [SQRawStrengthExercise] = {
            guard !trimmed.isEmpty else { return allExercisesAlphabetical }

            let tokens = trimmed
                .lowercased()
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)

            return allExercisesAlphabetical.filter { ex in
                // Add more fields if you want:
                // - aliases, equipment, muscle group, etc.
                let searchableText = "\(ex.name) \(ex.id)".lowercased()
                return tokens.allSatisfy { searchableText.contains($0) }
            }
        }()

        // Recent exercises (alphabetical)
        let recentExercises = filteredExercises
            .filter { recentMap[$0.id] != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Remaining exercises (alphabetical)
        let otherExercises = filteredExercises
            .filter { recentMap[$0.id] == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none

        self.recentRows = recentExercises.map { ex in
            let lastUsed = recentMap[ex.id]!
            // Build the row and override subtitle to show last used.
            // If your SQExercisesListItemViewModel already has subtitle set,
            // this will replace it. If you want to *append* instead, see note below.
            var vm = SQExercisesListItemViewModel(rawExercise: ex)
            vm.tag = "Last used \(formatter.string(from: lastUsed))"
            return vm
        }

        self.otherRows = otherExercises.map { SQExercisesListItemViewModel(rawExercise: $0) }
    }

    // MARK: - Actions

    func exerciseSelected(_ exercise: SQRawStrengthExercise) {
        onExerciseSelected?(exercise)
    }
}
