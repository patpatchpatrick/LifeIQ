//
//  SQWorkoutSessionSetViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/15/25.
//

import SwiftUI
import Foundation


@Observable
@MainActor
final class SQWorkoutSessionSetViewModel: Identifiable {
    let id: UUID
    var setIndex: Int
    
    let repsTextFieldViewModel: SQTextFieldViewModel
    let weightTextFieldViewModel: SQTextFieldViewModel
    
    var isCompleted: Bool = false {
        didSet {
            onChanged()
        }
    }
    
    /// Called whenever the data is changed.  And update will be sent out to sync data with DB + watch
    let onChanged: () -> Void
    
    init(
        id: UUID = UUID(),
        isCompleted: Bool = false,
        setIndex: Int,
        initialReps: Int = 8,
        initialWeight: Double = 50,
        onChanged: @escaping () -> Void
    ) {
        self.id = id
        self.setIndex = setIndex
        self.isCompleted = isCompleted
        self.onChanged = onChanged
        
        // Reps: integer, 1...1000
        let repsVM = SQTextFieldViewModel(
            lineLimit: 1,
            placeholder: "Reps",
            keyboardType: .numberPad,
            textChangeFormatter: .integer,
            errorHandler: { _ in nil }
        )
        repsVM.text = "\(initialReps)"
        self.repsTextFieldViewModel = repsVM
        
        // Weight: decimal, 0...2000
        let weightVM = SQTextFieldViewModel(
            lineLimit: 1,
            placeholder: "lbs",
            keyboardType: .decimalPad,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            errorHandler: { _ in nil }
        )
        weightVM.text = String(format: "%.1f", initialWeight)
        self.weightTextFieldViewModel = weightVM
    }
    
    convenience init(from model: SQStrengthSet, onChanged: @escaping () -> Void) {
        self.init(
            id: model.id,
            isCompleted: model.isCompleted ?? false,
            setIndex: model.setIndex,
            initialReps: model.reps,
            initialWeight: model.weight,
            onChanged: onChanged
        )
        // rpe / isWarmup not surfaced in UI yet; easy to add later.
    }
    
    // Derived values from text
    var reps: Int {
        Int(repsTextFieldViewModel.text) ?? 0
    }
    
    var weight: Double {
        Double(weightTextFieldViewModel.text) ?? 0
    }
    
    var volume: Double {
        Double(reps) * weight
    }
    
    func asModel() -> SQStrengthSet {
        SQStrengthSet(
            id: id,
            isCompleted: isCompleted,
            setIndex: setIndex,
            reps: reps,
            weight: weight,
            rpe: nil,
            isWarmup: false
        )
    }
}

