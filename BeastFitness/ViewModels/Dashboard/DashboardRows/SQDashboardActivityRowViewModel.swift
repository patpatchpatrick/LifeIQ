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
        
        if workoutGroupViewModels.isEmpty {
            ctaViewModel = .init(
                title: "Start workout",
                onTap: {
                    SQAppState.shared.hub.domainEvents.send(.changeTab(.workouts))
            })
        } else {
            ctaViewModel = nil
        }
        
        super.init(rowId: .activityList, rowType: .activityList)
    }
    
}
