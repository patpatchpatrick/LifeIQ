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
    var workoutSessionController: SQWorkoutSessionController? { get }
    
    /// Actions
    func changeTab(to tab: NavigationState.Tab)
    func toggleWorkoutSessionSheetVisibility(_ isVisible: Bool)
    func displayWorkoutSessionSheet()
}

@MainActor
@Observable final class WorkoutsLandingState: WorkoutsLandingStating {
    private let hub: EventHub
    var isWorkoutSessionSheetVisible: Bool = false
    private(set) var workoutSessionController: SQWorkoutSessionController?
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func changeTab(to tab: NavigationState.Tab) {
        hub.domainEvents.send(.changeTab(tab))
    }
    
    func toggleWorkoutSessionSheetVisibility(_ isVisible: Bool) {
        isWorkoutSessionSheetVisible = isVisible
    }
    
    func displayWorkoutSessionSheet() {
        workoutSessionController = .default(for: nil, onDismiss: { [weak self] in
            self?.toggleWorkoutSessionSheetVisibility(false)
        })
        workoutSessionController?.willAppear(with: nil)
        isWorkoutSessionSheetVisible = true
    }
}
