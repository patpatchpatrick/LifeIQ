//
//  DashboardState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI
import Combine
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
    var loadingProgress: Double? { get }

    var isDailyCheckInSheetVisible: Bool { get }
    var dailyCheckInViewModel: SQDailyCheckInViewModel? { get }
    var dailyCheckInCtaViewModel: SQCallToActionViewModel? { get }
    var availableLayoutGroups: [SQDashboardLayoutGroupDescriptor] { get }
    var uncustomizedSectionGroups: [SQDashboardSectionGroupViewModel] { get }

    /// Actions
    func changeTab(to tab: NavigationState.Tab)

    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool)
    func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?, for date: Date?, period: SQMetricPeriod?)
    func updateDailyCheckInCtaViewModel(_ viewModel: SQCallToActionViewModel?)
    func updateAvailableLayoutGroups(_ groups: [SQDashboardLayoutGroupDescriptor])
    func updateUncustomizedSectionGroups(_ groups: [SQDashboardSectionGroupViewModel])

    func updateSectionGroups(to sectionGroups: [SQDashboardSectionGroupViewModel])
    func setLoading(_ isLoading: Bool)
    func updateLoadingProgress(_ progress: Double?)

    func navigateToWorkoutView(with workouts: [SQWorkoutSessionable])

    func displayLeaderboard(mode: SQLeaderboardMode)
    func displayMetricDetail(metricId: String)
}

struct SQCheckInPromptContext {
    let date: Date
    let period: SQMetricPeriod
}

@MainActor
@Observable final class DashboardState: DashboardStating {
    let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    private(set) var isDailyCheckInSheetVisible: Bool = false
    private(set) var isLeaderboardSheetVisible: Bool = false

    private(set) var dailyCheckInViewModel: SQDailyCheckInViewModel?
    private(set) var sectionGroups: [SQDashboardSectionGroupViewModel] = []
    private(set) var availableLayoutGroups: [SQDashboardLayoutGroupDescriptor] = []
    private(set) var uncustomizedSectionGroups: [SQDashboardSectionGroupViewModel] = []

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
    private(set) var loadingProgress: Double?
    private(set) var dailyCheckInCtaViewModel: SQCallToActionViewModel?

    init(hub: EventHub) {
        self.hub = hub
    }
    
    func changeTab(to tab: NavigationState.Tab) {
        hub.domainEvents.send(.changeTab(tab))
    }

    func updateSectionGroups(to sectionGroups: [SQDashboardSectionGroupViewModel]) {
        self.sectionGroups = sectionGroups
    }

    func updateAvailableLayoutGroups(_ groups: [SQDashboardLayoutGroupDescriptor]) {
        availableLayoutGroups = groups
    }

    func updateUncustomizedSectionGroups(_ groups: [SQDashboardSectionGroupViewModel]) {
        uncustomizedSectionGroups = groups
    }

