//
//  SQLoginController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI
import UIKit
import FirebaseAuth
import BeastFitnessCore

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
            shouldShowCharacterCount: false,
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

    func googleButtonTapped() {
        Task { await loginOrSignUpWithGoogle() }
    }

    private func loginOrSignUp() async {
        guard !isLoading else { return }
        guard inputsAreValid() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .login:
                let result = try await login()
                try await completeAuthentication(
                    result: result,
                    fallbackEmail: emailViewModel.text,
                    method: .email
                )
            case .signup:
                let result = try await signUp()
                try await completeAuthentication(
                    result: result,
                    fallbackEmail: emailViewModel.text,
                    method: .email
                )
            }
        } catch {
            presentAuthError(error)
        }
    }

    private func loginOrSignUpWithGoogle() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let presentingViewController = try currentPresentingViewController()
            let result = try await SQAuthManager.shared.signInWithGoogle(presentingViewController: presentingViewController)
            try await completeAuthentication(
                result: result,
                fallbackEmail: result.user.email,
                method: .google
            )
        } catch {
            presentAuthError(error)
        }
    }

    private func inputsAreValid() -> Bool {
        let emailValid = emailViewModel.isContentValid
        let passwordValid = passwordViewModel.isContentValid

        guard emailValid && passwordValid else {
            hub.alertEvents.send(.present(.init(SQError.standard(withDescription: "Enter a valid email and password."))))
            return false
        }

        return true
    }

    private func login() async throws -> AuthDataResult {
                
        let email = emailViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            return try await SQAuthManager.shared.signIn(email: email, password: passwordViewModel.text)
        } catch {
            throw SQAuthError.from(error)
        }
    }

    private func signUp() async throws -> AuthDataResult {
        let email = emailViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            return try await SQAuthManager.shared.createUser(email: email, password: passwordViewModel.text)
        } catch {
            throw SQAuthError.from(error)
        }
    }

    private func completeAuthentication(
        result: AuthDataResult,
        fallbackEmail: String?,
        method: SQAnalyticsAuthMethod
    ) async throws {
        let trimmedFallbackEmail = fallbackEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEmail = result.user.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmedFallbackEmail
        let isNewUser = result.additionalUserInfo?.isNewUser == true

        if isNewUser {
            guard let resolvedEmail, !resolvedEmail.isEmpty else {
                throw SQAuthError(description: "Could not determine your account email.")
            }

            let user = try await SQUserManager.shared.createUserDocument(uid: result.user.uid, email: resolvedEmail)
            SQUserDefaults.shared.markPendingOnboarding(for: result.user.uid)
            SQAppState.shared.userState.updateLoggedInUser(user, hasLoadedProfile: true)

            SQLogger.shared.log("User signed up successfully", .info, context: .loginSignup)
            SQAnalyticsManager.shared.track(.signupSucceeded(method: method))
            hub.toastEvents.send(.present(.init(title: "Signup successful!", style: .success)))
        } else {
            if let existingUser = try? await SQUserManager.shared.fetchUser(uid: result.user.uid) {
                SQAppState.shared.userState.updateLoggedInUser(existingUser, hasLoadedProfile: true)
            }

            SQLogger.shared.log("User logged in successfully", .info, context: .loginSignup)
            SQAnalyticsManager.shared.track(.loginSucceeded(method: method))
            hub.toastEvents.send(.present(.init(title: "Login successful!", style: .success)))
        }

        hub.domainEvents.send(.dismissDashboardNavStack)
        await Task.yield()
        hub.userEvents.send(.profileUpdated)
    }

    private func presentAuthError(_ error: Error) {
        if let authError = error as? SQAuthError {
            guard authError.shouldPresentToUser else { return }
            hub.alertEvents.send(.present(.init(authError)))
            return
        }

        hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
    }

    private func currentPresentingViewController() throws -> UIViewController {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            throw SQAuthError(description: "Could not start Google Sign-In because no active view was available.")
        }

        var presentingViewController = rootViewController
        while let presentedViewController = presentingViewController.presentedViewController {
            presentingViewController = presentedViewController
        }
        return presentingViewController
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
