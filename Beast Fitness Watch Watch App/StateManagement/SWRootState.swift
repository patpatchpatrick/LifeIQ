//
//  SWRootState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import SwiftUI
import Combine

@MainActor
protocol SWRootStating: AnyObject {
    var title: String { get }
    var heartRateTitle: String { get }
    var activeCaloriesTitle: String { get }
    func updateTitle(to title: String)
    var activeWorkoutDescription: String { get }
}

@MainActor
@Observable final class SWRootState: SWRootStating {
    private var cancellables = Set<AnyCancellable>()
    private(set) var title: String
    private(set) var heartRateTitle: String
    private(set) var activeCaloriesTitle: String
    private(set) var activeWorkoutDescription: String
    
    let hub: SWEventHub
    
    init(hub: SWEventHub) {
        self.hub = hub
        self.title = "Beast Fitness"
        self.heartRateTitle = "N/A"
        self.activeCaloriesTitle = "N/A"
        self.activeWorkoutDescription = "Active Workout Description: No Data"
        handleEventSubscriptions()
    }
    
    private func handleEventSubscriptions() {
        hub.workoutEngineEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .didStart, .didChangeState, .didStop, .didFail:
                break
            case .heartRate(let bpm, _):
                let roundedBpm = bpm.roundedString(decimals: 1)
                heartRateTitle = roundedBpm
            case .activeEnergy(let kcal, _):
                let roundedCals = kcal.roundedString(decimals: 1)
                activeCaloriesTitle = roundedCals
            }
            
        }.store(in: &cancellables)
    }
    
    func updateTitle(to title: String) {
        self.title = title
    }
    
    func updateActiveWorkoutDescription(to title: String) {
        activeWorkoutDescription = title
    }
}
