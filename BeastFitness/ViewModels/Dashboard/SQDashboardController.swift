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
    let dailyCheckInManager: SQDailyCheckInManaging
    let workoutManager: SQWorkoutManaging
    let healthKitManager: SQHealthKitManaging
    private(set) var hasLoadedUI = false
    let timeRangeMenuViewModel: SQDropDownMenuViewModel
    
    /// A context-bound refresh callback installed by `attach(context:)`.
       ///
       /// This is intentionally optional: if the controller is not attached yet,
       /// event-driven refreshes become a no-op rather than trying to guess a context.
    private(set) var refreshUiWithContext: ((ModelContext?) -> Void)?
    
    @MainActor
    static let `default` = SQDashboardController(state: SQAppState.shared.dashboardState)
    
    init(state: DashboardStating, dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(), workoutManager: SQWorkoutManaging = SQWorkoutManager(), healthKitManager: SQHealthKitManaging = SQHealthKitManager()) {
        self.state = state
        self.dailyCheckInManager = dailyCheckInManager
        self.workoutManager = workoutManager
        self.healthKitManager = healthKitManager
        
        let items = DashboardTimeRange.allCases.map {
            SQDropDownMenuViewModel.Item(title: $0.rawValue)
        }
        self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: state.selectedTimeRange.rawValue),
            items: items
        ) { [weak state] selectedTitle in
            guard let state else { return }
            if let selectedRange = DashboardTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }) {
                state.selectedTimeRange = selectedRange
            }
        }
        
        self.handleEventSubscriptions(hub: state.hub)
    }
    
    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated:
                self.refreshUiWithContext?(nil)
            case .workoutsDeleted:
                self.refreshUiWithContext?(nil)
            case .activeWorkoutUpdate:
                break
            }
        }.store(in: &cancellables)

        // Watch for time range changes and reload dashboard
        state.selectedTimeRangePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                SQLogger.shared.log(
                    "Time range changed, reloading dashboard",
                    .debug,
                    context: .dashboard
                )
                self.refreshUiWithContext?(nil)
            }
            .store(in: &cancellables)
    }
    
    /// Attaches the controller to a `ModelContext` so event-driven refreshes can reload the dashboard.
       ///
       /// Call this from the view layer once you have access to `@Environment(\.modelContext)`.
       /// You may call it multiple times (e.g., if the environment changes); the latest context wins.
    func attach(context: ModelContext) {
        refreshUiWithContext = { [weak self] modelContext in
            guard let self else { return }
            Task { await self.loadUI(for: modelContext ?? context, shouldForceRefresh: true) }
        }
    }
    
    func loadUI(for context: ModelContext, shouldForceRefresh: Bool = false) async {
        guard !hasLoadedUI || shouldForceRefresh else { return }
        hasLoadedUI = true

        // Set loading state
        state.setLoading(true)

        do {
            // Sync daily check-ins from Firestore
            let timeRange = state.selectedTimeRange.toSQTimeRange()
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

            // TODO: - PTD Handle Sleep
            //            let sleepTime = try? await SQHealthKitManager.shared.fetchSleep(currentTimeRange)

            var dailyRows: [SQDashboardRowViewModel] = []

            // Fetch VO2 Max samples for different time ranges
            let vo2MaxPast7Days = try await healthKitManager.fetchVO2MaxSamples(
                .pastWeek
            )
            let vo2MaxPastYear = try await healthKitManager.fetchVO2MaxSamples(
                .pastYear
            )

            // Add performance row to daily section (shows latest value, past 7 days sparkline)
            if !vo2MaxPast7Days.isEmpty {
                dailyRows.append(SQDashboardDailyPerformanceRowViewModel(
                    vo2MaxSamples: vo2MaxPast7Days,
                    timeRange: .today
                ))
            }
            
            let todaysWorkouts = try await workoutManager.getWorkouts(for: .today, modelContext: context)
            
            SQLogger.shared.log("Reloading today's workouts", .debug, context: .dashboard)
            for workout in todaysWorkouts {
                SQLogger.shared.log("Workout: \(workout.prettyDescription)", .debug, context: .dashboard)
            }
            
            let yesterdaysWorkouts = try await workoutManager.getWorkouts(for: .yesterday, modelContext: context)
            
            let lastWeekWorkouts = try await workoutManager.getWorkouts(for: .pastWeek, modelContext: context)
            let weekBeforeLastWorkouts = try await workoutManager.getWorkouts(for: .weekBeforeLast, modelContext: context)
            
            let lastYearWorkouts = try await workoutManager.getWorkouts(for: .pastYear, modelContext: context)
            let yearBeforeLastWorkouts = try await workoutManager.getWorkouts(for: .yearBeforeLast, modelContext: context)

            let dailyCheckInStats = try? await dailyCheckInManager.getDailyCheckInStats(for: .now, context: context)

            // Fetch historical check-ins for different time ranges using SQTimeRange dates
            let past7DaysCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.pastWeek.startDate,
                to: SQTimeRange.pastWeek.endDate,
                context: context
            )

            let pastYearCheckIns = try SQDailyCheckInEntity.getAll(
                from: SQTimeRange.pastYear.startDate,
                to: SQTimeRange.pastYear.endDate,
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
            let currentCheckIns: [SQDailyCheckInStats]
            let currentVO2MaxSamples: [SQVO2MaxSample]

            switch state.selectedTimeRange {
            case .today:
                currentWorkouts = todaysWorkouts
                currentCheckIns = past7DaysCheckIns // Use past 7 days for sparklines
                currentVO2MaxSamples = vo2MaxPast7Days
            case .pastSevenDays:
                currentWorkouts = lastWeekWorkouts
                currentCheckIns = past7DaysCheckIns
                currentVO2MaxSamples = vo2MaxPast7Days
            case .pastYear:
                currentWorkouts = lastYearWorkouts
                currentCheckIns = pastYearCheckIns
                currentVO2MaxSamples = vo2MaxPastYear
            }

            let sectionGroups = buildSectionGroups(
                checkIns: currentCheckIns,
                vo2MaxSamples: currentVO2MaxSamples,
                workouts: currentWorkouts,
                timeRange: state.selectedTimeRange.toSQTimeRange(),
                context: context
            )
            state.updateSectionGroups(to: sectionGroups)

            // Clear loading state
            state.setLoading(false)
        } catch {
            print("PTD Handle Errors here", error)
            SQLogger.shared.log("Error loading dashboard", .error, context: .dashboard)

            // Clear loading state on error
            state.setLoading(false)

            // TODO: - PTD allow refreshes if there is an error here
            state.hub.alertEvents.send(.present(.init(SQError.standard(withDescription: error.localizedDescription))))
        }
    }
    
    func refreshUI(for context: ModelContext) async {
        SQLogger.shared.log("Refreshing dashboard", .debug, context: .dashboard)
        refreshUiWithContext?(context)
    }
    
    func displayDailyCheckInSheet(for context: ModelContext, date: Date? = nil) async {
        let targetDate = date ?? .now
        let dailyCheckInStats = try? await dailyCheckInManager.getDailyCheckInStats(
            for: targetDate,
            context: context
        )
        state.displayDailyCheckInSheet(with: dailyCheckInStats, for: targetDate)
    }
    
    private func buildConfigTotalsSectionConfig(workoutSummaryRowId: SQDashboardWorkoutSummaryRowViewModel.WorkoutSummaryRowId) -> SQDashboardWorkoutSummaryRowConfig{

        return .init(timeRange: workoutSummaryRowId.timeRange, priorTimeRange: workoutSummaryRowId.priorTimeRange)
    }

    // MARK: - Metrics Subsection Builder

    private func buildMetricsSubsection(checkIns: [SQDailyCheckInStats], context: ModelContext) -> SQDashboardSubsectionViewModel {
        // Use the stats directly
        let stats = checkIns

        // Get all metric definitions
        let allDefinitions = SQMetricsManager.shared.dailyCheckInMetrics()

        // Extract unique groups from definitions that have data
        var uniqueGroups = Set<String>()
        for def in allDefinitions {
            let hasData = stats.contains { $0.values[def.id] != nil }
            if hasData {
                uniqueGroups.insert(def.group)
            }
        }

        // Sort groups alphabetically for consistency
        let sortedGroups = uniqueGroups.sorted()

        // Build dropdown items: "All" + sorted groups
        let filterItems = [SQDropDownMenuViewModel.Item(title: "All")] + sortedGroups.map { groupName in
            SQDropDownMenuViewModel.Item(title: groupName)
        }

        // Build rowsByFilter dictionary
        var rowsByFilter: [String: [Any]] = [:]

        // "All" filter: Include all metrics that have data
        var allRows: [SQDashboardMetricStatsRow] = []
        for def in allDefinitions {
            if let row = buildMetricRow(for: def, from: stats) {
                allRows.append(row)
            }
        }
        rowsByFilter["All"] = allRows

        // Per-group filters
        for groupName in sortedGroups {
            var groupRows: [SQDashboardMetricStatsRow] = []
            let groupDefinitions = allDefinitions.filter { $0.group == groupName }

            for def in groupDefinitions {
                if let row = buildMetricRow(for: def, from: stats) {
                    groupRows.append(row)
                }
            }

            rowsByFilter[groupName] = groupRows
        }

        // Create dropdown view model
        let dropDownViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: "All"),
            items: filterItems
        ) { [weak self] selectedFilter in
            guard let self else { return }
            // Find the section and update its active filter
            for group in self.state.sectionGroups {
                if let section = group.sections.first(where: { $0.id == "metrics" }) {
                    section.updateActiveFilter(selectedFilter)
                    break
                }
            }
        }

        // Return section view model
        return SQDashboardSubsectionViewModel(
            id: "metrics",
            title: "Metrics",
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel
        )
    }

    // MARK: - Performance Subsection Builder

    private func buildPerformanceSubsection(vo2MaxSamples: [SQVO2MaxSample], timeRange: SQTimeRange) -> SQDashboardSubsectionViewModel? {
        // Skip if no data
        guard !vo2MaxSamples.isEmpty else { return nil }

        // Calculate average VO2 Max
        let sum = vo2MaxSamples.reduce(0.0) { $0 + $1.value }
        let average = sum / Double(vo2MaxSamples.count)

        // Format average value (e.g., "45.3")
        let avgValueString = String(format: "%.1f", average)

        // Extract sparkline data (already in chronological order)
        let sparklineData = vo2MaxSamples.map { $0.value }

        // Create VO2 Max row
        let vo2MaxRow = SQDashboardMetricStatsRow(
            id: "vo2-max",
            icon: SQImageSymbol.heart.rawValue,
            title: "VO2 Max",
            avgValue: avgValueString,
            unit: "mL/kg/min",
            sparklineData: sparklineData,
            change14d: 0.0  // Placeholder for future 14-day change calculation
        )

        // Build rowsByFilter dictionary (no filters for Performance)
        let rowsByFilter: [String: [Any]] = ["All": [vo2MaxRow]]

        // Return section view model
        return SQDashboardSubsectionViewModel(
            id: "performance",
            title: "Performance",
            rowsByFilter: rowsByFilter,
            dropDownViewModel: nil  // No filter dropdown for performance
        )
    }

    // MARK: - Totals Subsection Builder

    private func buildTotalsSubsection(workouts: [SQWorkoutSessionable], timeRange: SQTimeRange) -> SQDashboardSubsectionViewModel? {
        // Skip if no workouts
        guard !workouts.isEmpty else { return nil }

        // Group workouts by activity type
        var workoutsByActivity: [String: [SQWorkoutSessionable]] = [:]
        for workout in workouts {
            let activityName = workout.activityType.name
            workoutsByActivity[activityName, default: []].append(workout)
        }

        // Build Time filter rows
        var timeRows: [SQDashboardMetricStatsRow] = []
        for (activityName, activityWorkouts) in workoutsByActivity {
            // Sum total duration in seconds
            let totalSeconds = activityWorkouts.compactMap { $0.activeDuration }.reduce(0, +)

            // Convert to hours or minutes
            let hours = totalSeconds / 3600.0
            let avgValue: String
            let unit: String

            if hours >= 1.0 {
                avgValue = String(format: "%.1f", hours)
                unit = "hrs"
            } else {
                let minutes = totalSeconds / 60.0
                avgValue = String(format: "%.1f", minutes)
                unit = "min"
            }

            // Get activity type from first workout
            let activityType = activityWorkouts.first?.activityType
            let icon = activityType?.imageSymbol.rawValue ?? ""

            timeRows.append(SQDashboardMetricStatsRow(
                id: activityName,
                icon: icon,
                title: activityName,
                avgValue: avgValue,
                unit: unit,
                sparklineData: [],
                change14d: 0.0
            ))
        }

        // Sort by total duration (descending)
        timeRows.sort { lhs, rhs in
            guard let lhsWorkouts = workoutsByActivity[lhs.id],
                  let rhsWorkouts = workoutsByActivity[rhs.id] else {
                return false
            }
            let lhsTotal = lhsWorkouts.compactMap { $0.activeDuration }.reduce(0, +)
            let rhsTotal = rhsWorkouts.compactMap { $0.activeDuration }.reduce(0, +)
            return lhsTotal > rhsTotal
        }

        // Build Kilocalories filter rows
        var kcalRows: [SQDashboardMetricStatsRow] = []
        for (activityName, activityWorkouts) in workoutsByActivity {
            // Sum total kilocalories
            let totalKcal = activityWorkouts.compactMap { $0.totalCalories }.reduce(0, +)

            // Skip if no calorie data
            guard totalKcal > 0 else { continue }

            let avgValue = String(format: "%.0f", totalKcal)

            // Get activity type from first workout
            let activityType = activityWorkouts.first?.activityType
            let icon = activityType?.imageSymbol.rawValue ?? ""

            kcalRows.append(SQDashboardMetricStatsRow(
                id: activityName,
                icon: icon,
                title: activityName,
                avgValue: avgValue,
                unit: "kcal",
                sparklineData: [],
                change14d: 0.0
            ))
        }

        // Sort by total kilocalories (descending)
        kcalRows.sort { lhs, rhs in
            guard let lhsWorkouts = workoutsByActivity[lhs.id],
                  let rhsWorkouts = workoutsByActivity[rhs.id] else {
                return false
            }
            let lhsTotal = lhsWorkouts.compactMap { $0.totalCalories }.reduce(0, +)
            let rhsTotal = rhsWorkouts.compactMap { $0.totalCalories }.reduce(0, +)
            return lhsTotal > rhsTotal
        }

        // Return nil if no data in either filter
        guard !timeRows.isEmpty || !kcalRows.isEmpty else { return nil }

        // Build rowsByFilter dictionary
        let rowsByFilter: [String: [Any]] = [
            "Time": timeRows,
            "Kilocalories": kcalRows
        ]

        // Create dropdown filter items
        let filterItems = [
            SQDropDownMenuViewModel.Item(title: "Time"),
            SQDropDownMenuViewModel.Item(title: "Kilocalories")
        ]

        // Create dropdown view model
        let dropDownViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: "Time"),
            items: filterItems
        ) { [weak self] selectedFilter in
            guard let self else { return }
            // Find the section and update its active filter
            for group in self.state.sectionGroups {
                if let section = group.sections.first(where: { $0.id == "totals" }) {
                    section.updateActiveFilter(selectedFilter)
                    break
                }
            }
        }

        // Return section view model
        return SQDashboardSubsectionViewModel(
            id: "totals",
            title: "Totals",
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel
        )
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
        var rowsByFilter: [String: [Any]] = [:]

        // "All" filter: Aggregate stats for ALL workouts
        var allRows: [SQDashboardMetricStatsRow] = []

        // Calculate total workouts count
        let totalWorkoutsCount = workouts.count
        allRows.append(SQDashboardMetricStatsRow(
            id: "all-workouts",
            icon: SQImageSymbol.chartBar.rawValue,
            title: "Workouts",
            avgValue: "\(totalWorkoutsCount)",
            unit: "total",
            sparklineData: [],
            change14d: 0.0
        ))

        // Calculate total duration
        let totalSeconds = workouts.compactMap { $0.activeDuration }.reduce(0, +)
        let totalHours = totalSeconds / 3600.0
        let durationValue: String
        let durationUnit: String
        if totalHours >= 1.0 {
            durationValue = String(format: "%.1f", totalHours)
            durationUnit = "hrs"
        } else {
            let minutes = totalSeconds / 60.0
            durationValue = String(format: "%.1f", minutes)
            durationUnit = "min"
        }
        allRows.append(SQDashboardMetricStatsRow(
            id: "all-duration",
            icon: SQImageSymbol.clock.rawValue,
            title: "Duration",
            avgValue: durationValue,
            unit: durationUnit,
            sparklineData: [],
            change14d: 0.0
        ))

        // Calculate total kilocalories
        let totalKcal = workouts.compactMap { $0.totalCalories }.reduce(0, +)
        if totalKcal > 0 {
            allRows.append(SQDashboardMetricStatsRow(
                id: "all-kcal",
                icon: SQImageSymbol.flame.rawValue,
                title: "Kilocalories",
                avgValue: String(format: "%.0f", totalKcal),
                unit: "kcal",
                sparklineData: [],
                change14d: 0.0
            ))
        }

        // Calculate average duration per workout
        let avgDurationSeconds = totalSeconds / Double(totalWorkoutsCount)
        let avgDurationHours = avgDurationSeconds / 3600.0
        let avgDurationValue: String
        let avgDurationUnit: String
        if avgDurationHours >= 1.0 {
            avgDurationValue = String(format: "%.1f", avgDurationHours)
            avgDurationUnit = "hrs"
        } else {
            let avgMinutes = avgDurationSeconds / 60.0
            avgDurationValue = String(format: "%.1f", avgMinutes)
            avgDurationUnit = "min"
        }
        allRows.append(SQDashboardMetricStatsRow(
            id: "all-avg-duration",
            icon: SQImageSymbol.clock.rawValue,
            title: "Avg Duration",
            avgValue: avgDurationValue,
            unit: avgDurationUnit,
            sparklineData: [],
            change14d: 0.0
        ))

        // Calculate average kilocalories per workout
        if totalKcal > 0 {
            let avgKcal = totalKcal / Double(totalWorkoutsCount)
            allRows.append(SQDashboardMetricStatsRow(
                id: "all-avg-kcal",
                icon: SQImageSymbol.flame.rawValue,
                title: "Avg Kilocalories",
                avgValue: String(format: "%.0f", avgKcal),
                unit: "kcal",
                sparklineData: [],
                change14d: 0.0
            ))
        }

        rowsByFilter["All"] = allRows

        // Per-activity filters
        for activityType in sortedActivityTypes {
            var activityRows: [SQDashboardMetricStatsRow] = []

            // Filter workouts for this activity type
            let activityWorkouts = workouts.filter { $0.activityType.name == activityType }

            // Get icon from first workout
            let icon = activityWorkouts.first?.activityType.imageSymbol.rawValue ?? SQImageSymbol.figureRun.rawValue

            // Workouts count for this activity
            let activityWorkoutsCount = activityWorkouts.count
            activityRows.append(SQDashboardMetricStatsRow(
                id: "\(activityType)-workouts",
                icon: icon,
                title: "Workouts",
                avgValue: "\(activityWorkoutsCount)",
                unit: "total",
                sparklineData: [],
                change14d: 0.0
            ))

            // Total duration for this activity
            let activityTotalSeconds = activityWorkouts.compactMap { $0.activeDuration }.reduce(0, +)
            let activityTotalHours = activityTotalSeconds / 3600.0
            let activityDurationValue: String
            let activityDurationUnit: String
            if activityTotalHours >= 1.0 {
                activityDurationValue = String(format: "%.1f", activityTotalHours)
                activityDurationUnit = "hrs"
            } else {
                let activityMinutes = activityTotalSeconds / 60.0
                activityDurationValue = String(format: "%.1f", activityMinutes)
                activityDurationUnit = "min"
            }
            activityRows.append(SQDashboardMetricStatsRow(
                id: "\(activityType)-duration",
                icon: SQImageSymbol.clock.rawValue,
                title: "Duration",
                avgValue: activityDurationValue,
                unit: activityDurationUnit,
                sparklineData: [],
                change14d: 0.0
            ))

            // Total kilocalories for this activity
            let activityTotalKcal = activityWorkouts.compactMap { $0.totalCalories }.reduce(0, +)
            if activityTotalKcal > 0 {
                activityRows.append(SQDashboardMetricStatsRow(
                    id: "\(activityType)-kcal",
                    icon: SQImageSymbol.flame.rawValue,
                    title: "Kilocalories",
                    avgValue: String(format: "%.0f", activityTotalKcal),
                    unit: "kcal",
                    sparklineData: [],
                    change14d: 0.0
                ))
            }

            // Average duration per workout for this activity
            let activityAvgDurationSeconds = activityTotalSeconds / Double(activityWorkoutsCount)
            let activityAvgDurationHours = activityAvgDurationSeconds / 3600.0
            let activityAvgDurationValue: String
            let activityAvgDurationUnit: String
            if activityAvgDurationHours >= 1.0 {
                activityAvgDurationValue = String(format: "%.1f", activityAvgDurationHours)
                activityAvgDurationUnit = "hrs"
            } else {
                let activityAvgMinutes = activityAvgDurationSeconds / 60.0
                activityAvgDurationValue = String(format: "%.1f", activityAvgMinutes)
                activityAvgDurationUnit = "min"
            }
            activityRows.append(SQDashboardMetricStatsRow(
                id: "\(activityType)-avg-duration",
                icon: SQImageSymbol.clock.rawValue,
                title: "Avg Duration",
                avgValue: activityAvgDurationValue,
                unit: activityAvgDurationUnit,
                sparklineData: [],
                change14d: 0.0
            ))

            // Average kilocalories per workout for this activity
            if activityTotalKcal > 0 {
                let activityAvgKcal = activityTotalKcal / Double(activityWorkoutsCount)
                activityRows.append(SQDashboardMetricStatsRow(
                    id: "\(activityType)-avg-kcal",
                    icon: SQImageSymbol.flame.rawValue,
                    title: "Avg Kilocalories",
                    avgValue: String(format: "%.0f", activityAvgKcal),
                    unit: "kcal",
                    sparklineData: [],
                    change14d: 0.0
                ))
            }

            rowsByFilter[activityType] = activityRows
        }

        // Create dropdown view model
        let dropDownViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: "All"),
            items: filterItems
        ) { [weak self] selectedFilter in
            guard let self else { return }
            // Find the section and update its active filter
            for group in self.state.sectionGroups {
                if let section = group.sections.first(where: { $0.id == "activities" }) {
                    section.updateActiveFilter(selectedFilter)
                    break
                }
            }
        }

        // Return section view model
        return SQDashboardSubsectionViewModel(
            id: "activities",
            title: "Activities",
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel
        )
    }

    // MARK: - Section Groups Builder

    private func buildSectionGroups(
        checkIns: [SQDailyCheckInStats],
        vo2MaxSamples: [SQVO2MaxSample],
        workouts: [SQWorkoutSessionable],
        timeRange: SQTimeRange,
        context: ModelContext
    ) -> [SQDashboardSectionGroupViewModel] {
        var sectionGroups: [SQDashboardSectionGroupViewModel] = []

        // Build Daily Stats group
        var dailyStatsSections: [SQDashboardSubsectionViewModel] = []

        // Add Metrics subsection
        let metricsSection = buildMetricsSubsection(checkIns: checkIns, context: context)
        dailyStatsSections.append(metricsSection)

        // Add Performance subsection
        if let performanceSection = buildPerformanceSubsection(vo2MaxSamples: vo2MaxSamples, timeRange: timeRange) {
            dailyStatsSections.append(performanceSection)
        }

        // Add Totals subsection
        if let totalsSection = buildTotalsSubsection(workouts: workouts, timeRange: timeRange) {
            dailyStatsSections.append(totalsSection)
        }

        // Add Activities subsection
        if let activitiesSection = buildActivitiesSubsection(workouts: workouts, timeRange: timeRange) {
            dailyStatsSections.append(activitiesSection)
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

        // Create Workouts section group (currently empty, will be populated later)
        let workoutsGroup = SQDashboardSectionGroupViewModel(
            id: "workouts",
            title: "Workouts",
            sections: []
        )
        sectionGroups.append(workoutsGroup)

        return sectionGroups
    }

    // MARK: - Metric Row Builder

    private func buildMetricRow(for definition: SQMetricDefinition, from stats: [SQDailyCheckInStats]) -> SQDashboardMetricStatsRow? {
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
            avgValueString = "\(Int(sum))"
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
        }

        // Build sparkline data (in chronological order)
        let sparklineData = values.map { Double($0) }

        // Icon: use emoji if available, otherwise empty string
        let icon = definition.emoji ?? ""

        return SQDashboardMetricStatsRow(
            id: definition.id,
            icon: icon,
            title: definition.title,
            avgValue: avgValueString,
            unit: unitString,
            sparklineData: sparklineData,
            change14d: 0.0  // Placeholder for now
        )
    }
}
