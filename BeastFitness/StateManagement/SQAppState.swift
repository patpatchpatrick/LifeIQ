//
//  SQAppState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//


import SwiftUI
import SwiftData
import Combine

@MainActor
@Observable
final class SQAppState {
    static let shared = SQAppState()

    var modelContext: ModelContext?

    let hub = EventHub()

    let userState: SQUserState
    let navigationState: NavigationState

    let dashboardState: DashboardState

    let leaderboardState: LeaderboardState

    let exercisesListState: ExercisesListState
    let metricsListState: SQMetricsListState
    let alertState: SQAlertState
    let modalState: SQModalState
    let settingsState: SettingsState
    let toastState: SQToastState
    let dropDownMenuState: SQDropDownMenuState

    init() {
        self.userState = .init(hub: hub)
        self.navigationState = .init(hub: hub)
        self.dashboardState = .init(hub: hub)
        self.leaderboardState = .init(hub: hub)
        self.exercisesListState = .init(hub: hub)
        self.metricsListState = .init(hub: hub)
        self.alertState = .init(hub: hub)
        self.modalState = .init(hub: hub)
        self.settingsState = .init(hub: hub)
        self.toastState = .init(hub: hub)
        self.dropDownMenuState = .init()
    }
}
