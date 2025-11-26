//
//  SQTextFieldViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

import Foundation
import SwiftUI

protocol SQTextFieldViewModelDelegate: AnyObject {
    func sqTextFieldViewModelFocused(_ viewModel: SQTextFieldViewModel)
    func sqTextFieldViewModelTextChanged(_ viewModel: SQTextFieldViewModel, text: String)
    func sqTextFieldViewModelStateChanged(_ viewModel: SQTextFieldViewModel, state: SQTextFieldViewModel.TextFieldState)
}

final class SQTextFieldViewModel: ObservableObject {
    weak var delegate: SQTextFieldViewModelDelegate?
    
    let id = UUID()
    
    let placeholder: String
    let keyboardType: UIKeyboardType
    let textAutoCap: TextInputAutocapitalization?
    let autoCorrectionEnabled: Bool
    
    let tintColor: SQColor
    let backgroundColor: SQColor
    let standardBorderColor: SQColor
    let errorBorderColor: SQColor
    let unfocusedBorderColor: SQColor
    let supportTextStandardColor: SQColor
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    
    /// Receives the text input (previous and newText), and returns what the newText should be.  This is similar to shouldChangeText in a UIKit TextField.
    let textChangeFormatter: TextChangeFormatter
    /// Receives the text input and returns what the error text should display (if any).
    let errorHandler: (String) -> String?
    
    @Published private(set) var textFieldState: TextFieldState {
        didSet {
            refreshUI(with: textFieldState)
            delegate?.sqTextFieldViewModelStateChanged(self, state: textFieldState)
        }
    }
    var isTextFieldFocused: Bool = false
    @Published var shouldFocusTextFieldProgramatically = false // Toggle to focus
    var previousText = ""
    @Published var text: String = ""
    @Published var borderColor: SQColor?
    @Published var hideKeyboard: Bool = false // Toggle to hide keyboard
    let uiConfig: UIConfig
    
    let axis: Axis
    let lineLimit: Int
    
    init(uiConfig: UIConfig = .standard, axis: Axis = .horizontal, lineLimit: Int = 0, placeholder: String, keyboardType: UIKeyboardType = .default, isSecureEntry: Bool = false, textAutoCap: TextInputAutocapitalization? = nil, autoCorrectionEnabled: Bool = false, textChangeFormatter: TextChangeFormatter = .default, errorHandler: @escaping (String) -> String? = { text in return nil }) {
        self.uiConfig = uiConfig
        self.borderColor = uiConfig.unfocusedBorderColor
        self.axis = axis
        self.lineLimit = lineLimit
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.textAutoCap = textAutoCap
        self.autoCorrectionEnabled = autoCorrectionEnabled
        self.tintColor = uiConfig.tintColor
        self.backgroundColor = uiConfig.backgroundColor
        self.standardBorderColor = uiConfig.standardBorderColor
        self.errorBorderColor = uiConfig.errorBorderColor
        self.unfocusedBorderColor = uiConfig.unfocusedBorderColor
        self.supportTextStandardColor = uiConfig.supportTextColor
        self.borderWidth = uiConfig.borderWidth
        self.cornerRadius = uiConfig.cornerRadius
        self.textChangeFormatter = textChangeFormatter
        self.errorHandler = errorHandler
        self.textFieldState = .unfocused
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
        
        let errorText = errorHandler(text)
        
        if let errorText {
            textFieldState = .focusedError(errorText)
        }
        else {
            textFieldState = .focused
        }
    }
    
    struct UIConfig {
        let textColor: SQColor
        let placeholderColor: SQColor
        let tintColor: SQColor
        let backgroundColor: SQColor
        let standardBorderColor: SQColor
        let unfocusedBorderColor: SQColor
        let supportTextColor: SQColor
        let errorBorderColor: SQColor
        let borderWidth: CGFloat
        let cornerRadius: CGFloat
        
        init(textColor: SQColor = .textPrimary, placeholderColor: SQColor = .textTertiary, tintColor: SQColor, backgroundColor: SQColor, standardBorderColor: SQColor, unfocusedBorderColor: SQColor, supportTextColor: SQColor, errorBorderColor: SQColor, borderWidth: CGFloat, cornerRadius: CGFloat) {
            self.textColor = textColor
            self.placeholderColor = placeholderColor
            self.tintColor = tintColor
            self.backgroundColor = backgroundColor
            self.standardBorderColor = standardBorderColor
            self.unfocusedBorderColor = unfocusedBorderColor
            self.supportTextColor = supportTextColor
            self.errorBorderColor = errorBorderColor
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
            borderWidth: 1,
            cornerRadius: .SQCornerRadius.s)
    }
    
    enum TextFieldState {
        case unfocused
        case focused
        case focusedError(String?)
        
        var isFocused: Bool {
            switch self {
            case .unfocused:
                return false
            case .focused, .focusedError:
                return true
            }
        }
    }
    
    var hasError: Bool {
        errorHandler(text) != nil
    }
    
    private func refreshUI(with state: TextFieldState) {
        switch state {
        case .focused:
            borderColor = standardBorderColor
        case .focusedError:
            borderColor = errorBorderColor
        case .unfocused:
            borderColor = unfocusedBorderColor
        }
    }
}

extension SQTextFieldViewModel {
    enum TextChangeFormatter {
        case custom((String, String) -> String)
        case `default`
        
        var formatter: (String, String) -> String {
            switch self {
            case .custom(let formatter):
                return formatter
            case .default:
                return { (_, newText) in return newText }
            }
        }
    }
}
