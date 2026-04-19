//
//  SQUserState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI
import Combine

struct SQEmailVerificationRequirement: Equatable {
    let email: String
}

@MainActor
protocol SQUserStating: AnyObject {
    var hub: EventHub { get }
    var isLoggedIn: Bool { get }
    var loggedInUser: SQUser? { get }
    var emailVerificationRequirement: SQEmailVerificationRequirement? { get }
    var hasResolvedInitialAuthState: Bool { get }
    var hasLoadedUserProfile: Bool { get }
    func setLoggedIn(_ user: SQUser)
    func setLoggedIn(_ user: SQUser, hasLoadedProfile: Bool, emailVerificationRequirement: SQEmailVerificationRequirement?)
    func updateLoggedInUser(_ user: SQUser, hasLoadedProfile: Bool, emailVerificationRequirement: SQEmailVerificationRequirement?)
    func setLoggedOut()
}

@MainActor
@Observable final class SQUserState: SQUserStating {
    let hub: EventHub

    private(set) var isLoggedIn: Bool = false
    private(set) var loggedInUser: SQUser? = nil
    private(set) var emailVerificationRequirement: SQEmailVerificationRequirement? = nil
    private(set) var hasResolvedInitialAuthState: Bool = false
    private(set) var hasLoadedUserProfile: Bool = false

    init(hub: EventHub) {
        self.hub = hub
    }

    func setLoggedIn(_ user: SQUser) {
        setLoggedIn(user, hasLoadedProfile: false, emailVerificationRequirement: nil)
    }

    func setLoggedIn(
        _ user: SQUser,
        hasLoadedProfile: Bool,
        emailVerificationRequirement: SQEmailVerificationRequirement?
    ) {
        let didAuthFieldsChange =
            !hasResolvedInitialAuthState
            || !isLoggedIn
            || loggedInUser != user
            || self.hasLoadedUserProfile != hasLoadedProfile
        let didVerificationRequirementChange = self.emailVerificationRequirement != emailVerificationRequirement
        guard didAuthFieldsChange || didVerificationRequirementChange else { return }

        loggedInUser = user
        isLoggedIn = true
        hasResolvedInitialAuthState = true
        hasLoadedUserProfile = hasLoadedProfile
        applyEmailVerificationRequirement(emailVerificationRequirement)

        if didAuthFieldsChange {
            hub.userEvents.send(.loginStateChanged(isLoggedIn: true))
        }
    }

    func updateLoggedInUser(
        _ user: SQUser,
        hasLoadedProfile: Bool,
        emailVerificationRequirement: SQEmailVerificationRequirement?
    ) {
        loggedInUser = user
        isLoggedIn = true
        hasResolvedInitialAuthState = true
        hasLoadedUserProfile = hasLoadedProfile
        applyEmailVerificationRequirement(emailVerificationRequirement)
    }

    func setLoggedOut() {
        guard !hasResolvedInitialAuthState || isLoggedIn || loggedInUser != nil else { return }
        loggedInUser = nil
        isLoggedIn = false
        hasResolvedInitialAuthState = true
        hasLoadedUserProfile = false
        applyEmailVerificationRequirement(nil)
        hub.userEvents.send(.loginStateChanged(isLoggedIn: false))
    }

    private func applyEmailVerificationRequirement(_ requirement: SQEmailVerificationRequirement?) {
        guard emailVerificationRequirement != requirement else { return }
        emailVerificationRequirement = requirement
        hub.userEvents.send(.emailVerificationStateChanged(isRequired: requirement != nil))
    }
}
