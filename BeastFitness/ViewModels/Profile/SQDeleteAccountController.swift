//
//  SQDeleteAccountController.swift
//  BeastFitness
//
//  Created by OpenAI on 4/7/26.
//

import SwiftUI
import SwiftData
import Observation
import UIKit

@MainActor
protocol SQDeleteAccountInterface: AnyObject {
    var title: String { get }
}

@MainActor
@Observable
final class SQDeleteAccountController: SQDeleteAccountInterface, Identifiable {
    let id = UUID().uuidString
    let hub: EventHub
    let userState: SQUserStating

    private let authManager: SQAuthManaging
    private let accountDeletionManager: SQAccountDeletionManaging

    let passwordViewModel: SQUITextFieldViewModel

    var title: String { "Delete Account" }
    var isLoading = false

    private(set) var authProviders: Set<SQAuthProvider>

    var email: String {
        userState.loggedInUser?.email ?? ""
    }

    var supportsPasswordConfirmation: Bool {
        authProviders.contains(.password)
    }

    var supportsGoogleConfirmation: Bool {
        authProviders.contains(.google)
    }

    var supportsAppleConfirmation: Bool {
        authProviders.contains(.apple)
    }

    init(
        hub: EventHub = SQAppState.shared.hub,
        userState: SQUserStating = SQAppState.shared.userState,
        authManager: SQAuthManaging = SQAuthManager.shared,
        accountDeletionManager: SQAccountDeletionManaging = SQAccountDeletionManager.shared
    ) {
        self.hub = hub
        self.userState = userState
        self.authManager = authManager
        self.accountDeletionManager = accountDeletionManager
        self.authProviders = authManager.currentAuthProviders()
        self.passwordViewModel = SQUITextFieldViewModel(
            placeholder: "Current password",
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

    func refreshProviders() {
        authProviders = authManager.currentAuthProviders()
    }

    func deleteWithPassword(modelContext: ModelContext) {
        guard supportsPasswordConfirmation else { return }
        guard passwordViewModel.isContentValid else {
            hub.alertEvents.send(.present(.init(SQAccountDeletionError.passwordRequired)))
            return
        }

        confirmDeletion(
            using: .password(passwordViewModel.text),
            modelContext: modelContext
        )
    }

    func deleteWithGoogle(modelContext: ModelContext) {
        guard supportsGoogleConfirmation else { return }

        confirmDeletion(
            using: .google,
            modelContext: modelContext
        )
    }

    func deleteWithApple(modelContext: ModelContext) {
        guard supportsAppleConfirmation else { return }

        confirmDeletion(
            using: .apple,
            modelContext: modelContext
        )
    }

    private func confirmDeletion(
        using method: SQAccountDeletionReauthenticationMethod,
        modelContext: ModelContext
    ) {
        let alert = SQAlertViewModel(
            title: "Delete account permanently?",
            subtitle: """
            This removes your LifeIQ account, profile, cloud check-ins, metrics, workout metadata, and local app data on this device.

            Apple Health data stays in the Health app and must be managed there separately.

            This cannot be undone.
            """,
            primary: .init(title: "Delete Account", role: .destructive) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.performDeletion(using: method, modelContext: modelContext)
                }
            },
            secondary: .init(title: "Cancel", role: .cancel),
            canDismiss: true
        )

        hub.alertEvents.send(.present(alert))
    }

    private func performDeletion(
        using method: SQAccountDeletionReauthenticationMethod,
        modelContext: ModelContext
    ) async {
        guard !isLoading else { return }
        guard let user = userState.loggedInUser else {
            hub.alertEvents.send(.present(.init(SQAccountDeletionError.notLoggedIn)))
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await accountDeletionManager.deleteAccount(
                for: user,
                reauthenticationMethod: method,
                modelContext: modelContext
            )
        } catch {
            hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
        }
    }

    private static func isValidPassword(_ text: String) -> Bool {
        passwordErrorMessage(for: text) == nil
    }

    private static func passwordErrorMessage(for text: String) -> String? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Password is required."
            : nil
    }
}
