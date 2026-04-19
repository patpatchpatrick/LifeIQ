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
    private static let resendCooldownInterval: TimeInterval = 60
    private static let resendWindowInterval: TimeInterval = 60 * 60 * 6
    private static let resendMaxAttemptsPerWindow = 5

    let id = UUID().uuidString
    let hub: EventHub
    let userState: SQUserStating
    let authManager: SQAuthManaging

    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var resendRefreshTask: Task<Void, Never>?

    private(set) var emailAddress: String = ""
    private(set) var isVerificationRequired: Bool = false
    var isRefreshingStatus = false
    var isResendingEmail = false
    var isLoggingOut = false
    private var resendStateReferenceDate: Date = .now

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
        startResendStateRefreshLoop()
    }

    deinit {
        resendRefreshTask?.cancel()
    }

    var title: String { "Verify Your Email" }

    var subtitle: String {
        let fallbackEmail = emailAddress.isEmpty ? "your email address" : emailAddress
        return "LifeIQ sent a verification link to \(fallbackEmail). Check your inbox, spam, or promotions, then come back and refresh to continue."
    }

    var resendButtonTitle: String {
        if let cooldownSeconds = resendCooldownSecondsRemaining {
            return "Resend in \(cooldownSeconds)s"
        }

        return "Resend Verification Email"
    }

    var resendHelperText: String? {
        if let cooldownSeconds = resendCooldownSecondsRemaining {
            return "You can request another verification email in \(cooldownSeconds) seconds."
        }

        if let lockoutDurationText = resendWindowLockoutDurationText {
            return "You've reached the resend limit. Try again in \(lockoutDurationText)."
        }

        return "You can request up to \(Self.resendMaxAttemptsPerWindow) verification emails every 6 hours."
    }

    var isResendDisabled: Bool {
        isResendingEmail || resendCooldownSecondsRemaining != nil || resendWindowLockoutDurationText != nil
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
        resendStateReferenceDate = .now
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
        guard !isResendDisabled else { return }
        isResendingEmail = true
        defer { isResendingEmail = false }

        do {
            try await authManager.sendEmailVerification()
            let email = emailAddress.isEmpty ? "unknown-email" : emailAddress
            if let userId = currentUserId {
                SQUserDefaults.shared.appendEmailVerificationResendAttempt(for: userId)
            }
            resendStateReferenceDate = .now
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
            let authError = SQAuthError.from(error)
            SQLogger.shared.log(
                "Email Verification: resend failed for \(email): \(error.localizedDescription)",
                .warning,
                context: .loginSignup,
                isPriority: true
            )
            presentError(authError)
        }
    }

    private var currentUserId: String? {
        userState.loggedInUser?.id
    }

    private var resendAttemptDatesWithinWindow: [Date] {
        guard let userId = currentUserId else { return [] }
        let cutoffDate = resendStateReferenceDate.addingTimeInterval(-Self.resendWindowInterval)
        let filteredDates = SQUserDefaults.shared
            .emailVerificationResendAttemptDates(for: userId)
            .filter { $0 >= cutoffDate }

        let storedDates = SQUserDefaults.shared.emailVerificationResendAttemptDates(for: userId)
        if filteredDates.count != storedDates.count {
            SQUserDefaults.shared.setEmailVerificationResendAttemptDates(filteredDates, for: userId)
        }

        return filteredDates.sorted()
    }

    private var resendCooldownSecondsRemaining: Int? {
        guard let lastAttemptDate = resendAttemptDatesWithinWindow.last else { return nil }
        let remaining = Int(ceil(lastAttemptDate.addingTimeInterval(Self.resendCooldownInterval).timeIntervalSince(resendStateReferenceDate)))
        return remaining > 0 ? remaining : nil
    }

    private var resendWindowLockoutDurationText: String? {
        let attempts = resendAttemptDatesWithinWindow
        guard attempts.count >= Self.resendMaxAttemptsPerWindow,
              let oldestAttemptInWindow = attempts.first else { return nil }

        let unlockDate = oldestAttemptInWindow.addingTimeInterval(Self.resendWindowInterval)
        let remaining = unlockDate.timeIntervalSince(resendStateReferenceDate)
        guard remaining > 0 else { return nil }

        let totalMinutes = max(1, Int(ceil(remaining / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0, minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func startResendStateRefreshLoop() {
        resendRefreshTask?.cancel()
        resendRefreshTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.resendStateReferenceDate = .now
                try? await Task.sleep(for: .seconds(1))
            }
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
