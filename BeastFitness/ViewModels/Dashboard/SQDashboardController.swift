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
    let state: DashboardStating
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
            
            var dashboardSections = [SQDashboardSectionViewModel]()
            
            let dailySectionConfig =  buildConfigTotalsSectionConfig(workoutSummaryRowId: .daily)

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

            dailyRows.append(contentsOf: [
                SQDashboardDailyCheckInRowViewModel(
                    dailyCheckInStats: dailyCheckInStats,
                    historicalStats: past7DaysCheckIns, // Past 7 days for sparklines
                    timeRange: .today,
                    context: context
                ),
                SQDashboardWorkoutSummaryRowViewModel(
                    rowId: .daily,
                    config: dailySectionConfig,
                    workouts: todaysWorkouts,
                    priorWorkouts: yesterdaysWorkouts)
            ])

            dashboardSections.append(.init(
                title: dailySectionConfig.timeRange.title,
                rows: dailyRows))

            let weeklySectionConfig = buildConfigTotalsSectionConfig(workoutSummaryRowId: .weekly)

            let weeklyCheckInRow = SQDashboardDailyCheckInRowViewModel(
                dailyCheckInStats: nil,
                historicalStats: past7DaysCheckIns, // Past 7 days for averages and sparklines
                timeRange: .pastSevenDays,
                context: context
            )

            let weeklyPerformanceRow = SQDashboardDailyPerformanceRowViewModel(
                vo2MaxSamples: vo2MaxPast7Days, // Past 7 days average and sparkline
                timeRange: .pastSevenDays
            )

            let weeklyWorkoutSummaryRowViewModel = SQDashboardWorkoutSummaryRowViewModel(
                rowId: .weekly,
                config: weeklySectionConfig,
                workouts: lastWeekWorkouts,
                priorWorkouts: weekBeforeLastWorkouts)

            var weeklyRows: [SQDashboardRowViewModel] = []
            
            if weeklyPerformanceRow.vitalRow != nil {
                weeklyRows.append(weeklyPerformanceRow)
            }
            
            if weeklyCheckInRow.shouldShow {
                weeklyRows.append(weeklyCheckInRow)
            }
            if !weeklyWorkoutSummaryRowViewModel.isEmpty {
                weeklyRows.append(weeklyWorkoutSummaryRowViewModel)
            }

            if !weeklyRows.isEmpty {
                dashboardSections.append(.init(
                    title: weeklySectionConfig.timeRange.title,
                    rows: weeklyRows))
            }
            
            let yearlySectionConfig =  buildConfigTotalsSectionConfig(workoutSummaryRowId: .yearly)

            let yearlyCheckInRow = SQDashboardDailyCheckInRowViewModel(
                dailyCheckInStats: nil,
                historicalStats: pastYearCheckIns, // Past year for averages and sparklines
                timeRange: .pastYear,
                context: context
            )

            let yearlyPerformanceRow = SQDashboardDailyPerformanceRowViewModel(
                vo2MaxSamples: vo2MaxPastYear, // Past year average and sparkline
                timeRange: .pastYear
            )

            let yearlyWorkoutSummaryRowViewModel = SQDashboardWorkoutSummaryRowViewModel(
                rowId: .yearly,
                config: yearlySectionConfig,
                workouts: lastYearWorkouts,
                priorWorkouts: yearBeforeLastWorkouts)

            var yearlyRows: [SQDashboardRowViewModel] = []
            
            if yearlyPerformanceRow.vitalRow != nil {
                yearlyRows.append(yearlyPerformanceRow)
            }
            
            if yearlyCheckInRow.shouldShow {
                yearlyRows.append(yearlyCheckInRow)
            }
            if !yearlyWorkoutSummaryRowViewModel.isEmpty {
                yearlyRows.append(yearlyWorkoutSummaryRowViewModel)
            }

            if !yearlyRows.isEmpty {
                dashboardSections.append(.init(
                    title: yearlySectionConfig.timeRange.title,
                    rows: yearlyRows))
            }
            
            state.updateSectionViewModels(to: dashboardSections)

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
}
