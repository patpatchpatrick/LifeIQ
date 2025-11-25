//
//  SQDashboardViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI
import Combine

@Observable @MainActor
final class SQDashboardViewModel {
    let state: DashboardStating
    private(set) var rowViewModels: [SQDashboardRowViewModel] = []
    let dailyCheckInViewModel = SQDailyCheckInViewModel()
    
    init(state: DashboardStating) {
        self.state = state
        Task {
            await loadUI()
        }
    }
    
    func loadUI() async {
        
        do {
            let todaysWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.today)
            let yesterdaysWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.yesterday)
            
            let lastWeekWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.pastWeek)
            let weekBeforeLastWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.weekBeforeLast)
            
            let lastYearWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.pastYear)
            let yearBeforeLastWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.yearBeforeLast)
            
            var dashboardRows = [SQDashboardRowViewModel]()
            
            dashboardRows.append(SQDashboardTextRowViewModel(text: "You’ve hit 4/5 of your workouts this week.\nKeep your streak up! 🔥"))
            
            dashboardRows.append(SQDashboardWorkoutSummaryRowViewModel(
                config: .init(
                    totalsSectionConfig: .init(callToAction: .init(
                        title: "Complete daily check-in",
                        onTap: { [weak self] in
                            self?.state.toggleDailyCheckInSheetVisibility(true)
                        })),
                    timeRange: .today,
                    priorTimeRange: .yesterday),
                workouts: todaysWorkouts,
                priorWorkouts: yesterdaysWorkouts))
            
            dashboardRows.append(SQDashboardWorkoutSummaryRowViewModel(config: .init(timeRange: .pastWeek, priorTimeRange: .weekBeforeLast), workouts: lastWeekWorkouts, priorWorkouts: weekBeforeLastWorkouts))
            
            dashboardRows.append(SQDashboardWorkoutSummaryRowViewModel(config: .init(timeRange: .pastYear, priorTimeRange: .yearBeforeLast), workouts: lastYearWorkouts, priorWorkouts: yearBeforeLastWorkouts))
            
            self.rowViewModels = dashboardRows
        } catch {
            print("PTD Handle Errors here", error)
        }
    }
}
