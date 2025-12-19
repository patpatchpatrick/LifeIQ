//
//  SWRootViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import SwiftUI

@Observable
@MainActor
final class SWRootViewModel {
    let rootState: SWRootStating
    
    // MARK: - Init
    
    init(appState: SWAppState) {
        self.rootState = appState.rootState
        
        if appState.useMockData {
            SWWorkoutManager.shared.startWorkout(with: .init())
        }
    }
}
