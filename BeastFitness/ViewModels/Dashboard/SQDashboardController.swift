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
    func loadUI(for context: ModelContext, shouldForceRefresh: Bool) async
    func refreshUI(for context: ModelContext) async
    func displayDailyCheckInSheet(for context: ModelContext, date: Date?) async
}

@Observable @MainActor
final class SQDashboardController: SQDashboardInterface {
    private var cancellables = Set<AnyCancellable>()
    var state: DashboardStating
    let navState: NavigationStating
    let userState: SQUserStating
    let dailyCheckInManager: SQDailyCheckInManaging
    let metricEntryManager: SQMetricEntryManaging
    let workoutManager: SQWorkoutManaging
    let healthKitManager: SQHealthKitManaging
    let statsManager: SQWorkoutStatsManaging
    let sleepAggregationService: SQSleepAggregationService
    private(set) var hasLoadedUI = false
    private var isLoadUIInProgress = false
    private var pendingForcedRefresh = false
    let timeRangeMenuViewModel: SQDropDownMenuViewModel
    
    
    @MainActor
    static let `default` = SQDashboardController(state: SQAppState.shared.dashboardState, navState: SQAppState.shared.navigationState)
    
    init(
        state: DashboardStating,
        navState: NavigationStating,
        userState: SQUserStating = SQAppState.shared.userState,
        dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(),
        metricEntryManager: SQMetricEntryManaging = SQAppState.shared.metricEntryManager,
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared,
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        statsManager: SQWorkoutStatsManaging = SQWorkoutStatsManager.shared,
        sleepAggregationService: SQSleepAggregationService = .init()
    ) {
        self.state = state
        self.navState = navState
        self.userState = userState
        self.dailyCheckInManager = dailyCheckInManager
        self.metricEntryManager = metricEntryManager
        self.workoutManager = workoutManager
        self.healthKitManager = healthKitManager
        self.statsManager = statsManager
        self.sleepAggregationService = sleepAggregationService
        
        let items = AppTimeRange.allCases
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }
        self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: state.selectedTimeRange.rawValue),
            items: items
        ) { [weak state] selectedTitle in
            guard let state else { return }
            if let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }) {
                state.selectedTimeRange = selectedRange
            }
        }

        if !userState.hasResolvedInitialAuthState {
            state.updateSectionGroups(to: SQDashboardSectionGroupViewModel.mock)
            state.setLoading(true)
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

        hub.userEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .loginStateChanged:
                if self.hasLoadedUI {
                    self.refreshFromGlobalContext()
                } else if let modelContext = SQAppState.shared.modelContext {
                    Task { await self.loadUI(for: modelContext) }
                }
            }
        }.store(in: &cancellables)

        // Watch for time range changes and reload dashboard
        state.selectedTimeRangePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                SQLogger.shared.log("Time range changed, reloading dashboard", .debug, context: .dashboard)
                self.refreshFromGlobalContext()
            }
            .store(in: &cancellables)
    }

    private func refreshFromGlobalContext() {
        guard let modelContext = SQAppState.shared.modelContext else { return }
        Task { await self.loadUI(for: modelContext, shouldForceRefresh: true) }
    }
    
    func loadUI(for context: ModelContext, shouldForceRefresh: Bool = false) async {
        guard userState.hasResolvedInitialAuthState else {
            SQLogger.shared.log(
                "Skipping dashboard load until initial auth state resolves.",
                .debug,
                context: .dashboard
            )
            return
        }
        guard !hasLoadedUI || shouldForceRefresh else { return }
        guard !isLoadUIInProgress else {
            if shouldForceRefresh {
                pendingForcedRefresh = true
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
                Task { @MainActor in
                    await self.loadUI(for: context, shouldForceRefresh: true)
                }
            }
        }

        hasLoadedUI = true

        // Show mock skeleton while real data loads
        state.updateSectionGroups(to: SQDashboardSectionGroupViewModel.mock)
        state.setLoading(true)

        do {
            // Sync daily check-ins from Firestore
            let timeRange = state.selectedTimeRange.sqTimeRange
            
            if userState.isLoggedIn {
                
                _ = try await dailyCheckInManager.syncDailyCheckInsIfNeeded(
                    for: timeRange,
                    context: context
                )
                
                _ = try await SQMetricsManager.shared.syncMetricsIfNeeded(using: context)
            }

            // Fetch VO2 Max samples for different time ranges
            let vo2MaxPast7Days = try await healthKitManager.fetchVO2MaxSamples(
                .pastWeek
            )
            let vo2MaxPast30Days = try await healthKitManager.fetchVO2MaxSamples(
                .past30Days
            )
            let vo2MaxPastYear = try await healthKitManager.fetchVO2MaxSamples(
                .pastYear
            )
            let vo2MaxAllTime = try await healthKitManager.fetchVO2MaxSamples(
                .allTime
            )

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

            let currentCheckInPeriod = DashboardState.checkInPeriod(for: .now)
            let dailyCheckInStats = try? await dailyCheckInManager.getDailyCheckInStats(
                for: .now,
                period: currentCheckInPeriod,
                context: context
            )

            // Fetch historical check-ins for different time ranges using SQTimeRange dates
            let todaysCheckIns = try await metricEntryManager.getDailyCheckInStats(
                from: SQTimeRange.today.startDate,
                to: SQTimeRange.today.endDate,
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

            // Set the daily check-in CTA view model if no stats exist
            if dailyCheckInStats == nil, userState.isLoggedIn {
                state.updateDailyCheckInCtaViewModel(.init(
                    icon: .init(symbol: .checkmark),
                    title: "Complete your \(title(for: currentCheckInPeriod)) check-in",
                    onTap: {
                        Task { await self.displayDailyCheckInSheet(for: context) }
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
                currentCheckIns = todaysCheckIns
                priorCheckIns = past7DaysCheckIns
                currentVO2MaxSamples = vo2MaxPast7Days
            case .pastSevenDays:
                currentWorkouts = lastWeekWorkouts
                priorWorkouts = weekBeforeLastWorkouts
                priorTimeRange = .weekBeforeLast
                currentCheckIns = past7DaysCheckIns
                priorCheckIns = weekBeforeLastCheckIns
                currentVO2MaxSamples = vo2MaxPast7Days
            case .past30Days:
                currentWorkouts = past30DaysWorkouts
                priorWorkouts = thirtyDaysBeforeLastWorkouts
                priorTimeRange = .thirtyDaysBeforeLast
                currentCheckIns = past30DaysCheckIns
                priorCheckIns = thirtyDaysBeforeLastCheckIns
                currentVO2MaxSamples = vo2MaxPast30Days
            case .pastYear:
                currentWorkouts = lastYearWorkouts
                priorWorkouts = yearBeforeLastWorkouts
                priorTimeRange = .yearBeforeLast
                currentCheckIns = pastYearCheckIns
                priorCheckIns = yearBeforeLastCheckIns
                currentVO2MaxSamples = vo2MaxPastYear
            case .allTime:
                currentWorkouts = allTimeWorkouts
                priorWorkouts = []  // No comparison for all time
                priorTimeRange = .allTime  // No prior period for all time
                currentCheckIns = allTimeCheckIns
                priorCheckIns = []
                currentVO2MaxSamples = vo2MaxAllTime
            }

            let sleepDashboardData = try await buildSleepDashboardData(
                for: state.selectedTimeRange
            )

            let sectionGroups = await buildSectionGroups(
                checkIns: currentCheckIns,
                priorCheckIns: priorCheckIns,
                todaysCheckIns: todaysCheckIns,
                vo2MaxSamples: currentVO2MaxSamples,
                vo2MaxAllTime: vo2MaxAllTime,
                todaysWorkouts: todaysWorkouts,
                yesterdaysWorkouts: yesterdaysWorkouts,
                workouts: currentWorkouts,
                priorWorkouts: priorWorkouts,
                allTimeWorkouts: allTimeWorkouts,
                sleepData: sleepDashboardData,
                timeRange: state.selectedTimeRange.sqTimeRange,
                priorTimeRange: priorTimeRange,
                context: context
            )
            state.updateSectionGroups(to: sectionGroups)

            // Clear loading state
            state.setLoading(false)

            // Emit any unreviewed recent workouts for the new workout review modal
            processNewWorkoutReviews(workouts: past30DaysWorkouts, context: context)
        } catch {
            SQLogger.shared.log("Error loading dashboard", .error, context: .dashboard)

            // Clear loading state on error
            state.setLoading(false)

            // TODO: - PTD allow refreshes if there is an error here
            state.hub.alertEvents.send(.present(.init(SQError.standard(withDescription: error.localizedDescription))))
        }
    }
    
    func refreshUI(for context: ModelContext) async {
        SQLogger.shared.log("Refreshing dashboard", .debug, context: .dashboard)
        await loadUI(for: context, shouldForceRefresh: true)
    }
    
    func displayDailyCheckInSheet(for context: ModelContext, date: Date? = nil) async {
        let targetDate = date ?? .now
        let checkInPeriod = DashboardState.checkInPeriod(for: targetDate)
        let dailyCheckInStats = try? await dailyCheckInManager.getDailyCheckInStats(
            for: targetDate,
            period: checkInPeriod,
            context: context
        )
        state.displayDailyCheckInSheet(with: dailyCheckInStats, for: targetDate)
    }

    // MARK: - New Workout Review Processing

    private func processNewWorkoutReviews(
        workouts: [SQWorkoutSessionable],
        context: ModelContext
    ) {
        guard let installDate = SQUserDefaults.shared.appInstallDate else {
            SQLogger.shared.log("appInstallDate missing — skipping workout review processing", .error, context: .dashboard)
            return
        }

        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let processedIds = workoutManager.fetchProcessedSourceIds(context: context)

        let reviewableWorkouts = workouts.filter { workout in
            guard let startDate = workout.startDate else { return false }
            let sourceId = workout.workoutSource.sourcableData.sourceId
            return startDate >= fourteenDaysAgo
                && startDate >= installDate
                && !processedIds.contains(sourceId)
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
//        
//        var sorted = [SQWorkoutSessionable]()
//        var total = 0
//        for workout in workouts.sorted(by: { $0.startDate ?? Date() > $1.startDate ?? Date() }) {
//            sorted.append(workout)
//            total += 1
//            if total >= 2 { break }
//        }
        print("PTD process new workout launch!")
        
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
        let allDefinitions = SQMetricsManager.shared.dailyCheckInMetrics().sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        SQLogger.shared.log(
            "Building Metrics subsection for \(timeRange.rawValue): current check-ins = \(stats.count), prior check-ins = \(priorCheckIns.count), definitions = \(allDefinitions.count)",
            .debug,
            context: .dashboard
        )

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

        // Create title button (edit button) only when showing "Today" timerange
        let titleButton: SQDashboardSubsectionViewModel.TitleButtonViewModel? = {
            guard timeRange == .today else { return nil }

            return .init(icon: .edit, title: "Edit") { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.displayDailyCheckInSheet(for: context)
                }
            }
        }()

        let sectionViewModel = SQDashboardSubsectionViewModel(
            id: "metrics",
            title: "Metrics",
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel,
            titleButton: titleButton,
            columnHeaders: ["", "Avg Score", timeRange.dashboardChangePctHeader],
            maxVisibleRows: 4
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
        allTimeWorkouts: [SQWorkoutSessionable],
        timeRange: SQTimeRange
    ) async -> SQDashboardSubsectionViewModel? {
        var rows: [SQDashboardMetricPerformanceRowViewModel] = []

        // Add VO2 Max row if we have samples
        if !vo2MaxSamples.isEmpty {
            // Calculate best VO2 Max (highest value)
            let bestVO2Max = vo2MaxSamples.map { $0.value }.max() ?? 0.0

            // Format best value (e.g., "45.3")
            let bestValueString = String(format: "%.1f", bestVO2Max)

            // Calculate percentile rank
            let historicalValues = vo2MaxAllTime.map { $0.value }
            let percentileRank = SQPercentileCalculator.calculatePercentile(
                currentBest: bestVO2Max,
                historicalValues: historicalValues,
                isLowerBetter: false  // Higher VO2 max is better
            )

            let vo2MaxRow = SQDashboardMetricPerformanceRowViewModel(
                metricId: "vo2-max",
                icon: SQImageSymbol.heart.rawValue,
                title: "VO₂ Max",
                bestValue: bestValueString,
                unit: "mL/kg/min",
                percentileRank: percentileRank,
                leaderboardMode: .vo2Max
            )
            rows.append(vo2MaxRow)
        }
        
        // Build performance rows per activity type using the stats manager
        let uniqueActivityTypes = Set(workouts.map { $0.activityType })
        for activityType in uniqueActivityTypes {
            let activityWorkouts = workouts.filter { $0.activityType == activityType }
            guard !activityWorkouts.isEmpty else { continue }

            let performanceRows = await statsManager.loadPerformanceRows(
                for: activityType,
                in: activityWorkouts,
                allTimeWorkouts: allTimeWorkouts
            )
            rows.append(contentsOf: performanceRows.map { rowData in
                SQDashboardMetricPerformanceRowViewModel(
                    metricId: rowData.id,
                    icon: rowData.icon,
                    title: rowData.title,
                    bestValue: rowData.bestValue,
                    unit: rowData.unit,
                    percentileRank: rowData.percentileRank,
                    leaderboardMode: rowData.leaderboardMode
                )
            })
        }

        // Skip section if no performance data at all
        guard !rows.isEmpty else { return nil }

        // Build rowsByFilter dictionary (no filters for Performance)
        let rowsByFilter: [String: [SQDashboardMetricPerformanceRowViewModel]] = ["All": rows]

        // Return section view model
        return SQDashboardSubsectionViewModel(
            id: "performance",
            title: "Performance",
            rowsByFilter: rowsByFilter,
            dropDownViewModel: nil,  // No filter dropdown for performance
            columnHeaders: ["", "Best Score", "Rank"],
            maxVisibleRows: 4
        )
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

    private func buildActivitiesSubsection(workouts: [SQWorkoutSessionable], timeRange: SQTimeRange) -> SQDashboardSubsectionViewModel? {
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

        for (activityType, workouts) in workouts.workoutsByActivityType.sorted(by: { $0.value.count > $1.value.count }) {
            allRows.append(.init(workouts: workouts))
            rowsByFilter[activityType.name] = [.init(workouts: workouts)]
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

    // MARK: - Sleep Builders

    private func buildSleepDashboardData(for timeRange: AppTimeRange) async throws -> SQSleepDashboardData? {
        let window = sleepAggregationService.makeDashboardWindow(for: timeRange)
        let sleepSegments = try await healthKitManager.fetchSleepSegments(
            from: window.fetchStartDate,
            to: window.fetchEndDate
        )

        let dashboardData = sleepAggregationService.buildDashboardData(
            segments: sleepSegments,
            window: window
        )

        return dashboardData.currentNights.isEmpty ? nil : dashboardData
    }

    private func buildSleepSectionGroup(with data: SQSleepDashboardData) -> SQDashboardSectionGroupViewModel? {
        var sleepSections = [SQDashboardSubsectionViewModel]()

        if let scoreSection = buildSleepScoreSubsection(with: data) {
            sleepSections.append(scoreSection)
        }

        if let summarySection = buildSleepSummarySubsection(with: data) {
            sleepSections.append(summarySection)
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
            rowsByFilter: ["All": [scoreRow]],
            dropDownViewModel: nil
        )
    }

    private func buildSleepSummarySubsection(with data: SQSleepDashboardData) -> SQDashboardSubsectionViewModel? {
        guard !data.currentNights.isEmpty else { return nil }

        let isAverageWindow = data.currentNights.count > 1
        let totalSleepSeconds = data.currentNights.map(\.totalSleepDuration).reduce(0, +)
        let averageSleepSeconds = totalSleepSeconds / Double(max(1, data.currentNights.count))

        let averageSleepStart = averageBedtimeTime(of: data.currentNights.map(\.sleepStartDate))
        let averageWakeTime = averageWakeTime(of: data.currentNights.map(\.wakeDate))

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
                changePercent: aggregate.changePercent
            )
            rows.append(row)
        }

        guard !rows.isEmpty else { return nil }

        return SQDashboardSubsectionViewModel(
            id: "sleep-phases",
            title: "Sleep Phases",
            rowsByFilter: ["All": rows],
            dropDownViewModel: nil,
            columnHeaders: ["Phase", "Avg Duration", state.selectedTimeRange.dashboardChangePctHeader]
        )
    }

    private func buildSleepTimelineSubsection(with data: SQSleepDashboardData) -> SQDashboardSubsectionViewModel? {
        guard state.selectedTimeRange == .today,
              let timelineRow = buildSleepPhaseTimelineRow(with: data) else { return nil }

        return SQDashboardSubsectionViewModel(
            id: "sleep-timeline",
            title: "Sleep Timeline",
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
            endDate: latestNight.wakeDate
        )
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

    private func averageBedtimeTime(of dates: [Date]) -> Date? {
        guard !dates.isEmpty else { return nil }

        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: dates[0])
        let secondsInDay = 24.0 * 60.0 * 60.0

        let adjustedSeconds = dates.compactMap { date -> Double? in
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let second = components.second ?? 0
            let totalSeconds = Double(hour * 3600 + minute * 60 + second)

            // Bedtimes after midnight should be treated as late-night continuation.
            let normalizedSeconds = totalSeconds < (12.0 * 3600.0) ? totalSeconds + secondsInDay : totalSeconds

            // Keep only likely nighttime bedtimes (6:00 PM to 5:00 AM next day).
            // This avoids daytime naps/skewed sessions polluting long-range averages.
            let lowerBound = 18.0 * 3600.0
            let upperBound = 29.0 * 3600.0
            guard normalizedSeconds >= lowerBound, normalizedSeconds <= upperBound else { return nil }

            return normalizedSeconds
        }

        guard !adjustedSeconds.isEmpty else { return nil }

        let averageSecondsAdjusted = adjustedSeconds.reduce(0, +) / Double(adjustedSeconds.count)
        let averageSeconds = averageSecondsAdjusted.truncatingRemainder(dividingBy: secondsInDay)
        return anchorDay.addingTimeInterval(averageSeconds)
    }

    private func averageWakeTime(of dates: [Date]) -> Date? {
        guard !dates.isEmpty else { return nil }

        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: dates[0])
        let secondsInDay = 24.0 * 60.0 * 60.0

        let secondsValues = dates.map { date -> Double in
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let second = components.second ?? 0
            return Double(hour * 3600 + minute * 60 + second)
        }

        let averageSeconds = (secondsValues.reduce(0, +) / Double(secondsValues.count))
            .truncatingRemainder(dividingBy: secondsInDay)
        return anchorDay.addingTimeInterval(averageSeconds)
    }

    // MARK: - Section Groups Builder

    private func buildSectionGroups(
        checkIns: [SQDailyCheckInStats],
        priorCheckIns: [SQDailyCheckInStats],
        todaysCheckIns: [SQDailyCheckInStats],
        vo2MaxSamples: [SQVO2MaxSample],
        vo2MaxAllTime: [SQVO2MaxSample],
        todaysWorkouts: [SQWorkoutSessionable],
        yesterdaysWorkouts: [SQWorkoutSessionable],
        workouts: [SQWorkoutSessionable],
        priorWorkouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        timeRange: SQTimeRange,
        priorTimeRange: SQTimeRange,
        context: ModelContext
    ) async -> [SQDashboardSectionGroupViewModel] {
        var sectionGroups: [SQDashboardSectionGroupViewModel] = []

        if let overviewGroup = buildOverviewSectionGroup(
            todaysCheckIns: todaysCheckIns,
            todaysWorkouts: todaysWorkouts,
            yesterdaysWorkouts: yesterdaysWorkouts,
            sleepData: sleepData
        ) {
            sectionGroups.append(overviewGroup)
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

        // Add Performance subsection
        if let performanceSection = await buildPerformanceSubsection(
            vo2MaxSamples: vo2MaxSamples,
            vo2MaxAllTime: vo2MaxAllTime,
            workouts: workouts,
            allTimeWorkouts: allTimeWorkouts,
            timeRange: timeRange
        ) {
            dailyStatsSections.append(performanceSection)
        }

        // Create Daily Stats section group (only if has sections)
        if !dailyStatsSections.isEmpty {
            let dailyStatsGroup = SQDashboardSectionGroupViewModel(
                id: "daily-stats",
                title: "Daily Stats",
                sections: dailyStatsSections
            )
            sectionGroups.append(dailyStatsGroup)
        }

        if let sleepData, let sleepGroup = buildSleepSectionGroup(with: sleepData) {
            sectionGroups.append(sleepGroup)
        }
        
        var workoutsSections: [SQDashboardSubsectionViewModel] = []
        
        // Add Totals subsection
        if let totalsSection = buildTotalsSubsection(config: .init(timeRange: timeRange, priorTimeRange: priorTimeRange), workouts: workouts, priorWorkouts: priorWorkouts) {
            workoutsSections.append(totalsSection)
        }

        // Add Activities subsection
        if let activitiesSection = buildActivitiesSubsection(workouts: workouts, timeRange: timeRange) {
            workoutsSections.append(activitiesSection)
        }

        // Create Workouts section group (currently empty, will be populated later)
        let workoutsGroup = SQDashboardSectionGroupViewModel(
            id: "workouts",
            title: "Workouts",
            sections: workoutsSections
        )
        
        sectionGroups.append(workoutsGroup)

        return sectionGroups
    }

    private func buildOverviewSectionGroup(
        todaysCheckIns: [SQDailyCheckInStats],
        todaysWorkouts: [SQWorkoutSessionable],
        yesterdaysWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?
    ) -> SQDashboardSectionGroupViewModel? {
        guard let bodyBatterySection = buildBodyBatterySubsection(
            todaysCheckIns: todaysCheckIns,
            todaysWorkouts: todaysWorkouts,
            yesterdaysWorkouts: yesterdaysWorkouts,
            sleepData: sleepData
        ) else {
            return nil
        }

        return SQDashboardSectionGroupViewModel(
            id: "overview",
            title: "Overview",
            sections: [bodyBatterySection]
        )
    }

    private func buildBodyBatterySubsection(
        todaysCheckIns: [SQDailyCheckInStats],
        todaysWorkouts: [SQWorkoutSessionable],
        yesterdaysWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?
    ) -> SQDashboardSubsectionViewModel? {
        guard sleepData?.latestNight != nil || !todaysWorkouts.isEmpty || !yesterdaysWorkouts.isEmpty || !todaysCheckIns.isEmpty else {
            return nil
        }

        let latestSleepScore = sleepData?.latestNight.map { sleepAggregationService.score(for: $0).totalScore }
        let sleepRecharge = clamp(
            (latestSleepScore ?? 52) * 0.52,
            min: 14,
            max: 55
        )

        let todaysStrain = clamp(
            todaysWorkouts.reduce(0.0) { $0 + workoutStrainPenalty(for: $1) },
            min: 0,
            max: 24
        )
        let carryoverStrain = clamp(
            yesterdaysWorkouts.reduce(0.0) { $0 + (workoutStrainPenalty(for: $1) * 0.45) },
            min: 0,
            max: 10
        )
        let totalStrain = todaysStrain + carryoverStrain

        let habitAdjustment = bodyBatteryHabitAdjustment(from: todaysCheckIns.last?.values ?? [:])
        let rawScore = 28 + sleepRecharge + habitAdjustment - totalStrain
        let score = Int(clamp(rawScore.rounded(), min: 5, max: 100))

        let statusTone: SQDashboardTrendTone
        let statusTitle: String
        let headline: String
        switch score {
        case 80...100:
            statusTone = .positive
            statusTitle = "High"
            headline = "Well charged for the day"
        case 60..<80:
            statusTone = .positive
            statusTitle = "Solid"
            headline = "Recovery is carrying you"
        case 40..<60:
            statusTone = .neutral
            statusTitle = "Moderate"
            headline = "Energy reserves are mixed"
        case 20..<40:
            statusTone = .negative
            statusTitle = "Low"
            headline = "Battery is running low"
        default:
            statusTone = .negative
            statusTitle = "Drained"
            headline = "Recovery is under pressure"
        }

        let summary = bodyBatterySummary(
            sleepRecharge: sleepRecharge,
            totalStrain: totalStrain,
            habitAdjustment: habitAdjustment
        )

        let row = SQDashboardBodyBatteryRowViewModel(
            score: score,
            statusTitle: statusTitle,
            statusTone: statusTone,
            headline: headline,
            summary: summary,
            drivers: [
                .init(
                    title: "Sleep",
                    valueText: "+\(Int(sleepRecharge.rounded()))",
                    detailText: latestSleepScore == nil ? "Awaiting sleep data" : "Recharge from last night",
                    tone: .positive,
                    symbol: .arrowUp
                ),
                .init(
                    title: "Strain",
                    valueText: "-\(Int(totalStrain.rounded()))",
                    detailText: todaysWorkouts.isEmpty && yesterdaysWorkouts.isEmpty ? "No recent load" : "Today + carryover load",
                    tone: totalStrain > 8 ? .negative : .neutral,
                    symbol: totalStrain > 8 ? .arrowDown : nil
                ),
                .init(
                    title: "Check-ins",
                    valueText: signedValueText(for: habitAdjustment),
                    detailText: habitAdjustment == 0 ? "No strong recovery signal" : "Energy, soreness, habits",
                    tone: tone(for: habitAdjustment),
                    symbol: symbol(for: habitAdjustment)
                )
            ],
            footer: "Estimated from last night’s sleep, current workout strain, and today’s recovery signals."
        )

        return SQDashboardSubsectionViewModel(
            id: "body-battery",
            title: "Body Battery",
            rowsByFilter: ["All": [row]],
            dropDownViewModel: nil
        )
    }

    private func workoutStrainPenalty(for workout: SQWorkoutSessionable) -> Double {
        let activeMinutes = max(0, (workout.activeDuration ?? 0) / 60)
        let caloriesPenalty = max(0, (workout.totalCalories ?? 0) / 180)
        let heartRateBonus: Double

        if let averageHeartRate = workout.averageHeartRate {
            heartRateBonus = clamp((averageHeartRate - 130) / 18, min: 0, max: 6)
        } else {
            heartRateBonus = 0
        }

        return clamp((activeMinutes / 11) + caloriesPenalty + heartRateBonus, min: 0, max: 18)
    }

    private func bodyBatteryHabitAdjustment(from values: [String: Float]) -> Double {
        let energyBoost = values[SQMetricId.energy].map { clamp((Double($0) - 5.5) * 1.5, min: -7, max: 7) } ?? 0
        let sorenessBoost = values[SQMetricId.soreness].map { clamp((Double($0) - 5.0) * 1.2, min: -6, max: 6) } ?? 0
        let nutritionBoost = values[SQMetricId.nutrition].map { clamp((Double($0) - 5.0) * 0.7, min: 0, max: 4) } ?? 0
        let alcoholPenalty = values[SQMetricId.alcohol].map { clamp(Double($0) * 1.5, min: 0, max: 12) } ?? 0
        let caffeinePenalty = values[SQMetricId.caffeine].map { clamp((Double($0) - 6.0) * 0.8, min: 0, max: 4) } ?? 0

        return clamp(
            energyBoost + sorenessBoost + nutritionBoost - alcoholPenalty - caffeinePenalty,
            min: -18,
            max: 12
        )
    }

    private func bodyBatterySummary(
        sleepRecharge: Double,
        totalStrain: Double,
        habitAdjustment: Double
    ) -> String {
        if sleepRecharge >= 38 && totalStrain <= 8 && habitAdjustment >= 0 {
            return "Strong overnight recovery is keeping your energy reserves high right now."
        }

        if totalStrain >= 16 {
            return "Recent training load is draining the battery faster than your recovery is rebuilding it."
        }

        if habitAdjustment <= -6 {
            return "Today’s recovery signals are dragging the battery down despite your baseline recharge."
        }

        if habitAdjustment >= 6 {
            return "Good energy and recovery check-ins are helping preserve your battery through the day."
        }

        return "Sleep, strain, and daily recovery signals are fairly balanced right now."
    }

    private func signedValueText(for value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 {
            return "+\(rounded)"
        }
        return "\(rounded)"
    }

    private func tone(for value: Double) -> SQDashboardTrendTone {
        if value > 0 {
            return .positive
        } else if value < 0 {
            return .negative
        }
        return .neutral
    }

    private func symbol(for value: Double) -> SQImageSymbol? {
        if value > 0 {
            return .arrowUp
        } else if value < 0 {
            return .arrowDown
        }
        return nil
    }

    private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    // MARK: - Metric Row Builder

    private func buildMetricRow(for definition: SQMetricDefinition, from stats: [SQDailyCheckInStats], priorStats: [SQDailyCheckInStats]) -> SQDashboardMetricStatsRowViewModel? {
        // Get all values for this metric
        let values = stats.compactMap { $0.values[definition.id] }

        // Skip if no data
        guard !values.isEmpty else {
            SQLogger.shared.log(
                "Metric row skipped for '\(definition.title)' (\(definition.id)) - no current values in \(stats.count) check-ins",
                .debug,
                context: .dashboard
            )
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
        } else if definition.unit == .hours {
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
        switch definition.unit {
        case .none:    return definition.max != nil ? "/\(Int(definition.max ?? 10))" : ""
        case .hours:   return "hrs"
        case .count:   return ""
        case .pounds:  return "lbs"
        case .kilograms: return "kg"
        case .percent: return "%"
        case .unknown: return ""
        }
    }
}
