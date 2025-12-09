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
    let title: String
    
    init(rawExercise: SQRawStrengthExercise) {
        self.title = rawExercise.name
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: SQExercisesListItemViewModel, rhs: SQExercisesListItemViewModel) -> Bool {
        lhs.id == rhs.id
    }
}
