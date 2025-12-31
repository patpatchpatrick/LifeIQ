//
//  SWRootController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import SwiftUI

@Observable
@MainActor
final class SWRootController {
    let rootState: SWRootStating
    private let workoutManager: SWWorkoutManaging
    private let watchConnectivityManager: SWWatchConnectivityManaging
    
    // MARK: - Init
    
    init(appState: SWAppState) {
        self.rootState = appState.rootState
        self.workoutManager = SWWorkoutManager()
        self.watchConnectivityManager = SWWatchConnectivityManager.shared
        
        if appState.useMockData {
            workoutManager.startWorkout(with: .init())
        }
    }
}
