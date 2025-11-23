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
    private let state: DashboardStating
    private(set) var rowViewModels: [SQDashboardRowViewModel] = []
    
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
            
            var dashboardRows = [SQDashboardRowViewModel]()
            
            dashboardRows.append(SQDashboardTextRowViewModel(text: "You’ve hit 4/5 of your workouts this week.\nKeep your streak up! 🔥"))
            
            dashboardRows.append(SQDashboardWeekSummaryRowViewModel(timeRange: .today, workouts: todaysWorkouts, priorWorkouts: yesterdaysWorkouts))
            
            dashboardRows.append(SQDashboardWeekSummaryRowViewModel(timeRange: .pastWeek, workouts: lastWeekWorkouts, priorWorkouts: weekBeforeLastWorkouts))
            
            self.rowViewModels = dashboardRows
        } catch {
            print("PTD Handle Errors here", error)
        }
    }
}
