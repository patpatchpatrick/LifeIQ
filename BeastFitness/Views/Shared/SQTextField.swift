//
//  SQTextField.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

import SwiftUI

@MainActor
struct SQTextField: View {
    
    @ObservedObject var viewModel: SQTextFieldViewModel
    
    @FocusState var isTextFieldFocused: Bool
    @State var borderWidth: CGFloat = 0
    
    var placeholder: Text {
        Text(viewModel.placeholder)
            .sqFont(.body)
            .foregroundColor(viewModel.uiConfig.placeholderColor.color)
    }
    
    var textField: some View {
        TextField(
            viewModel.placeholder,
            text: $viewModel.text,
            prompt: placeholder,
            axis: viewModel.axis
        )
        .font(viewModel.font.font)
        .focused($isTextFieldFocused)
        .autocorrectionDisabled(!viewModel.autoCorrectionEnabled)
        .textInputAutocapitalization(viewModel.textAutoCap)
        .lineLimit(viewModel.lineLimit)
        .padding(10)
        .sqForegroundColor(viewModel.uiConfig.textColor)
        .sqTintColor(viewModel.uiConfig.tintColor)
        .keyboardType(viewModel.keyboardType)
        .onChange(of: viewModel.shouldFocusTextFieldProgramatically) {
            isTextFieldFocused = true
        }
        .onChange(of: isTextFieldFocused) {
            if isTextFieldFocused {
                viewModel.focused()
            } else {
                viewModel.unfocus(dismissKeyboard: false)
            }
            
            withAnimation {
                borderWidth = isTextFieldFocused ? (viewModel.borderColor == nil ? 0 : viewModel.uiConfig.borderWidth) : 0
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
        VStack(alignment: .leading, spacing: 4) {
            if let errorText = viewModel.textFieldState.errorText {
                Text(errorText)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.colorErrorRed)
                    .transition(.opacity)
            }
            
            ZStack(alignment: .bottomTrailing) {
                textField
                    .sqBackgroundColor(viewModel.uiConfig.backgroundColor)
                    .cornerRadius(.SQCornerRadius.m)
                    .sqBorder(
                        viewModel.borderColor ?? .border,
                        width: borderWidth,
                        cornerRadius: viewModel.uiConfig.cornerRadius
                    )
                
                if let maxCharacterCountToShow = viewModel.maxCharacterCountToShow {
                    Text(viewModel.characterCountText)
                        .sqFont(.bodySmall)
                        .sqForegroundColor(.textTertiary)
                        .padding(.trailing, 8)
                        .padding(.bottom, 6)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.textFieldState)
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
