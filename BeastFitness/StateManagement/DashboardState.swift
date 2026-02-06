//
//  DashboardState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI
import Combine

enum DashboardTimeRange: String, CaseIterable {
    case today = "Today"
    case pastSevenDays = "Past 7 Days"
    case pastYear = "Past Year"

    func toSQTimeRange() -> SQTimeRange {
        switch self {
        case .today:
            return .today
        case .pastSevenDays:
            return .pastWeek
        case .pastYear:
            return .pastYear
        }
    }
}

@MainActor
protocol DashboardStating: AnyObject {
    var hub: EventHub { get }

    /// State
    ///
    var sectionViewModels: [SQDashboardSectionViewModel] { get }
    var selectedTimeRange: DashboardTimeRange { get set }
    var selectedTimeRangePublisher: AnyPublisher<DashboardTimeRange, Never> { get }
    var isLoading: Bool { get }

    var isDailyCheckInSheetVisible: Bool { get }
    var dailyCheckInViewModel: SQDailyCheckInViewModel? { get }
    var dailyCheckInCtaViewModel: SQCallToActionViewModel? { get }

    var isWorkoutListSheetVisible: Bool { get }
    var workoutsListController: SQWorkoutsListController? { get }
    
    /// Actions
    func changeTab(to tab: NavigationState.Tab)

    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool)
    func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?, for date: Date?)
    func updateDailyCheckInCtaViewModel(_ viewModel: SQCallToActionViewModel?)

    func updateSectionViewModels(to sectionViewModels: [SQDashboardSectionViewModel])
    func setLoading(_ isLoading: Bool)

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

    private let selectedTimeRangeSubject = PassthroughSubject<DashboardTimeRange, Never>()
    var selectedTimeRangePublisher: AnyPublisher<DashboardTimeRange, Never> {
        selectedTimeRangeSubject.eraseToAnyPublisher()
    }

    var selectedTimeRange: DashboardTimeRange = .today {
        didSet {
            selectedTimeRangeSubject.send(selectedTimeRange)
        }
    }

    private(set) var isLoading: Bool = false
    private(set) var dailyCheckInCtaViewModel: SQCallToActionViewModel?

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

    func updateDailyCheckInCtaViewModel(_ viewModel: SQCallToActionViewModel?) {
        self.dailyCheckInCtaViewModel = viewModel
    }

    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool) {
        isDailyCheckInSheetVisible = isVisible
    }
    
    func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?, for date: Date? = nil) {
        let targetDate = date ?? .now
        dailyCheckInViewModel = .init(
            eventHub: SQAppState.shared.hub,
            stats: stats,
            targetDate: targetDate,
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
