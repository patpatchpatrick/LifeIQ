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
            await refreshState()
        }
    }
    
    // MARK: - Nav Bar
    
    var timeRanges: [SQTimeRange] = [
        .pastWeek,
        .pastMonth,
        .pastYear,
        .allTime
    ]
    
    @ObservationIgnored
    lazy var currentTimeRange: SQTimeRange = .pastWeek {
        didSet {
            if oldValue != currentTimeRange {
                Task {
                    await refreshState()
                }
            }
        }
    }
    
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
    
    private func refreshState() async {
        refreshUi(with: nil)
        let hkWorkouts = await SQHealthKitManager.shared.fetchWorkouts(currentTimeRange).workouts ?? []
        let stravaWorkouts = SQStravaImport.shared.getSavedStravaWorkouts(currentTimeRange) ?? []
        let allWorkouts = hkWorkouts
            .appending(contentsOf: stravaWorkouts)
            .filterDuplicates()
        
        refreshUi(with: allWorkouts)
    }
    
    private func refreshUi(with workouts: [SQWorkout]?) {
        guard let workouts else {
            activitySection = .init(isPlaceholder: true, title: "Activity Stats", workouts: nil)
            return
        }
        
        activitySection = .init(title: "Activity Stats", workouts: workouts)
    }
}
