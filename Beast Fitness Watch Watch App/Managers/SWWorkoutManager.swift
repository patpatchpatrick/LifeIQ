//
//  SWWorkoutManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import Foundation
import HealthKit
import BeastFitnessCore

@MainActor
protocol SWWorkoutManaging {
    func startWorkout(with config: HKWorkoutConfiguration)
}

@MainActor
final class SWWorkoutManager: NSObject, SWWorkoutManaging {
    static let shared = SWWorkoutManager()

    private var engine: SQWorkoutSessionEngine?
    private var lastBPM: Double = 0

    func startWorkout(with config: HKWorkoutConfiguration) {
        SWAppState.shared.rootState.updateTitle(to: "Workout Started ✅")
        let engine = SQWorkoutSessionEngineFactory.make(config: .init(useMockData: SWAppState.shared.useMockData))
        self.engine = engine

        SQLogger.shared.logW("Starting workout (mock=\(SWAppState.shared.useMockData))", .info, context: .workoutSession)

        engine.start(config: config) { event in
            // hop back to MainActor for state/UI updates
            Task { @MainActor in
                self.handle(event)
            }
        }
    }

    func stopWorkout() {
        engine?.stop()
        engine = nil
    }

    private func handle(_ event: SQWorkoutEngineEvent) {
        SWAppState.shared.hub.workoutEngineEvents.send(event)
    }
}
