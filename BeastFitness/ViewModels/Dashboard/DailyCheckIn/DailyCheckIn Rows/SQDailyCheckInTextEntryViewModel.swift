//
//  SQDailyCheckInTextEntryViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//


import SwiftUI

@Observable @MainActor
final class SQDailyCheckInTextEntryViewModel: SQDailyCheckInRowViewModel {
    let textFieldViewModel: SQTextFieldViewModel

    // Designated init using already-mapped segments
    init(
        field: SQDailyCheckInField,
        title: String,
        textFieldViewModel: SQTextFieldViewModel,
        onFocused: ((SQDailyCheckInRowViewModel) -> Void)? = nil
    ) {
        self.textFieldViewModel = textFieldViewModel
        super.init(field: field, title: title, onFocused: onFocused)
        textFieldViewModel.delegate = self
    }
    
    func initialize(with text: String?) {
        guard let text else { return }
        /// Call the textChanged function to trigger the validation handler when the textField is initialized
        textFieldViewModel.text = text
        sqTextFieldViewModelTextChanged(textFieldViewModel, text: text)
    }
}

extension SQDailyCheckInTextEntryViewModel: SQTextFieldViewModelDelegate {
    
    func sqTextFieldViewModelFocused(_ viewModel: SQTextFieldViewModel) {
        /// no-op
    }
    
    func sqTextFieldViewModelTextChanged(_ viewModel: SQTextFieldViewModel, text: String) {
        isCompleted = viewModel.isContentValid
    }
    
    func sqTextFieldViewModelStateChanged(_ viewModel: SQTextFieldViewModel, state: SQTextFieldViewModel.TextFieldState) {
        isCompleted = viewModel.isContentValid
    }
}

