//
//  LeaderboardState.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI
import BeastFitnessCore

@MainActor
protocol LeaderboardStating: AnyObject {
    var hub: EventHub { get }
}

@MainActor
@Observable final class LeaderboardState: LeaderboardStating {
    let hub: EventHub

    init(hub: EventHub) {
        self.hub = hub
    }
}
