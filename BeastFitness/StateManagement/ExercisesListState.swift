//
//  ExercisesListState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

@MainActor
protocol ExercisesListStating: AnyObject {
}

@MainActor
@Observable final class ExercisesListState: ExercisesListStating {
    
    private let hub: EventHub
    
    init(hub: EventHub) {
        self.hub = hub
    }
}
