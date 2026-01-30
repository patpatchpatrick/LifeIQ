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
    func displayDailyCheckInSheet(for context: ModelContext) async
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
        
        do {
            
            // TODO: - PTD Handle Sleep
            //            let sleepTime = try? await SQHealthKitManager.shared.fetchSleep(currentTimeRange)
            
            var dailyRows: [SQDashboardRowViewModel] = []
            
            let vo2MaxData = try await healthKitManager.fetchVO2MaxSamples(.allTime)
            if let latestVo2Max = vo2MaxData.last {
                dailyRows.append(SQDashboardDailyPerformanceRowViewModel(latestVO2Max: latestVo2Max))
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
            
            dailyRows.append(contentsOf: [
                SQDashboardDailyCheckInRowViewModel(dailyCheckInStats: dailyCheckInStats, context: context),
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
            
            let weeklyWorkoutSummaryRowViewModel = SQDashboardWorkoutSummaryRowViewModel(
                rowId: .weekly,
                config: weeklySectionConfig,
                workouts: lastWeekWorkouts,
                priorWorkouts: weekBeforeLastWorkouts)
            
            if !weeklyWorkoutSummaryRowViewModel.isEmpty {
                dashboardSections.append(.init(
                    title: weeklySectionConfig.timeRange.title,
                    rows: [
                        weeklyWorkoutSummaryRowViewModel
                    ]))
            }
            
            let yearlySectionConfig =  buildConfigTotalsSectionConfig(workoutSummaryRowId: .yearly)
            
            let yearlyWorkoutSummaryRowViewModel = SQDashboardWorkoutSummaryRowViewModel(
                rowId: .yearly,
                config: yearlySectionConfig,
                workouts: lastYearWorkouts,
                priorWorkouts: yearBeforeLastWorkouts)
            
            if !yearlyWorkoutSummaryRowViewModel.isEmpty {
                dashboardSections.append(.init(
                    title: yearlySectionConfig.timeRange.title,
                    rows: [
                        SQDashboardWorkoutSummaryRowViewModel(
                            rowId: .yearly,
                            config: yearlySectionConfig,
                            workouts: lastYearWorkouts,
                            priorWorkouts: yearBeforeLastWorkouts)
                    ]))
            }
            
            state.updateSectionViewModels(to: dashboardSections)
        } catch {
            print("PTD Handle Errors here", error)
            SQLogger.shared.log("Error loading dashboard", .error, context: .dashboard)
            // TODO: - PTD allow refreshes if there is an error here
            state.hub.alertEvents.send(.present(.init(SQError.standard(withDescription: error.localizedDescription))))
        }
    }
    
    func refreshUI(for context: ModelContext) async {
        SQLogger.shared.log("Refreshing dashboard", .debug, context: .dashboard)
        refreshUiWithContext?(context)
    }
    
    func displayDailyCheckInSheet(for context: ModelContext) async {
        let dailyCheckInStats = try? await dailyCheckInManager.getDailyCheckInStats(for: .now, context: context)
        state.displayDailyCheckInSheet(with: dailyCheckInStats)
    }
    
    private func buildConfigTotalsSectionConfig(workoutSummaryRowId: SQDashboardWorkoutSummaryRowViewModel.WorkoutSummaryRowId) -> SQDashboardWorkoutSummaryRowConfig{
        
        return .init(timeRange: workoutSummaryRowId.timeRange, priorTimeRange: workoutSummaryRowId.priorTimeRange)
    }
}
