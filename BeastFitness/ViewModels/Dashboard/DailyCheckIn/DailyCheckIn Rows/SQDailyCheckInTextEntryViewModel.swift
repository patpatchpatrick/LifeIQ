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
        textFieldViewModel: SQTextFieldViewModel,
        onFocused: ((SQDailyCheckInRowViewModel) -> Void)? = nil
    ) {
        self.textFieldViewModel = textFieldViewModel
        super.init(title: title, onFocused: onFocused)
        textFieldViewModel.delegate = self
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

