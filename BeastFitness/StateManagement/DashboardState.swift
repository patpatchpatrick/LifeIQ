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
    var hub: EventHub { get }
    
    /// State
    ///
    var sectionViewModels: [SQDashboardSectionViewModel] { get }
    
    var isDailyCheckInSheetVisible: Bool { get }
    var dailyCheckInViewModel: SQDailyCheckInViewModel? { get }
    
    var isWorkoutListSheetVisible: Bool { get }
    var workoutsListController: SQWorkoutsListController? { get }
    
    /// Actions
    func changeTab(to tab: NavigationState.Tab)
    
    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool)
    func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?)
    
    func updateSectionViewModels(to sectionViewModels: [SQDashboardSectionViewModel])
    
    func toggleWorkoutListSheetVisibility(_ isVisible: Bool)
    func displayWorkoutsListSheet(with workouts: [SQWorkoutSessionable])
}

@MainActor
@Observable final class DashboardState: DashboardStating {
    let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    private(set) var isDailyCheckInSheetVisible: Bool = false
    private(set) var isWorkoutListSheetVisible: Bool = false
    
    private(set) var dailyCheckInViewModel: SQDailyCheckInViewModel?
    private(set) var sectionViewModels: [SQDashboardSectionViewModel] = []
    
    private(set) var workoutsListController: SQWorkoutsListController?
    
    init(hub: EventHub) {
        self.hub = hub
    }
    
    func changeTab(to tab: NavigationState.Tab) {
        hub.domainEvents.send(.changeTab(tab))
    }
    
    func updateSectionViewModels(to sectionViewModels: [SQDashboardSectionViewModel]) {
        self.sectionViewModels = sectionViewModels
    }
    
    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool) {
        isDailyCheckInSheetVisible = isVisible
    }
    
    func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?) {
        dailyCheckInViewModel = .init(
            eventHub: SQAppState.shared.hub,
            stats: stats,
            metricsManager: SQMetricsManager.shared,
            onDismiss: { [weak self] in
                self?.toggleDailyCheckInSheetVisibility(false)
            })
        
        toggleDailyCheckInSheetVisibility(true)
    }
    
    func toggleWorkoutListSheetVisibility(_ isVisible: Bool) {
        isWorkoutListSheetVisible = isVisible
    }
    
    func displayWorkoutsListSheet(with workouts: [any SQWorkoutSessionable]) {
        workoutsListController = .init(state: SQAppState.shared.workoutsListState, workouts: workouts)
        toggleWorkoutListSheetVisibility(true)
    }
}
