//
//  SQTextFieldViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

import Foundation
import SwiftUI

@MainActor
protocol SQTextFieldViewModelDelegate: AnyObject {
    func sqTextFieldViewModelFocused(_ viewModel: SQTextFieldViewModel)
    func sqTextFieldViewModelTextChanged(_ viewModel: SQTextFieldViewModel, text: String)
    func sqTextFieldViewModelStateChanged(_ viewModel: SQTextFieldViewModel, state: SQTextFieldViewModel.TextFieldState)
}

@MainActor
final class SQTextFieldViewModel: ObservableObject {
    weak var delegate: SQTextFieldViewModelDelegate?

     let id = UUID()
     
     let placeholder: String
     let keyboardType: UIKeyboardType
     let textAutoCap: TextInputAutocapitalization?
     let autoCorrectionEnabled: Bool
     
     let uiConfig: UIConfig
     
     let textChangeFormatter: TextChangeFormatter
     let errorHandler: (String) -> String?
     let validationRule: SQTextValidationRule?
     
     @Published private(set) var textFieldState: TextFieldState {
         didSet {
             refreshUI(with: textFieldState)
             delegate?.sqTextFieldViewModelStateChanged(self, state: textFieldState)
         }
     }

     @Published var text: String = ""
     @Published var borderColor: SQColor?
     @Published var hideKeyboard: Bool = false
     @Published var shouldFocusTextFieldProgramatically = false

     var isTextFieldFocused: Bool = false
     var previousText = ""
     
     let axis: Axis
     let lineLimit: Int
    
    init(
          uiConfig: UIConfig = .standard,
          axis: Axis = .horizontal,
          lineLimit: Int = 0,
          placeholder: String,
          keyboardType: UIKeyboardType = .default,
          isSecureEntry: Bool = false,
          textAutoCap: TextInputAutocapitalization? = nil,
          autoCorrectionEnabled: Bool = false,
          textChangeFormatter: TextChangeFormatter = .default,
          validationRule: SQTextValidationRule? = nil,
          errorHandler: @escaping (String) -> String? = { _ in nil }
      ) {
          self.uiConfig = uiConfig
          self.axis = axis
          self.lineLimit = lineLimit
          self.placeholder = placeholder
          self.keyboardType = keyboardType
          self.textAutoCap = textAutoCap
          self.autoCorrectionEnabled = autoCorrectionEnabled
          self.textChangeFormatter = textChangeFormatter
          self.errorHandler = errorHandler
          self.validationRule = validationRule
          self.textFieldState = .unfocused
          self.borderColor = uiConfig.unfocusedBorderColor
      }
    
    func focusProgramatically() {
        shouldFocusTextFieldProgramatically.toggle()
    }
    
    // Focused by user
    func focused() {
        isTextFieldFocused = true
        refreshStateAndError(isFocused: true)
        delegate?.sqTextFieldViewModelFocused(self)
    }
    
    // Programmatically unfocus the TextField
    func unfocus(dismissKeyboard: Bool, debounceKeyboardDismissal: Bool = false) {
        isTextFieldFocused = false
        refreshStateAndError(isFocused: false)
        if dismissKeyboard {
            self.dismissKeyboard(debounceKeyboardDismissal: debounceKeyboardDismissal)
        }
    }
    
