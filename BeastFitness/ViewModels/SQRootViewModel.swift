//
//  SQRootViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import Foundation
import HealthKit
import SwiftUI

@Observable
class SQRootViewModel {
    
    let deepLinkManager = SQDeepLinkManager()
    var navigationPath = NavigationPath()
    
    // MARK: - Vars

    private(set) var activitySection: SQRootActivitySectionViewModel = .init(
        isPlaceholder: true,
        title: "Activity Stats",
        workouts: [])
    
    // MARK: - Init
    
    init () {
        Task {
            let hkWorkouts = await SQHealthKitManager.shared.fetchWorkouts().workouts ?? []
            let stravaWorkouts = SQStravaImport.shared.getSavedStravaWorkouts() ?? []
            let allWorkouts = hkWorkouts.appending(contentsOf: stravaWorkouts)
            refreshUi(with: allWorkouts)
        }
    }
    
    // MARK: - Nav Bar
    
    enum SQTimeRange: String {
        case pastWeek = "Past Week"
        case pastMonth = "Past Month"
        case pastYear = "Past Year"
        case allTime = "All Time"
        
        var title: String {
            self.rawValue
        }
    }
    
    var timeRanges: [SQTimeRange] = [
        .pastWeek,
        .pastMonth,
        .pastYear,
        .allTime
    ]
    
    @ObservationIgnored
    lazy var currentTimeRange: SQTimeRange = .pastWeek
    
    @ObservationIgnored
    lazy var navBarViewModel = SQNavBarViewModel(leadingViewModel: navBarDropDownViewModel)
    
    @ObservationIgnored
    lazy var navBarDropDownViewModel = SQDropDownMenuViewModel(
        defaultItem: .init(title: currentTimeRange.title),
        items: timeRanges.map { .init(
            title: $0.title,
            shouldUpdateTitle: true) })
    { [weak self] modeTitle in
        if let selectedTimeRange = SQTimeRange(rawValue: modeTitle) {
            self?.currentTimeRange = selectedTimeRange
        }
    }
    
    // MARK: UI
    
    private func refreshUi(with workouts: [SQWorkout]?) {
        activitySection = .init(title: "Activity Stats", workouts: workouts)
    }
}
