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
    let dailyCheckInManager: SQDailyCheckInManaging
    let workoutManager: SQWorkoutManaging
    let healthKitManager: SQHealthKitManaging
    let statsManager: SQWorkoutStatsManaging
    let sleepAggregationService: SQSleepAggregationService
    private(set) var hasLoadedUI = false
    let timeRangeMenuViewModel: SQDropDownMenuViewModel
    
    
    @MainActor
    static let `default` = SQDashboardController(state: SQAppState.shared.dashboardState, navState: SQAppState.shared.navigationState)
    
    init(
        state: DashboardStating,
        navState: NavigationStating,
        dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(),
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared,
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        statsManager: SQWorkoutStatsManaging = SQWorkoutStatsManager.shared,
        sleepAggregationService: SQSleepAggregationService = .init()
    ) {
        self.state = state
        self.navState = navState
        self.dailyCheckInManager = dailyCheckInManager
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
        
        self.handleEventSubscriptions(hub: state.hub)
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
        guard !hasLoadedUI || shouldForceRefresh else { return }
        hasLoadedUI = true

        // Show mock skeleton while real data loads
        state.updateSectionGroups(to: SQDashboardSectionGroupViewModel.mock)
        state.setLoading(true)

        do {
            // Sync daily check-ins from Firestore
            let timeRange = state.selectedTimeRange.sqTimeRange
            _ = try await dailyCheckInManager.syncDailyCheckInsIfNeeded(
                for: timeRange,
                context: context
            )

            // Sync metric definitions from Firestore
            do {
                _ = try await SQMetricsManager.shared.syncMetricsIfNeeded(using: context)
            } catch {
                SQLogger.shared.log("Metric definitions sync failed: \(error)", .error, context: .dashboard)
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

            // period: nil → return stats if *any* entries exist today regardless of session.
            // This means the CTA disappears after the first completed check-in (morning or evening),
            // even if the other session hasn't been filled in yet. Update to use
            // DashboardState.checkInPeriod(for: .now) if the CTA should remain visible
            // until the *current* session's check-in is also complete.
            let dailyCheckInStats = try? await dailyCheckInManager.getDailyCheckInStats(for: .now, period: nil, context: context)

            // Fetch historical check-ins for different time ranges using SQTimeRange dates
            let todaysCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.today.startDate,
                to: SQTimeRange.today.endDate,
                context: context
            )

            let past7DaysCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.pastWeek.startDate,
                to: SQTimeRange.pastWeek.endDate,
                context: context
            )

            let past30DaysCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.past30Days.startDate,
                to: SQTimeRange.past30Days.endDate,
                context: context
            )

            let pastYearCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.pastYear.startDate,
                to: SQTimeRange.pastYear.endDate,
                context: context
            )

            let weekBeforeLastCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.weekBeforeLast.startDate,
                to: SQTimeRange.weekBeforeLast.endDate,
                context: context
            )

            let thirtyDaysBeforeLastCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.thirtyDaysBeforeLast.startDate,
                to: SQTimeRange.thirtyDaysBeforeLast.endDate,
                context: context
            )

            let yearBeforeLastCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.yearBeforeLast.startDate,
                to: SQTimeRange.yearBeforeLast.endDate,
                context: context
            )

            // Set the daily check-in CTA view model if no stats exist
            if dailyCheckInStats == nil {
                state.updateDailyCheckInCtaViewModel(.init(
                    icon: .init(symbol: .checkmark),
                    title: "Complete your daily check-in",
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
                currentCheckIns = pastYearCheckIns  // Use past year for metrics (all-time check-ins would be too much data)
                priorCheckIns = []
                currentVO2MaxSamples = vo2MaxAllTime
            }

            let sleepDashboardData = try await buildSleepDashboardData(
                for: state.selectedTimeRange
            )

            let sectionGroups = await buildSectionGroups(
                checkIns: currentCheckIns,
                priorCheckIns: priorCheckIns,
                vo2MaxSamples: currentVO2MaxSamples,
                vo2MaxAllTime: vo2MaxAllTime,
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

        let stats = checkIns
        let allDefinitions = SQMetricsManager.shared.dailyCheckInMetrics()

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

            return .init(icon: .edit) { [weak self] in
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
            columnHeaders: ["Metric", "Avg Score", timeRange.dashboardChangePctHeader]
        )

        // ✅ Pass the title (String) to match rowsByFilter keys
        dropDownViewModel.itemSelectionHandler = { [weak sectionViewModel] selectedItem in
            sectionViewModel?.updateActiveFilter(selectedItem)
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
                title: "VO2 Max",
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
            columnHeaders: ["Stat", "Best Score", "Rank"]
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
            rowSpacing: .SQSpace.l
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

        let scoreRow = SQDashboardSleepScoreRowViewModel(
            totalScore: totalScore,
            scoreLabel: "\(Int(round(totalScore)))/100",
            components: [
                .init(
                    id: "duration",
                    title: "Duration",
                    score: averageScore.durationScore,
                    maxScore: SQSleepScoreBreakdown.maxDurationScore,
                    color: .accent(1)
                ),
                .init(
                    id: "bedtime",
                    title: "Bedtime",
                    score: averageScore.bedtimeScore,
                    maxScore: SQSleepScoreBreakdown.maxBedtimeScore,
                    color: .accentNeutral1
                ),
                .init(
                    id: "interruptions",
                    title: "Interruptions",
                    score: averageScore.interruptionsScore,
                    maxScore: SQSleepScoreBreakdown.maxInterruptionsScore,
                    color: .accentNeutral4
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

        if state.selectedTimeRange == .today, let timelineRow = buildSleepPhaseTimelineRow(with: data) {
            rows.append(timelineRow)
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

    private func buildSleepPhaseTimelineRow(with data: SQSleepDashboardData) -> SQDashboardSleepPhaseTimelineRowViewModel? {
        guard let latestNight = data.latestNight else { return nil }

        let lanes: [TimelineChartLane] = [
            .init(id: SQSleepPhase.awake.rawValue, title: "Awake", color: SQColor.textWarning.color),
            .init(id: SQSleepPhase.rem.rawValue, title: "REM", color: SQColor.accentNeutral1.color),
            .init(id: SQSleepPhase.core.rawValue, title: "Core", color: SQColor.accent(1).color),
            .init(id: SQSleepPhase.deep.rawValue, title: "Deep", color: SQColor.accentNeutral4.color)
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
        vo2MaxSamples: [SQVO2MaxSample],
        vo2MaxAllTime: [SQVO2MaxSample],
        workouts: [SQWorkoutSessionable],
        priorWorkouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        timeRange: SQTimeRange,
        priorTimeRange: SQTimeRange,
        context: ModelContext
    ) async -> [SQDashboardSectionGroupViewModel] {
        var sectionGroups: [SQDashboardSectionGroupViewModel] = []

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

    // MARK: - Metric Row Builder

    private func buildMetricRow(for definition: SQMetricDefinition, from stats: [SQDailyCheckInStats], priorStats: [SQDailyCheckInStats]) -> SQDashboardMetricStatsRowViewModel? {
        // Get all values for this metric
        let values = stats.compactMap { $0.values[definition.id] }

        // Skip if no data
        guard !values.isEmpty else { return nil }

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
        let unitString: String
        switch definition.unit {
        case .none:
            unitString = definition.max != nil ? "/\(Int(definition.max ?? 10))" : ""
        case .hours:
            unitString = "hrs"
        case .count:
            unitString = ""
        case .pounds:
            unitString = "lbs"
        case .kilograms:
            unitString = "kg"
        case .percent:
            unitString = "%"
        case .unknown:
            unitString = ""
        }

        // Build sparkline data (in chronological order)
        let sparklineData = values.map { Double($0) }

        // Icon: use emoji if available, otherwise empty string
        let icon = definition.emoji ?? ""

        // Log sparkline data for debugging
        SQLogger.shared.log(
            "Metric '\(definition.title)': sparklineData count = \(sparklineData.count), icon = '\(icon)'",
            .debug,
            context: .dashboard
        )

        // Calculate percentage change vs comparison period
        let priorValues = priorStats.compactMap { $0.values[definition.id] }
        let priorAverage: Float? = priorValues.isEmpty ? nil : priorValues.reduce(0, +) / Float(priorValues.count)

        let changePercent: Double?
        if let prior = priorAverage, prior != 0 {
            changePercent = Double((average - prior) / prior)
        } else {
            changePercent = nil
        }

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
}