    private func dismissKeyboard(debounceKeyboardDismissal: Bool = false) {
        if debounceKeyboardDismissal {
            // SwiftUI Alert dismissal interferes with TextField keyboard dismissal so asyncAfter is required 😩
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.hideKeyboard = !self.hideKeyboard
            }
        }
        else {
            hideKeyboard = !hideKeyboard
        }
    }
    
    func initializeText(_ text: String) {
        self.text = text
        self.previousText = text
    }
    
    func textFieldTextChanged(_ newText: String) {
        let textChangeFormattter = self.textChangeFormatter.formatter
        text = textChangeFormattter(previousText, newText)
        previousText = text

        if textFieldState.isFocused {
            refreshStateAndError(isFocused: true)
        }
        
        delegate?.sqTextFieldViewModelTextChanged(self, text: text)
    }
    
    func refreshStateAndError(isFocused: Bool) {
        guard isFocused else {
            textFieldState = .unfocused
            return
        }
        
        // 1. Error always wins
        if let errorText = errorHandler(text) {
            textFieldState = .focusedError(errorText)
            return
        }
        
        // 2. If no error and we have a validation rule → maybe valid
        if let rule = validationRule, rule.isValid(text) {
            textFieldState = .focusedValid
        } else {
            textFieldState = .focused
        }
    }
    
    var isContentValid: Bool {
            if let rule = validationRule {
                return rule.isValid(text)
            } else {
                // Fallback: if there's no error, treat it as valid
                return errorHandler(text) == nil
            }
        }

    
    private func refreshUI(with state: TextFieldState) {
        switch state {
        case .focused:
            borderColor = uiConfig.standardBorderColor
        case .focusedValid:
            borderColor = uiConfig.validBorderColor
        case .focusedError:
            borderColor = uiConfig.errorBorderColor
        case .unfocused:
            borderColor = uiConfig.unfocusedBorderColor
        }
    }
}

// MARK: - Text Field State

extension SQTextFieldViewModel {
    
    enum TextFieldState: Equatable {
        case unfocused
        case focused
        case focusedValid
        case focusedError(String?)
        
        var isFocused: Bool {
            switch self {
            case .unfocused:
                return false
            case .focused, .focusedValid, .focusedError:
                return true
            }
        }
        
        var errorText: String? {
            if case .focusedError(let message) = self {
                return message
            }
            return nil
        }
        
        var hasError: Bool {
            errorText != nil
        }
        
        var isValid: Bool {
            if case .focusedValid = self {
                return true
            }
            return false
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.unfocused, .unfocused),
                 (.focused, .focused),
                 (.focusedValid, .focusedValid):
                return true
            case let (.focusedError(l), .focusedError(r)):
                return l == r
            default:
                return false
            }
        }
    }
}

// MARK: - UI Config

extension SQTextFieldViewModel {
    
    struct UIConfig {
        let textColor: SQColor
        let placeholderColor: SQColor
        let tintColor: SQColor
        let backgroundColor: SQColor
        let standardBorderColor: SQColor
        let unfocusedBorderColor: SQColor
        let supportTextColor: SQColor
        let errorBorderColor: SQColor
        let validBorderColor: SQColor       // 👈 NEW
        let borderWidth: CGFloat
        let cornerRadius: CGFloat
        
        init(
            textColor: SQColor = .textPrimary,
            placeholderColor: SQColor = .textTertiary,
            tintColor: SQColor,
            backgroundColor: SQColor,
            standardBorderColor: SQColor,
            unfocusedBorderColor: SQColor,
            supportTextColor: SQColor,
            errorBorderColor: SQColor,
            validBorderColor: SQColor,       // 👈 NEW
            borderWidth: CGFloat,
            cornerRadius: CGFloat
        ) {
            self.textColor = textColor
            self.placeholderColor = placeholderColor
            self.tintColor = tintColor
            self.backgroundColor = backgroundColor
            self.standardBorderColor = standardBorderColor
            self.unfocusedBorderColor = unfocusedBorderColor
            self.supportTextColor = supportTextColor
            self.errorBorderColor = errorBorderColor
            self.validBorderColor = validBorderColor
            self.borderWidth = borderWidth
            self.cornerRadius = cornerRadius
        }
        
        static let standard = UIConfig(
            tintColor: .textPrimary,
            backgroundColor: .backgroundSecondary,
            standardBorderColor: .border,
            unfocusedBorderColor: .border,
            supportTextColor: .textSecondary,
            errorBorderColor: .colorErrorRed,
            validBorderColor: .colorGreenPct(percent: 1, base: .textPrimary),
            borderWidth: 1,
            cornerRadius: .SQCornerRadius.s
        )
    }

}
