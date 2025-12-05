//
//  SQDashboardController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI
import Combine
import SwiftData

@MainActor
protocol SQDashboardInterface {
    func loadUI(for context: ModelContext) async
    func refreshUI(for context: ModelContext) async
    func displayDailyCheckInSheet(for context: ModelContext) async
}

@Observable @MainActor
final class SQDashboardController: SQDashboardInterface {
    let state: DashboardStating
    let dailyCheckInManager: SQDailyCheckInManaging
    private(set) var hasLoadedUI = false
    
    @MainActor
    static var `default` = SQDashboardController(state: AppState.shared.dashboardState)
    
    init(state: DashboardStating, dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager()) {
        self.state = state
        self.dailyCheckInManager = dailyCheckInManager
    }
    
    func loadUI(for context: ModelContext) async {
        guard !hasLoadedUI else { return }
        hasLoadedUI = true
        
        do {
            let todaysWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.today)
            let yesterdaysWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.yesterday)
            
            let lastWeekWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.pastWeek)
            let weekBeforeLastWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.weekBeforeLast)
            
            let lastYearWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.pastYear)
            let yearBeforeLastWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.yearBeforeLast)
            
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
        let currentViewModels = state.rowViewModels
        
        if let dailyWorkoutSummaryRow = currentViewModels.first(where: { $0.rowId == .dailySummary }) as? SQDashboardWorkoutSummaryRowViewModel {
            let config = await buildConfigTotalsSectionConfig(workoutSummaryRowId: .daily, for: context)
            dailyWorkoutSummaryRow.refresh(config: config)
        }
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
                onTap: { Task { await SQDashboardController.default.displayDailyCheckInSheet(for: context) }})
            
            return .init(
                callToAction: dailyCheckInCta,
                dailyCheckInSummaryConfig: dailyCheckInStatsSummaryConfig)
        }()
        
        return .init(timeRange: workoutSummaryRowId.timeRange, priorTimeRange: workoutSummaryRowId.priorTimeRange, dailyCheckInSummarySectionViewModel: dailyCheckInViewModel)
    }
}
