//
//  SWEventHub.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import Combine
import HealthKit

@MainActor
final class SWEventHub {
    let workoutEngineEvents = PassthroughSubject<SQWorkoutEngineEvent, Never>()
}

public enum SQWorkoutEngineEvent: Sendable {
    case didStart(start: Date)
    case didChangeState(from: HKWorkoutSessionState, to: HKWorkoutSessionState, date: Date)

    // Live metrics
    case heartRate(bpm: Double, date: Date)
    case activeEnergy(kcal: Double, date: Date)

    // Lifecycle/errors
    case didStop(end: Date)
    case didFail(errorDescription: String)
}
