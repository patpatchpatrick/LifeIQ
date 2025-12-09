//
//  AppState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//


import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    static let shared = AppState()
    
    let hub = EventHub()

    let navigationState: NavigationState
    
    let dashboardState: DashboardState
    
    let workoutSessionState: WorkoutSessionState
    let workoutScreenState: WorkoutsLandingState
    let workoutsListState: WorkoutsListState
    let workoutSummaryState: WorkoutSummaryState
    
    let exercisesListState: ExercisesListState

    init() {
        self.navigationState = .init(hub: hub)
        self.dashboardState = .init(hub: hub)
        self.workoutSessionState = .init(hub: hub)
        self.workoutScreenState = .init(hub: hub)
        self.workoutsListState = .init(hub: hub)
        self.workoutSummaryState = .init(hub: hub)
        self.exercisesListState = .init(hub: hub)
    }
}
