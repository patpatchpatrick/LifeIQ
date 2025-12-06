//
//  SQRootTabViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SQRootTabViewModel {
    private(set) var dashboardViewModel: SQDashboardController
    var dashboardNavigationPath = NavigationPath()
    
    private(set) var workoutsScreenController: SQWorkoutsLandingController
    var workoutsNavigationPath = NavigationPath()
    
    // MARK: - Init
    
    init(appState: AppState) {
        self.dashboardViewModel = .init(state: appState.dashboardState)
        self.workoutsScreenController = .init(state: appState.workoutScreenState)
    }
}
