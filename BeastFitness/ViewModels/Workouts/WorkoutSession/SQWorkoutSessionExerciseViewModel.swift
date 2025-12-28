//
//  SQWorkoutSessionExerciseViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/15/25.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SQWorkoutSessionExerciseViewModel: Identifiable {
    let id: UUID
    let rawExerciseId: String
    var name: String
    var muscleGroup: SQMuscleGroup
    let onRemoveExercise: ((UUID) -> Void)?
    private(set) var sets: [SQWorkoutSessionSetViewModel]
    
    init(
        id: UUID = UUID(),
        rawExerciseId: String,
        name: String,
        muscleGroup: SQMuscleGroup,
        sets: [SQWorkoutSessionSetViewModel],
        onRemoveExercise: ((UUID) -> Void)?
    ) {
        self.id = id
        self.rawExerciseId = rawExerciseId
        self.name = name
        self.muscleGroup = muscleGroup
        self.sets = sets
        self.onRemoveExercise = onRemoveExercise
        renumberSets()
    }
    
    /// New exercise with 3 default sets
    convenience init(
        name: String,
        rawExerciseId: String,
        muscleGroup: SQMuscleGroup,
        defaultSetCount: Int = 3,
        defaultReps: Int = 8,
        defaultWeight: Double = 50,
        onRemoveExercise: ((UUID) -> Void)?
    ) {
        let setVMs = (1...defaultSetCount).map { index in
            SQWorkoutSessionSetViewModel(
                setIndex: index,
                initialReps: defaultReps,
                initialWeight: defaultWeight
            )
        }
        
        self.init(
            rawExerciseId: rawExerciseId,
            name: name,
            muscleGroup: muscleGroup,
            sets: setVMs,
            onRemoveExercise: onRemoveExercise
        )
    }
    
    convenience init(from model: SQStrengthExercise, onRemoveExercise: ((UUID) -> Void)?) {
        let setVMs = model.sets
            .sorted { $0.setIndex < $1.setIndex }
            .map { SQWorkoutSessionSetViewModel(from: $0) }
        
        self.init(
            id: model.id,
            rawExerciseId: model.rawExerciseId,
            name: model.name,
            muscleGroup: model.muscleGroup,
            sets: setVMs,
            onRemoveExercise: onRemoveExercise
        )
    }
    
    // MARK: - Derived
    
    var isCompleted: Bool {
        !sets.isEmpty && sets.allSatisfy { $0.isCompleted }
    }
    
    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }
    
    // MARK: - Mutations
    
    func addSet(copyLast: Bool = true) {
        
        print("ADD SET on exerciseVM:", id, "instance:", ObjectIdentifier(self), "oldCount:", sets.count)
        
        let nextIndex = sets.count + 1
        
        if copyLast, let last = sets.last {
            let newSet = SQWorkoutSessionSetViewModel(
                setIndex: nextIndex,
                initialReps: last.reps,
                initialWeight: last.weight
            )
            sets.append(newSet)
        } else {
            let newSet = SQWorkoutSessionSetViewModel(
                setIndex: nextIndex,
                initialReps: 8,
                initialWeight: 50
            )
            sets.append(newSet)
        }
        
        renumberSets()
        
        // ... append ...
        print("newCount:", sets.count)
    }
    
    func removeSet(_ set: SQWorkoutSessionSetViewModel) {
        sets.removeAll { $0.id == set.id }
        renumberSets()
    }
    
    private func renumberSets() {
        for (idx, vm) in sets.enumerated() {
            vm.setIndex = idx + 1
        }
    }
    
    func asModel() -> SQStrengthExercise {
        SQStrengthExercise(
            id: id,
            rawExerciseId: rawExerciseId,
            name: name,
            muscleGroup: muscleGroup,
            sets: sets
                .sorted { $0.setIndex < $1.setIndex }
                .map { $0.asModel() }
        )
    }
    
    func deleteExercise() {
        onRemoveExercise?(self.id)
    }
}
