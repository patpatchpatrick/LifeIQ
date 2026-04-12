//
//  SQDashboardActivityRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardActivityRowViewModel: SQDashboardRowViewModel {
    let workoutGroupViewModels: [SQDashboardWorkoutGroupViewModel]
    let ctaViewModel: SQCallToActionViewModel?
    
    
    init(workoutGroupViewModels: [SQDashboardWorkoutGroupViewModel]) {
        self.workoutGroupViewModels = workoutGroupViewModels
        ctaViewModel = nil

        super.init(rowId: .activityList, rowType: .activityList)
    }
    
}
