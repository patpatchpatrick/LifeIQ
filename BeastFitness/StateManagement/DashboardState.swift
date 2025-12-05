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
    var rowViewModels: [SQDashboardRowViewModel] { get }
    var dailyCheckInViewModel: SQDailyCheckInViewModel? { get }
    
    /// Actions
    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool)
    func changeTab(to tab: NavigationState.Tab)
    func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?)
    func updateRowViewModels(to rowViewModels: [SQDashboardRowViewModel])
}

@MainActor
@Observable final class DashboardState: DashboardStating {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    var isDailyCheckInSheetVisible: Bool = false
    
    private(set) var dailyCheckInViewModel: SQDailyCheckInViewModel?
    private(set) var rowViewModels: [SQDashboardRowViewModel] = []
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func changeTab(to tab: NavigationState.Tab) {
        hub.events.send(.changeTab(tab))
    }
    
    func updateRowViewModels(to rowViewModels: [SQDashboardRowViewModel]) {
        self.rowViewModels = rowViewModels
    }
    
    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool) {
        isDailyCheckInSheetVisible = isVisible
    }
    
    func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?) {
        dailyCheckInViewModel = .init(
            stats: stats,
            onDismiss: { [weak self] in
                self?.toggleDailyCheckInSheetVisibility(false)
            })
        
        toggleDailyCheckInSheetVisibility(true)
    }
}
