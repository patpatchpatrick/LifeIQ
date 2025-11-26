//
//  SQTextField.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

import SwiftUI

struct SQTextField: View {
    
    @ObservedObject var viewModel: SQTextFieldViewModel
    @FocusState var isTextFieldFocused: Bool
    
    var placeholder: Text {
        Text(viewModel.placeholder)
            .sqFont(.body)
            .foregroundColor(viewModel.uiConfig.placeholderColor.color)
    }
    
    var textField: some View {
        // IF UPDATING THIS, ALSO UPDATE THE SECURETEXTFIELD!!!
        TextField(viewModel.placeholder, text: $viewModel.text, prompt: placeholder, axis: viewModel.axis)
            .font(.sqFont(.body))
            .focused($isTextFieldFocused)
            .autocorrectionDisabled(!viewModel.autoCorrectionEnabled)
            .textInputAutocapitalization(viewModel.textAutoCap)
            .lineLimit(viewModel.lineLimit)
            .padding(10)
            .sqForegroundColor(viewModel.uiConfig.textColor)
            .sqTintColor(viewModel.tintColor)
            .keyboardType(viewModel.keyboardType)
            .onChange(of: viewModel.shouldFocusTextFieldProgramatically) {
                isTextFieldFocused = true
            }
            .onChange(of: isTextFieldFocused) {
                if isTextFieldFocused {
                    // Begin Editing
                    viewModel.focused()
                }
                else {
                    // End Editing
                    viewModel.unfocus(dismissKeyboard: false)
                }
            }
            .onChange(of: viewModel.hideKeyboard) {
                sqHideKeyboard()
            }
            .onChange(of: viewModel.text) {
                viewModel.textFieldTextChanged(viewModel.text)
            }
    }
    
    var body: some View {
        textField
        .sqBackgroundColor(viewModel.backgroundColor)
        .cornerRadius(.SQCornerRadius.m)
        .sqBorder(viewModel.borderColor ?? .border,
            width: viewModel.borderColor == nil ? 0 : viewModel.borderWidth,
            cornerRadius: viewModel.cornerRadius)
    }
}

#Preview {
    
    VStack {
        Spacer()
        SQTextField(viewModel: SQTextFieldViewModel(
            placeholder: "Number of Simulations",
            keyboardType: .numberPad,
            errorHandler: { newText in
                guard newText.intValue != nil else {
                    return "Enter a valid number"
                }
                return nil
            }))
        .frame(maxWidth: .infinity)
        Spacer()
            .frame(maxWidth: .infinity)
    }
    .padding(20)
    .sqBackgroundColor(.backgroundSecondary)
}
