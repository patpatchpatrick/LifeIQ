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
    var loggedInUser: SQUser { get }
}

@MainActor
@Observable final class SQUserState: SQUserStating {
    let hub: EventHub

    /// TODO: Replace with actual user authentication
    var isLoggedIn: Bool = false

    /// The currently logged-in user
    /// TODO: Replace with actual user authentication
    var loggedInUser: SQUser = .mock

    init(hub: EventHub) {
        self.hub = hub
    }
}
