//
//  SWWorkoutSessionEngine.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import Foundation
import HealthKit

public protocol SQWorkoutSessionEngine: Sendable {
    func start(
        config: HKWorkoutConfiguration,
        onEvent: @escaping @Sendable (SQWorkoutEngineEvent) -> Void
    )
    func stop()
}

// The watch app is currently parked, so keep the workout engine as a no-op.
// This avoids pulling in live workout builder APIs while preserving the target structure.
public final class HKWorkoutSessionEngine: SQWorkoutSessionEngine {
    private var onEvent: (@Sendable (SQWorkoutEngineEvent) -> Void)?

    public init(healthStore: HKHealthStore = HKHealthStore()) {}

    public func start(
        config: HKWorkoutConfiguration,
        onEvent: @escaping @Sendable (SQWorkoutEngineEvent) -> Void
    ) {
        self.onEvent = onEvent
        onEvent(.didFail(errorDescription: "Watch workouts are temporarily disabled."))
    }

    public func stop() {
        onEvent = nil
    }
}
