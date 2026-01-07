//
//  SQUITextFieldViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/6/26.
//

import Foundation
import UIKit

@MainActor
protocol SQUITextFieldViewModelDelegate: AnyObject {
    func squiTextFieldFocused(_ viewModel: SQUITextFieldViewModel)
    func squiTextFieldTextChanged(_ viewModel: SQUITextFieldViewModel, text: String)
    func squiTextFieldStateChanged(_ viewModel: SQUITextFieldViewModel, state: SQUITextFieldViewModel.TextFieldState)
}

@MainActor
final class SQUITextFieldViewModel: ObservableObject {

    // MARK: - Public Config

    let id = UUID()

    let placeholder: String
    let font: UIFont
    let keyboardType: UIKeyboardType
    let autocapitalizationType: UITextAutocapitalizationType
    let autocorrectionType: UITextAutocorrectionType
    let isSecureTextEntry: Bool
    let returnKeyType: UIReturnKeyType

    let selectAllOnFocus: Bool
    let maxCharacterCountToShow: Int?

    let uiConfig: UIConfig

    let textChangeFormatter: TextChangeFormatter
    let errorHandler: (String) -> String?
    let validationRule: SQTextValidationRule?

    weak var delegate: SQUITextFieldViewModelDelegate?

    // MARK: - State

    @Published private(set) var textFieldState: TextFieldState = .unfocused {
        didSet {
            refreshUI(with: textFieldState)
            delegate?.squiTextFieldStateChanged(self, state: textFieldState)
        }
    }

    @Published private(set) var text: String = ""
    @Published private(set) var borderColor: SQColor?

    var previousText: String = ""

    // We hold a weak reference so the VM can issue imperative focus/blur without SwiftUI races.
    private weak var boundTextField: UITextField?

    // MARK: - Init

    init(
        placeholder: String,
        font: UIFont,
        uiConfig: UIConfig = .standard,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .no,
        isSecureTextEntry: Bool = false,
        returnKeyType: UIReturnKeyType = .done,
        selectAllOnFocus: Bool = false,
        textChangeFormatter: TextChangeFormatter = .default,
        validationRule: SQTextValidationRule? = nil,
        errorHandler: @escaping (String) -> String? = { _ in nil }
    ) {
        self.placeholder = placeholder
        self.font = font
        self.uiConfig = uiConfig
        self.keyboardType = keyboardType
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.isSecureTextEntry = isSecureTextEntry
        self.returnKeyType = returnKeyType
        self.selectAllOnFocus = selectAllOnFocus

        self.textChangeFormatter = textChangeFormatter
        self.validationRule = validationRule
        self.errorHandler = errorHandler

        self.maxCharacterCountToShow = textChangeFormatter.maxLengthLimit
        self.borderColor = uiConfig.unfocusedBorderColor
    }

    // MARK: - Binding (View ↔ UITextField)

    func bind(textField: UITextField) {
        self.boundTextField = textField
        applyConfig(to: textField)
        applyPlaceholder(to: textField)
        // Keep UI and text in sync on bind
        textField.text = text
    }

    func unbind(textField: UITextField) {
        if boundTextField === textField {
            boundTextField = nil
        }
    }

    // MARK: - Commands (Stable imperative API)

    func setText(_ newText: String) {
        // Used by the app to set text programmatically.
        text = newText
        previousText = newText
        boundTextField?.text = newText
        refreshStateAndError(isFocused: boundTextField?.isFirstResponder ?? false)
    }

    func focus() {
        boundTextField?.becomeFirstResponder()
    }

    func blur() {
        boundTextField?.resignFirstResponder()
    }

    // MARK: - Events (from UITextField)

    func userDidBeginEditing() {
        refreshStateAndError(isFocused: true)
        delegate?.squiTextFieldFocused(self)

        if selectAllOnFocus {
            // Do not async if we can avoid it; but selection must happen after responder is active.
            // Guarded + cancellable at coordinator layer (we'll do it there).
        }
    }

    func userDidEndEditing() {
        refreshStateAndError(isFocused: false)
    }

    func userDidEditText(_ rawNewText: String) {
        let formatter = textChangeFormatter.formatter
        let formatted = formatter(previousText, rawNewText)

        // Update both model and field only if needed (prevents recursion loops)
        if formatted != rawNewText {
            boundTextField?.text = formatted
        }

        text = formatted
        previousText = formatted

        if textFieldState.isFocused {
            refreshStateAndError(isFocused: true)
        }

        delegate?.squiTextFieldTextChanged(self, text: formatted)
    }

    // MARK: - Derived

    var characterCountText: String {
        if let max = maxCharacterCountToShow {
            return "\(text.count)/\(max)"
        } else {
            return "\(text.count)"
        }
    }

