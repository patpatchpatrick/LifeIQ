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
        title: String,
        textFieldViewModel: SQTextFieldViewModel
    ) {
        self.textFieldViewModel = textFieldViewModel
        super.init(title: title)
        textFieldViewModel.delegate = self
    }
}

extension SQDailyCheckInTextEntryViewModel: SQTextFieldViewModelDelegate {
    
    func sqTextFieldViewModelFocused(_ viewModel: SQTextFieldViewModel) {
        /// no-op
    }
    
    func sqTextFieldViewModelTextChanged(_ viewModel: SQTextFieldViewModel, text: String) {
        /// no-op
    }
    
    func sqTextFieldViewModelStateChanged(_ viewModel: SQTextFieldViewModel, state: SQTextFieldViewModel.TextFieldState) {
        isCompleted = state.isValid
    }
}

