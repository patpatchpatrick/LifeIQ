//
//  SQDashboardController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI
import Combine
import SwiftData
import BeastFitnessCore
import HealthKit
import CoolCharts

@MainActor
protocol SQDashboardInterface {
    func loadUI(for context: ModelContext, shouldForceRefresh: Bool, showLoadingState: Bool, suppressErrorAlert: Bool) async
    func refreshUI(for context: ModelContext) async
    func displayDailyCheckInSheet(for context: ModelContext, date: Date?) async
}

@Observable @MainActor
final class SQDashboardController: SQDashboardInterface {
    private enum DashboardGridCardID {
        static let group = "dashboard-grid"
        static let sleep = "sleep-overview"
        static let sleepPhases = "sleep-phases"
        static let topInsight = "top-insight"
        static let keyMetrics = "key-metrics"
        static let latestWorkout = "latest-workout"
        static let activityCalories = "activity-calories"
        static let vo2Max = "vo2-max"
        static let heartOverview = "heart-overview"
    }

    private static let automaticForegroundRefreshMinimumInterval: TimeInterval = 180
    private var cancellables = Set<AnyCancellable>()
    var state: DashboardStating
    let navState: NavigationStating
    let userState: SQUserStating
    let metricEntryManager: SQMetricEntryManaging
    let metricsManager: SQMetricDefinitionManaging
    let workoutManager: SQWorkoutManaging
    let healthKitManager: SQHealthKitManaging
    let statsManager: SQWorkoutStatsManaging
    let sleepAggregationService: SQSleepAggregationService
    let bodyBatteryService: SQBodyBatteryServicing
    let heartRateService: SQHeartRateServicing
    let workoutScoreService: SQWorkoutScoreServicing
    let insightsService: SQInsightsServicing
    let lifeScoreBuilder: SQLifeScoreBuilding
    let dashboardLayoutService: SQDashboardLayoutServicing
    private(set) var hasLoadedUI = false
    private var isLoadUIInProgress = false
    private var pendingForcedRefresh = false
    private var pendingRefreshShowsLoadingState = false
    private var pendingRefreshSuppressesErrorAlert = false
    private var lastSuccessfulLoadAt: Date?
    let timeRangeMenuViewModel: SQDropDownMenuViewModel
    private(set) var availableLayoutGroups: [SQDashboardLayoutGroupDescriptor] = []
    private var lastLoadedSectionGroups: [SQDashboardSectionGroupViewModel] = []
    private var lastLoadedUncustomizedSectionGroups: [SQDashboardSectionGroupViewModel] = []
    private var lastLoadedAvailableLayoutGroups: [SQDashboardLayoutGroupDescriptor] = []
    private var lastLoadedDailyCheckInCtaViewModel: SQCallToActionViewModel?
    private var lastLoadedHealthKitAccessCtaViewModel: SQCallToActionViewModel?
    private var lastLoadedLifeScoreViewModel: SQLifeScoreViewModel?
    private var lastLoadedAllTimeWorkouts: [SQWorkoutSessionable] = []
    private let remoteConfigManager: SQRemoteConfigManaging
    var healthKitAccessCtaViewModel: SQCallToActionViewModel?
    var runtimeControlCtaViewModel: SQCallToActionViewModel?
    var lifeScoreViewModel: SQLifeScoreViewModel?
    let emailVerificationController: SQEmailVerificationController
    private(set) var emailVerificationRequirement: SQEmailVerificationRequirement?

    private var shouldUseDashboardDemoData: Bool {
        SQAdminConfig.useMockDashboardHealthData
            || userState.loggedInUser?.usesAppReviewDemoData == true
    }
    
    
    @MainActor
    static let `default` = SQDashboardController(state: SQAppState.shared.dashboardState, navState: SQAppState.shared.navigationState)
    
