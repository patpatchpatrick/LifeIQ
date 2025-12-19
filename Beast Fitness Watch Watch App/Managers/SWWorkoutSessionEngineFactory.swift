//
//  SWWorkoutSessionEngineFactory.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import HealthKit

public enum SQWorkoutSessionEngineFactory {
    public static func make(config: SQWorkoutEngineConfig) -> SQWorkoutSessionEngine {
        if config.useMockData { return SWMockWorkoutSessionEngine() }
        return HKWorkoutSessionEngine()
    }
}

public struct SQWorkoutEngineConfig: Sendable {
    public var useMockData: Bool
    public init(useMockData: Bool) { self.useMockData = useMockData }
}
