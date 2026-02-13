//
//  DashboardState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI
import Combine
import HealthKit
import BeastFitnessCore

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

enum TotalsType: String, CaseIterable {
    case time = "Time"
    case kilocalories = "Kilocalories"
}

@MainActor
protocol DashboardStating: AnyObject {
    var hub: EventHub { get }

    /// State
    
    var sectionGroups: [SQDashboardSectionGroupViewModel] { get }
    var selectedTimeRange: DashboardTimeRange { get set }
    var selectedTimeRangePublisher: AnyPublisher<DashboardTimeRange, Never> { get }
    var isLoading: Bool { get }

    var isDailyCheckInSheetVisible: Bool { get }
    var dailyCheckInViewModel: SQDailyCheckInViewModel? { get }
    var dailyCheckInCtaViewModel: SQCallToActionViewModel? { get }

    var isWorkoutListSheetVisible: Bool { get }
    var workoutsListController: SQWorkoutsListController? { get }

    var isLeaderboardSheetVisible: Bool { get }
    var leaderboardController: SQLeaderboardController? { get }

    /// Actions
    func changeTab(to tab: NavigationState.Tab)

    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool)
    func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?, for date: Date?)
    func updateDailyCheckInCtaViewModel(_ viewModel: SQCallToActionViewModel?)

    func updateSectionGroups(to sectionGroups: [SQDashboardSectionGroupViewModel])
    func setLoading(_ isLoading: Bool)

    func toggleWorkoutListSheetVisibility(_ isVisible: Bool)
    func displayWorkoutsListSheet(with workouts: [SQWorkoutSessionable])

    func toggleLeaderboardSheetVisibility(_ isVisible: Bool)
    func displayLeaderboardSheet(quantityType: SQQuantityType, activityType: HKWorkoutActivityType)
}

@MainActor
@Observable final class DashboardState: DashboardStating {
    let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    private(set) var isDailyCheckInSheetVisible: Bool = false
    private(set) var isWorkoutListSheetVisible: Bool = false
    private(set) var isLeaderboardSheetVisible: Bool = false

    private(set) var dailyCheckInViewModel: SQDailyCheckInViewModel?
    private(set) var sectionGroups: [SQDashboardSectionGroupViewModel] = []

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
    private(set) var leaderboardController: SQLeaderboardController?

    init(hub: EventHub) {
        self.hub = hub
    }
    
    func changeTab(to tab: NavigationState.Tab) {
        hub.domainEvents.send(.changeTab(tab))
    }

    func updateSectionGroups(to sectionGroups: [SQDashboardSectionGroupViewModel]) {
        self.sectionGroups = sectionGroups
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

    func toggleLeaderboardSheetVisibility(_ isVisible: Bool) {
        isLeaderboardSheetVisible = isVisible
    }

    func displayLeaderboardSheet(quantityType: SQQuantityType, activityType: HKWorkoutActivityType) {
        leaderboardController = .init(
            state: SQAppState.shared.leaderboardState,
            quantityType: quantityType,
            activityType: activityType
        )
        toggleLeaderboardSheetVisibility(true)
    }
}
