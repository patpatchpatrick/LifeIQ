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
    private(set) var hasLoadedUI = false
    /// A context-bound refresh callback installed by `attach(context:)`.
       ///
       /// This is intentionally optional: if the controller is not attached yet,
       /// event-driven refreshes become a no-op rather than trying to guess a context.
    private(set) var refreshUiWithContext: ((ModelContext?) -> Void)?
    
    @MainActor
    static let `default` = SQDashboardController(state: AppState.shared.dashboardState)
    
    init(state: DashboardStating, dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(), workoutManager: SQWorkoutManaging = SQWorkoutManager()) {
        self.state = state
        self.dailyCheckInManager = dailyCheckInManager
        self.workoutManager = workoutManager
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
            let todaysWorkouts = try await workoutManager.getWorkouts(for: .today, modelContext: context)
            let yesterdaysWorkouts = try await workoutManager.getWorkouts(for: .yesterday, modelContext: context)
            
            let lastWeekWorkouts = try await workoutManager.getWorkouts(for: .pastWeek, modelContext: context)
            let weekBeforeLastWorkouts = try await workoutManager.getWorkouts(for: .weekBeforeLast, modelContext: context)
            
            let lastYearWorkouts = try await workoutManager.getWorkouts(for: .pastYear, modelContext: context)
            let yearBeforeLastWorkouts = try await workoutManager.getWorkouts(for: .yearBeforeLast, modelContext: context)
            
            var dashboardRows = [SQDashboardRowViewModel]()
            
            dashboardRows.append(SQDashboardTextRowViewModel(rowId: .motiviationalQuote, text: "You’ve hit 4/5 of your workouts this week.\nKeep your streak up! 🔥"))
            
            let dailySectionConfig = await buildConfigTotalsSectionConfig(workoutSummaryRowId: .daily, for: context)
            
            dashboardRows.append(SQDashboardWorkoutSummaryRowViewModel(
                rowId: .daily,
                config: dailySectionConfig,
                workouts: todaysWorkouts,
                priorWorkouts: yesterdaysWorkouts))
            
            let weeklySectionConfig = await buildConfigTotalsSectionConfig(workoutSummaryRowId: .weekly, for: context)
            dashboardRows.append(SQDashboardWorkoutSummaryRowViewModel(rowId: .weekly, config: weeklySectionConfig, workouts: lastWeekWorkouts, priorWorkouts: weekBeforeLastWorkouts))
            
            let yearlySectionConfig = await buildConfigTotalsSectionConfig(workoutSummaryRowId: .yearly, for: context)
            dashboardRows.append(SQDashboardWorkoutSummaryRowViewModel(rowId: .yearly, config: yearlySectionConfig, workouts: lastYearWorkouts, priorWorkouts: yearBeforeLastWorkouts))
            
            state.updateRowViewModels(to: dashboardRows)
        } catch {
            print("PTD Handle Errors here", error)
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
    
    private func buildConfigTotalsSectionConfig(workoutSummaryRowId: SQDashboardWorkoutSummaryRowViewModel.WorkoutSummaryRowId,  for context: ModelContext) async -> SQDashboardWorkoutSummaryRowConfig{
        
        let dailyCheckInViewModel: SQDashboardWorkoutSummaryDailyCheckInSectionViewModel? = await {
            guard workoutSummaryRowId == .daily else { return nil }
            let dailyCheckInStats = try? await dailyCheckInManager.getDailyCheckInStats(for: .now, context: context)
            let dailyCheckInStatsSummaryConfig: SQDashboardWorkoutSummaryDailyCheckInSectionViewModel.DailyCheckInStatsSummaryConfig? = {
                guard let dailyCheckInStats else { return nil }
                return .init(
                    title: "Daily check-in",
                    subtitle: dailyCheckInStats.summaryString,
                    icon: .edit,
                    /// It's important to not use weak self here.  because the dashboard controller could be deallocated if it's being initialize temporarily to trigger an action
                    onTap: { Task { await SQDashboardController.default.displayDailyCheckInSheet(for: context) } }
                )
            }()
            
            let dailyCheckInCta: SQCallToActionViewModel? = dailyCheckInStats != nil ? nil : .init(
                title: "Complete daily check-in",
                /// It's important to not use weak self here.  because the dashboard controller could be deallocated if it's being initialize temporarily to trigger an action
                onTap: {
                    Task { await SQDashboardController.default.displayDailyCheckInSheet(for: context) }
                })
            
            return .init(
                callToAction: dailyCheckInCta,
                dailyCheckInSummaryConfig: dailyCheckInStatsSummaryConfig)
        }()
        
        return .init(timeRange: workoutSummaryRowId.timeRange, priorTimeRange: workoutSummaryRowId.priorTimeRange, dailyCheckInSummarySectionViewModel: dailyCheckInViewModel)
    }
}
