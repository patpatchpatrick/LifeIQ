//
//  SQWorkoutSessionSetViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/15/25.
//

import SwiftUI
import Foundation
import UIKit

@Observable
@MainActor
final class SQWorkoutSessionSetViewModel: Identifiable {

    let id: UUID
    var setIndex: Int

    let repsTextFieldViewModel: SQUITextFieldViewModel
    let weightTextFieldViewModel: SQUITextFieldViewModel

    var isCompleted: Bool = false {
        didSet { onChanged() }
    }

    /// Called whenever the data is changed. An update will be sent out to sync data with DB + watch.
    let onChanged: () -> Void

    init(
        id: UUID = UUID(),
        isCompleted: Bool = false,
        setIndex: Int,
        initialReps: Int = 8,
        initialWeight: Double? = 50,
        onChanged: @escaping () -> Void
    ) {
        self.id = id
        self.setIndex = setIndex
        self.isCompleted = isCompleted
        self.onChanged = onChanged

        // Reps: integer, 1...1000
        let repsVM = SQUITextFieldViewModel(
            placeholder: "Reps",
            font: SQFont(type: .body).uiFont,                // ✅ UIKit font
            uiConfig: .standard,
            keyboardType: .numberPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            isSecureTextEntry: false,
            returnKeyType: .done,
            selectAllOnFocus: true,
            textChangeFormatter: .integer,
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        // Weight: decimal, 0...2000 (1 decimal place)
        let weightVM = SQUITextFieldViewModel(
            placeholder: "lbs",
            font: SQFont(type: .body).uiFont,                // ✅ UIKit font
            uiConfig: .standard,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            isSecureTextEntry: false,
            returnKeyType: .done,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        // Set initial values using the VM API (text is private(set))
        repsVM.setText("\(initialReps)")
        if let initialWeight {
            weightVM.setText(String(format: "%.1f", initialWeight))
        }

        self.repsTextFieldViewModel = repsVM
        self.weightTextFieldViewModel = weightVM

        // Wire change notifications to onChanged()
        let delegate = DelegateProxy(owner: self)
        repsVM.delegate = delegate
        weightVM.delegate = delegate
        self.delegateProxy = delegate
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
    }

    // Derived values from text
    var reps: Int {
        Int(repsTextFieldViewModel.text) ?? 0
    }

    var weight: Double? {
        Double(weightTextFieldViewModel.text)
    }

    var volume: Double {
        Double(reps) * (weight ?? 0)
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

    // MARK: - Delegate proxy (keeps VM -> onChanged stable)

    private var delegateProxy: DelegateProxy?

    private final class DelegateProxy: NSObject, SQUITextFieldViewModelDelegate {
        weak var owner: SQWorkoutSessionSetViewModel?

        init(owner: SQWorkoutSessionSetViewModel) {
            self.owner = owner
        }

        func squiTextFieldFocused(_ viewModel: SQUITextFieldViewModel) {
            // Optional: do nothing
        }

        func squiTextFieldTextChanged(_ viewModel: SQUITextFieldViewModel, text: String) {
            owner?.onChanged()
        }

        func squiTextFieldStateChanged(_ viewModel: SQUITextFieldViewModel, state: SQUITextFieldViewModel.TextFieldState) {
            // Optional: if you want DB sync on validation changes too:
            // owner?.onChanged()
        }
    }
}