    func updateDailyCheckInCtaViewModel(_ viewModel: SQCallToActionViewModel?) {
        self.dailyCheckInCtaViewModel = viewModel
    }

    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
        if isLoading {
            loadingProgress = 0.05
        } else {
            loadingProgress = nil
        }
    }

    func updateLoadingProgress(_ progress: Double?) {
        guard let progress else {
            loadingProgress = nil
            return
        }
        guard isLoading else { return }
        loadingProgress = max(0, min(1, progress))
    }

    func toggleDailyCheckInSheetVisibility(_ isVisible: Bool) {
        isDailyCheckInSheetVisible = isVisible
    }
    
    func displayDailyCheckInSheet(
        with stats: SQDailyCheckInStats?,
        for date: Date? = nil,
        period: SQMetricPeriod? = nil
    ) {
        let targetDate = date ?? .now
        let resolvedPeriod = period ?? Self.checkInPeriod(for: targetDate)

        dailyCheckInViewModel = .init(
            eventHub: SQAppState.shared.hub,
            stats: stats,
            targetDate: targetDate,
            period: resolvedPeriod,
            metricsManager: SQMetricDefinitionManager.shared,
            onDismiss: { [weak self] in
                self?.toggleDailyCheckInSheetVisibility(false)
            })

        toggleDailyCheckInSheetVisibility(true)
    }

    /// Determines which check-in flow to open for the current time.
    /// Uses the user's usual sleep schedule when available; otherwise falls back to fixed daytime cutoffs.
    static func checkInPeriod(for date: Date, sleepSchedule: SQSleepSchedule? = nil) -> SQMetricPeriod {
        guard let sleepSchedule else {
            let hour = Calendar.current.component(.hour, from: date)
            return hour < 16 ? .morning : .evening
        }

        let currentMinutes = minutesSinceMidnight(for: date)
        let wakeMinutes = sleepSchedule.wakeTime.minutesSinceMidnight
        let eveningStartMinutes = positiveModulo(
            sleepSchedule.sleepTime.minutesSinceMidnight - (7 * 60)
        )

        if isWithinCircularRange(
            currentMinutes,
            start: wakeMinutes,
            end: eveningStartMinutes
        ) {
            return .morning
        }

        return .evening
    }

    /// Determines whether the dashboard should actively prompt for a check-in.
    /// Uses a +/- 5 hour window around the user's wake time and sleep time. When both windows
    /// overlap, the closer anchor wins, with sleep time winning ties so late-night hours do not
    /// feel like "morning".
    static func checkInPromptPeriod(for date: Date, sleepSchedule: SQSleepSchedule? = nil) -> SQMetricPeriod? {
        let sleepSchedule = sleepSchedule ?? .onboardingDefault

        let currentMinutes = minutesSinceMidnight(for: date)
        let wakeMinutes = sleepSchedule.wakeTime.minutesSinceMidnight
        let sleepMinutes = sleepSchedule.sleepTime.minutesSinceMidnight
        let windowRadiusMinutes = 5 * 60
        let wakeDistance = circularDistance(from: currentMinutes, to: wakeMinutes)
        let sleepDistance = circularDistance(from: currentMinutes, to: sleepMinutes)

        let isWithinMorningWindow = wakeDistance <= windowRadiusMinutes
        let isWithinEveningWindow = sleepDistance <= windowRadiusMinutes

        switch (isWithinMorningWindow, isWithinEveningWindow) {
        case (true, false):
            return .morning
        case (false, true):
            return .evening
        case (true, true):
            return sleepDistance <= wakeDistance ? .evening : .morning
        case (false, false):
            return nil
        }
    }

    static func currentCheckInPromptContext(
        for date: Date,
        sleepSchedule: SQSleepSchedule? = nil
    ) -> SQCheckInPromptContext? {
        guard let period = checkInPromptPeriod(
            for: date,
            sleepSchedule: sleepSchedule
        ) else {
            return nil
        }

        return .init(
            date: currentCheckInDate(
                for: date,
                sleepSchedule: sleepSchedule
            ),
            period: period
        )
    }

    /// Returns the calendar date that should own the user's current check-in session.
    static func currentCheckInDate(for date: Date, sleepSchedule: SQSleepSchedule? = nil) -> Date {
        guard let sleepSchedule else {
            return date
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        let currentMinutes = minutesSinceMidnight(for: date)
        let wakeMinutes = sleepSchedule.wakeTime.minutesSinceMidnight

        if currentMinutes >= wakeMinutes {
            return startOfToday
        }

        return calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
    }

    private static func minutesSinceMidnight(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    private static func positiveModulo(_ value: Int, modulus: Int = 24 * 60) -> Int {
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private static func circularDistance(from value: Int, to anchor: Int, modulus: Int = 24 * 60) -> Int {
        let forward = positiveModulo(anchor - value, modulus: modulus)
        let backward = positiveModulo(value - anchor, modulus: modulus)
        return min(forward, backward)
    }

    private static func isWithinCircularRange(_ value: Int, start: Int, end: Int) -> Bool {
        guard start != end else { return false }

        if start < end {
            return value >= start && value < end
        }

        return value >= start || value < end
    }
    
    func navigateToWorkoutView(with workouts: [any SQWorkoutSessionable]) {
        if workouts.count == 1, let firstWorkout = workouts.first {
            hub.domainEvents.send(.pushDashboardRoute(.workoutSummary(controller: .init(workout: firstWorkout, mode: .standard))))
        } else {
            hub.domainEvents.send(.pushDashboardRoute(.workoutsList(workouts: workouts)))
        }
    }

    func toggleLeaderboardSheetVisibility(_ isVisible: Bool) {
        isLeaderboardSheetVisible = isVisible
    }

    func displayLeaderboard(mode: SQLeaderboardMode) {
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

        SQAnalyticsManager.shared.track(.dashboardItemOpened(
            itemType: "leaderboard",
            itemId: mode.analyticsIdentifier,
            sourceGroup: "dashboard",
            score: nil
        ))
        SQAnalyticsManager.shared.track(.leaderboardOpened(mode: mode, sourceScreen: "dashboard"))

        let leaderboardController = SQLeaderboardController(
            hub: hub,
            mode: mode,
            initialTimeRange: initialTimeRange
        )
        
        hub.domainEvents.send(.pushDashboardRoute(.leaderboard(controller: leaderboardController)))
    }

    func displayMetricDetail(metricId: String) {
        let metricDefinition = SQMetricDefinitionManager.shared.metrics.first(where: { $0.id == metricId })

        SQAnalyticsManager.shared.track(.dashboardItemOpened(
            itemType: "metric_detail",
            itemId: metricId,
            sourceGroup: "metrics",
            score: nil
        ))
        SQAnalyticsManager.shared.track(.metricDetailViewed(
            metricId: metricId,
            definition: metricDefinition,
            sourceScreen: "dashboard"
        ))

        let metricDetailController = SQMetricDetailController(
            hub: hub,
            metricId: metricId,
            initialTimeRange: selectedTimeRange
        )

        hub.domainEvents.send(.pushDashboardRoute(.metricDetail(controller: metricDetailController)))
    }
}
