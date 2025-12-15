//
//  WorkoutsListState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

@MainActor
protocol WorkoutsListStating: AnyObject {
    var hub: EventHub { get }
}

@MainActor
@Observable final class WorkoutsListState: WorkoutsListStating {
    let hub: EventHub
    
    init(hub: EventHub) {
        self.hub = hub
    }
}
