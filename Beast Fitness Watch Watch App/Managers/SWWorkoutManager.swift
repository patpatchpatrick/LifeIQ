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
final class SWWorkoutManager: NSObject {
    static let shared = SWWorkoutManager()

    private var engine: SQWorkoutSessionEngine?
    private var watchConnectivityManager: SWWatchConnectivityManager?
    private var lastBPM: Double = 0

    func startWorkout(with config: HKWorkoutConfiguration) {
        SWAppState.shared.rootState.updateTitle(to: "Workout Started ✅")
        let engine = SQWorkoutSessionEngineFactory.make(config: .init(useMockData: SWAppState.shared.useMockData))
        self.engine = engine
        self.watchConnectivityManager = .init()

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
        switch event {
        case .didStart:
            SQLogger.shared.logW("Engine started", .debug, context: .workoutSession)

        case .didChangeState(let from, let to, _):
            SQLogger.shared.logW("State \(from.rawValue) → \(to.rawValue)", .debug, context: .workoutSession)

        case .heartRate(let bpm, _):
            lastBPM = bpm
            SWAppState.shared.rootState.updateHeartRate(to: "Heart Rate: \(bpm) bpm")

        case .activeEnergy(let kcal, _):
            break

        case .didStop:
            SQLogger.shared.logW("Engine stopped", .info, context: .workoutSession)

        case .didFail(let message):
            SQLogger.shared.logW("Engine error: \(message)", .error, context: .workoutSession, isPriority: true)
        }
    }
}
