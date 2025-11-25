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
    /// State
    var isDailyCheckInSheetVisible: Bool { get }
    
    /// Actions
    func changeTab(to tab: NavigationState.Tab)
    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool)
}

@MainActor
@Observable final class DashboardState: DashboardStating {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    var isDailyCheckInSheetVisible: Bool = false
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func changeTab(to tab: NavigationState.Tab) {
        hub.events.send(.changeTab(tab))
    }
    
    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool) {
        isDailyCheckInSheetVisible = isVisible
    }
}
