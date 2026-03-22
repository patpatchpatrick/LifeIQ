//
//  SQProfileController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI
import Combine
import BeastFitnessCore

@MainActor
protocol SQProfileInterface: AnyObject {
    var title: String { get }
}

@MainActor
@Observable final class SQProfileController: SQProfileInterface, Identifiable {
    let id = UUID().uuidString
    let hub: EventHub
    let userState: SQUserStating
    let authManager: SQAuthManaging

    var title: String { "Profile" }

    // MARK: - Button view models (nil = hidden)

    var loginButtonViewModel: SQButtonViewModel?
    var signUpButtonViewModel: SQButtonViewModel?
    var logOutButtonViewModel: SQButtonViewModel?
    var isLoggingOut = false

    private var cancellables = Set<AnyCancellable>()

    init(hub: EventHub = SQAppState.shared.hub, userState: SQUserStating = SQAppState.shared.userState, authManager: SQAuthManaging = SQAuthManager.shared) {
        self.hub = hub
        self.userState = userState
        self.authManager = authManager
        refreshUI()
        subscribeToUserEvents()
    }

    // MARK: - Private

    private func subscribeToUserEvents() {
        hub.userEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .loginStateChanged:
                    self?.refreshUI()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshUI() {
        if userState.isLoggedIn {
            loginButtonViewModel = nil
            signUpButtonViewModel = nil
            logOutButtonViewModel = SQButtonViewModel(title: "Log out") { [weak self] in
                self?.confirmLogOut()
            }
        } else {
            loginButtonViewModel = SQButtonViewModel(title: "Log in") { [weak self] in
                self?.showLogin(mode: .login)
            }
            signUpButtonViewModel = SQButtonViewModel(title: "Sign up") { [weak self] in
                self?.showLogin(mode: .signup)
            }
            logOutButtonViewModel = nil
        }
    }

    private func confirmLogOut() {
        let alert = SQAlertViewModel(
            title: "Log out?",
            subtitle: "Are you sure you want to log out?",
            primary: .init(title: "Log out", role: .destructive) { [weak self] _ in
                self?.performLogOut()
            },
            secondary: .init(title: "Cancel", role: .cancel)
        )
        hub.alertEvents.send(.present(alert))
    }

    private func performLogOut() {
        isLoggingOut = true
        do {
            try authManager.signOut()
            hub.toastEvents.send(.present(.init(title: "Logout successful", style: .success)))
            hub.domainEvents.send(.dismissDashboardNavStack)
        } catch {
            SQLogger.shared.log("Sign out failed: \(error.localizedDescription)", .error, context: .general)
            hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
        }
        isLoggingOut = false
    }

    private func showLogin(mode: SQLoginMode) {
        let controller = SQLoginController(mode: mode)
        hub.domainEvents.send(.pushDashboardRoute(.login(controller: controller)))
    }
}
