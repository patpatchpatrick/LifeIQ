//
//  SQUserState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI
import Combine

@MainActor
protocol SQUserStating: AnyObject {
    var hub: EventHub { get }
    var isLoggedIn: Bool { get }
    var loggedInUser: SQUser? { get }
    var hasResolvedInitialAuthState: Bool { get }
    var hasLoadedUserProfile: Bool { get }
    func setLoggedIn(_ user: SQUser)
    func setLoggedIn(_ user: SQUser, hasLoadedProfile: Bool)
    func updateLoggedInUser(_ user: SQUser, hasLoadedProfile: Bool)
    func setLoggedOut()
}

@MainActor
@Observable final class SQUserState: SQUserStating {
    let hub: EventHub

    private(set) var isLoggedIn: Bool = false
    private(set) var loggedInUser: SQUser? = nil
    private(set) var hasResolvedInitialAuthState: Bool = false
    private(set) var hasLoadedUserProfile: Bool = false

    init(hub: EventHub) {
        self.hub = hub
    }

    func setLoggedIn(_ user: SQUser) {
        setLoggedIn(user, hasLoadedProfile: false)
    }

    func setLoggedIn(_ user: SQUser, hasLoadedProfile: Bool) {
        guard !hasResolvedInitialAuthState || !isLoggedIn || loggedInUser != user || self.hasLoadedUserProfile != hasLoadedProfile else { return }
        loggedInUser = user
        isLoggedIn = true
        hasResolvedInitialAuthState = true
        hasLoadedUserProfile = hasLoadedProfile
        hub.userEvents.send(.loginStateChanged(isLoggedIn: true))
    }

    func updateLoggedInUser(_ user: SQUser, hasLoadedProfile: Bool) {
        loggedInUser = user
        isLoggedIn = true
        hasResolvedInitialAuthState = true
        hasLoadedUserProfile = hasLoadedProfile
    }

    func setLoggedOut() {
        guard !hasResolvedInitialAuthState || isLoggedIn || loggedInUser != nil else { return }
        loggedInUser = nil
        isLoggedIn = false
        hasResolvedInitialAuthState = true
        hasLoadedUserProfile = false
        hub.userEvents.send(.loginStateChanged(isLoggedIn: false))
    }
}
