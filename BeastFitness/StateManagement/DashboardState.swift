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

enum TotalsType: String, CaseIterable {
    case time = "Time"
    case kilocalories = "Kilocalories"
}

@MainActor
protocol DashboardStating: AnyObject {
    var hub: EventHub { get }

    /// State
    
    var sectionGroups: [SQDashboardSectionGroupViewModel] { get }
    var selectedTimeRange: AppTimeRange { get set }
    var selectedTimeRangePublisher: AnyPublisher<AppTimeRange, Never> { get }
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

    private let selectedTimeRangeSubject = PassthroughSubject<AppTimeRange, Never>()
    var selectedTimeRangePublisher: AnyPublisher<AppTimeRange, Never> {
        selectedTimeRangeSubject.eraseToAnyPublisher()
    }

    var selectedTimeRange: AppTimeRange = .today {
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
        // Determine initial time range based on dashboard selection
        let initialTimeRange: AppTimeRange = {
            // Exception: Today → All Time (not enough data for meaningful leaderboard)
            if selectedTimeRange == .today {
                return .allTime
            }

            // Fallback: If time range not available, use last (largest) time range
            if !AppTimeRange.allCases.contains(selectedTimeRange) {
                return AppTimeRange.allCases
                    .sorted(by: { $0.sortOrder < $1.sortOrder })
                    .last ?? .allTime
            }

            return selectedTimeRange
        }()

        leaderboardController = .init(
            state: SQAppState.shared.leaderboardState,
            quantityType: quantityType,
            activityType: activityType,
            initialTimeRange: initialTimeRange
        )
        toggleLeaderboardSheetVisibility(true)
    }
}
