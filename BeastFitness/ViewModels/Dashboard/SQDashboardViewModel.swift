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
        
        let lastWeekWorkouts = await SQHealthKitManager.shared.fetchWorkouts(.pastWeek).workouts ?? []
        let weekBeforeLastWorkouts = await SQHealthKitManager.shared.fetchWorkouts(.weekBeforeLast).workouts ?? []
        
        var dashboardRows = [SQDashboardRowViewModel]()
        
        dashboardRows.append(SQDashboardTextRowViewModel(text: "You’ve hit 4/5 of your workouts this week.\nKeep your streak up! 🔥"))
        
        dashboardRows.append(SQDashboardWeekSummaryRowViewModel(workouts: lastWeekWorkouts, priorWeekWorkouts: weekBeforeLastWorkouts))
        
        self.rowViewModels = dashboardRows
    }
}
