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
        var dashboardRows = [SQDashboardRowViewModel]()
        
        dashboardRows.append(SQDashboardTextRowViewModel(text: "You’ve hit 4/5 of your workouts this week.\nKeep your streak up! 🔥"))
        
        self.rowViewModels = dashboardRows
    }
}
