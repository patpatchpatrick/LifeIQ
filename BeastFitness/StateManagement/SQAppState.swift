//
//  SQAppState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//


import SwiftUI
import Combine

@MainActor
@Observable
final class SQAppState {
    static let shared = SQAppState()
    
    let hub = EventHub()

    let userState: SQUserState
    let navigationState: NavigationState

    let dashboardState: DashboardState

    let workoutSessionState: WorkoutSessionState
    let workoutScreenState: WorkoutsLandingState
    let workoutsListState: WorkoutsListState
    let workoutSummaryState: WorkoutSummaryState

    let exercisesListState: ExercisesListState
    let metricsListState: SQMetricsListState
    let alertState: SQAlertState
    let settingsState: SettingsState
    let toastState: SQToastState

    init() {
        self.userState = .init(hub: hub)
        self.navigationState = .init(hub: hub)
        self.dashboardState = .init(hub: hub)
        self.workoutSessionState = .init(hub: hub)
        self.workoutScreenState = .init(hub: hub)
        self.workoutsListState = .init(hub: hub)
        self.workoutSummaryState = .init(hub: hub)
        self.exercisesListState = .init(hub: hub)
        self.metricsListState = .init(hub: hub)
        self.alertState = .init(hub: hub)
        self.settingsState = .init(hub: hub)
        self.toastState = .init(hub: hub)
    }
}
