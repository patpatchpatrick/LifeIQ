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

    init() {
        self.navigationState = .init(hub: hub)
        self.dashboardState = .init(hub: hub)
    }
}
