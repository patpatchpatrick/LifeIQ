//
//  SQWatchInterface.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/18/25.
//

import HealthKit

@MainActor
final class SQWatchInterface {
    private let healthStore = HKHealthStore()
    
    static let shared = SQWatchInterface()

    func startStrengthWorkoutOnWatch() {
        var config = HKWorkoutConfiguration()
        config.activityType = .functionalStrengthTraining
        config.locationType = .indoor

        healthStore.startWatchApp(with: config) { success, error in
            if let error { print("startWatchApp error:", error) }
            print("startWatchApp success:", success)
        }
    }
    
    func configureMirroringHandler(
            onStart: @escaping @MainActor (HKWorkoutSession) -> Void
        ) {
            healthStore.workoutSessionMirroringStartHandler = { session in
                Task { @MainActor in
                    onStart(session)
                }
            }
        }
}
