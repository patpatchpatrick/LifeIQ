//
//  WorkoutsLandingState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI
import Combine

@MainActor
protocol WorkoutsLandingStating: AnyObject {
    /// State
    var isWorkoutSessionSheetVisible: Bool { get }
    var workoutSessionViewModel: SQWorkoutSessionViewModel? { get }
    
    /// Actions
    func changeTab(to tab: NavigationState.Tab)
    func toggleWorkoutSessionSheetVisibility(_ isVisible: Bool)
    func displayWorkoutSessionSheet()
}

@MainActor
@Observable final class WorkoutsLandingState: WorkoutsLandingStating {
    private let hub: EventHub
    var isWorkoutSessionSheetVisible: Bool = false
    private(set) var workoutSessionViewModel: SQWorkoutSessionViewModel?
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func changeTab(to tab: NavigationState.Tab) {
        hub.events.send(.changeTab(tab))
    }
    
    func toggleWorkoutSessionSheetVisibility(_ isVisible: Bool) {
        isWorkoutSessionSheetVisible = isVisible
    }
    
    func displayWorkoutSessionSheet() {
        workoutSessionViewModel = .init(state: AppState.shared.workoutSessionState)
        isWorkoutSessionSheetVisible = true
    }
}
