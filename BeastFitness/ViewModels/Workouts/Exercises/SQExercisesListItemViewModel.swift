//
//  SQExercisesListItem.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

@Observable @MainActor
final class SQExercisesListItemViewModel: Identifiable, Hashable, Equatable {
    let id = UUID()
    let rawExercise: SQRawStrengthExercise
    let title: String
    let subtitle: String
    var tag: String? = nil
    
    init(rawExercise: SQRawStrengthExercise) {
        self.rawExercise = rawExercise
        self.title = rawExercise.name
        self.subtitle = rawExercise.primaryMuscles
            .map { $0.rawValue.capitalized }
            .joined(separator: ", ")
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: SQExercisesListItemViewModel, rhs: SQExercisesListItemViewModel) -> Bool {
        lhs.id == rhs.id
    }
}
