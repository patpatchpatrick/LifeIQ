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
    let userState: SQUserStating

    var title: String { "Profile" }

    init(userState: SQUserStating = SQAppState.shared.userState) {
        self.userState = userState
    }
}