    init(
        state: DashboardStating,
        navState: NavigationStating,
        userState: SQUserStating = SQAppState.shared.userState,
        metricEntryManager: SQMetricEntryManaging = SQAppState.shared.metricEntryManager,
        metricsManager: SQMetricDefinitionManaging = SQMetricDefinitionManager.shared,
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared,
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        statsManager: SQWorkoutStatsManaging = SQWorkoutStatsManager.shared,
        sleepAggregationService: SQSleepAggregationService = .init(),
        bodyBatteryService: SQBodyBatteryServicing? = nil,
        heartRateService: SQHeartRateServicing? = nil,
        workoutScoreService: SQWorkoutScoreServicing? = nil,
        insightsService: SQInsightsServicing? = nil,
        lifeScoreBuilder: SQLifeScoreBuilding? = nil,
        dashboardLayoutService: SQDashboardLayoutServicing? = nil,
        remoteConfigManager: SQRemoteConfigManaging = SQRemoteConfigManager.shared
    ) {
        let resolvedHeartRateService = heartRateService ?? SQHeartRateService(
            healthKitManager: healthKitManager,
            userState: userState
        )
        let resolvedLifeScoreBuilder = lifeScoreBuilder ?? SQLifeScoreBuilder(
            sleepAggregationService: sleepAggregationService
        )

        self.state = state
        self.navState = navState
        self.userState = userState
        self.metricEntryManager = metricEntryManager
        self.metricsManager = metricsManager
        self.workoutManager = workoutManager
        self.healthKitManager = healthKitManager
        self.statsManager = statsManager
        self.sleepAggregationService = sleepAggregationService
        self.bodyBatteryService = bodyBatteryService ?? SQBodyBatteryService(
            metricEntryManager: metricEntryManager,
            sleepAggregationService: sleepAggregationService,
            healthKitManager: healthKitManager
        )
        self.heartRateService = resolvedHeartRateService
        self.workoutScoreService = workoutScoreService ?? SQWorkoutScoreService(
            heartRateService: resolvedHeartRateService
        )
        self.insightsService = insightsService ?? SQInsightsService()
        self.lifeScoreBuilder = resolvedLifeScoreBuilder
        self.dashboardLayoutService = dashboardLayoutService ?? SQDashboardLayoutService()
        self.remoteConfigManager = remoteConfigManager
        self.emailVerificationController = .init(
            hub: state.hub,
            userState: userState
        )
        self.emailVerificationRequirement = userState.emailVerificationRequirement
        
        let items = AppTimeRange.allCases
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }
        self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: state.selectedTimeRange.rawValue),
            items: items
        ) { [weak state] selectedTitle in
            guard let state else { return }
            if let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }),
               selectedRange != state.selectedTimeRange {
                SQAnalyticsManager.shared.track(.dashboardTimeRangeChanged(timeRange: selectedRange))
                state.selectedTimeRange = selectedRange
            }
        }

        if !userState.hasResolvedInitialAuthState {
            let mockGroups = SQDashboardSectionGroupViewModel.mock(for: state.selectedTimeRange)
            let mockGridGroups = Self.buildDashboardGridLayoutGroups()
            state.updateUncustomizedSectionGroups(mockGroups)
            availableLayoutGroups = self.dashboardLayoutService.descriptors(from: mockGridGroups)
            state.updateAvailableLayoutGroups(availableLayoutGroups)
            state.updateSectionGroups(to: self.dashboardLayoutService.apply(to: mockGridGroups))
            state.setLoading(true)
            state.updateLoadingProgress(0.05)
        }

        refreshRuntimeControlCtaViewModel()
        _ = remoteConfigManager.addSnapshotObserver { [weak self] _ in
            self?.refreshRuntimeControlCtaViewModel()
        }
        
        self.handleEventSubscriptions(hub: state.hub)
    }

    var authButtonSymbol: SQImageSymbol {
        userState.isLoggedIn ? .personCircleFill : .personCircle
    }

    func handleAuthButtonTap() {
        let controller = SQProfileController(userState: userState)
        state.hub.domainEvents.send(.pushDashboardRoute(.profile(controller: controller)))
    }

    func handleLayoutButtonTap() {
        let controller = SQDashboardLayoutController(
            availableGroups: availableLayoutGroups,
            layoutService: dashboardLayoutService
        ) { [weak self] in
            self?.applyLayoutCustomizationToCurrentState()
        }

        state.hub.domainEvents.send(.pushDashboardRoute(.dashboardLayout(controller: controller)))
    }

    func displayDashboardDetail(title: String, sectionIds: [String]) {
        let sections = state.uncustomizedSectionGroups
            .flatMap(\.sections)
            .filter { sectionIds.contains($0.id) }
            .map { section -> SQDashboardSubsectionViewModel in
                let clone = section.cloned()
                clone.isCollapsed = false
                return clone
            }

        guard !sections.isEmpty else { return }

        state.hub.domainEvents.send(
            .pushDashboardRoute(
                .dashboardDetail(
                    controller: .init(title: title, sections: sections)
                )
            )
        )
    }

    func displayWorkoutDetail(_ workout: SQWorkoutSessionable) {
        state.hub.domainEvents.send(
            .pushDashboardRoute(.workoutSummary(controller: .init(workout: workout, mode: .standard)))
        )
    }

    func displayWorkoutsList() {
        let workouts = lastLoadedAllTimeWorkouts.isEmpty
            ? dashboardWorkoutsFromCurrentSections()
            : lastLoadedAllTimeWorkouts
        state.hub.domainEvents.send(
            .pushDashboardRoute(
                .workoutsList(
                    workouts: workouts,
                    initialTimeRange: state.selectedTimeRange
                )
            )
        )
    }

    private func dashboardWorkoutsFromCurrentSections() -> [SQWorkoutSessionable] {
        state.uncustomizedSectionGroups
            .flatMap(\.sections)
            .first(where: { $0.id == "activities" })?
            .activeRows
            .compactMap { $0 as? SQDashboardActivityRowViewModel }
            .flatMap { activityRow in
                activityRow.workoutGroupViewModels.flatMap { $0.workouts.workouts }
            } ?? []
    }

    func displayPerformanceRow(_ row: SQDashboardMetricPerformanceRowViewModel) {
        if row.isPremiumLocked {
            SQSubscriptionManager.displaySubscriptionScreen(
                source: "dashboard_grid_performance_row",
                feature: row.scoreKind?.rawValue ?? row.title.analyticsKey
            )
            return
        }

        guard let leaderboardMode = row.leaderboardMode else { return }
        state.displayLeaderboard(mode: leaderboardMode)
    }

    func handleSeeMoreInsightsTap() {
        guard state.selectedTimeRange == .today else { return }
        timeRangeMenuViewModel.defaultItem = .init(title: AppTimeRange.pastSevenDays.rawValue)
    }

    private func updateTimeRangeMenuBadges(selectedTimeRange: AppTimeRange) {
        let items = AppTimeRange.allCases
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { timeRange in
                let hasUnseenNewInsights = timeRange.newInsightSurfaceIntent.map {
                    insightsService.hasUnseenNewInsights(surfaceIntent: $0)
                } ?? false

                return SQDropDownMenuViewModel.Item(
                    title: timeRange.rawValue,
                    badgeText: hasUnseenNewInsights && timeRange != selectedTimeRange ? "New" : nil
                )
            }

        let hasHiddenFreshness = AppTimeRange.allCases.contains { timeRange in
            guard timeRange != selectedTimeRange,
                  let surfaceIntent = timeRange.newInsightSurfaceIntent else {
                return false
            }

            return insightsService.hasUnseenNewInsights(surfaceIntent: surfaceIntent)
        }

        timeRangeMenuViewModel.updateItems(
            items,
            defaultItem: items.first(where: { $0.title == selectedTimeRange.rawValue }) ?? .init(title: selectedTimeRange.rawValue),
            showsIndicatorDotOnMainButton: hasHiddenFreshness
        )
    }

    func handleViewLabTrigger() {
        guard SQAdminConfig.viewLabEnabled else { return }
        state.hub.domainEvents.send(.pushDashboardRoute(.viewLab(controller: .init())))
    }

    private static func buildDashboardGridLayoutGroups() -> [SQDashboardSectionGroupViewModel] {
        let cards: [(id: String, title: String, priority: Int)] = [
            (DashboardGridCardID.sleep, "Sleep", 10),
            (DashboardGridCardID.sleepPhases, "Sleep Phases", 20),
            (DashboardGridCardID.topInsight, "Top Insight", 30),
            (DashboardGridCardID.keyMetrics, "Key Metrics", 40),
            (DashboardGridCardID.latestWorkout, "Latest Workout", 50),
            (DashboardGridCardID.activityCalories, "Activity & Calories", 60),
            (DashboardGridCardID.vo2Max, "VO₂ Max", 70),
            (DashboardGridCardID.heartOverview, "Heart Overview", 80)
        ]

        return [
            SQDashboardSectionGroupViewModel(
                id: DashboardGridCardID.group,
                title: "Dashboard Cards",
                defaultPriority: 10,
                sections: cards.map {
                    SQDashboardSubsectionViewModel(
                        id: $0.id,
                        title: $0.title,
                        defaultPriority: $0.priority,
                        rowsByFilter: ["All": []]
                    )
                }
            )
        ]
    }
    
    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated, .workoutsDeleted:
                self.refreshFromGlobalContext()
            case .activeWorkoutUpdate:
                break
            }
        }.store(in: &cancellables)

        hub.metricEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .metricEntriesUpdated, .lifeScoreInputsUpdated:
                self.refreshFromGlobalContext()
            case .metricsUpdated:
                break
            }
        }.store(in: &cancellables)

        hub.userEvents.sink { [weak self] event in
            guard let self else { return }
            self.refreshEmailVerificationRequirement()
            switch event {
            case .loginStateChanged:
                self.refreshRuntimeControlCtaViewModel()
                if let modelContext = SQAppState.shared.modelContext {
                    Task {
                        await self.loadUI(
                            for: modelContext,
                            shouldForceRefresh: true,
                            showLoadingState: true
                        )
                    }
                }
            case .emailVerificationStateChanged:
                break
            case .profileUpdated:
                self.refreshRuntimeControlCtaViewModel()
                guard !self.isLoadUIInProgress else {
                    SQLogger.shared.log(
                        "Profile update received during dashboard load. Skipping duplicate dashboard refresh.",
                        .debug,
                        context: .dashboard
                    )
                    return
                }

                if let modelContext = SQAppState.shared.modelContext {
                    Task {
                        await self.loadUI(
                            for: modelContext,
                            shouldForceRefresh: true,
                            showLoadingState: true
                        )
                    }
                }
            }
        }.store(in: &cancellables)

        // Watch for time range changes and reload dashboard
        state.selectedTimeRangePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                SQLogger.shared.log("Time range changed, reloading dashboard", .debug, context: .dashboard)
                guard let modelContext = SQAppState.shared.modelContext else { return }
                Task {
                    await self.loadUI(
                        for: modelContext,
                        shouldForceRefresh: true,
                        showLoadingState: true
                    )
                }
            }
            .store(in: &cancellables)
    }

    private func refreshFromGlobalContext() {
        refreshEmailVerificationRequirement()
        refreshRuntimeControlCtaViewModel()
        guard let modelContext = SQAppState.shared.modelContext else { return }
        Task { await self.refreshUI(for: modelContext) }
    }

    private func refreshEmailVerificationRequirement() {
        emailVerificationRequirement = userState.emailVerificationRequirement
    }

    var shouldAutoRefreshOnForeground: Bool {
        guard hasLoadedUI else { return true }
        guard !isLoadUIInProgress else { return false }
        guard let lastSuccessfulLoadAt else { return true }
        return Date().timeIntervalSince(lastSuccessfulLoadAt) >= Self.automaticForegroundRefreshMinimumInterval
    }

    func refreshUIIfNeededOnForeground(for context: ModelContext) async {
        guard shouldAutoRefreshOnForeground else {
            SQLogger.shared.log(
                "Skipping automatic foreground dashboard refresh because the last successful load is still fresh.",
                .debug,
                context: .dashboard
            )
            return
        }

        await loadUI(
            for: context,
            shouldForceRefresh: true,
            showLoadingState: false,
            suppressErrorAlert: true
        )
    }

    private func applyLayoutCustomizationToCurrentState() {
        state.updateSectionGroups(to: dashboardLayoutService.apply(to: Self.buildDashboardGridLayoutGroups()))
    }

    private func refreshRuntimeControlCtaViewModel() {
        let snapshot = remoteConfigManager.snapshot
        guard userState.isLoggedIn, snapshot.writesDisabled else {
            runtimeControlCtaViewModel = nil
            return
        }

        runtimeControlCtaViewModel = .init(
            icon: .init(symbol: .exclamationmarkTriangleFill),
            priority: .high,
            badgeTitle: "Read-Only Mode",
            title: "Saving is temporarily unavailable",
            subtitle: snapshot.writesDisabledMessage,
            actionText: nil,
            onTap: nil,
            showsChevron: false
        )
    }
    
    func loadUI(
        for context: ModelContext,
        shouldForceRefresh: Bool = false,
        showLoadingState: Bool = true,
        suppressErrorAlert: Bool = false
    ) async {
        guard userState.hasResolvedInitialAuthState else {
            SQLogger.shared.log(
                "Skipping dashboard load until initial auth state resolves.",
                .debug,
                context: .dashboard
            )
            return
        }

        if shouldPresentLaunchTutorial {
            presentLaunchTutorialIfNeeded(context: context)
            return
        }

        guard !hasLoadedUI || shouldForceRefresh else { return }
        guard !isLoadUIInProgress else {
            if shouldForceRefresh {
                pendingForcedRefresh = true
                pendingRefreshShowsLoadingState = pendingRefreshShowsLoadingState || showLoadingState
                pendingRefreshSuppressesErrorAlert = pendingRefreshSuppressesErrorAlert || suppressErrorAlert
                SQLogger.shared.log(
                    "Dashboard load in progress. Queuing a forced refresh for after completion.",
                    .debug,
                    context: .dashboard
                )
            }
            SQLogger.shared.log(
                "Dashboard load already in progress. Skipping duplicate request.",
                .debug,
                context: .dashboard
            )
            return
        }

        isLoadUIInProgress = true
        defer {
            isLoadUIInProgress = false
            if pendingForcedRefresh {
                pendingForcedRefresh = false
                let queuedRefreshShowsLoadingState = pendingRefreshShowsLoadingState
                let queuedRefreshSuppressesErrorAlert = pendingRefreshSuppressesErrorAlert
                pendingRefreshShowsLoadingState = false
                pendingRefreshSuppressesErrorAlert = false
                Task { @MainActor in
                    await self.loadUI(
                        for: context,
                        shouldForceRefresh: true,
                        showLoadingState: queuedRefreshShowsLoadingState,
                        suppressErrorAlert: queuedRefreshSuppressesErrorAlert
                    )
                }
            }
        }

        hasLoadedUI = true

        if shouldForceRefresh {
            healthKitManager.invalidateCache()
        }

        if showLoadingState {
            // Show mock skeleton while real data loads.
            let mockGroups = SQDashboardSectionGroupViewModel.mock(for: state.selectedTimeRange)
            state.updateUncustomizedSectionGroups(mockGroups)
            availableLayoutGroups = dashboardLayoutService.descriptors(from: mockGroups)
            state.updateAvailableLayoutGroups(availableLayoutGroups)
            state.updateSectionGroups(to: dashboardLayoutService.apply(to: mockGroups))
            state.setLoading(true)
            state.updateLoadingProgress(0.05)
        }

        do {
            try metricsManager.loadIfNeeded(using: context)
            state.updateLoadingProgress(0.12)

            if userState.isLoggedIn {
                _ = try await SQMetricDefinitionManager.shared.syncMetricsIfNeeded(using: context)
            }
            state.updateLoadingProgress(0.18)

            let useDashboardDemoData = shouldUseDashboardDemoData
            let sleepAccessStatus: SQHealthKitDashboardAccessStatus
            let heartAccessStatus: SQHealthKitDashboardAccessStatus
            let workoutsAccessStatus: SQHealthKitDashboardAccessStatus
            if useDashboardDemoData {
                sleepAccessStatus = .available
                heartAccessStatus = .available
                workoutsAccessStatus = .available
            } else {
                async let sleepAccessStatusTask = healthKitManager.dashboardAccessStatus(for: .sleep)
                async let heartAccessStatusTask = healthKitManager.dashboardAccessStatus(for: .heart)
                async let workoutsAccessStatusTask = healthKitManager.dashboardAccessStatus(for: .workouts)
                sleepAccessStatus = await sleepAccessStatusTask
                heartAccessStatus = await heartAccessStatusTask
                workoutsAccessStatus = await workoutsAccessStatusTask
            }
            state.updateLoadingProgress(0.26)

            let restingHeartRatePast30Days: [SQHeartRateDailySummary]
            let restingHeartRatePastYear: [SQHeartRateDailySummary]
            let vo2MaxPast7Days: [SQVO2MaxSample]
            let vo2MaxPast30Days: [SQVO2MaxSample]
            let vo2MaxPastYear: [SQVO2MaxSample]
            let vo2MaxAllTime: [SQVO2MaxSample]

            if useDashboardDemoData {
                restingHeartRatePast30Days = SQHealthKitManager.shared.mockHealthData.dailyRestingHeartRateSummaries(for: .past30Days)
                restingHeartRatePastYear = SQHealthKitManager.shared.mockHealthData.dailyRestingHeartRateSummaries(for: .pastYear)
                vo2MaxPast7Days = SQHealthKitManager.shared.mockHealthData.vo2MaxSamples(for: .pastWeek)
                vo2MaxPast30Days = SQHealthKitManager.shared.mockHealthData.vo2MaxSamples(for: .past30Days)
                vo2MaxPastYear = SQHealthKitManager.shared.mockHealthData.vo2MaxSamples(for: .pastYear)
                vo2MaxAllTime = SQHealthKitManager.shared.mockHealthData.vo2MaxSamples(for: .allTime)
            } else {
                async let restingHeartRatePast30DaysTask = healthKitManager.fetchDailyRestingHeartRateSummaries(.past30Days)
                async let restingHeartRatePastYearTask = healthKitManager.fetchDailyRestingHeartRateSummaries(.pastYear)

                vo2MaxPast7Days = try await healthKitManager.fetchVO2MaxSamples(.pastWeek)
                vo2MaxPast30Days = try await healthKitManager.fetchVO2MaxSamples(.past30Days)
                vo2MaxPastYear = try await healthKitManager.fetchVO2MaxSamples(.pastYear)
                vo2MaxAllTime = try await healthKitManager.fetchVO2MaxSamples(.allTime)
                restingHeartRatePast30Days = (try? await restingHeartRatePast30DaysTask) ?? []
                restingHeartRatePastYear = (try? await restingHeartRatePastYearTask) ?? []
            }
            state.updateLoadingProgress(0.34)

            let todaysWorkouts = try await workoutManager.getWorkouts(for: .today, modelContext: context)
            
            SQLogger.shared.log("Reloading today's workouts", .debug, context: .dashboard)
            for workout in todaysWorkouts {
                SQLogger.shared.log("Workout: \(workout.prettyDescription)", .debug, context: .dashboard)
            }
            
            let yesterdaysWorkouts = try await workoutManager.getWorkouts(for: .yesterday, modelContext: context)
            
            let lastWeekWorkouts = try await workoutManager.getWorkouts(for: .pastWeek, modelContext: context)
            let weekBeforeLastWorkouts = try await workoutManager.getWorkouts(for: .weekBeforeLast, modelContext: context)
            
            let past30DaysWorkouts = try await workoutManager.getWorkouts(for: .past30Days, modelContext: context)
            let thirtyDaysBeforeLastWorkouts = try await workoutManager.getWorkouts(for: .thirtyDaysBeforeLast, modelContext: context)

            let lastYearWorkouts = try await workoutManager.getWorkouts(for: .pastYear, modelContext: context)
            let yearBeforeLastWorkouts = try await workoutManager.getWorkouts(for: .yearBeforeLast, modelContext: context)
            let allTimeWorkouts = try await workoutManager.getWorkouts(for: .allTime, modelContext: context)
            state.updateLoadingProgress(0.48)

            let dashboardReferenceDate = Date()
            let sleepSchedule = userState.loggedInUser?.sleepSchedule
            let currentCheckInPromptContext = DashboardState.currentCheckInPromptContext(
                for: dashboardReferenceDate,
                sleepSchedule: sleepSchedule
            )
            let currentCheckInDate = currentCheckInPromptContext?.date ?? DashboardState.currentCheckInDate(
                for: dashboardReferenceDate,
                sleepSchedule: sleepSchedule
            )
            let currentCheckInPromptPeriod = currentCheckInPromptContext?.period
            let yesterdayReferenceDate = Calendar.current.date(byAdding: .day, value: -1, to: dashboardReferenceDate) ?? dashboardReferenceDate
            let yesterdayCheckInPromptContext = DashboardState.currentCheckInPromptContext(
                for: yesterdayReferenceDate,
                sleepSchedule: sleepSchedule
            )
            let yesterdayCheckInDate = yesterdayCheckInPromptContext?.date ?? DashboardState.currentCheckInDate(
                for: yesterdayReferenceDate,
                sleepSchedule: sleepSchedule
            )
            let yesterdayCheckInPromptPeriod = yesterdayCheckInPromptContext?.period
            let hasCompletedCurrentCheckIn: Bool
            if let currentCheckInPromptPeriod {
                hasCompletedCurrentCheckIn = (try? await metricEntryManager.hasCompletedCheckIn(
                    for: currentCheckInDate,
                    period: currentCheckInPromptPeriod,
                    context: context
                )) ?? false
            } else {
                hasCompletedCurrentCheckIn = true
            }
            let hasCompletedYesterdayCheckIn: Bool
            if let yesterdayCheckInPromptPeriod {
                hasCompletedYesterdayCheckIn = (try? await metricEntryManager.hasCompletedCheckIn(
                    for: yesterdayCheckInDate,
                    period: yesterdayCheckInPromptPeriod,
                    context: context
                )) ?? false
            } else {
                hasCompletedYesterdayCheckIn = true
            }

            // Fetch historical check-ins for different time ranges using SQTimeRange dates
            let todaysCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.today.startDate,
                to: SQTimeRange.today.endDate,
                context: context
            )
            let todaysMorningSleepCheckIn = try await metricEntryManager.getDailyCheckInStats(
                for: currentCheckInDate,
                period: .morning,
                context: context
            )
            let yesterdaysMorningSleepCheckIn = try await metricEntryManager.getDailyCheckInStats(
                for: yesterdayCheckInDate,
                period: .morning,
                context: context
            )

            let past7DaysCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.pastWeek.startDate,
                to: SQTimeRange.pastWeek.endDate,
                context: context
            )

            let past30DaysCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.past30Days.startDate,
                to: SQTimeRange.past30Days.endDate,
                context: context
            )

            let pastYearCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.pastYear.startDate,
                to: SQTimeRange.pastYear.endDate,
                context: context
            )

            let allTimeCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.allTime.startDate,
                to: SQTimeRange.allTime.endDate,
                context: context
            )

            let weekBeforeLastCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.weekBeforeLast.startDate,
                to: SQTimeRange.weekBeforeLast.endDate,
                context: context
            )

            let thirtyDaysBeforeLastCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.thirtyDaysBeforeLast.startDate,
                to: SQTimeRange.thirtyDaysBeforeLast.endDate,
                context: context
            )

            let yearBeforeLastCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.yearBeforeLast.startDate,
                to: SQTimeRange.yearBeforeLast.endDate,
                context: context
            )
            let useMockDashboardData = useDashboardDemoData
            let effectiveHasCompletedCurrentCheckIn = useMockDashboardData ? true : hasCompletedCurrentCheckIn
            let effectiveTodaysMorningSleepCheckIn = useMockDashboardData
                ? SQHealthKitManager.shared.mockHealthData.dailyCheckIn(on: currentCheckInDate, period: .morning)
                : todaysMorningSleepCheckIn
            let effectiveYesterdaysMorningSleepCheckIn = useMockDashboardData
                ? SQHealthKitManager.shared.mockHealthData.dailyCheckIn(on: yesterdayCheckInDate, period: .morning)
                : yesterdaysMorningSleepCheckIn

            func dashboardCheckIns(_ realCheckIns: [SQDailyCheckInStats], for timeRange: SQTimeRange) -> [SQDailyCheckInStats] {
                useMockDashboardData
                    ? SQHealthKitManager.shared.mockHealthData.dailyCheckIns(for: timeRange)
                    : realCheckIns
            }

            state.updateLoadingProgress(0.62)

            // Set the daily check-in CTA view model if no stats exist
            if
                let currentCheckInPromptPeriod,
                !effectiveHasCompletedCurrentCheckIn,
                userState.isLoggedIn
            {
                state.updateDailyCheckInCtaViewModel(.dailyCheckInPrompt(
                    periodTitle: title(for: currentCheckInPromptPeriod),
                    onTap: {
                        Task { await self.displayDailyCheckInSheet(for: context) }
                    }
                ))
            } else if !userState.isLoggedIn {
                let preferredMode: SQLoginMode = remoteConfigManager.snapshot.signupDisabled ? .login : .signup
                state.updateDailyCheckInCtaViewModel(.guestDailyCheckInPrompt(
                    signupEnabled: !remoteConfigManager.snapshot.signupDisabled,
                    onTap: {
                        let controller = SQLoginController(
                            mode: preferredMode,
                            hub: self.state.hub,
                            remoteConfigManager: self.remoteConfigManager
                        )
                        self.state.hub.domainEvents.send(.pushDashboardRoute(.login(controller: controller)))
                    }
                ))
            } else {
                state.updateDailyCheckInCtaViewModel(nil)
            }

            // Build section groups for new dashboard architecture
            let currentWorkouts: [SQWorkoutSessionable]
            let priorWorkouts: [SQWorkoutSessionable]
            let priorTimeRange: SQTimeRange
            let currentCheckIns: [SQDailyCheckInStats]
            let priorCheckIns: [SQDailyCheckInStats]
            let currentVO2MaxSamples: [SQVO2MaxSample]

            switch state.selectedTimeRange {
            case .today:
                currentWorkouts = todaysWorkouts
                priorTimeRange = .yesterday
                priorWorkouts = yesterdaysWorkouts
                currentCheckIns = dashboardCheckIns(todaysCheckIns, for: .today)
                priorCheckIns = dashboardCheckIns(past7DaysCheckIns, for: .pastWeek)
                currentVO2MaxSamples = vo2MaxPast7Days
            case .pastSevenDays:
                currentWorkouts = lastWeekWorkouts
                priorWorkouts = weekBeforeLastWorkouts
                priorTimeRange = .weekBeforeLast
                currentCheckIns = dashboardCheckIns(past7DaysCheckIns, for: .pastWeek)
                priorCheckIns = dashboardCheckIns(weekBeforeLastCheckIns, for: .weekBeforeLast)
                currentVO2MaxSamples = vo2MaxPast7Days
            case .past30Days:
                currentWorkouts = past30DaysWorkouts
                priorWorkouts = thirtyDaysBeforeLastWorkouts
                priorTimeRange = .thirtyDaysBeforeLast
                currentCheckIns = dashboardCheckIns(past30DaysCheckIns, for: .past30Days)
                priorCheckIns = dashboardCheckIns(thirtyDaysBeforeLastCheckIns, for: .thirtyDaysBeforeLast)
                currentVO2MaxSamples = vo2MaxPast30Days
            case .pastYear:
                currentWorkouts = lastYearWorkouts
                priorWorkouts = yearBeforeLastWorkouts
                priorTimeRange = .yearBeforeLast
                currentCheckIns = dashboardCheckIns(pastYearCheckIns, for: .pastYear)
                priorCheckIns = dashboardCheckIns(yearBeforeLastCheckIns, for: .yearBeforeLast)
                currentVO2MaxSamples = vo2MaxPastYear
            case .allTime:
                currentWorkouts = allTimeWorkouts
                priorWorkouts = []  // No comparison for all time
                priorTimeRange = .allTime  // No prior period for all time
                currentCheckIns = dashboardCheckIns(allTimeCheckIns, for: .allTime)
                priorCheckIns = []
                currentVO2MaxSamples = vo2MaxAllTime
            }

            let sleepDashboardData = try await buildSleepDashboardData(for: state.selectedTimeRange)
            let insightExplorerSleepDashboardData = state.selectedTimeRange == .pastYear
                ? sleepDashboardData
                : (try? await buildSleepDashboardData(for: .pastYear)) ?? sleepDashboardData
            state.updateLoadingProgress(0.74)

            healthKitAccessCtaViewModel = await buildHealthKitAccessCtaViewModel(
                for: context,
                hasAnyHealthKitSignal: !allTimeWorkouts.isEmpty
                    || !vo2MaxAllTime.isEmpty
                    || !restingHeartRatePast30Days.isEmpty
                    || sleepDashboardData?.latestNight != nil
                    || sleepDashboardData?.averageScore != nil
            )

            let referenceDate = dashboardReferenceDate
            let metricDefinitions = SQSubscriptionManager.availableMetricDefinitions(
                metricsManager.allMetrics(includeArchived: true)
            )

            func buildHealthIntelligenceInput(for timeRange: AppTimeRange) -> SQHealthIntelligenceInput {
                let scopedCheckIns: [SQDailyCheckInStats]
                let scopedWorkouts: [any SQWorkoutSessionable]
                let scopedRestingHeartRateSummaries: [SQHeartRateDailySummary]

                switch timeRange {
                case .today, .pastSevenDays, .past30Days:
                    scopedCheckIns = dashboardCheckIns(past30DaysCheckIns, for: .past30Days)
                    scopedWorkouts = past30DaysWorkouts
                    scopedRestingHeartRateSummaries = restingHeartRatePast30Days
                case .pastYear, .allTime:
                    scopedCheckIns = dashboardCheckIns(pastYearCheckIns, for: .pastYear)
                    scopedWorkouts = lastYearWorkouts
                    scopedRestingHeartRateSummaries = restingHeartRatePastYear
                }

                let scopedSleepData = timeRange == .pastYear || timeRange == .allTime
                    ? insightExplorerSleepDashboardData
                    : sleepDashboardData

                return .init(
                    referenceDate: referenceDate,
                    timeRange: timeRange,
                    metricDefinitions: metricDefinitions,
                    checkIns: scopedCheckIns,
                    sleepCheckIns: [effectiveTodaysMorningSleepCheckIn, effectiveYesterdaysMorningSleepCheckIn].compactMap { $0 },
                    workouts: scopedWorkouts,
                    sleepData: scopedSleepData,
                    restingHeartRateSummaries: scopedRestingHeartRateSummaries,
                    currentCheckInPromptPeriod: timeRange == .today ? currentCheckInPromptPeriod : nil,
                    hasCompletedCurrentPromptCheckIn: timeRange == .today ? effectiveHasCompletedCurrentCheckIn : false,
                    isLoggedIn: userState.isLoggedIn
                )
            }

            var healthIntelligenceInput = buildHealthIntelligenceInput(for: state.selectedTimeRange)
            state.updateLoadingProgress(0.82)

            var insightsResult = buildDashboardInsightsResult(
                input: healthIntelligenceInput
            )
            lifeScoreViewModel = lifeScoreBuilder.buildViewModel(
                input: .init(
                    intelligenceInput: healthIntelligenceInput,
                    insightsResult: insightsResult
                )
            )

            if state.selectedTimeRange.insightSurfaceIntent == .today,
               let currentLifeScoreViewModel = lifeScoreViewModel {
                healthIntelligenceInput = healthIntelligenceInput.withScoreContext(
                    scoreContext(from: currentLifeScoreViewModel)
                )
                insightsResult = buildDashboardInsightsResult(
                    input: healthIntelligenceInput
                )
                lifeScoreViewModel = lifeScoreBuilder.buildViewModel(
                    input: .init(
                        intelligenceInput: healthIntelligenceInput,
                        insightsResult: insightsResult
                    )
                )
            }

            for timeRange in [AppTimeRange.pastSevenDays, .pastYear] where timeRange != state.selectedTimeRange {
                _ = buildDashboardInsightsResult(
                    input: buildHealthIntelligenceInput(for: timeRange)
                )
            }

            if state.selectedTimeRange.insightSurfaceIntent != .today {
                insightsService.markVisibleInsightsSeenIfNeeded(
                    insightsResult.insights,
                    referenceDate: referenceDate,
                    surfaceIntent: state.selectedTimeRange.insightSurfaceIntent
                )
            }

            updateTimeRangeMenuBadges(selectedTimeRange: state.selectedTimeRange)
            state.updateLoadingProgress(0.90)

            let sectionGroups = try await buildSectionGroups(
                checkIns: currentCheckIns,
                priorCheckIns: priorCheckIns,
                insightsResult: insightsResult,
                insightExplorerInput: buildHealthIntelligenceInput(for: .pastYear),
                vo2MaxSamples: currentVO2MaxSamples,
                vo2MaxAllTime: vo2MaxAllTime,
                todaysWorkouts: todaysWorkouts,
                yesterdaysWorkouts: yesterdaysWorkouts,
                workouts: currentWorkouts,
                priorWorkouts: priorWorkouts,
                allTimeWorkouts: allTimeWorkouts,
                sleepData: sleepDashboardData,
                sleepAccessStatus: sleepAccessStatus,
                heartAccessStatus: heartAccessStatus,
                workoutsAccessStatus: workoutsAccessStatus,
                includeHeartRateData: true,
                timeRange: state.selectedTimeRange.sqTimeRange,
                priorTimeRange: priorTimeRange,
                context: context
            )
            let gridLayoutGroups = Self.buildDashboardGridLayoutGroups()
            let appliedSectionGroups = dashboardLayoutService.apply(to: gridLayoutGroups)
            let updatedAvailableLayoutGroups = dashboardLayoutService.descriptors(from: gridLayoutGroups)

            state.updateUncustomizedSectionGroups(sectionGroups)
            availableLayoutGroups = updatedAvailableLayoutGroups
            state.updateAvailableLayoutGroups(availableLayoutGroups)
            state.updateSectionGroups(to: appliedSectionGroups)
            lastLoadedUncustomizedSectionGroups = sectionGroups
            lastLoadedSectionGroups = appliedSectionGroups
            lastLoadedAvailableLayoutGroups = updatedAvailableLayoutGroups
            lastLoadedDailyCheckInCtaViewModel = state.dailyCheckInCtaViewModel
            lastLoadedHealthKitAccessCtaViewModel = healthKitAccessCtaViewModel
            lastLoadedLifeScoreViewModel = lifeScoreViewModel
            lastLoadedAllTimeWorkouts = allTimeWorkouts
            lastSuccessfulLoadAt = .now

            if showLoadingState {
                state.updateLoadingProgress(1)
                state.setLoading(false)
            }

            presentHighestPriorityDashboardRouteIfNeeded(
                workouts: past30DaysWorkouts,
                context: context
            )
        } catch {
            SQLogger.shared.log("Error loading dashboard", .error, context: .dashboard)

            /// Restore the last loaded data, to ensure that we're never showing mock data whenever we get errors fetching healthKit data
            state.updateDailyCheckInCtaViewModel(lastLoadedDailyCheckInCtaViewModel)
            state.updateUncustomizedSectionGroups(lastLoadedUncustomizedSectionGroups)
            availableLayoutGroups = lastLoadedAvailableLayoutGroups
            state.updateAvailableLayoutGroups(lastLoadedAvailableLayoutGroups)
            state.updateSectionGroups(to: lastLoadedSectionGroups)
            lifeScoreViewModel = lastLoadedLifeScoreViewModel
            healthKitAccessCtaViewModel = lastLoadedHealthKitAccessCtaViewModel

            if showLoadingState {
                state.setLoading(false)
            }

            if suppressErrorAlert {
                SQLogger.shared.log(
                    "Automatic foreground dashboard refresh failed. Preserving last successful dashboard state without showing an alert.",
                    .debug,
                    context: .dashboard
                )
            } else {
                presentDashboardLoadError(error, context: context)
            }
        }
    }
    
    func refreshUI(for context: ModelContext) async {
        SQLogger.shared.log("Refreshing dashboard", .debug, context: .dashboard)
        await loadUI(
            for: context,
            shouldForceRefresh: true,
            showLoadingState: false
        )
    }
    
    func displayDailyCheckInSheet(for context: ModelContext, date: Date? = nil) async {
        guard userState.isLoggedIn else {
            handleAuthButtonTap()
            return
        }

        let sleepSchedule = userState.loggedInUser?.sleepSchedule
        let referenceDate = date ?? .now
        let promptContext = date == nil
            ? DashboardState.currentCheckInPromptContext(
                for: referenceDate,
                sleepSchedule: sleepSchedule
            )
            : nil
        let targetDate = date ?? promptContext?.date ?? DashboardState.currentCheckInDate(
            for: referenceDate,
            sleepSchedule: sleepSchedule
        )
        let checkInPeriod: SQMetricPeriod = {
            if let promptContext {
                return promptContext.period
            }

            return DashboardState.checkInPeriod(
                for: referenceDate,
                sleepSchedule: sleepSchedule
            )
        }()

        let dailyCheckInStats: SQDailyCheckInStats?
        do {
            dailyCheckInStats = try await metricEntryManager.getDailyCheckInStats(
                for: targetDate,
                period: checkInPeriod,
                context: context
            )
        } catch {
            SQLogger.shared.log(
                "Failed to load daily check-in data: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn
            )
            state.hub.alertEvents.send(
                .present(.init(SQError.standard(withDescription: "Error loading check-in data: \(error.localizedDescription)")))
            )
            return
        }

        state.displayDailyCheckInSheet(
            with: dailyCheckInStats,
            for: targetDate,
            period: checkInPeriod
        )
    }

    // MARK: - New Workout Review Processing

    private func presentDashboardLoadError(_ error: Error, context: ModelContext) {
        let alert = SQAlertViewModel(
            title: "Couldn't load dashboard",
            subtitle: dashboardLoadFailureMessage(for: error),
            primary: .init(title: "Retry") { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.loadUI(
                        for: context,
                        shouldForceRefresh: true,
                        showLoadingState: true
                    )
                }
            },
            secondary: .init(title: "Cancel", role: .cancel),
            canDismiss: true
        )

        state.hub.alertEvents.send(.present(alert))
    }

    private func dashboardLoadFailureMessage(for error: Error) -> String {
        let baseMessage = "Something went wrong while loading your dashboard. Open the Health app, tap your profile picture, then go to Apps > LifeIQ and make sure the data types you want are enabled. After that, come back here and tap Retry."
        let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !detail.isEmpty else { return baseMessage }

        return "\(baseMessage)\n\nError: \(detail)"
    }

    private func buildHealthKitAccessCtaViewModel(
        for context: ModelContext,
        hasAnyHealthKitSignal: Bool
    ) async -> SQCallToActionViewModel? {
        guard !shouldUseDashboardDemoData else { return nil }

        let accessStatus = await healthKitManager.dashboardAccessStatus()
        guard accessStatus == .unavailable, !hasAnyHealthKitSignal else { return nil }

        return .init(
            icon: .init(symbol: .heart),
            priority: .high,
            badgeTitle: "Health Access",
            title: "Connect Health data for full dashboard insights",
            subtitle: "LifeIQ couldn't find Health data yet. Check Health app > Profile > Apps > LifeIQ to confirm access, or make sure your device or apps are recording workouts, sleep, heart, or VO2 max data.",
            actionText: "Tap to retry",
            onTap: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.loadUI(
                        for: context,
                        shouldForceRefresh: true,
                        showLoadingState: true
                    )
                }
            }
        )
    }

    private func presentGuestSleepAccuracyAlert() {
        let alert = SQAlertViewModel(
            title: "Guest Sleep Data",
            subtitle: "Sleep data can still appear in guest mode, but your sleep score, bedtime grouping, and check-in timing may be less accurate until you create an account and save your usual sleep and wake times.",
            primary: .ok,
            secondary: nil,
            canDismiss: true
        )

        state.hub.alertEvents.send(.present(alert))
    }

    private func presentLaunchTutorialIfNeeded(context: ModelContext) {
        guard navState.dashboardRootSheetView == nil else { return }
        guard shouldPresentLaunchTutorial else { return }

        let controller = SQLaunchTutorialController { [weak self] _ in
            guard let self else { return }

            await self.loadUI(
                for: context,
                shouldForceRefresh: true,
                showLoadingState: true
            )
        }
        state.hub.domainEvents.send(.pushDashboardRoute(.launchTutorial(controller: controller)))
    }

    private func presentHighestPriorityDashboardRouteIfNeeded(
        workouts: [SQWorkoutSessionable],
        context: ModelContext
    ) {
        guard navState.dashboardRootSheetView == nil else { return }

        if shouldPresentLaunchTutorial {
            presentLaunchTutorialIfNeeded(context: context)
            return
        }

        if shouldPresentOnboarding {
            let controller = SQOnboardingController()
            state.hub.domainEvents.send(.pushDashboardRoute(.onboarding(controller: controller)))
            return
        }

        processNewWorkoutReviews(workouts: workouts, context: context)
    }

    private var shouldPresentLaunchTutorial: Bool {
        !userState.isLoggedIn &&
        !SQUserDefaults.shared.hasCompletedLaunchTutorial(version: SQLaunchTutorialController.currentVersion)
    }

    private var shouldPresentOnboarding: Bool {
        guard userState.isLoggedIn, let user = userState.loggedInUser else { return false }

        if userState.hasLoadedUserProfile, user.requiresOnboarding {
            return true
        }

        return SQUserDefaults.shared.hasPendingOnboarding(for: user.id)
    }

    private func processNewWorkoutReviews(
        workouts: [SQWorkoutSessionable],
        context: ModelContext
    ) {
        guard userState.isLoggedIn, let user = userState.loggedInUser else {
            SQLogger.shared.log(
                "Skipping new workout review modal in guest mode",
                .debug,
                context: .dashboard
            )
            return
        }

        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let processedIds = workoutManager.fetchProcessedSourceIds(context: context)
        let reviewStartDate = user.createdAt ?? SQUserDefaults.shared.appInstallDate ?? .distantPast

        let reviewableWorkouts = workouts.filter { workout in
            guard let startDate = workout.startDate else { return false }
            let sourceId = workout.workoutSource.sourcableData.sourceId
            return startDate >= fourteenDaysAgo
                && startDate >= reviewStartDate
                && !processedIds.contains(sourceId)
        }

        if !SQUserDefaults.shared.hasWorkoutReviewBaseline(for: user.id) {
            if !reviewableWorkouts.isEmpty {
                workoutManager.markWorkoutsAsProcessed(reviewableWorkouts, context: context)
                SQLogger.shared.log(
                    "Established workout review baseline for user \(user.id) with \(reviewableWorkouts.count) workout(s)",
                    .info,
                    context: .dashboard
                )
            }

            SQUserDefaults.shared.markWorkoutReviewBaselineEstablished(for: user.id)
            return
        }

        guard !reviewableWorkouts.isEmpty else {
            SQLogger.shared.log("Not launching new workout review modal - no workouts to display", .debug, context: .dashboard)
            return
        }

        let sorted = reviewableWorkouts.sorted {
            ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast)
        }

        SQLogger.shared.log(
            "Emitting \(sorted.count) workout(s) ready for review",
            .info,
            context: .dashboard
        )
        
