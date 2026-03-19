//
//  SQProfileController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI

@MainActor
protocol SQProfileInterface: AnyObject {
    var title: String { get }
}

@MainActor
@Observable final class SQProfileController: SQProfileInterface, Identifiable {
    let id = UUID().uuidString
    let hub: EventHub
    let userState: SQUserStating

    var title: String { "Profile" }

    init(hub: EventHub = SQAppState.shared.hub, userState: SQUserStating = SQAppState.shared.userState) {
        self.hub = hub
        self.userState = userState
    }

    func showLogin(mode: SQLoginMode) {
        let controller = SQLoginController(mode: mode)
        hub.domainEvents.send(.pushDashboardRoute(.login(controller: controller)))
    }
}
