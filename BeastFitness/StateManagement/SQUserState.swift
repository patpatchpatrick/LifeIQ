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
    func setLoggedIn(_ user: SQUser)
    func setLoggedOut()
}

@MainActor
@Observable final class SQUserState: SQUserStating {
    let hub: EventHub

    private(set) var isLoggedIn: Bool = false
    private(set) var loggedInUser: SQUser? = nil
    private(set) var hasResolvedInitialAuthState: Bool = false

    init(hub: EventHub) {
        self.hub = hub
    }

    func setLoggedIn(_ user: SQUser) {
        guard !hasResolvedInitialAuthState || !isLoggedIn || loggedInUser?.id != user.id else { return }
        loggedInUser = user
        isLoggedIn = true
        hasResolvedInitialAuthState = true
        hub.userEvents.send(.loginStateChanged(isLoggedIn: true))
    }

    func setLoggedOut() {
        guard !hasResolvedInitialAuthState || isLoggedIn || loggedInUser != nil else { return }
        loggedInUser = nil
        isLoggedIn = false
        hasResolvedInitialAuthState = true
        hub.userEvents.send(.loginStateChanged(isLoggedIn: false))
    }
}
