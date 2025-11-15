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
            let lastWeekWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.pastWeek)
            let weekBeforeLastWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(.weekBeforeLast)
            
            var dashboardRows = [SQDashboardRowViewModel]()
            
            dashboardRows.append(SQDashboardTextRowViewModel(text: "You’ve hit 4/5 of your workouts this week.\nKeep your streak up! 🔥"))
            
            dashboardRows.append(SQDashboardWeekSummaryRowViewModel(workouts: lastWeekWorkouts, priorWeekWorkouts: weekBeforeLastWorkouts))
            
            self.rowViewModels = dashboardRows
        } catch {
            print("PTD Handle Errors here", error)
        }
    }
}
