//
//  SQLoginController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI
import UIKit

enum SQLoginMode: String {
    case login = "Log In"
    case signup = "Sign Up"

    var toggleTitle: String {
        switch self {
        case .login:
            return "Sign Up"
        case .signup:
            return "Log In"
        }
    }

    func toggled() -> SQLoginMode {
        switch self {
        case .login:
            return .signup
        case .signup:
            return .login
        }
    }
}

@MainActor
protocol SQLoginInterface: AnyObject {
    var title: String { get }
    var mode: SQLoginMode { get set }
    func toggleMode()
}

@MainActor
@Observable final class SQLoginController: SQLoginInterface, Identifiable {
    let id = UUID().uuidString
    let hub: EventHub

    var mode: SQLoginMode
    var isLoading: Bool = false

    let emailViewModel: SQUITextFieldViewModel
    let passwordViewModel: SQUITextFieldViewModel

    var title: String { mode.rawValue }

    init(mode: SQLoginMode = .login, hub: EventHub = SQAppState.shared.hub) {
        self.mode = mode
        self.hub = hub
        self.emailViewModel = SQUITextFieldViewModel(
            placeholder: "Email",
            font: SQFont(type: .body).uiFont,
            keyboardType: .emailAddress,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            returnKeyType: .next,
            textChangeFormatter: .maxLength(254),
            validationRule: .custom(Self.isValidEmail),
            errorHandler: { text in
                Self.emailErrorMessage(for: text)
            }
        )
        self.passwordViewModel = SQUITextFieldViewModel(
            placeholder: "Password",
            font: SQFont(type: .body).uiFont,
            keyboardType: .default,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            isSecureTextEntry: true,
            returnKeyType: .done,
            textChangeFormatter: .maxLength(128),
            validationRule: .custom(Self.isValidPassword),
            errorHandler: { text in
                Self.passwordErrorMessage(for: text)
            }
        )
    }

    func toggleMode() {
        mode = mode.toggled()
    }

    func loginOrSignUpButtonTapped() {
        Task { await loginOrSignUp() }
    }

    private func loginOrSignUp() async {
        guard !isLoading else { return }
        guard inputsAreValid() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .login:
                try await login()
            case .signup:
                try await signUp()
            }
        } catch {
            hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
        }
    }

    private func inputsAreValid() -> Bool {
        let emailValid = emailViewModel.isContentValid
        let passwordValid = passwordViewModel.isContentValid

        guard emailValid && passwordValid else {
            hub.alertEvents.send(.present(.init(SQError.standard(withDescription: "Please enter a valid email and a stronger password."))))
            return false
        }

        return true
    }

    private func login() async throws {
        try await Task.sleep(nanoseconds: 900_000_000)
        throw SQError.standard(withDescription: "Login is not wired up yet.")
    }

    private func signUp() async throws {
        try await Task.sleep(nanoseconds: 900_000_000)
        throw SQError.standard(withDescription: "Sign up is not wired up yet.")
    }

    private static func isValidEmail(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let regex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES[c] %@", regex)
        return predicate.evaluate(with: trimmed)
    }

    private static func emailErrorMessage(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Email is required." }
        return isValidEmail(trimmed) ? nil : "Enter a valid email."
    }

    private static func isValidPassword(_ text: String) -> Bool {
        passwordErrorMessage(for: text) == nil
    }

    private static func passwordErrorMessage(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Password is required." }
        guard trimmed.count >= 8 else { return "Password must be at least 8 characters." }

        let hasUpper = trimmed.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLower = trimmed.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = trimmed.range(of: "[0-9]", options: .regularExpression) != nil

        guard hasUpper && hasLower && hasNumber else {
            return "Use upper, lower, and a number."
        }

        return nil
    }
}
