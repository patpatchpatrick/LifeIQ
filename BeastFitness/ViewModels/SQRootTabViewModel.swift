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
    private(set) var dashboardViewModel: SQDashboardViewModel
    var dashboardNavigationPath = NavigationPath()
    
    // MARK: - Init
    
    init(appState: AppState) {
        self.dashboardViewModel = .init(state: appState.dashboardState)
    }
}