//        var sorted = [SQWorkoutSessionable]()
//        var total = 0
//        for workout in workouts.sorted(by: { $0.startDate ?? Date() > $1.startDate ?? Date() }) {
//            sorted.append(workout)
//            total += 1
//            if total >= 2 { break }
//        }
        if navState.dashboardRootSheetView == nil {
            state.hub.domainEvents.send(.pushDashboardRoute(.workoutReview(workouts: sorted)))
        }
    }

    // MARK: - Metrics Subsection Builder

    private func buildMetricsSubsection(
        checkIns: [SQDailyCheckInStats],
        priorCheckIns: [SQDailyCheckInStats],
        timeRange: AppTimeRange,
        context: ModelContext
    ) -> SQDashboardSubsectionViewModel {

        // If not logged in, return a locked preview subsection
        if !userState.isLoggedIn {
            return buildLockedMetricsSubsection(timeRange: timeRange)
        }

        let stats = checkIns
        let allDefinitions = SQMetricDefinitionManager.shared.dailyCheckInMetrics().sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        if SQAdminConfig.verboseLoggingEnabled {
            SQLogger.shared.log(
                "Building Metrics subsection for \(timeRange.rawValue): current check-ins = \(stats.count), prior check-ins = \(priorCheckIns.count), definitions = \(allDefinitions.count)",
                .debug,
                context: .dashboard
            )
        }

        // Only include groups that actually have data
        let groupsWithData: [String] = {
            var set = Set<String>()
            for def in allDefinitions {
                if stats.contains(where: { $0.values[def.id] != nil }) {
                    set.insert(def.group)
                }
            }
            return set.sorted()
        }()

        // Build dropdown items (ensure "All" is the same instance used for default + list)
        let allItem = SQDropDownMenuViewModel.Item(title: "All")
        let groupItems = groupsWithData.map { SQDropDownMenuViewModel.Item(title: $0) }
        let items = [allItem] + groupItems

        // Build rows
        func rows(for definitions: [SQMetricDefinition]) -> [SQDashboardMetricStatsRowViewModel] {
            definitions.compactMap { buildMetricRow(for: $0, from: stats, priorStats: priorCheckIns) }
        }

        var rowsByFilter: [String: [SQDashboardMetricStatsRowViewModel]] = [:]
        rowsByFilter[allItem.title] = rows(for: allDefinitions)

        for groupName in groupsWithData {
            let defs = allDefinitions.filter { $0.group == groupName }
            rowsByFilter[groupName] = rows(for: defs)
        }

        // Create dropdown + section
        let dropDownViewModel = SQDropDownMenuViewModel(
            defaultItem: allItem,
            items: items,
            itemSelectionHandler: { _ in }
        )

        let metricsEmptyState: SQDashboardSubsectionViewModel.EmptyStateViewModel = {
            let emptyStateTitle: String
            if timeRange == .today {
                if let currentCheckInPromptContext = DashboardState.currentCheckInPromptContext(
                    for: Date(),
                    sleepSchedule: userState.loggedInUser?.sleepSchedule
                ) {
                    emptyStateTitle = "Complete your \(title(for: currentCheckInPromptContext.period)) check-in"
                } else {
                    emptyStateTitle = "Log your next daily check-in"
                }
            } else {
                emptyStateTitle = "Log your next daily check-in"
            }

            return .init(
                title: emptyStateTitle,
                subtitle: "Track your daily metrics to populate this section.",
                icon: .checkmarkCircle,
                onTap: { [weak self] in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.displayDailyCheckInSheet(for: context)
                    }
                }
            )
        }()

        let sectionViewModel = SQDashboardSubsectionViewModel(
            id: "metrics",
            title: "Metrics",
            defaultPriority: 10,
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel,
            titleButton: nil,
            columnHeaders: ["", "Avg Score", timeRange.dashboardChangePctHeader],
            maxVisibleRows: 4,
            emptyState: metricsEmptyState
        )

        // ✅ Pass the title (String) to match rowsByFilter keys
        dropDownViewModel.itemSelectionHandler = { [weak sectionViewModel] selectedItem in
            sectionViewModel?.updateActiveFilter(selectedItem)
        }

        return sectionViewModel
    }

    private func buildLockedMetricsSubsection(timeRange: AppTimeRange) -> SQDashboardSubsectionViewModel {
        let fakeSparkline: [Double] = [5.8, 6.5, 7.2, 6.8, 7.5, 7.2, 6.9]
        let fakeValues: [Double] = [7.2, 6.8, 8.1, 5.9, 7.5, 6.3, 7.8, 8.0, 6.5, 7.1]

        let presets: [(id: String, icon: String, title: String, unit: String)] = [
            ("mood",    "😊", "Mood",    "/10"),
            ("energy",  "⚡️", "Energy",  "/10"),
            ("sleep",   "😴", "Sleep",   "hrs"),
            ("soreness","🦵", "Soreness","/10"),
            ("clarity", "🧠", "Clarity", "/10")
        ]
        let fakeRows = presets.enumerated().map { index, preset in
            SQDashboardMetricStatsRowViewModel(
                metricId: preset.id,
                icon: preset.icon,
                title: preset.title,
                avgValue: String(format: "%.1f", fakeValues[index % fakeValues.count]),
                unit: preset.unit,
                sparklineData: fakeSparkline,
                changePercent: [0.04, -0.02, 0.07, -0.05, 0.03][index % 5],
                quantityType: nil,
                activityType: nil
            )
        }

        let sectionViewModel = SQDashboardSubsectionViewModel(
            id: "metrics",
            title: "Metrics",
            defaultPriority: 10,
            rowsByFilter: ["All": fakeRows],
            dropDownViewModel: nil,
            titleButton: nil,
            columnHeaders: ["", "Avg Score", timeRange.dashboardChangePctHeader],
            maxVisibleRows: 4
        )
        sectionViewModel.isLocked = true
        sectionViewModel.onLockedTap = { [weak self] in
            self?.handleAuthButtonTap()
        }
        return sectionViewModel
    }

    // MARK: - Performance Subsection Builder

    private func buildPerformanceSubsection(
        vo2MaxSamples: [SQVO2MaxSample],
        vo2MaxAllTime: [SQVO2MaxSample],
        workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable]
    ) async -> SQDashboardSubsectionViewModel? {
        var sharedRows = [SQDashboardMetricPerformanceRowViewModel]()
        var activityRowsByFilter = [String: [SQDashboardMetricPerformanceRowViewModel]]()

        // Add VO2 Max row if we have samples
        if !vo2MaxSamples.isEmpty {
            let vo2Values = vo2MaxSamples.map(\.value)
            let averageVO2Max = vo2Values.reduce(0, +) / Double(vo2Values.count)

            let valueString = String(format: "%.1f", averageVO2Max)

            let historicalValues = vo2MaxAllTime.map { $0.value }
            let percentileRank = SQPercentileCalculator.calculatePercentile(
                currentBest: averageVO2Max,
                historicalValues: historicalValues,
                isLowerBetter: false
            )

            let vo2MaxRow = SQDashboardMetricPerformanceRowViewModel(
                metricId: "vo2-max",
                icon: SQImageSymbol.heart.rawValue,
                title: "VO₂ Max",
                bestValue: valueString,
                unit: "mL/kg/min",
                percentileRank: percentileRank,
                leaderboardMode: .vo2Max
            )
            sharedRows.append(vo2MaxRow)
        }
        
        // Build performance rows per activity type using the stats manager
        let uniqueActivityTypes = Array(Set(workouts.map(\.activityType)))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        for activityType in uniqueActivityTypes {
            let activityWorkouts = workouts.filter { $0.activityType == activityType }
            guard !activityWorkouts.isEmpty else { continue }
            var activityRows = [SQDashboardMetricPerformanceRowViewModel]()

            let performanceRows = await statsManager.loadPerformanceRows(
                for: activityType,
                in: activityWorkouts,
                allTimeWorkouts: allTimeWorkouts,
                isPremiumUnlocked: SQSubscriptionManager.hasPremiumAccess
            )
            activityRows.append(contentsOf: performanceRows.map { rowData in
                SQDashboardMetricPerformanceRowViewModel(
                    metricId: rowData.id,
                    icon: rowData.icon,
                    title: rowData.title,
                    bestValue: rowData.bestValue,
                    unit: rowData.unit,
                    percentileRank: rowData.percentileRank,
                    leaderboardMode: rowData.leaderboardMode,
                    isPremiumLocked: rowData.isPremiumLocked,
                    premiumLockText: rowData.premiumLockText,
                    scoreKind: rowData.scoreKind
                )
            })

            guard !activityRows.isEmpty else { continue }
            activityRowsByFilter[activityType.name] = activityRows
        }

        // Skip section if no performance data at all
        let allRows = sharedRows + uniqueActivityTypes.flatMap { activityRowsByFilter[$0.name] ?? [] }
        guard !allRows.isEmpty else { return nil }

        // Build rowsByFilter dictionary with an activity filter like Metrics.
        var rowsByFilter: [String: [SQDashboardMetricPerformanceRowViewModel]] = [
            "All": allRows
        ]
        for (filter, rows) in activityRowsByFilter {
            rowsByFilter[filter] = sharedRows + rows
        }

        let filterItems = [SQDropDownMenuViewModel.Item(title: "All")] + activityRowsByFilter.keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { SQDropDownMenuViewModel.Item(title: $0) }

        let dropDownViewModel: SQDropDownMenuViewModel? = filterItems.count > 1
            ? SQDropDownMenuViewModel(
                defaultItem: .init(title: "All"),
                items: filterItems,
                itemSelectionHandler: { _ in }
            )
            : nil

        // Return section view model
        let scoreColumnTitle = state.selectedTimeRange == .today ? "Score" : "AVG SCORE"

        let sectionViewModel = SQDashboardSubsectionViewModel(
            id: "performance",
            title: "Performance",
            defaultPriority: 20,
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel,
            columnHeaders: ["", scoreColumnTitle, "Rank"],
            maxVisibleRows: 4
        )

        dropDownViewModel?.itemSelectionHandler = { selectedFilter in
            sectionViewModel.updateActiveFilter(selectedFilter)
        }

        return sectionViewModel
    }

    // MARK: - Totals Subsection Builder

    private func buildTotalsSubsection(config: SQDashboardWorkoutSummaryRowConfig, workouts: [SQWorkoutSessionable], priorWorkouts: [SQWorkoutSessionable]) -> SQDashboardSubsectionViewModel? {
        
        let timeRow = SQDashboardWorkoutTotalsRowViewModel(config: config, workouts: workouts, priorWorkouts: priorWorkouts, filter: .workoutTime)
        let caloriesRow = SQDashboardWorkoutTotalsRowViewModel(config: config, workouts: workouts, priorWorkouts: priorWorkouts, filter: .kilocalories)

        // Build rowsByFilter dictionary
        let rowsByFilter: [String: [SQDashboardWorkoutTotalsRowViewModel]] = [
            "Time": [timeRow],
            "Kilocalories": [caloriesRow]
        ]

        // Create dropdown filter items
        let filterItems = [
            SQDropDownMenuViewModel.Item(title: "Time"),
            SQDropDownMenuViewModel.Item(title: "Kilocalories")
        ]

        // Create dropdown view model
        let dropDownViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: "Time"),
            items: filterItems,
            itemSelectionHandler: { _ in }
        )
        let sectionViewModel = SQDashboardSubsectionViewModel(
            id: "totals",
            title: "Totals",
            defaultPriority: 10,
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel
        )
        
        dropDownViewModel.itemSelectionHandler = { [weak self] selectedFilter in
            sectionViewModel.updateActiveFilter(selectedFilter)
        }

        // Return section view model
        return sectionViewModel
    }

    // MARK: - Activities Subsection Builder

    private func buildActivitiesSubsection(
        workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable]
    ) async -> SQDashboardSubsectionViewModel? {
        // Skip if no workouts
        guard !workouts.isEmpty else { return nil }

        // Extract unique activity types from workouts
        var uniqueActivityTypes = Set<String>()
        for workout in workouts {
            uniqueActivityTypes.insert(workout.activityType.name)
        }

        // Sort activity types alphabetically
        let sortedActivityTypes = uniqueActivityTypes.sorted()

        // Create dropdown items: "All" + sorted activity types
        let filterItems = [SQDropDownMenuViewModel.Item(title: "All")] + sortedActivityTypes.map { activityType in
            SQDropDownMenuViewModel.Item(title: activityType)
        }

        // Build rowsByFilter dictionary
        var rowsByFilter: [String: [SQDashboardActivityRowViewModel]] = [:]
        
        // "All" filter: Aggregate stats for ALL workouts
        var allRows: [SQDashboardActivityRowViewModel] = []

        let scoreItemsByActivity = await workoutScoreService.activityScoreItems(
            for: workouts,
            allTimeWorkouts: allTimeWorkouts,
            isPremiumUnlocked: SQSubscriptionManager.hasPremiumAccess
        )

        for (activityType, workouts) in workouts.workoutsByActivityType.sorted(by: { $0.value.count > $1.value.count }) {
            let groupViewModel = SQDashboardWorkoutGroupViewModel(
                activityType: activityType,
                workouts: .init(workouts: workouts),
                additionalStatItems: scoreItemsByActivity[activityType] ?? []
            )
            allRows.append(.init(workoutGroupViewModels: [groupViewModel]))
            rowsByFilter[activityType.name] = [.init(workoutGroupViewModels: [groupViewModel])]
        }
        rowsByFilter["All"] = allRows
        
        // Create dropdown view model
        let dropDownViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: "All"),
            items: filterItems,
            itemSelectionHandler: { _ in }
        )
        
        let sectionViewModel = SQDashboardSubsectionViewModel(
            id: "activities",
            title: "Activities",
            defaultPriority: 20,
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel,
            rowSpacing: .SQSpace.l,
            maxVisibleRows: 4
        )
        
        dropDownViewModel.itemSelectionHandler = { selectedFilter in
            sectionViewModel.updateActiveFilter(selectedFilter)
        }

        // Return section view model
        return sectionViewModel
    }

    private func buildPerformanceInsightsSubsection(
        workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable]
    ) async -> SQDashboardSubsectionViewModel? {
        guard let model = await workoutScoreService.dashboardInsights(
            for: workouts,
            allTimeWorkouts: allTimeWorkouts,
            isPremiumUnlocked: SQSubscriptionManager.hasPremiumAccess
        ) else {
            return nil
        }

        let row = SQDashboardWorkoutPremiumInsightRowViewModel(
            model: model
        ) { [weak self] score in
            self?.displayWorkoutInsightDetail(score.detailModel)
        } onLockedTap: {
            SQSubscriptionManager.displaySubscriptionScreen(
                source: "dashboard_performance_insights",
                feature: "workout_scores"
            )
        }
        return SQDashboardSubsectionViewModel(
            id: "performance-insights",
            title: "Performance Insights",
            defaultPriority: 5,
            rowsByFilter: ["All": [row as SQDashboardRowViewModel]]
        )
    }

    private func displayWorkoutInsightDetail(_ model: SQWorkoutPremiumInsightDetailModel) {
        SQAnalyticsManager.shared.track(.insightOpened(
            insightId: nil,
            insightType: model.title.analyticsKey,
            sourceScreen: "dashboard",
            insightCategory: "workout_score"
        ))
        let controller = SQWorkoutInsightDetailController(model: model)
        state.hub.domainEvents.send(.pushDashboardRoute(.workoutInsightDetail(controller: controller)))
    }

    // MARK: - Sleep Builders

    private func buildSleepDashboardData(for timeRange: AppTimeRange) async throws -> SQSleepDashboardData? {
        let sleepSchedule = userState.loggedInUser?.sleepSchedule
        let initialWindow = sleepAggregationService.makeDashboardWindow(
            for: timeRange,
            sleepSchedule: sleepSchedule
        )

        var sleepSegments = try await fetchDashboardSleepSegments(
            from: initialWindow.fetchStartDate,
            to: initialWindow.fetchEndDate
        )
        let resolvedWindow = sleepAggregationService.resolveDashboardWindow(
            for: timeRange,
            segments: sleepSegments,
            baseWindow: initialWindow,
            sleepSchedule: sleepSchedule
        )

        if resolvedWindow.fetchStartDate < initialWindow.fetchStartDate
            || resolvedWindow.fetchEndDate > initialWindow.fetchEndDate {
            sleepSegments = try await fetchDashboardSleepSegments(
                from: resolvedWindow.fetchStartDate,
                to: resolvedWindow.fetchEndDate
            )
        }

        let dashboardData = sleepAggregationService.buildDashboardData(
            segments: sleepSegments,
            window: resolvedWindow,
            sleepSchedule: sleepSchedule
        )

        return dashboardData.currentNights.isEmpty ? nil : dashboardData
    }

    private func fetchDashboardSleepSegments(from startDate: Date, to endDate: Date) async throws -> [SQSleepStageSegment] {
        if shouldUseDashboardDemoData {
            return SQHealthKitManager.shared.mockHealthData.sleepSegments(from: startDate, to: endDate)
        }

        return try await healthKitManager.fetchSleepSegments(from: startDate, to: endDate)
    }

    private func buildSleepSectionGroup(with data: SQSleepDashboardData) -> SQDashboardSectionGroupViewModel? {
        var sleepSections = [SQDashboardSubsectionViewModel]()

        if let scoreSection = buildSleepScoreSubsection(with: data) {
            sleepSections.append(scoreSection)
        }

        if let summarySection = buildSleepSummarySubsection(with: data) {
            sleepSections.append(summarySection)
        }

        if let durationSection = buildSleepDurationSubsection(with: data) {
            sleepSections.append(durationSection)
        }

        if let timelineSection = buildSleepTimelineSubsection(with: data) {
            sleepSections.append(timelineSection)
        }

        if let phasesSection = buildSleepPhasesSubsection(with: data) {
            sleepSections.append(phasesSection)
        }

        guard !sleepSections.isEmpty else { return nil }

        return SQDashboardSectionGroupViewModel(
            id: "sleep",
            title: "Sleep",
            defaultPriority: 30,
            sections: sleepSections
        )
    }

    private func buildSleepScoreSubsection(with data: SQSleepDashboardData) -> SQDashboardSubsectionViewModel? {
        guard let averageScore = data.averageScore else { return nil }

        let totalScore = averageScore.totalScore
        let detailPrefix = sleepScoreDetailPrefix(for: data.currentNights.count, timeRange: state.selectedTimeRange)

        let scoreRow = SQDashboardSleepScoreRowViewModel(
            totalScore: totalScore,
            scoreLabel: "\(Int(round(totalScore)))/100",
            components: [
                .init(
                    id: "duration",
                    title: "Duration",
                    score: averageScore.durationScore,
                    maxScore: SQSleepScoreBreakdown.maxDurationScore,
                    color: .accent(1),
                    detailText: durationDetailText(for: data.currentNights, prefix: detailPrefix)
                ),
                .init(
                    id: "efficiency",
                    title: "Efficiency",
                    score: averageScore.efficiencyScore,
                    maxScore: SQSleepScoreBreakdown.maxEfficiencyScore,
                    color: .accentNeutral1,
                    detailText: efficiencyDetailText(for: data.currentNights, prefix: detailPrefix)
                ),
                .init(
                    id: "fragmentation",
                    title: "Fragmentation",
                    score: averageScore.fragmentationScore,
                    maxScore: SQSleepScoreBreakdown.maxFragmentationScore,
                    color: .accentNeutral4,
                    detailText: fragmentationDetailText(for: data.currentNights, prefix: detailPrefix)
                ),
                .init(
                    id: "architecture",
                    title: "Architecture",
                    score: averageScore.architectureScore,
                    maxScore: SQSleepScoreBreakdown.maxArchitectureScore,
                    color: .dashboardGlowMint,
                    detailText: architectureDetailText(for: data.currentNights, prefix: detailPrefix)
                )
            ]
        )

        return SQDashboardSubsectionViewModel(
            id: "sleep-score",
            title: data.currentNights.count > 1 ? "Average Sleep Score" : "Sleep Score",
            defaultPriority: 10,
            rowsByFilter: ["All": [scoreRow]],
            dropDownViewModel: nil,
            titleButton: userState.isLoggedIn
            ? nil
            : .init(icon: .infoCircle, title: "Guest") { [weak self] in
                self?.presentGuestSleepAccuracyAlert()
            }
        )
    }

    private func buildSleepSummarySubsection(with data: SQSleepDashboardData) -> SQDashboardSubsectionViewModel? {
        guard !data.currentNights.isEmpty else { return nil }

        let isAverageWindow = data.currentNights.count > 1
        let totalSleepSeconds = data.currentNights.map(\.totalSleepDuration).reduce(0, +)
        let averageSleepSeconds = totalSleepSeconds / Double(max(1, data.currentNights.count))
        let sleepSchedule = userState.loggedInUser?.sleepSchedule

        let averageSleepStart = averageBedtimeTime(
            of: data.currentNights.map(\.sleepStartDate),
            sleepSchedule: sleepSchedule
        )
        let averageWakeTime = averageWakeTime(
            of: data.currentNights.map(\.wakeDate),
            sleepSchedule: sleepSchedule
        )

        let summaryRow = SQDashboardSleepSummaryRowViewModel(items: [
            .init(
                id: "sleep-total",
                title: isAverageWindow ? "Avg Total Sleep" : "Total Sleep",
                value: formattedDuration(averageSleepSeconds)
            ),
            .init(
                id: "sleep-bedtime",
                title: isAverageWindow ? "Avg Bedtime" : "Bedtime",
                value: averageSleepStart?.formattedString(with: .timeOnly) ?? "N/A"
            ),
            .init(
                id: "sleep-wake",
                title: isAverageWindow ? "Avg Wake Time" : "Wake Time",
                value: averageWakeTime?.formattedString(with: .timeOnly) ?? "N/A"
            )
        ])

        return SQDashboardSubsectionViewModel(
            id: "sleep-summary",
            title: "Sleep Summary",
            defaultPriority: 20,
            rowsByFilter: ["All": [summaryRow]],
            dropDownViewModel: nil
        )
    }

    private func buildSleepPhasesSubsection(with data: SQSleepDashboardData) -> SQDashboardSubsectionViewModel? {
        var rows = [SQDashboardRowViewModel]()

        let iconByPhase: [SQSleepPhase: String] = [
            .rem: SQImageSymbol.eye.rawValue,
            .deep: SQImageSymbol.moonZzzFill.rawValue,
            .core: SQImageSymbol.bedDoubleFill.rawValue,
            .awake: SQImageSymbol.sunMaxFill.rawValue
        ]

        let phaseOrder: [SQSleepPhase] = [.rem, .deep, .core, .awake]
        for phase in phaseOrder {
            guard let aggregate = data.phaseAggregates.first(where: { $0.phase == phase }) else { continue }

            let row = SQDashboardMetricStatsRowViewModel(
                metricId: "sleep.\(phase.rawValue)",
                icon: iconByPhase[phase] ?? SQImageSymbol.moonFill.rawValue,
                title: phase.title,
                avgValue: formattedDuration(aggregate.averageDuration),
                unit: "",
                sparklineData: aggregate.sparklineDataHours,
                changePercent: aggregate.changePercent,
                onTap: { [weak self] in
                    self?.displaySleepPhaseTrends(focusedPhase: phase)
                }
            )
            rows.append(row)
        }

        guard !rows.isEmpty else { return nil }

        return SQDashboardSubsectionViewModel(
            id: "sleep-phases",
            title: "Sleep Phases",
            defaultPriority: 40,
            rowsByFilter: ["All": rows],
            dropDownViewModel: nil,
            columnHeaders: ["Phase", "Avg Duration", state.selectedTimeRange.dashboardChangePctHeader]
        )
    }

    private func displaySleepPhaseTrends(focusedPhase: SQSleepPhase) {
        SQLogger.shared.log(
            "Displaying sleep phase trends for '\(focusedPhase.title)'",
            .debug,
            context: .dashboard
        )
        let controller = SQSleepPhaseTrendsController(
            initialTimeRange: state.selectedTimeRange,
            focusedPhase: focusedPhase
        )
        
        state.hub.domainEvents.send(.pushDashboardRoute(.sleepPhaseTrends(controller: controller)))
    }

    private func buildSleepDurationSubsection(with data: SQSleepDashboardData) -> SQDashboardSubsectionViewModel? {
        guard let row = buildSleepDurationRow(with: data, timeRange: state.selectedTimeRange) else {
            return nil
        }

        return SQDashboardSubsectionViewModel(
            id: "sleep-duration",
            title: "Sleep Duration",
            defaultPriority: 30,
            rowsByFilter: ["All": [row]],
            dropDownViewModel: nil
        )
    }

    private func buildSleepTimelineSubsection(with data: SQSleepDashboardData) -> SQDashboardSubsectionViewModel? {
        guard state.selectedTimeRange == .today,
              let timelineRow = buildSleepPhaseTimelineRow(with: data) else { return nil }

        return SQDashboardSubsectionViewModel(
            id: "sleep-timeline",
            title: "Sleep Timeline",
            defaultPriority: 30,
            rowsByFilter: ["All": [timelineRow]],
            dropDownViewModel: nil
        )
    }

    private func buildSleepPhaseTimelineRow(with data: SQSleepDashboardData) -> SQDashboardSleepPhaseTimelineRowViewModel? {
        guard let latestNight = data.latestNight else { return nil }

        let lanes: [TimelineChartLane] = [
            .init(id: SQSleepPhase.awake.rawValue, title: "Awake", color: SQColor.dashboardTrendWarm.color),
            .init(id: SQSleepPhase.rem.rawValue, title: "REM", color: SQColor.dashboardGlowBlue.color),
            .init(id: SQSleepPhase.core.rawValue, title: "Core", color: Color.white.opacity(SQColor.isDarkMode ? 0.88 : 0.72)),
            .init(id: SQSleepPhase.deep.rawValue, title: "Deep", color: SQColor.dashboardGlowMint.color)
        ]

        let segments = latestNight.segments.map { segment in
            TimelineChartSegment(
                id: segment.id,
                laneId: segment.phase.rawValue,
                startDate: segment.startDate,
                endDate: segment.endDate
            )
        }

        let title = "Last Night Timeline • \(latestNight.sleepStartDate.formattedString(with: .timeOnly))-\(latestNight.wakeDate.formattedString(with: .timeOnly))"

        return SQDashboardSleepPhaseTimelineRowViewModel(
            title: title,
            lanes: lanes,
            segments: segments,
            startDate: latestNight.sleepStartDate,
            endDate: latestNight.wakeDate,
            onPhaseSelected: { [weak self] phase in
                self?.displaySleepPhaseTrends(focusedPhase: phase)
            }
        )
    }

    private func buildSleepDurationRow(
        with data: SQSleepDashboardData,
        timeRange: AppTimeRange
    ) -> SQDashboardSleepDurationRowViewModel? {
        let buckets = makeSleepDurationBuckets(with: data, timeRange: timeRange)
        guard !buckets.isEmpty else { return nil }

        let averageSourceBuckets = buckets.filter { $0.durationHours > 0 }
        let averageDurationHours = averageSourceBuckets.map(\.durationHours).average ?? 0
        let latestBucketId = buckets.last?.id
        let defaultColor = SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.58 : 0.70)
        let highlightColor = SQColor.dashboardGlowBlue.color

        let shouldPackBarsLeading = (timeRange == .pastYear || timeRange == .allTime)
            && buckets.count <= 6

        return SQDashboardSleepDurationRowViewModel(
            bars: buckets.map { bucket in
                .init(
                    id: bucket.id,
                    label: bucket.label,
                    focusTitle: bucket.focusTitle,
                    valueHours: bucket.durationHours,
                    color: bucket.id == latestBucketId ? highlightColor : defaultColor
                )
            },
            averageDurationHours: averageDurationHours,
            averageLabel: "AVG \(formattedDuration(averageDurationHours * 3600))",
            barSpacing: timeRange == .past30Days ? 4 : 8,
            minimumBarWidth: timeRange == .past30Days ? 3 : 8,
            maximumBarWidth: timeRange == .past30Days ? 8 : 18,
            packsBarsLeading: shouldPackBarsLeading
        )
    }

    private struct SleepDurationBucket {
        let id: String
        let label: String
        let focusTitle: String
        let durationHours: Double
        let sortDate: Date
    }

    private func makeSleepDurationBuckets(
        with data: SQSleepDashboardData,
        timeRange: AppTimeRange
    ) -> [SleepDurationBucket] {
        let calendar = Calendar.current
        let nights: [SQSleepNight]
        switch timeRange {
        case .today:
            nights = Array((data.priorNights + data.currentNights).sorted { $0.wakeDay < $1.wakeDay }.suffix(7))
        default:
            nights = data.currentNights.sorted { $0.wakeDay < $1.wakeDay }
        }

        switch timeRange {
        case .pastYear:
            let grouped = Dictionary(grouping: nights) { night in
                calendar.date(from: calendar.dateComponents([.year, .month], from: night.wakeDay))
                ?? calendar.startOfDay(for: night.wakeDay)
            }

            let latestMonth = nights.last.flatMap {
                calendar.date(from: calendar.dateComponents([.year, .month], from: $0.wakeDay))
            } ?? calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now

            let monthStarts = (0..<12).compactMap { offset in
                calendar.date(byAdding: .month, value: -(11 - offset), to: latestMonth)
            }

            return monthStarts.compactMap { monthStart in
                guard let bucketNights = grouped[monthStart],
                      let averageHours = bucketNights.map({ $0.totalSleepDuration / 3600 }).average else {
                    return nil
                }
                return SleepDurationBucket(
                    id: monthStart.firebaseDailyDateKey,
                    label: monthLabel(for: monthStart),
                    focusTitle: fullMonthLabel(for: monthStart),
                    durationHours: averageHours,
                    sortDate: monthStart
                )
            }

        case .allTime:
            let grouped = Dictionary(grouping: nights) { night in
                let year = calendar.component(.year, from: night.wakeDay)
                return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
                ?? calendar.startOfDay(for: night.wakeDay)
            }

            return grouped.compactMap { yearStart, bucketNights -> SleepDurationBucket? in
                let averageHours = bucketNights.map { $0.totalSleepDuration / 3600 }.average
                guard let averageHours else { return nil }
                return SleepDurationBucket(
                    id: yearStart.firebaseDailyDateKey,
                    label: yearLabel(for: yearStart),
                    focusTitle: yearLabel(for: yearStart),
                    durationHours: averageHours,
                    sortDate: yearStart
                )
            }
            .sorted { $0.sortDate < $1.sortDate }

        case .past30Days:
            return nights.map { night in
                SleepDurationBucket(
                    id: night.id,
                    label: "",
                    focusTitle: night.wakeDay.formattedString(with: .medium),
                    durationHours: night.totalSleepDuration / 3600,
                    sortDate: night.wakeDay
                )
            }

        case .today, .pastSevenDays:
            return nights.map { night in
                SleepDurationBucket(
                    id: night.id,
                    label: weekdayLabel(for: night.wakeDay),
                    focusTitle: sleepFocusTitle(for: night.wakeDay),
                    durationHours: night.totalSleepDuration / 3600,
                    sortDate: night.wakeDay
                )
            }
        }
    }

    private func weekdayLabel(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date) - 1
        let symbols = ["S", "M", "T", "W", "T", "F", "S"]
        guard symbols.indices.contains(weekday) else { return "" }
        return symbols[weekday]
    }

    private func monthLabel(for date: Date) -> String {
        let month = Calendar.current.component(.month, from: date) - 1
        let symbols = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        guard symbols.indices.contains(month) else { return "" }
        return symbols[month]
    }

    private func fullMonthLabel(for date: Date) -> String {
        let month = Calendar.current.component(.month, from: date) - 1
        let symbols = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]
        guard symbols.indices.contains(month) else { return date.formattedString(with: .medium) }
        return symbols[month]
    }

    private func yearLabel(for date: Date) -> String {
        String(Calendar.current.component(.year, from: date))
    }

    private func sleepFocusTitle(for date: Date) -> String {
        let weekday = date.weekdayName(from: date)
        let mediumDate = date.formattedString(with: .medium)
        return "\(weekday), \(mediumDate)"
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60.0).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func title(for period: SQMetricPeriod) -> String {
        switch period {
        case .morning:
            return "Morning"
        case .evening:
            return "Evening"
        case .unknown:
            return "Daily"
        }
    }

    private func sleepScoreDetailPrefix(for nightCount: Int, timeRange: AppTimeRange) -> String {
        guard nightCount > 1 else { return "Last night" }

        switch timeRange {
        case .today:
            return "Last night"
        case .allTime:
            return "Across \(nightCount) nights"
        default:
            return "Across the last \(nightCount) nights"
        }
    }

    private func durationDetailText(for nights: [SQSleepNight], prefix: String) -> AttributedString {
        let averageSleep = nights.map(\.totalSleepDuration).average ?? 0
        return buildSleepDetailText([
            .plain("\(prefix), average sleep was "),
            .highlight(formattedDuration(averageSleep)),
            .plain(". This score compares sleep time against an "),
            .highlight("8h"),
            .plain(" target, so shorter nights pull it down.")
        ])
    }

    private func efficiencyDetailText(for nights: [SQSleepNight], prefix: String) -> AttributedString {
        let totalSleep = nights.map(\.totalSleepDuration).reduce(0, +)
        let totalTimeInBed = nights.map(\.timeInBedDuration).reduce(0, +)
        guard totalTimeInBed > 0 else {
            return buildSleepDetailText([
                .plain("\(prefix), efficiency could not be calculated because time-in-bed data was unavailable.")
            ])
        }

        let efficiency = totalSleep / totalTimeInBed
        return buildSleepDetailText([
            .plain("\(prefix), about "),
            .highlight(efficiency.toPercentageString(decimals: 0)),
            .plain(" of time in bed was spent asleep ("),
            .highlight(formattedDuration(totalSleep / Double(max(1, nights.count)))),
            .plain(" asleep out of "),
            .highlight(formattedDuration(totalTimeInBed / Double(max(1, nights.count)))),
            .plain(" in bed on average).")
        ])
    }

    private func fragmentationDetailText(for nights: [SQSleepNight], prefix: String) -> AttributedString {
        let awakeMinutes = nights.map { $0.phaseDuration(for: .awake) / 60.0 }
        let awakePeriods = nights.map { Double($0.segments.filter { $0.phase == .awake }.count) }
        let averageAwakeMinutes = awakeMinutes.average ?? 0
        let averageAwakePeriods = awakePeriods.average ?? 0
        let roundedPeriods = max(0, Int(averageAwakePeriods.rounded()))

        if nights.count == 1 {
            let periodLabel = roundedPeriods == 1 ? "awake period" : "awake periods"
            return buildSleepDetailText([
                .plain("\(prefix), sleep was interrupted by "),
                .highlight("\(roundedPeriods)"),
                .plain(" \(periodLabel) totaling "),
                .highlight(formattedDuration(averageAwakeMinutes * 60)),
                .plain(". More interruptions or awake time lower this score.")
            ])
        }

        let periodLabel = roundedPeriods == 1 ? "awake period" : "awake periods"
        return buildSleepDetailText([
            .plain("\(prefix), there were about "),
            .highlight("\(roundedPeriods)"),
            .plain(" \(periodLabel) per night totaling "),
            .highlight(formattedDuration(averageAwakeMinutes * 60)),
            .plain(" awake on average. More broken-up sleep lowers this score.")
        ])
    }

    private func architectureDetailText(for nights: [SQSleepNight], prefix: String) -> AttributedString {
        let totalSleep = nights.map(\.totalSleepDuration).reduce(0, +)
        guard totalSleep > 0 else {
            return buildSleepDetailText([
                .plain("\(prefix), architecture could not be calculated because no sleep-phase data was available.")
            ])
        }

        let remShare = nights.map { $0.phaseDuration(for: .rem) }.reduce(0, +) / totalSleep
        let deepShare = nights.map { $0.phaseDuration(for: .deep) }.reduce(0, +) / totalSleep

        return buildSleepDetailText([
            .plain("\(prefix), REM made up "),
            .highlight(remShare.toPercentageString(decimals: 0)),
            .plain(" and Deep sleep made up "),
            .highlight(deepShare.toPercentageString(decimals: 0)),
            .plain(" of total sleep. This score rewards a balanced restorative mix.")
        ])
    }

    private enum SleepDetailSegment {
        case plain(String)
        case highlight(String)
    }

    private func buildSleepDetailText(_ segments: [SleepDetailSegment]) -> AttributedString {
        segments.reduce(into: AttributedString()) { result, segment in
            switch segment {
            case .plain(let text):
                result += AttributedString.build(with: text, color: SQColor.textSecondary.color)
            case .highlight(let text):
                result += AttributedString.build(with: text, color: SQColor.dashboardGlowBlue.color)
            }
        }
    }

    private func averageBedtimeTime(
        of dates: [Date],
        sleepSchedule: SQSleepSchedule?
    ) -> Date? {
        guard !dates.isEmpty else { return nil }

        let fallbackAnchorMinutes = 23 * 60
        return averageTime(
            of: dates,
            anchorMinutes: sleepSchedule?.sleepTime.minutesSinceMidnight ?? fallbackAnchorMinutes
        )
    }

    private func averageWakeTime(
        of dates: [Date],
        sleepSchedule: SQSleepSchedule?
    ) -> Date? {
        guard !dates.isEmpty else { return nil }

        return averageTime(
            of: dates,
            anchorMinutes: sleepSchedule?.wakeTime.minutesSinceMidnight ?? (7 * 60)
        )
    }

    private func averageTime(of dates: [Date], anchorMinutes: Int) -> Date? {
        guard !dates.isEmpty else { return nil }

        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: dates[0])
        let secondsInDay = 24.0 * 60.0 * 60.0
        let anchorSeconds = Double(anchorMinutes * 60)

        let adjustedSeconds = dates.map { date -> Double in
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let second = components.second ?? 0
            var totalSeconds = Double(hour * 3600 + minute * 60 + second)

            if (totalSeconds - anchorSeconds) < (-secondsInDay / 2.0) {
                totalSeconds += secondsInDay
            } else if (totalSeconds - anchorSeconds) > (secondsInDay / 2.0) {
                totalSeconds -= secondsInDay
            }

            return totalSeconds
        }

        let averageSeconds = positiveModulo(
            adjustedSeconds.reduce(0, +) / Double(adjustedSeconds.count),
            modulus: secondsInDay
        )
        return anchorDay.addingTimeInterval(averageSeconds)
    }

    private func positiveModulo(_ value: Double, modulus: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }

    // MARK: - Section Groups Builder

    private func buildSectionGroups(
        checkIns: [SQDailyCheckInStats],
        priorCheckIns: [SQDailyCheckInStats],
        insightsResult: SQInsightsResult,
        insightExplorerInput: SQHealthIntelligenceInput,
        vo2MaxSamples: [SQVO2MaxSample],
        vo2MaxAllTime: [SQVO2MaxSample],
        todaysWorkouts: [SQWorkoutSessionable],
        yesterdaysWorkouts: [SQWorkoutSessionable],
        workouts: [SQWorkoutSessionable],
        priorWorkouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        sleepAccessStatus: SQHealthKitDashboardAccessStatus,
        heartAccessStatus: SQHealthKitDashboardAccessStatus,
        workoutsAccessStatus: SQHealthKitDashboardAccessStatus,
        includeHeartRateData: Bool,
        timeRange: SQTimeRange,
        priorTimeRange: SQTimeRange,
        context: ModelContext
    ) async throws -> [SQDashboardSectionGroupViewModel] {
        var sectionGroups: [SQDashboardSectionGroupViewModel] = []

        if timeRange == .today,
           let recoveryGroup = try await buildRecoverySectionGroup(
                todaysWorkouts: todaysWorkouts,
                yesterdaysWorkouts: yesterdaysWorkouts,
                sleepData: sleepData,
                includeHeartRateData: includeHeartRateData,
                context: context
           ) {
            sectionGroups.append(recoveryGroup)
        }

        // Build Daily Stats group
        var dailyStatsSections: [SQDashboardSubsectionViewModel] = []

        // Add Metrics subsection
        let metricsSection = buildMetricsSubsection(
            checkIns: checkIns,
            priorCheckIns: priorCheckIns,
            timeRange: state.selectedTimeRange,
            context: context
        )
        dailyStatsSections.append(metricsSection)

        // Create Daily Stats section group (only if has sections)
        if !dailyStatsSections.isEmpty {
            let dailyStatsTitleButton: SQDashboardSubsectionViewModel.TitleButtonViewModel? = userState.isLoggedIn
                ? .init(icon: .edit, title: "Edit Check-In") { [weak self] in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.displayDailyCheckInSheet(for: context)
                    }
                }
                : nil

            let dailyStatsGroup = SQDashboardSectionGroupViewModel(
                id: "daily-stats",
                title: "Daily Stats",
                defaultPriority: 20,
                titleButton: dailyStatsTitleButton,
                sections: dailyStatsSections
            )
            sectionGroups.append(dailyStatsGroup)
        }

        let insightsSection = buildInsightsSubsection(
            result: insightsResult,
            explorerInput: insightExplorerInput
        )
        let explorerSection = buildInsightExplorerSubsection(input: insightExplorerInput)

        let insightsGroup = SQDashboardSectionGroupViewModel(
            id: "insights",
            title: "Insights",
            defaultPriority: 25,
            sections: [insightsSection, explorerSection]
        )
        sectionGroups.append(insightsGroup)

        if let sleepData, let sleepGroup = buildSleepSectionGroup(with: sleepData) {
            sectionGroups.append(sleepGroup)
        } else if sleepAccessStatus == .unavailable {
            sectionGroups.append(
                buildHealthAccessWarningSectionGroup(
                    id: "sleep",
                    title: "Sleep",
                    subsectionId: "sleep-access-warning",
                    subsectionTitle: "Sleep Access Required",
                    icon: .bedDoubleFill,
                    message: "Sleep data is currently unavailable",
                    detail: "Sleep may not be tracked yet, or Health access may not be enabled. If you use sleep data in LifeIQ, check Health app > Profile > Apps > LifeIQ, enable Sleep, then come back here and tap to retry.",
                    context: context,
                    defaultPriority: 30
                )
            )
        } else {
            sectionGroups.append(
                buildHealthAccessWarningSectionGroup(
                    id: "sleep",
                    title: "Sleep",
                    subsectionId: "sleep-empty-warning",
                    subsectionTitle: "Sleep Data Unavailable",
                    icon: .bedDoubleFill,
                    message: "No sleep data is available right now",
                    detail: "You may not have any sleep data yet, or Health access may not be enabled for Sleep. If you use sleep data in LifeIQ, check Health app > Profile > Apps > LifeIQ, then come back here and tap to retry.",
                    context: context,
                    defaultPriority: 30
                )
            )
        }

        let heartGroup = try await buildHeartSectionGroup(
            timeRange: timeRange,
            includeHeartRateData: includeHeartRateData
        )
        if let heartGroup {
            sectionGroups.append(heartGroup)
        } else if heartAccessStatus == .unavailable {
            sectionGroups.append(
                buildHealthAccessWarningSectionGroup(
                    id: "heart",
                    title: "Heart",
                    subsectionId: "heart-access-warning",
                    subsectionTitle: "Heart Access Required",
                    icon: .heart,
                    message: "Heart data is currently unavailable",
                    detail: "Heart data may not be tracked yet, or Health access may not be enabled. If you use heart data in LifeIQ, check Health app > Profile > Apps > LifeIQ, enable Heart Rate and Resting Heart Rate, then come back here and tap to retry.",
                    context: context,
                    defaultPriority: 40
                )
            )
        } else {
            sectionGroups.append(
                buildHealthAccessWarningSectionGroup(
                    id: "heart",
                    title: "Heart",
                    subsectionId: "heart-empty-warning",
                    subsectionTitle: "Heart Data Unavailable",
                    icon: .heart,
                    message: "No heart data is available right now",
                    detail: "You may not have any heart data yet, or Health access may not be enabled for Heart Rate or Resting Heart Rate. If you use heart data in LifeIQ, check Health app > Profile > Apps > LifeIQ, then come back here and tap to retry.",
                    context: context,
                    defaultPriority: 40
                )
            )
        }
        
        var workoutsSections: [SQDashboardSubsectionViewModel] = []

        if let runInsightsSection = await buildPerformanceInsightsSubsection(
            workouts: workouts,
            allTimeWorkouts: allTimeWorkouts
        ) {
            workoutsSections.append(runInsightsSection)
        }

        if let performanceSection = await buildPerformanceSubsection(
            vo2MaxSamples: vo2MaxSamples,
            vo2MaxAllTime: vo2MaxAllTime,
            workouts: workouts,
            allTimeWorkouts: allTimeWorkouts
        ) {
            workoutsSections.append(performanceSection)
        }
        
        // Add Totals subsection
        if let totalsSection = buildTotalsSubsection(config: .init(timeRange: timeRange, priorTimeRange: priorTimeRange), workouts: workouts, priorWorkouts: priorWorkouts) {
            workoutsSections.append(totalsSection)
        }

        // Add Activities subsection
        if let activitiesSection = await buildActivitiesSubsection(
            workouts: workouts,
            allTimeWorkouts: allTimeWorkouts
        ) {
            workoutsSections.append(activitiesSection)
        }

        let workoutsGroup: SQDashboardSectionGroupViewModel
        if workoutsAccessStatus == .unavailable && allTimeWorkouts.isEmpty {
            workoutsGroup = buildHealthAccessWarningSectionGroup(
                id: "workouts",
                title: "Workouts",
                subsectionId: "workouts-access-warning",
                subsectionTitle: "Workout Access Required",
                icon: .bicycle,
                message: "Workout data is currently unavailable",
                detail: "Open the Health app > Profile > Apps > LifeIQ, enable Workouts, then come back here and tap to retry.",
                context: context,
                defaultPriority: 50
            )
        } else if allTimeWorkouts.isEmpty {
            workoutsGroup = buildHealthAccessWarningSectionGroup(
                id: "workouts",
                title: "Workouts",
                subsectionId: "workouts-empty-warning",
                subsectionTitle: "Workout Data Unavailable",
                icon: .bicycle,
                message: "No workout data is available right now",
                detail: "You may not have any workouts yet, or Health access may not be enabled for Workouts. If you use workout data in LifeIQ, check Health app > Profile > Apps > LifeIQ, then come back here and tap to retry.",
                context: context,
                defaultPriority: 50
            )
        } else {
            workoutsGroup = SQDashboardSectionGroupViewModel(
                id: "workouts",
                title: "Workouts",
                defaultPriority: 50,
                sections: workoutsSections
            )
        }
        
        sectionGroups.append(workoutsGroup)

        return sectionGroups
    }

    private func buildDashboardInsightsResult(
        input: SQHealthIntelligenceInput
    ) -> SQInsightsResult {
        insightsService.dashboardInsights(input: input)
    }

    private func scoreContext(from lifeScoreViewModel: SQLifeScoreViewModel) -> SQHealthIntelligenceScoreContext {
        .init(
            score: lifeScoreViewModel.score,
            stateTitle: lifeScoreViewModel.state.title,
            scoreDeltaFromPreviousDay: lifeScoreViewModel.scoreDeltaFromPreviousDay
        )
    }

    private func buildInsightsSubsection(
        result: SQInsightsResult,
        explorerInput: SQHealthIntelligenceInput
    ) -> SQDashboardSubsectionViewModel {
        let displayInsights = SQAdminConfig.hideScreenshotSensitiveInsights
            ? result.insights.filter { !isScreenshotSensitiveInsight($0) }
            : result.insights
        let displayState: SQInsightDataState = displayInsights.isEmpty && result.state == .ready
            ? .noPatterns
            : result.state

        let emptyState: SQDashboardSubsectionViewModel.EmptyStateViewModel?
        switch displayState {
        case .ready:
            emptyState = nil
        case .notEnoughData:
            let remainingDays = max(0, result.requiredMinimumDayCount - result.analyzedDayCount)
            emptyState = .init(
                title: "Insights are calibrating",
                subtitle: remainingDays > 0
                    ? "Log about \(remainingDays) more days of sleep, habits, and workout feedback so LifeIQ can start finding patterns."
                    : "Log a bit more sleep, habit, and workout feedback so LifeIQ can start finding patterns.",
                icon: .chartBar,
                onTap: nil
            )
        case .noPatterns:
            emptyState = .init(
                title: "No strong patterns yet",
                subtitle: "Keep logging sleep, habits, check-ins, and workout feedback so LifeIQ can spot stronger patterns over time.",
                icon: .chartBar,
                onTap: nil
            )
        }

        let isPremiumUnlocked = SQSubscriptionManager.hasPremiumAccess
        func buildRows(for insights: [SQInsight]) -> [SQDashboardRowViewModel] {
            var rows = [SQDashboardRowViewModel]()

            if let firstInsight = insights.first {
                rows.append(SQDashboardInsightRowViewModel(
                    model: firstInsight,
                    onInfoTap: { [weak state] in
                        SQAnalyticsManager.shared.track(.insightOpened(
                            insightId: firstInsight.id,
                            insightType: firstInsight.familyKey.analyticsKey,
                            sourceScreen: "dashboard",
                            insightCategory: firstInsight.category.rawValue.analyticsKey
                        ))
                        state?.hub.domainEvents.send(.pushDashboardRoute(.insightDetail(
                            model: firstInsight,
                            explorerController: self.makeInsightExplorerController(
                                input: explorerInput,
                                insight: firstInsight
                            )
                        )))
                    }
                ))
            }

            if isPremiumUnlocked {
                for insight in insights.dropFirst() {
                    rows.append(SQDashboardInsightRowViewModel(
                        model: insight,
                        onInfoTap: { [weak state] in
                            SQAnalyticsManager.shared.track(.insightOpened(
                                insightId: insight.id,
                                insightType: insight.familyKey.analyticsKey,
                                sourceScreen: "dashboard",
                                insightCategory: insight.category.rawValue.analyticsKey
                            ))
                            state?.hub.domainEvents.send(.pushDashboardRoute(.insightDetail(
                                model: insight,
                                explorerController: self.makeInsightExplorerController(
                                    input: explorerInput,
                                    insight: insight
                                )
                            )))
                        }
                    ))
                }
            } else if let lockedPreview = insights.dropFirst().first {
                rows.append(SQDashboardInsightRowViewModel(
                    model: lockedPreview,
                    isLocked: true,
                    onLockedTap: {
                        SQSubscriptionManager.displaySubscriptionScreen(
                            source: "dashboard_insights_locked_preview",
                            feature: "insights"
                        )
                    }
                ))
            }

            return rows
        }

        let rows = buildRows(for: displayInsights)

        let categoryOrder: [SQInsightCategory] = [.recovery, .sleep, .training, .habits]
        let presentCategories = categoryOrder.filter { category in
            displayInsights.contains(where: { $0.category == category })
        }

        var rowsByFilter: [String: [SQDashboardRowViewModel]] = ["All": rows]
        for category in presentCategories {
            rowsByFilter[category.badgeTitle] = buildRows(
                for: displayInsights.filter { $0.category == category }
            )
        }

        let filterItems = [SQDropDownMenuViewModel.Item(title: "All")] + presentCategories.map {
            SQDropDownMenuViewModel.Item(title: $0.badgeTitle)
        }
        let dropDownViewModel: SQDropDownMenuViewModel? = isPremiumUnlocked && filterItems.count > 1
            ? SQDropDownMenuViewModel(
                defaultItem: .init(title: "All"),
                items: filterItems,
                itemSelectionHandler: { _ in }
            )
            : nil

        let visibleInsightTitles = rows.compactMap { row -> String? in
            guard let insightRow = row as? SQDashboardInsightRowViewModel else { return nil }
            return insightRow.model.title
        }

        if SQAdminConfig.verboseLoggingEnabled {
            SQLogger.shared.log(
                "Insights surfaced on dashboard: showing \(visibleInsightTitles.count) of \(displayInsights.count) display-safe insights, \(result.insights.count) total. Visible: \(visibleInsightTitles.joined(separator: " | "))",
                .debug,
                context: .dashboard
            )
        }

        let sectionViewModel = SQDashboardSubsectionViewModel(
            id: "insights",
            title: "Insights",
            defaultPriority: 15,
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel,
            titleButton: .init(
                icon: .chartBar,
                title: "All",
                onTap: { [weak self] in
                    guard let self else { return }

                    if isPremiumUnlocked {
                        self.state.hub.domainEvents.send(
                            .pushDashboardRoute(
                                .insightLibrary(
                                    controller: .init(
                                        input: explorerInput,
                                        source: "dashboard_insights"
                                    )
                                )
                            )
                        )
                    } else {
                        SQSubscriptionManager.displaySubscriptionScreen(
                            source: "dashboard_insights_library",
                            feature: "insights"
                        )
                    }
                }
            ),
            rowSpacing: .SQSpace.m,
            maxVisibleRows: 4,
            emptyState: emptyState
        )

        dropDownViewModel?.itemSelectionHandler = { selectedFilter in
            sectionViewModel.updateActiveFilter(selectedFilter)
        }

        return sectionViewModel
    }

    private func buildInsightExplorerSubsection(input: SQHealthIntelligenceInput) -> SQDashboardSubsectionViewModel {
        let isPremiumUnlocked = SQSubscriptionManager.hasPremiumAccess
        let controller = SQInsightExplorerController(input: input)
        let topRelationships = SQAdminConfig.hideScreenshotSensitiveInsights
            ? controller.topRelationships.filter { !isScreenshotSensitiveRelationship($0) }
            : controller.topRelationships
        let row = SQDashboardInsightExplorerRowViewModel(
            isLocked: !isPremiumUnlocked,
            topRelationships: topRelationships,
            onOpenExplorer: { [weak state] in
                state?.hub.domainEvents.send(.pushDashboardRoute(.insightExplorer(controller: controller)))
            },
            onOpenLibrary: { [weak state] in
                state?.hub.domainEvents.send(
                    .pushDashboardRoute(
                        .insightLibrary(
                            controller: .init(
                                input: input,
                                source: "dashboard_insight_explorer"
                            )
                        )
                    )
                )
            },
            onLockedTap: {
                SQSubscriptionManager.displaySubscriptionScreen(
                    source: "dashboard_insight_explorer",
                    feature: "insight_explorer"
                )
            },
            onRelationshipTap: { [weak state] relationship in
                controller.applyTopRelationship(relationship)
                state?.hub.domainEvents.send(.pushDashboardRoute(.insightExplorer(controller: controller)))
            }
        )

        return SQDashboardSubsectionViewModel(
            id: "insight-explorer",
            title: "Insight Explorer",
            defaultPriority: 16,
            rowsByFilter: ["All": [row as SQDashboardRowViewModel]]
        )
    }

    private func isScreenshotSensitiveInsight(_ insight: SQInsight) -> Bool {
        if containsScreenshotSensitiveSignalId(insight.inputSignalId)
            || containsScreenshotSensitiveSignalId(insight.outputSignalId)
            || containsScreenshotSensitiveText(insight.id)
            || containsScreenshotSensitiveText(insight.familyKey) {
            return true
        }

        return [
            insight.title,
            insight.summary,
            insight.evidenceText,
            insight.actionText,
            insight.driverText,
            insight.outcomeText,
            insight.deltaText
        ].contains(where: containsScreenshotSensitiveText)
    }

    private func isScreenshotSensitiveRelationship(_ relationship: SQInsightExplorerRelationshipResult) -> Bool {
        if containsScreenshotSensitiveSignalId(relationship.driverId)
            || containsScreenshotSensitiveSignalId(relationship.outcomeId)
            || containsScreenshotSensitiveText(relationship.id) {
            return true
        }

        return [
            relationship.driverTitle,
            relationship.outcomeTitle,
            relationship.effectSummary
        ].contains(where: containsScreenshotSensitiveText)
    }

    private func containsScreenshotSensitiveSignalId(_ signalId: String?) -> Bool {
        guard let signalId else { return false }
        return signalId == SQMetricId.weed || signalId == SQMetricId.porn
    }

    private func containsScreenshotSensitiveText(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        return lowercasedText.contains("weed")
            || lowercasedText.contains("porn")
            || lowercasedText.contains("cannabis")
            || lowercasedText.contains("marijuana")
    }

    private func makeInsightExplorerController(
        input: SQHealthIntelligenceInput,
        insight: SQInsight
    ) -> SQInsightExplorerController? {
        SQLogger.shared.log(
            "PTD InsightExplorer request insightId=\(insight.id) title=\(insight.title) class=\(insight.insightClass.rawValue) input=\(insight.inputSignalId ?? "nil") output=\(insight.outputSignalId ?? "nil") supports=\(insight.supportsInsightExplorer)",
            .debug,
            context: .dashboard
        )

        guard insight.supportsInsightExplorer else {
            SQLogger.shared.log(
                "PTD InsightExplorer skipped unsupported insightId=\(insight.id) class=\(insight.insightClass.rawValue) input=\(insight.inputSignalId ?? "nil") output=\(insight.outputSignalId ?? "nil")",
                .debug,
                context: .dashboard
            )
            return nil
        }

        let controller = SQInsightExplorerController(
            input: input,
            preselectedDriverId: insight.inputSignalId,
            preselectedOutcomeId: insight.outputSignalId,
            preselectedLag: insight.variantPriority >= 2 ? .twoDaysLater : .nextDay
        )

        guard controller.result != nil else {
            let optionIds = Set(controller.metricOptions.map(\.id))
            SQLogger.shared.log(
                "PTD InsightExplorer unavailable insightId=\(insight.id) input=\(insight.inputSignalId ?? "nil") inputInOptions=\(insight.inputSignalId.map { optionIds.contains($0) }?.description ?? "nil") output=\(insight.outputSignalId ?? "nil") outputInOptions=\(insight.outputSignalId.map { optionIds.contains($0) }?.description ?? "nil") selectedDriver=\(controller.selectedDriverId) selectedOutcome=\(controller.selectedOutcomeId) selectedRange=\(controller.selectedRange.rawValue) selectedLag=\(controller.selectedLag.rawValue) optionCount=\(controller.metricOptions.count) topRelationshipCount=\(controller.topRelationships.count)",
                .debug,
                context: .dashboard
            )
            return nil
        }

        SQLogger.shared.log(
            "PTD InsightExplorer ready insightId=\(insight.id) selectedDriver=\(controller.selectedDriverId) selectedOutcome=\(controller.selectedOutcomeId) selectedRange=\(controller.selectedRange.rawValue) selectedLag=\(controller.selectedLag.rawValue)",
            .debug,
            context: .dashboard
        )

        return controller
    }

    private func presentInsightsInfoAlert() {
        let alert = SQAlertViewModel(
            title: "How Insights Work",
            subtitle: "LifeIQ looks for patterns across your check-ins, sleep, workouts, and health data so you can better understand what affects your mood, energy, recovery, and performance.\n\nYou might see insights like \"Low sleep may be linked to lower mood\" or \"Caffeine is trending higher recently.\"\n\nThe more check-ins you complete, the more personal and accurate your insights become. Early insights may be simple, but they get stronger as LifeIQ learns your patterns.",
            primary: .init(title: "Got it"),
            canDismiss: true
        )

        state.hub.alertEvents.send(.present(alert))
    }

    private func buildInsightActionsSubsection(
        result: SQInsightsResult
    ) -> SQDashboardSubsectionViewModel? {
        guard !result.actions.isEmpty else { return nil }

        let rows = result.actions.map {
            SQDashboardInsightActionRowViewModel(model: $0) as SQDashboardRowViewModel
        }

        return SQDashboardSubsectionViewModel(
            id: "insight-actions",
            title: "What To Do",
            defaultPriority: 13,
            rowsByFilter: ["All": rows],
            rowSpacing: .SQSpace.m,
            maxVisibleRows: 1
        )
    }

    private func buildInsightChangesSubsection(
        result: SQInsightsResult
    ) -> SQDashboardSubsectionViewModel? {
        guard !result.changes.isEmpty else { return nil }

        let rows = result.changes.map {
            SQDashboardInsightChangeRowViewModel(model: $0) as SQDashboardRowViewModel
        }

        return SQDashboardSubsectionViewModel(
            id: "insight-changes",
            title: "What Changed",
            defaultPriority: 14,
            rowsByFilter: ["All": rows],
            rowSpacing: .SQSpace.m,
            maxVisibleRows: 2
        )
    }

    private func buildHealthAccessWarningSectionGroup(
        id: String,
        title: String,
        subsectionId: String,
        subsectionTitle: String,
        icon: SQImageSymbol,
        message: String,
        detail: String,
        context: ModelContext,
        defaultPriority: Int? = nil
    ) -> SQDashboardSectionGroupViewModel {
        let subsection = SQDashboardSubsectionViewModel(
            id: subsectionId,
            title: subsectionTitle,
            defaultPriority: 10,
            rowsByFilter: ["All": []],
            emptyState: .init(
                title: message,
                subtitle: detail,
                icon: icon,
                onTap: { [weak self] in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.loadUI(
                            for: context,
                            shouldForceRefresh: true,
                            showLoadingState: true
                        )
                    }
                }
            )
        )

        return SQDashboardSectionGroupViewModel(
            id: id,
            title: title,
            defaultPriority: defaultPriority ?? 30,
            sections: [subsection]
        )
    }

    private func buildRecoverySectionGroup(
        todaysWorkouts: [SQWorkoutSessionable],
        yesterdaysWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        includeHeartRateData: Bool,
        context: ModelContext
    ) async throws -> SQDashboardSectionGroupViewModel? {
        guard let row = try await bodyBatteryService.buildDashboardRowViewModel(
            todaysWorkouts: todaysWorkouts,
            yesterdaysWorkouts: yesterdaysWorkouts,
            sleepData: sleepData,
            includeHeartRateData: includeHeartRateData,
            context: context
        ) else {
            return nil
        }

        return SQDashboardSectionGroupViewModel(
            id: "recovery",
            title: "Recovery",
            defaultPriority: 15,
            sections: [buildRecoveryScoreSubsection(row: row)]
        )
    }

    private func buildRecoveryScoreSubsection(
        row: SQDashboardBodyBatteryRowViewModel
    ) -> SQDashboardSubsectionViewModel {
        SQDashboardSubsectionViewModel(
            id: "recovery-score",
            title: "Recovery",
            defaultPriority: 10,
            rowsByFilter: ["All": [row]],
            dropDownViewModel: nil,
            titleButton: .init(
                icon: .infoCircle,
                title: nil,
                onTap: { [weak self] in
                    self?.handleRecoveryScoreInfoTap(row: row)
                }
            )
        )
    }

    private func buildHeartSectionGroup(
        timeRange: SQTimeRange,
        includeHeartRateData: Bool
    ) async throws -> SQDashboardSectionGroupViewModel? {
        guard let row = try await heartRateService.buildDashboardRowViewModel(
            for: timeRange,
            includeHealthKitData: includeHeartRateData
        ) else {
            return nil
        }

        let section = SQDashboardSubsectionViewModel(
            id: "heart-rate",
            title: "Heart Rate",
            defaultPriority: 10,
            rowsByFilter: ["All": [row]]
        )

        return SQDashboardSectionGroupViewModel(
            id: "heart",
            title: "Heart",
            defaultPriority: 40,
            sections: [section]
        )
    }

    // MARK: - Metric Row Builder

    private func buildMetricRow(for definition: SQMetricDefinition, from stats: [SQDailyCheckInStats], priorStats: [SQDailyCheckInStats]) -> SQDashboardMetricStatsRowViewModel? {
        // Get all values for this metric
        let values = stats.compactMap { $0.values[definition.id] }

        // Skip if no data
        guard !values.isEmpty else {
            if SQAdminConfig.verboseLoggingEnabled {
                SQLogger.shared.log(
                    "Metric row skipped for '\(definition.title)' (\(definition.id)) - no current values in \(stats.count) check-ins",
                    .debug,
                    context: .dashboard
                )
            }
            return nil
        }

        // Calculate average
        let sum = values.reduce(0, +)
        let average = sum / Float(values.count)

        // Format average value
        let avgValueString: String
        if definition.kind == .binary {
            // For binary metrics, show count
            avgValueString = String(format: "%.1f", average)
        } else if definition.quantityUnit == .hours {
            avgValueString = String(format: "%.1f", average)
        } else {
            avgValueString = String(format: "%.1f", average)
        }

        // Format unit
        let unitString = metricUnitString(for: definition)

        // Build sparkline data (in chronological order)
        let sparklineData = values.map { Double($0) }

        // Icon: use emoji if available, otherwise empty string
        let icon = definition.emoji ?? ""

        let priorValues = priorStats.compactMap { $0.values[definition.id] }
        let priorAverage: Float? = priorValues.isEmpty ? nil : priorValues.reduce(0, +) / Float(priorValues.count)

        let changePercent: Double?
        if let prior = priorAverage, prior != 0 {
            changePercent = Double((average - prior) / prior)
        } else {
            changePercent = nil
        }

        SQLogger.shared.log(
            """
            Metric row '\(definition.title)' (\(definition.id)):
            currentValues=\(values.count)
            priorValues=\(priorValues.count)
            currentAverage=\(String(format: "%.2f", average))
            priorAverage=\(priorAverage.map { String(format: "%.2f", $0) } ?? "nil")
            sparklineCount=\(sparklineData.count)
            changePercent=\(changePercent.map { String(format: "%.4f", $0) } ?? "nil")
            icon='\(icon)'
            """,
            .debug,
            context: .dashboard
        )

        return SQDashboardMetricStatsRowViewModel(
            metricId: definition.id,
            icon: icon,
            title: definition.title,
            avgValue: avgValueString,
            unit: unitString,
            sparklineData: sparklineData,
            changePercent: changePercent
        )
    }

    private func metricUnitString(for definition: SQMetricDefinition) -> String {
        let unit = definition.quantityUnit
        switch unit {
        case .none:
            return (definition.kind == .scale || definition.kind == .binary) ? "/\(Int(definition.scaleMaxValue))" : ""
        case .count:
            return ""
        case .percent:
            return "%"
        case .unknown:
            return ""
        default:
            return unit.shortDisplayName
        }
    }
}