    var isContentValid: Bool {
        if let rule = validationRule {
            return rule.isValid(text)
        }
        return errorHandler(text) == nil
    }

    // MARK: - Private

    private func refreshStateAndError(isFocused: Bool) {
        guard isFocused else {
            textFieldState = .unfocused
            return
        }

        if let errorText = errorHandler(text) {
            textFieldState = .focusedError(errorText)
            return
        }

        if let rule = validationRule, rule.isValid(text) {
            textFieldState = .focusedValid
        } else {
            textFieldState = .focused
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

    private func applyConfig(to tf: UITextField) {
        tf.font = font
        tf.keyboardType = keyboardType
        tf.autocapitalizationType = autocapitalizationType
        tf.autocorrectionType = autocorrectionType
        tf.isSecureTextEntry = isSecureTextEntry
        tf.returnKeyType = returnKeyType
    }

    private func applyPlaceholder(to tf: UITextField) {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: uiConfig.placeholderColor.uiColor,
            .font: font
        ]
        tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: attrs)
    }
}

// MARK: - State

extension SQUITextFieldViewModel {
    enum TextFieldState: Equatable {
        case unfocused
        case focused
        case focusedValid
        case focusedError(String?)

        var isFocused: Bool {
            switch self {
            case .unfocused: return false
            case .focused, .focusedValid, .focusedError: return true
            }
        }

        var errorText: String? {
            if case .focusedError(let msg) = self { return msg }
            return nil
        }
    }
}

// MARK: - UI Config

extension SQUITextFieldViewModel {
    struct UIConfig {
        let textColor: SQColor
        let placeholderColor: SQColor
        let tintColor: SQColor
        let backgroundColor: SQColor
        let standardBorderColor: SQColor
        let unfocusedBorderColor: SQColor
        let errorBorderColor: SQColor
        let validBorderColor: SQColor
        let borderWidth: CGFloat
        let cornerRadius: CGFloat

        static let standard = UIConfig(
            textColor: .textPrimary,
            placeholderColor: .textTertiary,
            tintColor: .textPrimary,
            backgroundColor: .backgroundSecondary,
            standardBorderColor: .border,
            unfocusedBorderColor: .border,
            errorBorderColor: .colorErrorRed,
            validBorderColor: .colorGreenPct(percent: 1, base: .textPrimary),
            borderWidth: 1,
            cornerRadius: .SQCornerRadius.s
        )
    }
}

extension SQUITextFieldViewModel {
    enum TextChangeFormatter {
        case custom((String, String) -> String)
        case `default`
        case numeric
        case decimal(maxDecimalPlaces: Int)
        case maxLength(Int)
        case integer
        
        var formatter: (String, String) -> String {
            switch self {
            case .custom(let formatter):
                return formatter
                
            case .default:
                return { _, newText in newText }
                
            case .numeric:
                return { _, newText in
                    newText.filter { $0.isWholeNumber }
                }
                
            case .decimal(let maxDecimalPlaces):
                return decimalFormatter(maxDecimalPlaces: maxDecimalPlaces)
                
            case .maxLength(let limit):
                return maxLengthFormatter(limit: limit)
                
            case .integer:
                    return integerFormatter
            }
        }
    }
}

// MARK: - Formatters

extension SQUITextFieldViewModel.TextChangeFormatter {
    
    fileprivate func decimalFormatter(maxDecimalPlaces: Int) -> (String, String) -> String {
        { _, newText in
            var filtered = newText.filter { $0.isWholeNumber || $0 == "." }
            
            if filtered.filter({ $0 == "." }).count > 1 {
                var seenDot = false
                filtered = filtered.filter {
                    if $0 == "." {
                        defer { seenDot = true }
                        return !seenDot
                    }
                    return true
                }
            }
            
            if let dotIndex = filtered.firstIndex(of: ".") {
                let decimalPart = filtered[filtered.index(after: dotIndex)...]
                if decimalPart.count > maxDecimalPlaces {
                    let allowedEnd = filtered.index(dotIndex, offsetBy: 1 + maxDecimalPlaces)
                    filtered = String(filtered[..<allowedEnd])
                }
            }
            
            return filtered
        }
    }
    
    fileprivate func maxLengthFormatter(limit: Int) -> (String, String) -> String {
        { _, newText in
            guard newText.count > limit else { return newText }
            let idx = newText.index(newText.startIndex, offsetBy: limit)
            return String(newText[..<idx])
        }
    }
    
    fileprivate var integerFormatter: (String, String) -> String {
        { _, newText in
            newText.filter { $0.isWholeNumber }
        }
    }
    
    /// Extract length limit if this is `.maxLength`
    var maxLengthLimit: Int? {
        if case let .maxLength(limit) = self {
            return limit
        }
        return nil
    }
}
