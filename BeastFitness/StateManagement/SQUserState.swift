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
    func setLoggedIn(_ user: SQUser)
    func setLoggedOut()
}

@MainActor
@Observable final class SQUserState: SQUserStating {
    let hub: EventHub

    private(set) var isLoggedIn: Bool = false
    private(set) var loggedInUser: SQUser? = nil

    init(hub: EventHub) {
        self.hub = hub
    }

    func setLoggedIn(_ user: SQUser) {
        loggedInUser = user
        isLoggedIn = true
    }

    func setLoggedOut() {
        loggedInUser = nil
        isLoggedIn = false
    }
}
