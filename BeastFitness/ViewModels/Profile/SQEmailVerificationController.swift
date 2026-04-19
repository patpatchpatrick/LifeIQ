//
//  SQEmailVerificationController.swift
//  BeastFitness
//
//  Created by Codex on 4/19/26.
//

import SwiftUI
import Combine
import BeastFitnessCore

@MainActor
@Observable final class SQEmailVerificationController: Identifiable {
    let id = UUID().uuidString
    let hub: EventHub
    let userState: SQUserStating
    let authManager: SQAuthManaging

    private var cancellables = Set<AnyCancellable>()

    private(set) var emailAddress: String = ""
    private(set) var isVerificationRequired: Bool = false
    var isRefreshingStatus = false
    var isResendingEmail = false
    var isLoggingOut = false

    init(
        hub: EventHub = SQAppState.shared.hub,
        userState: SQUserStating = SQAppState.shared.userState,
        authManager: SQAuthManaging = SQAuthManager.shared
    ) {
        self.hub = hub
        self.userState = userState
        self.authManager = authManager
        refreshStateFromUserContext()
        subscribeToUserEvents()
    }

    var title: String { "Verify Your Email" }

    var subtitle: String {
        let fallbackEmail = emailAddress.isEmpty ? "your email address" : emailAddress
        return "LifeIQ sent a verification link to \(fallbackEmail). Check your inbox, spam, or promotions, then come back and refresh to continue."
    }

    func refreshStatusTapped() {
        Task { await refreshVerificationStatus() }
    }

    func resendEmailTapped() {
        Task { await resendVerificationEmail() }
    }

    func logOutTapped() {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        defer { isLoggingOut = false }

        do {
            try authManager.signOut()
            hub.toastEvents.send(.present(.init(title: "Logged out", style: .success)))
            hub.domainEvents.send(.dismissDashboardNavStack)
        } catch {
            presentError(error)
        }
    }

    private func subscribeToUserEvents() {
        hub.userEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshStateFromUserContext()
            }
            .store(in: &cancellables)
    }

    private func refreshStateFromUserContext() {
        emailAddress = userState.emailVerificationRequirement?.email
            ?? userState.loggedInUser?.email
            ?? ""
        isVerificationRequired = userState.emailVerificationRequirement != nil
    }

    private func refreshVerificationStatus() async {
        guard !isRefreshingStatus else { return }
        isRefreshingStatus = true
        defer { isRefreshingStatus = false }

        do {
            let firebaseUser = try await authManager.reloadCurrentUser()
            SQLogger.shared.log(
                "Email Verification: refreshed verification status for \(firebaseUser.uid); isEmailVerified=\(firebaseUser.isEmailVerified)",
                .info,
                context: .loginSignup,
                isPriority: true
            )
            await SQUserManager.shared.handleAuthStateChange(
                firebaseUser: firebaseUser,
                userState: SQAppState.shared.userState
            )

            if SQAuthManager.emailVerificationRequirement(for: firebaseUser) == nil {
                hub.toastEvents.send(.present(.init(title: "Email verified", style: .success)))
                hub.userEvents.send(.profileUpdated)
            } else {
                SQLogger.shared.log(
                    "Email Verification: refresh completed but email is still unverified for \(firebaseUser.uid)",
                    .warning,
                    context: .loginSignup
                )
                hub.alertEvents.send(.present(.init(
                    SQError.standard(
                        withDescription: "Your email is not verified yet. Open the verification link from your inbox, then try again."
                    )
                )))
            }
        } catch {
            SQLogger.shared.log(
                "Email Verification: failed to refresh verification status: \(error.localizedDescription)",
                .warning,
                context: .loginSignup,
                isPriority: true
            )
            presentError(error)
        }
    }

    private func resendVerificationEmail() async {
        guard !isResendingEmail else { return }
        isResendingEmail = true
        defer { isResendingEmail = false }

        do {
            try await authManager.sendEmailVerification()
            let email = emailAddress.isEmpty ? "unknown-email" : emailAddress
            SQLogger.shared.log(
                "Email Verification: resend succeeded for \(email)",
                .info,
                context: .loginSignup,
                isPriority: true
            )
            hub.toastEvents.send(.present(.init(
                title: "Verification email resent",
                subtitle: "If you don't see it, check spam or promotions.",
                style: .success,
                duration: 4.0
            )))
        } catch {
            let email = emailAddress.isEmpty ? "unknown-email" : emailAddress
            SQLogger.shared.log(
                "Email Verification: resend failed for \(email): \(error.localizedDescription)",
                .warning,
                context: .loginSignup,
                isPriority: true
            )
            presentError(error)
        }
    }

    private func presentError(_ error: Error) {
        if let authError = error as? SQAuthError {
            guard authError.shouldPresentToUser else { return }
            hub.alertEvents.send(.present(.init(authError)))
            return
        }

        hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
    }
}
