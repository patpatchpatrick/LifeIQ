//
//  DashboardState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI
import Combine

@MainActor
protocol DashboardStating: AnyObject {
    func changeTab(to tab: NavigationState.Tab)
}

@MainActor
@Observable final class DashboardState: DashboardStating {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func changeTab(to tab: NavigationState.Tab) {
        hub.events.send(.changeTab(tab))
    }
}
