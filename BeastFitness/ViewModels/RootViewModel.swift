//
//  RootViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import Foundation
import HealthKit

@Observable
class RootViewModel {
    
    let deepLinkManager = SQDeepLinkManager()
    
    // MARK: - Vars

    private(set) var activitySection: RootActivitySectionViewModel = .init(
        isPlaceholder: true,
        title: "Activity Stats",
        workouts: [])
    
    init () {
        Task {
            let hkWorkouts = await SQHealthKitManager.shared.fetchWorkouts().workouts ?? []
            let stravaWorkouts = SQStravaImport.shared.getSavedStravaWorkouts() ?? []
            let allWorkouts = hkWorkouts.appending(contentsOf: stravaWorkouts)
            refreshUi(with: allWorkouts)
        }
    }
    
    // MARK: UI
    
    private func refreshUi(with workouts: [SQWorkout]?) {
        activitySection = .init(title: "Activity Stats", workouts: workouts)
    }
}
