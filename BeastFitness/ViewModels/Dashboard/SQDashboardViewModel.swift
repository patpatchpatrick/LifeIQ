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
    
    init(state: DashboardStating) {
        self.state = state
    }
}
